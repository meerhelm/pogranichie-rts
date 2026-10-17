class_name VedroshaBot
extends RefCounted
## A scripted player for «ВКЛ 5. Ведроша, 1500»: plays the mission through to its end with plain
## player commands, so the recorded game (tests/replays/gdl05_playthrough.json) shows that the
## retreat can be made and keeps every trigger on the way working:
##   godot --headless -s tools/sim/sim_cli.gd -- mission --mission gdl_05 \
##     --out tests/replays/gdl05_playthrough.json
## It sees the whole world and is not meant to play well, only to get through. Servants put up
## a stable and the camp hires light horse; the army rides east along the road with the allies
## and strikes the forward regiment; once it falls back a rider looks into the forest while the
## rest hold the right edge of the line. When the ambush strikes everyone makes for the bridge,
## Andrei first, but the lances stay at its far end as the rearguard against the axemen; whoever
## is still east of the river when it falls goes over the ford two at a time.

const THINK_EVERY := 20
const P := 1
const CAMP := Vector2i(22, 54)
const FORWARD := Vector2i(57, 46)
const RIGHT := Vector2i(100, 68)
const FOREST := Vector2i(101, 24)
const BRIDGE_E := Vector2i(78, 50)
const BRIDGE_W := Vector2i(62, 50)
const FORD_E := Vector2i(79, 74)
const FORD_W := Vector2i(62, 75)
const SAFE := Vector2i(52, 62)
## Columns: east of this the unit is on the far bank, west of WEST it is safe.
const EAST := 74
const WEST := 68
const NOT_SOLDIERS: Array[StringName] = [&"hero_andrei", &"gdl_camp_servant", &"gdl_znakharka"]

var sim: Simulation
var _sent: Dictionary[String, int] = {}
var _last_order := -100000
var _scout := EntityStore.NO_ID


func _init(p_sim: Simulation) -> void:
	sim = p_sim


## Orders for the coming tick; call before each step.
func think() -> void:
	if sim.tick % THINK_EVERY != 0 or sim.mission.is_over():
		return
	var m := sim.mission
	_camp()
	if not m.fired.has("3"):
		_march()
	elif not m.fired.has("6"):
		_battle()
	else:
		_retreat()
	_andrei()
	if sim.tick % 1200 == 0 and OS.has_environment("BOT_LOG"):
		_log()


func _log() -> void:
	var m := sim.mission
	var last := ""
	var at := -1
	for tid: String in m.fired:
		if m.fired[tid] >= at:
			at = m.fired[tid]
			last = tid
	var count := {}
	for id in sim.entities.alive_ids:
		var o := sim.entities.owners[id - 1]
		count[o] = count.get(o, 0) + 1
	print(
		(
			"%02d:%02d last=%s units=%s bridge=%d saved=%d drowned=%d captives=%d"
			% [
				sim.tick / 1200,
				sim.tick / 20 % 60,
				last,
				count,
				m.retreat.bridge_permille(m),
				m.retreat.saved(m),
				m.retreat.drowned,
				m.captives,
			]
		)
	)


# --- the camp -------------------------------------------------------------------------------


## Servants put up a stable once; it hires light horse while there is food and hiring is open.
func _camp() -> void:
	if sim.tick % 100 != 0:
		return
	var servants := _of_type(&"gdl_camp_servant")
	if servants.size() >= 2 and not _sent.has("stable"):
		if _build(servants.slice(0, 4), &"gdl_stable", Vector2i(26, 62)):
			_sent["stable"] = sim.tick
	var state := sim.economy.player(P)
	for b in _buildings(&"gdl_stable"):
		if state.stock[EconomySystem.FOOD] >= 120:
			_queue(b, &"gdl_light_horse")


func _build(ids: PackedInt32Array, type: StringName, near: Vector2i) -> bool:
	var def := sim.economy.db.building(type)
	for r in range(0, 8):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := near + Vector2i(dx, dy)
				var fail := sim.economy.placement.can_place(P, def, c.x, c.y, false)
				if fail != EconomySystem.Fail.OK:
					continue
				_cmd(SimCommand.build(sim.tick, P, ids, type, _fx(c.x), _fx(c.y)))
				return true
	return false


func _queue(b: int, item: StringName) -> void:
	var store := sim.economy.buildings
	if not store.is_done(b) or (store.queues[b - 1] as Array).size() >= 1:
		return
	if sim.economy.production.can_queue(P, b, item) == EconomySystem.Fail.OK:
		_cmd(SimCommand.queue_item(sim.tick, P, b, item))


func _buildings(type: StringName) -> PackedInt32Array:
	var out := PackedInt32Array()
	var store := sim.economy.buildings
	for b in store.alive_ids:
		if store.owners[b - 1] == P and store.type_ids[b - 1] == type:
			out.append(b)
	return out


# --- the march and the forward regiment ------------------------------------------------------


## The riders scout the road; once the allies go, everyone strikes the forward regiment.
func _march() -> void:
	if sim.tick - _last_order < 60:
		return
	_last_order = sim.tick
	var army := _idle(_soldiers())
	if not sim.mission.fired.has("1.2"):
		var riders := PackedInt32Array()
		for id in army:
			if sim.entities.type_ids[id - 1] == &"gdl_light_horse":
				riders.append(id)
		_go(riders, Vector2i(46, 49), 3, false)
		return
	var foe := _nearest_enemy(_centre(army), FORWARD, 20)
	if foe != EntityStore.NO_ID:
		_attack_move_to(army, foe)


# --- the battle on the field ----------------------------------------------------------------


## One rider looks into the forest; the rest hold the right edge and strike whoever comes near.
func _battle() -> void:
	if sim.tick - _last_order < 60:
		return
	_last_order = sim.tick
	var m := sim.mission
	var army := _soldiers()
	if not m.fired.has("2"):
		if _scout == EntityStore.NO_ID or not sim.entities.is_alive(_scout):
			_scout = EntityStore.NO_ID
			for id in army:
				if sim.entities.type_ids[id - 1] == &"gdl_light_horse":
					_scout = id
					break
		if _scout != EntityStore.NO_ID:
			var one := PackedInt32Array([_scout])
			_cmd(SimCommand.move(sim.tick, P, one, _fx(FOREST.x), _fx(FOREST.y)))
	var rest := PackedInt32Array()
	for id in _idle(army):
		if id != _scout or m.fired.has("2"):
			rest.append(id)
	var foe := _nearest_enemy(_centre(rest), RIGHT, 12)
	if foe != EntityStore.NO_ID:
		_attack_move_to(rest, foe)
	else:
		_go(rest, RIGHT, 5, true)


# --- the retreat ----------------------------------------------------------------------------


## While the bridge stands everyone east of the river rides over it; after, they gather at the
## ford's near end and go in two at a time when it is clear; west of the river they ride on to
## safety.
func _retreat() -> void:
	if sim.tick - _last_order < 20:
		return
	_last_order = sim.tick
	var down := sim.mission.retreat.bridge_fell
	var east := PackedInt32Array()
	var mid := PackedInt32Array()
	var west := PackedInt32Array()
	for id in _all():
		var cx := Fixed.to_cells(sim.entities.pos_x[id - 1])
		if cx > EAST:
			east.append(id)
		elif cx > WEST:
			mid.append(id)
		else:
			west.append(id)
	_go(_not_going(west, SAFE), SAFE, 6, false)
	if not down:
		# The lances stay as the rearguard at the bridge's far end; the rest ride over it.
		var guard := PackedInt32Array()
		var going := PackedInt32Array()
		for id in east:
			if sim.entities.type_ids[id - 1] == &"gdl_szlachta_lance":
				guard.append(id)
			else:
				going.append(id)
		_go(_not_going(going, BRIDGE_W), BRIDGE_W, 2, false)
		_go(_not_going(mid, BRIDGE_W), BRIDGE_W, 2, false)
		var idle := _idle(guard)
		var foe := _nearest_enemy(_centre(idle), BRIDGE_E, 6)
		if foe != EntityStore.NO_ID:
			_attack_move_to(idle, foe)
		else:
			_go(idle, BRIDGE_E, 3, false)
		return
	# Over the ford: those already in it or past it go on; the rest wait at the near end.
	_go(_not_going(mid, FORD_W), FORD_W, 2, false)
	var waiting := PackedInt32Array()
	for id in east:
		if not _going_to(id, FORD_W):
			waiting.append(id)
	_go(_not_going(waiting, FORD_E), FORD_E, 3, false)
	var in_ford := sim.mission.retreat.ford_in.size()
	var walking := 0
	for id in east:
		if _going_to(id, FORD_W):
			walking += 1
	if in_ford + walking >= 2:
		return
	var ready := PackedInt32Array()
	for id in waiting:
		if _dist_cells(id, FORD_E) <= 4:
			ready.append(id)
	if ready.is_empty():
		return
	var send := PackedInt32Array([ready[0]])
	if ready.size() > 1 and in_ford + walking == 0:
		send.append(ready[1])
	_cmd(SimCommand.move(sim.tick, P, send, _fx(FORD_W.x), _fx(FORD_W.y)))


# --- Andrei ---------------------------------------------------------------------------------


## Andrei keeps behind his men; when the ambush strikes he goes over the bridge first.
func _andrei() -> void:
	if sim.tick % 100 != 0:
		return
	var ids := sim.mission.alive_of("andrei")
	if ids.is_empty():
		return
	var m := sim.mission
	if not _sent.has("andrei_stance"):
		_sent["andrei_stance"] = sim.tick
		_cmd(SimCommand.set_stance(sim.tick, P, ids, EntityStore.Stance.PASSIVE))
	if m.fired.has("6"):
		if not _sent.has("andrei_home"):
			_sent["andrei_home"] = sim.tick
			_cmd(SimCommand.move(sim.tick, P, ids, _fx(SAFE.x), _fx(SAFE.y)))
		return
	var army := _soldiers()
	if army.is_empty():
		return
	var c := _centre(army)
	var witch := _of_type(&"gdl_znakharka")
	var to_x := c.x - Fixed.from_cells(6)
	_cmd(SimCommand.move(sim.tick, P, ids, to_x, c.y))
	if not witch.is_empty():
		_cmd(SimCommand.move(sim.tick, P, witch, to_x, c.y))


# --- queries --------------------------------------------------------------------------------


func _soldiers() -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in sim.entities.alive_ids:
		var s := id - 1
		if sim.entities.owners[s] != P or sim.combat.is_fleeing(id):
			continue
		if sim.entities.type_ids[s] in NOT_SOLDIERS:
			continue
		out.append(id)
	return out


## Every unit of ours that has been on the far bank (the servants stay home).
func _all() -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in sim.entities.alive_ids:
		var s := id - 1
		if sim.entities.owners[s] != P or sim.entities.type_ids[s] == &"gdl_camp_servant":
			continue
		if sim.entities.hp[s] > 0:
			out.append(id)
	return out


func _of_type(t: StringName) -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in sim.entities.alive_ids:
		var s := id - 1
		if sim.entities.owners[s] == P and sim.entities.type_ids[s] == t:
			out.append(id)
	return out


func _idle(ids: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in ids:
		var s := id - 1
		if sim.entities.orders[s] == EntityStore.Order.IDLE and sim.entities.target[s] == 0:
			out.append(id)
	return out


## Whether the unit walks to `at` now (its move target is that cell).
func _going_to(id: int, at: Vector2i) -> bool:
	var s := id - 1
	if sim.entities.orders[s] == EntityStore.Order.IDLE:
		return false
	return (
		Fixed.to_cells(sim.entities.target_x[s]) == at.x
		and Fixed.to_cells(sim.entities.target_y[s]) == at.y
	)


func _not_going(ids: PackedInt32Array, at: Vector2i) -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in ids:
		if not _going_to(id, at):
			out.append(id)
	return out


func _go(ids: PackedInt32Array, at: Vector2i, within: int, attack: bool) -> void:
	var away := PackedInt32Array()
	for id in ids:
		if _dist_cells(id, at) > within:
			away.append(id)
	if away.is_empty():
		return
	if attack:
		_cmd(SimCommand.attack_move(sim.tick, P, away, _fx(at.x), _fx(at.y)))
	else:
		_cmd(SimCommand.move(sim.tick, P, away, _fx(at.x), _fx(at.y)))


func _attack_move_to(ids: PackedInt32Array, foe: int) -> void:
	if ids.is_empty():
		return
	var x := sim.entities.pos_x[foe - 1]
	var y := sim.entities.pos_y[foe - 1]
	_cmd(SimCommand.attack_move(sim.tick, P, ids, x, y))


func _centre(ids: PackedInt32Array) -> Vector2i:
	if ids.is_empty():
		return Vector2i(_fx(CAMP.x), _fx(CAMP.y))
	var x := 0
	var y := 0
	for id in ids:
		x += sim.entities.pos_x[id - 1]
		y += sim.entities.pos_y[id - 1]
	return Vector2i(x / ids.size(), y / ids.size())


func _nearest_enemy(from: Vector2i, at: Vector2i, radius: int) -> int:
	var best := EntityStore.NO_ID
	var best_d := 0
	var r := Fixed.from_cells(radius)
	var ax := _fx(at.x)
	var ay := _fx(at.y)
	for id in sim.entities.alive_ids:
		var s := id - 1
		if not sim.sides.hostile(P, sim.entities.owners[s]) or sim.combat.untouchable.has(id):
			continue
		if sim.entities.hp[s] <= 0:
			continue
		if _dist_sq(sim.entities.pos_x[s] - ax, sim.entities.pos_y[s] - ay) > r * r:
			continue
		var d := _dist_sq(sim.entities.pos_x[s] - from.x, sim.entities.pos_y[s] - from.y)
		if best == EntityStore.NO_ID or d < best_d:
			best = id
			best_d = d
	return best


func _dist_cells(id: int, at: Vector2i) -> int:
	var dx := sim.entities.pos_x[id - 1] - _fx(at.x)
	var dy := sim.entities.pos_y[id - 1] - _fx(at.y)
	return Fixed.to_cells(Fixed.isqrt(dx * dx + dy * dy))


static func _dist_sq(dx: int, dy: int) -> int:
	return dx * dx + dy * dy


static func _fx(cell: int) -> int:
	return Fixed.from_cells(cell) + Fixed.HALF


func _cmd(c: SimCommand) -> void:
	sim.enqueue(c)
