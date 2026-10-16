extends EconomyTest
## Taking own buildings apart: peasants take it down, 80% of its price is left as salvage that
## only the owner's peasants carry to a building that takes that resource in.


func _dismantle(sim: Simulation, player: int, units: PackedInt32Array, b: int) -> void:
	sim.enqueue(SimCommand.on_building(sim.tick, player, SimCommand.Kind.DISMANTLE, units, b))
	sim.step()


func _peasants(sim: Simulation, player: int, count: int, x: float, y: float) -> PackedInt32Array:
	var ids := PackedInt32Array()
	for i in count:
		ids.append(_spawn(sim, player, PEASANT, x + i, y))
	return ids


## Steps until building b is gone, at most `limit` ticks; the ticks it took, or -1.
func _until_gone(sim: Simulation, b: int, limit: int) -> int:
	for i in limit:
		if not sim.economy.buildings.is_alive(b):
			return i
		sim.step()
	return -1


func _salvage_nodes(sim: Simulation) -> PackedInt32Array:
	var out := PackedInt32Array()
	for n in sim.economy.nodes.alive_ids:
		if ResourceNodes.is_salvage(sim.economy.nodes.sources[n - 1]):
			out.append(n)
	return out


func test_a_town_center_taken_apart_gives_80_percent_carried_to_storage() -> void:
	var sim := _drawn(30, 14)
	var state := _join(sim, 1, GDL)
	assert_ne(_place(sim, 1, &"gdl_town_center", 2, 4), 0)
	var b := _place(sim, 1, &"gdl_town_center", 18, 4)
	assert_ne(b, 0)
	var pop_before := state.pop_provided
	var wood := _stock(sim, 1, EconomySystem.WOOD)
	var iron := _stock(sim, 1, EconomySystem.IRON)
	var give := sim.economy.construction.salvage(b)
	var cost := sim.economy.placement.building_cost(1, sim.economy.buildings.defs[b - 1])
	assert_eq(give[EconomySystem.WOOD], cost[EconomySystem.WOOD] * 8 / 10)
	assert_eq(give[EconomySystem.IRON], cost[EconomySystem.IRON] * 8 / 10)
	var ids := _peasants(sim, 1, 3, 16.5, 9.5)
	_dismantle(sim, 1, ids, b)
	assert_eq(sim.economy.buildings.dismantling[b - 1], 1)
	assert_gt(_until_gone(sim, b, 3000), 0, "taken apart")
	assert_eq(state.buildings_lost, 0, "taking apart is not a loss")
	assert_eq(state.pop_provided, pop_before - 5, "its houses go")
	var piles := _salvage_nodes(sim)
	assert_eq(piles.size(), 2, "a pile of wood and one of iron")
	var total := 0
	for n in piles:
		assert_eq(sim.economy.nodes.owners[n - 1], 1)
		total += sim.economy.nodes.amounts[n - 1]
	assert_eq(total, give[EconomySystem.WOOD] + give[EconomySystem.IRON])
	for id in ids:
		assert_eq(sim.economy.job[id - 1], EconomySystem.Job.GATHER, "on to the piles")
	# Nothing reaches the stock until it is carried to the other town centre.
	assert_eq(_stock(sim, 1, EconomySystem.WOOD), wood)
	for i in 12000:
		if _salvage_nodes(sim).is_empty() and _carried(sim, ids) == 0:
			break
		sim.step()
	assert_eq(_stock(sim, 1, EconomySystem.WOOD), wood + give[EconomySystem.WOOD])
	assert_eq(_stock(sim, 1, EconomySystem.IRON), iron + give[EconomySystem.IRON])


func test_more_peasants_take_it_apart_faster_and_a_foundation_takes_little() -> void:
	var times: Array[int] = []
	for n: int in [1, 3]:
		var sim := _drawn(20, 12)
		_join(sim, 1, GDL)
		var b := _place(sim, 1, &"gdl_house", 10, 4)
		_dismantle(sim, 1, _peasants(sim, 1, n, 8.5, 8.5), b)
		times.append(_until_gone(sim, b, 2000))
	assert_gt(times[0], 0)
	assert_lt(times[1], times[0], "three are faster than one")
	# A foundation nobody worked on comes down at once, still giving back 80%.
	var sim := _drawn(20, 12)
	_join(sim, 1, GDL)
	var ids := _peasants(sim, 1, 1, 8.5, 8.5)
	var house := _build(sim, 1, PackedInt32Array(), &"gdl_house", 10, 4)
	assert_ne(house, 0)
	_dismantle(sim, 1, ids, house)
	assert_gt(_until_gone(sim, house, 400), -1)
	var piles := _salvage_nodes(sim)
	assert_eq(piles.size(), 1)
	assert_eq(sim.economy.nodes.amounts[piles[0] - 1], 30 * 8 / 10)


func test_a_build_order_stops_taking_it_apart() -> void:
	var sim := _drawn(20, 12)
	_join(sim, 1, GDL)
	var b := _place(sim, 1, &"gdl_house", 10, 4)
	var ids := _peasants(sim, 1, 2, 8.5, 8.5)
	_dismantle(sim, 1, ids, b)
	sim.run(60)
	assert_lt(sim.economy.buildings.hp[b - 1], sim.economy.buildings.max_hp[b - 1])
	sim.enqueue(SimCommand.on_building(sim.tick, 1, SimCommand.Kind.WORK, ids, b))
	sim.run(2000)
	assert_true(sim.economy.buildings.is_alive(b), "still standing")
	assert_eq(sim.economy.buildings.dismantling[b - 1], 0)
	assert_eq(sim.economy.buildings.hp[b - 1], sim.economy.buildings.max_hp[b - 1], "repaired")


func test_only_the_owner_takes_apart_and_picks_up_salvage() -> void:
	var sim := _drawn(24, 12)
	_join(sim, 1, GDL)
	_join(sim, 2, ORDER)
	var b := _place(sim, 1, &"gdl_house", 10, 4)
	var theirs := _peasants(sim, 2, 2, 8.5, 9.5)
	_dismantle(sim, 2, theirs, b)
	assert_eq(sim.economy.buildings.dismantling[b - 1], 0, "not theirs to take apart")
	_dismantle(sim, 1, _peasants(sim, 1, 2, 8.5, 8.5), b)
	assert_gt(_until_gone(sim, b, 2000), 0)
	var pile := _salvage_nodes(sim)[0]
	sim.enqueue(SimCommand.gather(sim.tick, 2, theirs, EconomySystem.Target.NODE, pile))
	sim.step()
	for id in theirs:
		assert_eq(sim.economy.job[id - 1], EconomySystem.Job.NONE, "not their salvage")


func test_the_queue_is_cancelled_with_a_refund() -> void:
	var sim := _drawn(30, 12)
	_join(sim, 1, GDL)
	_place(sim, 1, &"gdl_town_center", 20, 4)
	var tc := _place(sim, 1, &"gdl_town_center", 8, 4)
	var food := _stock(sim, 1, EconomySystem.FOOD)
	sim.enqueue(SimCommand.queue_item(sim.tick, 1, tc, PEASANT))
	sim.step()
	assert_lt(_stock(sim, 1, EconomySystem.FOOD), food)
	_dismantle(sim, 1, _peasants(sim, 1, 1, 6.5, 9.5), tc)
	assert_eq(_stock(sim, 1, EconomySystem.FOOD), food, "paid back")
	assert_true(sim.economy.buildings.queues[tc - 1].is_empty())
	assert_eq(sim.economy.production.can_queue(1, tc, PEASANT), EconomySystem.Fail.DISMANTLING)


func _carried(sim: Simulation, ids: PackedInt32Array) -> int:
	var n := 0
	for id in ids:
		n += sim.economy.carry[id - 1]
	return n


func test_the_last_capital_cannot_be_taken_apart() -> void:
	var sim := _drawn(30, 14)
	_join(sim, 1, GDL)
	var a := _place(sim, 1, &"gdl_town_center", 2, 4)
	var b := _place(sim, 1, &"gdl_town_center", 18, 4)
	_dismantle(sim, 1, _peasants(sim, 1, 3, 16.5, 9.5), b)
	assert_gt(_until_gone(sim, b, 3000), 0, "one of two may go")
	assert_true(sim.economy.construction.is_last_capital(a))
	assert_false(sim.economy.construction.can_dismantle(1, a))
	_dismantle(sim, 1, _peasants(sim, 1, 2, 6.5, 9.5), a)
	assert_eq(sim.economy.buildings.dismantling[a - 1], 0, "the last one stays")
