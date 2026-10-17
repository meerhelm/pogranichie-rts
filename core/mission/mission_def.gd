class_name MissionDef
extends RefCounted
## A campaign mission as data (M9): missions/<id>/mission.json, read once and never changed.
## MissionRuntime plays it. JSON numbers are turned into ints here, so the simulation sees only
## integers (positions are map cells, times are ticks).
##
## The file has
## - id, title, map (maps/<map>/terrain.txt), player (the human's side), players: [[player,
##   faction], ...], camera: the cell the camera starts on, difficulties;
## - setup: stock per player, locked items per player, buildings (finished, optionally named
##   and wooden), walls (cell lines), groups of units (named groups can be ordered later),
##   consecrated: [[place index, building name], ...];
## - rules: hunger (the player's food falls with the number of units until a trigger fires) and
##   boats (reinforcements at a pier every so often once a trigger switches them on, until the
##   player holds the pier);
## - triggers: [{id, when: condition, do: [actions]}], each fires once, in file order.
## MissionRuntime's comments list the conditions and actions.

const DIR := "res://missions/%s/mission.json"

var id := ""
var title := ""
var map_id := ""
var player := 1
## [[player, faction], ...]
var players: Array = []
var camera := Vector2i.ZERO
var difficulties := PackedStringArray()
var setup: Dictionary = {}
var rules: Dictionary = {}
var triggers: Array = []


static func path_for(mission_id: String) -> String:
	return DIR % mission_id


static func load_id(mission_id: String) -> MissionDef:
	var text := FileAccess.get_file_as_string(path_for(mission_id))
	if text.is_empty():
		push_error("cannot read mission %s" % mission_id)
		return null
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("mission %s is not a JSON object" % mission_id)
		return null
	return from_dict(ints(parsed) as Dictionary)


static func from_dict(d: Dictionary) -> MissionDef:
	var m := MissionDef.new()
	m.id = d.get("id", "")
	m.title = d.get("title", "")
	m.map_id = d.get("map", "")
	m.player = d.get("player", 1)
	m.players = d.get("players", [])
	var cam: Array = d.get("camera", [0, 0])
	m.camera = Vector2i(cam[0], cam[1])
	m.difficulties = PackedStringArray(d.get("difficulties", ["normal"]))
	m.setup = d.get("setup", {})
	m.rules = d.get("rules", {})
	m.triggers = d.get("triggers", [])
	return m


## JSON numbers come as floats: whole ones become ints, everywhere in the tree.
static func ints(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var f: float = value
			if f == floorf(f):
				return int(f)
			return f
		TYPE_ARRAY:
			var out := []
			for item: Variant in value:
				out.append(ints(item))
			return out
		TYPE_DICTIONARY:
			var out := {}
			var d: Dictionary = value
			for k: Variant in d:
				out[k] = ints(d[k])
			return out
	return value


## The faction of a player in this mission, or "" if it has none.
func faction_of(p: int) -> StringName:
	for entry: Array in players:
		if entry[0] == p:
			return StringName(entry[1])
	return &""


## Every text the player reads, for the translation extractor's tests: objectives, hints,
## dialogue and cutscene lines (speakers too), end texts and the options of questions.
func texts() -> PackedStringArray:
	var out := PackedStringArray([title])
	for t: Dictionary in triggers:
		for action: Dictionary in t.get("do", []):
			if action.has("text"):
				out.append(action["text"])
			for line: Array in action.get("lines", []):
				out.append(line[0])
				out.append(line[1])
			for option: String in action.get("options", []):
				out.append(option)
	return out
