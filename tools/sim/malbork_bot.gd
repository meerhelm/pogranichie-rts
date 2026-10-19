class_name MalborkBot
extends RefCounted
## A scripted player for «Корона 2. Мальборк, 1410»: plays the siege through to victory with
## plain player commands, so the recorded game (tests/replays/crown02_playthrough.json) shows
## that the mission can be won and keeps every trigger on the way working:
##   godot --headless -s tools/sim/sim_cli.gd -- mission --mission crown_02 \
##     --out tests/replays/crown02_playthrough.json
## It sees the whole world and is not meant to play well, only to get through: the camp servants
## put up three batteries east of the castle and the bombards fire from them; the army follows
## Jakub's party into the burned town to the church and comes back to guard the guns against the
## night sorties; a fourth battery goes up by St John's church; the priest sets up both chapels;
## an infirmary goes up once the plague asks for it; the lances ride out to meet the envoys; and
## when the siege is lifted every bombard goes to Sztum with the army behind it. The campaign
## mark of «Корона 1» (a guest knight taken for ransom) is answered at the start.

const THINK_EVERY := 20
const P := 1
## Top-left cells of the batteries east of the castle, just out of reach of its towers.
const BATTERIES: Array[Vector2i] = [
	Vector2i(56, 30), Vector2i(58, 40), Vector2i(56, 47), Vector2i(57, 53)
]
const FORGE := Vector2i(64, 45)
const LAZARET := Vector2i(67, 47)
## Where the army waits by the guns, at the town gate and at the church.
const GUARD := Vector2i(62, 42)
const TOWN_GATE := Vector2i(35, 79)
const CHURCH := Vector2i(36, 56)
const JASKO_POST := Vector2i(63, 39)
## The places of power (top-left of the site) and the road to Sztum.
const PLACES: Array[Vector2i] = [Vector2i(78, 102), Vector2i(33, 101)]
const SZTUM := Vector2i(100, 117)
const REARGUARD := Vector2i(82, 106)
const WOOD := Vector2i(72, 40)

var sim: Simulation
var _asked := false
var _told := false
var _guns_set: Dictionary[int, int] = {}
var _last_fire := -100000
var _stage := "batteries"
var _place_turn := 0


func _init(p_sim: Simulation) -> void:
	sim = p_sim


## Orders for the coming tick; call before each step.
func think() -> void:
	if sim.mission.is_over():
		if not _told and OS.has_environment("BOT_LOG"):
			_told = true
			print("over at %d: %s" % [sim.tick, sim.mission.outcome_text])
		return
	if not _asked:
		_asked = true
		_cmd(SimCommand.choose(sim.tick, P, &"mark:crown_01:captive", 0))
	if sim.tick % THINK_EVERY != 0:
		return
	var m := sim.mission
	if m.fired.has("14"):
		_stage = "sztum"
	elif m.fired.has("4"):
		_stage = "siege"
	elif m.fired.has("3"):
		_stage = "town"
	match _stage:
		"batteries":
			_build_batteries(3)
			_servants_idle_to_wood()
			_army_to(GUARD, 4)
			_guns_to_batteries()
		"town":
			_build_batteries(3)
			_servants_idle_to_wood()
			_guns_to_batteries()
			if m.fired.has("3b"):
				_army_attack(CHURCH, 3)
			else:
				_army_to(TOWN_GATE, 4)
		"siege":
			_build_batteries(4)
			_build_once(&"pl_smithy", FORGE)
			if m.fired.has("10"):
				_build_once(&"pl_lazaret", LAZARET)
			_servants_idle_to_wood()
			_guns_to_batteries()
			_fire()
			_guard()
			_envoys()
			_priest()
			_spiked_to_forge()
		"sztum":
			_to_sztum()
	if sim.tick % 600 == 0 and OS.has_environment("BOT_LOG"):
		_log()


func _log() -> void:
	var m := sim.mission
	var b := m.besiege
	var last := ""
	var at := -1
	for tid: String in m.fired:
		if m.fired[tid] >= at:
			at = m.fired[tid]
			last = tid
	var stock := sim.economy.player(P).stock
	var kinds := {}
	for id in _mine():
		var t := String(sim.entities.type_ids[id - 1])
		kinds[t] = kinds.get(t, 0) + 1
	print(kinds)
	print(
		(
			(
				"%02d:%02d %s last=%s units=%d guns=%d spiked=%d plague=%d hunger=%d night=%s"
				% [
					sim.tick / 1200,
					sim.tick / 20 % 60,
					_stage,
					last,
					_mine().size(),
					_of(&"pl_bombard").size(),
					b.spiked_total,
					b.plague,
					b.hunger,
					m.stealth.night,
				]
			)
			+ (
				" stock=%s sworn=%d brought=%d taken=%d chapels=%d"
				% [stock, b.count_towns(1), b.brought, b.taken, b.chapels(m)]
			)
		)
	)


# --- building -------------------------------------------------------------------------------


func _build_batteries(count: int) -> void:
	for i in count:
		_build_once(&"pl_battery", BATTERIES[i])


## Has the servants build the building at `at` unless one of that type already stands there.
func _build_once(type: StringName, at: Vector2i) -> void:
	var store := sim.economy.buildings
	for b in store.alive_ids:
		var s := b - 1
		if store.owners[s] == P and store.type_ids[s] == type:
			if store.cell_x[s] == at.x and store.cell_y[s] == at.y:
				if store.done[s] == 0:
					_help_build(b)
				return
	var servants := _of(&"pl_camp_servant")
	if servants.is_empty():
		return
	var def := sim.economy.db.building(type)
	if sim.economy.placement.can_place(P, def, at.x, at.y, false) != EconomySystem.Fail.OK:
		return
	if not sim.economy.player(P).can_pay(sim.economy.placement.building_cost(P, def)):
		return
	_cmd(SimCommand.build(sim.tick, P, servants, type, _fx(at.x), _fx(at.y)))


func _help_build(b: int) -> void:
	var idle := PackedInt32Array()
	for id in _of(&"pl_camp_servant"):
		if sim.economy.job[id - 1] == EconomySystem.Job.NONE:
			idle.append(id)
	if not idle.is_empty():
		_cmd(SimCommand.on_building(sim.tick, P, SimCommand.Kind.WORK, idle, b))


func _servants_idle_to_wood() -> void:
	var idle := PackedInt32Array()
	for id in _of(&"pl_camp_servant"):
		if sim.economy.job[id - 1] == EconomySystem.Job.NONE and _idle_one(id):
			idle.append(id)
	if not idle.is_empty() and sim.tick % 200 == 0:
		_cmd(SimCommand.gather_at(sim.tick, P, idle, _fx(WOOD.x), _fx(WOOD.y)))


# --- the guns -------------------------------------------------------------------------------


## Two bombards to each finished battery, in the batteries' order.
func _guns_to_batteries() -> void:
	var store := sim.economy.buildings
	var slots: Array[Vector2i] = []
	for at in BATTERIES:
		for b in store.alive_ids:
			var s := b - 1
			if store.owners[s] == P and store.type_ids[s] == &"pl_battery" and store.done[s] == 1:
				if store.cell_x[s] == at.x and store.cell_y[s] == at.y:
					slots.append(at + Vector2i(-1, 0))
					slots.append(at + Vector2i(-1, 1))
	var guns := _of(&"pl_bombard")
	for i in mini(guns.size(), slots.size()):
		var id := guns[i]
		var want := slots[i]
		if _guns_set.get(id, -1) == want.y * 1000 + want.x:
			continue
		_guns_set[id] = want.y * 1000 + want.x
		_cmd(SimCommand.move(sim.tick, P, _one(id), _fx(want.x), _fx(want.y)))


## Deployed bombards fire at the nearest castle building in reach.
func _fire() -> void:
	if sim.tick - _last_fire < 400:
		return
	_last_fire = sim.tick
	var crown := sim.combat.crown
	var store := sim.economy.buildings
	for id in _of(&"pl_bombard"):
		if not crown.deployed.has(id) or crown.spiked.has(id):
			continue
		if sim.economy.job[id - 1] != EconomySystem.Job.NONE:
			continue
		var best := 0
		var best_d := -1
		var x := sim.entities.pos_x[id - 1]
		var y := sim.entities.pos_y[id - 1]
		for b in sim.mission.besiege.castle:
			if not store.is_alive(b):
				continue
			var d := store.distance_sq(b, x, y)
			if d >= Fixed.from_cells(5) * Fixed.from_cells(5) and (best_d < 0 or d < best_d):
				best_d = d
				best = b
		if best != 0 and best_d <= Fixed.from_cells(12) * Fixed.from_cells(12):
			_cmd(SimCommand.on_building(sim.tick, P, SimCommand.Kind.ASSAULT, _one(id), best))


func _spiked_to_forge() -> void:
	for id: int in sim.combat.crown.spiked:
		if not sim.entities.is_alive(id):
			continue
		if _guns_set.get(id, -1) == -2:
			continue
		_guns_set[id] = -2
		_cmd(SimCommand.move(sim.tick, P, _one(id), _fx(FORGE.x - 1), _fx(FORGE.y + 1)))


# --- the army -------------------------------------------------------------------------------


func _army() -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in _mine():
		var t := sim.entities.type_ids[id - 1]
		if t in [&"pl_kopia", &"pl_crossbow", &"pl_foot_servant"]:
			out.append(id)
	return out


func _army_to(at: Vector2i, within: int) -> void:
	var away := PackedInt32Array()
	for id in _army():
		if _dist_cells(id, at) > within and _idle_one(id):
			away.append(id)
	if not away.is_empty():
		_cmd(SimCommand.move(sim.tick, P, away, _fx(at.x), _fx(at.y)))
	_jasko_to(JASKO_POST if not sim.mission.fired.has("3") else TOWN_GATE + Vector2i(4, 6))


func _army_attack(at: Vector2i, within: int) -> void:
	var away := PackedInt32Array()
	for id in _army():
		if _dist_cells(id, at) > within and _idle_one(id):
			away.append(id)
	if not away.is_empty():
		_cmd(SimCommand.attack_move(sim.tick, P, away, _fx(at.x), _fx(at.y)))
	_jasko_to(TOWN_GATE + Vector2i(4, 6))


## The army by the guns: on the shipmen when they come, else back to the guard post. The
## lances ride out to the envoys once they come.
func _guard() -> void:
	var foes := _foes_near(GUARD, 16, true)
	var army := _army()
	if not sim.mission.besiege.envoys_walk or sim.mission.fired.has("envoys_done"):
		pass
	var idle := PackedInt32Array()
	for id in army:
		if sim.entities.type_ids[id - 1] == &"pl_kopia" and _envoys_out():
			continue
		if _idle_one(id):
			idle.append(id)
	if idle.is_empty():
		pass
	elif foes != EntityStore.NO_ID:
		var fx := sim.entities.pos_x[foes - 1]
		var fy := sim.entities.pos_y[foes - 1]
		_cmd(SimCommand.attack_move(sim.tick, P, idle, fx, fy))
	else:
		var away := PackedInt32Array()
		for id in idle:
			if _dist_cells(id, GUARD) > 5:
				away.append(id)
		if not away.is_empty():
			_cmd(SimCommand.move(sim.tick, P, away, _fx(GUARD.x), _fx(GUARD.y)))
	_jasko_to(JASKO_POST)


func _envoys_out() -> bool:
	var b := sim.mission.besiege
	if not b.envoys_walk:
		return false
	for g: String in b.towns:
		if b.towns[g] == 0:
			return true
	return false


## The lances go to the envoy the hunters are nearest to.
func _envoys() -> void:
	if not _envoys_out() or sim.tick % 100 != 0:
		return
	var b := sim.mission.besiege
	var lances := _of(&"pl_kopia")
	if lances.is_empty():
		return
	var names := b.towns.keys()
	names.sort()
	for g: String in names:
		if b.towns[g] != 0 or g == "envoy_torun":
			continue
		var ids := sim.mission.alive_of(g)
		if ids.is_empty():
			continue
		var x := sim.entities.pos_x[ids[0] - 1]
		var y := sim.entities.pos_y[ids[0] - 1]
		_cmd(SimCommand.attack_move(sim.tick, P, lances, x, y))
		return


func _jasko_to(at: Vector2i) -> void:
	var j := _of(&"hero_jasko")
	if j.is_empty():
		return
	if _dist_cells(j[0], at) > 2 and _idle_one(j[0]):
		_cmd(SimCommand.move(sim.tick, P, j, _fx(at.x), _fx(at.y)))


## The priest sets up a cross on each place of power, then makes each a chapel.
func _priest() -> void:
	var pr := _of(&"pl_priest")
	if pr.is_empty() or not _idle_one(pr[0]) or sim.tick % 100 != 0:
		return
	var store := sim.economy.buildings
	for at in PLACES:
		var shrine := 0
		for b in store.alive_ids:
			var s := b - 1
			if store.owners[s] == P and store.type_ids[s] == &"pl_shrine":
				if store.cell_x[s] == at.x and store.cell_y[s] == at.y:
					shrine = b
		if shrine == 0:
			_cmd(SimCommand.build(sim.tick, P, pr, &"pl_shrine", _fx(at.x), _fx(at.y)))
			return
		if store.done[shrine - 1] == 0:
			_cmd(SimCommand.on_building(sim.tick, P, SimCommand.Kind.WORK, pr, shrine))
			return
		if store.upgraded[shrine - 1] == 1:
			continue
		if _dist_cells(pr[0], at) > 3:
			_cmd(SimCommand.move(sim.tick, P, pr, _fx(at.x + 2), _fx(at.y + 2)))
			return
		if sim.economy.production.can_queue(P, shrine, &"chapel") == EconomySystem.Fail.OK:
			_cmd(SimCommand.queue_item(sim.tick, P, shrine, &"chapel"))
		return


# --- the road to Sztum ----------------------------------------------------------------------


func _to_sztum() -> void:
	if sim.tick % 200 != 0:
		return
	var guns := _of(&"pl_bombard")
	if not guns.is_empty():
		var moving := PackedInt32Array()
		for id in guns:
			if sim.entities.orders[id - 1] != EntityStore.Order.MOVE:
				moving.append(id)
		if not moving.is_empty():
			_cmd(SimCommand.move(sim.tick, P, moving, _fx(SZTUM.x), _fx(SZTUM.y)))
	var tail := _centre(guns) if not guns.is_empty() else REARGUARD
	var army := PackedInt32Array()
	for id in _army():
		if _idle_one(id) and _dist_cells(id, tail) > 6:
			army.append(id)
	if not army.is_empty():
		_cmd(SimCommand.attack_move(sim.tick, P, army, _fx(tail.x - 2), _fx(tail.y - 3)))
	var rest := PackedInt32Array()
	for id in _mine():
		var t := sim.entities.type_ids[id - 1]
		if t in [&"hero_jasko", &"pl_priest", &"pl_camp_servant"] and _idle_one(id):
			if _dist_cells(id, SZTUM) > 6:
				rest.append(id)
	if not rest.is_empty():
		_cmd(SimCommand.move(sim.tick, P, rest, _fx(SZTUM.x - 4), _fx(SZTUM.y - 3)))


# --- queries --------------------------------------------------------------------------------


func _mine() -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in sim.entities.alive_ids:
		if sim.entities.owners[id - 1] == P and sim.entities.hp[id - 1] > 0:
			out.append(id)
	return out


func _of(type: StringName) -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in _mine():
		if sim.entities.type_ids[id - 1] == type:
			out.append(id)
	return out


func _idle_one(id: int) -> bool:
	var s := id - 1
	return sim.entities.orders[s] == EntityStore.Order.IDLE and sim.entities.target[s] == 0


## The enemy unit nearest `at` within `radius` cells, or NO_ID; with `safe`, only one standing
## out of reach of the castle's towers.
func _foes_near(at: Vector2i, radius: int, safe := false) -> int:
	var best := EntityStore.NO_ID
	var best_d := -1
	var r := Fixed.from_cells(radius)
	for id in sim.entities.alive_ids:
		var s := id - 1
		if sim.entities.owners[s] != 2 or sim.combat.untouchable.has(id) or sim.entities.hp[s] <= 0:
			continue
		if (
			safe
			and Fixed.to_cells(sim.entities.pos_x[s]) < 53
			and Fixed.to_cells(sim.entities.pos_y[s]) < 58
		):
			continue
		var dx := sim.entities.pos_x[s] - _fx(at.x)
		var dy := sim.entities.pos_y[s] - _fx(at.y)
		var d := dx * dx + dy * dy
		if d <= r * r and (best_d < 0 or d < best_d):
			best_d = d
			best = id
	return best


func _centre(ids: PackedInt32Array) -> Vector2i:
	var sx := 0
	var sy := 0
	for id in ids:
		sx += sim.entities.pos_x[id - 1]
		sy += sim.entities.pos_y[id - 1]
	return Vector2i(Fixed.to_cells(sx / ids.size()), Fixed.to_cells(sy / ids.size()))


func _one(id: int) -> PackedInt32Array:
	return PackedInt32Array([id])


func _dist_cells(id: int, at: Vector2i) -> int:
	var dx := sim.entities.pos_x[id - 1] - _fx(at.x)
	var dy := sim.entities.pos_y[id - 1] - _fx(at.y)
	return Fixed.to_cells(Fixed.isqrt(dx * dx + dy * dy))


static func _fx(cell: int) -> int:
	return Fixed.from_cells(cell) + Fixed.HALF


func _cmd(c: SimCommand) -> void:
	sim.enqueue(c)
