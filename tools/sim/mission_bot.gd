class_name MissionBot
extends RefCounted
## A scripted player for «ВКЛ 1. Жемайтский огонь» (M9): plays the mission through to victory
## with plain player commands, so the recorded game (tests/replays/m9_gdl01_playthrough.json)
## shows that the mission can be won and keeps every trigger on the way working:
##   godot --headless -s tools/sim/sim_cli.gd -- mission \
##     --out tests/replays/m9_gdl01_playthrough.json
## It sees the whole world (no fog) and is not meant to play well, only to get through: hunt for
## the first 300 food, build up spearmen and archers, take the grove with Gintaut at their head,
## lay the alka, wait for Rumbaudas, break into Skirsnemune and set the castle on fire, then
## split the army over the three blockade posts round Dubysa and hold them until the garrison
## gives up.

const THINK_EVERY := 20
const P := 1
const HOME := Vector2i(125, 22)
## Where the granary and the fields go: the forest edge east of the village, by the game.
const FIELDS := Vector2i(136, 22)
const GROVE := Vector2i(80, 76)
const GROVE_SITE := Vector2i(79, 75)
const SKIR_GATHER := Vector2i(100, 108)
const SKIR_BREACH := Vector2i(97, 118)
## Army sizes before each attack.
const GROVE_ARMY := 24
const SKIR_ARMY := 30
const PEASANTS := 28
## Where the army forms up before the grove and before Skirsnemune.
const GROVE_RALLY := Vector2i(100, 68)
const SKIR_RALLY := Vector2i(106, 100)
## The way round Dubysa to each blockade post (north road, river road, Neman bank).
const POST_WAYPOINTS: Array[Vector2i] = [Vector2i(80, 100), Vector2i(90, 128), Vector2i(90, 140)]

var sim: Simulation
var stage := "food"
var _sent := {}
## Peasants given an order this think (orders take effect next tick, so they still look idle).
var _ordered := {}
## Blockade post (index) of each soldier in phase 4.
var _post_of: Dictionary[int, int] = {}


func _init(p_sim: Simulation) -> void:
	sim = p_sim


## Orders for the coming tick; call before each step.
func think() -> void:
	if sim.tick % THINK_EVERY != 0 or sim.mission.is_over():
		return
	_ordered.clear()
	_economy()
	_army()
	if sim.tick % 1200 == 0 and OS.has_environment("BOT_LOG"):
		_log()


## A line a minute when BOT_LOG is set, to see where a run goes wrong.
func _log() -> void:
	var m := sim.mission
	var last := ""
	var at := -1
	for tid: String in m.fired:
		if m.fired[tid] >= at:
			at = m.fired[tid]
			last = tid
	var enemies := 0
	for id in sim.entities.alive_ids:
		if sim.entities.owners[id - 1] == 2:
			enemies += 1
	print(
		(
			"%02d:%02d %s last=%s army=%d enemies=%d garrison=%d posts=%d stock=%s"
			% [
				sim.tick / 1200,
				sim.tick / 20 % 60,
				stage,
				last,
				_soldiers().size(),
				enemies,
				m.garrison,
				m.posts_held,
				sim.economy.player(P).stock
			]
		)
	)


# --- economy --------------------------------------------------------------------------------


func _economy() -> void:
	var state := sim.economy.player(P)
	var m := sim.mission
	var peasants := _mine(&"gdl_peasant")
	var food_phase := not m.fired.has("1.4")
	_builder(state, peasants)
	var food_target := peasants.size() if food_phase else peasants.size() / 2
	var on_food := 0
	for id in peasants:
		if _on_food(id):
			on_food += 1
	for id in peasants:
		if not _idle_peasant(id):
			continue
		if on_food < food_target and _food(id):
			on_food += 1
		else:
			_wood(id)
	if not food_phase:
		_train(state, peasants.size())


func _idle_peasant(id: int) -> bool:
	var s := id - 1
	return (
		not _ordered.has(id)
		and sim.economy.job[s] == EconomySystem.Job.NONE
		and sim.entities.orders[s] == EntityStore.Order.IDLE
	)


func _on_food(id: int) -> bool:
	var eco := sim.economy
	var s := id - 1
	if eco.job[s] == EconomySystem.Job.HUNT:
		return true
	return (
		eco.job[s] == EconomySystem.Job.GATHER
		and eco.job_source[s] in [ResourceNodes.Source.FARM, ResourceNodes.Source.HUNT]
	)


## Hunts the nearest game, or works a field with a free place; false if there is neither.
func _food(id: int) -> bool:
	var animal := _nearest_animal(id)
	if animal != 0:
		_cmd(SimCommand.gather(sim.tick, P, _one(id), EconomySystem.Target.ANIMAL, animal))
		return true
	var store := sim.economy.buildings
	for b in _buildings(&"gdl_farm"):
		if store.workers[b - 1] < sim.economy.rules.farm_workers:
			_cmd(SimCommand.gather(sim.tick, P, _one(id), EconomySystem.Target.BUILDING, b))
			return true
	return false


## The next buildings the plan needs, laid by an idle peasant or a woodcutter.
func _builder(state: PlayerState, peasants: PackedInt32Array) -> void:
	var m := sim.mission
	var wants: Array = []
	if sim.economy.pop_cap(P) - state.pop_used() < 4 and sim.economy.pop_cap(P) < 75:
		wants.append([&"gdl_house", HOME])
	if m.fired.has("2.2") and _count_b(&"gdl_shrine") == 0 and _site_ours():
		wants.append([&"gdl_shrine", GROVE_SITE])
	# A second barracks and range once wood piles up.
	var halls := 1 if state.stock[EconomySystem.WOOD] < 300 else 2
	if m.fired.has("1.4") and _count_b(&"gdl_barracks") < halls:
		wants.append([&"gdl_barracks", HOME])
	if m.fired.has("1.4") and _count_b(&"gdl_range") < halls:
		wants.append([&"gdl_range", HOME])
	if _count_b(&"gdl_granary") == 0:
		wants.append([&"gdl_granary", FIELDS])
	var fields := 2 if not m.fired.has("1.4") else (8 if not m.fired.has("2.3") else 12)
	if _count_b(&"gdl_farm") < fields:
		wants.append([&"gdl_farm", FIELDS])
	for w: Array in wants:
		var want: StringName = w[0]
		var started := _foundation(want)
		if started != 0:
			if not _being_built(started):
				var hand := _free_builder(peasants)
				if hand != 0:
					_ordered[hand] = true
					_cmd(
						SimCommand.on_building(
							sim.tick, P, SimCommand.Kind.WORK, _one(hand), started
						)
					)
			continue
		var def := sim.economy.db.building(want)
		if not state.can_pay(sim.economy.placement.building_cost(P, def)):
			return
		var spot: Vector2i = GROVE_SITE if want == &"gdl_shrine" else _spot(def, w[1])
		if spot.x < 0:
			continue
		var builder := _free_builder(peasants)
		if builder != 0 and _try_build(builder, want, spot):
			_ordered[builder] = true
		return


func _free_builder(peasants: PackedInt32Array) -> int:
	for id in peasants:
		if _idle_peasant(id):
			return id
	for id in peasants:
		if sim.economy.job_source[id - 1] == ResourceNodes.Source.WOOD and not _ordered.has(id):
			if sim.economy.job[id - 1] == EconomySystem.Job.GATHER:
				return id
	return 0


func _spot(def: BuildingDef, near: Vector2i) -> Vector2i:
	for r in range(2, 32):
		for k in 32:
			var a := k * TAU / 32
			var c := near + Vector2i(roundi(r * cos(a)), roundi(r * sin(a)))
			if sim.economy.placement.can_place(P, def, c.x, c.y, false) != EconomySystem.Fail.OK:
				continue
			if _roomy(def, c):
				return c
	return Vector2i(-1, -1)


## A free walkable ring of cells around the footprint (and two around the town centre), so
## buildings never wall the villagers in.
func _roomy(def: BuildingDef, c: Vector2i) -> bool:
	var size := sim.economy.placement.footprint(def, false)
	var nav := sim.nav
	var store := sim.economy.buildings
	var tc: int = sim.mission.named["village_tc"]
	for y in range(c.y - 1, c.y + size.y + 1):
		for x in range(c.x - 1, c.x + size.x + 1):
			if not nav.in_bounds(x, y):
				return false
			var cell := nav.cell_at(x, y)
			var inside := x >= c.x and y >= c.y and x < c.x + size.x and y < c.y + size.y
			if not inside and (store.occupant[cell] != 0 or not nav.passable(0, cell)):
				return false
	var tx := store.cell_x[tc - 1]
	var ty := store.cell_y[tc - 1]
	var tw := store.w[tc - 1]
	var th := store.h[tc - 1]
	var apart_x := c.x + size.x + 2 <= tx or c.x >= tx + tw + 2
	var apart_y := c.y + size.y + 2 <= ty or c.y >= ty + th + 2
	return apart_x or apart_y


func _try_build(id: int, type: StringName, c: Vector2i) -> bool:
	var def := sim.economy.db.building(type)
	if sim.economy.placement.can_place(P, def, c.x, c.y, false) != EconomySystem.Fail.OK:
		return false
	var x := Fixed.from_cells(c.x) + Fixed.HALF
	var y := Fixed.from_cells(c.y) + Fixed.HALF
	_cmd(SimCommand.build(sim.tick, P, _one(id), type, x, y))
	return true


## An unfinished building of this type, or 0.
func _foundation(type: StringName) -> int:
	var store := sim.economy.buildings
	for b in store.alive_ids:
		if store.owners[b - 1] == P and store.type_ids[b - 1] == type and store.done[b - 1] == 0:
			return b
	return 0


func _being_built(b: int) -> bool:
	var eco := sim.economy
	for id in sim.entities.alive_ids:
		var s := id - 1
		if eco.job[s] == EconomySystem.Job.BUILD and eco.job_ref[s] == b:
			return true
	return false


func _wood(id: int) -> void:
	var nav := sim.nav
	var e := sim.entities
	var cell := nav.cell_of(e.pos_x[id - 1], e.pos_y[id - 1])
	var cx := cell % nav.width
	var cy := cell / nav.width
	for r in range(1, 30):
		for dy in range(-r, r + 1):
			var step := 1 if absi(dy) == r else 2 * r
			for dx in range(-r, r + 1, step):
				var x: int = cx + dx
				var y: int = cy + dy
				if not nav.in_bounds(x, y):
					continue
				var c := nav.cell_at(x, y)
				if sim.economy.nodes.wood[c] > 0 and sim.economy.buildings.occupant[c] == 0:
					_cmd(
						SimCommand.gather_at(
							sim.tick, P, _one(id), nav.center_x(c), nav.center_y(c)
						)
					)
					return


func _nearest_animal(id: int) -> int:
	var e := sim.entities
	var best := 0
	var best_d := Fixed.from_cells(40) * Fixed.from_cells(40)
	for a in e.alive_ids:
		var def := sim.economy.unit_defs[a - 1]
		if e.owners[a - 1] != 0 or def == null or def.food_yield <= 0:
			continue
		var dx := e.pos_x[a - 1] - e.pos_x[id - 1]
		var dy := e.pos_y[a - 1] - e.pos_y[id - 1]
		if dx * dx + dy * dy < best_d:
			best_d = dx * dx + dy * dy
			best = a
	return best


func _train(state: PlayerState, peasants: int) -> void:
	var tc: int = sim.mission.named["village_tc"]
	if peasants < PEASANTS:
		_queue(tc, &"gdl_peasant")
	for b in _buildings(&"gdl_barracks"):
		_queue(b, &"gdl_spearman")
	for b in _buildings(&"gdl_range"):
		_queue(b, &"gdl_forest_archer")
	if state.stock[EconomySystem.FOOD] > 200:
		for b in _buildings(&"gdl_shrine"):
			if _mine(&"gdl_znakharka").is_empty():
				_queue(b, &"gdl_znakharka")


func _queue(b: int, item: StringName) -> void:
	var store := sim.economy.buildings
	if not store.is_done(b) or (store.queues[b - 1] as Array).size() >= 1:
		return
	if sim.economy.production.can_queue(P, b, item) == EconomySystem.Fail.OK:
		_cmd(SimCommand.queue_item(sim.tick, P, b, item))


# --- army -----------------------------------------------------------------------------------


func _army() -> void:
	var m := sim.mission
	var army := _soldiers()
	match stage:
		"food":
			if m.fired.has("1.4"):
				stage = "build_grove"
		"build_grove":
			_move(army, GROVE_RALLY)
			if _near_count(army, GROVE_RALLY, 6) >= GROVE_ARMY:
				stage = "grove"
				_attack_move(army, GROVE, true)
		"grove":
			if not m.alive_of("grove_guard").is_empty():
				_attack_move(army, GROVE)
			elif sim.economy.buildings.is_alive(m.named["chapel"]):
				_order_once("chapel", SimCommand.Kind.ASSAULT, army, m.named["chapel"])
			else:
				_move(army, GROVE_SITE + Vector2i(1, 3))
				if m.fired.has("2.3"):
					stage = "wait_riders"
		"wait_riders":
			_move(army, SKIR_RALLY)
			if m.fired.has("3.1") and _near_count(army, SKIR_RALLY, 8) >= SKIR_ARMY:
				stage = "skirsnemune"
		"dubysa":
			_dubysa(army)
		"skirsnemune":
			if m.fired.has("3.5"):
				stage = "dubysa"
				return
			# Too few left against a garrison still standing: fall back and gather again.
			if army.size() < 15 and _enemies_near(Vector2i(100, 125), 10) > 3:
				stage = "wait_riders"
			else:
				_skirsnemune(army)


func _skirsnemune(army: PackedInt32Array) -> void:
	var m := sim.mission
	var castle: int = m.named["skir_castle"]
	if not sim.economy.buildings.is_alive(castle):
		_attack_move(army, Vector2i(110, 140))
		return
	# Break a palisade cell on the north side, then fight the garrison in the yard, then carry
	# torches to the castle.
	var store := sim.economy.buildings
	var wall := store.occupant[sim.nav.cell_at(SKIR_BREACH.x, SKIR_BREACH.y)]
	if wall != 0 and store.is_alive(wall) and store.owners[wall - 1] != P:
		var melee := PackedInt32Array()
		var ranged := PackedInt32Array()
		for id in army:
			if sim.economy.unit_defs[id - 1].attack_range > 0:
				ranged.append(id)
			else:
				melee.append(id)
		_order_once("breach", SimCommand.Kind.ASSAULT, melee, wall)
		_attack_move(ranged, SKIR_BREACH + Vector2i(0, -4))
		return
	if _enemies_near(Vector2i(100, 125), 9) > 4 or sim.fire.is_burning(castle):
		_attack_move(army, Vector2i(100, 124))
		return
	var ids := PackedInt32Array()
	for id in army:
		if sim.fire.can_ignite(id) and not sim.fire.arson.has(id):
			ids.append(id)
	if not ids.is_empty():
		_cmd(SimCommand.ignite(sim.tick, P, ids, castle))


## Every soldier goes to a post in turn (by id, so a squad keeps its post), walking round the
## castle by a waypoint (an attack-move past its walls draws the whole garrison out), and once
## there takes the defensive stance, so it beats off sorties without chasing them home.
func _dubysa(army: PackedInt32Array) -> void:
	var posts: Array = sim.mission.def.rules["blockade"]["posts"]
	var squads: Array[PackedInt32Array] = []
	for i in posts.size():
		squads.append(PackedInt32Array())
	# A soldier keeps the post it was first sent to; a new one joins the smallest squad.
	for id in army:
		if _post_of.has(id):
			squads[_post_of[id]].append(id)
	for id in army:
		if not _post_of.has(id):
			var least := 0
			for i in posts.size():
				if squads[i].size() < squads[least].size():
					least = i
			_post_of[id] = least
			squads[least].append(id)
	var e := sim.entities
	for i in posts.size():
		var at: Array = posts[i]
		var post := Vector2i(at[0], at[1])
		var via: Vector2i = POST_WAYPOINTS[i]
		var settle := PackedInt32Array()
		var to_via := PackedInt32Array()
		var to_post := PackedInt32Array()
		for id in squads[i]:
			var cell := Vector2i(Fixed.to_cells(e.pos_x[id - 1]), Fixed.to_cells(e.pos_y[id - 1]))
			var far := _cells_sq(cell, post)
			if far <= 100 and e.stance[id - 1] == EntityStore.Stance.DEFENSIVE:
				continue
			if far <= 9:
				if e.stance[id - 1] != EntityStore.Stance.DEFENSIVE:
					settle.append(id)
			elif far > _cells_sq(via, post) and _cells_sq(cell, via) > 16:
				to_via.append(id)
			else:
				to_post.append(id)
		if not settle.is_empty():
			_cmd(SimCommand.set_stance(sim.tick, P, settle, EntityStore.Stance.DEFENSIVE))
		_move(to_via, via)
		_move(to_post, post)
		# Sortie crossbowmen that stop out of a defensive spearman's reach would hold the
		# post for good: the squad goes at them.
		var foe := _enemy_by(post, 8)
		if foe.x >= 0:
			var there := PackedInt32Array()
			for id in squads[i]:
				var c := Vector2i(Fixed.to_cells(e.pos_x[id - 1]), Fixed.to_cells(e.pos_y[id - 1]))
				if _cells_sq(c, post) <= 100:
					there.append(id)
			_attack_move(there, foe)


static func _cells_sq(a: Vector2i, b: Vector2i) -> int:
	return (a - b).length_squared()


## The cell of the enemy nearest to `at` within `radius` cells, or (-1, -1).
func _enemy_by(at: Vector2i, radius: int) -> Vector2i:
	var e := sim.entities
	var best := Vector2i(-1, -1)
	var best_d := radius * radius + 1
	for id in e.alive_ids:
		if e.owners[id - 1] != 2:
			continue
		var c := Vector2i(Fixed.to_cells(e.pos_x[id - 1]), Fixed.to_cells(e.pos_y[id - 1]))
		var d := _cells_sq(c, at)
		if d < best_d:
			best = c
			best_d = d
	return best


func _enemies_near(at: Vector2i, radius: int) -> int:
	var e := sim.entities
	var x := Fixed.from_cells(at.x)
	var y := Fixed.from_cells(at.y)
	var r := Fixed.from_cells(radius)
	var n := 0
	for id in e.alive_ids:
		if e.owners[id - 1] != 2:
			continue
		var dx := e.pos_x[id - 1] - x
		var dy := e.pos_y[id - 1] - y
		if dx * dx + dy * dy <= r * r:
			n += 1
	return n


## Fighting units the player commands: everyone but peasants, casters, the keeper, and Gintaut
## when he is hurt.
func _soldiers() -> PackedInt32Array:
	var out := PackedInt32Array()
	var e := sim.entities
	for id in e.alive_ids:
		var t := e.type_ids[id - 1]
		if e.owners[id - 1] != P or t in [&"gdl_peasant", &"gdl_znakharka", &"hero_keeper"]:
			continue
		if sim.combat.is_fleeing(id):
			continue
		if t == &"hero_gintaut" and not _gintaut_fit(id):
			continue
		out.append(id)
	return out


## Gintaut fights with the army while he has more than half his HP, then rides home (his fall
## loses the mission).
func _gintaut_fit(id: int) -> bool:
	var e := sim.entities
	var s := id - 1
	if e.hp[s] * 2 > e.max_hp[s]:
		return true
	if not _sent.has("gintaut_home") or sim.tick - int(_sent["gintaut_home"]) > 200:
		_sent["gintaut_home"] = sim.tick
		var x := Fixed.from_cells(HOME.x) + Fixed.HALF
		var y := Fixed.from_cells(HOME.y + 4) + Fixed.HALF
		_cmd(SimCommand.move(sim.tick, P, _one(id), x, y))
	return false


func _near_count(ids: PackedInt32Array, at: Vector2i, radius: int) -> int:
	var e := sim.entities
	var x := Fixed.from_cells(at.x)
	var y := Fixed.from_cells(at.y)
	var r := Fixed.from_cells(radius)
	var n := 0
	for id in ids:
		var dx := e.pos_x[id - 1] - x
		var dy := e.pos_y[id - 1] - y
		if dx * dx + dy * dy <= r * r:
			n += 1
	return n


func _attack_move(ids: PackedInt32Array, at: Vector2i, all: bool = false) -> void:
	var idle := ids if all else _not_busy(ids, at)
	if not idle.is_empty():
		var x := Fixed.from_cells(at.x) + Fixed.HALF
		var y := Fixed.from_cells(at.y) + Fixed.HALF
		_cmd(SimCommand.attack_move(sim.tick, P, idle, x, y))


func _move(ids: PackedInt32Array, at: Vector2i) -> void:
	var idle := _not_busy(ids, at)
	if not idle.is_empty():
		var x := Fixed.from_cells(at.x) + Fixed.HALF
		var y := Fixed.from_cells(at.y) + Fixed.HALF
		_cmd(SimCommand.move(sim.tick, P, idle, x, y))


## Units standing about (not walking, not fighting) away from the point.
func _not_busy(ids: PackedInt32Array, at: Vector2i) -> PackedInt32Array:
	var e := sim.entities
	var out := PackedInt32Array()
	var x := Fixed.from_cells(at.x)
	var y := Fixed.from_cells(at.y)
	var r := Fixed.from_cells(4)
	for id in ids:
		var s := id - 1
		if e.orders[s] != EntityStore.Order.IDLE or e.target[s] != EntityStore.NO_ID:
			continue
		if sim.economy.job[s] != EconomySystem.Job.NONE or sim.fire.arson.has(id):
			continue
		var dx := e.pos_x[s] - x
		var dy := e.pos_y[s] - y
		if dx * dx + dy * dy > r * r:
			out.append(id)
	return out


## An order on a building, given again to units not already on it.
func _order_once(key: String, kind: SimCommand.Kind, ids: PackedInt32Array, b: int) -> void:
	var idle := PackedInt32Array()
	for id in ids:
		if sim.economy.job[id - 1] != EconomySystem.Job.ASSAULT:
			idle.append(id)
	if not idle.is_empty():
		_sent[key] = sim.tick
		_cmd(SimCommand.on_building(sim.tick, P, kind, idle, b))


# --- queries --------------------------------------------------------------------------------


func _mine(type: StringName) -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in sim.entities.alive_ids:
		if sim.entities.owners[id - 1] == P and sim.entities.type_ids[id - 1] == type:
			out.append(id)
	return out


func _buildings(type: StringName) -> PackedInt32Array:
	var out := PackedInt32Array()
	var store := sim.economy.buildings
	for b in store.alive_ids:
		if store.owners[b - 1] == P and store.type_ids[b - 1] == type and store.done[b - 1] == 1:
			out.append(b)
	return out


func _count_b(type: StringName) -> int:
	var n := 0
	var store := sim.economy.buildings
	for b in store.alive_ids:
		if store.owners[b - 1] == P and store.type_ids[b - 1] == type:
			n += 1
	return n


func _site_ours() -> bool:
	return sim.economy.placement.places.site_free_for(P, GROVE_SITE.x, GROVE_SITE.y)


static func _one(id: int) -> PackedInt32Array:
	return PackedInt32Array([id])


func _cmd(c: SimCommand) -> void:
	sim.enqueue(c)
