class_name ResourceNodes
extends RefCounted
## What peasants gather besides fields and hives: wood in forest cells (an amount per cell),
## and nodes: ore deposits and silver mines from the map, carcasses of hunted animals.
## Node ids are their own sequence (slot = id - 1), alive ids ascending.

## What a node or a field gives; the order is also the order of gather rates and tech bonuses.
enum Source { FARM, HUNT, BORT, WOOD, IRON, SILVER }

const NO_ID := 0
const SOURCE_COUNT := 6
## Resource index (EconomySystem.FOOD...) each source fills.
const SOURCE_RESOURCE: Array[int] = [0, 0, 0, 1, 2, 3]

## Wood left in each cell; 0 where there is no forest.
var wood := PackedInt32Array()

var next_id := 1
var alive_ids := PackedInt32Array()
var alive := PackedByteArray()
var sources := PackedByteArray()
var cells := PackedInt32Array()
var amounts := PackedInt32Array()
## 1 when the node stands in the way (deposits); carcasses lie on the ground.
var blocks := PackedByteArray()
## For a carcass: the animal it came from.
var from_unit := PackedInt32Array()


func is_alive(id: int) -> bool:
	return id >= 1 and id < next_id and alive[id - 1] == 1


func add(source: int, cell: int, amount: int, blocking: bool, unit_id: int = 0) -> int:
	var id := next_id
	next_id += 1
	alive.append(1)
	sources.append(source)
	cells.append(cell)
	amounts.append(amount)
	blocks.append(1 if blocking else 0)
	from_unit.append(unit_id)
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
