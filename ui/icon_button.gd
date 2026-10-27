class_name IconButton
extends Button
## A HUD order button: a square picture with its name under it, the hotkey in the corner and,
## on hover, a rich tooltip (Tips) with the price, what the thing is for and what it gives.
## tooltip_text keeps the same tooltip as plain text. A compact button (queue items) shows
## only the picture and, for the item in work, how far along it is.

const SIZE := Vector2(96, 98)
const COMPACT := Vector2(56, 56)
const ICON := 58.0
const TIP_WIDTH := 440.0
const TIP_TEXT := Color(0.17, 0.11, 0.05)

## The name under the picture.
var caption := "":
	set(value):
		caption = value
		_label.text = value
## Rich tooltip (BBCode, see Tips); empty: the plain tooltip_text.
var rich_tip := ""
## Key shown in the upper left corner.
var hotkey := ""
## 0..1 progress drawn over a compact button (-1: none).
var progress := -1.0:
	set(value):
		if not is_equal_approx(value, progress):
			progress = value
			queue_redraw()

var _icon := TextureRect.new()
var _label := Label.new()
var _compact := false


func _init(texture: Texture2D = null, p_caption := "", compact := false) -> void:
	_compact = compact
	custom_minimum_size = COMPACT if compact else SIZE
	theme_type_variation = &"CommandButton"
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 5)
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_icon.texture = texture
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_icon.custom_minimum_size = Vector2(0, (COMPACT.y - 8) if compact else ICON)
	box.add_child(_icon)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.max_lines_visible = 2
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_constant_override("line_spacing", -4)
	_label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02))
	_label.add_theme_constant_override("outline_size", 3)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = not compact
	_label.custom_minimum_size = Vector2(0, 34)
	_label.size_flags_vertical = Control.SIZE_SHRINK_END
	box.add_child(_label)
	caption = p_caption
	if texture == null:
		# No picture yet: the name fills the button.
		_icon.visible = false
		_label.visible = true
		_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_label.max_lines_visible = 3


func _draw() -> void:
	var dim := Color(0.42, 0.42, 0.42) if disabled else Color.WHITE
	_icon.modulate = dim
	_label.modulate = Color(0.75, 0.72, 0.66) if disabled else Color.WHITE
	var font := get_theme_default_font()
	if not hotkey.is_empty():
		var at := Vector2(7, 17)
		draw_string_outline(font, at, hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
		draw_string(font, at, hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.86, 0.5))
	if progress >= 0.0:
		var bar := Rect2(4, size.y - 9, size.x - 8, 5)
		draw_rect(bar, Color(0, 0, 0, 0.7))
		draw_rect(
			Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), Color(0.4, 0.8, 0.3)
		)


func _make_custom_tooltip(for_text: String) -> Object:
	if rich_tip.is_empty():
		return null
	return Tips.make_label(rich_tip, TIP_WIDTH) if not for_text.is_empty() else null
