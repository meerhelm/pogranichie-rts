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


func count() -> int:
	return alive_ids.size()


func is_alive(id: int) -> bool:
	return id >= 1 and id < next_id and alive[id - 1] == 1


func spawn(type_id: StringName, owner: int, x: int, y: int, hit_points: int, step: int) -> int:
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


func stop(id: int) -> void:
	var slot := id - 1
	orders[slot] = Order.IDLE
	target_x[slot] = pos_x[slot]
	target_y[slot] = pos_y[slot]


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
