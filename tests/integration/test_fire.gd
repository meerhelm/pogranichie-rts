extends EconomyTest
## M9 «Поджог»: units set someone else's wooden building on fire, it loses HP over time, the
## fire jumps to wooden buildings next to it, the owner's free units put it out; stone and
## brick do not burn unless a mission makes them wooden.

const HOUSE := &"to_house"
const CASTLE := &"to_castle"


func _world() -> Simulation:
	var sim := _open(40, 30)
	_join(sim, 1, GDL)
	_join(sim, 2, ORDER)
	return sim


func _ignite(sim: Simulation, units: PackedInt32Array, b: int) -> void:
	sim.enqueue(SimCommand.ignite(sim.tick, 1, units, b))
	sim.step()


func test_fire_rules_come_from_the_catalog() -> void:
	var rules := _db.fire
	assert_not_null(rules)
	assert_eq(rules.zaseka_burn_ticks, 400, "catalog «Засека»: сгорает за 20 с")
	assert_gt(rules.burn_ticks, 0)
	assert_gt(rules.douse_ticks, 0)
	assert_true(_db.building(CASTLE).tags.has(&"fireproof"), "the Order's brick castle")
	assert_false(_db.building(HOUSE).tags.has(&"fireproof"))


func test_a_unit_sets_a_house_on_fire_and_it_burns_down() -> void:
	var sim := _world()
	var house := _place(sim, 2, HOUSE, 20, 10)
	var torch := _spawn(sim, 1, SPEARMAN, 14.5, 10.5)
	_ignite(sim, _ids(torch), house)
	assert_true(sim.fire.arson.has(torch))
	var rules := _db.fire
	sim.run(rules.ignite_ticks + 200)
	assert_true(sim.fire.is_burning(house), "lit after working at it")
	var hp := sim.economy.buildings.hp[house - 1]
	sim.run(200)
	assert_lt(sim.economy.buildings.hp[house - 1], hp, "the fire takes HP over time")
	sim.run(rules.burn_ticks)
	assert_false(sim.economy.buildings.is_alive(house), "burnt down within burn_ticks")


func test_stone_does_not_burn_unless_the_mission_makes_it_wooden() -> void:
	var sim := _world()
	var castle := _place(sim, 2, CASTLE, 20, 10)
	assert_ne(castle, BuildingStore.NO_ID)
	assert_false(sim.fire.flammable(castle))
	var torch := _spawn(sim, 1, SPEARMAN, 15.5, 10.5)
	_ignite(sim, _ids(torch), castle)
	assert_false(sim.fire.arson.has(torch), "nobody carries a torch to brick")
	sim.fire.wooden[castle] = true
	assert_true(sim.fire.flammable(castle), "Skirsnemune and Dubysa are wooden castles")


func test_own_buildings_and_animals_cannot_set_fires() -> void:
	var sim := _world()
	var own := _place(sim, 1, &"gdl_house", 20, 10)
	var torch := _spawn(sim, 1, SPEARMAN, 15.5, 10.5)
	_ignite(sim, _ids(torch), own)
	assert_false(sim.fire.arson.has(torch))
	var elk := _spawn(sim, 0, &"nt_elk", 5.5, 5.5)
	assert_false(sim.fire.can_ignite(elk))


func test_fire_spreads_to_wooden_neighbours_and_not_to_far_ones() -> void:
	var sim := _world()
	var store := sim.economy.buildings
	var first := _place(sim, 2, HOUSE, 10, 10)
	var near := _place(sim, 2, HOUSE, 13, 10)
	var far := _place(sim, 2, HOUSE, 30, 20)
	assert_eq(store.cell_x[near - 1] - store.cell_x[first - 1] - store.w[first - 1], 1)
	sim.fire.ignite(first)
	var caught := false
	for i in _db.fire.burn_ticks:
		sim.step()
		if sim.fire.is_burning(near):
			caught = true
			break
	assert_true(caught, "a house one cell away catches fire")
	assert_false(sim.fire.is_burning(far))


func test_the_owners_free_units_put_a_fire_out() -> void:
	var sim := _world()
	var house := _place(sim, 2, HOUSE, 20, 10)
	var helpers := PackedInt32Array()
	for i in 4:
		var id := _spawn(sim, 2, KNECHT, 17.5 + i, 14.5)
		helpers.append(id)
	sim.fire.ignite(house)
	sim.run(_db.fire.douse_ticks / helpers.size() + 300)
	assert_false(sim.fire.is_burning(house), "four knechts douse it")
	assert_true(sim.economy.buildings.is_alive(house))
	assert_true(sim.fire.dousers.is_empty(), "they go back to standing about")


func test_a_new_order_drops_the_torch() -> void:
	var sim := _world()
	var house := _place(sim, 2, HOUSE, 20, 10)
	var torch := _spawn(sim, 1, SPEARMAN, 14.5, 10.5)
	_ignite(sim, _ids(torch), house)
	sim.enqueue(SimCommand.stop(sim.tick, 1, _ids(torch)))
	sim.step()
	assert_false(sim.fire.arson.has(torch))
	sim.run(_db.fire.ignite_ticks + 200)
	assert_false(sim.fire.is_burning(house))


func test_a_hero_with_ignite_ticks_is_quicker() -> void:
	var sim := _world()
	var rumbaudas := _spawn(sim, 1, &"hero_rumbaudas", 5.5, 5.5)
	var spearman := _spawn(sim, 1, SPEARMAN, 6.5, 5.5)
	assert_lt(sim.fire.ignite_ticks_of(rumbaudas), sim.fire.ignite_ticks_of(spearman))
	assert_eq(sim.fire.ignite_ticks_of(spearman), _db.fire.ignite_ticks)


func test_fire_is_part_of_the_state_hash() -> void:
	var a := _world()
	var b := _world()
	var ha := _place(a, 2, HOUSE, 20, 10)
	_place(b, 2, HOUSE, 20, 10)
	assert_eq(a.state_hash(), b.state_hash())
	a.fire.ignite(ha)
	assert_ne(a.state_hash(), b.state_hash())
