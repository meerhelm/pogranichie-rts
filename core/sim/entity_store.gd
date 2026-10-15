class_name EntityStore
extends RefCounted
## Simulation state of every entity, kept in flat arrays indexed by id (struct of arrays),
## not in scene nodes. Ids start at 1, only grow and are never reused, so iterating
## alive ids in ascending order is the one deterministic order for every system.
## Scene nodes only read these arrays to draw.

enum Order { IDLE, MOVE }
## What the unit does in combat beyond its order: running from the fight with no morale left
## (FLEE, deaf to orders), or the «Литовский отход» (RETREAT).
enum Intent { NONE, FLEE, RETREAT }
## How a unit picks fights (M4): AGGRESSIVE chases what it sees, DEFENSIVE follows only a little
## way from its post and comes back, STAND never moves and shoots what is in range. PASSIVE
## (peasants, civilians, spiritual units) never starts a fight on its own.
enum Stance { AGGRESSIVE, DEFENSIVE, STAND, PASSIVE }
## How the current target was chosen: by the unit itself or by an attack order.
enum TargetKind { NONE, AUTO, ORDERED }

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

# Combat (M4). Morale is in thousandths of a point (catalog 0..100 × 1000).
var max_hp := PackedInt32Array()
var morale := PackedInt32Array()
var stance := PackedByteArray()
var intents := PackedByteArray()
## Remaining ticks of the intent (flight or retreat).
var intent_ticks := PackedInt32Array()
var target := PackedInt32Array()
var target_kind := PackedByteArray()
## 1 while an attack-move is under way to (am_x, am_y): the unit fights what it meets there.
var attack_move := PackedByteArray()
var am_x := PackedInt64Array()
var am_y := PackedInt64Array()
## Defensive post, or where the chase of a fleeing target began.
var post_x := PackedInt64Array()
var post_y := PackedInt64Array()
var chase_x := PackedInt64Array()
var chase_y := PackedInt64Array()
## Where the unit was created: it flees there when its side has no rally point.
var home_x := PackedInt64Array()
var home_y := PackedInt64Array()
## Ticks until the next strike, the next javelin, the next «Литовский отход».
var cooldown := PackedInt32Array()
var javelin_cd := PackedInt32Array()
var retreat_cd := PackedInt32Array()
## Way the unit faces, a vector of length Fixed.ONE.
var facing_x := PackedInt32Array()
var facing_y := PackedInt32Array()
## Distance walked without stopping, for the charge, and 1 if the unit moved this tick.
var run := PackedInt64Array()
var moved := PackedByteArray()
## Ticks since the unit last hit or was hit; morale recovers once it is out of combat.
var calm := PackedInt32Array()
## Tenths of max HP already lost (−1 morale each).
var lost_tenths := PackedByteArray()
## Ticks left to order «Разворот» after a retreat, and 1 while its bonus waits for the next hit.
var turn_ticks := PackedInt32Array()
var turn_bonus := PackedByteArray()
## Ticks a pursuer of a retreating unit stays out of order (−2 melee armor).
var disorder := PackedInt32Array()
## Ticks a forest archer stays visible after a shot.
var reveal := PackedInt32Array()
var dismounted := PackedByteArray()


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
	max_hp.append(hit_points)
	morale.append(0)
	stance.append(Stance.AGGRESSIVE)
	intents.append(Intent.NONE)
	intent_ticks.append(0)
	target.append(NO_ID)
	target_kind.append(TargetKind.NONE)
	attack_move.append(0)
	am_x.append(x)
	am_y.append(y)
	post_x.append(x)
	post_y.append(y)
	chase_x.append(x)
	chase_y.append(y)
	home_x.append(x)
	home_y.append(y)
	cooldown.append(0)
	javelin_cd.append(0)
	retreat_cd.append(0)
	facing_x.append(0)
	facing_y.append(Fixed.ONE)
	run.append(0)
	moved.append(0)
	calm.append(0)
	lost_tenths.append(0)
	turn_ticks.append(0)
	turn_bonus.append(0)
	disorder.append(0)
	reveal.append(0)
	dismounted.append(0)
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
		_write_combat(buf, slot)


func _write_combat(buf: StreamPeerBuffer, slot: int) -> void:
	buf.put_32(max_hp[slot])
	buf.put_32(morale[slot])
	buf.put_8(stance[slot])
	buf.put_8(intents[slot])
	buf.put_32(intent_ticks[slot])
	buf.put_32(target[slot])
	buf.put_8(target_kind[slot])
	buf.put_8(attack_move[slot])
	buf.put_64(am_x[slot])
	buf.put_64(am_y[slot])
	buf.put_64(post_x[slot])
	buf.put_64(post_y[slot])
	buf.put_64(chase_x[slot])
	buf.put_64(chase_y[slot])
	buf.put_64(home_x[slot])
	buf.put_64(home_y[slot])
	buf.put_32(cooldown[slot])
	buf.put_32(javelin_cd[slot])
	buf.put_32(retreat_cd[slot])
	buf.put_32(facing_x[slot])
	buf.put_32(facing_y[slot])
	buf.put_64(run[slot])
	buf.put_8(moved[slot])
	buf.put_32(calm[slot])
	buf.put_8(lost_tenths[slot])
	buf.put_32(turn_ticks[slot])
	buf.put_8(turn_bonus[slot])
	buf.put_32(disorder[slot])
	buf.put_32(reveal[slot])
	buf.put_8(dismounted[slot])
