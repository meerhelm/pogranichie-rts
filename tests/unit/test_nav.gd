extends GutTest
## M3: terrain from the catalog, the nav grid, A*, flow fields and formations.

var _db: CatalogDB


func before_all() -> void:
	_db = CatalogDB.load_all()


func _grid(text: String) -> NavGrid:
	return MapText.parse(text, _db)


func _cells(grid: NavGrid, path: PackedInt32Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in path:
		out.append(Vector2i(c % grid.width, c / grid.width))
	return out


func _terrains_on(grid: NavGrid, path: PackedInt32Array) -> Dictionary:
	var seen := {}
	for c in path:
		seen[String(grid.terrain_at(c))] = true
	return seen


func test_terrain_numbers_from_catalog() -> void:
	var forest := _db.terrain(&"t_forest")
	assert_eq([forest.infantry_permille, forest.cavalry_permille], [700, 500])
	assert_eq(_db.terrain(&"t_bog").infantry_permille, 500)
	assert_eq(_db.terrain(&"t_ford").infantry_permille, 400)
	assert_true(_db.terrain(&"t_ford").siege_blocked)
	assert_eq(_db.terrain(&"t_road").cavalry_permille, 1200)
	var hill := _db.terrain(&"t_hill")
	assert_eq([hill.infantry_permille, hill.uphill_permille], [1000, 900])
	assert_false(_db.terrain(&"t_old_forest").passable)
	assert_false(_db.terrain(&"t_quagmire").passable)
	assert_true(_db.terrain(&"t_water").boats_only)
	assert_false(_db.terrain(&"t_water").passable)


func test_move_class_from_catalog_classes() -> void:
	assert_eq(NavGrid.move_class_for(_db.unit(&"to_knight_brother")), NavGrid.MoveClass.CAVALRY)
	assert_eq(NavGrid.move_class_for(_db.unit(&"gdl_light_horse")), NavGrid.MoveClass.CAVALRY)
	assert_eq(NavGrid.move_class_for(_db.unit(&"gdl_wagon")), NavGrid.MoveClass.SIEGE)
	var samogitian := _db.unit(&"gdl_samogitian")
	assert_eq(NavGrid.move_class_for(samogitian), NavGrid.MoveClass.FOREST_FOOT)
	assert_eq(NavGrid.move_class_for(_db.unit(&"gdl_spearman")), NavGrid.MoveClass.FOOT)


func test_map_text_round_trips() -> void:
	var text := "..f#\n~=bh\n"
	var grid := _grid(text)
	assert_eq([grid.width, grid.height], [4, 2])
	assert_eq(grid.terrain_at(grid.cell_at(2, 0)), &"t_forest")
	assert_eq(MapText.to_text(grid), text)


func test_straight_path_on_open_ground() -> void:
	var grid := NavGrid.for_catalog(20, 20, _db)
	var pf := Pathfinder.new(grid)
	var path := pf.find_path(NavGrid.MoveClass.FOOT, grid.cell_at(2, 2), grid.cell_at(12, 6))
	assert_eq(path.size(), 10, "8-direction steps: max(dx, dy)")
	assert_eq(path[-1], grid.cell_at(12, 6))
	assert_eq(pf.path_cost(NavGrid.MoveClass.FOOT, grid.cell_at(2, 2), path), 4 * 141 + 6 * 100)
	assert_eq(pf.last_expanded, 11, "exact heuristic on open ground: no detours explored")


func test_path_goes_around_a_wall_without_cutting_corners() -> void:
	var grid := _grid(
		(
			"\n"
			. join(
				[
					".......",
					"...F...",
					"...F...",
					"...F...",
					".......",
				]
			)
		)
	)
	var pf := Pathfinder.new(grid)
	var path := pf.find_path(NavGrid.MoveClass.FOOT, grid.cell_at(1, 2), grid.cell_at(5, 2))
	assert_false(path.is_empty())
	var prev := grid.cell_at(1, 2)
	for c in path:
		assert_true(grid.passable(NavGrid.MoveClass.FOOT, c))
		var dx := c % grid.width - prev % grid.width
		var dy := c / grid.width - prev / grid.width
		if dx != 0 and dy != 0:
			assert_true(
				grid.passable(
					NavGrid.MoveClass.FOOT, grid.cell_at(c % grid.width, prev / grid.width)
				)
			)
			assert_true(
				grid.passable(
					NavGrid.MoveClass.FOOT, grid.cell_at(prev % grid.width, c / grid.width)
				)
			)
		prev = c
	assert_eq(path[-1], grid.cell_at(5, 2))


func test_ford_is_the_way_across_and_carts_cannot_take_it() -> void:
	var grid := _grid(
		(
			"\n"
			. join(
				[
					"...~...",
					"...~...",
					"...=...",
					"...~...",
					"...~...",
				]
			)
		)
	)
	var pf := Pathfinder.new(grid)
	var start := grid.cell_at(0, 0)
	var goal := grid.cell_at(6, 0)
	var foot := pf.find_path(NavGrid.MoveClass.FOOT, start, goal)
	assert_true(foot.has(grid.cell_at(3, 2)), "foot crosses at the ford")
	assert_eq(foot[-1], goal)
	var cart := pf.find_path(NavGrid.MoveClass.SIEGE, start, goal)
	assert_false(cart.has(grid.cell_at(3, 2)), "siege does not cross a ford")
	assert_eq(cart[-1] % grid.width, 2, "the cart stops on its own bank, closest to the goal")


func test_cavalry_takes_the_road_and_forest_walkers_the_forest() -> void:
	# Straight through: 8 forest cells. Around: a road two rows down.
	var grid := _grid(
		(
			"\n"
			. join(
				[
					"..ffffffff..",
					"..ffffffff..",
					"..ffffffff..",
					"..ffffffff..",
					"############",
				]
			)
		)
	)
	var pf := Pathfinder.new(grid)
	var start := grid.cell_at(0, 1)
	var goal := grid.cell_at(11, 1)
	var knight := pf.find_path(NavGrid.MoveClass.CAVALRY, start, goal)
	assert_true(_terrains_on(grid, knight).has("t_road"), "cavalry detours by road")
	assert_false(_terrains_on(grid, knight).has("t_forest"))
	var samogitian := pf.find_path(NavGrid.MoveClass.FOREST_FOOT, start, goal)
	assert_false(_terrains_on(grid, samogitian).has("t_road"), "no forest penalty, no detour")
	assert_eq(samogitian.size(), 11)


func test_unreachable_goal_leads_to_the_closest_cell() -> void:
	var grid := _grid(
		(
			"\n"
			. join(
				[
					"..~~~~~",
					"..~...~",
					"..~...~",
					"..~~~~~",
				]
			)
		)
	)
	var pf := Pathfinder.new(grid)
	var path := pf.find_path(NavGrid.MoveClass.FOOT, grid.cell_at(0, 0), grid.cell_at(4, 2))
	assert_eq(_cells(grid, path)[-1], Vector2i(1, 2))


func test_same_search_twice_gives_the_same_path() -> void:
	var grid := NavGrid.for_catalog(30, 30, _db)
	for i in 30:
		grid.set_blocked(grid.cell_at(15, i), i != 7 and i != 22)
	var pf := Pathfinder.new(grid)
	var a := pf.find_path(NavGrid.MoveClass.FOOT, grid.cell_at(2, 15), grid.cell_at(28, 15))
	var b := Pathfinder.new(grid).find_path(
		NavGrid.MoveClass.FOOT, grid.cell_at(2, 15), grid.cell_at(28, 15)
	)
	assert_eq(a, b)
	assert_true(a.has(grid.cell_at(15, 7)) or a.has(grid.cell_at(15, 22)))


func test_blocking_a_cell_changes_the_grid_version() -> void:
	var grid := NavGrid.for_catalog(5, 5, _db)
	var v := grid.version
	grid.set_blocked(3, true)
	grid.set_blocked(3, true)
	assert_false(grid.passable(NavGrid.MoveClass.FOOT, 3))
	grid.set_blocked(3, false)
	assert_false(grid.passable(NavGrid.MoveClass.FOOT, 3), "two blockers, one removed")
	grid.set_blocked(3, false)
	assert_true(grid.passable(NavGrid.MoveClass.FOOT, 3))
	assert_eq(grid.version, v + 4)


func test_flow_field_leads_every_start_to_the_goal() -> void:
	var grid := MapText.load_map("res://tests/maps/forest_ford.txt", _db)
	var goal := grid.cell_at(36, 14)
	var starts := PackedInt32Array()
	for y in range(10, 20):
		for x in range(2, 6):
			starts.append(grid.cell_at(x, y))
	var flow := FlowField.new(grid, NavGrid.MoveClass.FOOT, goal, starts)
	var pf := Pathfinder.new(grid)
	for s in starts:
		assert_true(flow.reached(s))
		var cur := s
		var steps := 0
		while cur != goal and steps < 200:
			var nxt := flow.next[cur]
			assert_lt(flow.dist[nxt], flow.dist[cur])
			cur = nxt
			steps += 1
		assert_eq(cur, goal)
	# The field's cost equals the best A* cost from the same cell.
	var start := grid.cell_at(3, 3)
	var path := pf.find_path(NavGrid.MoveClass.FOOT, start, goal)
	var flow2 := FlowField.new(grid, NavGrid.MoveClass.FOOT, goal, PackedInt32Array([start]))
	assert_eq(flow2.dist[start], pf.path_cost(NavGrid.MoveClass.FOOT, start, path))


func test_formation_shapes() -> void:
	var line := Formation.offsets(Formation.Kind.LINE, 50)
	assert_eq(line.size(), 50)
	assert_eq(Formation.line_width(50), 15)
	var column := Formation.offsets(Formation.Kind.COLUMN, 10)
	var widths := _rank_widths(column)
	assert_eq(widths, [3, 3, 3, 1])
	var wedge := Formation.offsets(Formation.Kind.WEDGE, 12)
	assert_eq(_rank_widths(wedge), [1, 3, 5, 3])
	assert_eq(wedge[0].x, 0, "the wedge's point is in the middle")
	for shape: Array[Vector2i] in [line, column, wedge]:
		var seen := {}
		for o in shape:
			assert_false(seen.has(o), "two slots in one place")
			seen[o] = true


func _rank_widths(slots: Array[Vector2i]) -> Array[int]:
	var widths: Array[int] = []
	var last := -(1 << 40)
	for s in slots:
		if s.y != last:
			widths.append(0)
			last = s.y
		widths[-1] += 1
	return widths


func test_formation_faces_the_direction_of_travel() -> void:
	# Moving east, a line stands north-south: all slots share x, spread over y.
	var slots := Formation.slot_positions(
		Formation.Kind.LINE, 4, Fixed.from_cells(10), Fixed.from_cells(10), Fixed.ONE, 0
	)
	for s in slots:
		assert_eq(s.x, Fixed.from_cells(10))
	assert_eq(slots[0].y, Fixed.from_cells(10) - 3 * Fixed.HALF)
	assert_eq(slots[3].y, Fixed.from_cells(10) + 3 * Fixed.HALF)


func test_slot_assignment_is_a_permutation_that_keeps_order() -> void:
	var ids := PackedInt32Array([4, 7, 9])
	# Facing east; unit 9 is northmost, 4 southmost: left-to-right is north-to-south.
	var xs := PackedInt64Array([0, 0, 0])
	var ys := PackedInt64Array([Fixed.from_cells(5), 0, -Fixed.from_cells(5)])
	var taken := Formation.assign(Formation.Kind.LINE, ids, xs, ys, Fixed.ONE, 0)
	assert_eq(taken, PackedInt32Array([2, 1, 0]))


func test_skirmish_map_connects_both_starts_for_every_kind_of_unit() -> void:
	var grid := MapText.load_map("map_proto_samogitia", _db)
	assert_eq([grid.width, grid.height], [120, 120])
	var pf := Pathfinder.new(grid)
	var gdl := grid.cell_at(14, 14)
	var order := grid.cell_at(104, 104)
	for cls in NavGrid.MOVE_CLASS_COUNT:
		assert_true(grid.passable(cls, gdl) and grid.passable(cls, order))
		var path := pf.find_path(cls, gdl, order)
		assert_eq(
			path[-1] if not path.is_empty() else -1, order, "class %d reaches the Order" % cls
		)
	var cart := pf.find_path(NavGrid.MoveClass.SIEGE, gdl, order)
	assert_false(_terrains_on(grid, cart).has("t_ford"), "carts cross by the bridge")
