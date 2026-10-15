class_name Hud
extends Control
## The in-game interface (M6): a top bar with resources, Power, population, age and game time;
## at the bottom the minimap, the card of what is selected and the order buttons; a line with
## what is being placed and why it cannot stand; and the game menu. P pauses without the menu,
## Esc (with nothing to cancel) or F10 opens it. Lets clicks through to the map wherever it
## draws nothing.

var sim: Simulation
var input: PlayerInput
var clock: SimClock
var player := 1

var minimap := Minimap.new()
var card := UnitCard.new()
var commands := CommandPanel.new()
var menu := PauseMenu.new()

var _top := PanelContainer.new()
var _resources: Array[Label] = []
var _power := Label.new()
var _population := Label.new()
var _age := Label.new()
var _time := Label.new()
var _menu_button := Button.new()
var _placing := Label.new()
var _paused := Label.new()
var _bottom_panel := PanelContainer.new()
var _bottom := HBoxContainer.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top()
	_build_bottom()
	_placing.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_placing.position.y = 52
	_placing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placing.add_theme_color_override("font_outline_color", Color.BLACK)
	_placing.add_theme_constant_override("outline_size", 4)
	add_child(_placing)
	_paused.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_paused.add_theme_font_size_override("font_size", 40)
	_paused.visible = false
	add_child(_paused)
	add_child(menu)
	menu.resumed.connect(refresh)


func _build_top() -> void:
	_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_top.add_child(row)
	for r in 4:
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		_resources.append(label)
		row.add_child(label)
	for label: Label in [_power, _population, _age, _time]:
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_menu_button.focus_mode = Control.FOCUS_NONE
	_menu_button.pressed.connect(menu.open)
	row.add_child(_menu_button)


func _build_bottom() -> void:
	_bottom_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bottom_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bottom_panel)
	_bottom.add_theme_constant_override("separation", 8)
	_bottom_panel.add_child(_bottom)
	minimap.custom_minimum_size = Vector2(320, 180)
	_bottom.add_child(minimap)
	card.size_flags_vertical = Control.SIZE_FILL
	_bottom.add_child(card)
	commands.size_flags_vertical = Control.SIZE_FILL
	commands.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom.add_child(commands)


func attach(
	p_sim: Simulation, p_clock: SimClock, p_input: PlayerInput, camera: RtsCamera, p_player: int
) -> void:
	sim = p_sim
	clock = p_clock
	input = p_input
	player = p_player
	minimap.attach(sim, clock, camera, player)
	card.attach(sim, input)
	commands.attach(sim, input)
	input.selection.changed.connect(refresh)
	input.economy_changed.connect(refresh)
	input.formation_changed.connect(func(_k: Formation.Kind) -> void: refresh())
	input.menu_requested.connect(menu.open)
	clock.ticked.connect(_on_ticked)
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and sim != null:
		refresh()


func _on_ticked(tick: int) -> void:
	if tick % 2 == 0:
		refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or menu.visible:
		return
	if key.physical_keycode == KEY_P or key.physical_keycode == KEY_PAUSE:
		toggle_pause()
		get_viewport().set_input_as_handled()


## Pauses the game without the menu (P), or resumes it.
func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	_paused.visible = get_tree().paused
	_paused.text = tr("Paused (P)")


func refresh() -> void:
	if sim == null:
		return
	_menu_button.text = tr("Menu (F10)")
	var eco := sim.economy
	var state := eco.player(player)
	_top.visible = state != null
	if state != null:
		for r in 4:
			_resources[r].text = "%s %d" % [UiText.resource(r), state.stock[r]]
			_resources[r].tooltip_text = UiText.resource(r)
		_power.text = "%s %d" % [UiText.resource(-1), state.power_points()]
		_power.tooltip_text = (
			tr("Power: from places of power and shrines")
			+ "\n"
			+ tr("+%s a second") % _power_income()
		)
		_population.text = tr("Population %d/%d") % [state.pop_used(), eco.pop_cap(player)]
		var age := eco.db.age_by_index(state.age)
		_age.text = UiText.name_of(age.id) if age != null else ""
		_time.text = UiText.clock(sim.tick)
	_placing.text = _placing_text()
	card.refresh()
	commands.refresh()


## Сила a second the player's shrines give now, as "1.2".
func _power_income() -> String:
	var places := sim.magic.places
	var milli := 0
	for i in places.count():
		if places.holders[i] == player:
			milli += places.rate_milli(i)
	return "%.1f" % (milli / 1000.0)


func _placing_text() -> String:
	if input.casting != null:
		return (
			"%s: %s" % [UiText.name_of(input.casting.id), tr("click where to cast it")]
			+ "\n"
			+ tr("Esc or right click cancel")
		)
	if input.placing == null:
		return ""
	var cost := sim.economy.placement.building_cost(player, input.placing)
	var text := "%s: %s" % [UiText.name_of(input.placing.id), UiText.cost(cost)]
	if input.place_fail != EconomySystem.Fail.OK:
		text += " · " + UiText.fail(input.place_fail)
	return text + "\n" + tr("B next, F turn, Shift keep placing, Esc or right click cancel")
