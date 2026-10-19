class_name BalticBot
extends RefCounted
## A scripted player for «Корона 3. Балтийская вода, 1433»: marches the army to the sea with
## plain player commands, so the recorded game (tests/replays/crown03_playthrough.json) shows
## that the mission can be won and keeps every trigger on the way working:
##   godot --headless -s tools/sim/sim_cli.gd -- mission --mission crown_03 \
##     --out tests/replays/crown03_playthrough.json
## It sees the whole world and is not meant to play well, only to get through: the army covers
## the wagons out of the trenches and follows Mikołaj from camp to camp, the wagons draw up a
## ring at each camp, the monks of Pelplin are led out, the wages are paid, the foot servants set
## the westmost houses of Tczew's suburb alight and the army goes in when the gate has burned,
## the prisoners are led to Mikołaj, the lances take the villages round Gdańsk, the priest sets up
## the chapels, three banners kneel on the shore and Jaśko goes to the boulder.

const THINK_EVERY := 20
const P := 1
const CAMPS: Array[Vector2i] = [
	Vector2i(50, 168), Vector2i(50, 140), Vector2i(44, 104), Vector2i(52, 46)
]
const OUT_OF_TRENCHES := Vector2i(50, 176)
const TOWN := Vector2i(79, 103)
const SHORE := Vector2i(46, 13)
const BOULDER := Vector2i(47, 12)
## The places of power (top-left of the site) by stage: the well at Pelplin, the cross by
## Tczew, the boulder on the shore.
const PLACES: Array[Vector2i] = [Vector2i(36, 146), Vector2i(48, 116), Vector2i(46, 10)]
## The villages round Gdańsk the lances ride to (nearest the hill first).
const VILLAGES: Array[String] = ["village_7", "village_8", "village_6", "village_5"]
## Trigger fired -> stage, latest first (trigger 8 to 10go is the prisoners, see _stage_now).
const STAGES: Array[Array] = [
	["knights_done", "boulder"],
	["11b", "sea"],
	["10go", "camp_3"],
	["7", "town"],
	["6", "tczew"],
	["6go", "camp_2"],
	["3b", "camp_1"],
	["2", "camp_0"],
]
const EARLY_VILLAGES: Array[String] = ["village_1", "village_2"]
const MID_VILLAGES: Array[String] = ["village_3", "village_4"]

var sim: Simulation
var _told := false
## Lances are out taking food from the villages (not called back to the camp).
var _foraging := false
var _was_foraging := false
## Camp index -> tick the TABOR order was last given there.
var _ringed: Dictionary[int, int] = {}
var _stage := ""


func _init(p_sim: Simulation) -> void:
	sim = p_sim


## Orders for the coming tick; call before each step.
func think() -> void:
	var m := sim.mission
	if m.is_over():
		if not _told and OS.has_environment("BOT_LOG"):
			_told = true
			print("over at %d: %s" % [sim.tick, m.outcome_text])
		return
	if sim.tick % THINK_EVERY != 0:
		return
	_answer()
	_stage = _stage_now()
	match _stage:
		"leave":
			_wagons_to(OUT_OF_TRENCHES)
			_cover_wagons()
		"camp_0":
			_camp(0)
			_forage(EARLY_VILLAGES, CAMPS[0])
		"camp_1":
			_camp(1)
			_monks()
			_forage(MID_VILLAGES, CAMPS[1])
		"camp_2":
			_camp(2)
		"tczew":
			_camp(2)
			_burn_suburb()
		"town":
			_wagons_hold(2)
			_army_attack(TOWN, 4)
		"prisoners":
			_wagons_hold(2)
			_prisoners()
		"camp_3":
			_camp(3)
			if sim.mission.fired.has("10"):
				_forage(VILLAGES, CAMPS[3])
		"sea":
			_army_to(SHORE, 6)
			_wagons_to(SHORE + Vector2i(0, 8))
		"boulder":
			_jasko_to(BOULDER)
	_priest()
	if sim.tick % 600 == 0 and OS.has_environment("BOT_LOG"):
		_log()


func _stage_now() -> String:
	var f := sim.mission.fired
	if f.has("8") and not f.has("10go"):
		return "prisoners" if not f.has("9") else "camp_2"
	for step: Array in STAGES:
		if f.has(step[0]):
			return step[1]
	return "leave"


func _log() -> void:
	var m := sim.mission
	var b := m.baltic
	var last := ""
	var at := -1
	for tid: String in m.fired:
		if m.fired[tid] >= at:
			at = m.fired[tid]
			last = tid
	print(
		(
			"%02d:%02d %s last=%s units=%d wagons=%d concord=%d camps=%d/%d stock=%s"
			% [
				sim.tick / 1200,
				sim.tick / 20 % 60,
				_stage,
				last,
				_mine().size(),
				m.alive_of("wagons").size(),
				b.concord,
				b.camps_count(),
				b.camps_now,
				sim.economy.player(P).stock,
			]
		)
	)


# --- questions ------------------------------------------------------------------------------


## Wages are paid when the chest allows; banners kneel in order: lances, crossbows, foot.
func _answer() -> void:
	var m := sim.mission
	var silver := sim.economy.player(P).stock[EconomySystem.SILVER]
	for q: String in ["wages_1", "wages_2"]:
		if m.choices.has(q):
			_cmd(SimCommand.choose(sim.tick, P, StringName(q), 0 if silver >= 100 else 1))
	for k in 3:
		var q := "knight_%d" % (k + 1)
		if m.choices.has(q):
			_cmd(SimCommand.choose(sim.tick, P, StringName(q), k))


# --- the march ------------------------------------------------------------------------------


func _army() -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in _mine():
		var t := sim.entities.type_ids[id - 1]
		if t in [&"pl_kopia", &"pl_crossbow", &"pl_foot_servant", &"nt_hussite_flail"]:
			out.append(id)
	return out


func _wagons() -> PackedInt32Array:
	return _of(&"pl_wagon")


## The army stands by the wagons, on whoever comes at them.
func _cover_wagons() -> void:
	var wagons := _wagons()
	if wagons.is_empty():
		return
	var at := _centre(wagons)
	var foe := _foe_near(at, 12)
	var idle := PackedInt32Array()
	for id in _army():
		if _idle_one(id):
			idle.append(id)
	if not idle.is_empty() and foe != EntityStore.NO_ID:
		var fx := sim.entities.pos_x[foe - 1]
		var fy := sim.entities.pos_y[foe - 1]
		_cmd(SimCommand.attack_move(sim.tick, P, idle, fx, fy))
	else:
		_army_to(at + Vector2i(0, 2), 4)
	_jasko_to(at)


func _wagons_to(at: Vector2i) -> void:
	var away := PackedInt32Array()
	for id in _wagons():
		if _dist_cells(id, at) > 4 and sim.entities.orders[id - 1] == EntityStore.Order.IDLE:
			away.append(id)
	if not away.is_empty():
		_cmd(SimCommand.move(sim.tick, P, away, _fx(at.x), _fx(at.y)))


## The wagons to the camp and into a ring, the army inside it.
func _camp(i: int) -> void:
	var at := CAMPS[i]
	var wagons := _wagons()
	var far := 0
	for id in wagons:
		if _dist_cells(id, at) > 7:
			far += 1
	if far > 0:
		_wagons_to(at)
		_ringed.erase(i)
	else:
		_wagons_hold(i)
	if _foe_near(at, 14) != EntityStore.NO_ID:
		_cover_wagons()
	else:
		_army_to(at, 3)
		_jasko_to(at + Vector2i(1, 1))


## Wagons at the camp: once all stand still, the TABOR order (again if no ring stands a while).
func _wagons_hold(i: int) -> void:
	var b := sim.mission.baltic
	if b.camps_now & (1 << i):
		return
	var wagons := _wagons()
	for id in wagons:
		if sim.entities.orders[id - 1] != EntityStore.Order.IDLE:
			return
	if sim.tick - _ringed.get(i, -100000) < 600:
		return
	_ringed[i] = sim.tick
	_cmd(SimCommand.order(sim.tick, P, SimCommand.Kind.TABOR, wagons))


func _monks() -> void:
	var monks := sim.mission.alive_of("monks")
	if monks.is_empty() or sim.tick % 200 != 0:
		return
	var to := CAMPS[1]
	_cmd(SimCommand.move(sim.tick, P, monks, _fx(to.x), _fx(to.y)))


# --- Tczew ----------------------------------------------------------------------------------


## The foot servants set fire to the westmost burning-free houses of the suburb, from the west.
func _burn_suburb() -> void:
	if sim.tick % 100 != 0:
		return
	var m := sim.mission
	var store := sim.economy.buildings
	var target := 0
	for n: int in [1, 2, 3, 4]:
		var b: int = m.named.get("suburb_%d" % n, 0)
		if store.is_alive(b) and not sim.fire.is_burning(b):
			target = b
			break
	if target == 0:
		return
	var foot := PackedInt32Array()
	for id in _of(&"pl_foot_servant"):
		if not sim.fire.arson.has(id):
			foot.append(id)
	if foot.size() >= 3:
		var few := foot.slice(0, 3)
		_cmd(SimCommand.ignite(sim.tick, P, few, target))


func _prisoners() -> void:
	var held := sim.mission.alive_of("prisoners")
	var mik := sim.mission.alive_of("mikolaj")
	if held.is_empty() or mik.is_empty() or sim.tick % 100 != 0:
		return
	var x := sim.entities.pos_x[mik[0] - 1]
	var y := sim.entities.pos_y[mik[0] - 1]
	_cmd(SimCommand.move(sim.tick, P, held, x, y))
	_army_to(Vector2i(66, 104), 4)


# --- Gdańsk ---------------------------------------------------------------------------------


## The lances ride to the villages round the hill, one after another.
func _forage(list: Array[String], back: Vector2i) -> void:
	if sim.tick % 100 != 0:
		return
	_foraging = false
	var lances := _of(&"pl_kopia")
	if lances.is_empty():
		return
	var store := sim.economy.buildings
	for v in list:
		if sim.mission.baltic.villages.has(v):
			continue
		var b: int = sim.mission.named.get(v, 0)
		if not store.is_alive(b):
			continue
		_foraging = true
		_was_foraging = true
		var x := store.center_x(b)
		var y := store.center_y(b)
		_cmd(SimCommand.attack_move(sim.tick, P, lances, x, y))
		return
	if _was_foraging:
		_cmd(SimCommand.attack_move(sim.tick, P, lances, _fx(back.x), _fx(back.y)))
	_was_foraging = false


# --- the army -------------------------------------------------------------------------------


func _army_to(at: Vector2i, within: int) -> void:
	var away := PackedInt32Array()
	for id in _army():
		if _foraging and sim.entities.type_ids[id - 1] == &"pl_kopia":
			continue
		if _dist_cells(id, at) > within and _idle_one(id):
			away.append(id)
	if not away.is_empty():
		_cmd(SimCommand.attack_move(sim.tick, P, away, _fx(at.x), _fx(at.y)))
	_jasko_to(at)


func _army_attack(at: Vector2i, within: int) -> void:
	var away := PackedInt32Array()
	for id in _army():
		if _dist_cells(id, at) > within and _idle_one(id):
			away.append(id)
	if not away.is_empty():
		_cmd(SimCommand.attack_move(sim.tick, P, away, _fx(at.x), _fx(at.y)))
	_jasko_to(Vector2i(66, 104))


func _jasko_to(at: Vector2i) -> void:
	var j := _of(&"hero_jasko")
	if j.is_empty():
		return
	if _dist_cells(j[0], at) > 2 and _idle_one(j[0]):
		_cmd(SimCommand.move(sim.tick, P, j, _fx(at.x), _fx(at.y)))


## The priest sets up a cross on the place of power of the stage the army is at.
func _priest() -> void:
	var pr := _of(&"pl_priest")
	if pr.is_empty() or sim.tick % 100 != 0:
		return
	var f := sim.mission.fired
	var at := Vector2i(-1, -1)
	if f.has("knights_done") or f.has("12"):
		at = PLACES[2]
	elif f.has("6") and not f.has("10go"):
		at = PLACES[1]
	elif f.has("4") and not f.has("6go"):
		at = PLACES[0]
	if at.x < 0:
		if _idle_one(pr[0]):
			var w := _wagons()
			if not w.is_empty() and _dist_cells(pr[0], _centre(w)) > 5:
				var c := _centre(w)
				_cmd(SimCommand.move(sim.tick, P, pr, _fx(c.x), _fx(c.y)))
		return
	var store := sim.economy.buildings
	var shrine := 0
	for b in store.alive_ids:
		var s := b - 1
		if store.owners[s] == P and store.type_ids[s] == &"pl_shrine":
			if store.cell_x[s] == at.x and store.cell_y[s] == at.y:
				shrine = b
	if shrine != 0 and store.done[shrine - 1] == 1:
		return
	if not _idle_one(pr[0]) and sim.economy.job[pr[0] - 1] != EconomySystem.Job.NONE:
		return
	if shrine == 0:
		_cmd(SimCommand.build(sim.tick, P, pr, &"pl_shrine", _fx(at.x), _fx(at.y)))
	else:
		_cmd(SimCommand.on_building(sim.tick, P, SimCommand.Kind.WORK, pr, shrine))


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


## Standing about: no walk, no foe, no torch in hand.
func _idle_one(id: int) -> bool:
	var s := id - 1
	if sim.fire.arson.has(id):
		return false
	return sim.entities.orders[s] == EntityStore.Order.IDLE and sim.entities.target[s] == 0


## The nearest enemy unit (of the Order or Gdańsk) within `radius` cells of `at`, or NO_ID.
func _foe_near(at: Vector2i, radius: int) -> int:
	var best := EntityStore.NO_ID
	var best_d := -1
	var r := Fixed.from_cells(radius)
	for id in sim.entities.alive_ids:
		var s := id - 1
		if not sim.sides.hostile(P, sim.entities.owners[s]) or sim.entities.hp[s] <= 0:
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


func _dist_cells(id: int, at: Vector2i) -> int:
	var dx := sim.entities.pos_x[id - 1] - _fx(at.x)
	var dy := sim.entities.pos_y[id - 1] - _fx(at.y)
	return Fixed.to_cells(Fixed.isqrt(dx * dx + dy * dy))


static func _fx(cell: int) -> int:
	return Fixed.from_cells(cell) + Fixed.HALF


func _cmd(c: SimCommand) -> void:
	sim.enqueue(c)
