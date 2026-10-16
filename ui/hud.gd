class_name Hud
extends Control
## The in-game interface (M6): a top bar with resources, Power, population, age and game time;
## at the bottom the minimap, the card of what is selected and the order buttons; a line with
## what is being placed and why it cannot stand; and the game menu. P pauses without the menu,
## Esc (with nothing to cancel) or F10 opens it. Lets clicks through to the map wherever it
## draws nothing. The top bar shows each value as an icon and a number (names in the tooltips).
## In a skirmish the Advisor gives a new player step-by-step hints; F1 opens the
## «How to play» page (HelpPanel), which the game menu opens too.

const ICONS: Array[String] = ["food", "wood", "iron", "silver"]
const ICON_SIZE := 30

var sim: Simulation
var input: PlayerInput
var clock: SimClock
var player := 1

var minimap := Minimap.new()
var card := UnitCard.new()
var commands := CommandPanel.new()
var menu := PauseMenu.new()
var advisor := Advisor.new()
var help := HelpPanel.new()

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
	add_child(advisor)
	add_child(menu)
	add_child(help)
	menu.resumed.connect(refresh)
	menu.help_requested.connect(help.open)
	menu.hints_changed.connect(_on_hints_changed)


func _build_top() -> void:
	_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top.mouse_filter = Control.MOUSE_FILTER_STOP
	_top.theme_type_variation = &"HudBar"
	add_child(_top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	_top.add_child(row)
	for r in 4:
		var label := Label.new()
		_resources.append(label)
		row.add_child(_with_icon(ICONS[r], label))
	var icons: Array[String] = ["power", "population", "age", "time"]
	var labels: Array[Label] = [_power, _population, _age, _time]
	for i in labels.size():
		row.add_child(_with_icon(icons[i], labels[i]))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_menu_button.focus_mode = Control.FOCUS_NONE
	_menu_button.pressed.connect(menu.open)
	row.add_child(_menu_button)


## An icon from ui/icons before `label`; the pair shows the label's tooltip.
static func _with_icon(icon: String, label: Label) -> HBoxContainer:
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 6)
	pair.mouse_filter = Control.MOUSE_FILTER_PASS
	var tex := TextureRect.new()
	tex.texture = load("res://ui/icons/%s.svg" % icon)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	tex.mouse_filter = Control.MOUSE_FILTER_PASS
	pair.add_child(tex)
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.add_theme_font_size_override("font_size", 22)
	pair.add_child(label)
	# The pair follows the label's visibility (Power is hidden early in a mission).
	label.visibility_changed.connect(func() -> void: pair.visible = label.visible)
	return pair


func _build_bottom() -> void:
	_bottom_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bottom_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bottom_panel)
	_bottom.add_theme_constant_override("separation", 8)
	_bottom_panel.add_child(_bottom)
	minimap.custom_minimum_size = Vector2(320, 180)
	var well := PanelContainer.new()
	well.theme_type_variation = &"Well"
	well.add_child(minimap)
	_bottom.add_child(well)
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
	advisor.attach(sim, input, player)
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
	elif key.physical_keycode == KEY_F1 and not help.visible:
		help.open(true)
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
			_resources[r].text = str(state.stock[r])
			_resources[r].tooltip_text = "%s\n%s" % [UiText.resource(r), UiText.resource_help(r)]
		# A mission shows Power only once it has told the player about it (ВКЛ 1, trigger 2.3).
		_power.visible = sim.mission == null or sim.mission.flags.has("show_power")
		_power.text = str(state.power_points())
		_power.tooltip_text = (
			UiText.resource(-1)
			+ "\n"
			+ UiText.resource_help(-1)
			+ "\n"
			+ tr("+%s a second") % _power_income()
		)
		_population.text = "%d/%d" % [state.pop_used(), eco.pop_cap(player)]
		_population.tooltip_text = tr("Population %d/%d") % [state.pop_used(), eco.pop_cap(player)]
		var age := eco.db.age_by_index(state.age)
		_age.text = UiText.name_of(age.id) if age != null else ""
		_time.text = UiText.clock(sim.tick)
	_placing.text = _placing_text()
	card.refresh()
	commands.refresh()
	advisor.refresh()


func _on_hints_changed() -> void:
	if GameSettings.hints:
		advisor.step = 0
	advisor.refresh()


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
	if input.taking_apart:
		var why := ""
		if input.take_apart_fail:
			why = " · " + tr("The last capital cannot be taken apart")
		return tr("Take apart: click your building") + why + "\n" + tr("Esc or right click cancel")
	if input.placing == null:
		return ""
	var cost := sim.economy.placement.building_cost(player, input.placing)
	var text := "%s: %s" % [UiText.name_of(input.placing.id), UiText.cost(cost)]
	if input.place_fail != EconomySystem.Fail.OK:
		text += " · " + UiText.fail(input.place_fail)
	return text + "\n" + tr("B next, F turn, Shift keep placing, Esc or right click cancel")
