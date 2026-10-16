class_name EndScreen
extends Control
## The end of a skirmish (M8) or a mission (M9): victory or defeat and why, the game time, and
## each side's statistics side by side (units trained, lost and killed, buildings built and
## lost, what was gathered, Сила gained). Opens over the paused game; back to the main menu or
## quit.

signal closed

const MENU_SCENE := "res://ui/main_menu.tscn"

var _title := Label.new()
var _reason := Label.new()
var _grid := GridContainer.new()
var _to_menu := Button.new()
var _watch := Button.new()
var _quit := Button.new()
var _sim: Simulation
var _player := 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	_title.add_theme_font_size_override("font_size", 40)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_reason)
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 32)
	box.add_child(_grid)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	for b: Button in [_watch, _to_menu, _quit]:
		b.custom_minimum_size = Vector2(200, 44)
		buttons.add_child(b)
	box.add_child(buttons)
	_watch.pressed.connect(_on_watch)
	_to_menu.pressed.connect(_on_main_menu)
	_quit.pressed.connect(func() -> void: get_tree().quit())
	visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and _sim != null:
		_fill()


## Shows the outcome for `player` and pauses the game.
func open(sim: Simulation, player: int) -> void:
	_sim = sim
	_player = player
	_fill()
	visible = true
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
