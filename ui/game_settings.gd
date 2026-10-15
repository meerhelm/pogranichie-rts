class_name GameSettings
extends RefCounted
## Player settings: language, edge scrolling, fullscreen. Kept in user://settings.cfg and applied
## at start (main menu or game scene, whichever opens first).

const PATH := "user://settings.cfg"
## Locales the game ships (i18n/<locale>.po); English is the development language.
const LANGUAGES: Array[String] = ["en", "be", "pl", "uk", "lt"]
## Each language's name in itself, shown in the language list untranslated.
const LANGUAGE_NAMES: Array[String] = [
	"English",  # notr
	"Беларуская",  # notr
	"Polski",  # notr
	"Українська",  # notr
	"Lietuvių",  # notr
]

static var language := "en"
static var edge_scroll := true
static var fullscreen := false
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
	apply()


static func apply() -> void:
	TranslationServer.set_locale(language)
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
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("cannot save settings: %s" % error_string(err))
