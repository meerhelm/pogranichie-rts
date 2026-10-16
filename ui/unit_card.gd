class_name UnitCard
extends PanelContainer
## What is selected (M6): one unit with its HP, morale, damage, armor, range, speed, stance and
## state; several units as a count per type; or the selected building with its HP,
## construction and what it is training or researching. Refreshed by the HUD after ticks.
## Anything else the player clicks (PlayerInput.look) shows here too, without orders: another
## side's or a wild unit, another side's building, a deposit or carcass with what is left of
## what it held, a forest cell, a place of power.

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
	elif input.look == PlayerInput.Look.UNIT:
		_unit(input.look_ref)
	elif input.look == PlayerInput.Look.BUILDING:
		_building(input.look_ref)
	elif input.look == PlayerInput.Look.NODE:
		_node(input.look_ref)
	elif input.look == PlayerInput.Look.FOREST:
		_forest(input.look_ref)
	elif input.look == PlayerInput.Look.PLACE:
		_place(input.look_ref)
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
	if e.owners[slot] != input.player:
		lines.append(_owner(e.owners[slot]))
	if def == null:
		_lines.text = "\n".join(lines)
		return
	if def.food_yield > 0 and e.owners[slot] == 0:
		lines.append(tr("Gives %d food when hunted") % def.food_yield)
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
	var own := store.owners[s] == input.player
	if not own:
		lines.append(_owner(store.owners[s]))
	if store.dismantling[s] == 1:
		var taken := store.dismantle_total[s] - store.dismantle_left[s]
		lines.append(tr("Being taken apart: %d%%") % (taken * 100 / store.dismantle_total[s]))
		lines.append(tr("Gives back: %s") % UiText.cost(sim.economy.construction.salvage(b)))
	elif store.done[s] == 0:
		lines.append(tr("Under construction: %d%%") % (store.progress[s] * 100 / store.work[s]))
	elif not own:
		_resource_lines(b, lines)
	else:
		var q: Array = store.queues[s]
		if not q.is_empty():
			var first: StringName = q[0]
			var total := sim.economy.production.item_ticks(first)
			var pct := store.queue_ticks[s] * 100 / maxi(total, 1)
			lines.append(tr("In work: %s, %d%%") % [UiText.name_of(first), pct])
		if store.defs[s].pop_provided > 0:
			lines.append(tr("Houses %d") % store.defs[s].pop_provided)
		_resource_lines(b, lines)
		lines.append(tr("Right click: rally point"))
	_lines.text = "\n".join(lines)


## What a finished building gives or takes: a field's food left, a hive's endless food, the
## resources a storehouse takes in.
func _resource_lines(b: int, lines: PackedStringArray) -> void:
	var eco := sim.economy
	var s := b - 1
	var def := eco.buildings.defs[s]
	if def.base_id == &"farm":
		var state := eco.player(eco.buildings.owners[s])
		var bonus := state.farm_food_bonus if state != null else 0
		var full := def.param(&"food_capacity") * (1000 + bonus) / 1000
		lines.append(tr("Food left %d of %d") % [eco.buildings.food[s], full])
	elif eco.building_source(eco.buildings.owners[s], b) == ResourceNodes.Source.BORT:
		lines.append(tr("Food: never runs out"))
	var takes := PackedStringArray()
	for r in 4:
		if def.accepts.has(EconomySystem.RESOURCE_NAMES[r]):
			takes.append(UiText.resource(r).to_lower())
	if not takes.is_empty():
		lines.append(tr("Takes in: %s") % ", ".join(takes))


## Whose it is: a faction (and the player's number), or nobody's for wild things.
func _owner(p: int) -> String:
	var state := sim.economy.player(p)
	if p == 0 or state == null:
		return tr("Wild, nobody's")
	return tr("Player %d, %s") % [p, UiText.name_of(state.faction)]


## A deposit, carcass or salvage: what it gives and how much of what it held is left.
func _node(n: int) -> void:
	var nodes := sim.economy.nodes
	var s := n - 1
	var source := nodes.sources[s]
	var res := ResourceNodes.SOURCE_RESOURCE[source]
	_title.text = UiText.node_name(source)
	if source == ResourceNodes.Source.HUNT and sim.entities.type_ids.size() >= nodes.from_unit[s]:
		var animal := sim.entities.type_ids[nodes.from_unit[s] - 1]
		_title.text = "%s: %s" % [_title.text, UiText.name_of(animal)]
	var left := nodes.amounts[s]
	var full := maxi(nodes.initial[s], left)
	_bar(_hp_label, _hp, "%s %d/%d" % [UiText.resource(res), left, full], left, full)
	_lines.text = tr("Peasants gather it (right click).")


## A forest cell: the wood left in it.
func _forest(cell: int) -> void:
	var left := sim.economy.nodes.wood[cell]
	var full := maxi(sim.economy.rules.tree_wood, left)
	_title.text = tr("Forest")
	var wood := UiText.resource(EconomySystem.WOOD)
	_bar(_hp_label, _hp, "%s %d/%d" % [wood, left, full], left, full)
	_lines.text = tr("Peasants fell it for wood (right click).")


## A place of power: who holds it and whether a shrine stands on it.
func _place(i: int) -> void:
	var places := sim.magic.places
	_title.text = UiText.name_of(places.defs[i].id)
	var lines := PackedStringArray()
	lines.append(tr("Place of power"))
	if places.holders[i] == 0:
		lines.append(tr("Nobody holds it"))
	else:
		lines.append(tr("Held by: %s") % _owner(places.holders[i]))
	if places.shrines[i] != BuildingStore.NO_ID:
		lines.append(tr("A shrine stands on it"))
	lines.append(tr("Power x%.1f") % (places.defs[i].power_permille / 1000.0))
	_lines.text = "\n".join(lines)
