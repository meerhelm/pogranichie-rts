extends EconomyTest
## M5: gathering and construction in the running simulation (training and research:
## test_production.gd).

const FIVE_MINUTES := 5 * 60 * Fixed.TICKS_PER_SECOND

# --- gathering -----------------------------------------------------------------------------


## The M5 acceptance test: 10 peasants felling for 5 minutes bring what the catalog's rate and
## carry give, with the walk to the lumber yard and back counted, within ±5%.
func test_ten_peasants_on_wood_for_five_minutes() -> void:
	# Forest from column 20 east; five lumber yards (2×2) in column 13–14, so every peasant
	# has its own tree in row 10..19 and a yard straight to the west, a 5-cell gap between.
	var sim := _drawn(40, 30, _fill({}, 20, 8, 24, 21, "f"))
	_join(sim, 1, GDL)
	for i in 5:
		assert_ne(_place(sim, 1, &"gdl_lumber_yard", 13, 10 + 2 * i), 0)
	var ids := PackedInt32Array()
	for row in range(10, 20):
		ids.append(_spawn(sim, 1, PEASANT, 16.5, row + 0.5))
	var before := _stock(sim, 1, EconomySystem.WOOD)
	for i in ids.size():
		var row := 10 + i
		sim.enqueue(SimCommand.gather_at(sim.tick, 1, _ids(ids[i]), _cell(20), _cell(row)))
	sim.run(FIVE_MINUTES)
	var income := _stock(sim, 1, EconomySystem.WOOD) - before

	# The calculation: walk to the tree, then gather a full load at gather_wood_milli, carry it
	# to the yard (it counts on arrival) and walk back, until the five minutes are up.
	var rules := _db.economy
	var speed := sim.entities.speed[ids[0] - 1]
	var reach := Fixed.from_milli(rules.work_reach_milli)
	var work_x := Fixed.from_cells(20) - reach
	var drop_x := Fixed.from_cells(15) + reach
	var gather_ticks := ceili(float(rules.carry * EconomySystem.UNIT_ACC) / rules.gather_wood_milli)
	var walk_ticks := ceili(float(work_x - drop_x) / speed)
	var t := ceili(float(work_x - _at(16.5)) / speed)
	var per_peasant := 0
	while true:
		t += gather_ticks + walk_ticks
		if t > FIVE_MINUTES:
			break
		per_peasant += rules.carry
		t += walk_ticks
	var expected := per_peasant * ids.size()
	gut.p("wood in 5 min: %d, calculated %d" % [income, expected])
	assert_gt(expected, 0)
	assert_almost_eq(income, expected, expected * 5 / 100, "income within ±5% of the calculation")
	# Felled wood leaves the trees.
	var left := 0
	for row in range(10, 20):
		left += sim.economy.nodes.wood[sim.nav.cell_at(20, row)]
	assert_eq(left, 10 * rules.tree_wood - income - _carried(sim, ids))


func _carried(sim: Simulation, ids: PackedInt32Array) -> int:
	var n := 0
	for id in ids:
		n += sim.economy.carry[id - 1]
	return n


func test_a_felled_tree_turns_to_grass_and_the_peasant_takes_the_next() -> void:
	var sim := _drawn(20, 10, _fill({}, 10, 4, 11, 4, "f"))
	_join(sim, 1, GDL)
	_place(sim, 1, &"gdl_lumber_yard", 6, 4)
	var cell := sim.nav.cell_at(10, 4)
	sim.economy.nodes.wood[cell] = 3
	var p := _spawn(sim, 1, PEASANT, 9.5, 5.5)
	sim.enqueue(SimCommand.gather_at(sim.tick, 1, _ids(p), _cell(10), _cell(4)))
	sim.run(600)
	assert_eq(sim.nav.terrain_at(cell), &"t_grass")
	assert_eq(sim.economy.nodes.wood[cell], 0)
	assert_eq(sim.economy.job_ref[p - 1], sim.nav.cell_at(11, 4), "goes on to the next tree")
	assert_lt(sim.economy.nodes.wood[sim.nav.cell_at(11, 4)], _db.economy.tree_wood)


func test_iron_from_a_bog_ore_deposit() -> void:
	var sim := _drawn(20, 10, {Vector2i(10, 5): "o"})
	_join(sim, 1, GDL)
	_place(sim, 1, &"gdl_mine", 6, 4)
	var node := sim.economy.nodes.at_cell(sim.nav.cell_at(10, 5))
	assert_ne(node, ResourceNodes.NO_ID, "the map's deposit is a node")
	assert_eq(sim.economy.nodes.amounts[node - 1], _db.economy.bog_ore_iron)
	assert_false(sim.nav.passable(NavGrid.MoveClass.FOOT, sim.nav.cell_at(10, 5)), "it blocks")
	var p := _spawn(sim, 1, PEASANT, 9.5, 5.5)
	var before := _stock(sim, 1, EconomySystem.IRON)
	sim.enqueue(SimCommand.gather(sim.tick, 1, _ids(p), EconomySystem.Target.NODE, node))
	sim.run(1200)
	assert_gt(_stock(sim, 1, EconomySystem.IRON), before)
	assert_lt(sim.economy.nodes.amounts[node - 1], _db.economy.bog_ore_iron)


func test_a_hive_takes_two_and_never_runs_out() -> void:
	var sim := _drawn(20, 10, _fill({}, 10, 2, 14, 7, "f"))
	_join(sim, 1, GDL)
	var tc := _place(sim, 1, &"gdl_town_center", 2, 3)
	assert_ne(tc, 0)
	var hive := _place(sim, 1, &"gdl_bort", 10, 5)
	assert_ne(hive, 0, "a hive stands in the forest")
	var ids := PackedInt32Array()
	for i in 3:
		ids.append(_spawn(sim, 1, PEASANT, 8.5, 4.5 + i))
	sim.enqueue(SimCommand.gather(sim.tick, 1, ids, EconomySystem.Target.BUILDING, hive))
	sim.step()
	assert_eq(sim.economy.buildings.workers[hive - 1], _db.economy.bort_workers)
	assert_eq(sim.economy.job[ids[2] - 1], EconomySystem.Job.NONE, "the third finds no place")
	var before := _stock(sim, 1, EconomySystem.FOOD)
	sim.run(2400)
	assert_gt(_stock(sim, 1, EconomySystem.FOOD), before)
	assert_eq(sim.economy.job[ids[0] - 1], EconomySystem.Job.GATHER, "still gathering")


func test_hunting_an_elk_leaves_a_carcass_to_gather() -> void:
	var sim := _open()
	_join(sim, 1, GDL)
	_place(sim, 1, &"gdl_town_center", 2, 2)
	var elk := _spawn(sim, 0, &"nt_elk", 12.5, 4.5)
	var ids := PackedInt32Array()
	for i in 3:
		ids.append(_spawn(sim, 1, PEASANT, 11.5, 3.5 + i))
	var before := _stock(sim, 1, EconomySystem.FOOD)
	sim.enqueue(SimCommand.gather(sim.tick, 1, ids, EconomySystem.Target.ANIMAL, elk))
	sim.run(2400)
	assert_false(sim.entities.is_alive(elk), "the elk is down")
	assert_gt(_stock(sim, 1, EconomySystem.FOOD), before, "meat brought to the centre")


# --- construction --------------------------------------------------------------------------


func test_cannot_build_on_water() -> void:
	var sim := _drawn(20, 10, _fill({}, 8, 2, 12, 6, "~"))
	_join(sim, 1, GDL)
	var p := _spawn(sim, 1, PEASANT, 4.5, 4.5)
	var house := _db.building(&"gdl_house")
	assert_eq(sim.economy.placement.can_place(1, house, 9, 3, false), EconomySystem.Fail.TERRAIN)
	assert_eq(
		sim.economy.placement.can_place(1, house, 7, 3, false),
		EconomySystem.Fail.TERRAIN,
		"half on the shore is still on water"
	)
	var wood := _stock(sim, 1, EconomySystem.WOOD)
	assert_eq(_build(sim, 1, _ids(p), &"gdl_house", 9, 3), 0, "no foundation")
	assert_eq(_stock(sim, 1, EconomySystem.WOOD), wood, "nothing paid")
	assert_eq(sim.economy.placement.can_place(1, house, 3, 3, false), EconomySystem.Fail.OK)


func test_cannot_build_on_units_of_buildings_or_off_the_map() -> void:
	var sim := _open(20, 10)
	_join(sim, 1, GDL)
	_place(sim, 1, &"gdl_house", 5, 5)
	var house := _db.building(&"gdl_house")
	assert_eq(sim.economy.placement.can_place(1, house, 6, 6, false), EconomySystem.Fail.OCCUPIED)
	assert_eq(
		sim.economy.placement.can_place(1, house, 19, 3, false), EconomySystem.Fail.OUT_OF_MAP
	)
	assert_eq(
		sim.economy.placement.can_place(1, _db.building(&"to_house"), 1, 1, false),
		EconomySystem.Fail.FACTION
	)
	assert_eq(
		sim.economy.placement.can_place(1, _db.building(&"gdl_castle"), 1, 1, false),
		EconomySystem.Fail.AGE
	)


func test_more_builders_build_faster() -> void:
	var house := _db.building(&"gdl_house")
	var times: Array[int] = []
	for n: int in [1, 3]:
		var sim := _open(20, 12)
		_join(sim, 1, GDL)
		var ids := PackedInt32Array()
		for i in n:
			ids.append(_spawn(sim, 1, PEASANT, 4.5, 4.5 + i))
		var wood := _stock(sim, 1, EconomySystem.WOOD)
		var b := _build(sim, 1, ids, &"gdl_house", 5, 4)
		assert_ne(b, 0)
		assert_eq(_stock(sim, 1, EconomySystem.WOOD), wood - house.cost_wood, "paid when laid")
		times.append(_until_done(sim, b, 2000))
		assert_eq(sim.economy.buildings.hp[b - 1], house.hp, "full HP when finished")
		assert_eq(sim.economy.pop_cap(1), house.pop_provided)
	var three := house.build_ticks * 1000 / (1000 + 2 * _db.economy.builder_extra_permille)
	# The builders standing next to it start in the tick the order comes, so one tick less.
	assert_between(times[0], house.build_ticks - 1, house.build_ticks + 20, "one builder")
	assert_between(times[1], three - 1, three + 20, "three builders")


func test_repair_restores_hp_for_half_the_price() -> void:
	var sim := _open(20, 12)
	_join(sim, 1, GDL)
	var b := _place(sim, 1, &"gdl_lumber_yard", 5, 4)
	var def := _db.building(&"gdl_lumber_yard")
	sim.economy.hit_building(b, def.hp / 2)
	var p := _spawn(sim, 1, PEASANT, 4.5, 4.5)
	var wood := _stock(sim, 1, EconomySystem.WOOD)
	sim.enqueue(SimCommand.on_building(sim.tick, 1, SimCommand.Kind.WORK, _ids(p), b))
	sim.run(def.build_ticks / 2 + 40)
	assert_eq(sim.economy.buildings.hp[b - 1], def.hp)
	var price := def.cost_wood * _db.economy.repair_cost_permille / 1000 / 2
	assert_almost_eq(wood - _stock(sim, 1, EconomySystem.WOOD), price, 1)
	assert_eq(sim.economy.job[p - 1], EconomySystem.Job.NONE, "done")


func test_palisade_line_cell_by_cell_without_diagonal_gaps() -> void:
	var sim := _open(30, 20)
	_join(sim, 1, GDL)
	var ids := PackedInt32Array(
		[_spawn(sim, 1, PEASANT, 4.5, 4.5), _spawn(sim, 1, PEASANT, 4.5, 6.5)]
	)
	var wood := _stock(sim, 1, EconomySystem.WOOD)
	var first := sim.economy.buildings.next_id
	sim.enqueue(
		SimCommand.wall(
			sim.tick,
			1,
			ids,
			&"gdl_palisade",
			Vector2i(_cell(5), _cell(5)),
			Vector2i(_cell(13), _cell(8))
		)
	)
	sim.step()
	var count := sim.economy.buildings.next_id - first
	assert_eq(count, 8 + 3 + 1, "a 4-connected line")
	var per_cell := _db.building(&"gdl_palisade").cost_wood
	assert_eq(_stock(sim, 1, EconomySystem.WOOD), wood - count * per_cell)
	for b in range(first + 1, first + count):
		var s := b - 1
		var step := absi(sim.economy.buildings.cell_x[s] - sim.economy.buildings.cell_x[s - 1])
		step += absi(sim.economy.buildings.cell_y[s] - sim.economy.buildings.cell_y[s - 1])
		assert_eq(step, 1, "no diagonal step")
	sim.run(1500)
	for b in range(first, first + count):
		assert_true(sim.economy.buildings.is_done(b), "every cell built")
		assert_false(
			sim.nav.passable(NavGrid.MoveClass.FOOT, sim.economy.buildings.cells_of(b, 30)[0])
		)


func test_a_gate_lets_its_owner_through_and_stops_others() -> void:
	var sim := _open(20, 10)
	_join(sim, 1, GDL)
	for y in 10:
		if y == 5:
			assert_ne(_place(sim, 1, &"gdl_gate", 10, y), 0)
		else:
			_place(sim, 1, &"gdl_palisade", 10, y)
	var own := _spawn(sim, 1, PEASANT, 5.5, 5.5)
	var enemy := _spawn(sim, 2, TO_PEASANT, 5.5, 4.5)
	sim.enqueue(SimCommand.move(sim.tick, 1, _ids(own), _at(15.5), _at(5.5)))
	sim.enqueue(SimCommand.move(sim.tick, 2, _ids(enemy), _at(15.5), _at(4.5)))
	sim.run(400)
	assert_gt(sim.entities.pos_x[own - 1], _at(14.0), "the owner walks through")
	assert_lt(sim.entities.pos_x[enemy - 1], _at(10.0), "the enemy stays outside")


func test_zaseka_is_felled_from_the_forest_in_fifteen_seconds() -> void:
	var sim := _drawn(20, 10, _fill({}, 8, 2, 14, 7, "f"))
	_join(sim, 1, GDL)
	var zaseka := _db.building(&"gdl_zaseka")
	assert_eq(
		sim.economy.placement.can_place(1, zaseka, 2, 2, false), EconomySystem.Fail.NOT_FOREST
	)
	var p := _spawn(sim, 1, PEASANT, 6.5, 4.5)
	var wood := _stock(sim, 1, EconomySystem.WOOD)
	var b := _build(sim, 1, _ids(p), &"gdl_zaseka", 8, 4)
	assert_ne(b, 0)
	assert_eq(_stock(sim, 1, EconomySystem.WOOD), wood, "free")
	assert_eq(sim.economy.buildings.w[b - 1], _db.economy.zaseka_cells)
	assert_between(_until_done(sim, b, 1000), zaseka.build_ticks, zaseka.build_ticks + 20)
	assert_eq(sim.economy.buildings.hp[b - 1], zaseka.hp)
	for cell in sim.economy.buildings.cells_of(b, 20):
		assert_eq(sim.nav.terrain_at(cell), &"t_grass", "the trees are down")
		assert_false(sim.nav.passable(NavGrid.MoveClass.FOOT, cell), "and lie across the way")


func test_zaseka_tech_halves_the_time_and_adds_half_the_hp() -> void:
	var sim := _drawn(20, 10, _fill({}, 8, 2, 14, 7, "f"))
	var state := _join(sim, 1, GDL)
	var yard := _place(sim, 1, &"gdl_lumber_yard", 2, 2)
	state.stock[EconomySystem.FOOD] = 1000
	sim.enqueue(SimCommand.queue_item(sim.tick, 1, yard, &"t_gdl_zaseka"))
	sim.run(_db.tech(&"t_gdl_zaseka").research_ticks + 2)
	assert_true(state.techs.has(&"t_gdl_zaseka"))
	var p := _spawn(sim, 1, PEASANT, 6.5, 4.5)
	var b := _build(sim, 1, _ids(p), &"gdl_zaseka", 8, 4)
	var zaseka := _db.building(&"gdl_zaseka")
	assert_between(_until_done(sim, b, 1000), zaseka.build_ticks / 2, zaseka.build_ticks / 2 + 20)
	assert_eq(sim.economy.buildings.hp[b - 1], zaseka.hp * 3 / 2)


func test_podseka_only_near_the_forest() -> void:
	var sim := _drawn(30, 12, _fill({}, 20, 0, 29, 11, "f"))
	_join(sim, 1, GDL)
	var farm := _db.building(&"gdl_farm")
	assert_eq(
		sim.economy.placement.can_place(1, farm, 3, 3, false), EconomySystem.Fail.NO_FOREST_NEAR
	)
	assert_eq(sim.economy.placement.can_place(1, farm, 16, 3, false), EconomySystem.Fail.OK)
	var b := _place(sim, 1, &"gdl_farm", 16, 3)
	assert_eq(sim.economy.buildings.food[b - 1], farm.param(&"food_capacity"))
	assert_true(sim.nav.passable(NavGrid.MoveClass.FOOT, sim.nav.cell_at(17, 4)), "walked over")


func test_brickworks_cheapens_order_walls() -> void:
	var sim := _open(20, 12)
	_join(sim, 2, ORDER)
	var wall := _db.building(&"to_wall")
	var before := sim.economy.placement.building_cost(2, wall)
	_place(sim, 2, &"to_brickworks", 5, 5)
	var after := sim.economy.placement.building_cost(2, wall)
	var rules := _db.economy
	assert_eq(
		after[EconomySystem.WOOD],
		wall.cost_wood * (1000 - rules.brick_wood_discount_permille) / 1000
	)
	assert_eq(
		after[EconomySystem.SILVER],
		wall.cost_silver * (1000 - rules.brick_wall_silver_discount_permille) / 1000
	)
	assert_eq(before[EconomySystem.WOOD], wall.cost_wood)


func test_the_builder_of_a_field_works_it_at_once() -> void:
	var sim := _drawn(20, 12)
	var state := _join(sim, 1, ORDER)
	_place(sim, 1, &"to_town_center", 2, 2)
	state.stock[EconomySystem.WOOD] = 500
	var builders := PackedInt32Array()
	for i in sim.economy.rules.farm_workers + 1:
		builders.append(_spawn(sim, 1, TO_PEASANT, 8.5 + i, 9.5))
	var farm := _build(sim, 1, builders, &"to_farm", 10, 5)
	assert_ne(farm, 0)
	assert_gt(_until_done(sim, farm, 3000), 0)
	sim.run(2)
	var on_it := 0
	for id in builders:
		var s := id - 1
		if sim.economy.job[s] == EconomySystem.Job.GATHER and sim.economy.job_ref[s] == farm:
			on_it += 1
	assert_eq(on_it, sim.economy.rules.farm_workers, "as many as the field takes")
	assert_eq(sim.economy.buildings.workers[farm - 1], sim.economy.rules.farm_workers)


## Valentin, 2026-10-27: five peasants, five fields laid one after another with Shift, further
## apart than builders look for the next foundation. As each field is done one of its builders
## stays to work it and the rest go on, so in the end every field is worked.
func test_builders_of_queued_fields_leave_one_on_each() -> void:
	var sim := _drawn(60, 14)
	var state := _join(sim, 1, ORDER)
	_place(sim, 1, &"to_town_center", 2, 2)
	state.stock[EconomySystem.WOOD] = 1000
	var builders := PackedInt32Array()
	for i in 5:
		builders.append(_spawn(sim, 1, TO_PEASANT, 8.5 + i, 11.5))
	var farms: Array[int] = []
	for i in 5:
		var farm := sim.economy.buildings.next_id
		var x := _cell(6 + 10 * i)
		sim.enqueue(SimCommand.build(sim.tick, 1, builders, &"to_farm", x, _cell(6), false, true))
		sim.step()
		assert_true(sim.economy.buildings.is_alive(farm))
		farms.append(farm)
	for id in builders:
		assert_eq(sim.economy.job_ref[id - 1], farms[0], "the first field first")
	for farm in farms:
		assert_gte(_until_done(sim, farm, 9000), 0)
	sim.run(2)
	for farm in farms:
		assert_eq(sim.economy.buildings.workers[farm - 1], 1, "field %d is worked" % farm)
	for id in builders:
		assert_eq(sim.economy.job[id - 1], EconomySystem.Job.GATHER, "peasant %d works" % id)
	assert_true(sim.economy.construction.queue.is_empty())


## Without Shift a new foundation takes the builders off the one they were building.
func test_a_build_order_without_shift_takes_the_builders_over() -> void:
	var sim := _drawn(40, 14)
	var state := _join(sim, 1, ORDER)
	state.stock[EconomySystem.WOOD] = 1000
	var p := _spawn(sim, 1, TO_PEASANT, 8.5, 11.5)
	var first := _build(sim, 1, _ids(p), &"to_farm", 6, 6)
	var second := _build(sim, 1, _ids(p), &"to_farm", 16, 6)
	assert_eq(sim.economy.job_ref[p - 1], second)
	assert_false(sim.economy.construction.queue.has(p - 1))
	assert_ne(first, second)


func test_wood_is_cut_from_the_side_nearest_the_lumber_yard() -> void:
	var sim := _drawn(30, 10, _fill({}, 12, 2, 20, 7, "f"))
	_join(sim, 1, GDL)
	_place(sim, 1, &"gdl_lumber_yard", 4, 4)
	var p := _spawn(sim, 1, PEASANT, 10.5, 8.5)
	# A click two cells into the wood: the peasant takes the edge facing the yard.
	sim.enqueue(SimCommand.gather_at(sim.tick, 1, _ids(p), _cell(14), _cell(4)))
	sim.step()
	assert_eq(sim.economy.job_ref[p - 1] % 30, 12, "the near edge of the wood")
	# Felled: the next tree is again the one nearest the yard.
	var first := sim.economy.job_ref[p - 1]
	sim.economy.nodes.wood[first] = 1
	sim.run(400)
	assert_eq(sim.economy.nodes.wood[first], 0)
	assert_eq(sim.economy.job_ref[p - 1] % 30, 12, "still the near edge")
