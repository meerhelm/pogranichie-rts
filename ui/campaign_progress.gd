class_name CampaignProgress
extends RefCounted
## The two campaigns and how far the player has got in them. A campaign's missions open one
## after another: the first is open from the start, each next one once the one before it is won.
## Won missions are kept in user://campaign.cfg. A mission that is planned but not made yet (no
## missions/<id>/mission.json) is listed under its planned title and cannot be played.

const PATH := "user://campaign.cfg"
## Campaign ids in the order the menu shows them.
const ORDER: Array[String] = ["gdl", "crown"]
## Each campaign's missions in order.
const MISSIONS := {
	"gdl": ["gdl_01", "gdl_02", "gdl_03", "gdl_04", "gdl_05", "gdl_06", "gdl_07", "gdl_08"],
	"crown": ["crown_01", "crown_02", "crown_03", "crown_04", "crown_05", "crown_06"],
}
## The faction whose name the country button shows (a catalog id, translated as a name).
const FACTION := {"gdl": &"gdl", "crown": &"pl"}

## Where the progress is kept; tests point it elsewhere.
static var path := PATH
static var _won := {}
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_won = {}
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for id: String in cfg.get_value("campaign", "won", PackedStringArray()):
		_won[id] = true


## Forgets what was loaded, so the next call reads `path` again (tests).
static func reset() -> void:
	_loaded = false
	_won = {}


static func is_won(mission_id: String) -> bool:
	ensure_loaded()
	return _won.has(mission_id)


## Records a won mission and saves; the next mission of its campaign opens.
static func mark_won(mission_id: String) -> void:
	ensure_loaded()
	if _won.has(mission_id):
		return
	_won[mission_id] = true
	var cfg := ConfigFile.new()
	var ids := PackedStringArray(_won.keys())
	ids.sort()
	cfg.set_value("campaign", "won", ids)
	var err := cfg.save(path)
	if err != OK:
		push_warning("cannot save campaign progress: %s" % error_string(err))


## Whether the mission is made (its mission.json is in the game).
static func is_made(mission_id: String) -> bool:
	return FileAccess.file_exists(MissionDef.path_for(mission_id))


## Whether the player may start the mission: it is made, and it is its campaign's first or the
## one before it is won.
static func is_open(mission_id: String) -> bool:
	if not is_made(mission_id):
		return false
	var list: Array = MISSIONS[campaign_of(mission_id)]
	var i := list.find(mission_id)
	return i == 0 or is_won(list[i - 1])


## The campaign a mission belongs to ("" for none).
static func campaign_of(mission_id: String) -> String:
	for c: String in ORDER:
		if (MISSIONS[c] as Array).has(mission_id):
			return c
	return ""


static func won_count(campaign: String) -> int:
	var n := 0
	for id: String in MISSIONS[campaign]:
		if is_won(id):
			n += 1
	return n


## The mission's title as a translation key: from its mission.json, or the planned one.
static func title_key(mission_id: String) -> String:
	if is_made(mission_id):
		var def := MissionDef.load_id(mission_id)
		if def != null:
			return def.title
	return planned_title(mission_id)


## Titles of the Crown missions until they are made (docs/03-missions/12…17), translated.
static func planned_title(mission_id: String) -> String:
	match mission_id:
		"crown_01":
			return UiText.t("Crown 1. Grunwald, 1410")
		"crown_02":
			return UiText.t("Crown 2. Malbork, 1410")
		"crown_03":
			return UiText.t("Crown 3. Baltic Water, 1433")
		"crown_04":
			return UiText.t("Crown 4. Chojnice, 1454")
		"crown_05":
			return UiText.t("Crown 5. Silver for Malbork, 1457")
		"crown_06":
			return UiText.t("Crown 6. Świecino, 1462")
	return mission_id


## The campaign's own name (docs/02-campaign-story.md), translated.
static func campaign_name(campaign: String) -> String:
	match campaign:
		"gdl":
			return UiText.t("The Oak and the Chase")
		"crown":
			return UiText.t("The Banner and the Silver")
	return campaign
