extends Control
## Main menu: start a skirmish (against the Order AI, easy or normal), the campaign missions
## (at the same difficulty), load a saved mission, how to play, settings, quit. The first
## scene the game opens.

const GAME_SCENE := "res://game/main.tscn"
## Campaign missions, one button each, in campaign order.
const MISSIONS: Array[String] = ["gdl_01", "gdl_02", "gdl_03", "gdl_04"]
const BACKGROUND := preload("res://ui/art/menu_background.jpg")

var _title := Label.new()
var _subtitle := Label.new()
var _skirmish := Button.new()
var _campaign: Array[Button] = []
var _load := Button.new()
var _saves := VBoxContainer.new()
var _difficulty := OptionButton.new()
var _settings_button := Button.new()
var _help_button := Button.new()
var _quit := Button.new()
var _version := Label.new()
var _menu := VBoxContainer.new()
var _settings := SettingsPanel.new()
var _help := HelpPanel.new()
var _panel: PanelContainer


func _ready() -> void:
	GameSettings.ensure_loaded()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_backdrop()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	margin.add_theme_constant_override("margin_left", 96)
	add_child(margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	_title.theme_type_variation = &"Title"
	_title.add_theme_font_size_override("font_size", 84)
	column.add_child(_title)
	_subtitle.add_theme_font_size_override("font_size", 22)
	_subtitle.add_theme_color_override("font_color", Color(0.93, 0.84, 0.66))
	column.add_child(_subtitle)
	var rule := ColorRect.new()
	rule.color = Color(0.75, 0.6, 0.35, 0.8)
	rule.custom_minimum_size = Vector2(380, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(rule)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	column.add_child(gap)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(stack)
	var panel := PanelContainer.new()
	stack.add_child(panel)
	_menu.add_theme_constant_override("separation", 12)
	panel.add_child(_menu)
	_panel = panel
	for id in MISSIONS:
		var mission := Button.new()
		mission.pressed.connect(_on_campaign.bind(id))
		_campaign.append(mission)
	var buttons: Array[Control] = []
	buttons.append_array(_campaign)
	buttons.append_array([_skirmish, _difficulty, _load, _help_button, _settings_button, _quit])
	for b: Control in buttons:
		b.custom_minimum_size = Vector2(340, 50)
		_menu.add_child(b)
	_menu.add_child(_saves)
	_load.pressed.connect(_list_saves)
	for level in GameSettings.DIFFICULTIES:
		_difficulty.add_item(String(level))
	_difficulty.selected = maxi(GameSettings.DIFFICULTIES.find(GameSettings.ai_difficulty), 0)
	_difficulty.item_selected.connect(_on_difficulty)
	_skirmish.pressed.connect(_on_skirmish)
	_settings_button.pressed.connect(_show_settings.bind(true))
	_help_button.pressed.connect(_help.open)
	_quit.pressed.connect(func() -> void: get_tree().quit())
	_settings.visible = false
	_settings.closed.connect(_show_settings.bind(false))
	stack.add_child(_settings)
	add_child(_help)
	_version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_version.position = Vector2(16, -36)
	_version.modulate = Color(1, 1, 1, 0.6)
	add_child(_version)
	var game_name: String = ProjectSettings.get_setting("application/config/name")
	var version: String = ProjectSettings.get_setting("application/config/version")
	_version.text = "%s %s" % [game_name, version]
	_retranslate()
	_skirmish.grab_focus.call_deferred()


## The evening court (tools/art/menu_scene.py) behind a shade that darkens the menu side.
func _build_backdrop() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.08, 0.06)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var art := TextureRect.new()
	art.texture = BACKGROUND
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(art)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.05, 0.035, 0.02, 0.88))
	gradient.set_color(1, Color(0.05, 0.035, 0.02, 0.0))
	gradient.add_point(0.35, Color(0.05, 0.035, 0.02, 0.6))
	var shade_tex := GradientTexture2D.new()
	shade_tex.gradient = gradient
	shade_tex.width = 256
	shade_tex.height = 4
	shade_tex.fill_to = Vector2(1, 0)
	var shade := TextureRect.new()
	shade.texture = shade_tex
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	shade.anchor_right = 0.62
	add_child(shade)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_retranslate()


func _retranslate() -> void:
	_title.text = tr("Pogranichie")
	_subtitle.text = tr("Grand Duchy of Lithuania against the Teutonic Order")
	_skirmish.text = tr("Skirmish")
	for i in MISSIONS.size():
		_campaign[i].text = tr("Campaign: %s") % tr(MissionDef.load_id(MISSIONS[i]).title)
	_load.text = tr("Load game")
	# The locale can change before _ready() has filled the list (GameSettings.ensure_loaded).
	var levels := [tr("Opponent: easy"), tr("Opponent: normal")]
	for i in mini(levels.size(), _difficulty.item_count):
		_difficulty.set_item_text(i, levels[i])
	_settings_button.text = tr("Settings")
	_help_button.text = tr("How to play")
	_quit.text = tr("Quit")


func _show_settings(on: bool) -> void:
	_panel.visible = not on
	_settings.visible = on


func _on_difficulty(index: int) -> void:
	GameSettings.ai_difficulty = GameSettings.DIFFICULTIES[index]
	GameSettings.save()


func _on_skirmish() -> void:
	GameSettings.mission_id = ""
	GameSettings.load_path = ""
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_campaign(id: String) -> void:
	GameSettings.mission_id = id
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
