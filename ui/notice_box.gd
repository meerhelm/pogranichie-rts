class_name NoticeBox
extends PanelContainer
## One message of a mission in the game's oak and iron frame: a hint (text only), a character's
## line (their portrait, if they have one, their name in gold and what they say), or a cutscene
## subtitle (the same, larger, with how to go on). Speakers are catalog ids of heroes, whose
## portraits come from IconDB, or English keys such as "Chronicler", shown without a picture.

## Pressed with the left mouse button (the panel goes to the next line).
signal clicked

var _frame := PanelContainer.new()
var _portrait := TextureRect.new()
var _name := Label.new()
var _text := Label.new()
var _footer := Label.new()


func _init(portrait_size := 96.0, text_width := 640.0) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	_frame.theme_type_variation = &"PortraitFrame"
	_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.custom_minimum_size = Vector2(portrait_size, portrait_size)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_frame.add_child(_portrait)
	row.add_child(_frame)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(column)
	_name.theme_type_variation = &"Title"
	column.add_child(_name)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = text_width
	column.add_child(_text)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_footer.add_theme_color_override("font_color", Color(0.75, 0.68, 0.55))
	_footer.add_theme_font_size_override("font_size", 15)
	_footer.visible = false
	column.add_child(_footer)


## Shows a line: `speaker` a hero id or a name key ("" for a hint), `text` a translation key.
func show_line(speaker: String, text: String) -> void:
	var tex: Texture2D = IconDB.of(StringName(speaker)) if not speaker.is_empty() else null
	_frame.visible = tex != null
	_portrait.texture = tex
	_name.visible = not speaker.is_empty()
	_name.text = UiText.t(speaker) if _name.visible else ""
	_text.text = tr(text)


## A line at the bottom in small print, such as how to go on ("" hides it).
func set_footer(text: String) -> void:
	_footer.text = text
	_footer.visible = not text.is_empty()


## The speaker's name and the line as shown, for tests.
func shown() -> String:
	return "%s — %s" % [_name.text, _text.text] if _name.visible else _text.text


func has_portrait() -> bool:
	return _frame.visible


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
		accept_event()
