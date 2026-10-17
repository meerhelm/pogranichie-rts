class_name BaptismBot
extends RefCounted
## A scripted player for «ВКЛ 3. Крещение, 1413–1417»: plays the four chapters through to
## victory with plain player commands, so the recorded game (tests/replays/gdl03_playthrough.json)
## shows that the mission can be won and keeps every trigger on the way working:
##   godot --headless -s tools/sim/sim_cli.gd -- mission --mission gdl_03 \
##     --out tests/replays/gdl03_playthrough.json
## It sees the whole world and is not meant to play well, only to get through: build the church
## by the yard and farm round it so the farmers are baptized, buy peace from the pagans in every
## chapter with a raid (Gintaut rides to the farmstead and pays in food or silver), mine silver
## for the delegation, escort the cart to the northern ford, beat back the Order's raid at the
## church, then lay a church in each village ahead of the envoys and lead them round the grove.
## It casts nothing and never strikes a spy.

const THINK_EVERY := 20
const P := 1
const HOME := Vector2i(100, 76)
## Where the church goes and the fields round it (within the baptism radius of the church).
const CHURCH_AT := Vector2i(100, 84)
const SILVER := Vector2i(118, 52)
## Where Gintaut stands to talk to the pagans (within the talk radius, out of their sight).
const TALK_AT := Vector2i(56, 137)
## Where the army waits for the Order's raid, and meets the cart at the northern ford.
const GUARD_AT := Vector2i(96, 86)
const NORTH_FORD := Vector2i(42, 34)
const VILLAGES: Array[Vector2i] = [Vector2i(50, 104), Vector2i(104, 112), Vector2i(132, 92)]
const PEASANTS := 32
const ON_SILVER := 8

var sim: Simulation
var _sent := {}
## Peasants given an order this think (orders take effect next tick, so they still look idle).
var _ordered := {}


func _init(p_sim: Simulation) -> void:
	sim = p_sim


## Orders for the coming tick; call before each step.
func think() -> void:
	if sim.tick % THINK_EVERY != 0 or sim.mission.is_over():
		return
	_ordered.clear()
	_answer()
	_economy()
	_gintaut()
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
	print(
		(
			"%02d:%02d last=%s army=%d peasants=%d baptized=%d evidence=%d spies=%d stock=%s %s"
			% [
				sim.tick / 1200,
				sim.tick / 20 % 60,
				last,
				_soldiers().size(),
				_mine(&"gdl_peasant").size(),
				m.baptized_alive(),
				m.evidence / 1000,
				m.spies.size(),
				sim.economy.player(P).stock,
				m.flags.keys().filter(func(k: String) -> bool: return k.begins_with("truce")),
			]
		)
	)


# --- questions ------------------------------------------------------------------------------


## The pagans get food if there is enough, else silver; the envoys go round the grove.
func _answer() -> void:
	var m := sim.mission
	var stock := sim.economy.player(P).stock
	for q: String in m.choices:
		var pick := -1
		if q == "oak":
			pick = 1
		elif q.begins_with("pagans_"):
			if stock[EconomySystem.FOOD] >= 150:
				pick = 0
			elif stock[EconomySystem.SILVER] >= 100:
				pick = 1
		if pick >= 0 and not _sent.has("answered_" + q):
			_sent["answered_" + q] = sim.tick
			_cmd(SimCommand.choose(sim.tick, P, StringName(q), pick))


# --- economy --------------------------------------------------------------------------------


func _economy() -> void:
	var state := sim.economy.player(P)
	var peasants := _mine(&"gdl_peasant")
	_builder(state, peasants)
	var on_silver := 0
	var on_food := 0
	for id in peasants:
		if _on_source(id, ResourceNodes.Source.SILVER):
			on_silver += 1
		elif _on_food(id):
			on_food += 1
	var silver_wanted := ON_SILVER if not _buildings(&"gdl_mine").is_empty() else 0
	var food_wanted := peasants.size() / 3
	for id in peasants:
		if not _idle_peasant(id):
			continue
		if on_silver < silver_wanted and _silver(id):
			on_silver += 1
		elif on_food < food_wanted and _food(id):
			on_food += 1
		else:
			_wood(id)
	_train(state, peasants.size())


func _idle_peasant(id: int) -> bool:
	var s := id - 1
	return (
		not _ordered.has(id)
		and sim.economy.job[s] == EconomySystem.Job.NONE
		and sim.entities.orders[s] == EntityStore.Order.IDLE
	)


func _on_source(id: int, source: int) -> bool:
	var eco := sim.economy
	return eco.job[id - 1] == EconomySystem.Job.GATHER and eco.job_source[id - 1] == source


func _on_food(id: int) -> bool:
	var eco := sim.economy
	var s := id - 1
	if eco.job[s] == EconomySystem.Job.HUNT:
		return true
	return (
		eco.job[s] == EconomySystem.Job.GATHER
		and eco.job_source[s] in [ResourceNodes.Source.FARM, ResourceNodes.Source.HUNT]
	)


## Works a field with a free place, else hunts; false if there is neither.
func _food(id: int) -> bool:
	var store := sim.economy.buildings
	for b in _buildings(&"gdl_farm"):
		if store.workers[b - 1] < sim.economy.rules.farm_workers:
			_cmd(SimCommand.gather(sim.tick, P, _one(id), EconomySystem.Target.BUILDING, b))
			return true
	var animal := _nearest_animal(id)
	if animal != 0:
		_cmd(SimCommand.gather(sim.tick, P, _one(id), EconomySystem.Target.ANIMAL, animal))
		return true
	return false


func _silver(id: int) -> bool:
	var nodes := sim.economy.nodes
	for n in nodes.alive_ids:
		if nodes.sources[n - 1] == ResourceNodes.Source.SILVER and nodes.amounts[n - 1] > 0:
			_cmd(SimCommand.gather(sim.tick, P, _one(id), EconomySystem.Target.NODE, n))
			return true
	return false


## The next buildings the plan needs, laid by an idle peasant or a woodcutter.
func _builder(state: PlayerState, peasants: PackedInt32Array) -> void:
	var m := sim.mission
	var wants: Array = []
	if sim.economy.pop_cap(P) - state.pop_used() < 4 and sim.economy.pop_cap(P) < 80:
		wants.append([&"gdl_house", HOME + Vector2i(-6, -8)])
	if _count_b(&"gdl_temple") == 0 and not m.fired.has("9"):
		wants.append([&"gdl_temple", CHURCH_AT])
	if _count_b(&"gdl_granary") == 0:
		wants.append([&"gdl_granary", CHURCH_AT + Vector2i(6, 0)])
	if _count_b(&"gdl_farm") < 6:
		wants.append([&"gdl_farm", CHURCH_AT])
	if _count_b(&"gdl_mine") == 0:
		wants.append([&"gdl_mine", SILVER + Vector2i(-3, 0)])
	if m.fired.has("2") and _count_b(&"gdl_range") == 0:
		wants.append([&"gdl_range", HOME + Vector2i(8, -6)])
	if m.fired.has("6"):
		for v in VILLAGES:
			if not _church_near(v, true):
				wants.append([&"gdl_temple", v])
	for w: Array in wants:
		var want: StringName = w[0]
		var near: Vector2i = w[1]
		var started := _foundation(want, near)
		if started != 0:
			if not _being_built(started):
				var hand := _free_builder(peasants, near)
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
		var spot := _spot(def, near)
		if spot.x < 0:
			continue
		var builder := _free_builder(peasants, near)
		if builder != 0 and _try_build(builder, want, spot):
			_ordered[builder] = true
		return


## A church of ours (finished, if `done`) within 10 cells of the village.
func _church_near(at: Vector2i, done: bool) -> bool:
	var store := sim.economy.buildings
	for b in store.alive_ids:
		var s := b - 1
		if store.owners[s] != P or store.type_ids[s] != &"gdl_temple":
			continue
		if done and store.done[s] != 1:
			continue
		var c := Vector2i(Fixed.to_cells(store.center_x(b)), Fixed.to_cells(store.center_y(b)))
		if (c - at).length_squared() <= 100:
			return true
	return false


## An idle peasant, else a woodcutter, the nearest to `near` first.
func _free_builder(peasants: PackedInt32Array, near: Vector2i) -> int:
	var best := 0
	var best_d := 0
	for pass_no in 2:
		for id in peasants:
			if _ordered.has(id):
				continue
			var ok := _idle_peasant(id)
			if pass_no == 1:
				ok = (
					sim.economy.job[id - 1] == EconomySystem.Job.GATHER
					and sim.economy.job_source[id - 1] == ResourceNodes.Source.WOOD
				)
			if not ok:
				continue
			var d := (_cell(id) - near).length_squared()
			if best == 0 or d < best_d:
				best = id
				best_d = d
		if best != 0:
			return best
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


## A free walkable ring of cells around the footprint (and two around the yard), so buildings
## never wall the villagers in.
func _roomy(def: BuildingDef, c: Vector2i) -> bool:
	var size := sim.economy.placement.footprint(def, false)
	var nav := sim.nav
	var store := sim.economy.buildings
	var tc: int = sim.mission.named["yard"]
	for y in range(c.y - 1, c.y + size.y + 1):
		for x in range(c.x - 1, c.x + size.x + 1):
			if not nav.in_bounds(x, y):
				return false
			var cell := nav.cell_at(x, y)
			var inside := x >= c.x and y >= c.y and x < c.x + size.x and y < c.y + size.y
			if not inside and (store.occupant[cell] != 0 or not nav.passable(0, cell)):
				return false
	if not store.is_alive(tc):
		return true
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


## An unfinished building of this type within 16 cells of `near`, or 0.
func _foundation(type: StringName, near: Vector2i) -> int:
	var store := sim.economy.buildings
	for b in store.alive_ids:
		var s := b - 1
		if store.owners[s] != P or store.type_ids[s] != type or store.done[s] != 0:
			continue
		var c := Vector2i(Fixed.to_cells(store.center_x(b)), Fixed.to_cells(store.center_y(b)))
		if (c - near).length_squared() <= 256:
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
	var c0 := _cell(id)
	var store := sim.economy.buildings
	for r in range(1, 40):
		for dy in range(-r, r + 1):
			var step := 1 if absi(dy) == r else 2 * r
			for dx in range(-r, r + 1, step):
				var x: int = c0.x + dx
				var y: int = c0.y + dy
				if not nav.in_bounds(x, y):
					continue
				var c := nav.cell_at(x, y)
				if sim.economy.nodes.wood[c] > 0 and store.occupant[c] == 0:
					# The grove's oaks stay (and the far bank is the Order's).
					if x < 34 or (absi(x - 67) <= 10 and absi(y - 81) <= 10):
						continue
					_cmd(
						SimCommand.gather_at(
							sim.tick, P, _one(id), nav.center_x(c), nav.center_y(c)
						)
					)
					return


func _nearest_animal(id: int) -> int:
	var e := sim.entities
	var best := 0
	var best_d := Fixed.from_cells(30) * Fixed.from_cells(30)
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


## Peasants up to PEASANTS, spearmen and archers; food is kept for the pagans' price and the
## delegation, silver for the churches and the delegation.
func _train(state: PlayerState, peasants: int) -> void:
	var m := sim.mission
	var tc: int = m.named["yard"]
	var food := state.stock[EconomySystem.FOOD]
	if peasants < PEASANTS and food >= 200:
		_queue(tc, &"gdl_peasant")
	var reserve := 350 if m.fired.has("4") and not m.fired.has("5") else 200
	if food < reserve + 60 or _soldiers().size() >= 28:
		return
	for b in _buildings(&"gdl_barracks"):
		_queue(b, &"gdl_spearman")
	for b in _buildings(&"gdl_range"):
		if state.stock[EconomySystem.WOOD] >= 300:
			_queue(b, &"gdl_forest_archer")


func _queue(b: int, item: StringName) -> void:
	var store := sim.economy.buildings
	if not store.is_done(b) or (store.queues[b - 1] as Array).size() >= 1:
		return
	if sim.economy.production.can_queue(P, b, item) == EconomySystem.Fail.OK:
		_cmd(SimCommand.queue_item(sim.tick, P, b, item))


# --- Gintaut --------------------------------------------------------------------------------


## Gintaut rides to the farmstead when a chapter's talk is open and the price is at hand, then
## home again; he never fights.
func _gintaut() -> void:
	var m := sim.mission
	var ids := m.alive_of("gintaut")
	if ids.is_empty():
		return
	var id := ids[0]
	if not _sent.has("gintaut_stance"):
		_sent["gintaut_stance"] = true
		_cmd(SimCommand.set_stance(sim.tick, P, ids, EntityStore.Stance.PASSIVE))
	var talk := ""
	if not m.fired.has("4") and not m.fired.has("talk_1"):
		talk = "talk_1"
	elif m.fired.has("6") and not m.fired.has("8") and not m.fired.has("talk_3"):
		talk = "talk_3"
	elif m.fired.has("9") and not m.fired.has("talk_4"):
		talk = "talk_4"
	var stock := sim.economy.player(P).stock
	var can_pay := stock[EconomySystem.FOOD] >= 150 or stock[EconomySystem.SILVER] >= 100
	var to := HOME + Vector2i(-2, 6)
	if not talk.is_empty() and can_pay:
		to = TALK_AT
	if sim.entities.orders[id - 1] == EntityStore.Order.IDLE and (_cell(id) - to).length() > 3:
		_cmd(SimCommand.move(sim.tick, P, ids, Fixed.from_cells(to.x), Fixed.from_cells(to.y)))


# --- army -----------------------------------------------------------------------------------


## The army waits by the church, meets the cart at the northern ford in chapter 2 and walks with
## the envoys in chapter 4; it goes for any enemy soldier near where it is.
func _army() -> void:
	var m := sim.mission
	var army := _soldiers()
	if army.is_empty() or sim.tick - int(_sent.get("army", -1000)) < 60:
		return
	_sent["army"] = sim.tick
	var post := GUARD_AT
	if m.fired.has("5") and not m.fired.has("6"):
		var cart := m.alive_of("delegation")
		post = NORTH_FORD if cart.is_empty() else _cell(cart[0])
		if not cart.is_empty() and _cell(cart[0]).x > 60:
			post = NORTH_FORD
	elif m.fired.has("9") and not m.fired.has("12"):
		var envoys := m.alive_of("envoys")
		if not envoys.is_empty():
			post = _cell(envoys[0])
	var foe := _enemy_near(_centre(army), 14)
	if foe.x < 0:
		foe = _enemy_near(post, 14)
	var idle := PackedInt32Array()
	for id in army:
		var s := id - 1
		if sim.entities.target[s] == EntityStore.NO_ID:
			idle.append(id)
	if idle.is_empty():
		return
	if foe.x >= 0:
		_attack_move(idle, foe)
		return
	var away := PackedInt32Array()
	for id in idle:
		if (_cell(id) - post).length_squared() > 36:
			away.append(id)
	if not away.is_empty():
		_cmd(SimCommand.move(sim.tick, P, away, _fx(post.x), _fx(post.y)))


## The cell of the nearest armed enemy (the Order's soldiers or the pagans, not spies) within
## `radius` cells of `at`, or (-1, -1).
func _enemy_near(at: Vector2i, radius: int) -> Vector2i:
	var e := sim.entities
	var best := Vector2i(-1, -1)
	var best_d := radius * radius + 1
	for id in e.alive_ids:
		var s := id - 1
		if not sim.sides.hostile(P, e.owners[s]) or e.type_ids[s] == &"to_spy":
			continue
		var c := _cell(id)
		var d := (c - at).length_squared()
		if d < best_d:
			best = c
			best_d = d
	return best


func _soldiers() -> PackedInt32Array:
	var out := PackedInt32Array()
	var e := sim.entities
	for id in e.alive_ids:
		var t := e.type_ids[id - 1]
		if e.owners[id - 1] != P:
			continue
		if t in [&"gdl_peasant", &"gdl_znakharka", &"hero_keeper", &"hero_gintaut", &"gdl_wagon"]:
			continue
		if sim.combat.is_fleeing(id):
			continue
		out.append(id)
	return out


func _attack_move(ids: PackedInt32Array, at: Vector2i) -> void:
	if not ids.is_empty():
		_cmd(SimCommand.attack_move(sim.tick, P, ids, _fx(at.x), _fx(at.y)))


func _centre(ids: PackedInt32Array) -> Vector2i:
	var sx := 0
	var sy := 0
	for id in ids:
		var c := _cell(id)
		sx += c.x
		sy += c.y
	return Vector2i(sx / maxi(ids.size(), 1), sy / maxi(ids.size(), 1))


# --- queries --------------------------------------------------------------------------------


func _cell(id: int) -> Vector2i:
	var e := sim.entities
	return Vector2i(Fixed.to_cells(e.pos_x[id - 1]), Fixed.to_cells(e.pos_y[id - 1]))


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


static func _fx(cells: int) -> int:
	return Fixed.from_cells(cells) + Fixed.HALF


static func _one(id: int) -> PackedInt32Array:
	return PackedInt32Array([id])


func _cmd(c: SimCommand) -> void:
	sim.enqueue(c)
