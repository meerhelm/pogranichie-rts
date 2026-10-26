class_name EndScreen
extends Control
## The end of a skirmish (M8) or a mission (M9): victory or defeat and why, the game time, and
## each side's statistics side by side (units trained, lost and killed, buildings built and
## lost, what was gathered, Сила gained). Opens over the paused game; back to the main menu or
## quit.

signal closed

const MENU_SCENE := "res://ui/main_menu.tscn"
const SCENE := "res://ui/end_screen.tscn"

var _sim: Simulation
var _player := 1

@onready var _title: Label = %Title
@onready var _reason: Label = %Reason
@onready var _grid: GridContainer = %Grid
@onready var _to_menu: Button = %ToMenu
@onready var _watch: Button = %Watch
@onready var _quit: Button = %Quit


## A new end screen (the scene, end_screen.tscn).
static func create() -> EndScreen:
	return (load(SCENE) as PackedScene).instantiate()


func _ready() -> void:
	_watch.pressed.connect(_on_watch)
	_to_menu.pressed.connect(_on_main_menu)
	_quit.pressed.connect(func() -> void: get_tree().quit())


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and _sim != null:
		_fill()


## Shows the outcome for `player` and pauses the game.
func open(sim: Simulation, player: int) -> void:
	_sim = sim
	_player = player
	_fill()
	visible = true
	UiAnim.pop_in(self, %Panel)
	get_tree().paused = true
	_to_menu.grab_focus.call_deferred()


func _fill() -> void:
	var v := _sim.victory
	if v.winner == _player:
		_title.text = tr("Victory")
	elif v.winner == 0:
		_title.text = tr("Draw")
	else:
		_title.text = tr("Defeat")
	var why := ""
	match v.reason:
		SkirmishVictory.Reason.CONQUEST:
			why = tr("The capital and castles of the losing side are destroyed.")
		SkirmishVictory.Reason.PLACES:
			why = tr("All places of power held for five minutes.")
		SkirmishVictory.Reason.MISSION:
			why = tr(v.message)
	_reason.text = "%s %s" % [why, tr("Game time: %s") % UiText.clock(v.end_tick + 1)]
	var m := _sim.mission
	if m != null and m.def.rules.has("rescue"):
		_reason.text += "\n" + tr("Brought back over the river: %d") % m.retreat.saved(m)
	if m != null and m.swiecino.on:
		var s := m.swiecino
		var silver := _sim.economy.player(s.player).stock[EconomySystem.SILVER]
		_reason.text += (
			"\n"
			+ tr("Fallen: %d, prisoners: %d, silver left: %d") % [s.fallen(m), s.prisoners, silver]
		)
	_watch.text = tr("Keep watching")
	_to_menu.text = tr("Main menu")
	_quit.text = tr("Quit")
	for child in _grid.get_children():
		child.queue_free()
	var players := _sim.economy.players.keys()
	players.sort()
	_grid.columns = players.size() + 1
	_cell("")
	for p: int in players:
		_cell(UiText.name_of(_sim.economy.players[p].faction), true)
	for row: Array in rows():
		_cell(row[0])
		for value: String in row[1]:
			_cell(value)


## The table as [label, [value per player in id order]] rows; also what tests read.
func rows() -> Array:
	var players := _sim.economy.players.keys()
	players.sort()
	var states: Array[PlayerState] = []
	for p: int in players:
		states.append(_sim.economy.players[p])
	var out := []
	out.append(
		[tr("Units trained"), _column(states, func(s: PlayerState) -> int: return s.trained)]
	)
	out.append([tr("Units lost"), _column(states, func(s: PlayerState) -> int: return s.lost)])
	out.append([tr("Units killed"), _column(states, func(s: PlayerState) -> int: return s.killed)])
	out.append(
		[tr("Buildings built"), _column(states, func(s: PlayerState) -> int: return s.built)]
	)
	out.append(
		[
			tr("Buildings lost"),
			_column(states, func(s: PlayerState) -> int: return s.buildings_lost)
		]
	)
	for r in 4:
		var label := tr("%s gathered") % UiText.resource(r)
		out.append([label, _column(states, func(s: PlayerState) -> int: return s.gathered[r])])
	out.append(
		[
			tr("Power gained"),
			_column(
				states, func(s: PlayerState) -> int: return s.power_gained / MagicSystem.POWER_UNIT
			)
		]
	)
	out.append([tr("Age"), _ages(states)])
	return out


static func _column(states: Array[PlayerState], value: Callable) -> PackedStringArray:
	var cells := PackedStringArray()
	for s in states:
		cells.append(str(value.call(s)))
	return cells


func _ages(states: Array[PlayerState]) -> PackedStringArray:
	var cells := PackedStringArray()
	for s in states:
		var age := _sim.economy.db.age_by_index(s.age)
		cells.append(UiText.name_of(age.id) if age != null else str(s.age))
	return cells


func _cell(text: String, header: bool = false) -> void:
	var label := Label.new()
	label.text = text
	if header:
		label.add_theme_font_size_override("font_size", 20)
	_grid.add_child(label)


func _on_watch() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()


func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
