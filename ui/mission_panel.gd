class_name MissionPanel
extends Control
## What a campaign mission shows (M9): the objectives (top right; optional ones marked, done
## ones ticked, failed ones crossed), hints (top middle, each for a while), the characters'
## lines in the mission through Dialogic, and cutscenes on the engine: the game stops, a black
## band rises at the bottom, the camera flies to the place and the lines run there as subtitles
## (click, Space or Enter for the next one, Esc skips the rest). Reads MissionRuntime.events;
## the only thing it sends is the player's answer to a mission's question (ВКЛ 3), as a CHOOSE
## command. All texts are translation keys.

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

## While true (the briefing before the mission is open) no cutscene, dialogue or question
## starts; they wait until release().
var hold := false

var _read := 0
var _objectives := VBoxContainer.new()
var _objective_panel := PanelContainer.new()
## The blockade's state under the objectives (phase 4 of ВКЛ 1), hidden while it is off.
var _blockade := Label.new()
## ВКЛ 3: the evidence and the baptized under the objectives, and the question being asked.
var _evidence := Label.new()
## ВКЛ 4: the countdown to dawn and the captive banners under the objectives.
var _march := Label.new()
var _question := PanelContainer.new()
var _question_text := Label.new()
var _answers := VBoxContainer.new()
## Questions waiting to be shown (choice events), the one on screen ("" for none).
var _questions: Array = []
var _asking := ""
var _hints := VBoxContainer.new()
## Waiting dialogues (lists of [speaker, text]) while one is on screen.
var _dialogues: Array = []
var _in_dialogue := false
## The cutscene being shown: its lines and the one on screen; queued ones wait.
var _cutscenes: Array = []
var _lines: Array = []
var _line := -1
var _line_left := 0.0
var _bottom_bar := ColorRect.new()
var _subtitle := Label.new()
var _speaker := Label.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	_evidence.visible = false
	_evidence.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
	column.add_child(_evidence)
	_march.visible = false
	_march.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
	column.add_child(_march)
	_objective_panel.add_child(column)
	add_child(_objective_panel)
	_hints.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hints.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hints.position.y = 96
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hints)
	_question.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_question.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_question.grow_vertical = Control.GROW_DIRECTION_BOTH
	_question.visible = false
	var ask := VBoxContainer.new()
	ask.add_theme_constant_override("separation", 10)
	_question_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_question_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_question_text.custom_minimum_size.x = 420
	ask.add_child(_question_text)
	ask.add_child(_answers)
	_question.add_child(ask)
	add_child(_question)
	# Only a band at the bottom for the subtitles: the top bar with resources stays in view.
	_bottom_bar.color = Color.BLACK
	_bottom_bar.visible = false
	_bottom_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bottom_bar)
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
	# ...except a question still open.
	for e: Dictionary in sim.mission.events:
		if e["kind"] == "choice" and sim.mission.choices.has(e["id"]):
			_questions.append(e)
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
			"choice":
				_questions.append(e)
			"chosen":
				if _asking == e["id"]:
					_close_question()
			"ping":
				pass
	_show_blockade()
	_show_evidence()
	_show_march()
	if hold:
		return
	if _asking.is_empty() and _line < 0 and not _questions.is_empty():
		_ask(_questions.pop_front())
	if _line < 0 and not _cutscenes.is_empty():
		_start_cutscene(_cutscenes.pop_front())
	elif _line < 0 and not _in_dialogue and not _dialogues.is_empty():
		_start_dialogue(_dialogues.pop_front())


## Ends the hold: what waited starts now.
func release() -> void:
	hold = false
	poll()


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
		var row := objective_row(m, oid)
		var label := Label.new()
		label.text = row[0]
		label.modulate = row[1]
		_objectives.add_child(label)
	_objective_panel.visible = not m.objectives.is_empty()


## An objective as shown: [text with its mark, colour]: «• Burn the castle», «✓ ...» in
## green when done, «✗ ...» in red when failed; optional ones say so.
static func objective_row(m: MissionRuntime, oid: String) -> Array:
	var text := UiText.t(m.objective_text[oid])
	if m.objective_optional[oid]:
		text = UiText.t("(optional) %s") % text
	match m.objective_state[oid]:
		MissionRuntime.Objective.DONE:
			return ["✓ " + text, Color(0.6, 1.0, 0.6)]  # notr
		MissionRuntime.Objective.FAILED:
			return ["✗ " + text, Color(1.0, 0.55, 0.5)]  # notr
	return ["• " + text, Color.WHITE]  # notr


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


## «Evidence: 34 of 100 · Baptized: 12» while the mission keeps evidence (ВКЛ 3).
func _show_evidence() -> void:
	var m := sim.mission
	_evidence.visible = m.def.rules.has("evidence")
	if not _evidence.visible:
		return
	var most := int(m.def.rules["evidence"].get("max", 100))
	_evidence.text = (
		tr("Evidence: %d of %d") % [m.evidence / 1000, most]
		+ "\n"
		+ tr("Baptized: %d") % m.baptized_alive()
	)


## «Dawn in 04:12» while the mission counts down, «Banners taken captive: 3» once the mission
## asks for captives (ВКЛ 4).
func _show_march() -> void:
	var m := sim.mission
	var lines := PackedStringArray()
	if m.countdown_end >= 0 and not m.countdown_text.is_empty():
		var left := maxi(m.countdown_end - sim.tick, 0)
		lines.append(tr(m.countdown_text) % UiText.clock(left))
	var c: Dictionary = m.def.rules.get("capture", {})
	if c.has("banners") and m.objective_state.has("captives"):
		var taken := MissionMarch.groups_taken(m, c["banners"])
		lines.append(tr("Banners taken captive: %d") % taken)
	_retreat_lines(m, lines)
	_stealth_lines(m, lines)
	_siege_lines(m, lines)
	_battle_lines(m, lines)
	_field_lines(m, lines)
	_besiege_lines(m, lines)
	_baltic_lines(m, lines)
	_march.visible = not lines.is_empty()
	_march.text = "\n".join(lines)


## ВКЛ 5: «Bridge: 64%» while the axemen are at it, «Brought back over the river: 12» once the
## retreat begins.
func _retreat_lines(m: MissionRuntime, lines: PackedStringArray) -> void:
	var r := m.retreat
	if r.bridge_from >= 0 and not r.bridge_fell:
		lines.append(tr("Bridge: %d%%") % (r.bridge_permille(m) / 10))
	if m.def.rules.has("rescue") and m.objective_state.has("out"):
		lines.append(tr("Brought back over the river: %d") % r.saved(m))


## ВКЛ 6: «Suspicion: 40%» while the watch looks, «The chase sets out in 03:10» until it does,
## «Horses: 62%» (the most tired horse of the band, «Tired» when one only walks).
func _stealth_lines(m: MissionRuntime, lines: PackedStringArray) -> void:
	var st := m.stealth
	if st.on:
		lines.append(tr("Suspicion: %d%%") % (st.meter / 10))
	if st.pursuit_at >= 0 and sim.tick < st.pursuit_at:
		lines.append(tr("The chase sets out in %s") % UiText.clock(st.pursuit_at - sim.tick))
	if st.on and not st.stamina.is_empty():
		var least := MissionStealth.FULL
		for id: int in st.stamina:
			least = mini(least, st.stamina[id])
		var line := tr("Horses: %d%%") % (least / 10)
		if not st.tired.is_empty():
			line += " · " + tr("Tired")
		lines.append(line)


## ВКЛ 7: «Next assault in 03:20» while the rebels get ready, «Ladders at the walls: 2» while
## any stand, «The Lower castle is lost» while it is, «Posad standing: 70%».
func _siege_lines(m: MissionRuntime, lines: PackedStringArray) -> void:
	var r: Dictionary = m.def.rules.get("siege", {})
	if r.is_empty():
		return
	var sg := m.siege
	if sg.assault_base >= 0 and sim.tick < sg.assault_due(m):
		lines.append(tr("Next assault in %s") % UiText.clock(sg.assault_due(m) - sim.tick))
	if sg.ladders_up() > 0:
		lines.append(tr("Ladders at the walls: %d") % sg.ladders_up())
	if sg.lost.get("lower", false):
		lines.append(tr("The Lower castle is lost"))
	var posad: Array = r.get("posad", {}).get("buildings", [])
	if not posad.is_empty():
		lines.append(tr("Posad standing: %d%%") % (sg.standing_permille(m, posad) / 10))


## ВКЛ 8: «Bridge 1: 2 of 3 sections (40%)» while the bridges are laid, «The patrol has raised
## the alarm» once it has, «Hidden in the ambush: 9» while the foot and the guns wait.
func _battle_lines(m: MissionRuntime, lines: PackedStringArray) -> void:
	var r: Dictionary = m.def.rules.get("battle", {})
	if r.is_empty():
		return
	var bt := m.battle
	var bridges: Array = r.get("bridges", [])
	for i in bridges.size():
		var sections := int(bridges[i]["sections"])
		if bt.built[i] < sections and m.stealth.night:
			var line := tr("Bridge %d: %d of %d sections") % [i + 1, bt.built[i], sections]
			lines.append(line + " (%d%%)" % (bt.section_permille(m, i) / 10))
	if bt.alarm and m.stealth.night:
		lines.append(tr("The patrol has raised the alarm"))
	if not bt.held.is_empty():
		lines.append(tr("Hidden in the ambush: %d") % bt.hidden.size())


## Корона 1: «Heat on your lances: 30%» while it is hot and the lances feel it, «Guest knights
## taken captive: 2» once any is.
func _field_lines(m: MissionRuntime, lines: PackedStringArray) -> void:
	if not m.def.rules.get("field", {}).has("heat"):
		return
	var heat := m.field.player_heat(m)
	if heat > 0:
		lines.append(tr("Heat on your lances: %d%%") % (heat / 10))
	if m.field.captured > 0:
		lines.append(tr("Guest knights taken captive: %d") % m.field.captured)


## Корона 2: «Siege: 40%» (the hunger in the castle, as the card wants), «Powder for 30 shots»
## (iron is powder), «Plague in the camp: 25%» once it starts, «Bombards spiked: 2» while any
## is, «Towns sworn: 3» once the envoys walk, «Bombards brought to Sztum: 5» on the road back.
func _besiege_lines(m: MissionRuntime, lines: PackedStringArray) -> void:
	var bs := m.besiege
	if not bs.on:
		return
	lines.append(tr("Siege: %d%%") % (bs.hunger / 10))
	var shot := maxi(int(sim.economy.db.unit(&"pl_bombard").params.get(&"shot_iron", 1)), 1)
	var iron := sim.economy.player(m.def.player).stock[EconomySystem.IRON]
	lines.append(tr("Powder for %d shots") % (iron / shot))
	if bs.plague > 0:
		lines.append(tr("Plague in the camp: %d%%") % (bs.plague / 10))
	if not bs.spiked.is_empty():
		lines.append(tr("Bombards spiked: %d") % bs.spiked.size())
	if bs.envoys_walk or not bs.towns.is_empty():
		lines.append(tr("Towns sworn: %d") % bs.count_towns(1))
	if m.fired.has(str(m.def.rules["besiege"].get("sztum", {}).get("from", ""))):
		lines.append(tr("Bombards brought to Sztum: %d") % bs.brought)


## Корона 3: «Concord: 70%» once Čapek first asks for wages (and «The orphans listen to nobody»
## while they mutiny), «Wagons: 12», «Camps fortified: 1 of 4», «Wind: from the west» at Tczew,
## the prisoners ransomed and killed once there are any, the villages taken by each side.
func _baltic_lines(m: MissionRuntime, lines: PackedStringArray) -> void:
	var b := m.baltic
	if not b.on:
		return
	if m.flags.has("concord_shown") or b.concord < 700:
		lines.append(tr("Concord: %d%%") % (b.concord / 10))
	if b.mutiny_until >= 0:
		lines.append(tr("The orphans listen to nobody"))
	lines.append(tr("Wagons: %d") % m.alive_of("wagons").size())
	lines.append(tr("Camps fortified: %d of %d") % [b.camps_count(), b.camps_total(m)])
	if m.fired.has("6") and not m.fired.has("8"):
		lines.append(tr("Wind: from the west"))
	if b.ransomed + b.killed > 0:
		lines.append(tr("Prisoners ransomed: %d, killed: %d") % [b.ransomed, b.killed])
	if not b.villages.is_empty():
		lines.append(tr("Villages: %d ours, %d plundered") % [b.foraged(1), b.foraged(2)])


## The countdown and captives lines as shown, for tests ("" while hidden).
func march_text() -> String:
	return _march.text if _march.visible else ""


## The evidence lines as shown, for tests ("" while hidden).
func evidence_text() -> String:
	return _evidence.text if _evidence.visible else ""


## The question on screen, for tests ("" for none).
func asking() -> String:
	return _asking


func _ask(e: Dictionary) -> void:
	if not sim.mission.choices.has(e["id"]):
		return
	_asking = e["id"]
	_question_text.text = tr(e["text"])
	for child in _answers.get_children():
		_answers.remove_child(child)
		child.queue_free()
	var options: Array = e["options"]
	for i in options.size():
		var b := Button.new()
		b.text = tr(options[i])
		b.custom_minimum_size = Vector2(360, 44)
		b.pressed.connect(answer.bind(i))
		_answers.add_child(b)
	_question.visible = true


## The player picks an option (a button, or a test).
func answer(option: int) -> void:
	if _asking.is_empty():
		return
	sim.enqueue(SimCommand.choose(sim.tick, sim.mission.def.player, StringName(_asking), option))
	_close_question()


func _close_question() -> void:
	_asking = ""
	_question.visible = false


## The blockade line as shown, for tests ("" while hidden).
func blockade_text() -> String:
	return _blockade.text if _blockade.visible else ""


func _hint(text: String) -> void:
	var label := Label.new()
	label.text = tr(text)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 640
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
