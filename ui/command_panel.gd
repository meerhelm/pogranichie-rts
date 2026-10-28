class_name CommandPanel
extends PanelContainer
## Orders for what is selected (M6), the same as the hotkeys: for units stop, stances,
## formations and the faction moves they have; for peasants the buildings they can lay; for a
## building what it can train or research, with the queue (click an item to cancel it).
## Every button is a picture with its name under it (IconButton, icons in IconDB) and a rich
## tooltip (Tips): the price, what it is for, what it gives and why it cannot be had now.
## Buttons are rebuilt when the selection changes and their state refreshed after ticks.
## Casters get a button per spell (M7) with its Сила, cooldown and why it cannot be cast now.

## Buildings in the order a player needs them: economy first, then troops, walls and the rest.
const BUILD_ORDER: Array[StringName] = [
	&"house",
	&"farm",
	&"",
	&"granary",
	&"lumber_yard",
	&"mine",
	&"barracks",
	&"range",
	&"stable",
	&"siege_workshop",
	&"smithy",
	&"temple",
	&"shrine",
	&"market",
	&"castle",
	&"tower",
	&"palisade",
	&"gate"
]

var sim: Simulation
var input: PlayerInput

var _box := VBoxContainer.new()
var _orders := GridContainer.new()
var _build := GridContainer.new()
var _queue := HBoxContainer.new()
## What the buttons were built for, to rebuild only when it changes.
var _context := ""
## Queue buttons by item and build buttons by building id, to refresh their state.
var _item_buttons: Dictionary[StringName, IconButton] = {}
var _build_buttons: Dictionary[StringName, IconButton] = {}
var _spell_buttons: Dictionary[StringName, IconButton] = {}


func _ready() -> void:
	# Room for three rows, so the panel keeps its height whatever is selected.
	custom_minimum_size = Vector2(520, 3 * IconButton.SIZE.y + 2 * 4 + 24)
	add_child(_box)
	_box.add_theme_constant_override("separation", 6)
	for grid: GridContainer in [_orders, _build]:
		grid.columns = 10
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
	_queue.add_theme_constant_override("separation", 4)
	_box.add_child(_orders)
	_box.add_child(_build)
	_box.add_child(_queue)
	resized.connect(_fit_columns)


## As many columns as the panel holds.
func _fit_columns() -> void:
	var room := size.x - 24.0
	var cols := maxi(4, int(room / (IconButton.SIZE.x + 4.0)))
	_orders.columns = cols
	_build.columns = cols


func attach(p_sim: Simulation, p_input: PlayerInput) -> void:
	sim = p_sim
	input = p_input
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_context = ""
		refresh()


func refresh() -> void:
	if sim == null:
		return
	var context := _context_key()
	if context != _context:
		_context = context
		_rebuild()
	_refresh_state()


func _context_key() -> String:
	if not input.selection.ids.is_empty():
		var key := "units"  # notr
		for id in input.selection.ids:
			key += ",%d" % id
		return key
	if input.selected_building != BuildingStore.NO_ID:
		var b := input.selected_building
		var store := sim.economy.buildings
		var state := sim.economy.player(input.player)
		return (
			"building,%d,%d,%d,%d,%d"  # notr
			% [b, store.done[b - 1], store.queues[b - 1].size(), state.age, state.techs.size()]
		)
	return ""


func _clear() -> void:
	for box: Container in [_orders, _build, _queue]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	_item_buttons.clear()
	_build_buttons.clear()
	_spell_buttons.clear()


func _rebuild() -> void:
	_clear()
	if not input.selection.ids.is_empty():
		_unit_orders()
	elif input.selected_building != BuildingStore.NO_ID:
		_building_orders()


func _button(
	box: Container, icon: Texture2D, caption: String, tip: Tips.Tip, action: Callable
) -> IconButton:
	var b := IconButton.new(icon, caption)
	_set_tip(b, tip)
	b.pressed.connect(action)
	box.add_child(b)
	return b


static func _set_tip(b: IconButton, tip: Tips.Tip) -> void:
	b.tooltip_text = tip.plain_text()
	b.rich_tip = tip.bbcode()


## An order button: icon (ui/icons/orders), name, key and what it does.
func _order(icon: String, title: String, key: String, what: String, action: Callable) -> IconButton:
	var b := _button(_orders, IconDB.order(icon), title, Tips.order(icon, title, key, what), action)
	b.hotkey = key
	return b


func _unit_orders() -> void:
	_order("stop", tr("Stop"), "H", tr("Stop what they are doing and stand."), input.order_stop)
	var stances := [
		[
			EntityStore.Stance.AGGRESSIVE,
			"Z",
			"aggressive",
			tr("Attack any enemy they see and chase it.")
		],
		[
			EntityStore.Stance.DEFENSIVE,
			"X",
			"defensive",
			tr("Fight enemies who come near, then come back.")
		],
		[
			EntityStore.Stance.STAND,
			"C",
			"stand_ground",
			tr("Hold this spot: fight only what comes within reach.")
		],
	]
	for row: Array in stances:
		var s: EntityStore.Stance = row[0]
		var key: String = row[1]
		var icon: String = row[2]
		var what: String = row[3]
		_order(icon, UiText.stance(s), key, what, input.order_stance.bind(s))
	var formations := [
		[Formation.Kind.LINE, "Q", "line", tr("Walk and stand in a broad line.")],
		[
			Formation.Kind.COLUMN,
			"E",
			"column",
			tr("Walk in a narrow column, for roads and the forest.")
		],
		[
			Formation.Kind.WEDGE,
			"R",
			"wedge",
			tr("Form a wedge with its point to the front, for the charge.")
		],
	]
	for row: Array in formations:
		var k: Formation.Kind = row[0]
		var key: String = row[1]
		var icon: String = row[2]
		var what: String = row[3]
		var title := UiText.formation(k)
		var b := _order(icon, title, key, what, input.set_formation.bind(k))
		b.tooltip_text = tr("Formation: %s (%s)") % [title, key] + "\n" + what
	var any_flags := 0
	for id in input.selection.ids:
		if sim.combat.enabled():
			any_flags |= sim.combat.flags[id - 1]
	if any_flags & CombatSystem.F_RETREAT:
		var feigned := sim.mission != null and sim.mission.swiecino.on
		_order(
			"retreat",
			tr("Fall back") if feigned else tr("Lithuanian retreat"),
			"T",
			(
				tr("Give way before the enemy and lead him on, then turn on the chasers.")
				if feigned
				else tr("Flee from the enemy at full speed, then turn on the chasers.")
			),
			input.order_kind.bind(SimCommand.Kind.RETREAT)
		)
		_order(
			"turn",
			tr("Turn around"),
			"G",
			tr("Turn and face the chasers at once."),
			input.order_kind.bind(SimCommand.Kind.TURN)
		)
	if any_flags & CombatSystem.F_DISMOUNT:
		_order(
			"dismount",
			tr("Dismount"),
			"V",
			tr("Get off the horse and fight on foot: more armor, the speed of foot soldiers."),
			input.order_kind.bind(SimCommand.Kind.DISMOUNT)
		)
	if _wagons_selected() >= 2:
		_order(
			"tabor",
			tr("Tabor"),
			"U",
			(
				tr("Draw the wagons up in a ring.")
				+ " "
				+ tr("Foot soldiers and shooters inside get more armor and fear no flank attacks.")
			),
			input.order_kind.bind(SimCommand.Kind.TABOR)
		)
	if _fugitives_selected():
		_order(
			"dismount",
			tr("Lead the horses / mount"),
			"V",
			tr("Get down and lead the horses at a walk: quiet, and the horses rest. Again: ride."),
			input.order_kind.bind(SimCommand.Kind.DISMOUNT)
		)
	for spell in input.spells():
		var b := _button(
			_orders,
			IconDB.of(spell.id),
			UiText.name_of(spell.id),
			Tips.spell(spell),
			input.start_casting.bind(spell)
		)
		_spell_buttons[spell.id] = b
	if input.builders().is_empty():
		return
	if not input.peasants().is_empty():
		_take_apart_order()
	var p := input.player
	for def in _in_build_order(input.buildable()):
		var b := _button(
			_build,
			IconDB.of(def.id),
			UiText.name_of(def.id),
			Tips.building(def, sim.economy, p),
			input.start_placing.bind(def)
		)
		_build_buttons[def.id] = b


func _take_apart_order() -> void:
	_order(
		"take_apart",
		tr("Take apart"),
		"Y",
		(
			tr("Then click your building.")
			+ " "
			+ (
				tr("Peasants take it apart and carry %d%% of its price to storage.")
				% (sim.economy.rules.dismantle_refund_permille / 10)
			)
		),
		input.start_taking_apart
	)


static func _in_build_order(defs: Array[BuildingDef]) -> Array[BuildingDef]:
	var out := defs.duplicate()
	out.sort_custom(
		func(a: BuildingDef, b: BuildingDef) -> bool:
			var ia := BUILD_ORDER.find(a.base_id)
			var ib := BUILD_ORDER.find(b.base_id)
			ia = ia if ia >= 0 else BUILD_ORDER.size()
			ib = ib if ib >= 0 else BUILD_ORDER.size()
			return ia < ib if ia != ib else String(a.id) < String(b.id)
	)
	return out


func _building_orders() -> void:
	var b := input.selected_building
	var store := sim.economy.buildings
	if store.done[b - 1] == 0:
		return
	var items := input.queue_items()
	for i in items.size():
		var item := items[i]
		var key := PlayerInput.QUEUE_KEYS[i] if i < PlayerInput.QUEUE_KEYS.size() else KEY_NONE
		var button := _button(
			_orders,
			IconDB.of(item),
			UiText.name_of(item),
			Tips.Tip.new(),
			input.queue_item.bind(item)
		)
		button.hotkey = OS.get_keycode_string(key) if key != KEY_NONE else ""
		_item_buttons[item] = button
	var q: Array = store.queues[b - 1]
	for i in q.size():
		var item: StringName = q[i]
		var cancel := IconButton.new(IconDB.of(item), UiText.name_of(item), true)
		cancel.tooltip_text = tr("Cancel %s") % UiText.name_of(item)
		cancel.pressed.connect(input.cancel_item.bind(i))
		_queue.add_child(cancel)


## Prices and availability change with the stock, so these refresh after every tick.
func _refresh_state() -> void:
	var p := input.player
	var eco := sim.economy
	var state := eco.player(p)
	if state == null:
		return
	for id: StringName in _build_buttons:
		var def := eco.db.building(id)
		var button := _build_buttons[id]
		button.disabled = not state.can_pay(eco.placement.building_cost(p, def))
		var fail := UiText.fail(EconomySystem.Fail.COST) if button.disabled else ""
		_set_tip(button, Tips.building(def, eco, p, fail))
	_refresh_spells()
	var b := input.selected_building
	if b == BuildingStore.NO_ID:
		return
	var q: Array = eco.buildings.queues[b - 1]
	if not q.is_empty() and _queue.get_child_count() > 0:
		var first: StringName = q[0]
		var total := maxi(eco.production.item_ticks(first, b), 1)
		(_queue.get_child(0) as IconButton).progress = (
			eco.buildings.queue_ticks[b - 1] / float(total)
		)
	for item: StringName in _item_buttons:
		var button := _item_buttons[item]
		var reason := eco.production.can_queue(p, b, item)
		button.disabled = reason != EconomySystem.Fail.OK
		var fail := UiText.fail(reason) if button.disabled else ""
		var cost := eco.production.item_cost(p, b, item)
		var ticks := eco.production.item_ticks(item, b)
		var tip: Tips.Tip
		if item == EconomyProduction.CHAPEL:
			var bdef := eco.buildings.defs[b - 1]
			tip = Tips.chapel(bdef, cost, ticks, fail, button.hotkey)
		elif eco.db.unit(item) != null:
			tip = Tips.unit(eco.db.unit(item), cost, ticks, fail, button.hotkey)
		elif eco.db.techs.has(item):
			tip = Tips.tech(eco.db.techs[item], cost, ticks, fail, button.hotkey)
		else:
			var age: AgeDef = eco.db.ages.get(item)
			tip = Tips.age(age, eco.db, state.faction, cost, ticks, fail, button.hotkey)
		_set_tip(button, tip)


## A spell can be cast if any selected caster may; otherwise the first caster's reason shows.
func _refresh_spells() -> void:
	var magic := sim.magic
	for id: StringName in _spell_buttons:
		var spell := magic.spells[magic.spell_index[id]]
		var reason := MagicSystem.Cast.UNKNOWN
		var ready_in := 0
		for caster in input.casters_of(spell):
			var r := magic.can_cast(input.player, caster, id)
			if r == MagicSystem.Cast.OK or reason == MagicSystem.Cast.UNKNOWN:
				reason = r
			if r == MagicSystem.Cast.COOLDOWN:
				var left := magic.cooldown_ticks(caster, id)
				ready_in = left if ready_in == 0 else mini(ready_in, left)
			if r == MagicSystem.Cast.OK:
				break
		var button := _spell_buttons[id]
		button.disabled = reason != MagicSystem.Cast.OK
		var fail := ""
		if button.disabled:
			fail = UiText.cast_fail(reason)
			if reason == MagicSystem.Cast.COOLDOWN:
				fail += " " + tr("(%d s)") % ceili(ready_in / float(Fixed.TICKS_PER_SECOND))
		_set_tip(button, Tips.spell(spell, fail))


## How many selected units are wagons that make a tabor.
func _wagons_selected() -> int:
	var n := 0
	for id in input.selection.ids:
		var def := sim.combat.defs[id - 1] if sim.combat.enabled() else null
		if def != null and def.param(&"tabor_wagons") > 0:
			n += 1
	return n


## ВКЛ 6: whether a selected unit is one of the fugitives (who lead their horses with V).
func _fugitives_selected() -> bool:
	if sim.mission == null:
		return false
	for id in input.selection.ids:
		if sim.mission.stealth.stamina.has(id):
			return true
	return false
