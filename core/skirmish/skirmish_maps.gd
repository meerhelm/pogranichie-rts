class_name SkirmishMaps
extends RefCounted
## The skirmish maps (2026-10-19): maps/skirmish.json lists them in menu order, each with its
## title and history note (English keys, translated in i18n/*.po), the year of the battle it is
## drawn after and the top-left cell of each side's town centre. The maps are written by
## tools/maps/gen_skirmish.py, which also writes this list; every map but the first (the
## prototype's) is point-symmetric, so both sides start on equal ground (netplay needs that).

const PATH := "res://maps/skirmish.json"

static var _maps: Array = []


## Every map as a Dictionary: id, title, note, year, size [w, h], bases [[x, y], [x, y]].
static func all() -> Array:
	if _maps.is_empty():
		var text := FileAccess.get_file_as_string(PATH)
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary:
			_maps = parsed.get("maps", [])
		if _maps.is_empty():
			push_error("cannot read the skirmish map list %s" % PATH)
	return _maps


static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for m: Dictionary in all():
		out.append(str(m["id"]))
	return out


## The map's entry, or the first map's if there is no such map.
static func find(map_id: String) -> Dictionary:
	for m: Dictionary in all():
		if m["id"] == map_id:
			return m
	return all()[0] if not all().is_empty() else {}


static func has(map_id: String) -> bool:
	return ids().has(map_id)


## The top-left cell of the town centre of the map's side `index` (0 or 1).
static func base(map_id: String, index: int) -> Vector2i:
	var b: Array = find(map_id)["bases"][index]
	return Vector2i(Num.of(b[0]), Num.of(b[1]))
