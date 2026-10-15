class_name SimCommand
extends RefCounted
## One order for the simulation. Players, the AI and mission scripts all change the world
## only through commands; a replay is the seed plus the list of commands.
## Coordinates are fixed-point (see Fixed). Serialized with short keys to keep replays small.

## JOIN and later (M5) are economy commands, see EconomySystem.order().
enum Kind {
	SPAWN,
	MOVE,
	STOP,
	REMOVE,
	ATTACK,
	ATTACK_MOVE,
	STANCE,
	RETREAT,
	TURN,
	DISMOUNT,
	RALLY,
	JOIN,
	PLACE,
	BUILD,
	WALL,
	GATHER,
	WORK,
	ASSAULT,
	QUEUE,
	CANCEL,
	BUILDING_RALLY,
	CAST,
}

## Kinds whose x and y are a point on the map.
const POINT_KINDS: Array[Kind] = [
	Kind.SPAWN,
	Kind.MOVE,
	Kind.ATTACK_MOVE,
	Kind.RALLY,
	Kind.PLACE,
	Kind.BUILD,
	Kind.WALL,
	Kind.GATHER,
	Kind.BUILDING_RALLY,
	Kind.CAST,
]
## Kinds that name a type: unit, faction, building, or queued unit, tech or age.
const TYPE_KINDS: Array[Kind] = [
	Kind.SPAWN, Kind.JOIN, Kind.PLACE, Kind.BUILD, Kind.WALL, Kind.QUEUE, Kind.CAST
]
const VALUE_KINDS: Array[Kind] = [Kind.STANCE, Kind.PLACE, Kind.BUILD, Kind.GATHER, Kind.CANCEL]

## Tick at whose start the command is applied.
var tick: int
var player: int
var kind: Kind
var ids := PackedInt32Array()
var x: int
var y: int
## Second point of a WALL line.
var x2: int
var y2: int
## Unit type for SPAWN; faction for JOIN; building for PLACE, BUILD, WALL; item for QUEUE;
## spell for CAST.
var type_id: StringName
## Formation.Kind for a group MOVE.
var formation := 0
## Unit to attack (ATTACK; optional for TURN); building for WORK and ASSAULT; node or animal
## for GATHER.
var target := 0
## EntityStore.Stance for STANCE; 1 for a building turned on its side (PLACE, BUILD);
## EconomySystem.Target for GATHER; queue index for CANCEL.
var value := 0
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


static func move(
	at_tick: int, by: int, units: PackedInt32Array, px: int, py: int, shape: int = 0
) -> SimCommand:
	var c := SimCommand.new()
	c.tick = at_tick
	c.player = by
	c.kind = Kind.MOVE
	c.ids = units
	c.x = px
	c.y = py
	c.formation = shape
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


## Attack one unit (an enemy, or a neutral animal to hunt).
static func attack(at_tick: int, by: int, units: PackedInt32Array, enemy: int) -> SimCommand:
	var c := SimCommand.new()
	c.tick = at_tick
	c.player = by
	c.kind = Kind.ATTACK
	c.ids = units
	c.target = enemy
	return c


## Walk to the point like MOVE, but fight every enemy met on the way.
static func attack_move(
	at_tick: int, by: int, units: PackedInt32Array, px: int, py: int, shape: int = 0
) -> SimCommand:
	var c := move(at_tick, by, units, px, py, shape)
	c.kind = Kind.ATTACK_MOVE
	return c


static func set_stance(at_tick: int, by: int, units: PackedInt32Array, s: int) -> SimCommand:
	var c := SimCommand.new()
	c.tick = at_tick
	c.player = by
	c.kind = Kind.STANCE
	c.ids = units
	c.value = s
	return c


## Unit orders without arguments: RETREAT («Литовский отход»), TURN («Разворот»), DISMOUNT.
static func order(at_tick: int, by: int, what: Kind, units: PackedInt32Array) -> SimCommand:
	var c := SimCommand.new()
	c.tick = at_tick
	c.player = by
	c.kind = what
	c.ids = units
	return c


## The player's rally point: units without morale flee there.
static func rally(at_tick: int, by: int, px: int, py: int) -> SimCommand:
	var c := SimCommand.new()
	c.tick = at_tick
	c.player = by
	c.kind = Kind.RALLY
	c.x = px
	c.y = py
	return c


# --- economy (M5) ---------------------------------------------------------------------------


## A player enters the game with a faction and the starting stock.
static func join(at_tick: int, by: int, faction: StringName) -> SimCommand:
	var c := SimCommand.new()
	c.tick = at_tick
	c.player = by
	c.kind = Kind.JOIN
	c.type_id = faction
	return c


## Map setup: a finished building at the cell holding the point (no price, no builders).
static func place(
	at_tick: int, by: int, building: StringName, px: int, py: int, turned: bool = false
) -> SimCommand:
	var c := SimCommand.new()
	c.tick = at_tick
	c.player = by
	c.kind = Kind.PLACE
	c.type_id = building
	c.x = px
	c.y = py
	c.value = 1 if turned else 0
	return c


## Lay a foundation with its top-left cell at the point, paid now, and send builders to it.
static func build(
	at_tick: int,
	by: int,
	units: PackedInt32Array,
	building: StringName,
	px: int,
	py: int,
	turned: bool = false
) -> SimCommand:
	var c := place(at_tick, by, building, px, py, turned)
	c.kind = Kind.BUILD
	c.ids = units
	return c


## A palisade (or another per-cell wall) from one point to another.
static func wall(
	at_tick: int,
	by: int,
	units: PackedInt32Array,
	building: StringName,
	from: Vector2i,
	to: Vector2i
) -> SimCommand:
	var c := place(at_tick, by, building, from.x, from.y)
	c.kind = Kind.WALL
	c.ids = units
	c.x2 = to.x
	c.y2 = to.y
	return c


## Gather from the forest cell holding the point.
static func gather_at(
	at_tick: int, by: int, units: PackedInt32Array, px: int, py: int
) -> SimCommand:
	var c := SimCommand.new()
	c.tick = at_tick
	c.player = by
	c.kind = Kind.GATHER
	c.ids = units
	c.x = px
	c.y = py
	return c


## Gather from a node, a field or hive, or hunt an animal (`what` is EconomySystem.Target).
static func gather(
	at_tick: int, by: int, units: PackedInt32Array, what: int, ref: int
) -> SimCommand:
	var c := SimCommand.new()
	c.tick = at_tick
	c.player = by
	c.kind = Kind.GATHER
	c.ids = units
	c.value = what
	c.target = ref
	return c


## Build or repair an own building (WORK), or attack someone else's (ASSAULT).
static func on_building(
	at_tick: int, by: int, what: Kind, units: PackedInt32Array, building: int
) -> SimCommand:
	var c := SimCommand.new()
	c.tick = at_tick
	c.player = by
	c.kind = what
	c.ids = units
	c.target = building
	return c


## Train a unit, research a tech or the next age in a building.
static func queue_item(at_tick: int, by: int, building: int, item: StringName) -> SimCommand:
	var c := SimCommand.new()
	c.tick = at_tick
	c.player = by
	c.kind = Kind.QUEUE
	c.ids = PackedInt32Array([building])
	c.type_id = item
	return c


static func cancel_item(at_tick: int, by: int, building: int, index: int) -> SimCommand:
	var c := SimCommand.new()
	c.tick = at_tick
	c.player = by
	c.kind = Kind.CANCEL
	c.ids = PackedInt32Array([building])
	c.value = index
	return c


## Where the buildings' trained units go.
static func building_rally(
	at_tick: int, by: int, building_ids: PackedInt32Array, px: int, py: int
) -> SimCommand:
	var c := SimCommand.new()
	c.tick = at_tick
	c.player = by
	c.kind = Kind.BUILDING_RALLY
	c.ids = building_ids
	c.x = px
	c.y = py
	return c


# --- magic (M7) ----------------------------------------------------------------------------


## Cast a spell: one of the units that may (MagicSystem.order) casts it at the point, or around
## itself for a spell aimed at its caster.
static func cast(
	at_tick: int, by: int, units: PackedInt32Array, spell: StringName, px: int, py: int
) -> SimCommand:
	var c := SimCommand.new()
	c.tick = at_tick
	c.player = by
	c.kind = Kind.CAST
	c.ids = units
	c.type_id = spell
	c.x = px
	c.y = py
	return c


func duplicate_command() -> SimCommand:
	return from_dict(to_dict())


func to_dict() -> Dictionary:
	var d := {"t": tick, "p": player, "k": Kind.keys()[kind]}
	if not ids.is_empty():
		d["ids"] = Array(ids)
	if kind in POINT_KINDS:
		d["x"] = x
		d["y"] = y
	if kind == Kind.WALL:
		d["x2"] = x2
		d["y2"] = y2
	if kind in TYPE_KINDS:
		d["u"] = String(type_id)
	if (kind == Kind.MOVE or kind == Kind.ATTACK_MOVE) and formation != 0:
		d["f"] = formation
	if target != 0:
		d["tg"] = target
	if kind == Kind.STANCE or (kind in VALUE_KINDS and value != 0):
		d["v"] = value
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
	c.x2 = int(d.get("x2", 0))
	c.y2 = int(d.get("y2", 0))
	c.type_id = StringName(str(d.get("u", "")))
	c.formation = int(d.get("f", 0))
	c.target = int(d.get("tg", 0))
	c.value = int(d.get("v", 0))
	return c
