class_name NetChat
extends VBoxContainer
## Chat in a network game: Enter opens a line, Enter sends it (Esc drops it). The last lines of
## both players show above the bottom panel on the left and fade after LINE_SECONDS.

const LINE_SECONDS := 12.0
const MAX_LINES := 6

var session: NetSession
var edit := LineEdit.new()
## Shown lines, oldest first: [Label, seconds left].
var _lines: Array[Array] = []


func _init() -> void:
	name = "NetChat"  # notr
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Above the bottom panel on the left, growing upwards.
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 16
	offset_right = 536
	offset_top = -440
	offset_bottom = -440
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	alignment = BoxContainer.ALIGNMENT_END
	edit.visible = false
	edit.max_length = NetSession.MAX_CHAT
	edit.custom_minimum_size = Vector2(520, 0)
	edit.text_submitted.connect(_on_submitted)
	add_child(edit)


func attach(p_session: NetSession) -> void:
	session = p_session
	session.chat.connect(_on_chat)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode in [KEY_ENTER, KEY_KP_ENTER] and not edit.visible:
		edit.visible = true
		edit.placeholder_text = tr("Message to the other player (Enter sends, Esc closes)")
		edit.grab_focus()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if edit.visible and key != null and key.pressed and key.physical_keycode == KEY_ESCAPE:
		_close_edit()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	for line in _lines:
		line[1] = float(line[1]) - delta
		var label: Label = line[0]
		label.modulate.a = clampf(float(line[1]), 0.0, 1.0)
	while not _lines.is_empty() and float(_lines[0][1]) <= 0.0:
		(_lines.pop_front()[0] as Label).queue_free()


func _on_submitted(text: String) -> void:
	if not text.strip_edges().is_empty():
		session.send_chat(text)
		show_line(tr("You: %s") % text.strip_edges().left(NetSession.MAX_CHAT))
	_close_edit()


func _close_edit() -> void:
	edit.text = ""
	edit.visible = false
	edit.release_focus()


func _on_chat(text: String) -> void:
	var who := session.remote_name()
	if who.is_empty():
		who = tr("Opponent")
	show_line("%s: %s" % [who, text])


func show_line(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(520, 0)
	label.add_theme_color_override("font_color", Color(0.98, 0.9, 0.7))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	move_child(edit, -1)
	_lines.append([label, LINE_SECONDS])
	while _lines.size() > MAX_LINES:
		(_lines.pop_front()[0] as Label).queue_free()
