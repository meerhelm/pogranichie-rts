class_name MissionBriefing
extends Control
## The mission's briefing: its title, where and when, a short story, the goal of the whole
## mission, the objectives as they stand (done ones ticked, failed ones crossed) and the ways to
## lose. Opens by itself when a new mission starts (the mission waits: no cutscene or dialogue
## until it is closed) and again with F2 or from the game menu. Pauses the game while open;
## Esc, Enter, F2 or the button close it. Texts come from the mission's briefing
## (MissionDef.briefing) and are translation keys.

signal closed

const GOLD := Color(0.95, 0.8, 0.45)

var sim: Simulation

var _title := Label.new()
var _place := Label.new()
var _text := RichTextLabel.new()
var _close := Button.new()
## Whether this is the briefing before the mission (the button says «Begin»).
var _first := false
## Whether opening paused the tree (so closing resumes it).
var _paused_it := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_title.theme_type_variation = &"Title"
	_title.add_theme_font_size_override("font_size", 32)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place.add_theme_color_override("font_color", GOLD)
	box.add_child(_place)
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.custom_minimum_size = Vector2(980, 0)
	_text.focus_mode = Control.FOCUS_NONE
	box.add_child(_text)
	_close.custom_minimum_size = Vector2(300, 44)
	_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close.pressed.connect(close)
	box.add_child(_close)
	visible = false


func attach(p_sim: Simulation) -> void:
	sim = p_sim


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and visible:
		_retranslate()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or sim == null:
		return
	if visible:
		if key.physical_keycode in [KEY_ESCAPE, KEY_F2, KEY_ENTER, KEY_KP_ENTER, KEY_F10]:
			close()
		# The briefing is in front of everything: no other key reaches the game meanwhile.
		get_viewport().set_input_as_handled()
	elif key.physical_keycode == KEY_F2 and not get_tree().paused:
		open()
		get_viewport().set_input_as_handled()


## Shows the briefing; `first`: before the mission (the button begins it).
func open(first: bool = false) -> void:
	_first = first
	_retranslate()
	visible = true
	_paused_it = not get_tree().paused
	if _paused_it:
		get_tree().paused = true
	_close.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	if _paused_it:
		get_tree().paused = false
		_paused_it = false
	closed.emit()


func _retranslate() -> void:
	var def := sim.mission.def
	_title.text = tr(def.title)
	_place.text = tr(def.briefing.get("place", ""))
	_place.visible = not _place.text.is_empty()
	_close.text = tr("Begin") if _first else tr("Back to the game (F2)")
	_text.text = page()


## The page under the title as BBCode, in the current language.
func page() -> String:
	var b := sim.mission.def.briefing
	var out := PackedStringArray()
	if b.has("story"):
		out.append(_esc(tr(b["story"])))
	if b.has("goal"):
		out.append(_head(tr("Goal")) + "\n" + _esc(tr(b["goal"])))
	var lines := PackedStringArray()
	for row: Array in objective_rows():
		var color: Color = row[1]
		lines.append("[color=#%s]%s[/color]" % [color.to_html(false), _esc(row[0])])
	var later := tr("New objectives appear as the mission goes on.")
	lines.append("[color=#a0a0a0][i]%s[/i][/color]" % later)
	out.append(_head(tr("Objectives")) + "\n" + "\n".join(lines))
	var lose: Array = b.get("lose", [])
	if not lose.is_empty():
		var why := PackedStringArray()
		for line: String in lose:
			why.append("• " + _esc(tr(line)))  # notr
		out.append(_head(tr("You lose if")) + "\n" + "\n".join(why))
	return "\n\n".join(out)


## The objectives as [text, colour] rows: the mission's own once it has set them, before that
## the ones it sets at the start (the briefing opens before the first tick).
func objective_rows() -> Array:
	var m := sim.mission
	var rows := []
	if not m.objectives.is_empty():
		for oid in m.objectives:
			rows.append(MissionPanel.objective_row(m, oid))
		return rows
	for t: Dictionary in m.def.triggers:
		if t["when"].get("type", "") != "start":
			continue
		for a: Dictionary in t["do"]:
			if a["do"] == "objective" and a.has("text"):
				var text := tr(a["text"])
				if a.get("optional", false):
					text = tr("(optional) %s") % text
				rows.append(["• " + text, Color.WHITE])  # notr
	return rows


static func _head(text: String) -> String:
	return "[font_size=24][color=#%s]%s[/color][/font_size]" % [GOLD.to_html(false), text]


## Text with BBCode's brackets shown as they are.
static func _esc(text: String) -> String:
	return text.replace("[", "[lb]")
