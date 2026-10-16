class_name UnitCard
extends PanelContainer
## What is selected (M6): one unit with its HP, morale, damage, armor, range, speed, stance and
## state; several units as a count per type; or the selected building with its HP,
## construction and what it is training or researching. Refreshed by the HUD after ticks.

var sim: Simulation
var input: PlayerInput

var _title := Label.new()
var _lines := Label.new()
var _hp := ProgressBar.new()
var _morale := ProgressBar.new()
var _hp_label := Label.new()
var _morale_label := Label.new()


func _ready() -> void:
	custom_minimum_size = Vector2(380, 0)
	var box := VBoxContainer.new()
	add_child(box)
	_title.add_theme_font_size_override("font_size", 20)
	box.add_child(_title)
	for pair: Array in [[_hp_label, _hp], [_morale_label, _morale]]:
		var row := HBoxContainer.new()
		var label: Label = pair[0]
		var bar: ProgressBar = pair[1]
		label.custom_minimum_size = Vector2(130, 0)
		row.add_child(label)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 14)
		row.add_child(bar)
		box.add_child(row)
	_morale.modulate = Color(1.0, 0.85, 0.35)
	box.add_child(_lines)


func attach(p_sim: Simulation, p_input: PlayerInput) -> void:
	sim = p_sim
	input = p_input
	refresh()


func refresh() -> void:
	if sim == null:
		return
	var ids := input.selection.ids
	_hp.visible = false
	_hp_label.visible = false
	_morale.visible = false
	_morale_label.visible = false
	if ids.size() == 1:
		_unit(ids[0])
	elif ids.size() > 1:
		_group(ids)
	elif input.selected_building != BuildingStore.NO_ID:
		_building(input.selected_building)
	else:
		_title.text = ""
		_lines.text = (
			tr("Nothing selected")
			+ "\n"
			+ tr("Left click or drag a box to select.")
			+ "\n"
			+ tr("Right click gives orders. F1: how to play.")
		)


func _bar(label: Label, bar: ProgressBar, text: String, value: int, most: int) -> void:
	label.visible = true
	bar.visible = true
	label.text = text
	bar.max_value = maxi(most, 1)
	bar.value = value


func _unit(id: int) -> void:
	var e := sim.entities
	var slot := id - 1
	var def := sim.economy.unit_defs[slot]
	_title.text = UiText.name_of(e.type_ids[slot])
	_bar(_hp_label, _hp, tr("HP %d/%d") % [e.hp[slot], e.max_hp[slot]], e.hp[slot], e.max_hp[slot])
	var lines := PackedStringArray()
	if def == null:
		_lines.text = ""
		return
	if sim.combat.enabled():
		if def.never_flees:
			lines.append(tr("Morale: never flees"))
		else:
			var morale := sim.combat.effective_morale(slot) / CombatSystem.MORALE_SCALE
			_bar(
				_morale_label,
				_morale,
				tr("Morale %d/%d") % [morale, def.morale],
				morale,
				def.morale
			)
	if def.damage > 0:
		var damage := def.damage + e.up_damage[slot]
		var text := tr("Damage %d (%s)") % [damage, UiText.damage_type(def.damage_type)]
		var reach := def.attack_range + e.up_range[slot]
		if reach > 0:
			text += " · " + tr("range %d") % reach
		lines.append(text)
	lines.append(
		(
			tr("Armor %d melee / %d pierce")
			% [def.armor_melee + e.up_armor_m[slot], def.armor_pierce + e.up_armor_p[slot]]
		)
	)
	lines.append(tr("Speed %.2f cells/s") % (def.speed_milli / 1000.0))
	lines.append(tr("Stance: %s") % UiText.stance(e.stance[slot]))
	var state := _state(slot)
	if not state.is_empty():
		lines.append(state)
	_lines.text = "\n".join(lines)


## What the unit is doing beyond walking: fleeing, wavering, hidden, carrying.
func _state(slot: int) -> String:
	var e := sim.entities
	if e.intents[slot] == EntityStore.Intent.FLEE:
		return tr("Fleeing!")
	if e.intents[slot] == EntityStore.Intent.RETREAT:
		return tr("Lithuanian retreat")
	if sim.combat.enabled() and sim.combat.wavering(slot):
		return tr("Wavering")
	if sim.combat.enabled() and sim.combat.is_hidden(slot + 1):
		return tr("Hidden in the forest")
	var eco := sim.economy
	if eco.enabled() and eco.carry[slot] > 0:
		return (
			tr("Carries %d %s") % [eco.carry[slot], UiText.resource(eco.carry_res[slot]).to_lower()]
		)
	return ""


func _group(ids: PackedInt32Array) -> void:
	var counts := {}
	for id in ids:
		var type := String(sim.entities.type_ids[id - 1])
		counts[type] = (counts.get(type, 0) as int) + 1
	var types := PackedStringArray(counts.keys())
	types.sort()
	var lines := PackedStringArray()
	for type in types:
		lines.append("%s × %d" % [UiText.name_of(StringName(type)), counts[type]])
	_title.text = tr("%d units") % ids.size()
	_lines.text = "\n".join(lines)


func _building(b: int) -> void:
	var store := sim.economy.buildings
	var s := b - 1
	_title.text = UiText.name_of(store.type_ids[s])
	_bar(
		_hp_label,
		_hp,
		tr("HP %d/%d") % [store.hp[s], store.max_hp[s]],
		store.hp[s],
		store.max_hp[s]
	)
	var lines := PackedStringArray()
	if store.done[s] == 0:
		lines.append(tr("Under construction: %d%%") % (store.progress[s] * 100 / store.work[s]))
	else:
		var q: Array = store.queues[s]
		if not q.is_empty():
			var first: StringName = q[0]
			var total := sim.economy.production.item_ticks(first)
			var pct := store.queue_ticks[s] * 100 / maxi(total, 1)
			lines.append(tr("In work: %s, %d%%") % [UiText.name_of(first), pct])
		if store.defs[s].pop_provided > 0:
			lines.append(tr("Houses %d") % store.defs[s].pop_provided)
		lines.append(tr("Right click: rally point"))
	_lines.text = "\n".join(lines)
