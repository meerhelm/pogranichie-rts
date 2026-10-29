extends Control
## Main menu (main_menu.tscn: the evening court from tools/art/menu_scene.py behind a shade, the
## title and the pages). The first page: campaign, single player, network play (NetLobby), load
## a saved game, how to play, about the game (version and what each build added), settings, quit.
## The game's version stands under the title. Campaign leads to the choice of a country (GDL or the
## Crown) and then to its missions, which open one after another as they are won (CampaignProgress);
## single player is the skirmish against the Order AI. Esc steps back a page. Coming back from a
## campaign mission, the menu opens on that campaign's missions. The first scene the game opens.
## Typing CampaignProgress.CHEAT_CODE on any page opens (or closes back) every campaign mission.

enum Page { MAIN, COUNTRIES, MISSIONS, SINGLE, NET }

const GAME_SCENE := "res://game/main.tscn"
## The main menu theme; the menu stays silent while the file is missing.
const MENU_MUSIC := "res://audio/music/menu_1.ogg"
## Colour of the notes under countries, missions and maps.
const NOTE_COLOR := Color(0.85, 0.72, 0.45)
const BUTTON_SIZE := Vector2(340, 50)
const MISSION_SIZE := Vector2(460, 46)

## The last letters typed, for the cheat code.
var _typed := ""
## Per campaign (CampaignProgress.ORDER): its button and the line under it.
var _country: Array[Button] = []
var _country_note: Array[Label] = []
## The shown campaign's mission buttons and their state lines, in mission order.
var _campaign: Array[Button] = []
var _mission_state: Array[Label] = []
var _back: Array[Button] = []
var _page := Page.MAIN
## The campaign the missions page shows.
var _shown := "gdl"
## The «Network play» page.
var _net := NetLobby.new()
## Set once _ready() has made every control; the locale can change before that.
var _built := false

@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _campaign_button: Button = %CampaignButton
@onready var _single_button: Button = %SingleButton
@onready var _network: Button = %Network
@onready var _load: Button = %Load
@onready var _saves: VBoxContainer = %Saves
@onready var _settings_button: Button = %SettingsButton
@onready var _help_button: Button = %HelpButton
@onready var _about_button: Button = %AboutButton
@onready var _quit: Button = %Quit
@onready var _version: Label = %Version
## A short line that says the cheat was turned on or off.
@onready var _cheat_note: Label = %CheatNote
## The pages; one shows at a time.
@onready var _menu: VBoxContainer = %Menu
@onready var _countries: VBoxContainer = %Countries
@onready var _missions: VBoxContainer = %Missions
@onready var _single: VBoxContainer = %Single
@onready var _countries_head: Label = %CountriesHead
@onready var _missions_head: Label = %MissionsHead
@onready var _missions_note: Label = %MissionsNote
@onready var _mission_list: VBoxContainer = %MissionList
@onready var _campaign_difficulty: OptionButton = %CampaignDifficulty
@onready var _single_head: Label = %SingleHead
@onready var _skirmish: Button = %Skirmish
@onready var _difficulty: OptionButton = %Difficulty
@onready var _my_faction: OptionButton = %MyFaction
@onready var _enemy_faction: OptionButton = %EnemyFaction
## The skirmish map (SkirmishMaps) and its history note.
@onready var _map: OptionButton = %Map
@onready var _map_note: Label = %MapNote
@onready var _settings: SettingsPanel = %Settings
@onready var _help: HelpPanel = %Help
@onready var _about: AboutPanel = %About
@onready var _panel: PanelContainer = %Panel


func _ready() -> void:
	GameSettings.ensure_loaded()
	_build_main()
	_build_countries()
	_build_missions()
	_build_single()
	_build_net()
	_settings.closed.connect(_show_settings.bind(false))
	_start_music()
	Sfx.ensure()
	_built = true
	var back_to := CampaignProgress.campaign_of(GameSettings.mission_id)
	if back_to.is_empty():
		_show_page(Page.MAIN)
	else:
		_open_campaign(back_to)
	_retranslate()


## The menu theme (audio/music/menu_1.ogg) on the Music bus, looped, fading in.
func _start_music() -> void:
	if not ResourceLoader.exists(MENU_MUSIC):
		return
	var stream := load(MENU_MUSIC) as AudioStreamOggVorbis
	if stream == null:
		return
	stream.loop = true
	var player := AudioStreamPlayer.new()
	player.name = "Music"  # notr
	player.stream = stream
	player.bus = &"Music"
	player.volume_db = -40.0
	add_child(player)
	player.play()
	create_tween().tween_property(player, "volume_db", 0.0, 2.5)


func _build_main() -> void:
	_campaign_button.pressed.connect(_show_page.bind(Page.COUNTRIES))
	_single_button.pressed.connect(_show_page.bind(Page.SINGLE))
	_load.pressed.connect(_list_saves)
	_settings_button.pressed.connect(_show_settings.bind(true))
	_help_button.pressed.connect(_help.open)
	_about_button.pressed.connect(_about.open)
	_quit.pressed.connect(func() -> void: get_tree().quit())


func _build_countries() -> void:
	var back: Button = %CountriesBack
	for c: String in CampaignProgress.ORDER:
		var b := Button.new()
		b.custom_minimum_size = BUTTON_SIZE
		b.pressed.connect(_open_campaign.bind(c))
		_countries.add_child(b)
		_country.append(b)
		var note := Label.new()
		note.add_theme_color_override("font_color", NOTE_COLOR)
		_countries.add_child(note)
		_country_note.append(note)
	_countries.move_child(back, -1)
	_add_back(back, Page.MAIN)


func _build_missions() -> void:
	_fill_difficulty(_campaign_difficulty)
	_add_back(%MissionsBack as Button, Page.COUNTRIES)


func _build_single() -> void:
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
	_add_back(%SingleBack as Button, Page.MAIN)


func _build_net() -> void:
	_single.add_sibling(_net)
	_network.disabled = false
	_network.pressed.connect(_show_page.bind(Page.NET))
	_net.back.connect(_show_page.bind(Page.MAIN))
	_net.start.connect(_on_net_start)


func _add_back(b: Button, to: Page) -> void:
	b.pressed.connect(_show_page.bind(to))
	_back.append(b)


func _fill_difficulty(box: OptionButton) -> void:
	for level in GameSettings.DIFFICULTIES:
		box.add_item(String(level))
	box.item_selected.connect(_on_difficulty)


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
		Page.NET:
			_net.cancel()
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
	_network.text = tr("Network play")
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
	var levels: Array[String] = [tr("Opponent: easy"), tr("Opponent: normal")]
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
	var year: int = m.get("year", 0)
	return "%s, %d" % [title, year] if year > 0 else title


func _show_map_note() -> void:
	_map_note.text = tr(str(SkirmishMaps.find(GameSettings.skirmish_map)["note"]))


func _show_page(page: Page) -> void:
	_page = page
	_menu.visible = page == Page.MAIN
	_countries.visible = page == Page.COUNTRIES
	_missions.visible = page == Page.MISSIONS
	_single.visible = page == Page.SINGLE
	_net.visible = page == Page.NET
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
		Page.NET:
			_net.open()
			return
	focus.grab_focus.call_deferred()


func _open_campaign(campaign: String) -> void:
	_shown = campaign
	_show_page(Page.MISSIONS)


## Each country's name and, under it, its campaign and how many of its missions are won.
func _fill_countries() -> void:
	for i in CampaignProgress.ORDER.size():
		var c := CampaignProgress.ORDER[i]
		_country[i].text = UiText.name_of(CampaignProgress.FACTION[c])
		var missions: Array = CampaignProgress.MISSIONS[c]
		var total := missions.size()
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


## Both network games agreed: the game scene plays the session's skirmish (NetSession.current).
func _on_net_start() -> void:
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
		var tick: int = head.get("tick", 0)
		var b := Button.new()
		b.text = "%s · %s" % [tr(str(head.get("title", path.get_file()))), UiText.clock(tick)]
		b.pressed.connect(
			func() -> void:
				GameSettings.load_path = path
				GameSettings.mission_id = str(head.get("mission_id", ""))
				get_tree().change_scene_to_file(GAME_SCENE)
		)
		_saves.add_child(b)
