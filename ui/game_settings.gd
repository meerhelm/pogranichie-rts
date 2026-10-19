class_name GameSettings
extends RefCounted
## Player settings: language, edge scrolling, fullscreen, text size, skirmish hints, and the
## skirmish AI's difficulty and both sides' factions last picked. Kept in user://settings.cfg
## and applied at start (main menu or game scene, whichever opens first).

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

static var language := "en"
static var edge_scroll := true
static var fullscreen := false
## Index in TEXT_SIZES.
static var text_size := 1
## Whether a skirmish shows the advisor's step-by-step hints.
static var hints := true
## AiProfile.difficulty of the skirmish opponent (ai/profiles/*_<difficulty>.tres).
static var ai_difficulty: StringName = &"normal"
## Skirmish factions (SkirmishSetup.FACTIONS): the player's and the AI opponent's.
static var player_faction: StringName = &"gdl"
static var enemy_faction: StringName = &"to"
## The skirmish map (SkirmishMaps).
static var skirmish_map := SkirmishSetup.MAP_ID
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
	if cfg.load(PATH) == OK:
		var lang: String = cfg.get_value("general", "language", language)
		language = lang if LANGUAGES.has(lang) else "en"
		edge_scroll = cfg.get_value("general", "edge_scroll", edge_scroll)
		fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
		var size: int = cfg.get_value("video", "text_size", text_size)
		text_size = clampi(size, 0, TEXT_SIZES.size() - 1)
		hints = cfg.get_value("general", "hints", hints)
		var level := StringName(cfg.get_value("skirmish", "ai_difficulty", String(ai_difficulty)))
		ai_difficulty = level if DIFFICULTIES.has(level) else &"normal"
		var mine := StringName(cfg.get_value("skirmish", "faction", String(player_faction)))
		player_faction = mine if SkirmishSetup.FACTIONS.has(mine) else &"gdl"
		var theirs := StringName(cfg.get_value("skirmish", "enemy", String(enemy_faction)))
		enemy_faction = theirs if SkirmishSetup.FACTIONS.has(theirs) else &"to"
		var map: String = cfg.get_value("skirmish", "map", skirmish_map)
		skirmish_map = map if SkirmishMaps.has(map) else SkirmishSetup.MAP_ID
	apply()


static func apply() -> void:
	TranslationServer.set_locale(language)
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


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "language", language)
	cfg.set_value("general", "edge_scroll", edge_scroll)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "text_size", text_size)
	cfg.set_value("general", "hints", hints)
	cfg.set_value("skirmish", "ai_difficulty", String(ai_difficulty))
	cfg.set_value("skirmish", "faction", String(player_faction))
	cfg.set_value("skirmish", "enemy", String(enemy_faction))
	cfg.set_value("skirmish", "map", skirmish_map)
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("cannot save settings: %s" % error_string(err))
