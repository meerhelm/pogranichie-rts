class_name SettingsPanel
extends PanelContainer
## Settings window for the main menu and the pause menu: language, edge scrolling, fullscreen,
## text size and the skirmish hints.
## Changes apply at once and are saved; texts follow the language as it changes.

signal closed
## The skirmish hints were turned on or off.
signal hints_changed

var _title := Label.new()
var _language_label := Label.new()
var _language := OptionButton.new()
var _edge := CheckBox.new()
var _fullscreen := CheckBox.new()
var _text_label := Label.new()
var _text_size := OptionButton.new()
var _hints := CheckBox.new()
var _back := Button.new()


func _ready() -> void:
	GameSettings.ensure_loaded()
	custom_minimum_size = Vector2(420, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	_title.theme_type_variation = &"Title"
	_title.add_theme_font_size_override("font_size", 28)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	var row := HBoxContainer.new()
	row.add_child(_language_label)
	_language_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for name in GameSettings.LANGUAGE_NAMES:
		_language.add_item(name)
	# Language names stay in their own language whatever the locale.
	_language.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_language.select(GameSettings.LANGUAGES.find(GameSettings.language))
	_language.item_selected.connect(_on_language)
	row.add_child(_language)
	box.add_child(row)
	_edge.button_pressed = GameSettings.edge_scroll
	_edge.toggled.connect(_on_edge)
	box.add_child(_edge)
	_fullscreen.button_pressed = GameSettings.fullscreen
	_fullscreen.toggled.connect(_on_fullscreen)
	box.add_child(_fullscreen)
	var text_row := HBoxContainer.new()
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_row.add_child(_text_label)
	for i in GameSettings.TEXT_SIZES.size():
		_text_size.add_item("")
	_text_size.select(GameSettings.text_size)
	_text_size.item_selected.connect(_on_text_size)
	text_row.add_child(_text_size)
	box.add_child(text_row)
	_hints.button_pressed = GameSettings.hints
	_hints.toggled.connect(_on_hints)
	box.add_child(_hints)
	_back.pressed.connect(func() -> void: closed.emit())
	box.add_child(_back)
	_retranslate()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_retranslate()


func _retranslate() -> void:
	_title.text = tr("Settings")
	_language_label.text = tr("Language")
	_edge.text = tr("Scroll at the screen edge")
	_fullscreen.text = tr("Fullscreen")
	_text_label.text = tr("Text size")
	var sizes := [tr("Small"), tr("Normal"), tr("Large"), tr("Very large")]
	for i in sizes.size():
		_text_size.set_item_text(i, sizes[i])
	_hints.text = tr("Hints in skirmish")
	_back.text = tr("Back")


func _on_language(index: int) -> void:
	GameSettings.language = GameSettings.LANGUAGES[index]
	GameSettings.apply()
	GameSettings.save()


func _on_edge(on: bool) -> void:
	GameSettings.edge_scroll = on
	GameSettings.save()


func _on_fullscreen(on: bool) -> void:
	GameSettings.fullscreen = on
	GameSettings.apply()
	GameSettings.save()


func _on_text_size(index: int) -> void:
	GameSettings.text_size = index
	GameSettings.apply()
	GameSettings.save()


func _on_hints(on: bool) -> void:
	GameSettings.hints = on
	GameSettings.save()
	hints_changed.emit()
