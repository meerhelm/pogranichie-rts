extends GutTest
## M3 acceptance: units walk the map by terrain, in formation, and arrive.

const SPEARMAN := &"gdl_spearman"
const PEASANT := &"gdl_peasant"
const KNIGHT := &"to_knight_brother"

var _db: CatalogDB


func before_all() -> void:
	_db = CatalogDB.load_all()


func _cell(n: int) -> int:
	return Fixed.from_cells(n) + Fixed.HALF


func _sim_on(text: String) -> Simulation:
	return Simulation.new(1, _db, 0, 0, MapText.parse(text, _db))


## Ticks until unit 1 walks from (0, 1) to (11, 1) over ten cells of the given terrain.
func _walk_ticks(tile: String, unit: StringName) -> int:
	# Water on both sides, so the only way is along the row.
	var row := "." + tile.repeat(10) + "."
	var sim := _sim_on("\n".join(["~".repeat(12), row, "~".repeat(12)]))
	sim.enqueue(SimCommand.spawn(0, 1, unit, _cell(0), _cell(1)))
	sim.enqueue(SimCommand.move(0, 1, PackedInt32Array([1]), _cell(11), _cell(1)))
	for t in 2000:
		sim.step()
		if sim.entities.orders[0] == EntityStore.Order.IDLE:
			return sim.tick
	return -1


func test_time_on_the_road_through_the_forest_and_the_ford() -> void:
	# Spearman 0,9 cells/s = 46 units a tick: 11 cells take 11264 / 46 = 245 ticks on grass.
	var speed := Fixed.speed_per_tick(_db.unit(SPEARMAN).speed_milli)
	assert_eq(speed, 46)
	assert_almost_eq(_walk_ticks(".", SPEARMAN), ceili(11264.0 / speed), 1)
	assert_almost_eq(_walk_ticks("f", SPEARMAN), _expected(speed, 700), 2)
	assert_almost_eq(_walk_ticks("b", SPEARMAN), _expected(speed, 500), 2)
	assert_almost_eq(_walk_ticks("=", SPEARMAN), _expected(speed, 400), 2)
	assert_almost_eq(_walk_ticks("#", SPEARMAN), _expected(speed, 1200), 2)
	var knight := Fixed.speed_per_tick(_db.unit(KNIGHT).speed_milli)
	assert_almost_eq(_walk_ticks("f", KNIGHT), _expected(knight, 500), 2)


## Ticks for the walk: half a grass cell at each end and ten cells of the tested terrain, where
## a tick covers speed * permille / 1000 units, rounded down like the simulation does.
func _expected(speed: int, permille: int) -> int:
	return roundi(float(Fixed.ONE) / speed + 10.0 * Fixed.ONE / (speed * permille / 1000))


func test_climbing_a_hill_is_slower_than_walking_on_it() -> void:
	var climb := _walk_ticks("h", SPEARMAN)
	var flat := _walk_ticks(".", SPEARMAN)
	assert_gt(climb, flat, "the first hill cell is a climb")
	# One cell at 0,9 of the speed (46 → 41 units a tick) costs about 3 ticks more.
	assert_almost_eq(climb, flat + 3, 1, "only the first cell is climbed, the top is flat")


func test_group_walks_at_the_speed_of_the_slowest() -> void:
	var sim := Simulation.new(1, _db, 40, 20)
	sim.enqueue(SimCommand.spawn(0, 1, KNIGHT, _cell(2), _cell(5)))
	sim.enqueue(SimCommand.spawn(0, 1, PEASANT, _cell(2), _cell(7)))
	sim.enqueue(SimCommand.move(0, 1, PackedInt32Array([1, 2]), _cell(30), _cell(6)))
	sim.step()
	var e := sim.entities
	var peasant_speed := Fixed.speed_per_tick(_db.unit(PEASANT).speed_milli)
	assert_eq(e.move_speed[0], peasant_speed)
	assert_eq(e.move_speed[1], peasant_speed)
	var arrived := [-1, -1]
	for t in 1500:
		sim.step()
		for i in 2:
			if arrived[i] < 0 and e.orders[i] == EntityStore.Order.IDLE:
				arrived[i] = sim.tick
	assert_gt(arrived[0], 0)
	assert_almost_eq(arrived[0], arrived[1], 25, "they arrive together")
	assert_eq(e.speed[0], Fixed.speed_per_tick(_db.unit(KNIGHT).speed_milli), "own speed kept")
	assert_eq(e.move_speed[0], e.speed[0], "after the order, back to its own speed")


func test_fifty_units_cross_forest_and_ford_in_formation() -> void:
	for kind: Formation.Kind in [Formation.Kind.LINE, Formation.Kind.COLUMN, Formation.Kind.WEDGE]:
		var grid := MapText.load_map("res://tests/maps/forest_ford.txt", _db)
		var sim := Simulation.new(7, _db, 0, 0, grid)
		var ids := PackedInt32Array()
		for i in 50:
			var unit := SPEARMAN if i % 3 != 0 else PEASANT
			sim.enqueue(SimCommand.spawn(0, 1, unit, _cell(1 + i % 5 * 2), _cell(4 + i / 5 * 2)))
			ids.append(i + 1)
		var target := Vector2i(_cell(36), _cell(14))
		sim.enqueue(SimCommand.move(1, 1, ids, target.x, target.y, kind))
		sim.run(2)
		var e := sim.entities
		var slots := {}
		for id in ids:
			slots[id] = Vector2i(e.target_x[id - 1], e.target_y[id - 1])
		var ticks := 0
		while ticks < 6000 and _moving(e) > 0:
			sim.step()
			ticks += 1
		assert_eq(
			_moving(e), 0, "%s: all 50 arrived within 6000 ticks" % Formation.Kind.keys()[kind]
		)
		var spots := {}
		for id in ids:
			var slot := id - 1
			var at := Vector2i(e.pos_x[slot], e.pos_y[slot])
			var want: Vector2i = slots[id]
			# A slot moved off a thicket or the water can end up closer to its neighbour than a
			# body (3/4 cell): the two standing men then step a little apart.
			assert_lte(
				maxi(absi(at.x - want.x), absi(at.y - want.y)),
				Fixed.ONE / 4,
				(
					"%s: unit %d stands in its slot (order %d, replans %d)"
					% [Formation.Kind.keys()[kind], id, e.orders[slot], e.replans[slot]]
				)
			)
			assert_false(spots.has(at), "two units in one spot")
			spots[at] = true
			assert_true(grid.passable(e.move_class[slot], grid.cell_of(at.x, at.y)))


func _moving(e: EntityStore) -> int:
	var n := 0
	for id in e.alive_ids:
		if e.orders[id - 1] == EntityStore.Order.MOVE:
			n += 1
	return n


func test_zaseka_across_the_way_makes_units_go_around() -> void:
	var sim := Simulation.new(1, _db, 30, 30)
	sim.enqueue(SimCommand.spawn(0, 1, SPEARMAN, _cell(2), _cell(15)))
	sim.enqueue(SimCommand.move(0, 1, PackedInt32Array([1]), _cell(27), _cell(15)))
	sim.run(40)
	# A wall at x = 15 from y = 5 to 25 appears while the unit is on the way.
	for y in range(5, 26):
		sim.nav.set_blocked(sim.nav.cell_at(15, y), true)
	var e := sim.entities
	var went_around := false
	for t in 3000:
		sim.step()
		var cell := sim.nav.cell_of(e.pos_x[0], e.pos_y[0])
		assert_true(sim.nav.passable(NavGrid.MoveClass.FOOT, cell))
		if cell % 30 == 15:
			went_around = true
		if e.orders[0] == EntityStore.Order.IDLE:
			break
	assert_true(went_around)
	assert_eq([e.pos_x[0], e.pos_y[0]], [_cell(27), _cell(15)])


func test_crowded_units_push_apart() -> void:
	var sim := Simulation.new(1, _db, 20, 20)
	for i in 4:
		sim.enqueue(SimCommand.spawn(0, 1, SPEARMAN, _cell(10), _cell(10)))
	sim.run(60)
	var e := sim.entities
	for a in 4:
		for b in range(a + 1, 4):
			var d := Fixed.distance(e.pos_x[a], e.pos_y[a], e.pos_x[b], e.pos_y[b])
			assert_gt(d, Simulation.SEPARATION / 2, "units %d and %d" % [a + 1, b + 1])


## Two of a side's peasants walking at each other along one line, in the open and along a lane
## one cell wide (between trees): both step aside and get where they were going.
func _head_on(rows: PackedStringArray, y: int) -> void:
	var sim := _sim_on("\n".join(rows))
	sim.enqueue(SimCommand.spawn(0, 1, PEASANT, _cell(1), _cell(y)))
	sim.enqueue(SimCommand.spawn(0, 1, PEASANT, _cell(14), _cell(y)))
	sim.enqueue(SimCommand.move(0, 1, PackedInt32Array([1]), _cell(14), _cell(y)))
	sim.enqueue(SimCommand.move(0, 1, PackedInt32Array([2]), _cell(1), _cell(y)))
	var e := sim.entities
	for t in 1200:
		sim.step()
		if e.orders[0] == EntityStore.Order.IDLE and e.orders[1] == EntityStore.Order.IDLE:
			break
	var near := Fixed.ONE / 2
	assert_lt(Fixed.distance(e.pos_x[0], e.pos_y[0], _cell(14), _cell(y)), near, "first got there")
	assert_lt(Fixed.distance(e.pos_x[1], e.pos_y[1], _cell(1), _cell(y)), near, "second got there")


func test_two_peasants_walking_head_on_pass_each_other() -> void:
	_head_on(PackedStringArray([".".repeat(16), ".".repeat(16), ".".repeat(16)]), 1)


func test_two_peasants_head_on_in_a_lane_between_trees_pass_each_other() -> void:
	var trees := "F".repeat(16)
	_head_on(PackedStringArray([trees, ".".repeat(16), trees]), 1)


func test_unit_spawned_in_water_is_put_on_the_bank() -> void:
	var sim := _sim_on("..~~\n..~~\n")
	sim.enqueue(SimCommand.spawn(0, 1, SPEARMAN, _cell(3), _cell(0)))
	sim.step()
	var cell := sim.nav.cell_of(sim.entities.pos_x[0], sim.entities.pos_y[0])
	assert_eq(cell, sim.nav.cell_at(1, 0))


## M10: a long search is spread over ticks (at most PATH_BUDGET cells a tick) and the unit
## waits for it, then walks the whole winding way.
func test_long_search_runs_in_slices() -> void:
	var rows := PackedStringArray()
	for y in 41:
		if y % 2 == 0:
			rows.append(".".repeat(60))
		elif y % 4 == 1:
			rows.append("~".repeat(59) + ".")
		else:
			rows.append("." + "~".repeat(59))
	var sim := _sim_on("\n".join(rows))
	sim.enqueue(SimCommand.spawn(0, 1, SPEARMAN, _cell(0), _cell(0)))
	sim.enqueue(SimCommand.move(0, 1, PackedInt32Array([1]), _cell(0), _cell(40)))
	var slices := 0
	var before := 0
	while slices == 0 or sim.entities.path_version[0] == Simulation.PATH_PENDING:
		sim.step()
		var spent := sim.pathfinder.total_expanded - before
		before = sim.pathfinder.total_expanded
		assert_lte(spent, Simulation.PATH_BUDGET)
		slices += 1
		if slices > 50:
			break
	assert_gt(slices, 1, "the search took more than one tick")
	assert_eq(sim.pathfinder.searches, 1)
	var path := sim.entities.paths[0]
	assert_gt(path.size(), 1000, "the path winds through every row")
	assert_eq(path[-1], sim.nav.cell_at(0, 40), "and ends at the order point")
	var y0 := sim.entities.pos_y[0]
	sim.run(100)
	assert_ne(sim.entities.pos_y[0] + sim.entities.pos_x[0], y0 + _cell(0), "the unit walks")
