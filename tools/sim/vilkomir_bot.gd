class_name VilkomirBot
extends RefCounted
## A scripted player for «ВКЛ 4. Вилькомир, 1435»: plays the mission through to victory with
## plain player commands, so the recorded game (tests/replays/gdl04_playthrough.json) shows that
## the mission can be won and keeps every trigger on the way working:
##   godot --headless -s tools/sim/sim_cli.gd -- mission --mission gdl_04 \
##     --out tests/replays/gdl04_playthrough.json
## It sees the whole world and is not meant to play well, only to get through. The two nights:
## servants put up a stable and an archery range and the camp hires light horse and archers;
## the light horse keep the dry strip north of the lake against the Tatar raids; the lances
## take the spring on the island. Before dawn the army waits at the lake's end; at dawn it
## crosses the middle ford and holds the road in the column's middle until the column falls
## apart, then fights whoever is nearest, going for Nesselrode and Kerskorf once the Livonians
## turn back. Mikołaj rides behind the army.

const THINK_EVERY := 20
const P := 1
const CAMP := Vector2i(125, 59)
const STRIP := Vector2i(88, 31)
const STAGING := Vector2i(76, 29)
const FORD := Vector2i(56, 37)
const CUT := Vector2i(50, 46)
const SPRING := Vector2i(85, 72)
## When the army gathers at the lake's end (a little before dawn).
const GATHER_TICK := 12600
## How long after dawn the army waits at the lake's end before it goes for the ford.
const WAIT_AT_DAWN := 1700
## How far behind the army's centre Mikołaj keeps.
const BEHIND := 5
const NOT_SOLDIERS: Array[StringName] = [&"hero_mikolaj", &"gdl_camp_servant", &"gdl_znakharka"]

var sim: Simulation
var _sent: Dictionary[String, int] = {}
var _last_order := -100000


func _init(p_sim: Simulation) -> void:
	sim = p_sim


## Orders for the coming tick; call before each step.
func think() -> void:
	if sim.tick % THINK_EVERY != 0 or sim.mission.is_over():
		return
	var m := sim.mission
	_camp()
	if not m.fired.has("2.1"):
		_night()
	elif not m.fired.has("2.3"):
		_cut()
	else:
		_battle()
	_mikolaj()
	_mist()
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
	var foes := {}
	for id in sim.entities.alive_ids:
		var o := sim.entities.owners[id - 1]
		foes[o] = foes.get(o, 0) + 1
	var hero := m.alive_of("mikolaj")
	print(
		(
			"%02d:%02d last=%s army=%d units=%s captives=%d exited=%s mikolaj=%d"
			% [
				sim.tick / 1200,
				sim.tick / 20 % 60,
				last,
				_soldiers().size(),
				foes,
				m.captives,
				m.exited,
				sim.entities.hp[hero[0] - 1] if not hero.is_empty() else 0,
			]
		)
	)


# --- the camp -------------------------------------------------------------------------------


## Servants put up a stable and an archery range once; the camp hires light horse and archers.
func _camp() -> void:
	if sim.tick % 100 != 0:
		return
	var servants := _of_type(&"gdl_camp_servant", false)
	if servants.size() >= 2:
		if not _sent.has("stable"):
			if _build(servants.slice(0, 5), &"gdl_stable", Vector2i(115, 64)):
				_sent["stable"] = sim.tick
		elif not _sent.has("range"):
			if _build(servants.slice(5, 10), &"gdl_range", Vector2i(121, 66)):
				_sent["range"] = sim.tick
	var state := sim.economy.player(P)
	for b in _buildings(&"gdl_stable"):
		if state.stock[EconomySystem.FOOD] >= 200:
			_queue(b, &"gdl_light_horse")
	for b in _buildings(&"gdl_range"):
		if state.stock[EconomySystem.WOOD] >= 60:
			_queue(b, &"gdl_castle_archer")


## Lays the building near `near` (the first free spot on rings around it).
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
				var x := Fixed.from_cells(c.x) + Fixed.HALF
				var y := Fixed.from_cells(c.y) + Fixed.HALF
				_cmd(SimCommand.build(sim.tick, P, ids, type, x, y))
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


# --- the two nights -------------------------------------------------------------------------


## The light horse keep the strip, the lances take the spring, the rest wait in camp; before
## dawn everyone gathers at the lake's end.
func _night() -> void:
	if sim.tick - _last_order < 100:
		return
	_last_order = sim.tick
	var m := sim.mission
	var gather := sim.tick >= GATHER_TICK
	# Light horse: any raider near the strip or the camp is ridden down, else back to the strip.
	var riders := _idle(_of_type(&"gdl_light_horse", true))
	if not riders.is_empty():
		var foe := _nearest_enemy(_centre(riders), STRIP, 16)
		if foe == EntityStore.NO_ID:
			foe = _nearest_enemy(_centre(riders), CAMP, 16)
		if foe != EntityStore.NO_ID:
			_attack_move_to(riders, foe)
		else:
			_go(riders, STAGING if gather else STRIP, 5, true)
	# The lances take the spring and come back.
	var lances := _of_type(&"gdl_lit_lance", true)
	var held := sim.magic.places.holders[1] == P
	if not held and sim.tick >= 600:
		var idle := _idle(lances)
		var patrol := m.alive_of("patrol")
		if not patrol.is_empty():
			if not idle.is_empty():
				_attack_move_to(idle, patrol[0])
		else:
			_go(idle, SPRING, 1, false)
	elif gather:
		_go(_idle(lances), STAGING, 6, false)
	else:
		_go(_idle(lances), CAMP + Vector2i(-10, -4), 6, false)
	if gather:
		var rest := PackedInt32Array()
		for id in _soldiers():
			var t := sim.entities.type_ids[id - 1]
			if t != &"gdl_light_horse" and t != &"gdl_lit_lance":
				rest.append(id)
		_go(_idle(rest), STAGING, 7, false)


# --- dawn: the cut --------------------------------------------------------------------------


## Everyone goes over the middle ford to the road and holds it: idle units near the point
## strike the nearest enemy, the others come to it.
func _cut() -> void:
	if sim.tick - _last_order < 40:
		return
	_last_order = sim.tick
	# Wait at the lake's end until the column's head is over the stream, in the allies' hands.
	if sim.tick < sim.mission.fired["2.1"] + WAIT_AT_DAWN:
		return
	var army := _soldiers()
	var far := PackedInt32Array()
	var close := PackedInt32Array()
	for id in _idle(army):
		if _dist_cells(id, CUT) > 6:
			far.append(id)
		else:
			close.append(id)
	if not far.is_empty():
		# Over the middle ford: units still north of the stream aim at the ford first.
		var north := PackedInt32Array()
		var south := PackedInt32Array()
		for id in far:
			if Fixed.to_cells(sim.entities.pos_y[id - 1]) < 35:
				north.append(id)
			else:
				south.append(id)
		if not north.is_empty():
			_cmd(SimCommand.attack_move(sim.tick, P, north, _fx(FORD.x), _fx(FORD.y + 3)))
		if not south.is_empty():
			_cmd(SimCommand.attack_move(sim.tick, P, south, _fx(CUT.x), _fx(CUT.y)))
	if not close.is_empty():
		var foe := _nearest_enemy(_centre(close), CUT, 8)
		if foe != EntityStore.NO_ID:
			_cmd(SimCommand.attack(sim.tick, P, close, foe))


# --- the battle -----------------------------------------------------------------------------


## After the cut: the lances go for the Livonian heroes once the Livonians turn back (riders and
## archers take the nearest enemy), everyone else the nearest enemy anywhere.
func _battle() -> void:
	if sim.tick - _last_order < 60:
		return
	_last_order = sim.tick
	var m := sim.mission
	var army := _idle(_soldiers())
	if army.is_empty():
		return
	var heroes := m.alive_of("nesselrode")
	heroes.append_array(m.alive_of("kerskorf"))
	if m.fired.has("3.1") and not heroes.is_empty():
		var lances := PackedInt32Array()
		var rest := PackedInt32Array()
		for id in army:
			if sim.entities.type_ids[id - 1] == &"gdl_lit_lance":
				lances.append(id)
			else:
				rest.append(id)
		if not lances.is_empty():
			var target := _nearest_of(_centre(lances), heroes)
			_cmd(SimCommand.attack(sim.tick, P, lances, target))
		army = rest
		if army.is_empty():
			return
	var foe := _nearest_enemy(_centre(army), CUT, 200)
	if foe != EntityStore.NO_ID:
		_attack_move_to(army, foe)


# --- Mikołaj and the znakharka --------------------------------------------------------------


## Mikołaj keeps BEHIND cells behind the army's centre, on the camp's side; hurt, he goes home.
func _mikolaj() -> void:
	if sim.tick % 100 != 0:
		return
	var ids := sim.mission.alive_of("mikolaj")
	if ids.is_empty():
		return
	var id := ids[0]
	if not _sent.has("mikolaj_stance"):
		_sent["mikolaj_stance"] = sim.tick
		_cmd(SimCommand.set_stance(sim.tick, P, ids, EntityStore.Stance.DEFENSIVE))
	var e := sim.entities
	if e.hp[id - 1] * 2 < e.max_hp[id - 1]:
		_cmd(SimCommand.move(sim.tick, P, ids, _fx(CAMP.x), _fx(CAMP.y)))
		return
	var army := _soldiers()
	if army.is_empty() or not sim.mission.fired.has("2.1") and sim.tick < GATHER_TICK:
		return
	var c := _centre(army)
	var back := Vector2i(_fx(STAGING.x), _fx(STAGING.y))
	var bx := back.x - c.x
	var by := back.y - c.y
	var len := maxi(Fixed.isqrt(bx * bx + by * by), 1)
	var px := c.x + bx * Fixed.from_cells(BEHIND) / len
	var py := c.y + by * Fixed.from_cells(BEHIND) / len
	_cmd(SimCommand.move(sim.tick, P, ids, px, py))
	var witch := _of_type(&"gdl_znakharka", false)
	if not witch.is_empty():
		_cmd(SimCommand.move(sim.tick, P, witch, px, py))


## At dawn the znakharka lays «Bog mist» over the middle ford if there is Сила for it.
func _mist() -> void:
	var m := sim.mission
	if not m.fired.has("2.1") or m.fired.has("2.3") or _sent.has("mist"):
		return
	var witch := _of_type(&"gdl_znakharka", false)
	if witch.is_empty():
		return
	if sim.magic.can_cast(P, witch[0], &"sp_bog_mist") != MagicSystem.Cast.OK:
		return
	_sent["mist"] = sim.tick
	_cmd(SimCommand.cast(sim.tick, P, witch, &"sp_bog_mist", _fx(FORD.x), _fx(FORD.y)))


# --- queries --------------------------------------------------------------------------------


## Fighting units: everyone of ours but Mikołaj, the servants and the znakharka, not fleeing.
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


func _of_type(t: StringName, fit: bool) -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in sim.entities.alive_ids:
		var s := id - 1
		if sim.entities.owners[s] == P and sim.entities.type_ids[s] == t:
			if not fit or not sim.combat.is_fleeing(id):
				out.append(id)
	return out


func _idle(ids: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in ids:
		var s := id - 1
		if sim.entities.orders[s] == EntityStore.Order.IDLE and sim.entities.target[s] == 0:
			out.append(id)
	return out


## Sends those farther than `within` cells from `at` there (in attack if `attack`).
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


## The enemy unit nearest to `from` (fixed point) within `radius` cells of `at`, one that may be
## attacked.
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


func _nearest_of(from: Vector2i, ids: PackedInt32Array) -> int:
	var best := ids[0]
	var best_d := -1
	for id in ids:
		var d := _dist_sq(sim.entities.pos_x[id - 1] - from.x, sim.entities.pos_y[id - 1] - from.y)
		if best_d < 0 or d < best_d:
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
