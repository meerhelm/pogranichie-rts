extends Control
## Main menu. The first page: campaign, single player, network play (not made yet), load a saved
## game, how to play, about the game (version and what each build added), settings, quit. The
## game's version stands under the title. Campaign leads to the choice of a country (GDL or the
## Crown) and then to its missions, which open one after another as they are won
## (CampaignProgress); single player is the skirmish against the Order AI. Esc steps back a page.
## Coming back from a campaign mission, the menu opens on that campaign's missions. The first scene
## the game opens.
## Typing CampaignProgress.CHEAT_CODE on any page opens (or closes back) every campaign mission.

enum Page { MAIN, COUNTRIES, MISSIONS, SINGLE }

const GAME_SCENE := "res://game/main.tscn"
const BACKGROUND := preload("res://ui/art/menu_background_grok.jpg")
const BUTTON_SIZE := Vector2(340, 50)
const MISSION_SIZE := Vector2(460, 46)

var _title := Label.new()
var _subtitle := Label.new()
var _campaign_button := Button.new()
var _single_button := Button.new()
var _network := Button.new()
var _load := Button.new()
var _saves := VBoxContainer.new()
var _settings_button := Button.new()
var _help_button := Button.new()
var _about_button := Button.new()
var _quit := Button.new()
var _version := Label.new()
## A short line that says the cheat was turned on or off.
var _cheat_note := Label.new()
## The last letters typed, for the cheat code.
var _typed := ""
## The pages; one shows at a time.
var _menu := VBoxContainer.new()
var _countries := VBoxContainer.new()
var _missions := VBoxContainer.new()
var _single := VBoxContainer.new()
var _countries_head := Label.new()
## Per campaign (CampaignProgress.ORDER): its button and the line under it.
var _country: Array[Button] = []
var _country_note: Array[Label] = []
var _missions_head := Label.new()
var _missions_note := Label.new()
var _mission_list := VBoxContainer.new()
## The shown campaign's mission buttons and their state lines, in mission order.
var _campaign: Array[Button] = []
var _mission_state: Array[Label] = []
var _campaign_difficulty := OptionButton.new()
var _single_head := Label.new()
var _skirmish := Button.new()
var _difficulty := OptionButton.new()
var _my_faction := OptionButton.new()
var _enemy_faction := OptionButton.new()
## The skirmish map (SkirmishMaps) and its history note.
var _map := OptionButton.new()
var _map_note := Label.new()
var _back: Array[Button] = []
var _settings := SettingsPanel.new()
var _help := HelpPanel.new()
var _about := AboutPanel.new()
var _panel: PanelContainer
var _page := Page.MAIN
## The campaign the missions page shows.
var _shown := "gdl"
## Set once _ready() has made every control; the locale can change before that.
var _built := false


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
	_version.add_theme_font_size_override("font_size", 22)
	_version.add_theme_color_override("font_color", Color(0.85, 0.72, 0.45))
	column.add_child(_version)
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
	var pages := VBoxContainer.new()
	panel.add_child(pages)
	_panel = panel
	for page: VBoxContainer in [_menu, _countries, _missions, _single]:
		page.add_theme_constant_override("separation", 12)
		pages.add_child(page)
	_build_main()
	_build_countries()
	_build_missions()
	_build_single()
	_settings.visible = false
	_settings.closed.connect(_show_settings.bind(false))
	stack.add_child(_settings)
	_cheat_note.add_theme_font_size_override("font_size", 22)
	_cheat_note.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
	_cheat_note.visible = false
	column.add_child(_cheat_note)
	add_child(_help)
	add_child(_about)
	_built = true
	var back_to := CampaignProgress.campaign_of(GameSettings.mission_id)
	if back_to.is_empty():
		_show_page(Page.MAIN)
	else:
		_open_campaign(back_to)
	_retranslate()


func _build_main() -> void:
	for b: Button in [
		_campaign_button,
		_single_button,
		_network,
		_load,
		_help_button,
		_about_button,
		_settings_button,
		_quit
	]:
		b.custom_minimum_size = BUTTON_SIZE
		_menu.add_child(b)
	_menu.add_child(_saves)
	_menu.move_child(_saves, _load.get_index() + 1)
	_network.disabled = true
	_campaign_button.pressed.connect(_show_page.bind(Page.COUNTRIES))
	_single_button.pressed.connect(_show_page.bind(Page.SINGLE))
	_load.pressed.connect(_list_saves)
	_settings_button.pressed.connect(_show_settings.bind(true))
	_help_button.pressed.connect(_help.open)
	_about_button.pressed.connect(_about.open)
	_quit.pressed.connect(func() -> void: get_tree().quit())


func _build_countries() -> void:
	_heading(_countries_head)
	_countries.add_child(_countries_head)
	for c: String in CampaignProgress.ORDER:
		var b := Button.new()
		b.custom_minimum_size = BUTTON_SIZE
		b.pressed.connect(_open_campaign.bind(c))
		_countries.add_child(b)
		_country.append(b)
		var note := Label.new()
		note.add_theme_color_override("font_color", Color(0.85, 0.72, 0.45))
		_countries.add_child(note)
		_country_note.append(note)
	_add_back(_countries, Page.MAIN)


func _build_missions() -> void:
	_heading(_missions_head)
	_missions.add_child(_missions_head)
	_missions_note.add_theme_color_override("font_color", Color(0.85, 0.72, 0.45))
	_missions.add_child(_missions_note)
	_mission_list.add_theme_constant_override("separation", 8)
	_missions.add_child(_mission_list)
	_fill_difficulty(_campaign_difficulty)
	_campaign_difficulty.custom_minimum_size = BUTTON_SIZE
	_missions.add_child(_campaign_difficulty)
	_add_back(_missions, Page.COUNTRIES)


func _build_single() -> void:
	_heading(_single_head)
	_single.add_child(_single_head)
	for b: Control in [_skirmish, _map, _my_faction, _enemy_faction, _difficulty]:
		b.custom_minimum_size = BUTTON_SIZE
		_single.add_child(b)
	_map_note.add_theme_color_override("font_color", Color(0.85, 0.72, 0.45))
	_map_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_map_note.custom_minimum_size = Vector2(MISSION_SIZE.x, 0)
	_single.add_child(_map_note)
	_single.move_child(_map_note, _map.get_index() + 1)
	for m: Dictionary in SkirmishMaps.all():
		_map.add_item(str(m["id"]))
	_map.item_selected.connect(_on_map)
	_fill_difficulty(_difficulty)
	for box: OptionButton in [_my_faction, _enemy_faction]:
		for f in SkirmishSetup.FACTIONS:
			box.add_item(String(f))
	_my_faction.item_selected.connect(_on_faction.bind(true))
	_enemy_faction.item_selected.connect(_on_faction.bind(false))
	_skirmish.pressed.connect(_on_skirmish)
	_add_back(_single, Page.MAIN)


func _heading(label: Label) -> void:
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.93, 0.84, 0.66))


func _add_back(page: VBoxContainer, to: Page) -> void:
	var b := Button.new()
	b.custom_minimum_size = BUTTON_SIZE
	b.pressed.connect(_show_page.bind(to))
	page.add_child(b)
	_back.append(b)


func _fill_difficulty(box: OptionButton) -> void:
	for level in GameSettings.DIFFICULTIES:
		box.add_item(String(level))
	box.item_selected.connect(_on_difficulty)


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


func _unhandled_input(event: InputEvent) -> void:
	_check_cheat(event)
	if not event.is_action_pressed("ui_cancel") or _settings.visible:
		return
	if _help.visible or _about.visible:
		return
	match _page:
		Page.COUNTRIES, Page.SINGLE:
			_show_page(Page.MAIN)
		Page.MISSIONS:
			_show_page(Page.COUNTRIES)
		_:
			return
	get_viewport().set_input_as_handled()


## Collects typed letters by key position (any keyboard layout); the cheat code toggles every
## campaign mission open and the shown page is refilled.
func _check_cheat(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var code := key.physical_keycode
	if code < KEY_A or code > KEY_Z:
		_typed = ""
		return
	_typed += char(code)
	var word := CampaignProgress.CHEAT_CODE
	_typed = _typed.right(word.length())
	if _typed != word:
		return
	_typed = ""
	var on := not CampaignProgress.all_open()
	CampaignProgress.set_all_open(on)
	_cheat_note.text = (
		tr("All campaign missions are open") if on else tr("Missions open as they are won again")
	)
	_cheat_note.visible = true
	get_tree().create_timer(4.0).timeout.connect(_hide_cheat_note.bind(_cheat_note.text))
	_fill_countries()
	_fill_missions()
	get_viewport().set_input_as_handled()


func _hide_cheat_note(text: String) -> void:
	if _cheat_note.text == text:
		_cheat_note.visible = false


func _retranslate() -> void:
	if not _built:
		return
	_title.text = tr("Pogranichie")
	_subtitle.text = tr("Grand Duchy of Lithuania against the Teutonic Order")
	_campaign_button.text = tr("Campaign")
	_single_button.text = tr("Single player")
	_network.text = tr("Network play (coming later)")
	_load.text = tr("Load game")
	_settings_button.text = tr("Settings")
	_help_button.text = tr("How to play")
	_about_button.text = tr("About the game")
	_version.text = tr("Version %s") % AboutPanel.version()
	_quit.text = tr("Quit")
	_countries_head.text = tr("Choose a country")
	_single_head.text = tr("Single player")
	_skirmish.text = tr("Skirmish")
	for b in _back:
		b.text = tr("Back")
	# The locale can change before _ready() has filled the lists (GameSettings.ensure_loaded).
	var levels := [tr("Opponent: easy"), tr("Opponent: normal")]
	for box: OptionButton in [_difficulty, _campaign_difficulty]:
		for i in mini(levels.size(), box.item_count):
			box.set_item_text(i, levels[i])
	for i in mini(SkirmishSetup.FACTIONS.size(), _my_faction.item_count):
		var faction := UiText.name_of(SkirmishSetup.FACTIONS[i])
		_my_faction.set_item_text(i, tr("You play: %s") % faction)
		_enemy_faction.set_item_text(i, tr("Opponent plays: %s") % faction)
	var maps := SkirmishMaps.all()
	for i in mini(maps.size(), _map.item_count):
		var m: Dictionary = maps[i]
		_map.set_item_text(i, tr("Map: %s") % _map_title(m))
	_show_map_note()
	_fill_countries()
	_fill_missions()


## «Grunwald, 1410»: the map's title and the year of its battle (none for the prototype map).
func _map_title(m: Dictionary) -> String:
	var title := tr(str(m["title"]))
	var year := int(m.get("year", 0))
	return "%s, %d" % [title, year] if year > 0 else title


func _show_map_note() -> void:
	_map_note.text = tr(str(SkirmishMaps.find(GameSettings.skirmish_map)["note"]))


func _show_page(page: Page) -> void:
	_page = page
	_menu.visible = page == Page.MAIN
	_countries.visible = page == Page.COUNTRIES
	_missions.visible = page == Page.MISSIONS
	_single.visible = page == Page.SINGLE
	var level := maxi(GameSettings.DIFFICULTIES.find(GameSettings.ai_difficulty), 0)
	_difficulty.selected = level
	_campaign_difficulty.selected = level
	_my_faction.selected = maxi(SkirmishSetup.FACTIONS.find(GameSettings.player_faction), 0)
	_enemy_faction.selected = maxi(SkirmishSetup.FACTIONS.find(GameSettings.enemy_faction), 0)
	_map.selected = maxi(SkirmishMaps.ids().find(GameSettings.skirmish_map), 0)
	var focus: Control = _campaign_button
	match page:
		Page.COUNTRIES:
			_fill_countries()
			focus = _country[CampaignProgress.ORDER.find(_shown)]
		Page.MISSIONS:
			_fill_missions()
			focus = _back[1]
			for b in _campaign:
				if not b.disabled:
					focus = b
		Page.SINGLE:
			focus = _skirmish
	focus.grab_focus.call_deferred()


func _open_campaign(campaign: String) -> void:
	_shown = campaign
	_show_page(Page.MISSIONS)


## Each country's name and, under it, its campaign and how many of its missions are won.
func _fill_countries() -> void:
	for i in CampaignProgress.ORDER.size():
		var c := CampaignProgress.ORDER[i]
		_country[i].text = UiText.name_of(CampaignProgress.FACTION[c])
		var total: int = (CampaignProgress.MISSIONS[c] as Array).size()
		_country_note[i].text = (
			"«%s» · %s"
			% [
				CampaignProgress.campaign_name(c),
				tr("missions won: %d of %d") % [CampaignProgress.won_count(c), total]
			]
		)


## The shown campaign's missions, one row each: the mission and its state (won, open, locked,
## not made yet). Remade on every visit, since winning a mission opens the next.
func _fill_missions() -> void:
	for child in _mission_list.get_children():
		_mission_list.remove_child(child)
		child.queue_free()
	_campaign.clear()
	_mission_state.clear()
	_missions_head.text = UiText.name_of(CampaignProgress.FACTION[_shown])
	_missions_note.text = "«%s»" % CampaignProgress.campaign_name(_shown)
	for id: String in CampaignProgress.MISSIONS[_shown]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var b := Button.new()
		b.custom_minimum_size = MISSION_SIZE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = tr(CampaignProgress.title_key(id))
		var state := Label.new()
		state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if not CampaignProgress.is_made(id):
			b.disabled = true
			state.text = tr("not made yet")
			state.add_theme_color_override("font_color", Color(0.6, 0.55, 0.48))
		elif CampaignProgress.is_won(id):
			state.text = tr("won")
			state.add_theme_color_override("font_color", Color(0.6, 0.85, 0.45))
		elif CampaignProgress.is_open(id):
			state.text = tr("open")
			state.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
		else:
			b.disabled = true
			state.text = tr("win the previous mission to open")
			state.add_theme_color_override("font_color", Color(0.6, 0.55, 0.48))
		b.pressed.connect(_on_campaign.bind(id))
		row.add_child(b)
		row.add_child(state)
		_mission_list.add_child(row)
		_campaign.append(b)
		_mission_state.append(state)


func _show_settings(on: bool) -> void:
	_panel.visible = not on
	_settings.visible = on


func _on_difficulty(index: int) -> void:
	GameSettings.ai_difficulty = GameSettings.DIFFICULTIES[index]
	GameSettings.save()
	_difficulty.selected = index
	_campaign_difficulty.selected = index


func _on_faction(index: int, mine: bool) -> void:
	if mine:
		GameSettings.player_faction = SkirmishSetup.FACTIONS[index]
	else:
		GameSettings.enemy_faction = SkirmishSetup.FACTIONS[index]
	GameSettings.save()


func _on_map(index: int) -> void:
	GameSettings.skirmish_map = SkirmishMaps.ids()[index]
	GameSettings.save()
	_show_map_note()


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
