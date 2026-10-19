# gdlint:ignore = max-public-methods
class_name EconomySystem
extends RefCounted
## Economy and construction (M5), run by Simulation every tick before movement. Integers only,
## ascending ids, so it plays out the same everywhere. Every number comes from EconomyRulesDef
## and the catalog defs.
##
## Players join with a faction and a starting stock. Peasants gather into what they carry
## (rules.carry) and take it to the nearest own building that accepts it: wood from forest cells,
## iron and silver from map deposits, food from fields, hives and hunted animals. Builders put
## up foundations (several speed it up), repair, fell zaseki out of the forest and lay palisades
## cell by cell. Buildings train units and research techs and ages from a queue, within the
## population limit.

## What a unit is busy with besides plain orders.
enum Job { NONE, GATHER, HUNT, BUILD, ASSAULT, DISMANTLE }
## A gather job walks to its work, works, and carries the load back.
enum Phase { GO, WORK, RETURN }
## What a GATHER command points at (SimCommand.value).
enum Target { CELL, NODE, BUILDING, ANIMAL }
## Why a building cannot go somewhere (can_place) or a queue item cannot be ordered.
enum Fail {
	OK,
	NO_PLAYER,
	UNKNOWN,
	FACTION,
	AGE,
	OUT_OF_MAP,
	TERRAIN,
	OCCUPIED,
	NOT_FOREST,
	NO_FOREST_NEAR,
	POWER_PLACE,
	COST,
	QUEUE_FULL,
	LIMIT,
	CONDITION,
	LOCKED,
	DISMANTLING,
	NO_SPRING,
	TOO_MANY,
}

const FOOD := 0
const WOOD := 1
const IRON := 2
const SILVER := 3
const RESOURCE_NAMES: Array[StringName] = [&"food", &"wood", &"iron", &"silver"]
## Thousandths of a resource unit times ticks per second: one whole unit gathered.
const UNIT_ACC := 1000 * Fixed.TICKS_PER_SECOND
## A worker that cannot get to its work after this many walks gives up.
const MAX_WALK_TRIES := 3
## How far around a footprint a worker looks for a free cell to stand on.
const STAND_RINGS := 3
const FOREST := &"t_forest"
const GRASS := &"t_grass"
## A click on the forest: the peasant starts on the cell within this many cells of it that is
## nearest to where the wood is carried.
const WOOD_PICK_CELLS := 3
const GATE := &"gate"
const TOWN_CENTER := &"town_center"
const MELEE := &"melee"
const PIERCE := &"pierce"
const SIEGE := &"siege"

var entities: EntityStore
var nav: NavGrid
var db: CatalogDB
var rules: EconomyRulesDef
var combat: CombatSystem
## Allies (set by Simulation): their buildings cannot be assaulted.
var sides := Sides.new()
var tick := 0
var players: Dictionary[int, PlayerState] = {}
var buildings := BuildingStore.new()
var nodes := ResourceNodes.new()
## Where buildings may stand and their prices; queues, training and research. Both work on
## this system's players and buildings.
var placement: BuildingPlacement
var production: EconomyProduction
## Building, repairing and taking apart.
var construction: Construction

# Per unit, by slot (id - 1).
var unit_defs: Array[UnitDef] = []
var job := PackedByteArray()
var phase := PackedByteArray()
## ResourceNodes.Source of a gather job, and what it works on: a cell, node, building or animal.
var job_source := PackedByteArray()
var job_target := PackedByteArray()
var job_ref := PackedInt32Array()
## 1 while the unit counts as one of a field's or hive's workers.
var claimed := PackedByteArray()
## What it carries: resource index (-1 nothing) and amount.
var carry_res := PackedInt32Array()
var carry := PackedInt32Array()
## Gathering progress toward the next whole unit (UNIT_ACC = one unit).
var gather_acc := PackedInt32Array()
var tries := PackedInt32Array()
## The building an assault was ordered at, while the unit breaks a wall on the way (Breach).
var assault_goal := PackedInt32Array()

var _walk: Callable
var _stop: Callable
var _forest := -1
var _grass := -1
var _drop_sites := DropSites.new()


## `walk(id, x, y)` and `stop(id)` move units; `spawn(type_id, player, x, y) -> id` creates one.
func _init(
	p_entities: EntityStore,
	p_nav: NavGrid,
	p_db: CatalogDB,
	p_combat: CombatSystem,
	walk: Callable,
	stop: Callable,
	spawn: Callable
) -> void:
	entities = p_entities
	nav = p_nav
	db = p_db
	rules = db.economy if db != null else null
	combat = p_combat
	_walk = walk
	_stop = stop
	placement = BuildingPlacement.new(self)
	production = EconomyProduction.new(self, walk, spawn)
	construction = Construction.new(_self)
	_forest = nav.terrain_index(FOREST)
	_grass = nav.terrain_index(GRASS)
	var n := nav.cell_count()
	buildings.resize_map(n)
	nodes.wood.resize(n)
	nodes.wood.fill(0)
	if rules == null:
		return
	for cell in n:
		if _forest >= 0 and nav.terrain[cell] == _forest:
			nodes.wood[cell] = rules.tree_wood
		match nav.object_at(cell):
			&"o_bog_ore":
				nodes.add(ResourceNodes.Source.IRON, cell, rules.bog_ore_iron, true)
				nav.set_blocked(cell, true)
			&"o_silver_mine":
				nodes.add(ResourceNodes.Source.SILVER, cell, rules.silver_mine_silver, true)
				nav.set_blocked(cell, true)
			SaltWorks.SPRING:
				nodes.add(ResourceNodes.Source.SILVER, cell, rules.salt_spring_silver, true)
				nav.set_blocked(cell, true)


func enabled() -> bool:
	return rules != null


## This system, for parts that must not hold it (Construction).
func _self() -> EconomySystem:
	return self


func player(p: int) -> PlayerState:
	return players.get(p)


# --- units come and go ---------------------------------------------------------------------


func on_spawn(id: int, def: UnitDef) -> void:
	unit_defs.append(def)
	job.append(Job.NONE)
	phase.append(Phase.GO)
	job_source.append(0)
	job_target.append(0)
	job_ref.append(0)
	claimed.append(0)
	carry_res.append(-1)
	carry.append(0)
	gather_acc.append(0)
	tries.append(0)
	assault_goal.append(0)
	var p := player(entities.owners[id - 1])
	if p != null and def != null:
		p.pop_units += def.pop
		production.apply_mods(id)


## Called before a unit leaves the world. A hunted animal leaves its carcass.
func on_remove(id: int) -> void:
	var slot := id - 1
	if slot >= unit_defs.size():
		return
	end_job(slot)
	var def := unit_defs[slot]
	var p := player(entities.owners[slot])
	if p != null and def != null:
		p.pop_units -= def.pop
	if def != null and def.food_yield > 0 and entities.hp[slot] <= 0 and enabled():
		var cell := nav.cell_of(entities.pos_x[slot], entities.pos_y[slot])
		nodes.add(ResourceNodes.Source.HUNT, cell, def.food_yield, false, id)


## Plain orders (move, stop, attack, retreat) end whatever job the units had.
func drop_jobs(ids: PackedInt32Array) -> void:
	for id in ids:
		if id - 1 < job.size():
			end_job(id - 1)


func end_job(slot: int) -> void:
	_unclaim(slot)
	job[slot] = Job.NONE
	phase[slot] = Phase.GO
	tries[slot] = 0
	gather_acc[slot] = 0


func _unclaim(slot: int) -> void:
	if claimed[slot] == 1:
		claimed[slot] = 0
		var b := job_ref[slot]
		if buildings.is_alive(b):
			buildings.workers[b - 1] -= 1


# --- commands ------------------------------------------------------------------------------


## Economy commands. `units` are the command's alive units that obey (for unit orders).
func order(cmd: SimCommand, units: PackedInt32Array) -> void:
	if not enabled():
		return
	match cmd.kind:
		SimCommand.Kind.JOIN:
			_join(cmd.player, cmd.type_id)
		SimCommand.Kind.PLACE:
			var def := db.building(cmd.type_id)
			if def != null and players.has(cmd.player):
				var at := Vector2i(Fixed.to_cells(cmd.x), Fixed.to_cells(cmd.y))
				if (
					placement.can_place(cmd.player, def, at.x, at.y, cmd.value == 1, true)
					== Fail.OK
				):
					var b := _found(cmd.player, def, at.x, at.y, cmd.value == 1)
					complete(b)
		SimCommand.Kind.BUILD:
			_order_build(cmd, units)
		SimCommand.Kind.WALL:
			_order_wall(cmd, units)
		SimCommand.Kind.GATHER:
			_order_gather(cmd, units)
		SimCommand.Kind.WORK:
			for id in units:
				_set_build_job(id, cmd.target)
		SimCommand.Kind.ASSAULT:
			_order_assault(cmd, units)
		SimCommand.Kind.DISMANTLE:
			construction.order_dismantle(cmd, units)
		SimCommand.Kind.QUEUE:
			if not cmd.ids.is_empty():
				production.enqueue(cmd.player, cmd.ids[0], cmd.type_id)
		SimCommand.Kind.CANCEL:
			if not cmd.ids.is_empty():
				production.cancel(cmd.player, cmd.ids[0], cmd.value)
		SimCommand.Kind.BUILDING_RALLY:
			for b in cmd.ids:
				if buildings.is_alive(b) and buildings.owners[b - 1] == cmd.player:
					buildings.rally_x[b - 1] = cmd.x
					buildings.rally_y[b - 1] = cmd.y
					buildings.has_rally[b - 1] = 1


func _join(p: int, faction: StringName) -> void:
	if players.has(p) or db.faction(faction) == null:
		return
	var state := PlayerState.new(p, faction)
	state.stock = PackedInt64Array(
		[rules.start_food, rules.start_wood, rules.start_iron, rules.start_silver]
	)
	for id in entities.alive_ids:
		if entities.owners[id - 1] == p and unit_defs[id - 1] != null:
			state.pop_units += unit_defs[id - 1].pop
	players[p] = state


## Peasants build everything; the Crown's priest (builds_shrine) only shrines.
func _can_build(id: int, b: int) -> bool:
	var def := unit_defs[id - 1]
	if def != null and def.tags.has(&"builds_shrine"):
		return buildings.defs[b - 1].tags.has(&"power_place_only")
	return def != null and def.has_class(&"peasant")


func _can_gather(id: int) -> bool:
	var def := unit_defs[id - 1]
	return def != null and def.has_class(&"peasant") and not def.tags.has(&"no_gather")


func _order_build(cmd: SimCommand, units: PackedInt32Array) -> void:
	var def := db.building(cmd.type_id)
	if def == null:
		return
	var at := Vector2i(Fixed.to_cells(cmd.x), Fixed.to_cells(cmd.y))
	var vertical := cmd.value == 1
	if placement.can_place(cmd.player, def, at.x, at.y, vertical) != Fail.OK:
		return
	var p := players[cmd.player]
	var cost := placement.building_cost(cmd.player, def)
	if not p.can_pay(cost):
		return
	p.pay(cost)
	var b := _found(cmd.player, def, at.x, at.y, vertical)
	for id in units:
		_set_build_job(id, b)


## Palisade (any per-cell wall) from one cell to another, along a 4-connected line so it has
## no diagonal gaps. Cells where it cannot stand are skipped; it stops when money runs out.
func _order_wall(cmd: SimCommand, units: PackedInt32Array) -> void:
	var def := db.building(cmd.type_id)
	if def == null or not BuildingPlacement.is_wall(def):
		return
	var p: PlayerState = players.get(cmd.player)
	if p == null:
		return
	var cost := placement.building_cost(cmd.player, def)
	var first := BuildingStore.NO_ID
	for c in BuildingPlacement.wall_cells(
		Fixed.to_cells(cmd.x), Fixed.to_cells(cmd.y), Fixed.to_cells(cmd.x2), Fixed.to_cells(cmd.y2)
	):
		if placement.can_place(cmd.player, def, c.x, c.y, false) != Fail.OK:
			continue
		if not p.can_pay(cost):
			break
		p.pay(cost)
		var b := _found(cmd.player, def, c.x, c.y, false)
		if first == BuildingStore.NO_ID:
			first = b
	if first != BuildingStore.NO_ID:
		for id in units:
			_set_build_job(id, first)


func _set_build_job(id: int, b: int) -> void:
	if not buildings.is_alive(b) or not _can_build(id, b):
		return
	var slot := id - 1
	if buildings.owners[b - 1] != entities.owners[slot]:
		return
	end_job(slot)
	job[slot] = Job.BUILD
	job_ref[slot] = b
	if buildings.dismantling[b - 1] == 1:
		construction.stop_dismantling(b)


func _order_gather(cmd: SimCommand, units: PackedInt32Array) -> void:
	for id in units:
		if not _can_gather(id):
			continue
		var slot := id - 1
		var source := -1
		var ref := 0
		match cmd.value:
			Target.CELL:
				var cell := nav.cell_of(cmd.x, cmd.y)
				if nodes.wood[cell] > 0 and buildings.occupant[cell] == 0:
					source = ResourceNodes.Source.WOOD
					# The edge of that wood nearest to where the wood is carried, first.
					var fx := cell % nav.width
					var fy := cell / nav.width
					ref = _wood_by_drop(cmd.player, fx, fy, WOOD_PICK_CELLS)
					if ref < 0:
						ref = cell
			Target.NODE:
				if nodes.is_alive(cmd.target) and nodes.open_to(cmd.target, cmd.player):
					source = nodes.sources[cmd.target - 1]
					ref = cmd.target
			Target.BUILDING:
				source = building_source(cmd.player, cmd.target)
				ref = cmd.target
			Target.ANIMAL:
				var t := cmd.target
				if entities.is_alive(t) and entities.owners[t - 1] == 0:
					var adef := unit_defs[t - 1]
					if adef != null and adef.food_yield > 0:
						end_job(slot)
						job[slot] = Job.HUNT
						job_ref[slot] = t
				continue
		if source < 0:
			continue
		start_gather(slot, source, cmd.value, ref)


## The source a field or hive of this player gives, or -1.
func building_source(p: int, b: int) -> int:
	if not buildings.is_done(b) or buildings.owners[b - 1] != p:
		return -1
	var def := buildings.defs[b - 1]
	if def.base_id == &"farm":
		return ResourceNodes.Source.FARM
	if def.params.has(&"size_w") and def.tags.has(&"in_forest") and def.tags.has(&"walkable"):
		return ResourceNodes.Source.BORT
	return -1


func start_gather(slot: int, source: int, target: int, ref: int) -> bool:
	end_job(slot)
	if target == Target.BUILDING:
		var limit := (
			rules.farm_workers if source == ResourceNodes.Source.FARM else rules.bort_workers
		)
		if buildings.workers[ref - 1] >= limit:
			return false
		buildings.workers[ref - 1] += 1
		claimed[slot] = 1
	var res := ResourceNodes.SOURCE_RESOURCE[source]
	if carry_res[slot] != res:
		# A peasant who changes resource drops what he carried.
		carry[slot] = 0
		carry_res[slot] = res
	job[slot] = Job.GATHER
	job_source[slot] = source
	job_target[slot] = target
	job_ref[slot] = ref
	phase[slot] = Phase.RETURN if carry[slot] >= rules.carry else Phase.GO
	return true


func _order_assault(cmd: SimCommand, units: PackedInt32Array) -> void:
	var b := cmd.target
	if not buildings.is_alive(b) or sides.friendly(buildings.owners[b - 1], cmd.player):
		return
	combat.drop_targets(units)
	for id in units:
		var def := unit_defs[id - 1]
		if def == null or def.damage <= 0:
			continue
		end_job(id - 1)
		job[id - 1] = Job.ASSAULT
		job_ref[id - 1] = b
		assault_goal[id - 1] = b


# --- placement and prices ------------------------------------------------------------------


## Population the player may have: what its buildings give, never above rules.pop_cap.
func pop_cap(p: int) -> int:
	var state: PlayerState = players.get(p)
	return mini(state.pop_provided, rules.pop_cap) if state != null else 0


# --- foundations, construction, destruction ------------------------------------------------


## A new foundation: blocks its cells (unless it is walked over), moves units out of them.
func _found(p: int, def: BuildingDef, cx: int, cy: int, vertical: bool) -> int:
	var size := placement.footprint(def, vertical)
	var full_hp := def.hp
	var ticks := def.build_ticks
	var state := players[p]
	if BuildingPlacement.is_zaseka(def):
		full_hp = full_hp * (1000 + state.zaseka_hp_bonus) / 1000
		ticks = ticks * 1000 / (1000 + state.zaseka_speed_bonus)
	for y in range(cy, cy + size.y):
		for x in range(cx, cx + size.x):
			var old := buildings.occupant[nav.cell_at(x, y)]
			if old != 0 and placement.replaceable(p, def, old):
				remove_building(old)
	if def.tags.has(&"on_salt_spring"):
		SaltWorks.take_spring(self, cx, cy, size)
	var b := buildings.add(def, p, cx, cy, size.x, size.y, full_hp, maxi(ticks, 1) * 1000)
	# A gate closes its cell like a wall; once finished it opens to its owner (NavGrid).
	var blocking := not def.tags.has(&"walkable")
	buildings.blocks[b - 1] = 1 if blocking else 0
	for cell in buildings.cells_of(b, nav.width):
		buildings.occupant[cell] = b
		if blocking:
			nav.set_blocked(cell, true)
	if blocking:
		_push_out(b)
	return b


## Units standing on a new building's cells step to the nearest open cell.
func _push_out(b: int) -> void:
	var e := entities
	for id in e.alive_ids:
		var slot := id - 1
		var cell := nav.cell_of(e.pos_x[slot], e.pos_y[slot])
		if buildings.occupant[cell] != b:
			continue
		var open := nav.nearest_passable(e.move_class[slot], cell, STAND_RINGS + 2)
		if open != NavGrid.NO_CELL:
			e.pos_x[slot] = nav.center_x(open)
			e.pos_y[slot] = nav.center_y(open)
			if e.orders[slot] == EntityStore.Order.IDLE:
				_stop.call(id)


func complete(b: int) -> void:
	var s := b - 1
	var def := buildings.defs[s]
	buildings.done[s] = 1
	buildings.version += 1
	buildings.progress[s] = buildings.work[s]
	buildings.hp[s] = maxi(buildings.hp[s], 1)
	if buildings.progress[s] >= buildings.work[s] and buildings.hp[s] < buildings.max_hp[s]:
		# Placed finished (map setup): full HP.
		if buildings.repair_hp[s] == 0 and buildings.hp[s] == 1:
			buildings.hp[s] = buildings.max_hp[s]
	var state := players[buildings.owners[s]]
	state.pop_provided += def.pop_provided
	if def.base_id == &"farm":
		var capacity := def.param(&"food_capacity")
		buildings.food[s] = capacity * (1000 + state.farm_food_bonus) / 1000
	for cell in buildings.cells_of(b, nav.width):
		if def.base_id == GATE:
			buildings.gates[cell] = buildings.owners[s]
			nav.set_gate(buildings.owners[s], cell, true)
		if BuildingPlacement.is_zaseka(def):
			# The trees are down: the cells are a felled barrier now, not forest.
			nodes.wood[cell] = 0
			if _grass >= 0:
				nav.set_terrain(cell, _grass)


## The building is lost (burnt, stormed, a mission's script).
func destroy(b: int) -> void:
	if not buildings.is_alive(b):
		return
	var state: PlayerState = players.get(buildings.owners[b - 1])
	if state != null:
		state.buildings_lost += 1
	remove_building(b)


## The building leaves the map (destroyed or taken apart): its population, queue and cells.
func remove_building(b: int) -> void:
	if not buildings.is_alive(b):
		return
	var s := b - 1
	var def := buildings.defs[s]
	var state: PlayerState = players.get(buildings.owners[s])
	if state != null:
		if buildings.done[s] == 1:
			state.pop_provided -= def.pop_provided
		var q: Array = buildings.queues[s]
		for i in q.size():
			var item: StringName = q[i]
			state.researching.erase(item)
			if i == 0 and buildings.queue_started[s] == 1 and db.unit(item) != null:
				state.pop_training -= db.unit(item).pop
	for cell in buildings.cells_of(b, nav.width):
		buildings.occupant[cell] = 0
		if buildings.gates[cell] != 0:
			nav.set_gate(buildings.gates[cell], cell, false)
		buildings.gates[cell] = 0
		if buildings.blocks[s] == 1:
			nav.set_blocked(cell, false)
	buildings.remove(b)


# --- the economy step ----------------------------------------------------------------------


func step(at_tick: int) -> void:
	tick = at_tick
	if not enabled():
		return
	construction.begin_step()
	for id in entities.alive_ids:
		if job[id - 1] != Job.NONE:
			_work(id)
	construction.end_step()
	for b in buildings.alive_ids.duplicate():
		if buildings.is_alive(b):
			production.produce(b)
	SaltWorks.step(self)


func _work(id: int) -> void:
	var slot := id - 1
	if entities.hp[slot] <= 0 or combat.is_fleeing(id):
		return
	match job[slot]:
		Job.GATHER:
			_gather(id)
		Job.HUNT:
			_hunt(id)
		Job.BUILD:
			construction.build(id)
		Job.DISMANTLE:
			construction.dismantle(id)
		Job.ASSAULT:
			if entities.target[slot] == EntityStore.NO_ID:
				_assault(id)


## Walks toward (gx, gy) until the unit is within reach of its work; true once it is there.
## A unit that stops short MAX_WALK_TRIES times gives up its job.
func _approach(id: int, gx: int, gy: int, in_reach: bool) -> bool:
	var slot := id - 1
	if in_reach:
		if entities.orders[slot] == EntityStore.Order.MOVE:
			_stop.call(id)
		tries[slot] = 0
		return true
	if entities.orders[slot] == EntityStore.Order.MOVE:
		return false
	if tries[slot] >= MAX_WALK_TRIES:
		end_job(slot)
		return false
	tries[slot] += 1
	_walk.call(id, gx, gy)
	return false


func _reach() -> int:
	return Fixed.from_milli(rules.work_reach_milli)


## Where to stand to work on a rectangle of cells: on it if it can be walked on, else on the
## nearest open cell around it (nearest to the unit, ties by cell index).
func _stand_point(id: int, x0: int, y0: int, w: int, h: int, blocking: bool) -> Vector2i:
	var px := entities.pos_x[id - 1]
	var py := entities.pos_y[id - 1]
	if not blocking:
		var cx := clampi(Fixed.to_cells(px), x0, x0 + w - 1)
		var cy := clampi(Fixed.to_cells(py), y0, y0 + h - 1)
		var c := nav.cell_at(cx, cy)
		return Vector2i(nav.center_x(c), nav.center_y(c))
	var cls: int = entities.move_class[id - 1]
	for r in range(1, STAND_RINGS + 1):
		var best := NavGrid.NO_CELL
		var best_d := 0
		for y in range(y0 - r, y0 + h + r):
			for x in range(x0 - r, x0 + w + r):
				var ring := x == x0 - r or x == x0 + w + r - 1 or y == y0 - r or y == y0 + h + r - 1
				if not ring or not nav.in_bounds(x, y):
					continue
				var c := nav.cell_at(x, y)
				if not nav.passable(cls, c):
					continue
				var d := Fixed.distance(px, py, nav.center_x(c), nav.center_y(c))
				if best == NavGrid.NO_CELL or d < best_d:
					best = c
					best_d = d
		if best != NavGrid.NO_CELL:
			return Vector2i(nav.center_x(best), nav.center_y(best))
	return Vector2i(Fixed.from_cells(x0) + Fixed.HALF, Fixed.from_cells(y0) + Fixed.HALF)


func _rect_distance_sq(px: int, py: int, x0: int, y0: int, w: int, h: int) -> int:
	var ax := Fixed.from_cells(x0)
	var ay := Fixed.from_cells(y0)
	var dx := maxi(maxi(ax - px, 0), px - (ax + Fixed.from_cells(w)))
	var dy := maxi(maxi(ay - py, 0), py - (ay + Fixed.from_cells(h)))
	return dx * dx + dy * dy


## Walks to a building and reports whether the unit is at it.
func to_building(id: int, b: int, reach: int = -1) -> bool:
	var s := b - 1
	var r := _reach() if reach < 0 else reach
	var slot := id - 1
	var near := buildings.distance_sq(b, entities.pos_x[slot], entities.pos_y[slot]) <= r * r
	var goal := Vector2i.ZERO
	if not near and entities.orders[slot] != EntityStore.Order.MOVE:
		goal = _stand_point(
			id,
			buildings.cell_x[s],
			buildings.cell_y[s],
			buildings.w[s],
			buildings.h[s],
			buildings.blocks[s] == 1
		)
	return _approach(id, goal.x, goal.y, near)


# --- gathering -----------------------------------------------------------------------------


func _gather(id: int) -> void:
	var slot := id - 1
	if phase[slot] == Phase.RETURN:
		_carry_home(id)
		return
	if not _has_resource(slot) and not _retarget(slot):
		if carry[slot] > 0:
			phase[slot] = Phase.RETURN
		else:
			end_job(slot)
		return
	if not _to_resource(id):
		return
	phase[slot] = Phase.WORK
	var source := job_source[slot]
	var state := players.get(entities.owners[slot]) as PlayerState
	var bonus := 0
	if state != null and source < ResourceNodes.SOURCE_COUNT:
		bonus = state.gather_bonus[source]
	var rate := rules.gather_salvage_milli
	if not ResourceNodes.is_salvage(source):
		rate = _base_rate(source)
	gather_acc[slot] += rate * (1000 + bonus) / 1000
	while gather_acc[slot] >= UNIT_ACC and carry[slot] < rules.carry and _has_resource(slot):
		gather_acc[slot] -= UNIT_ACC
		carry[slot] += 1
		_take_one(slot)
	if carry[slot] >= rules.carry:
		gather_acc[slot] = 0
		phase[slot] = Phase.RETURN
	elif not _has_resource(slot) and not _retarget(slot):
		gather_acc[slot] = 0
		phase[slot] = Phase.RETURN


func _base_rate(source: int) -> int:
	match source:
		ResourceNodes.Source.FARM:
			return rules.gather_farm_milli
		ResourceNodes.Source.HUNT:
			return rules.gather_hunt_milli
		ResourceNodes.Source.BORT:
			return rules.gather_bort_milli
		ResourceNodes.Source.WOOD:
			return rules.gather_wood_milli
		ResourceNodes.Source.IRON:
			return rules.gather_iron_milli
	return rules.gather_silver_milli


func _has_resource(slot: int) -> bool:
	var ref := job_ref[slot]
	match job_target[slot]:
		Target.CELL:
			return nodes.wood[ref] > 0 and buildings.occupant[ref] == 0
		Target.NODE:
			return nodes.is_alive(ref) and nodes.amounts[ref - 1] > 0
		Target.BUILDING:
			if not buildings.is_done(ref):
				return false
			if job_source[slot] == ResourceNodes.Source.BORT:
				return true
			return buildings.food[ref - 1] > 0 or _reseed(ref)
	return false


func _take_one(slot: int) -> void:
	var ref := job_ref[slot]
	match job_target[slot]:
		Target.CELL:
			nodes.wood[ref] -= 1
			if nodes.wood[ref] == 0 and _grass >= 0:
				nav.set_terrain(ref, _grass)
		Target.NODE:
			nodes.amounts[ref - 1] -= 1
			if nodes.amounts[ref - 1] == 0:
				if nodes.blocks[ref - 1] == 1:
					nav.set_blocked(nodes.cells[ref - 1], false)
				nodes.remove(ref)
		Target.BUILDING:
			if job_source[slot] == ResourceNodes.Source.FARM:
				buildings.food[ref - 1] -= 1


## «Пересев»: an empty field is sown again for its price, if the owner can pay.
func _reseed(b: int) -> bool:
	var s := b - 1
	var state: PlayerState = players.get(buildings.owners[s])
	var def := buildings.defs[s]
	var cost := placement.building_cost(buildings.owners[s], def)
	if state == null or not state.can_pay(cost):
		return false
	state.pay(cost)
	buildings.food[s] = def.param(&"food_capacity") * (1000 + state.farm_food_bonus) / 1000
	return buildings.food[s] > 0


## When the resource runs out: the nearest of the same kind around it (forest cell, deposit,
## carcass), within rules.resource_search_cells. False if there is none.
func _retarget(slot: int) -> bool:
	var target := job_target[slot]
	if target == Target.BUILDING:
		return false
	var from_cell := job_ref[slot] if target == Target.CELL else nodes.cells[job_ref[slot] - 1]
	var r := rules.resource_search_cells
	var fx := from_cell % nav.width
	var fy := from_cell / nav.width
	var best := -1
	var best_d := 0
	if target == Target.CELL:
		best = _wood_by_drop(entities.owners[slot], fx, fy, r)
		if best >= 0:
			job_ref[slot] = best
			tries[slot] = 0
			return true
		for y in range(fy - r, fy + r + 1):
			for x in range(fx - r, fx + r + 1):
				if not nav.in_bounds(x, y):
					continue
				var c := nav.cell_at(x, y)
				if nodes.wood[c] <= 0 or buildings.occupant[c] != 0:
					continue
				var d := (x - fx) * (x - fx) + (y - fy) * (y - fy)
				if best < 0 or d < best_d:
					best = c
					best_d = d
	else:
		var source := job_source[slot]
		for n in nodes.alive_ids:
			if nodes.sources[n - 1] != source or nodes.amounts[n - 1] <= 0:
				continue
			if not nodes.open_to(n, entities.owners[slot]):
				continue
			var c := nodes.cells[n - 1]
			var dx := c % nav.width - fx
			var dy := c / nav.width - fy
			if maxi(absi(dx), absi(dy)) > r:
				continue
			var d := dx * dx + dy * dy
			if best < 0 or d < best_d:
				best = n
				best_d = d
	if best < 0:
		return false
	job_ref[slot] = best
	tries[slot] = 0
	return true


## The forest cell within `r` of (fx, fy) nearest to where player p carries wood (ResourceNodes
## .wood_toward), -1 when there is none or nowhere to carry it.
func _wood_by_drop(p: int, fx: int, fy: int, r: int) -> int:
	var at := nav.cell_at(fx, fy)
	var drop := drop_site(p, WOOD, nav.center_x(at), nav.center_y(at))
	if drop == BuildingStore.NO_ID:
		return -1
	return nodes.wood_toward(nav, buildings, drop, fx, fy, r)


func _to_resource(id: int) -> bool:
	var slot := id - 1
	var ref := job_ref[slot]
	var px := entities.pos_x[slot]
	var py := entities.pos_y[slot]
	var r := _reach()
	match job_target[slot]:
		Target.BUILDING:
			return to_building(id, ref)
		Target.CELL:
			var near := _rect_distance_sq(px, py, ref % nav.width, ref / nav.width, 1, 1) <= r * r
			return _approach(id, nav.center_x(ref), nav.center_y(ref), near)
	var cell := nodes.cells[ref - 1]
	var cx := cell % nav.width
	var cy := cell / nav.width
	var near_node := _rect_distance_sq(px, py, cx, cy, 1, 1) <= r * r
	var goal := Vector2i.ZERO
	if not near_node and entities.orders[slot] != EntityStore.Order.MOVE:
		goal = _stand_point(id, cx, cy, 1, 1, nodes.blocks[ref - 1] == 1)
	return _approach(id, goal.x, goal.y, near_node)


## Takes the load to the nearest own building that accepts it, then goes back to work.
func _carry_home(id: int) -> void:
	var slot := id - 1
	var res := carry_res[slot]
	var drop := drop_site(entities.owners[slot], res, entities.pos_x[slot], entities.pos_y[slot])
	if drop == BuildingStore.NO_ID:
		if entities.orders[slot] == EntityStore.Order.MOVE:
			_stop.call(id)
		return
	if not to_building(id, drop):
		return
	var state: PlayerState = players.get(entities.owners[slot])
	if state != null and res >= 0:
		state.stock[res] += carry[slot]
		state.gathered[res] += carry[slot]
	carry[slot] = 0
	phase[slot] = Phase.GO
	if not _has_resource(slot) and not _retarget(slot):
		end_job(slot)


## The nearest finished building of the player that takes this resource, ties by id.
func drop_site(p: int, res: int, px: int, py: int) -> int:
	if res < 0:
		return BuildingStore.NO_ID
	var best := BuildingStore.NO_ID
	var best_d := 0
	for b in _drop_sites.of(buildings, p, res):
		var d := buildings.distance_sq(b, px, py)
		if best == BuildingStore.NO_ID or d < best_d:
			best = b
			best_d = d
	return best


func _hunt(id: int) -> void:
	var slot := id - 1
	var animal := job_ref[slot]
	if entities.is_alive(animal) and entities.hp[animal - 1] > 0:
		if entities.target[slot] != animal:
			combat.order_attack(entities.owners[slot], PackedInt32Array([id]), animal)
		return
	var carcass := nodes.carcass_of(animal)
	if carcass == ResourceNodes.NO_ID:
		end_job(slot)
		return
	start_gather(slot, ResourceNodes.Source.HUNT, Target.NODE, carcass)


# --- attacking buildings -------------------------------------------------------------------


func _assault(id: int) -> void:
	var slot := id - 1
	var b := job_ref[slot]
	if not buildings.is_alive(b) and buildings.is_alive(assault_goal[slot]):
		# The way is broken open: on at the building it was sent at.
		b = assault_goal[slot]
		job_ref[slot] = b
	if not buildings.is_alive(b):
		end_job(slot)
		return
	var def := unit_defs[slot]
	var reach := _reach()
	if def.attack_range > 0:
		reach = Fixed.from_cells(def.attack_range + entities.up_range[slot])
	if combat.crown.anchored(slot):
		# The bombard keeps to its battery: it fires at what is in range or gives up.
		var far := buildings.distance_sq(b, entities.pos_x[slot], entities.pos_y[slot])
		if far > reach * reach:
			end_job(slot)
			return
		if entities.cooldown[slot] > 0 or not combat.crown.may_fire(slot):
			return
		combat.crown.fired(slot)
	else:
		if tries[slot] > 0 and entities.orders[slot] != EntityStore.Order.MOVE:
			b = Breach.break_in(self, id, b, reach)
		if not to_building(id, b, reach):
			return
		if entities.cooldown[slot] > 0:
			return
	entities.cooldown[slot] = maxi(def.reload_ticks, 1)
	entities.last_attack[slot] = tick
	hit_building(b, building_damage(slot, b))


## One strike of a unit on a building (Damage.against_building).
func building_damage(slot: int, b: int) -> int:
	var bonus := entities.up_damage[slot]
	return Damage.against_building(unit_defs[slot], bonus, buildings.defs[b - 1], combat.rules)


func hit_building(b: int, damage: int) -> void:
	buildings.hp[b - 1] = maxi(buildings.hp[b - 1] - damage, buildings.hp_floor.get(b, 0))
	if buildings.hp[b - 1] <= 0:
		destroy(b)


# --- state ---------------------------------------------------------------------------------


func write_to(buf: StreamPeerBuffer) -> void:
	var ids := players.keys()
	ids.sort()
	buf.put_32(ids.size())
	for p: int in ids:
		players[p].write_to(buf)
	buildings.write_to(buf)
	nodes.write_to(buf)
	for id in entities.alive_ids:
		var s := id - 1
		if job[s] == Job.NONE and carry[s] == 0:
			continue
		buf.put_32(id)
		buf.put_8(job[s])
		buf.put_8(phase[s])
		buf.put_8(job_source[s])
		buf.put_8(job_target[s])
		buf.put_32(job_ref[s])
		buf.put_32(assault_goal[s])
		buf.put_8(claimed[s])
		buf.put_32(carry_res[s])
		buf.put_32(carry[s])
		buf.put_32(gather_acc[s])
		buf.put_32(tries[s])
