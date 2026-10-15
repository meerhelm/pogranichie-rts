class_name EntityStore
extends RefCounted
## Simulation state of every entity, kept in flat arrays indexed by id (struct of arrays),
## not in scene nodes. Ids start at 1, only grow and are never reused, so iterating
## alive ids in ascending order is the one deterministic order for every system.
## Scene nodes only read these arrays to draw.

enum Order { IDLE, MOVE }

const NO_ID := 0

var next_id := 1
## Alive ids, ascending.
var alive_ids := PackedInt32Array()

# Per-entity fields; slot = id - 1. Dead slots keep their last values and alive[slot] = 0.
var alive := PackedByteArray()
var type_ids: Array[StringName] = []
var owners := PackedInt32Array()
var pos_x := PackedInt64Array()
var pos_y := PackedInt64Array()
var hp := PackedInt32Array()
## Fixed units per tick.
var speed := PackedInt32Array()
var orders := PackedInt32Array()
var target_x := PackedInt64Array()
var target_y := PackedInt64Array()
## NavGrid.MoveClass of the unit.
var move_class := PackedByteArray()
## Speed of the current order, fixed units per tick: the slowest unit's speed for a group.
var move_speed := PackedInt32Array()
## Cells still to walk (Pathfinder), and the index of the next one.
var paths: Array[PackedInt32Array] = []
var path_index := PackedInt32Array()
## 1 when the unit walks straight to its target, the line there being clear (path smoothing).
var direct := PackedByteArray()
## Cell the unit stood in last, and 1 if it climbed into its current cell (hill ×0,9 «вверх»).
var last_cell := PackedInt32Array()
var climbing := PackedByteArray()
## NavGrid.version the path was planned on.
var path_version := PackedInt32Array()
## Flow field the unit follows (Simulation flow id), 0 when it walks its own path.
var flow_ids := PackedInt32Array()
## Closest distance to the target so far and ticks without getting closer (stuck detection).
var best_dist := PackedInt64Array()
var stall := PackedInt32Array()
var replans := PackedInt32Array()


func count() -> int:
	return alive_ids.size()


func is_alive(id: int) -> bool:
	return id >= 1 and id < next_id and alive[id - 1] == 1


func spawn(
	type_id: StringName,
	owner: int,
	x: int,
	y: int,
	hit_points: int,
	step: int,
	p_move_class: int = 0
) -> int:
	var id := next_id
	next_id += 1
	alive.append(1)
	type_ids.append(type_id)
	owners.append(owner)
	pos_x.append(x)
	pos_y.append(y)
	hp.append(hit_points)
	speed.append(step)
	orders.append(Order.IDLE)
	target_x.append(x)
	target_y.append(y)
	move_class.append(p_move_class)
	move_speed.append(step)
	paths.append(PackedInt32Array())
	path_index.append(0)
	direct.append(0)
	last_cell.append(-1)
	climbing.append(0)
	path_version.append(0)
	flow_ids.append(0)
	best_dist.append(0)
	stall.append(0)
	replans.append(0)
	alive_ids.append(id)
	return id


func remove(id: int) -> void:
	if not is_alive(id):
		return
	alive[id - 1] = 0
	alive_ids.remove_at(alive_ids.bsearch(id))


func set_move_target(id: int, x: int, y: int) -> void:
	var slot := id - 1
	target_x[slot] = x
	target_y[slot] = y
	orders[slot] = Order.MOVE
	move_speed[slot] = speed[slot]
	set_path(id, PackedInt32Array(), 0)
	best_dist[slot] = Fixed.distance(pos_x[slot], pos_y[slot], x, y)
	stall[slot] = 0
	replans[slot] = 0


func set_path(id: int, cells: PackedInt32Array, nav_version: int) -> void:
	var slot := id - 1
	paths[slot] = cells
	path_index[slot] = 0
	direct[slot] = 0
	path_version[slot] = nav_version


## Ends the current order where the unit stands. The caller releases its flow field first.
func stop(id: int) -> void:
	var slot := id - 1
	orders[slot] = Order.IDLE
	target_x[slot] = pos_x[slot]
	target_y[slot] = pos_y[slot]
	move_speed[slot] = speed[slot]
	set_path(id, PackedInt32Array(), 0)
	flow_ids[slot] = 0
	stall[slot] = 0


## Writes every alive entity in ascending id order, for the state hash and snapshots.
func write_to(buf: StreamPeerBuffer) -> void:
	buf.put_64(next_id)
	buf.put_32(alive_ids.size())
	for id in alive_ids:
		var slot := id - 1
		buf.put_32(id)
		buf.put_utf8_string(String(type_ids[slot]))
		buf.put_32(owners[slot])
		buf.put_64(pos_x[slot])
		buf.put_64(pos_y[slot])
		buf.put_32(hp[slot])
		buf.put_32(speed[slot])
		buf.put_32(orders[slot])
		buf.put_64(target_x[slot])
		buf.put_64(target_y[slot])
		buf.put_8(move_class[slot])
		buf.put_32(move_speed[slot])
		var path := paths[slot]
		buf.put_32(path.size())
		buf.put_32(path_index[slot])
		buf.put_8(direct[slot])
		buf.put_32(last_cell[slot])
		buf.put_8(climbing[slot])
		if not path.is_empty():
			buf.put_32(path[-1])
		buf.put_32(path_version[slot])
		buf.put_32(flow_ids[slot])
		buf.put_64(best_dist[slot])
		buf.put_32(stall[slot])
		buf.put_32(replans[slot])
