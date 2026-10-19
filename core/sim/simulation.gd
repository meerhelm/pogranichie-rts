class_name Simulation
extends RefCounted
## The deterministic game world. It changes only in step(), only through commands, and uses
## only integers, its own SimRng and ascending-id iteration, so the same seed, data and
## commands give the same state on every machine. Rendering reads it and never writes it.

## Bump when a change to the rules makes old replays play out differently.
## 2: M3 movement (terrain, A*, flow fields, formations, separation).
## 3: M4 combat and morale (targets, strikes, projectiles, flight, stances, facing, run-up).
## 4: M5 economy (players, gathering, buildings, queues, techs; map deposits block cells).
## 5: M6 fog of war (units pick fights only with enemies their side can see).
## 6: M7 places of power, Сила, spells and healers; attacks are remembered (last_attack).
## 7: M8 match statistics (trained, lost, killed, built, gathered) and skirmish victory.
## 8: M9 fire (arson, burning, spreading, dousing), heroes' own auras, mission locks and the
## mission script (MissionRuntime) in the world.
## 10: taking own buildings apart (DISMANTLE, salvage piles carried to storage).
## 11: towers and gates shoot.
## 12: ВКЛ 3: the CHOOSE command, spies nobody strikes unordered, quenched places of power.
## 13: ВКЛ 4: a column on the march, captives, a spared hero (HP floor), camp supply, raids.
## 14: walkers meeting head-on sidestep to their right (Separation.SIDESTEP).
## 15: the mission state hash includes MissionRetreat (ВКЛ 5: bridge, ford, rescue, waves);
##   the Сила rules add icon_morale_floor.
## 16: ВКЛ 6: the watch and its detection meter, hidden places of power (in the hash), the trails
##   of «Волчья тропа», horses that tire and are led on foot (MissionStealth).
## 17: ВКЛ 7: the siege (MissionSiege in the mission hash): ladders, belts of walls, shooters on
##   the walls, quicker dousing, food in a siege, the secret passage.
## 18: ВКЛ 8: bridges laid by servants, the patrol, an ambush held deaf to orders and hidden in
##   cover, the feint to the rally point, the chase (MissionBattle in the mission hash).
## 19: the builder of a field or hive works it at once; wood is cut from the forest cell nearest
##   to where it is carried.
## 20: the Crown as a skirmish faction: tabor rings, pavises, the tiring lance, the foot
##   servant, the bombard's battery, the shrine's chapel, salt works on salt springs, and the
##   spells «Богородица», «Благословение хоругви» and «Договор».
## 21: Корона 2: a siege that cannot be won by storm (MissionBesiege in the mission hash): a
##   building may have an HP floor, a spiked bombard does not fire, a camp may be kept from
##   healing, campaign-only buildings a mission allows.
const SIM_VERSION := 21
## Map size when none is given; the skirmish map default from the implementation plan.
const DEFAULT_MAP_CELLS := 120
## Stats for unit types the catalog does not know (tests without data).
const FALLBACK_HP := 100
const FALLBACK_SPEED_MILLI := 1000
## Groups this big share one flow field instead of searching a path per unit...
const FLOW_GROUP_MIN := 8
## ...when they stand together: a group spread wider than this (in cells) plans per unit.
const FLOW_MAX_SPREAD := 16
## A flow-field unit this close to its slot (in cells) walks the last bit on its own path.
const SLOT_APPROACH_CELLS := 4
## Units closer than this push each other apart (fixed units); see Separation.
const SEPARATION := Separation.SEPARATION
## Ticks without getting closer to the target before re-planning; after MAX_REPLANS, give up.
const STALL_TICKS := 60
const MAX_REPLANS := 3
## Waypoint marker for "walk straight to the exact target point".
const FINAL := -2
## Waypoint marker for "the path is not searched yet, stand still this tick".
const WAIT := -3
## path_version of a unit whose path search is queued.
const PATH_PENDING := -1
## Cells the pathfinder and flow fields may expand per tick; a longer search goes on next tick
## where it stopped, so a big order or a path across the map cannot stall a tick (M10).
const PATH_BUDGET := 800
## How far ahead a unit looks for a straight line along its path, in path cells.
const SMOOTH_LOOKAHEAD := 8
## Up to this many cells away a unit checks for a straight line to the exact target.
const DIRECT_CELLS := 24
## Step when checking a straight line cell by cell (a quarter cell).
const LINE_SAMPLE := Fixed.ONE / 4

## Number of ticks already simulated; commands for this tick run at the next step().
var tick := 0
var seed_value: int
var rng: SimRng
var entities := EntityStore.new()
var queue := CommandQueue.new()
var map_width: int
var map_height: int
## Terrain and blockers for movement.
var nav: NavGrid
var pathfinder: Pathfinder
## Fights and morale; does nothing without the catalog's combat rules (tests without data).
var combat: CombatSystem
## Players, resources, buildings, training and research; idle without the catalog's rules.
var economy: EconomySystem
## Fog of war: what each player sees; off without the catalog's vision rules.
var vision: VisionSystem
## Places of power, Сила and spells; off without the catalog's magic rules.
var magic: MagicSystem
## Who has won the skirmish (M8); off without the catalog's skirmish rules.
var victory: SkirmishVictory
## Arson and burning buildings (M9); off without the catalog's fire rules.
var fire: FireSystem
## Towers shooting at enemies in range.
var towers: TowerFire
## The mission's script (M9): triggers, objectives and its own units' orders; null in a skirmish.
var mission: MissionRuntime
## Which players are allies (ВКЛ 2); empty in a skirmish.
var sides := Sides.new()
var data_version: String
## Every accepted command, in arrival order, for recording replays.
var command_log: Array[SimCommand] = []

var _db: CatalogDB
## Flow fields of group orders by id, and how many units still follow each.
var _flows: Dictionary[int, FlowField] = {}
var _flow_users: Dictionary[int, int] = {}
var _next_flow_id := 1
## Units waiting for a path search, in request order.
var _path_queue := PackedInt32Array()
## Flow fields still being built, oldest first.
var _flow_queue := PackedInt32Array()
## The unit whose path search is open in the pathfinder (0: none), the goal cell and map
## version it was started for.
var _searching := 0
var _search_goal := 0
var _search_version := 0
## Keeps units apart (and lets walkers meeting head-on sidestep); scratch only, no state.
var _separation := Separation.new()


## Without `map`, the world is open grass of the given size; with it, the map's size is used.
func _init(
	p_seed: int = 1,
	db: CatalogDB = null,
	width_cells: int = DEFAULT_MAP_CELLS,
	height_cells: int = DEFAULT_MAP_CELLS,
	map: NavGrid = null
) -> void:
	seed_value = p_seed
	rng = SimRng.new(p_seed)
	_db = db
	data_version = db.content_hash() if db != null else "none"
	nav = map if map != null else NavGrid.for_catalog(width_cells, height_cells, db)
	pathfinder = Pathfinder.new(nav)
	# Label the connected areas now, while the world loads, not in the first tick a unit walks.
	nav.area(0, 0)
	map_width = Fixed.from_cells(nav.width)
	map_height = Fixed.from_cells(nav.height)
	combat = CombatSystem.new(
		entities, nav, rng, db.rules if db != null else null, walk_unit, stop_unit, remove_unit
	)
	economy = EconomySystem.new(entities, nav, db, combat, walk_unit, stop_unit, spawn_unit)
	vision = VisionSystem.new(entities, nav, db, economy)
	combat.vision = vision
	combat.sides = sides
	vision.sides = sides
	magic = MagicSystem.new(entities, nav, db, economy, combat, walk_unit, stop_unit, remove_unit)
	combat.morale_floor = magic.morale_floor
	combat.silenced = magic.silenced
	combat.boost = magic.boost
	combat.crown.buildings = economy.buildings
	combat.crown.players = economy.players
	combat.on_kill = _count_kill
	vision.mist = magic.mist
	victory = SkirmishVictory.new(db.skirmish if db != null else null, economy, magic.places)
	fire = FireSystem.new(economy, rng, db.fire if db != null else null, stop_unit)
	towers = TowerFire.new(economy.buildings, entities, combat)
	towers.vision = vision
	fire.sides = sides
	economy.sides = sides


## Queues a command for its tick. Commands for a tick already simulated are refused,
## because applying them late would change the past differently on each machine.
func enqueue(cmd: SimCommand) -> bool:
	if cmd.tick < tick:
		push_warning("command for past tick %d refused at tick %d" % [cmd.tick, tick])
		return false
	queue.push(cmd)
	command_log.append(cmd)
	return true


func step() -> void:
	for cmd in queue.take_due(tick):
		_apply(cmd)
	if mission != null:
		mission.step(tick)
	combat.step(tick)
	towers.step()
	economy.step(tick)
	fire.step(tick)
	magic.step(tick)
	_move_units()
	combat.after_move()
	vision.step()
	victory.step(tick)
	tick += 1


## step() with each system timed: adds microseconds per system name into times (bench --profile).
func step_profiled(times: Dictionary) -> void:
	var t := Time.get_ticks_usec()
	for cmd in queue.take_due(tick):
		_apply(cmd)
	t = _lap(times, "commands", t)
	if mission != null:
		mission.step(tick)
	t = _lap(times, "mission", t)
	combat.step(tick)
	towers.step()
	t = _lap(times, "combat", t)
	economy.step(tick)
	t = _lap(times, "economy", t)
	fire.step(tick)
	magic.step(tick)
	t = _lap(times, "fire+magic", t)
	_serve_paths()
	t = _lap(times, "move.paths", t)
	_walk_units()
	t = _lap(times, "move.walk", t)
	_separation.run(entities, nav)
	t = _lap(times, "move.separate", t)
	combat.after_move()
	t = _lap(times, "combat_after_move", t)
	vision.step()
	t = _lap(times, "vision", t)
	victory.step(tick)
	_lap(times, "victory", t)
	tick += 1


static func _lap(times: Dictionary, key: String, since: int) -> int:
	var now := Time.get_ticks_usec()
	times[key] = int(times.get(key, 0)) + now - since
	return now


func run(ticks: int) -> void:
	for i in ticks:
		step()


## SHA-256 of the whole simulation state, as hex. Equal hashes mean equal worlds.
func state_hash() -> String:
	var buf := StreamPeerBuffer.new()
	buf.big_endian = false
	buf.put_32(SIM_VERSION)
	buf.put_64(tick)
	buf.put_64(rng.state)
	buf.put_64(map_width)
	buf.put_64(map_height)
	buf.put_data(nav.content_hash())
	buf.put_32(_next_flow_id)
	buf.put_32(_path_queue.size())
	for id in _path_queue:
		buf.put_32(id)
	buf.put_32(_searching)
	buf.put_32(_flow_queue.size())
	for flow_id in _flow_queue:
		buf.put_32(flow_id)
	entities.write_to(buf)
	combat.write_to(buf)
	economy.write_to(buf)
	vision.write_to(buf)
	magic.write_to(buf)
	victory.write_to(buf)
	fire.write_to(buf)
	sides.write_to(buf)
	if mission != null:
		mission.write_to(buf)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(buf.data_array)
	return ctx.finish().hex_encode()


## The catalog the world was made with (null in tests without data).
func catalog() -> CatalogDB:
	return _db


func clamp_x(x: int) -> int:
	return clampi(x, 0, map_width - 1)


func clamp_y(y: int) -> int:
	return clampi(y, 0, map_height - 1)


## Applies a command at once, without logging it: the mission script orders its units this way
## during its step (the same commands a player gives; replays keep only the players').
func apply_now(cmd: SimCommand) -> void:
	_apply(cmd)


func _apply(cmd: SimCommand) -> void:
	match cmd.kind:
		SimCommand.Kind.SPAWN:
			_spawn(cmd)
		SimCommand.Kind.MOVE, SimCommand.Kind.ATTACK_MOVE:
			var ids := _obedient(cmd)
			economy.drop_jobs(ids)
			magic.drop_casts(ids)
			fire.drop(ids)
			_order_move(ids, clamp_x(cmd.x), clamp_y(cmd.y), cmd.formation)
			for id in ids:
				combat.on_move_order(id, cmd.kind == SimCommand.Kind.ATTACK_MOVE)
		SimCommand.Kind.STOP:
			var ids := _obedient(cmd)
			economy.drop_jobs(ids)
			magic.drop_casts(ids)
			fire.drop(ids)
			for id in ids:
				_stop(id)
				combat.on_stop_order(id)
		SimCommand.Kind.REMOVE:
			for id in _owned(cmd):
				remove_unit(id)
		SimCommand.Kind.RALLY:
			combat.order(cmd, PackedInt32Array())
		SimCommand.Kind.JOIN, SimCommand.Kind.PLACE, SimCommand.Kind.QUEUE:
			economy.order(cmd, PackedInt32Array())
		SimCommand.Kind.CANCEL, SimCommand.Kind.BUILDING_RALLY:
			economy.order(cmd, PackedInt32Array())
		SimCommand.Kind.BUILD, SimCommand.Kind.WALL, SimCommand.Kind.GATHER:
			_economy_order(cmd)
		SimCommand.Kind.WORK, SimCommand.Kind.ASSAULT, SimCommand.Kind.DISMANTLE:
			_economy_order(cmd)
		SimCommand.Kind.CAST:
			var ids := _obedient(cmd)
			economy.drop_jobs(ids)
			combat.drop_targets(ids)
			fire.drop(ids)
			magic.order(cmd, ids)
		SimCommand.Kind.CHOOSE:
			if mission != null:
				mission.choose(cmd.player, String(cmd.type_id), cmd.value, tick)
		SimCommand.Kind.DISMOUNT:
			# ВКЛ 6: fugitives lead their horses on foot or ride again instead.
			var ids := _obedient(cmd)
			if mission != null:
				ids = mission.stealth.pace(mission, ids)
			combat.order(cmd, ids)
		SimCommand.Kind.IGNITE:
			var ids := _obedient(cmd)
			economy.drop_jobs(ids)
			combat.drop_targets(ids)
			magic.drop_casts(ids)
			for id in ids:
				_stop(id)
			fire.order(cmd, ids)
		_:
			var ids := _obedient(cmd)
			if cmd.kind in [SimCommand.Kind.ATTACK, SimCommand.Kind.RETREAT, SimCommand.Kind.TABOR]:
				economy.drop_jobs(ids)
				magic.drop_casts(ids)
				fire.drop(ids)
			combat.order(cmd, ids)
			if cmd.kind == SimCommand.Kind.RETREAT and mission != null:
				mission.battle.feint(self, cmd.player, ids)


## Work orders: the units stop what they were doing (walk, fight) and the economy takes over.
func _economy_order(cmd: SimCommand) -> void:
	var ids := _obedient(cmd)
	combat.drop_targets(ids)
	magic.drop_casts(ids)
	fire.drop(ids)
	for id in ids:
		_stop(id)
	economy.order(cmd, ids)


func _spawn(cmd: SimCommand) -> void:
	spawn_unit(cmd.type_id, cmd.player, cmd.x, cmd.y)


## Creates a unit at the point (or the nearest open cell); its id, or 0 if it cannot be made.
func spawn_unit(type_id: StringName, player: int, px: int, py: int) -> int:
	var hit_points := FALLBACK_HP
	var speed_milli := FALLBACK_SPEED_MILLI
	var move_class := NavGrid.MoveClass.FOOT
	var def: UnitDef = null
	if _db != null:
		def = _db.unit(type_id)
		if def == null:
			push_warning("spawn of unknown unit %s ignored" % type_id)
			return EntityStore.NO_ID
		hit_points = def.hp
		speed_milli = def.speed_milli
		move_class = NavGrid.move_class_for(def)
	var x := clamp_x(px)
	var y := clamp_y(py)
	var cell := nav.cell_of(x, y)
	if not nav.passable(move_class, cell):
		# Never place a unit in water or a thicket: move it to the nearest open cell.
		var open := nav.nearest_passable(move_class, cell, maxi(nav.width, nav.height))
		if open == NavGrid.NO_CELL:
			push_warning("no open cell to spawn %s" % type_id)
			return EntityStore.NO_ID
		x = nav.center_x(open)
		y = nav.center_y(open)
	var id := entities.spawn(
		type_id, player, x, y, hit_points, Fixed.speed_per_tick(speed_milli), move_class
	)
	combat.on_spawn(id, def)
	economy.on_spawn(id, def)
	vision.on_spawn(id, def)
	magic.on_spawn(id, def)
	return id


## Ids from the command that are alive and belong to its player, ascending, without repeats.
func _owned(cmd: SimCommand) -> PackedInt32Array:
	var result := PackedInt32Array()
	for id in cmd.ids:
		if entities.is_alive(id) and entities.owners[id - 1] == cmd.player:
			result.append(id)
	result.sort()
	var unique := PackedInt32Array()
	for id in result:
		if unique.is_empty() or unique[-1] != id:
			unique.append(id)
	return unique


## Like _owned(), without units that flee and ignore orders.
func _obedient(cmd: SimCommand) -> PackedInt32Array:
	var result := PackedInt32Array()
	var held: Dictionary[int, bool] = {}
	if mission != null:
		held = mission.battle.held
	for id in _owned(cmd):
		# ВКЛ 8: the ambush waits for the signal, deaf to its player's orders.
		if not combat.is_fleeing(id) and not held.has(id):
			result.append(id)
	return result


## Ends the unit's current walk where it stands (combat uses this to stop and fight).
func stop_unit(id: int) -> void:
	_stop(id)


## Sends one unit to the point on its own path, at its own speed (chases, flight, retreats).
func walk_unit(id: int, x: int, y: int) -> void:
	_release_flow(id)
	entities.set_move_target(id, clamp_x(x), clamp_y(y))
	_plan_path(id)


func remove_unit(id: int) -> void:
	var state: PlayerState = economy.players.get(entities.owners[id - 1])
	if state != null:
		state.lost += 1
	economy.on_remove(id)
	vision.on_remove(id)
	fire.on_remove(id)
	_release_flow(id)
	entities.remove(id)


## A hit of `killer`'s finished a unit of `victim`'s: the killer's statistics count it.
func _count_kill(killer: int, victim: int) -> void:
	var state: PlayerState = economy.players.get(killer)
	if state != null and victim > 0 and victim != killer:
		state.killed += 1


# --- movement ---------------------------------------------------------------------------


## One unit walks to the point; a group takes formation slots around it, facing the way it
## moves, at the speed of its slowest unit. Big groups share a flow field per movement class.
func _order_move(ids: PackedInt32Array, x: int, y: int, formation: int) -> void:
	if ids.is_empty():
		return
	var e := entities
	for id in ids:
		_release_flow(id)
	if ids.size() == 1:
		e.set_move_target(ids[0], x, y)
		_plan_path(ids[0])
		return
	var n := ids.size()
	var xs := PackedInt64Array()
	var ys := PackedInt64Array()
	var sum_x := 0
	var sum_y := 0
	var slowest := 1 << 30
	for id in ids:
		xs.append(e.pos_x[id - 1])
		ys.append(e.pos_y[id - 1])
		sum_x += e.pos_x[id - 1]
		sum_y += e.pos_y[id - 1]
		slowest = mini(slowest, e.speed[id - 1])
	var fx := x - Fixed.floor_div(sum_x, n)
	var fy := y - Fixed.floor_div(sum_y, n)
	var kind := formation as Formation.Kind
	var slots := Formation.slot_positions(kind, n, x, y, fx, fy)
	var taken_slot := Formation.assign(kind, ids, xs, ys, fx, fy)
	var flows_by_class := {}
	if n >= FLOW_GROUP_MIN and _spread_cells(xs, ys) <= FLOW_MAX_SPREAD:
		flows_by_class = _group_flows(ids, x, y)
	_fit_on_map(slots)
	var taken := {}
	for i in n:
		var id := ids[i]
		var slot := id - 1
		var spot := slots[taken_slot[i]]
		var cls: int = e.move_class[slot]
		var cell := nav.cell_of(spot.x, spot.y)
		if not nav.passable(cls, cell) or taken.has(cell):
			# A slot in water, a thicket or on another unit's spot: the nearest free open cell.
			var open := nav.nearest_passable(cls, cell, Pathfinder.GOAL_SNAP_RADIUS, taken)
			if open != NavGrid.NO_CELL:
				cell = open
				spot = Vector2i(nav.center_x(open), nav.center_y(open))
		taken[cell] = true
		e.set_move_target(id, spot.x, spot.y)
		e.move_speed[slot] = slowest
		if flows_by_class.has(cls):
			var flow_id: int = flows_by_class[cls]
			e.flow_ids[slot] = flow_id
			_flow_users[flow_id] += 1
		else:
			_plan_path(id)


## Shifts formation slots so they all lie on the map (a formation ordered to the map's edge
## keeps its shape instead of piling up on the border). Clamps what still does not fit.
func _fit_on_map(slots: Array[Vector2i]) -> void:
	var lo := Vector2i(map_width, map_height)
	var hi := Vector2i(-1, -1)
	for s in slots:
		lo = Vector2i(mini(lo.x, s.x), mini(lo.y, s.y))
		hi = Vector2i(maxi(hi.x, s.x), maxi(hi.y, s.y))
	var shift := Vector2i(_overflow(lo.x, hi.x, map_width), _overflow(lo.y, hi.y, map_height))
	for i in slots.size():
		var s := slots[i] + shift
		slots[i] = Vector2i(clamp_x(s.x), clamp_y(s.y))


## How far to move the span [lo, hi] to keep it half a cell inside [0, size).
static func _overflow(lo: int, hi: int, size: int) -> int:
	if lo < Fixed.HALF:
		return Fixed.HALF - lo
	if hi > size - Fixed.HALF:
		return maxi(size - Fixed.HALF - hi, Fixed.HALF - lo)
	return 0


## Side of the box around the units, in cells.
static func _spread_cells(xs: PackedInt64Array, ys: PackedInt64Array) -> int:
	var x0 := xs[0]
	var x1 := xs[0]
	var y0 := ys[0]
	var y1 := ys[0]
	for i in xs.size():
		x0 = mini(x0, xs[i])
		x1 = maxi(x1, xs[i])
		y0 = mini(y0, ys[i])
		y1 = maxi(y1, ys[i])
	return Fixed.to_cells(maxi(x1 - x0, y1 - y0))


## One flow field per movement class in the group, toward the order point. class -> flow id.
func _group_flows(ids: PackedInt32Array, x: int, y: int) -> Dictionary:
	var starts := {}
	for id in ids:
		var cls: int = entities.move_class[id - 1]
		if not starts.has(cls):
			starts[cls] = PackedInt32Array()
		var cells: PackedInt32Array = starts[cls]
		cells.append(nav.cell_of(entities.pos_x[id - 1], entities.pos_y[id - 1]))
		starts[cls] = cells
	var result := {}
	for cls in NavGrid.MOVE_CLASS_COUNT:
		if not starts.has(cls):
			continue
		var goal := nav.nearest_passable(cls, nav.cell_of(x, y), Pathfinder.GOAL_SNAP_RADIUS)
		if goal == NavGrid.NO_CELL:
			continue
		var flow_id := _next_flow_id
		_next_flow_id += 1
		var owner := entities.owners[ids[0] - 1]
		_flows[flow_id] = FlowField.new(nav, cls, goal, starts[cls], owner)
		_flow_users[flow_id] = 0
		_flow_queue.append(flow_id)
		result[cls] = flow_id
	return result


func _release_flow(id: int) -> void:
	var slot := id - 1
	var flow_id := entities.flow_ids[slot]
	if flow_id == 0:
		return
	entities.flow_ids[slot] = 0
	_flow_users[flow_id] -= 1
	if _flow_users[flow_id] <= 0:
		_flows.erase(flow_id)
		_flow_users.erase(flow_id)


func _stop(id: int) -> void:
	_release_flow(id)
	entities.stop(id)


## Asks for a new path. Searches run at the start of the movement step, in request order, up to
## PATH_BUDGET expanded cells a tick; a unit waiting for its path stands still meanwhile.
func _plan_path(id: int) -> void:
	var slot := id - 1
	if entities.path_version[slot] == PATH_PENDING:
		return
	entities.set_path(id, PackedInt32Array(), PATH_PENDING)
	_path_queue.append(id)


func _serve_paths() -> void:
	var spent := 0
	# Flow fields first, in the order the groups were sent; their units wait meanwhile.
	while not _flow_queue.is_empty() and spent < PATH_BUDGET:
		var flow: FlowField = _flows.get(_flow_queue[0])
		if flow != null:
			spent += flow.build(PATH_BUDGET - spent)
			if not flow.done:
				return
		_flow_queue = _flow_queue.slice(1)
	var e := entities
	var served := 0
	while served < _path_queue.size() and spent < PATH_BUDGET:
		var id := _path_queue[served]
		var slot := id - 1
		if not e.is_alive(id) or e.path_version[slot] != PATH_PENDING:
			served += 1
			_searching = 0
			continue
		var to := nav.cell_of(e.target_x[slot], e.target_y[slot])
		if _searching != id or to != _search_goal or nav.closing_version != _search_version:
			# A new search, or the open one is out of date (new target, the map changed).
			_searching = id
			_search_goal = to
			_search_version = nav.closing_version
			var from := nav.cell_of(e.pos_x[slot], e.pos_y[slot])
			pathfinder.begin(e.move_class[slot], from, to, e.owners[slot])
		spent += pathfinder.resume(PATH_BUDGET - spent)
		if not pathfinder.done:
			break
		e.set_path(id, pathfinder.result(), _search_version)
		_smooth(id)
		_searching = 0
		served += 1
	_path_queue = _path_queue.slice(served)


func _move_units() -> void:
	_serve_paths()
	_walk_units()
	_separation.run(entities, nav)


func _walk_units() -> void:
	var e := entities
	for id in e.alive_ids:
		if e.orders[id - 1] == EntityStore.Order.MOVE:
			_advance(id)
			_watch_progress(id)


## Moves one unit by its speed for this tick (faster in a «Литовский отход») and notes where it
## now faces and how far it has run without stopping (for the charge).
func _advance(id: int) -> void:
	var e := entities
	var slot := id - 1
	var x0 := e.pos_x[slot]
	var y0 := e.pos_y[slot]
	var budget := e.move_speed[slot]
	if e.intents[slot] == EntityStore.Intent.RETREAT and _db != null:
		budget = budget * _db.rules.retreat_speed_permille / 1000
	if mission != null and not mission.stealth.stamina.is_empty():
		budget = mission.stealth.speed(id, budget, mission)
	_walk(id, budget)
	var dx := e.pos_x[slot] - x0
	var dy := e.pos_y[slot] - y0
	if dx != 0 or dy != 0:
		var d := Fixed.isqrt(dx * dx + dy * dy)
		if d > 0:
			e.facing_x[slot] = dx * Fixed.ONE / d
			e.facing_y[slot] = dy * Fixed.ONE / d
		e.run[slot] += d
		e.moved[slot] = 1


## Walks the unit `budget` fixed units along its route, through as many waypoints as the
## distance allows. Speed is scaled by the terrain under the unit.
func _walk(id: int, p_budget: int) -> void:
	var e := entities
	var slot := id - 1
	var budget := p_budget
	for leg in 4:
		if budget <= 0 or e.orders[slot] != EntityStore.Order.MOVE:
			return
		var cell := nav.cell_of(e.pos_x[slot], e.pos_y[slot])
		var way := _waypoint(id, cell)
		if way == WAIT:
			return
		if way == NavGrid.NO_CELL:
			_stop(id)
			return
		var wx: int
		var wy: int
		if way == FINAL:
			wx = e.target_x[slot]
			wy = e.target_y[slot]
		else:
			wx = nav.center_x(way)
			wy = nav.center_y(way)
		var permille := _speed_permille(slot, cell)
		var reach := budget * permille / 1000
		var dx := wx - e.pos_x[slot]
		var dy := wy - e.pos_y[slot]
		var dist := Fixed.isqrt(dx * dx + dy * dy)
		if _gate_closed(slot, wx, wy, dist, reach):
			_stop(id)
			return
		if dist <= reach:
			e.pos_x[slot] = wx
			e.pos_y[slot] = wy
			budget -= dist * 1000 / permille
			_entered(slot)
			if way == FINAL:
				_stop(id)
				return
			_waypoint_reached(id, way)
		else:
			# '/' truncates toward zero, symmetric for both directions and the same everywhere.
			e.pos_x[slot] += dx * reach / dist
			e.pos_y[slot] += dy * reach / dist
			_entered(slot)
			return


## A finished gate lets only its owner through: anyone else stops in front of it.
func _gate_closed(slot: int, wx: int, wy: int, dist: int, reach: int) -> bool:
	var e := entities
	var nx := wx
	var ny := wy
	if dist > reach:
		nx = e.pos_x[slot] + (wx - e.pos_x[slot]) * reach / dist
		ny = e.pos_y[slot] + (wy - e.pos_y[slot]) * reach / dist
	var cell := nav.cell_of(nx, ny)
	var gate_owner := economy.buildings.gates[cell]
	if gate_owner == 0 or gate_owner == e.owners[slot]:
		return false
	return cell != nav.cell_of(e.pos_x[slot], e.pos_y[slot])


## Speed per-mille in the unit's cell, with the climb penalty if it came up a hill.
func _speed_permille(slot: int, cell: int) -> int:
	var cls: int = entities.move_class[slot]
	var permille := nav.cell_permille(cls, cell)
	if permille == 0:
		# Pushed or spawned into a closed cell: walk out at normal speed.
		return 1000
	if entities.climbing[slot] == 1:
		permille = nav.edge_permille(cls, NavGrid.NO_CELL, cell)
	return maxi(permille, 1)


## Notes the cell change after a move, to know whether the unit climbed into its new cell.
func _entered(slot: int) -> void:
	var e := entities
	var cell := nav.cell_of(e.pos_x[slot], e.pos_y[slot])
	var prev := e.last_cell[slot]
	if cell == prev:
		return
	e.climbing[slot] = 1 if prev >= 0 and nav.is_climb(prev, cell) else 0
	e.last_cell[slot] = cell


## The next cell to walk to, FINAL for the exact target, WAIT while the path is searched, or
## NO_CELL when there is nowhere to go.
func _waypoint(id: int, cell: int) -> int:
	var e := entities
	var slot := id - 1
	var goal := nav.cell_of(e.target_x[slot], e.target_y[slot])
	if e.flow_ids[slot] != 0:
		if not _flows[e.flow_ids[slot]].done:
			return WAIT
		var along := _flow_step(id, cell, goal)
		if along != NavGrid.NO_CELL:
			return along
	if e.path_version[slot] != nav.closing_version and e.path_version[slot] != PATH_PENDING:
		_plan_path(id)
	var path := e.paths[slot]
	var i := e.path_index[slot]
	var way := NavGrid.NO_CELL
	if e.path_version[slot] == PATH_PENDING:
		way = WAIT
	elif e.direct[slot] == 1:
		way = FINAL
	elif i < path.size():
		way = path[i]
	elif cell == goal:
		way = FINAL
	elif not path.is_empty() and path[-1] == goal:
		# Pushed out of the goal cell after the path ended: walk back.
		_plan_path(id)
		way = WAIT
	# Otherwise the path ended short of the target: it cannot be reached, stop there.
	return way


## The next cell on the unit's flow field; NO_CELL once the unit leaves the field (near its
## slot, at the goal, off the searched area, or the map changed) and walks its own path.
func _flow_step(id: int, cell: int, goal: int) -> int:
	var flow := _flows[entities.flow_ids[id - 1]]
	var near := _chebyshev(cell, goal) <= SLOT_APPROACH_CELLS
	if near or flow.is_stale() or not flow.reached(cell) or flow.next[cell] == NavGrid.NO_CELL:
		_release_flow(id)
		_plan_path(id)
		return NavGrid.NO_CELL
	return flow.next[cell]


func _waypoint_reached(id: int, cell: int) -> void:
	var slot := id - 1
	if entities.flow_ids[slot] != 0:
		return
	var path := entities.paths[slot]
	var i := entities.path_index[slot]
	if i < path.size() and path[i] == cell:
		entities.path_index[slot] = i + 1
		_smooth(id)


## Path smoothing: instead of zig-zagging through cell centres, head for the farthest path cell
## (or the target itself) the unit can walk to in a straight line, over open cells no slower
## than the path it skips. Run when a path is planned and at each waypoint, not every tick.
func _smooth(id: int) -> void:
	var e := entities
	var slot := id - 1
	var path := e.paths[slot]
	var i := e.path_index[slot]
	if path.is_empty() or i >= path.size():
		return
	var cls: int = e.move_class[slot]
	var px := e.pos_x[slot]
	var py := e.pos_y[slot]
	var goal := nav.cell_of(e.target_x[slot], e.target_y[slot])
	if path[-1] == goal and path.size() - i <= DIRECT_CELLS:
		var slowest := _slowest_on(cls, path, i, path.size() - 1)
		if slowest > 0 and _line_clear(cls, px, py, e.target_x[slot], e.target_y[slot], slowest):
			e.direct[slot] = 1
			return
	for j in range(mini(i + SMOOTH_LOOKAHEAD, path.size() - 1), i, -1):
		var slowest := _slowest_on(cls, path, i, j)
		# Through an own gate (closed to everyone else) only from cell to cell.
		if (
			slowest > 0
			and _line_clear(cls, px, py, nav.center_x(path[j]), nav.center_y(path[j]), slowest)
		):
			e.path_index[slot] = j
			return


func _slowest_on(cls: int, path: PackedInt32Array, from: int, to: int) -> int:
	var slowest := 1 << 30
	for k in range(from, to + 1):
		slowest = mini(slowest, nav.cell_permille(cls, path[k]))
	return slowest


## True when a straight walk crosses only cells that are open, at least `min_permille` fast,
## not hills (climbing is not free), and never squeezes diagonally between two closed corners.
func _line_clear(cls: int, ax: int, ay: int, bx: int, by: int, min_permille: int) -> bool:
	var dist := Fixed.distance(ax, ay, bx, by)
	var samples := dist / LINE_SAMPLE + 1
	var prev := nav.cell_of(ax, ay)
	for k in range(1, samples + 1):
		var cell := nav.cell_of(ax + (bx - ax) * k / samples, ay + (by - ay) * k / samples)
		if cell == prev:
			continue
		if nav.cell_permille(cls, cell) < min_permille or nav.is_climb(prev, cell):
			return false
		if cell % nav.width != prev % nav.width and cell / nav.width != prev / nav.width:
			var side_a := nav.cell_at(cell % nav.width, prev / nav.width)
			var side_b := nav.cell_at(prev % nav.width, cell / nav.width)
			if not nav.passable(cls, side_a) or not nav.passable(cls, side_b):
				return false
		prev = cell
	return true


## Re-plans a unit that stopped getting closer (pushed off its path, blocked by a crowd) and
## gives up after MAX_REPLANS stalls in a row, so nobody walks in place forever.
func _watch_progress(id: int) -> void:
	var e := entities
	var slot := id - 1
	if e.orders[slot] != EntityStore.Order.MOVE or e.path_version[slot] == PATH_PENDING:
		return
	if e.flow_ids[slot] != 0 and not _flows[e.flow_ids[slot]].done:
		return
	var d := Fixed.distance(e.pos_x[slot], e.pos_y[slot], e.target_x[slot], e.target_y[slot])
	if d < e.best_dist[slot]:
		e.best_dist[slot] = d
		e.stall[slot] = 0
		e.replans[slot] = 0
		return
	e.stall[slot] += 1
	if e.stall[slot] < STALL_TICKS:
		return
	e.stall[slot] = 0
	e.replans[slot] += 1
	if e.replans[slot] > MAX_REPLANS:
		_stop(id)
	else:
		_release_flow(id)
		_plan_path(id)


static func _chebyshev_cells(ax: int, ay: int, bx: int, by: int) -> int:
	return maxi(absi(ax - bx), absi(ay - by))


func _chebyshev(a: int, b: int) -> int:
	return _chebyshev_cells(a % nav.width, a / nav.width, b % nav.width, b / nav.width)
