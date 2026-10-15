class_name CommandPanel
extends PanelContainer
## Orders for what is selected (M6), the same as the hotkeys: for units stop, stances,
## formations and the faction moves they have; for peasants the buildings they can lay; for a
## building what it can train or research, with the queue (click an item to cancel it).
## Every button's tooltip names the order, its key and, for buildings and queue items, the price
## and why it cannot be had now. Buttons are rebuilt when the selection changes and their state
## refreshed after ticks.

const BUTTON_SIZE := Vector2(118, 34)

var sim: Simulation
var input: PlayerInput

var _box := VBoxContainer.new()
var _orders := GridContainer.new()
var _build := GridContainer.new()
var _queue := HBoxContainer.new()
## What the buttons were built for, to rebuild only when it changes.
var _context := ""
## Queue buttons by item and build buttons by building id, to refresh their state.
var _item_buttons: Dictionary[StringName, Button] = {}
var _build_buttons: Dictionary[StringName, Button] = {}


func _ready() -> void:
	custom_minimum_size = Vector2(520, 0)
	add_child(_box)
	_orders.columns = 4
	_build.columns = 4
	_box.add_child(_orders)
	_box.add_child(_build)
	_box.add_child(_queue)


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


func _rebuild() -> void:
	_clear()
	if not input.selection.ids.is_empty():
		_unit_orders()
	elif input.selected_building != BuildingStore.NO_ID:
		_building_orders()


func _button(box: Container, text: String, tip: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.custom_minimum_size = BUTTON_SIZE
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	box.add_child(b)
	return b


func _unit_orders() -> void:
	_button(_orders, tr("Stop"), tr("Stop (H)"), input.order_stop)
	var stances := [
		[EntityStore.Stance.AGGRESSIVE, "Z"],
		[EntityStore.Stance.DEFENSIVE, "X"],
		[EntityStore.Stance.STAND, "C"],
	]
	for pair: Array in stances:
		var s: EntityStore.Stance = pair[0]
		var name := UiText.stance(s)
		_button(_orders, name, "%s (%s)" % [name, pair[1]], input.order_stance.bind(s))
	var formations := [
		[Formation.Kind.LINE, "Q"], [Formation.Kind.COLUMN, "E"], [Formation.Kind.WEDGE, "R"]
	]
	for pair: Array in formations:
		var k: Formation.Kind = pair[0]
		var name := UiText.formation(k)
		_button(
			_orders, name, tr("Formation: %s (%s)") % [name, pair[1]], input.set_formation.bind(k)
		)
	var any_flags := 0
	for id in input.selection.ids:
		if sim.combat.enabled():
			any_flags |= sim.combat.flags[id - 1]
	if any_flags & CombatSystem.F_RETREAT:
		var retreat := tr("Lithuanian retreat")
		_button(_orders, retreat, retreat + " (T)", input.order_kind.bind(SimCommand.Kind.RETREAT))
		var turn := tr("Turn around")
		_button(_orders, turn, turn + " (G)", input.order_kind.bind(SimCommand.Kind.TURN))
	if any_flags & CombatSystem.F_DISMOUNT:
		var dismount := tr("Dismount")
		_button(
			_orders, dismount, dismount + " (V)", input.order_kind.bind(SimCommand.Kind.DISMOUNT)
		)
	if input.peasants().is_empty():
		return
	for def in input.buildable():
		var b := _button(_build, UiText.name_of(def.id), "", input.start_placing.bind(def))
		_build_buttons[def.id] = b


func _building_orders() -> void:
	var b := input.selected_building
	var store := sim.economy.buildings
	if store.done[b - 1] == 0:
		return
	var items := input.queue_items()
	for i in items.size():
		var item := items[i]
		var key := PlayerInput.QUEUE_KEYS[i] if i < PlayerInput.QUEUE_KEYS.size() else KEY_NONE
		var button := _button(_orders, UiText.name_of(item), "", input.queue_item.bind(item))
		button.set_meta(&"key", OS.get_keycode_string(key) if key != KEY_NONE else "")
		_item_buttons[item] = button
	var q: Array = store.queues[b - 1]
	for i in q.size():
		var item: StringName = q[i]
		var cancel := _button(
			_queue,
			UiText.name_of(item),
			tr("Cancel %s") % UiText.name_of(item),
			input.cancel_item.bind(i)
		)
		cancel.custom_minimum_size = Vector2(90, 28)


## Prices and availability change with the stock, so these refresh after every tick.
func _refresh_state() -> void:
	var p := input.player
	var eco := sim.economy
	var state := eco.player(p)
	if state == null:
		return
	for id: StringName in _build_buttons:
		var def := eco.db.building(id)
		var cost := eco.placement.building_cost(p, def)
		var button := _build_buttons[id]
		button.disabled = not state.can_pay(cost)
		var tip := "%s\n%s" % [UiText.name_of(id), UiText.cost(cost)]
		if button.disabled:
			tip += "\n" + UiText.fail(EconomySystem.Fail.COST)
		button.tooltip_text = tip
	var b := input.selected_building
	if b == BuildingStore.NO_ID:
		return
	for item: StringName in _item_buttons:
		var button := _item_buttons[item]
		var fail := eco.production.can_queue(p, b, item)
		button.disabled = fail != EconomySystem.Fail.OK
		var key: String = button.get_meta(&"key", "")
		var tip := UiText.name_of(item)
		if not key.is_empty():
			tip += " (%s)" % key
		tip += "\n" + UiText.cost(eco.production.item_cost(p, b, item))
		if button.disabled:
			tip += "\n" + UiText.fail(fail)
		button.tooltip_text = tip
