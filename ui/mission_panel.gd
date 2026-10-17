class_name MissionPanel
extends Control
## What a campaign mission shows (M9): the objectives (top right; optional ones marked, done
## ones ticked, failed ones crossed), hints (top middle, each for a while), the characters'
## lines in the mission through Dialogic, and cutscenes on the engine: the game stops, black
## bars close in, the camera flies to the place and the lines run as subtitles (click, Space or
## Enter for the next one, Esc skips the rest). Reads MissionRuntime.events and never changes
## the simulation; all texts are translation keys.

signal cutscene_started
signal cutscene_finished

## How long a hint stays, in seconds of real time, and how many show at once.
const HINT_SECONDS := 14.0
const MAX_HINTS := 3
## Seconds a subtitle stays before the next one comes by itself.
const LINE_SECONDS := 7.0
const BAR_HEIGHT := 120.0

var sim: Simulation
var clock: SimClock
var camera: RtsCamera

var _read := 0
var _objectives := VBoxContainer.new()
var _objective_panel := PanelContainer.new()
## The blockade's state under the objectives (phase 4 of ВКЛ 1), hidden while it is off.
var _blockade := Label.new()
var _hints := VBoxContainer.new()
## Waiting dialogues (lists of [speaker, text]) while one is on screen.
var _dialogues: Array = []
var _in_dialogue := false
## The cutscene being shown: its lines and the one on screen; queued ones wait.
var _cutscenes: Array = []
var _lines: Array = []
var _line := -1
var _line_left := 0.0
var _top_bar := ColorRect.new()
var _bottom_bar := ColorRect.new()
var _subtitle := Label.new()
var _speaker := Label.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_objective_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_objective_panel.position.y = 48
	_objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_child(_objectives)
	_blockade.visible = false
	_blockade.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
	column.add_child(_blockade)
	_objective_panel.add_child(column)
	add_child(_objective_panel)
	_hints.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hints.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hints.position.y = 96
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hints)
	for bar: ColorRect in [_top_bar, _bottom_bar]:
		bar.color = Color.BLACK
		bar.visible = false
		bar.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(bar)
	_top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top_bar.custom_minimum_size.y = BAR_HEIGHT
	_bottom_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bottom_bar.custom_minimum_size.y = BAR_HEIGHT
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_bottom_bar.add_child(box)
	_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speaker.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
	box.add_child(_speaker)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.custom_minimum_size.x = 1200
	_subtitle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_subtitle)


func attach(p_sim: Simulation, p_clock: SimClock, p_camera: RtsCamera) -> void:
	sim = p_sim
	clock = p_clock
	camera = p_camera
	# A loaded game shows its objectives but does not replay what was already said.
	_read = sim.mission.events.size()
	_fill_objectives()
	clock.ticked.connect(func(_t: int) -> void: poll())


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and sim != null:
		_fill_objectives()


## Takes the mission's new events; also what tests call.
func poll() -> void:
	var events := sim.mission.events
	while _read < events.size():
		var e: Dictionary = events[_read]
		_read += 1
		match e["kind"]:
			"objective":
				_fill_objectives()
			"hint":
				_hint(e["text"])
			"dialogue":
				_dialogues.append(e["lines"])
			"cutscene":
				_cutscenes.append(e)
			"ping":
				pass
	_show_blockade()
	if _line < 0 and not _cutscenes.is_empty():
		_start_cutscene(_cutscenes.pop_front())
	elif _line < 0 and not _in_dialogue and not _dialogues.is_empty():
		_start_dialogue(_dialogues.pop_front())


func in_cutscene() -> bool:
	return _line >= 0


## The objective lines as shown, for tests.
func objective_lines() -> PackedStringArray:
	var out := PackedStringArray()
	for child in _objectives.get_children():
		out.append((child as Label).text)
	return out


func _fill_objectives() -> void:
	for child in _objectives.get_children():
		child.queue_free()
		_objectives.remove_child(child)
	var m := sim.mission
	var title := Label.new()
	title.text = tr("Objectives")
	_objectives.add_child(title)
	for oid in m.objectives:
		var label := Label.new()
		var text := tr(m.objective_text[oid])
		if m.objective_optional[oid]:
			text = tr("(optional) %s") % text
		match m.objective_state[oid]:
			MissionRuntime.Objective.DONE:
				text = "✓ " + text  # notr
				label.modulate = Color(0.6, 1.0, 0.6)
			MissionRuntime.Objective.FAILED:
				text = "✗ " + text  # notr
				label.modulate = Color(1.0, 0.55, 0.5)
			_:
				text = "• " + text  # notr
		label.text = text
		_objectives.add_child(label)
	_objective_panel.visible = not m.objectives.is_empty()


## «Garrison strength 74% · posts held 2/3» while the blockade is on.
func _show_blockade() -> void:
	var m := sim.mission
	_blockade.visible = m.blockade_on
	if not m.blockade_on:
		return
	var posts: Array = m.def.rules["blockade"]["posts"]
	var held := 0
	for i in posts.size():
		if m.posts_held & (1 << i):
			held += 1
	_blockade.text = (
		tr("Dubysa garrison: %d%%") % (m.garrison / 10)
		+ "\n"
		+ tr("Posts held: %d of %d") % [held, posts.size()]
	)


## The blockade line as shown, for tests ("" while hidden).
func blockade_text() -> String:
	return _blockade.text if _blockade.visible else ""


func _hint(text: String) -> void:
	var label := Label.new()
	label.text = tr(text)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 760
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	_hints.add_child(label)
	while _hints.get_child_count() > MAX_HINTS:
		var old := _hints.get_child(0)
		_hints.remove_child(old)
		old.queue_free()
	get_tree().create_timer(HINT_SECONDS, true).timeout.connect(
		func() -> void:
			if is_instance_valid(label):
				label.queue_free()
	)


## Speaker name: a catalog id (a hero) or an English key.
static func speaker_name(key: String) -> String:
	return UiText.t(key)


# --- dialogues (Dialogic) -------------------------------------------------------------------


## The lines as a Dialogic timeline in its text format, already translated.
static func timeline_text(lines: Array) -> String:
	var out := PackedStringArray()
	for line: Array in lines:
		var said := "%s — %s" % [speaker_name(line[0]), UiText.t(line[1])]
		for ch: String in ["\\", ":", "[", "]", "{", "}", "#", "<", ">"]:
			said = said.replace(ch, "\\" + ch)
		out.append(said)
	return "\n".join(out)


func _start_dialogue(lines: Array) -> void:
	var dialogic := get_node_or_null(^"/root/Dialogic")
	if dialogic == null:
		# No Dialogic (a test scene): the lines go to the hint area instead.
		for line: Array in lines:
			_hint("%s — %s" % [speaker_name(line[0]), tr(line[1])])
		return
	var timeline := DialogicTimeline.new()
	timeline.from_text(timeline_text(lines))
	_in_dialogue = true
	dialogic.timeline_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)
	dialogic.start(timeline)


func _on_dialogue_ended() -> void:
	_in_dialogue = false
	poll()


# --- cutscenes ------------------------------------------------------------------------------


func _start_cutscene(e: Dictionary) -> void:
	_lines = e["lines"]
	_line = 0
	clock.paused = true
	_top_bar.visible = true
	_bottom_bar.visible = true
	cutscene_started.emit()
	var at: Array = e["at"]
	if camera != null:
		var to := Iso.cell_to_screen(Vector2(at[0], at[1]))
		var tween := create_tween()
		tween.tween_property(camera, ^"position", to, 1.5).set_trans(Tween.TRANS_SINE)
	_show_line()


func _show_line() -> void:
	var line: Array = _lines[_line]
	_speaker.text = speaker_name(line[0])
	_subtitle.text = tr(line[1])
	_line_left = LINE_SECONDS


## Next subtitle, or the end of the cutscene after the last one.
func next_line() -> void:
	if _line < 0:
		return
	_line += 1
	if _line < _lines.size():
		_show_line()
	else:
		end_cutscene()


func end_cutscene() -> void:
	_line = -1
	_top_bar.visible = false
	_bottom_bar.visible = false
	clock.paused = false
	cutscene_finished.emit()
	poll()


func _process(delta: float) -> void:
	if _line < 0:
		return
	_line_left -= delta
	if _line_left <= 0.0:
		next_line()


func _unhandled_input(event: InputEvent) -> void:
	if _line < 0:
		return
	var key := event as InputEventKey
	var mb := event as InputEventMouseButton
	if key != null and key.pressed and not key.echo:
		if key.physical_keycode == KEY_ESCAPE:
			end_cutscene()
		elif key.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			next_line()
		get_viewport().set_input_as_handled()
	elif mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		next_line()
		get_viewport().set_input_as_handled()
