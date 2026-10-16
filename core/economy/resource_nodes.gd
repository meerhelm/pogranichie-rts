class_name ResourceNodes
extends RefCounted
## What peasants gather besides fields and hives: wood in forest cells (an amount per cell),
## and nodes: ore deposits and silver mines from the map, carcasses of hunted animals, and
## salvage piles left by a building its owner took apart (only the owner's peasants pick them
## up; one pile per resource).
## Node ids are their own sequence (slot = id - 1), alive ids ascending.

## What a node or a field gives; the order is also the order of gather rates and tech bonuses
## (the first SOURCE_COUNT; salvage gets none).
enum Source {
	FARM, HUNT, BORT, WOOD, IRON, SILVER, SALVAGE_FOOD, SALVAGE_WOOD, SALVAGE_IRON, SALVAGE_SILVER
}

const NO_ID := 0
## Sources that have gather rates and tech bonuses (all but salvage).
const SOURCE_COUNT := 6
## Resource index (EconomySystem.FOOD...) each source fills.
const SOURCE_RESOURCE: Array[int] = [0, 0, 0, 1, 2, 3, 0, 1, 2, 3]

## Wood left in each cell; 0 where there is no forest.
var wood := PackedInt32Array()

var next_id := 1
var alive_ids := PackedInt32Array()
var alive := PackedByteArray()
var sources := PackedByteArray()
var cells := PackedInt32Array()
var amounts := PackedInt32Array()
## What each node held when it appeared (for the card; not part of the state hash, it follows
## from the map and the rules).
var initial := PackedInt32Array()
## 1 when the node stands in the way (deposits); carcasses lie on the ground.
var blocks := PackedByteArray()
## For a carcass: the animal it came from.
var from_unit := PackedInt32Array()
## For salvage: the player whose peasants may pick it up (0: anyone).
var owners := PackedInt32Array()


func is_alive(id: int) -> bool:
	return id >= 1 and id < next_id and alive[id - 1] == 1


## The salvage source of resource `res` (EconomySystem.FOOD...).
static func salvage_of(res: int) -> int:
	return Source.SALVAGE_FOOD + res


static func is_salvage(source: int) -> bool:
	return source >= Source.SALVAGE_FOOD


## Whether player p may gather node id (salvage only its owner).
func open_to(id: int, p: int) -> bool:
	return owners[id - 1] == 0 or owners[id - 1] == p


func add(
	source: int, cell: int, amount: int, blocking: bool, unit_id: int = 0, owner: int = 0
) -> int:
	var id := next_id
	next_id += 1
	alive.append(1)
	sources.append(source)
	cells.append(cell)
	amounts.append(amount)
	initial.append(amount)
	blocks.append(1 if blocking else 0)
	from_unit.append(unit_id)
	owners.append(owner)
	alive_ids.append(id)
	return id


func remove(id: int) -> void:
	if not is_alive(id):
		return
	alive[id - 1] = 0
	alive_ids.remove_at(alive_ids.bsearch(id))


## The carcass left by this animal, or NO_ID.
func carcass_of(unit_id: int) -> int:
	for id in alive_ids:
		if from_unit[id - 1] == unit_id and sources[id - 1] == Source.HUNT:
			return id
	return NO_ID


## The node on this cell, or NO_ID.
func at_cell(cell: int) -> int:
	for id in alive_ids:
		if cells[id - 1] == cell:
			return id
	return NO_ID


func write_to(buf: StreamPeerBuffer) -> void:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(wood.to_byte_array())
	buf.put_data(ctx.finish())
	buf.put_64(next_id)
	buf.put_32(alive_ids.size())
	for id in alive_ids:
		var s := id - 1
		buf.put_32(id)
		buf.put_8(sources[s])
		buf.put_32(cells[s])
		buf.put_32(amounts[s])
		buf.put_8(blocks[s])
		buf.put_32(from_unit[s])
		buf.put_32(owners[s])
