class_name AboutPanel
extends Control
## «About the game»: the version and what each build added, newest first, from
## ui/changelog.json. Opened from the main menu; Esc or the button close it.

signal closed

const CHANGELOG := "res://ui/changelog.json"

var _title := Label.new()
var _text := RichTextLabel.new()
var _close := Button.new()


func _ready() -> void:
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
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	_title.theme_type_variation = &"Title"
	_title.add_theme_font_size_override("font_size", 32)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_text.bbcode_enabled = true
	_text.fit_content = false
	_text.scroll_active = true
	_text.custom_minimum_size = Vector2(1000, 640)
	_text.focus_mode = Control.FOCUS_NONE
	box.add_child(_text)
	_close.custom_minimum_size = Vector2(300, 44)
	_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close.pressed.connect(close)
	box.add_child(_close)
	visible = false
	_retranslate()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_retranslate()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not visible or key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	_retranslate()
	_text.scroll_to_line(0)
	visible = true
	_close.grab_focus.call_deferred()


func close() -> void:
	visible = false
	closed.emit()


func _retranslate() -> void:
	_title.text = tr("About the game")
	_close.text = tr("Close")
	_text.text = page()


## The game's version from project.godot (application/config/version).
static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


## The builds in ui/changelog.json, newest first: {version, date, items: [{en, be, ...}]}.
static func versions() -> Array:
	var file := FileAccess.open(CHANGELOG, FileAccess.READ)
	if file == null:
		push_error("AboutPanel: cannot open %s" % CHANGELOG)
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("AboutPanel: %s is not a JSON object" % CHANGELOG)
		return []
	var dict: Dictionary = parsed
	var list: Variant = dict.get("versions", [])
	return list if list is Array else []


## One changelog item in the current language, English when it has no text in it.
static func item_text(item: Dictionary) -> String:
	var lang := TranslationServer.get_locale().get_slice("_", 0)
	return str(item.get(lang, item.get("en", "")))


## The page as BBCode, in the current language.
func page() -> String:
	var out := PackedStringArray()
	var head := get_theme_default_font_size() + 6
	out.append("%s · %s" % [tr("Pogranichie"), tr("Version %s") % version()])
	out.append("")
	for entry: Variant in versions():
		if not entry is Dictionary:
			continue
		var build: Dictionary = entry
		var heading := tr("Version %s") % str(build.get("version", "?"))
		var date := str(build.get("date", ""))
		if not date.is_empty():
			heading = "%s · %s" % [heading, _date(date)]
		out.append("[font_size=%d][b]%s[/b][/font_size]" % [head, heading])
		for item: Variant in build.get("items", []):
			if item is Dictionary:
				var line: Dictionary = item
				out.append("• " + item_text(line))
		out.append("")
	return "\n".join(out)


## "2026-10-17" as "17.10.2026".
static func _date(iso: String) -> String:
	var parts := iso.split("-")
	if parts.size() != 3:
		return iso
	return "%s.%s.%s" % [parts[2], parts[1], parts[0]]
