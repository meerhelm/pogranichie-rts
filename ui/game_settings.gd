class_name GameSettings
extends RefCounted
## Player settings: language, edge scrolling, fullscreen, text size, music volume, skirmish
## hints, and the skirmish AI's difficulty and both sides' factions last picked. Kept in
## user://settings.cfg and applied at start (main menu or game scene, whichever opens first).

const PATH := "user://settings.cfg"
## Locales the game ships (i18n/<locale>.po); English is the development language.
const LANGUAGES: Array[String] = ["en", "be", "pl", "uk", "lt"]
## Skirmish AI difficulties, easiest first.
const DIFFICULTIES: Array[StringName] = [&"easy", &"normal"]
## Each language's name in itself, shown in the language list untranslated.
const LANGUAGE_NAMES: Array[String] = [
	"English",  # notr
	"Беларуская",  # notr
	"Polski",  # notr
	"Українська",  # notr
	"Lietuvių",  # notr
]

## Interface font sizes the player picks from (the theme's default font size), smallest first.
const TEXT_SIZES: Array[int] = [16, 20, 24, 28]
## Edge scrolling speed multipliers the player picks from, slowest first.
const EDGE_SPEEDS: Array[float] = [0.6, 1.0, 1.5, 2.2]

## Where the settings are kept; tests point it elsewhere (tests/pre_run_hook.gd).
static var path := PATH
static var language := "en"
static var edge_scroll := true
## Index in EDGE_SPEEDS.
static var edge_speed := 1
static var fullscreen := false
## Index in TEXT_SIZES.
static var text_size := 1
## Music volume in percent (the Music bus of default_bus_layout.tres).
static var music_volume := 70
## Whether a skirmish shows the advisor's step-by-step hints.
static var hints := true
## AiProfile.difficulty of the skirmish opponent (ai/profiles/*_<difficulty>.tres).
static var ai_difficulty: StringName = &"normal"
## Skirmish factions (SkirmishSetup.FACTIONS): the player's and the AI opponent's.
static var player_faction: StringName = &"gdl"
static var enemy_faction: StringName = &"to"
## The skirmish map (SkirmishMaps).
static var skirmish_map := SkirmishSetup.MAP_ID
## The host's address last typed for network play (NetLobby).
static var net_address := ""
## The player's name in network play (NetLobby).
static var player_name := ""
## What the game scene opens (M9), set by the menus before switching to it: a campaign
## mission by id (empty: a skirmish), and a save to load instead (empty: a new game).
static var mission_id := ""
static var mission_difficulty := "normal"
static var load_path := ""
static var _loaded := false


## Loads the file once and applies it.
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		var lang: String = cfg.get_value("general", "language", language)
		language = lang if LANGUAGES.has(lang) else "en"
		edge_scroll = cfg.get_value("general", "edge_scroll", edge_scroll)
		var speed: int = cfg.get_value("general", "edge_speed", edge_speed)
		edge_speed = clampi(speed, 0, EDGE_SPEEDS.size() - 1)
		fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
		var size: int = cfg.get_value("video", "text_size", text_size)
		text_size = clampi(size, 0, TEXT_SIZES.size() - 1)
		hints = cfg.get_value("general", "hints", hints)
		var music: int = cfg.get_value("audio", "music", music_volume)
		music_volume = clampi(music, 0, 100)
		var level_name: String = cfg.get_value("skirmish", "ai_difficulty", String(ai_difficulty))
		var level := StringName(level_name)
		ai_difficulty = level if DIFFICULTIES.has(level) else &"normal"
		var mine_name: String = cfg.get_value("skirmish", "faction", String(player_faction))
		var mine := StringName(mine_name)
		player_faction = mine if SkirmishSetup.FACTIONS.has(mine) else &"gdl"
		var theirs_name: String = cfg.get_value("skirmish", "enemy", String(enemy_faction))
		var theirs := StringName(theirs_name)
		enemy_faction = theirs if SkirmishSetup.FACTIONS.has(theirs) else &"to"
		var map: String = cfg.get_value("skirmish", "map", skirmish_map)
		skirmish_map = map if SkirmishMaps.has(map) else SkirmishSetup.MAP_ID
		net_address = str(cfg.get_value("network", "address", net_address))
		player_name = str(cfg.get_value("network", "name", player_name))
	apply()


## Edge scrolling speed multiplier picked in the settings.
static func edge_speed_factor() -> float:
	return EDGE_SPEEDS[edge_speed]


static func apply() -> void:
	TranslationServer.set_locale(language)
	apply_volume()
	var theme := ThemeDB.get_project_theme()
	if theme != null and theme.default_font_size != TEXT_SIZES[text_size]:
		theme.default_font_size = TEXT_SIZES[text_size]
	if DisplayServer.get_name() == "headless":
		return
	var mode := (
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


## Sets the Music bus to the music volume (0 % mutes it).
static func apply_volume() -> void:
	var bus := AudioServer.get_bus_index(&"Music")
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, music_volume <= 0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(music_volume, 1) / 100.0))


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "language", language)
	cfg.set_value("general", "edge_scroll", edge_scroll)
	cfg.set_value("general", "edge_speed", edge_speed)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "text_size", text_size)
	cfg.set_value("general", "hints", hints)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("skirmish", "ai_difficulty", String(ai_difficulty))
	cfg.set_value("skirmish", "faction", String(player_faction))
	cfg.set_value("skirmish", "enemy", String(enemy_faction))
	cfg.set_value("skirmish", "map", skirmish_map)
	cfg.set_value("network", "address", net_address)
	cfg.set_value("network", "name", player_name)
	var err := cfg.save(path)
	if err != OK:
		push_warning("cannot save settings: %s" % error_string(err))
