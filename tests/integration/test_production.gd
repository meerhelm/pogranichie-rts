extends EconomyTest
## M5: training within the population limit, queues, prices, ages and techs, buildings under
## attack, and economy commands in replays.

# --- training, limits, research ------------------------------------------------------------


func test_cannot_train_over_the_population_limit() -> void:
	var sim := _open(30, 20)
	var state := _join(sim, 1, GDL)
	var tc := _place(sim, 1, &"gdl_town_center", 5, 5)
	var cap := _db.building(&"gdl_town_center").pop_provided
	assert_eq(sim.economy.pop_cap(1), cap)
	for i in cap:
		_spawn(sim, 1, PEASANT, 12.5, 3.5 + i)
	var peasant := _db.unit(PEASANT)
	var food := _stock(sim, 1, EconomySystem.FOOD)
	sim.enqueue(SimCommand.queue_item(sim.tick, 1, tc, PEASANT))
	sim.run(peasant.train_ticks * 2)
	assert_eq(_stock(sim, 1, EconomySystem.FOOD), food - peasant.cost_food, "queued and paid")
	assert_eq(_units_of(sim, 1, PEASANT), cap, "nobody over the limit")
	assert_eq(state.pop_used(), cap)
	_place(sim, 1, &"gdl_house", 15, 5)
	sim.run(peasant.train_ticks + 2)
	assert_eq(_units_of(sim, 1, PEASANT), cap + 1, "a house makes room")


func test_the_limit_never_goes_above_two_hundred() -> void:
	var sim := _open(30, 20)
	var state := _join(sim, 1, GDL)
	var tc := _place(sim, 1, &"gdl_town_center", 5, 5)
	state.pop_provided = 1000
	assert_eq(sim.economy.pop_cap(1), _db.economy.pop_cap)
	# As if 199 were alive already: one more comes out, the next waits.
	state.pop_units += _db.economy.pop_cap - 1
	state.stock[EconomySystem.FOOD] = 1000
	sim.enqueue(SimCommand.queue_item(sim.tick, 1, tc, PEASANT))
	sim.enqueue(SimCommand.queue_item(sim.tick, 1, tc, PEASANT))
	sim.run(_db.unit(PEASANT).train_ticks * 3)
	assert_eq(_units_of(sim, 1, PEASANT), 1)
	assert_eq(state.pop_used(), _db.economy.pop_cap)
	assert_eq(sim.economy.buildings.queues[tc - 1].size(), 1, "the second waits for room")


func test_trained_units_walk_to_the_rally_point() -> void:
	var sim := _open(30, 20)
	_join(sim, 1, GDL)
	var tc := _place(sim, 1, &"gdl_town_center", 5, 5)
	_place(sim, 1, &"gdl_house", 15, 5)
	sim.enqueue(
		SimCommand.building_rally(sim.tick, 1, PackedInt32Array([tc]), _at(20.5), _at(15.5))
	)
	sim.enqueue(SimCommand.queue_item(sim.tick, 1, tc, PEASANT))
	sim.run(_db.unit(PEASANT).train_ticks + 600)
	var id := sim.entities.next_id - 1
	assert_eq(sim.entities.type_ids[id - 1], PEASANT)
	assert_almost_eq(sim.entities.pos_x[id - 1], _at(20.5), Fixed.ONE)
	assert_almost_eq(sim.entities.pos_y[id - 1], _at(15.5), Fixed.ONE)


func test_cancel_gives_the_price_back() -> void:
	var sim := _open(30, 20)
	var state := _join(sim, 1, GDL)
	var tc := _place(sim, 1, &"gdl_town_center", 5, 5)
	var food := _stock(sim, 1, EconomySystem.FOOD)
	sim.enqueue(SimCommand.queue_item(sim.tick, 1, tc, PEASANT))
	sim.run(10)
	assert_eq(state.pop_training, 1)
	sim.enqueue(SimCommand.cancel_item(sim.tick, 1, tc, 0))
	sim.step()
	assert_eq(_stock(sim, 1, EconomySystem.FOOD), food)
	assert_eq(state.pop_training, 0)
	assert_true(sim.economy.buildings.queues[tc - 1].is_empty())


func test_queue_is_limited_and_needs_resources() -> void:
	var sim := _open(30, 20)
	var state := _join(sim, 1, GDL)
	var tc := _place(sim, 1, &"gdl_town_center", 5, 5)
	state.stock[EconomySystem.FOOD] = 100000
	for i in _db.economy.queue_max:
		assert_eq(sim.economy.production.enqueue(1, tc, PEASANT), EconomySystem.Fail.OK)
	assert_eq(sim.economy.production.enqueue(1, tc, PEASANT), EconomySystem.Fail.QUEUE_FULL)
	state.stock[EconomySystem.FOOD] = 0
	sim.economy.production.cancel(1, tc, 4)
	state.stock[EconomySystem.FOOD] = 0
	assert_eq(sim.economy.production.enqueue(1, tc, PEASANT), EconomySystem.Fail.COST)
	assert_eq(sim.economy.production.enqueue(1, tc, &"gdl_knight"), EconomySystem.Fail.UNKNOWN)


func test_the_order_stable_trains_cavalry_cheaper() -> void:
	var sim := _open(30, 20)
	var state := _join(sim, 2, ORDER)
	var stable := _place(sim, 2, &"to_stable", 5, 5)
	var u := _db.unit(HALFBROTHER)
	var discount := _db.building(&"to_stable").param(&"cavalry_discount_permille")
	assert_gt(discount, 0)
	var cost := sim.economy.production.item_cost(2, stable, HALFBROTHER)
	assert_eq(cost[EconomySystem.FOOD], u.cost_food * (1000 - discount) / 1000)
	assert_eq(cost[EconomySystem.IRON], u.cost_iron * (1000 - discount) / 1000)
	state.stock = PackedInt64Array([1000, 1000, 1000, 1000])
	state.age = 2
	assert_eq(sim.economy.production.enqueue(2, stable, HALFBROTHER), EconomySystem.Fail.OK)
	assert_eq(state.stock[EconomySystem.IRON], 1000 - cost[EconomySystem.IRON])


func test_khorugv_needs_two_buildings_of_the_udel() -> void:
	var sim := _open(40, 30)
	var state := _join(sim, 1, GDL)
	var tc := _place(sim, 1, &"gdl_town_center", 5, 5)
	_place(sim, 1, &"gdl_house", 12, 5)
	_place(sim, 1, &"gdl_house", 15, 5)
	state.stock[EconomySystem.FOOD] = 1000
	var age := _db.age(&"age_khorugv")
	assert_eq(
		sim.economy.production.can_queue(1, tc, age.id),
		EconomySystem.Fail.CONDITION,
		"houses do not count"
	)
	_place(sim, 1, &"gdl_lumber_yard", 12, 10)
	assert_eq(
		sim.economy.production.can_queue(1, tc, age.id), EconomySystem.Fail.CONDITION, "one kind"
	)
	_place(sim, 1, &"gdl_lumber_yard", 15, 10)
	assert_eq(
		sim.economy.production.can_queue(1, tc, age.id), EconomySystem.Fail.CONDITION, "same kind"
	)
	_place(sim, 1, &"gdl_barracks", 20, 10)
	assert_eq(sim.economy.production.can_queue(1, tc, age.id), EconomySystem.Fail.OK)
	sim.enqueue(SimCommand.queue_item(sim.tick, 1, tc, age.id))
	sim.step()
	assert_eq(state.stock[EconomySystem.FOOD], 1000 - age.cost_food)
	sim.run(age.research_ticks)
	assert_eq(state.age, 2, "Хоругвь")
	assert_eq(
		sim.economy.production.can_queue(1, tc, age.id), EconomySystem.Fail.UNKNOWN, "only once"
	)


func test_techs_raise_gathering_and_unit_stats() -> void:
	var sim := _open(40, 30)
	var state := _join(sim, 1, GDL)
	var yard := _place(sim, 1, &"gdl_lumber_yard", 5, 5)
	state.stock = PackedInt64Array([5000, 5000, 5000, 5000])
	sim.enqueue(SimCommand.queue_item(sim.tick, 1, yard, &"t_saw"))
	sim.run(_db.tech(&"t_saw").research_ticks + 2)
	assert_eq(
		state.gather_bonus[ResourceNodes.Source.WOOD], _db.tech(&"t_saw").effects[&"gather_wood"]
	)
	assert_eq(
		sim.economy.production.can_queue(1, yard, &"t_saw"),
		EconomySystem.Fail.CONDITION,
		"researched"
	)
	# Weapons: Хоругвь tech at the smithy, +1 melee for infantry, on units alive and new.
	state.age = 2
	var smithy := _place(sim, 1, &"gdl_smithy", 12, 5)
	var spear := _spawn(sim, 1, SPEARMAN, 20.5, 20.5)
	sim.enqueue(SimCommand.queue_item(sim.tick, 1, smithy, &"t_weapons_1"))
	sim.run(_db.tech(&"t_weapons_1").research_ticks + 2)
	assert_eq(sim.entities.up_damage[spear - 1], 1)
	var later := _spawn(sim, 1, SPEARMAN, 21.5, 20.5)
	assert_eq(sim.entities.up_damage[later - 1], 1)
	var bow := _spawn(sim, 1, &"gdl_forest_archer", 22.5, 20.5)
	assert_eq(sim.entities.up_damage[bow - 1], 0, "archers are not infantry melee")


# --- buildings under attack ----------------------------------------------------------------


func test_soldiers_assault_and_destroy_a_building() -> void:
	var sim := _open(30, 20)
	_join(sim, 1, GDL)
	var house := _place(sim, 1, &"gdl_house", 10, 5)
	var ids := PackedInt32Array()
	for i in 4:
		ids.append(_spawn(sim, 2, KNECHT, 5.5, 4.5 + i))
	var cap := sim.economy.pop_cap(1)
	sim.enqueue(SimCommand.on_building(sim.tick, 2, SimCommand.Kind.ASSAULT, ids, house))
	sim.run(6000)
	assert_false(sim.economy.buildings.is_alive(house), "the house falls")
	assert_eq(sim.economy.pop_cap(1), cap - _db.building(&"gdl_house").pop_provided)
	assert_true(sim.nav.passable(NavGrid.MoveClass.FOOT, sim.nav.cell_at(10, 5)), "cells free")


func test_economy_commands_survive_a_replay_round_trip() -> void:
	var cmds: Array[SimCommand] = [
		SimCommand.join(0, 1, GDL),
		SimCommand.place(0, 1, &"gdl_town_center", 100, 200, true),
		SimCommand.build(1, 1, PackedInt32Array([3, 4]), &"gdl_house", 300, 400),
		SimCommand.wall(
			2, 1, PackedInt32Array([3]), &"gdl_palisade", Vector2i(1, 2), Vector2i(5, 6)
		),
		SimCommand.gather_at(3, 1, PackedInt32Array([3]), 7, 8),
		SimCommand.gather(3, 1, PackedInt32Array([3]), EconomySystem.Target.NODE, 9),
		SimCommand.on_building(4, 1, SimCommand.Kind.WORK, PackedInt32Array([3]), 2),
		SimCommand.queue_item(5, 1, 1, PEASANT),
		SimCommand.cancel_item(6, 1, 1, 2),
		SimCommand.building_rally(7, 1, PackedInt32Array([1]), 10, 11),
	]
	for c in cmds:
		assert_eq(SimCommand.from_dict(c.to_dict()).to_dict(), c.to_dict())
	var w := SimCommand.from_dict(cmds[3].to_dict())
	assert_eq([w.x2, w.y2], [5, 6])
