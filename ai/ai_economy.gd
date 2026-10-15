class_name AiEconomy
extends RefCounted
## The skirmish AI's economy (M8): peasants, who gathers what, the build order, houses and
## fields as they are needed, places of power and army units. Each method is one step of the
## behaviour tree and always succeeds; the AI orders through SimCommands only.

const FOOD := EconomySystem.FOOD
const WOOD := EconomySystem.WOOD
const IRON := EconomySystem.IRON
const SILVER := EconomySystem.SILVER
## Queue at most this much in a building at once, so money is not tied up in long queues.
const QUEUE_AHEAD := 2
## Thinks the army plan waits for the money for one unit before it trains the next one instead
## (the ore near the base may be gone, and the rest of the army still has to come).
const ARMY_PATIENCE := 30
## Why a building cannot train a unit of the army plan for now and the plan moves past it.
const SKIP_FAILS: Array[int] = [
	EconomySystem.Fail.UNKNOWN,
	EconomySystem.Fail.FACTION,
	EconomySystem.Fail.AGE,
	EconomySystem.Fail.LIMIT,
]
## Free population to keep: this much, plus this much per building that trains.
const POP_HEADROOM := 4
const POP_PER_PRODUCER := 2
## How far from its anchor (cells) a building may be placed (a built-up base pushes houses
## out).
const FAR_RADIUS := 40
const SHRINE_RADIUS := 60
## A spot that could not be found is not searched for again for this many ticks.
const RETRY_TICKS := 200
## Wood within this many cells of a drop site is worth a lumber yard elsewhere.
const WOOD_SEARCH := 60
## Peasants moved from a crowded resource to a starved one per think.
const REBALANCE := 1
## A peasant explores for wood and deposits up to this far from the base, looking at points
## this many cells apart.
const EXPLORE_RADIUS := 56
const EXPLORE_STEP := 8
## A stock below LOW_STOCK doubles the resource's share of workers; above HIGH_STOCK it gets none.
const LOW_STOCK := 150
const HIGH_STOCK := 600
## Fields that are built even while the build order saves up.
const FIRST_FIELDS := 2
## Fields that may be under construction at once.
const FIELDS_AT_ONCE := 2
## A deposit farther than this (cells) from every own mine gets a mine of its own.
const MINE_REACH := 6
## A field farther than this (cells) from every place taking food gets a granary by it (the
## ВКЛ's fields go by the forest, often far from the centre).
const GRANARY_REACH := 7
## The ВКЛ's forest hive (борть): food without end for two workers, laid in the forest.
const BORT := &"bort"
## With this much food and wood piled up while every building training the army is busy, one
## more of the building the army's next unit comes from, up to MAX_PRODUCERS of a kind.
const SPARE_STOCK := 300
const MAX_PRODUCERS := 3

var ai: SkirmishAi
## Position in AiProfile.build_order and AiProfile.army.
var order_step := 0
var army_step := 0
## Thinks the army plan has waited for money on its current unit.
var army_waited := 0
## What the next build-order step will cost, kept back from army and peasants.
var reserve := PackedInt32Array([0, 0, 0, 0])
## What this think's orders have already spent (the stock changes only when they run).
var spent := PackedInt32Array([0, 0, 0, 0])

## The peasant out exploring (0 for none) and where it is going.
var explorer := 0
var explore_cell := Vector2i(-1, -1)

var _no_spot_until: Dictionary[StringName, int] = {}
## Place of power index -> unit sent to take it.
var _capturers: Dictionary[int, int] = {}


func _init(p_ai: SkirmishAi) -> void:
	ai = p_ai
	if not ai.profile.army.is_empty():
		army_step = ai.rng.next_below(ai.profile.army.size())


# --- peasants -------------------------------------------------------------------------------


## The profile's peasants, half as many again in the late game (AiMilitary.ALL_IN_TICK), when
## a bigger economy has to break the deadlock.
func peasant_target() -> int:
	var target := ai.profile.peasant_target
	return target * 3 / 2 if ai.sim.tick >= AiMilitary.ALL_IN_TICK else target


func train_peasants() -> bool:
	var tc := ai.town_center()
	if tc == 0:
		return true
	var item := ai.own_id(&"peasant")
	var queued := _queued(tc, item)
	var target := peasant_target()
	if ai.peasants.size() + queued >= target or queued >= QUEUE_AHEAD:
		return true
	# Until two thirds of the peasants are there they come first; then they wait while the
	# build order saves up (for the next age, mostly).
	_queue(tc, item, ai.peasants.size() * 3 >= target * 2)
	return true


## While peasants are short and none is in training, the army leaves the price of one.
func _peasant_reserve() -> PackedInt32Array:
	var tc := ai.town_center()
	var item := ai.own_id(&"peasant")
	var def := ai.sim.economy.db.unit(item)
	if tc == 0 or def == null or ai.peasants.size() >= peasant_target():
		return PackedInt32Array([0, 0, 0, 0])
	if _queued(tc, item) > 0:
		return PackedInt32Array([0, 0, 0, 0])
	return PackedInt32Array([def.cost_food, def.cost_wood, def.cost_iron, def.cost_silver])


## Idle peasants go to the resource furthest below its share; one peasant a think moves from
## the most crowded resource to the most starved.
func assign_workers() -> bool:
	var e := ai.sim.entities
	var eco := ai.sim.economy
	var counts := PackedInt32Array([0, 0, 0, 0])
	var idle := PackedInt32Array()
	var by_res: Array[PackedInt32Array] = [
		PackedInt32Array(), PackedInt32Array(), PackedInt32Array(), PackedInt32Array()
	]
	for id in ai.peasants:
		var slot := id - 1
		var job := eco.job[slot]
		if job == EconomySystem.Job.GATHER:
			var res := ResourceNodes.SOURCE_RESOURCE[eco.job_source[slot]]
			counts[res] += 1
			by_res[res].append(id)
		elif job == EconomySystem.Job.HUNT:
			counts[FOOD] += 1
			by_res[FOOD].append(id)
		elif job == EconomySystem.Job.NONE and e.orders[slot] == EntityStore.Order.IDLE:
			if id == explorer or ai.sim.combat.is_fleeing(id):
				continue
			idle.append(id)
	var want := _wanted_workers(counts, idle.size())
	for id in idle:
		var res := _most_needed(want, counts)
		if _send_to(id, res):
			counts[res] += 1
		elif res != WOOD and _send_to(id, WOOD):
			counts[WOOD] += 1
	for n in REBALANCE:
		var starved := _most_needed(want, counts)
		var crowded := _most_crowded(want, counts)
		if crowded < 0 or starved == crowded or want[starved] - counts[starved] < 2:
			break
		if counts[crowded] - want[crowded] < 2 or by_res[crowded].is_empty():
			break
		var mover := _least_loaded(by_res[crowded])
		if _send_to(mover, starved):
			counts[crowded] -= 1
			counts[starved] += 1
	return true


## How many gatherers each resource should have: the profile's split of all gatherers, with
## iron and silver only once there is a mine and a deposit to work.
func _wanted_workers(counts: PackedInt32Array, idle: int) -> PackedInt32Array:
	var total := idle
	for c in counts:
		total += c
	var split := ai.profile.worker_split.duplicate()
	# Short of a resource: twice the share; piled up: none.
	var st := ai.state()
	for r in 4:
		if st.stock[r] < LOW_STOCK:
			split[r] *= 2
		elif st.stock[r] > HIGH_STOCK:
			split[r] = 0
	if not _can_mine(ResourceNodes.Source.IRON):
		split[WOOD] += split[IRON]
		split[IRON] = 0
	if not _can_mine(ResourceNodes.Source.SILVER):
		split[FOOD] += split[SILVER]
		split[SILVER] = 0
	var parts := 0
	for s in split:
		parts += s
	var want := PackedInt32Array([0, 0, 0, 0])
	var given := 0
	for r in 4:
		want[r] = total * split[r] / maxi(parts, 1)
		given += want[r]
	# What rounding left over goes to food, then wood.
	want[FOOD] += total - given
	return want


func _can_mine(source: int) -> bool:
	return not ai.buildings_of(&"mine").is_empty() and _deposit(source) != 0


## The explored deposit of the kind nearest the base; 0 while none is known.
func _deposit(source: int) -> int:
	var base := ai.base_cell()
	return ai.view.nearest_deposit(source, base.x, base.y)


static func _most_needed(want: PackedInt32Array, counts: PackedInt32Array) -> int:
	var best := FOOD
	var best_gap := -(1 << 30)
	for r in 4:
		if want[r] == 0 and r != FOOD:
			continue
		var gap := want[r] - counts[r]
		if gap > best_gap:
			best = r
			best_gap = gap
	return best


static func _most_crowded(want: PackedInt32Array, counts: PackedInt32Array) -> int:
	var best := -1
	var best_gap := 0
	for r in 4:
		var gap := counts[r] - want[r]
		if gap > best_gap:
			best = r
			best_gap = gap
	return best


## The peasant carrying the least, so a move loses little.
func _least_loaded(ids: PackedInt32Array) -> int:
	var best := ids[0]
	for id in ids:
		if ai.sim.economy.carry[id - 1] < ai.sim.economy.carry[best - 1]:
			best = id
	return best


## Orders the peasant to gather the resource; false when there is nothing to gather it from.
func _send_to(id: int, res: int) -> bool:
	var sim := ai.sim
	var here := ai.unit_cell(id)
	var one := PackedInt32Array([id])
	match res:
		FOOD:
			var farm := _free_farm(here)
			if farm != 0:
				var target := EconomySystem.Target.BUILDING
				ai.order(SimCommand.gather(sim.tick, ai.player, one, target, farm))
				return true
			return false
		WOOD:
			var drop := _nearest_drop(WOOD, here)
			var cell := ai.view.nearest_wood(drop.x, drop.y, WOOD_SEARCH)
			if cell < 0:
				return false
			var p := SkirmishAi.point(Vector2i(cell % sim.nav.width, cell / sim.nav.width))
			ai.order(SimCommand.gather_at(sim.tick, ai.player, one, p.x, p.y))
			return true
	var source := ResourceNodes.Source.IRON if res == IRON else ResourceNodes.Source.SILVER
	var node := _deposit(source)
	if node == 0 or ai.buildings_of(&"mine").is_empty():
		return false
	ai.order(SimCommand.gather(sim.tick, ai.player, one, EconomySystem.Target.NODE, node))
	return true


## A finished field or hive of the AI's with room for another worker, nearest to the cell.
func _free_farm(near: Vector2i) -> int:
	var store := ai.sim.economy.buildings
	var rules := ai.sim.economy.rules
	var best := 0
	var best_d := 0
	for base: StringName in [&"farm", BORT]:
		var limit := rules.farm_workers if base == &"farm" else rules.bort_workers
		for b in ai.buildings_of(base):
			if store.done[b - 1] == 0 or store.workers[b - 1] >= limit:
				continue
			var d := _cell_dist_sq(near, _building_cell(b))
			if best == 0 or d < best_d:
				best = b
				best_d = d
	return best


## Where the resource is taken: the nearest finished own building that accepts it.
func _nearest_drop(res: int, near: Vector2i) -> Vector2i:
	var p := SkirmishAi.point(near)
	var b := ai.sim.economy.drop_site(ai.player, res, p.x, p.y)
	return _building_cell(b) if b != 0 else ai.base_cell()


## While wood, ore or silver is not found near the base, one peasant walks out to the nearest
## unexplored ground to look for it.
func explore() -> bool:
	var e := ai.sim.entities
	var base := ai.base_cell()
	var missing := ai.view.nearest_wood(base.x, base.y, EXPLORE_RADIUS) < 0
	for source: int in [ResourceNodes.Source.IRON, ResourceNodes.Source.SILVER]:
		if ai.view.nearest_deposit(source, base.x, base.y) == 0:
			missing = true
	if explorer != 0 and not (e.is_alive(explorer) and e.owners[explorer - 1] == ai.player):
		explorer = 0
	if not missing:
		explorer = 0
		return true
	if explorer == 0:
		if ai.peasants.size() < 3:
			return true
		explorer = ai.peasants[ai.peasants.size() - 1]
		explore_cell = Vector2i(-1, -1)
	var arrived := e.orders[explorer - 1] == EntityStore.Order.IDLE
	var seen := (
		explore_cell.x >= 0 and ai.view.explored(ai.sim.nav.cell_at(explore_cell.x, explore_cell.y))
	)
	if explore_cell.x >= 0 and not arrived and not seen:
		return true
	explore_cell = _unexplored_near(base)
	if explore_cell.x < 0:
		explorer = 0
		return true
	var p := SkirmishAi.point(explore_cell)
	ai.order(SimCommand.move(ai.sim.tick, ai.player, PackedInt32Array([explorer]), p.x, p.y))
	return true


## The unexplored open point within EXPLORE_RADIUS of the base that is nearest to it, counting
## the way to the middle of the map half (the edge of the map is the least likely to have
## anything); (-1, -1) if none.
func _unexplored_near(base: Vector2i) -> Vector2i:
	var nav := ai.sim.nav
	var mid := Vector2i(nav.width / 2, nav.height / 2)
	var best := Vector2i(-1, -1)
	var best_d := 0
	for y in range(EXPLORE_STEP / 2, nav.height, EXPLORE_STEP):
		for x in range(EXPLORE_STEP / 2, nav.width, EXPLORE_STEP):
			var at := Vector2i(x, y)
			var from_base := _cells_apart(base, at)
			if from_base > EXPLORE_RADIUS:
				continue
			var d := from_base * 2 + _cells_apart(at, mid)
			if best.x >= 0 and d >= best_d:
				continue
			var c := nav.cell_at(x, y)
			if ai.view.explored(c) or not nav.passable(NavGrid.MoveClass.FOOT, c):
				continue
			best = at
			best_d = d
	return best


# --- construction ---------------------------------------------------------------------------


## A foundation nobody works on gets the nearest free peasant.
func finish_foundations() -> bool:
	var eco := ai.sim.economy
	var store := eco.buildings
	var working: Dictionary[int, int] = {}
	for id in ai.peasants:
		if eco.job[id - 1] == EconomySystem.Job.BUILD:
			working[eco.job_ref[id - 1]] = working.get(eco.job_ref[id - 1], 0) + 1
	for b in ai.view.my_buildings():
		if store.done[b - 1] == 0 and not working.has(b):
			var builders := _builders_near(_building_cell(b), 1)
			if not builders.is_empty():
				var work := SimCommand.Kind.WORK
				ai.order(SimCommand.on_building(ai.sim.tick, ai.player, work, builders, b))
	return true


## A house when the population nears its limit, one at a time.
func build_houses() -> bool:
	var st := ai.state()
	var eco := ai.sim.economy
	var cap := eco.pop_cap(ai.player)
	if st == null or cap >= eco.rules.pop_cap or _unfinished(&"house") > 0:
		return true
	var producers := 1
	for base: StringName in ai.buildings_by_base:
		if base != &"town_center" and base != &"house":
			for b in ai.buildings_of(base):
				if not eco.buildings.defs[b - 1].trains.is_empty():
					producers += 1
	if cap - st.pop_used() > POP_HEADROOM + POP_PER_PRODUCER * producers:
		return true
	_build(&"house", ai.base_cell(), 3, false)
	return true


## The first build-order step not done, when it can be paid for; until then its price is kept
## back from the army.
func follow_build_order() -> bool:
	reserve = PackedInt32Array([0, 0, 0, 0])
	var plan := ai.profile.build_order
	# From the top every time, so a building the enemy has razed is built again.
	order_step = 0
	while order_step < plan.size():
		var step := plan[order_step]
		var done := _step_done(step)
		if done:
			order_step += 1
			continue
		if step == &"age":
			_take_age()
		else:
			_take_building(step)
		return true
	return true


## A build-order step is done when its age is reached (or being researched), or the AI has as
## many such buildings as the plan has asked for so far.
func _step_done(step: StringName) -> bool:
	var st := ai.state()
	if st == null:
		return true
	var asked := 0
	for i in order_step + 1:
		if ai.profile.build_order[i] == step:
			asked += 1
	if step == &"age":
		# The n-th "age" step leads to age n + 1.
		var next := ai.sim.economy.db.age_by_index(st.age + 1)
		if st.age >= 1 + asked or next == null or next.index > _max_age():
			return true
		return st.researching.has(next.id)
	var def := ai.sim.economy.db.building(ai.own_id(step))
	if def == null or def.campaign_only:
		return true
	return ai.buildings_of(step).size() >= asked


func _max_age() -> int:
	var top := 0
	for id: StringName in ai.sim.economy.db.ages:
		top = maxi(top, ai.sim.economy.db.ages[id].index)
	return top


func _take_age() -> void:
	var st := ai.state()
	var tc := ai.town_center()
	if tc == 0:
		return
	var next := ai.sim.economy.db.age_by_index(st.age + 1)
	var prod := ai.sim.economy.production
	var fail := prod.can_queue(ai.player, tc, next.id)
	var cost := prod.item_cost(ai.player, tc, next.id)
	if fail == EconomySystem.Fail.OK and _affordable(cost, false):
		ai.order(SimCommand.queue_item(ai.sim.tick, ai.player, tc, next.id))
		_spend(cost)
	elif fail == EconomySystem.Fail.OK or fail == EconomySystem.Fail.COST:
		reserve = cost


func _take_building(step: StringName) -> void:
	var def := ai.sim.economy.db.building(ai.own_id(step))
	var st := ai.state()
	if def.age > st.age:
		return
	var cost := ai.sim.economy.placement.building_cost(ai.player, def)
	if not _affordable(cost, false):
		reserve = cost
		return
	var anchor := ai.base_cell()
	var gap := 3
	match step:
		&"lumber_yard", &"mine":
			# Only once there is something to work next to it.
			anchor = _wood_anchor() if step == &"lumber_yard" else _deposit_anchor()
			if anchor.x < 0:
				return
			gap = 1
	_build(step, anchor, gap, false)


## Once the build order has a mine: one more next to the worked ore or silver deposit when
## no mine is near it, so its miners do not walk back to a mine by the other deposit.
func build_mines() -> bool:
	if ai.buildings_of(&"mine").is_empty() or _unfinished(&"mine") > 0:
		return true
	for source: int in [ResourceNodes.Source.IRON, ResourceNodes.Source.SILVER]:
		var node := _deposit(source)
		if node == 0:
			continue
		var c := ai.sim.economy.nodes.cells[node - 1]
		var at := Vector2i(c % ai.sim.nav.width, c / ai.sim.nav.width)
		var near := false
		for b in ai.buildings_of(&"mine"):
			near = near or _cells_apart(_building_cell(b), at) <= MINE_REACH
		if not near:
			_build(&"mine", at, 1, true)
			return true
	return true


## Once the build order is through, money piling up because the army cannot be trained fast
## enough buys one more barracks, range or stable (whichever trains the army plan's next unit).
func build_producers() -> bool:
	var st := ai.state()
	var plan := ai.profile.army
	if st == null or plan.is_empty() or order_step < ai.profile.build_order.size():
		return true
	if st.stock[FOOD] < SPARE_STOCK or st.stock[WOOD] < SPARE_STOCK:
		return true
	var store := ai.sim.economy.buildings
	for b in ai.view.my_buildings():
		var def := store.defs[b - 1]
		if store.done[b - 1] == 0 or def.base_id == EconomySystem.TOWN_CENTER:
			continue
		if not def.trains.is_empty() and store.queues[b - 1].size() < QUEUE_AHEAD:
			return true
	var unit := ai.sim.economy.db.unit(plan[army_step])
	if unit == null or unit.trained_at.is_empty():
		return true
	var base := StringName(String(unit.trained_at[0]).trim_prefix(String(ai.profile.faction) + "_"))
	if ai.buildings_of(base).size() >= MAX_PRODUCERS or _unfinished(base) > 0:
		return true
	_build(base, ai.base_cell(), 3, true)
	return true


## Fields for the food gatherers the split asks for, one at a time.
func build_fields() -> bool:
	var eco := ai.sim.economy
	if ai.town_center() == 0 or _unfinished(&"farm") >= FIELDS_AT_ONCE:
		return true
	var total := ai.peasants.size()
	var split := ai.profile.worker_split
	var parts := 0
	for s in split:
		parts += s
	var food := total * (split[FOOD] + split[SILVER]) / maxi(parts, 1) + 1
	var farms := ai.buildings_of(&"farm").size()
	var hives := ai.buildings_of(BORT).size()
	if _build_granary():
		return true
	if farms * eco.rules.farm_workers + hives * eco.rules.bort_workers >= food:
		return true
	# The first fields do not wait for the build order's savings; later ones do. A faction with
	# hives lays them in the forest nearest the base first (they never run out), then fields;
	# new fields go by the newest granary when there is one.
	var saving := farms + hives >= FIRST_FIELDS
	if _can_lay_hive() and _unfinished(BORT) == 0:
		if _build(BORT, _wood_anchor(), 0, saving):
			return true
	var granaries := ai.buildings_of(&"granary")
	var anchor := ai.base_cell() if granaries.is_empty() else _building_cell(granaries[-1])
	_build(&"farm", anchor, 3, saving)
	return true


func _can_lay_hive() -> bool:
	var def := ai.sim.economy.db.building(ai.own_id(BORT))
	return def != null and not def.campaign_only and _wood_anchor().x >= 0


## A granary by a finished field or hive that is far from every place taking food; true while one is
## being laid or built.
func _build_granary() -> bool:
	if _unfinished(&"granary") > 0:
		return true
	var eco := ai.sim.economy
	var sites := ai.buildings_of(&"farm") + ai.buildings_of(BORT)
	for b in sites:
		if eco.buildings.done[b - 1] == 0:
			continue
		var at := _building_cell(b)
		if _cells_apart(_nearest_drop(FOOD, at), at) > GRANARY_REACH:
			return _build(&"granary", at, 1, false)
	return false


## Lays a foundation of the building near the anchor and sends the nearest peasants; false
## if it cannot be paid or placed.
func _build(base: StringName, anchor: Vector2i, gap: int, use_reserve: bool) -> bool:
	var sim := ai.sim
	var def := sim.economy.db.building(ai.own_id(base))
	if def == null or _no_spot_until.get(base, -1) > sim.tick:
		return false
	var cost := sim.economy.placement.building_cost(ai.player, def)
	if not _affordable(cost, use_reserve):
		return false
	var spot := _find_spot(def, anchor, gap)
	if spot.x < 0:
		_no_spot_until[base] = sim.tick + RETRY_TICKS
		return false
	var builders := _builders_near(spot, 2 if def.build_ticks > 600 else 1)
	if builders.is_empty():
		return false
	var p := SkirmishAi.point(spot)
	ai.order(SimCommand.build(sim.tick, ai.player, builders, def.id, p.x, p.y))
	_spend(cost)
	return true


## Free peasants nearest to the cell: not building and not carrying much, wood cutters first.
func _builders_near(cell: Vector2i, count: int) -> PackedInt32Array:
	var eco := ai.sim.economy
	var picked := PackedInt32Array()
	var taken: Dictionary[int, bool] = {}
	for n in count:
		var best := 0
		var best_d := 0
		for id in ai.peasants:
			if taken.has(id) or id == explorer or eco.job[id - 1] == EconomySystem.Job.BUILD:
				continue
			if ai.sim.combat.is_fleeing(id):
				continue
			var d := _cell_dist_sq(cell, ai.unit_cell(id))
			if eco.job[id - 1] == EconomySystem.Job.GATHER and eco.carry_res[id - 1] != WOOD:
				d += 400
			if best == 0 or d < best_d:
				best = id
				best_d = d
		if best == 0:
			break
		taken[best] = true
		picked.append(best)
	return picked


## Top-left cell for the building on rings around the anchor, keeping `gap` free cells around
## it (fields may touch fields); (-1, -1) if there is none within FAR_RADIUS.
func _find_spot(def: BuildingDef, anchor: Vector2i, gap: int) -> Vector2i:
	var placement := ai.sim.economy.placement
	var size := placement.footprint(def, false)
	var ok := EconomySystem.Fail.OK
	for r in range(gap + 1, FAR_RADIUS + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var x := anchor.x + dx - size.x / 2
				var y := anchor.y + dy - size.y / 2
				if placement.can_place(ai.player, def, x, y, false) != ok:
					continue
				if _clear_around(x, y, size, gap if def.base_id != &"farm" else 0):
					return Vector2i(x, y)
	return Vector2i(-1, -1)


## The ring `gap` cells around the footprint is open ground (fields and hives allowed), so
## buildings never wall off a path.
func _clear_around(x0: int, y0: int, size: Vector2i, gap: int) -> bool:
	var nav := ai.sim.nav
	var store := ai.sim.economy.buildings
	for y in range(y0 - gap, y0 + size.y + gap):
		for x in range(x0 - gap, x0 + size.x + gap):
			if x >= x0 and x < x0 + size.x and y >= y0 and y < y0 + size.y:
				continue
			if not nav.in_bounds(x, y):
				return false
			var c := nav.cell_at(x, y)
			var b := store.occupant[c]
			if b != 0 and not store.defs[b - 1].tags.has(&"walkable"):
				return false
			if b == 0 and not nav.passable(NavGrid.MoveClass.FOOT, c):
				return false
	return true


## The explored forest nearest the base; (-1, -1) while none is known.
func _wood_anchor() -> Vector2i:
	var base := ai.base_cell()
	var cell := ai.view.nearest_wood(base.x, base.y, EXPLORE_RADIUS)
	if cell < 0:
		return Vector2i(-1, -1)
	return Vector2i(cell % ai.sim.nav.width, cell / ai.sim.nav.width)


## The explored ore or silver deposit nearest the base; (-1, -1) while none is known.
func _deposit_anchor() -> Vector2i:
	var base := ai.base_cell()
	var node := ai.view.nearest_deposit(ResourceNodes.Source.IRON, base.x, base.y)
	if node == 0:
		node = ai.view.nearest_deposit(ResourceNodes.Source.SILVER, base.x, base.y)
	if node == 0:
		return Vector2i(-1, -1)
	var c := ai.sim.economy.nodes.cells[node - 1]
	return Vector2i(c % ai.sim.nav.width, c / ai.sim.nav.width)


func _unfinished(base: StringName) -> int:
	var n := 0
	for b in ai.buildings_of(base):
		if ai.sim.economy.buildings.done[b - 1] == 0:
			n += 1
	return n


# --- places of power ------------------------------------------------------------------------


## The nearest places of power (AiProfile.shrines of them): a fighter (or a peasant) goes to
## take a free one, and once it is the AI's a peasant lays the shrine.
func take_places() -> bool:
	var places := ai.sim.magic.places
	if ai.profile.shrines <= 0 or places.count() == 0 or ai.town_center() == 0:
		return true
	for i in _nearest_places(ai.profile.shrines):
		if places.shrines[i] != BuildingStore.NO_ID:
			_capturers.erase(i)
			continue
		var site := Vector2i(places.cells[i] % ai.sim.nav.width, places.cells[i] / ai.sim.nav.width)
		if places.holders[i] == ai.player:
			_capturers.erase(i)
			_lay_shrine(site)
		else:
			_send_capturer(i, site)
	return true


func _nearest_places(count: int) -> PackedInt32Array:
	var places := ai.sim.magic.places
	var base := ai.base_cell()
	# Sort keys: distance first, then the index.
	var keys := PackedInt64Array()
	for i in places.count():
		var site := Vector2i(places.cells[i] % ai.sim.nav.width, places.cells[i] / ai.sim.nav.width)
		var d := _cell_dist_sq(base, site)
		if d <= SHRINE_RADIUS * SHRINE_RADIUS:
			keys.append(d * 1024 + i)
	keys.sort()
	var result := PackedInt32Array()
	for k in keys.slice(0, count):
		result.append(k % 1024)
	return result


func _lay_shrine(site: Vector2i) -> void:
	var def := ai.sim.economy.db.building(ai.own_id(&"shrine"))
	var store := ai.sim.economy.buildings
	if def == null or store.occupant[ai.sim.nav.cell_at(site.x, site.y)] != 0:
		return
	var cost := ai.sim.economy.placement.building_cost(ai.player, def)
	if not _affordable(cost, true):
		return
	if ai.sim.economy.placement.can_place(ai.player, def, site.x, site.y, false) != 0:
		return
	var builders := _builders_near(site, 1)
	if builders.is_empty():
		return
	var p := SkirmishAi.point(site)
	ai.order(SimCommand.build(ai.sim.tick, ai.player, builders, def.id, p.x, p.y))
	_spend(cost)


func _send_capturer(i: int, site: Vector2i) -> void:
	var e := ai.sim.entities
	var who: int = _capturers.get(i, 0)
	if who != 0 and e.is_alive(who):
		if e.orders[who - 1] == EntityStore.Order.IDLE:
			var p := SkirmishAi.point(site + Vector2i(1, 1))
			ai.order(SimCommand.move(ai.sim.tick, ai.player, PackedInt32Array([who]), p.x, p.y))
		return
	if ai.army.size() < 2:
		return
	who = ai.army[0]
	if ai.military_ai.in_wave(who):
		return
	_capturers[i] = who
	ai.military_ai.reserve_unit(who)
	var p := SkirmishAi.point(site + Vector2i(1, 1))
	ai.order(SimCommand.move(ai.sim.tick, ai.player, PackedInt32Array([who]), p.x, p.y))


## Units the economy has taken for places of power (the army leaves them be).
func is_capturer(id: int) -> bool:
	for i: int in _capturers:
		if _capturers[i] == id:
			return true
	return false


# --- army -----------------------------------------------------------------------------------


## The profile's army is trained in its order, so its mix is the army's mix: the next unit is
## queued where it can be trained, and the plan waits for it a while when only money is short;
## a unit whose buildings are all busy is passed over, and so are units nothing can train yet
## (no building, too early an age, a limit).
func train_army() -> bool:
	var plan := ai.profile.army
	if plan.is_empty():
		return true
	var prod := ai.sim.economy.production
	var store := ai.sim.economy.buildings
	var saved := reserve
	var peasant := _peasant_reserve()
	reserve = PackedInt32Array([0, 0, 0, 0])
	for r in 4:
		reserve[r] = saved[r] + peasant[r]
	for n in plan.size():
		var item := plan[army_step]
		var wait := false
		var queued := false
		for b in ai.view.my_buildings():
			var def := store.defs[b - 1]
			if store.done[b - 1] == 0 or def.base_id == EconomySystem.TOWN_CENTER:
				continue
			if not def.trains.has(item):
				continue
			var fail := prod.can_queue(ai.player, b, item)
			if fail in SKIP_FAILS:
				continue
			if store.queues[b - 1].size() >= QUEUE_AHEAD or fail == EconomySystem.Fail.QUEUE_FULL:
				continue
			# Free to train it: wait here for the money rather than skip ahead.
			wait = true
			if _queue(b, item, true):
				queued = true
				break
		if wait and not queued:
			army_waited += 1
			if army_waited < ARMY_PATIENCE:
				break
		army_waited = 0
		# Queued, waited long enough (a resource may have run out), or nothing free can train
		# it now (busy, no building, age, limit): on to the next one, so one busy building
		# does not hold up the others.
		army_step = (army_step + 1) % plan.size()
		if queued:
			# One a think: queues and stock change only when the command runs.
			break
	reserve = saved
	return true


func _queue(b: int, item: StringName, use_reserve: bool) -> bool:
	var prod := ai.sim.economy.production
	if prod.can_queue(ai.player, b, item) != EconomySystem.Fail.OK:
		return false
	if not _affordable(prod.item_cost(ai.player, b, item), use_reserve):
		return false
	ai.order(SimCommand.queue_item(ai.sim.tick, ai.player, b, item))
	_spend(prod.item_cost(ai.player, b, item))
	return true


func _queued(b: int, item: StringName) -> int:
	var n := 0
	for q: StringName in ai.sim.economy.buildings.queues[b - 1]:
		if q == item:
			n += 1
	return n


## The price can be paid from what this think has not spent yet, keeping the build order's
## reserve (of the resources the price takes) when asked to.
func _affordable(cost: PackedInt32Array, use_reserve: bool) -> bool:
	var st := ai.state()
	if st == null:
		return false
	for r in 4:
		var keep := reserve[r] if use_reserve and cost[r] > 0 else 0
		if st.stock[r] - spent[r] - keep < cost[r]:
			return false
	return true


## Called at the start of every think.
func begin_think() -> void:
	spent = PackedInt32Array([0, 0, 0, 0])


func _spend(cost: PackedInt32Array) -> void:
	for r in 4:
		spent[r] += cost[r]


# --- small helpers --------------------------------------------------------------------------


func _building_cell(b: int) -> Vector2i:
	var store := ai.sim.economy.buildings
	return Vector2i(
		store.cell_x[b - 1] + store.w[b - 1] / 2, store.cell_y[b - 1] + store.h[b - 1] / 2
	)


static func _cells_apart(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func _cell_dist_sq(a: Vector2i, b: Vector2i) -> int:
	return (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)
