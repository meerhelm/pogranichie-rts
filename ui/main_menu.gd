extends Control
## Main menu: start a skirmish (against the Order AI, easy or normal), the campaign mission
## (M9, at the same difficulty), load a saved mission, settings, quit. The first scene the game
## opens.

const GAME_SCENE := "res://game/main.tscn"
## The prototype's one campaign mission.
const MISSION := "gdl_01"

var _title := Label.new()
var _subtitle := Label.new()
var _skirmish := Button.new()
var _campaign := Button.new()
var _load := Button.new()
var _saves := VBoxContainer.new()
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
	_title.theme_type_variation = &"Title"
	_title.add_theme_font_size_override("font_size", 64)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(_title)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(_subtitle)
	for b: Button in [_campaign, _skirmish, _difficulty, _load, _settings_button, _quit]:
		b.custom_minimum_size = Vector2(320, 48)
		_menu.add_child(b)
	_menu.add_child(_saves)
	_campaign.pressed.connect(_on_campaign)
	_load.pressed.connect(_list_saves)
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
	_campaign.text = tr("Campaign: %s") % tr(MissionDef.load_id(MISSION).title)
	_load.text = tr("Load game")
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
	GameSettings.mission_id = ""
	GameSettings.load_path = ""
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_campaign() -> void:
	GameSettings.mission_id = MISSION
	GameSettings.mission_difficulty = String(GameSettings.ai_difficulty)
	GameSettings.load_path = ""
	get_tree().change_scene_to_file(GAME_SCENE)


func _list_saves() -> void:
	for child in _saves.get_children():
		_saves.remove_child(child)
		child.queue_free()
	var paths := SimSave.list()
	if paths.is_empty():
		var none := Label.new()
		none.text = tr("No saved games")
		_saves.add_child(none)
	for path in paths:
		var head := SimSave.read_header(path)
		var b := Button.new()
		b.text = (
			"%s · %s"
			% [tr(str(head.get("title", path.get_file()))), UiText.clock(int(head.get("tick", 0)))]
		)
		b.pressed.connect(
			func() -> void:
				GameSettings.load_path = path
				GameSettings.mission_id = str(head.get("mission_id", ""))
				get_tree().change_scene_to_file(GAME_SCENE)
		)
		_saves.add_child(b)
