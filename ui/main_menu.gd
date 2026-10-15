extends Control
## Main menu: start a skirmish (against the Order AI, easy or normal), settings, quit. The first
## scene the game opens.

const GAME_SCENE := "res://game/main.tscn"

var _title := Label.new()
var _subtitle := Label.new()
var _skirmish := Button.new()
var _difficulty := OptionButton.new()
var _settings_button := Button.new()
var _quit := Button.new()
var _version := Label.new()
var _menu := VBoxContainer.new()
var _settings := SettingsPanel.new()


func _ready() -> void:
	GameSettings.ensure_loaded()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.11, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var stack := VBoxContainer.new()
	center.add_child(stack)
	_menu.add_theme_constant_override("separation", 14)
	stack.add_child(_menu)
	_title.add_theme_font_size_override("font_size", 64)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(_title)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(_subtitle)
	for b: Button in [_skirmish, _difficulty, _settings_button, _quit]:
		b.custom_minimum_size = Vector2(320, 48)
		_menu.add_child(b)
	for level in GameSettings.DIFFICULTIES:
		_difficulty.add_item(String(level))
	_difficulty.selected = maxi(GameSettings.DIFFICULTIES.find(GameSettings.ai_difficulty), 0)
	_difficulty.item_selected.connect(_on_difficulty)
	_skirmish.pressed.connect(_on_skirmish)
	_settings_button.pressed.connect(_show_settings.bind(true))
	_quit.pressed.connect(func() -> void: get_tree().quit())
	_settings.visible = false
	_settings.closed.connect(_show_settings.bind(false))
	stack.add_child(_settings)
	_version.position = Vector2(16, 16)
	add_child(_version)
	var game_name: String = ProjectSettings.get_setting("application/config/name")
	var version: String = ProjectSettings.get_setting("application/config/version")
	_version.text = "%s %s" % [game_name, version]
	_retranslate()
	_skirmish.grab_focus.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_retranslate()


func _retranslate() -> void:
	_title.text = tr("Pogranichie")
	_subtitle.text = tr("Grand Duchy of Lithuania against the Teutonic Order")
	_skirmish.text = tr("Skirmish")
	_difficulty.set_item_text(0, tr("Opponent: easy"))
	_difficulty.set_item_text(1, tr("Opponent: normal"))
	_settings_button.text = tr("Settings")
	_quit.text = tr("Quit")


func _show_settings(on: bool) -> void:
	_menu.visible = not on
	_settings.visible = on


func _on_difficulty(index: int) -> void:
	GameSettings.ai_difficulty = GameSettings.DIFFICULTIES[index]
	GameSettings.save()


func _on_skirmish() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)
