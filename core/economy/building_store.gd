class_name BuildingStore
extends RefCounted
## Every building on the map, in flat arrays by id (slot = id - 1), like EntityStore for units.
## Building ids are their own sequence, separate from unit ids; they start at 1, only grow and
## are never reused, so iterating alive ids in ascending order is deterministic.
## A building occupies a rectangle of cells from (cell_x, cell_y), w by h. It is a foundation
## until `progress` reaches `work`, then done.

const NO_ID := 0

var next_id := 1
## Alive ids, ascending.
var alive_ids := PackedInt32Array()
## Per map cell: the building on it (NO_ID if none), and the owner of the finished gate on it
## (0 if none; nobody else may step in).
var occupant := PackedInt32Array()
var gates := PackedInt32Array()

var alive := PackedByteArray()
var type_ids: Array[StringName] = []
var defs: Array[BuildingDef] = []
var owners := PackedInt32Array()
var cell_x := PackedInt32Array()
var cell_y := PackedInt32Array()
var w := PackedInt32Array()
var h := PackedInt32Array()
var hp := PackedInt32Array()
var max_hp := PackedInt32Array()
## Construction: work done and work needed, in thousandths of a builder-tick.
var progress := PackedInt64Array()
var work := PackedInt64Array()
var done := PackedByteArray()
## 1 when the building blocks its cells for movement (everything but fields, hives and gates).
var blocks := PackedByteArray()
## Food left in a field (farm), refilled by reseeding.
var food := PackedInt32Array()
## Peasants working it now (fields and hives have a limit).
var workers := PackedInt32Array()
## Production queue: unit, tech or age ids; the first one is in work.
var queues: Array[Array] = []
## Ticks the first queued item has been in work, and 1 once it has started (population taken).
var queue_ticks := PackedInt32Array()
var queue_started := PackedByteArray()
## Where trained units walk; has_rally 0 means next to the building.
var rally_x := PackedInt64Array()
var rally_y := PackedInt64Array()
var has_rally := PackedByteArray()
## Repair: HP in thousandths gained but not yet whole, and resources owed in thousandths.
var repair_hp := PackedInt32Array()
var repair_owed: Array[PackedInt32Array] = []
## Taking apart (Dismantling): 1 while its owner has it taken apart, the work that takes in all
## and what is left of it, in thousandths of a builder-tick.
var dismantling := PackedByteArray()
var dismantle_total := PackedInt64Array()
var dismantle_left := PackedInt64Array()
## Towers: ticks until the next arrow (TowerFire).
var cooldown := PackedInt32Array()


func resize_map(cells: int) -> void:
	occupant.resize(cells)
	occupant.fill(NO_ID)
	gates.resize(cells)
	gates.fill(0)


func count() -> int:
	return alive_ids.size()


func is_alive(id: int) -> bool:
	return id >= 1 and id < next_id and alive[id - 1] == 1


func is_done(id: int) -> bool:
	return is_alive(id) and done[id - 1] == 1


func add(
	def: BuildingDef, owner: int, cx: int, cy: int, cw: int, ch: int, full_hp: int, work_needed: int
) -> int:
	var id := next_id
	next_id += 1
	alive.append(1)
	type_ids.append(def.id)
	defs.append(def)
	owners.append(owner)
	cell_x.append(cx)
	cell_y.append(cy)
	w.append(cw)
	h.append(ch)
	hp.append(1)
	max_hp.append(full_hp)
	progress.append(0)
	work.append(maxi(work_needed, 1))
	done.append(0)
	blocks.append(0)
	food.append(0)
	workers.append(0)
	queues.append([])
	queue_ticks.append(0)
	queue_started.append(0)
	rally_x.append(0)
	rally_y.append(0)
	has_rally.append(0)
	repair_hp.append(0)
	repair_owed.append(PackedInt32Array([0, 0, 0, 0]))
	dismantling.append(0)
	dismantle_total.append(0)
	dismantle_left.append(0)
	cooldown.append(0)
	alive_ids.append(id)
	return id


func remove(id: int) -> void:
	if not is_alive(id):
		return
	alive[id - 1] = 0
	alive_ids.remove_at(alive_ids.bsearch(id))


## Every cell of the footprint, row by row.
func cells_of(id: int, grid_width: int) -> PackedInt32Array:
	var slot := id - 1
	var out := PackedInt32Array()
	for y in range(cell_y[slot], cell_y[slot] + h[slot]):
		for x in range(cell_x[slot], cell_x[slot] + w[slot]):
			out.append(y * grid_width + x)
	return out


## Squared distance (fixed units) from a point to the footprint rectangle; 0 inside it.
func distance_sq(id: int, px: int, py: int) -> int:
	var slot := id - 1
	var x0 := Fixed.from_cells(cell_x[slot])
	var y0 := Fixed.from_cells(cell_y[slot])
	var dx := maxi(maxi(x0 - px, 0), px - (x0 + Fixed.from_cells(w[slot])))
	var dy := maxi(maxi(y0 - py, 0), py - (y0 + Fixed.from_cells(h[slot])))
	return dx * dx + dy * dy


func center_x(id: int) -> int:
	var slot := id - 1
	return Fixed.from_cells(cell_x[slot]) + Fixed.from_cells(w[slot]) / 2


func center_y(id: int) -> int:
	var slot := id - 1
	return Fixed.from_cells(cell_y[slot]) + Fixed.from_cells(h[slot]) / 2


func write_to(buf: StreamPeerBuffer) -> void:
	buf.put_64(next_id)
	buf.put_32(alive_ids.size())
	for id in alive_ids:
		var s := id - 1
		buf.put_32(id)
		buf.put_utf8_string(String(type_ids[s]))
		buf.put_32(owners[s])
		buf.put_32(cell_x[s])
		buf.put_32(cell_y[s])
		buf.put_32(w[s])
		buf.put_32(h[s])
		buf.put_32(hp[s])
		buf.put_32(max_hp[s])
		buf.put_64(progress[s])
		buf.put_64(work[s])
		buf.put_8(done[s])
		buf.put_8(blocks[s])
		buf.put_32(food[s])
		buf.put_32(workers[s])
		buf.put_32(queues[s].size())
		for item: StringName in queues[s]:
			buf.put_utf8_string(String(item))
		buf.put_32(queue_ticks[s])
		buf.put_8(queue_started[s])
		buf.put_64(rally_x[s])
		buf.put_64(rally_y[s])
		buf.put_8(has_rally[s])
		buf.put_32(repair_hp[s])
		for v in repair_owed[s]:
			buf.put_32(v)
		buf.put_8(dismantling[s])
		buf.put_64(dismantle_total[s])
		buf.put_64(dismantle_left[s])
		buf.put_32(cooldown[s])
