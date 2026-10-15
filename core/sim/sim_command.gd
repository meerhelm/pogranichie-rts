class_name SimCommand
extends RefCounted
## One order for the simulation. Players, the AI and mission scripts all change the world
## only through commands; a replay is the seed plus the list of commands.
## Coordinates are fixed-point (see Fixed). Serialized with short keys to keep replays small.

enum Kind { SPAWN, MOVE, STOP, REMOVE }

## Tick at whose start the command is applied.
var tick: int
var player: int
var kind: Kind
var ids := PackedInt32Array()
var x: int
var y: int
## Unit type for SPAWN.
var type_id: StringName
## Order of arrival, set by CommandQueue; breaks ties between commands of one player and tick.
var seq := -1


static func spawn(at_tick: int, by: int, unit: StringName, px: int, py: int) -> SimCommand:
	var c := SimCommand.new()
	c.tick = at_tick
	c.player = by
	c.kind = Kind.SPAWN
	c.type_id = unit
	c.x = px
	c.y = py
	return c


static func move(at_tick: int, by: int, units: PackedInt32Array, px: int, py: int) -> SimCommand:
	var c := SimCommand.new()
	c.tick = at_tick
	c.player = by
	c.kind = Kind.MOVE
	c.ids = units
	c.x = px
	c.y = py
	return c


static func stop(at_tick: int, by: int, units: PackedInt32Array) -> SimCommand:
	var c := SimCommand.new()
	c.tick = at_tick
	c.player = by
	c.kind = Kind.STOP
	c.ids = units
	return c


static func remove(at_tick: int, by: int, units: PackedInt32Array) -> SimCommand:
	var c := SimCommand.new()
	c.tick = at_tick
	c.player = by
	c.kind = Kind.REMOVE
	c.ids = units
	return c


func duplicate_command() -> SimCommand:
	return from_dict(to_dict())


func to_dict() -> Dictionary:
	var d := {"t": tick, "p": player, "k": Kind.keys()[kind]}
	if not ids.is_empty():
		d["ids"] = Array(ids)
	if kind == Kind.SPAWN or kind == Kind.MOVE:
		d["x"] = x
		d["y"] = y
	if kind == Kind.SPAWN:
		d["u"] = String(type_id)
	return d


## JSON gives numbers as floats; every field is converted back to int here.
static func from_dict(d: Dictionary) -> SimCommand:
	var c := SimCommand.new()
	c.tick = int(d["t"])
	c.player = int(d["p"])
	var kind_name: String = d["k"]
	var kind_index: int = Kind.keys().find(kind_name)
	assert(kind_index >= 0, "unknown command kind: %s" % kind_name)
	c.kind = kind_index as Kind
	var raw_ids: Array = d.get("ids", [])
	for v: Variant in raw_ids:
		c.ids.append(int(v))
	c.x = int(d.get("x", 0))
	c.y = int(d.get("y", 0))
	c.type_id = StringName(str(d.get("u", "")))
	return c
