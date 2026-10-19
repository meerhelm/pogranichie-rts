class_name SilverBot
extends RefCounted
## A scripted player for «Корона 5. Серебро для Мальборка, 1457»: plays the mission through
## with plain player commands, so the recorded game (tests/replays/crown05_playthrough.json)
## shows that the mission can be won and keeps every trigger on the way working:
##   godot --headless -s tools/sim/sim_cli.gd -- mission --mission crown_05 \
##     --out tests/replays/crown05_playthrough.json
## It sees the whole world and is not meant to play well, only to get through. The workers build
## the manor house by the ferry and a tower by the piles of the old bridge; Barbara waits at the
## Gdańsk town hall and borrows whenever the town is calm enough; the boats carry silver from the
## pier to the castle until the ice, the wagons from the manor house all the time; the horse
## guards the road to Malbork. In the spring the hired men go to the castle gate, stand passive
## while the brothers leave, and walk into the castle yard.

const THINK_EVERY := 20
const P := 1
const STATION := Vector2i(66, 50)
const TOWER := Vector2i(101, 80)
const PIER := Vector2i(112, 40)
const PIER_WATER := Vector2i(114, 41)
const BOAT_WAIT := Vector2i(114, 48)
const LANDING := Vector2i(105, 90)
const GATE := Vector2i(107, 93)
const YARD := Vector2i(113, 96)
const HALL := Vector2i(14, 18)
const GUARD := Vector2i(88, 70)
const VILLAGE := Vector2i(52, 37)
## Borrow only while the discontent is below this (so the crowd never comes).
const CALM := 300
## Wagons wait here, away from the treasury, until there is silver to spare beyond the wages.
const WAIT := Vector2i(68, 58)

var sim: Simulation
var _told := false
var _seen := 0
## Empty carriers sent to fill up, so no more go than the treasury can fill.
var _fetching := {}


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
	if OS.has_environment("BOT_LOG") and m.fired.size() != _seen:
		_seen = m.fired.size()
		print("%d fired %s" % [sim.tick, m.fired.keys()])
	if sim.tick % THINK_EVERY != 0:
		return
	_answer()
	_workers()
	_barbara()
	_convoy()
	_wagons()
	_boats()
	_guard()
	if sim.tick % 1200 == 0 and OS.has_environment("BOT_LOG"):
		_log()


func _log() -> void:
	var m := sim.mission
	var s := m.silver
	print(
		(
			"%02d:%02d season=%d delivered=%d stock=%d road=%d patience=%d mood=%d loans=%d raids=%d n=%d"
			% [
				sim.tick / 1200,
				sim.tick / 20 % 60,
				s.season,
				s.delivered,
				sim.economy.player(P).stock[EconomySystem.SILVER],
				s.on_the_road(m),
				s.patience,
				s.discontent,
				s.loans,
				s.raids.size(),
				_mine().size(),
			]
		)
	)
	var kinds := {}
	for id in _mine():
		var t := String(sim.entities.type_ids[id - 1])
		kinds[t] = int(kinds.get(t, 0)) + 1
	print("   ", kinds)


# --- questions ------------------------------------------------------------------------------


func _answer() -> void:
	var m := sim.mission
	var s := m.silver
	var open := m.choices.keys()
	open.sort()
	for q: String in open:
		var option := 0
		if q.begins_with("loan_"):
			option = 1 if s.discontent < CALM else 2
		elif q.begins_with("crowd_"):
			option = 2
		elif q == "swedes":
			option = 1
		_cmd(SimCommand.choose(sim.tick, P, StringName(q), option))


# --- building -------------------------------------------------------------------------------


func _workers() -> void:
	var w := _of(&"pl_camp_servant")
	if w.is_empty():
		return
	var station := _building(&"pl_town_center")
	if station == 0:
		_cmd(SimCommand.build(sim.tick, P, w, &"pl_town_center", _fx(STATION.x), _fx(STATION.y)))
		return
	if sim.economy.buildings.done[station - 1] != 1:
		_help(w, station)
		return
	var tower := _building(&"pl_tower")
	if tower == 0:
		_cmd(SimCommand.build(sim.tick, P, w, &"pl_tower", _fx(TOWER.x), _fx(TOWER.y)))
	elif sim.economy.buildings.done[tower - 1] != 1:
		_help(w, tower)


func _help(w: PackedInt32Array, b: int) -> void:
	var idle := PackedInt32Array()
	for id in w:
		if sim.economy.job[id - 1] == EconomySystem.Job.NONE and _idle_one(id):
			idle.append(id)
	if not idle.is_empty():
		_cmd(SimCommand.on_building(sim.tick, P, SimCommand.Kind.WORK, idle, b))


func _building(type: StringName) -> int:
	var store := sim.economy.buildings
	for b in store.alive_ids:
		if store.owners[b - 1] == P and store.type_ids[b - 1] == type:
			if store.cell_y[b - 1] > 30:
				return b
	return 0


# --- the silver -----------------------------------------------------------------------------


func _barbara() -> void:
	var b := _of(&"hero_barbara")
	if b.is_empty() or not _idle_one(b[0]):
		return
	# Once, in the winter, she collects the tax in the village on the Gdańsk road herself.
	var to := HALL
	if sim.mission.fired.has("6") and not sim.mission.flags.has("taxed"):
		to = VILLAGE
	if _dist_cells(b[0], to) > 2:
		_cmd(SimCommand.move(sim.tick, P, b, _fx(to.x), _fx(to.y)))


## The first payment goes to the pier.
func _convoy() -> void:
	var m := sim.mission
	if m.fired.has("3"):
		return
	var ids := m.alive_of("first_convoy")
	var away := PackedInt32Array()
	for id in ids:
		if _idle_one(id) and _dist_cells(id, PIER) > 3:
			away.append(id)
	if not away.is_empty():
		_cmd(SimCommand.move(sim.tick, P, away, _fx(PIER.x), _fx(PIER.y)))


func _wagons() -> void:
	var m := sim.mission
	if not m.fired.has("3"):
		return
	var s := m.silver
	var spare := _spare() - 200 * _fetching_count(&"pl_wagon")
	for id in _of(&"pl_wagon"):
		if not _idle_one(id):
			continue
		var to := WAIT
		if s.cargo.has(id):
			_fetching.erase(id)
			to = GATE
		elif _fetching.has(id):
			to = STATION + Vector2i(2, 5)
		elif spare >= 200:
			spare -= 200
			_fetching[id] = true
			to = STATION + Vector2i(2, 5)
		if _dist_cells(id, to) > 2:
			_cmd(SimCommand.move(sim.tick, P, PackedInt32Array([id]), _fx(to.x), _fx(to.y)))


func _fetching_count(type: StringName) -> int:
	var n := 0
	for id: int in _fetching.keys():
		if not sim.entities.is_alive(id) or sim.entities.hp[id - 1] <= 0:
			_fetching.erase(id)
		elif sim.mission.silver.cargo.has(id):
			_fetching.erase(id)
		elif sim.entities.type_ids[id - 1] == type:
			n += 1
	return n


## Silver in the treasury beyond three paydays.
func _spare() -> int:
	var m := sim.mission
	return sim.economy.player(P).stock[EconomySystem.SILVER] - 3 * m.silver.wages_due(m)


func _boats() -> void:
	var m := sim.mission
	if not m.fired.has("4") or _building(&"pl_tower") == 0:
		return
	var s := m.silver
	var spare := (
		_spare() - 200 * _fetching_count(&"pl_wagon") - 300 * _fetching_count(&"pl_river_boat")
	)
	for id in _of(&"pl_river_boat"):
		if not _idle_one(id):
			continue
		var to := BOAT_WAIT
		if s.cargo.has(id):
			_fetching.erase(id)
			to = LANDING
		elif _fetching.has(id):
			to = PIER_WATER
		elif spare >= 300:
			spare -= 300
			_fetching[id] = true
			to = PIER_WATER
		if _dist_cells(id, to) > 2:
			_cmd(SimCommand.move(sim.tick, P, PackedInt32Array([id]), _fx(to.x), _fx(to.y)))


# --- the hired men --------------------------------------------------------------------------


func _guard() -> void:
	var m := sim.mission
	var men := _of(&"pl_merc_horse") + _of(&"pl_drab")
	if men.is_empty():
		return
	if m.fired.has("11"):
		_set_stance(_mine(), EntityStore.Stance.PASSIVE)
		_go(men, YARD, 3)
		return
	if m.fired.has("10"):
		_go(men, GATE, 3)
		return
	_set_stance(men, EntityStore.Stance.AGGRESSIVE)
	var raider := _raider()
	if raider != Vector2i(-1, -1):
		_go(_of(&"pl_merc_horse"), raider, 2)
	else:
		_go(_of(&"pl_merc_horse"), GUARD, 6)
	_go(_of(&"pl_drab"), STATION + Vector2i(2, 8), 6)


## The Order's rider nearest the road to Malbork, west of the Nogat, or (-1, -1).
func _raider() -> Vector2i:
	var e := sim.entities
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for id in e.alive_ids:
		if e.owners[id - 1] != 2 or e.hp[id - 1] <= 0:
			continue
		var at := Vector2i(Fixed.to_cells(e.pos_x[id - 1]), Fixed.to_cells(e.pos_y[id - 1]))
		if at.x > 120:
			continue
		var d := absi(at.x - GUARD.x) + absi(at.y - GUARD.y)
		if d < best_d:
			best_d = d
			best = at
	return best


func _go(ids: PackedInt32Array, at: Vector2i, slack: int) -> void:
	var away := PackedInt32Array()
	for id in ids:
		if _idle_one(id) and _dist_cells(id, at) > slack:
			away.append(id)
	if not away.is_empty():
		_cmd(SimCommand.attack_move(sim.tick, P, away, _fx(at.x), _fx(at.y)))


# --- helpers --------------------------------------------------------------------------------


func _set_stance(ids: PackedInt32Array, stance: int) -> void:
	var change := PackedInt32Array()
	for id in ids:
		if sim.entities.stance[id - 1] != stance:
			change.append(id)
	if not change.is_empty():
		_cmd(SimCommand.set_stance(sim.tick, P, change, stance))


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
	var e := sim.entities
	return e.orders[id - 1] == EntityStore.Order.IDLE and e.target[id - 1] == EntityStore.NO_ID


func _dist_cells(id: int, at: Vector2i) -> int:
	var e := sim.entities
	var dx := Fixed.to_cells(e.pos_x[id - 1]) - at.x
	var dy := Fixed.to_cells(e.pos_y[id - 1]) - at.y
	return maxi(absi(dx), absi(dy))


func _cmd(c: SimCommand) -> void:
	sim.enqueue(c)


static func _fx(cell: int) -> int:
	return Fixed.from_cells(cell) + Fixed.HALF
