class_name AboutPanel
extends Control
## «About the game»: the version and what each build added, newest first, from
## ui/changelog.json. Opened from the main menu; Esc or the button close it.

signal closed

const SCENE := "res://ui/about_panel.tscn"

const CHANGELOG := "res://ui/changelog.json"

@onready var _title: Label = %Title
@onready var _text: RichTextLabel = %Text
@onready var _close: Button = %Close


## A new window (the scene, laid out in about_panel.tscn).
static func create() -> AboutPanel:
	return (load(SCENE) as PackedScene).instantiate()


func _ready() -> void:
	_close.pressed.connect(close)
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
	UiAnim.pop_in(self, %Panel as Control)
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
