class_name Hud
extends Control
## The in-game interface (M6, laid out in hud.tscn): a top bar with resources, Power, population,
## age and game time; at the bottom the minimap, the card of what is selected and the order buttons;
## a line with what is being placed and why it cannot stand; and the game menu. P pauses without the
## menu, Esc (with nothing to cancel) or F10 opens it. Lets clicks through to the map wherever it
## draws nothing. The top bar shows each value as an icon and a number (names in the tooltips). In a
## skirmish the Advisor gives a new player step-by-step hints; F1 opens the «How to play» page
## (HelpPanel), which the game menu opens too. A button by the menu sets the game speed: 1x, 2x, 4x,
## 8x (click or + goes up, right click or - goes down).

## Game speeds the speed button steps through, as multipliers.
const SPEEDS: Array[int] = [1, 2, 4, 8]
## How many times faster than the sim's own 20 ticks a second «1x» runs (Valentin 2026-10-17:
## the game felt slow, «1x» is now what was 2x). The button still shows 1x, 2x, 4x, 8x.
const BASE_SPEED := 2

var sim: Simulation
var input: PlayerInput
var clock: SimClock
var player := 1

@onready var minimap: Minimap = %Minimap
@onready var card: UnitCard = %Card
@onready var commands: CommandPanel = %Commands
@onready var menu: PauseMenu = %Menu
@onready var advisor: Advisor = %Advisor
@onready var help: HelpPanel = %Help

@onready var _top: PanelContainer = %Top
@onready var _resources: Array[Label] = [
	$Top/Row/Food/Value, $Top/Row/Wood/Value, $Top/Row/Iron/Value, $Top/Row/Silver/Value
]
@onready var _power: Label = $Top/Row/Power/Value
@onready var _population: Label = $Top/Row/Population/Value
@onready var _age: Label = $Top/Row/Age/Value
@onready var _time: Label = $Top/Row/Time/Value
@onready var _menu_button: Button = %MenuButton
@onready var _speed_button: Button = %SpeedButton
@onready var _placing: Label = %Placing
@onready var _paused: Label = %Paused
@onready var _bottom_panel: PanelContainer = %BottomPanel
@onready var _bottom: HBoxContainer = %Bottom


func _ready() -> void:
	# Power's icon hides with its number (Power is hidden early in a mission).
	_power.visibility_changed.connect(_sync_power_icon)
	_speed_button.gui_input.connect(_on_speed_input)
	_menu_button.pressed.connect(menu.open)
	menu.resumed.connect(refresh)
	menu.help_requested.connect(help.open)
	menu.hints_changed.connect(_on_hints_changed)


func _sync_power_icon() -> void:
	(_power.get_parent() as Control).visible = _power.visible


func attach(
	p_sim: Simulation, p_clock: SimClock, p_input: PlayerInput, camera: RtsCamera, p_player: int
) -> void:
	sim = p_sim
	clock = p_clock
	clock.speed_permille = BASE_SPEED * 1000
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
	clock.advanced.connect(_on_advanced)
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and sim != null:
		refresh()


## Once a frame after its ticks; refreshes at most every second tick, as before 8x.
func _on_advanced(tick: int, steps: int) -> void:
	if tick / 2 != (tick - steps) / 2:
		refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or menu.visible:
		return
	if key.physical_keycode == KEY_P or key.physical_keycode == KEY_PAUSE:
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif key.physical_keycode in [KEY_EQUAL, KEY_KP_ADD]:
		step_speed(1)
		get_viewport().set_input_as_handled()
	elif key.physical_keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
		step_speed(-1)
		get_viewport().set_input_as_handled()
	elif key.physical_keycode == KEY_F1 and not help.visible:
		help.open(true)
		get_viewport().set_input_as_handled()


## Pauses the game without the menu (P), or resumes it.
func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	_paused.visible = get_tree().paused
	_paused.text = tr("Paused (P)")


## The game speed as a multiplier: 1, 2, 4 or 8.
func speed() -> int:
	return clock.speed_permille / (BASE_SPEED * 1000) if clock != null else 1


## Sets the game speed to the next (`dir` 1) or previous (-1) of SPEEDS, wrapping around.
func step_speed(dir: int) -> void:
	if clock == null:
		return
	var i := SPEEDS.find(speed())
	i = posmod(i + dir, SPEEDS.size()) if i >= 0 else 0
	clock.speed_permille = SPEEDS[i] * BASE_SPEED * 1000
	_show_speed()


func _on_speed_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		step_speed(1)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		step_speed(-1)
	else:
		return
	_speed_button.accept_event()


func _show_speed() -> void:
	_speed_button.text = "%dx" % speed()  # notr
	_speed_button.tooltip_text = tr("Game speed: click or + faster, right click or - slower")


func refresh() -> void:
	if sim == null:
		return
	_menu_button.text = tr("Menu (F10)")
	_show_speed()
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
