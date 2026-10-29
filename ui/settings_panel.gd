class_name SettingsPanel
extends PanelContainer
## Settings window for the main menu and the pause menu (settings_panel.tscn): language, edge
## scrolling, fullscreen, text size, music volume and the skirmish hints.
## Changes apply at once and are saved; texts follow the language as it changes.

signal closed
## The skirmish hints were turned on or off.
signal hints_changed

const SCENE := "res://ui/settings_panel.tscn"

@onready var _title: Label = %Title
@onready var _language_label: Label = %LanguageLabel
@onready var _language: OptionButton = %Language
@onready var _edge: CheckBox = %Edge
@onready var _edge_speed_label: Label = %EdgeSpeedLabel
@onready var _edge_speed: OptionButton = %EdgeSpeed
@onready var _fullscreen: CheckBox = %Fullscreen
@onready var _text_label: Label = %TextLabel
@onready var _text_size: OptionButton = %TextSize
@onready var _music_label: Label = %MusicLabel
@onready var _music: HSlider = %Music
@onready var _hints: CheckBox = %Hints
@onready var _back: Button = %Back


## A new settings window (the scene, laid out in settings_panel.tscn).
static func create() -> SettingsPanel:
	return (load(SCENE) as PackedScene).instantiate()


func _ready() -> void:
	GameSettings.ensure_loaded()
	for language_name: String in GameSettings.LANGUAGE_NAMES:
		_language.add_item(language_name)
	_language.select(GameSettings.LANGUAGES.find(GameSettings.language))
	_language.item_selected.connect(_on_language)
	_edge.button_pressed = GameSettings.edge_scroll
	_edge.toggled.connect(_on_edge)
	for i in GameSettings.EDGE_SPEEDS.size():
		_edge_speed.add_item("")
	_edge_speed.select(GameSettings.edge_speed)
	_edge_speed.item_selected.connect(_on_edge_speed)
	_fullscreen.button_pressed = GameSettings.fullscreen
	_fullscreen.toggled.connect(_on_fullscreen)
	for i in GameSettings.TEXT_SIZES.size():
		_text_size.add_item("")
	_text_size.select(GameSettings.text_size)
	_text_size.item_selected.connect(_on_text_size)
	_music.value = GameSettings.music_volume
	_music.value_changed.connect(_on_music)
	_hints.button_pressed = GameSettings.hints
	_hints.toggled.connect(_on_hints)
	_back.pressed.connect(func() -> void: closed.emit())
	_retranslate()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_retranslate()


func _retranslate() -> void:
	_title.text = tr("Settings")
	_language_label.text = tr("Language")
	_edge.text = tr("Scroll at the screen edge")
	_edge_speed_label.text = tr("Edge scrolling speed")
	var speeds: Array[String] = [tr("Slow"), tr("Medium"), tr("Fast"), tr("Very fast")]
	for i in mini(speeds.size(), _edge_speed.item_count):
		_edge_speed.set_item_text(i, speeds[i])
	_fullscreen.text = tr("Fullscreen")
	_text_label.text = tr("Text size")
	var sizes: Array[String] = [tr("Small"), tr("Normal"), tr("Large"), tr("Very large")]
	for i in mini(sizes.size(), _text_size.item_count):
		_text_size.set_item_text(i, sizes[i])
	_music_label.text = tr("Music volume")
	_hints.text = tr("Hints in skirmish")
	_back.text = tr("Back")


func _on_language(index: int) -> void:
	GameSettings.language = GameSettings.LANGUAGES[index]
	GameSettings.apply()
	GameSettings.save()


func _on_edge(on: bool) -> void:
	GameSettings.edge_scroll = on
	GameSettings.save()


func _on_edge_speed(index: int) -> void:
	GameSettings.edge_speed = index
	GameSettings.save()


func _on_fullscreen(on: bool) -> void:
	GameSettings.fullscreen = on
	GameSettings.apply()
	GameSettings.save()


func _on_text_size(index: int) -> void:
	GameSettings.text_size = index
	GameSettings.apply()
	GameSettings.save()


func _on_music(value: float) -> void:
	GameSettings.music_volume = roundi(value)
	GameSettings.apply_volume()
	GameSettings.save()


func _on_hints(on: bool) -> void:
	GameSettings.hints = on
	GameSettings.save()
	hints_changed.emit()
