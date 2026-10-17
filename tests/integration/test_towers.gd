extends EconomyTest
## Towers that shoot, gates that open only to their owner and are broken by enemies, towers
## and gates put into a palisade line.


func _walled(sim: Simulation, x0: int, y0: int, x1: int, y1: int, gate: Vector2i) -> void:
	# A palisade ring round x0..x1, y0..y1 (the ring cells themselves) with a gate in it.
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if x != x0 and x != x1 and y != y0 and y != y1:
				continue
			var id := &"gdl_gate" if Vector2i(x, y) == gate else &"gdl_palisade"
			assert_ne(_place(sim, 1, id, x, y), 0, "%s at %d,%d" % [id, x, y])


func test_every_faction_has_a_tower_that_shoots() -> void:
	for faction: StringName in [&"gdl", &"pl", &"to", &"mo"]:
		var def := _db.building(StringName("%s_tower" % faction))
		assert_not_null(def, "%s_tower" % faction)
		assert_true(TowerFire.shoots(def), "%s_tower shoots" % faction)
		assert_eq(def.attack_range, 7, "catalog «дальн. 7»")
		assert_gt(def.param(&"reload_ticks"), 0)
		var gate := _db.building(StringName("%s_gate" % faction))
		assert_true(TowerFire.shoots(gate), "%s_gate: one or two archers on it" % faction)
		assert_gt(gate.param(&"reload_ticks"), def.param(&"reload_ticks"), "fewer than a tower")


func test_a_gate_shoots_enemies_near_it() -> void:
	var sim := _open(40, 20)
	_join(sim, 1, GDL)
	_join(sim, 2, ORDER)
	assert_ne(_place(sim, 1, &"gdl_gate", 10, 10), 0)
	var enemy := _spawn(sim, 2, KNECHT, 14.5, 10.5)
	_passive(sim, enemy)
	sim.run(200)
	assert_lt(sim.entities.hp[enemy - 1], sim.entities.max_hp[enemy - 1])


func test_a_tower_shoots_enemies_in_range_and_spares_its_own() -> void:
	var sim := _open(40, 20)
	_join(sim, 1, GDL)
	_join(sim, 2, ORDER)
	assert_ne(_place(sim, 1, &"gdl_tower", 10, 10), 0)
	var near := _spawn(sim, 2, KNECHT, 15.5, 10.5)
	var far := _spawn(sim, 2, KNECHT, 30.5, 10.5)
	var own := _spawn(sim, 1, SPEARMAN, 13.5, 10.5)
	for id: int in [near, far, own]:
		_passive(sim, id)
	var hp := sim.entities.hp[near - 1]
	sim.run(200)
	assert_lt(sim.entities.hp[near - 1], hp, "the enemy in range is hit")
	assert_eq(sim.entities.hp[far - 1], sim.entities.max_hp[far - 1], "out of range")
	assert_eq(sim.entities.hp[own - 1], sim.entities.max_hp[own - 1], "never its own")


func test_a_tower_foundation_does_not_shoot() -> void:
	var sim := _open(40, 20)
	_join(sim, 1, GDL)
	_join(sim, 2, ORDER)
	var peasant := _spawn(sim, 1, PEASANT, 2.5, 2.5)
	var b := _build(sim, 1, _ids(peasant), &"gdl_tower", 10, 10)
	assert_ne(b, 0)
	sim.enqueue(SimCommand.stop(sim.tick, 1, _ids(peasant)))
	var enemy := _spawn(sim, 2, KNECHT, 13.5, 10.5)
	_passive(sim, enemy)
	sim.run(200)
	assert_eq(sim.entities.hp[enemy - 1], sim.entities.max_hp[enemy - 1])


func test_a_gate_opens_paths_to_its_owner_only() -> void:
	var sim := _open(30, 20)
	_join(sim, 1, GDL)
	_walled(sim, 10, 5, 18, 13, Vector2i(10, 9))
	var gate := sim.nav.cell_at(10, 9)
	var outside := sim.nav.cell_at(4, 9)
	var inside := sim.nav.cell_at(14, 9)
	var own := sim.pathfinder.find_path(NavGrid.MoveClass.FOOT, outside, inside, 1)
	assert_true(own.has(gate), "the owner's path goes through the gate")
	assert_eq(own[-1], inside)
	var other := sim.pathfinder.find_path(NavGrid.MoveClass.FOOT, outside, inside, 2)
	assert_false(other.has(gate), "nobody else's does")
	assert_ne(other[-1] if not other.is_empty() else outside, inside, "and cannot get in")


func test_own_units_walk_out_through_the_gate_and_enemies_stay_out() -> void:
	var sim := _open(30, 20)
	_join(sim, 1, GDL)
	_walled(sim, 10, 5, 18, 13, Vector2i(10, 9))
	var own := _spawn(sim, 1, PEASANT, 14.5, 9.5)
	var enemy := _spawn(sim, 2, TO_PEASANT, 4.5, 6.5)
	sim.enqueue(SimCommand.move(sim.tick, 1, _ids(own), _at(3.5), _at(15.5)))
	sim.enqueue(SimCommand.move(sim.tick, 2, _ids(enemy), _at(14.5), _at(9.5)))
	sim.run(600)
	assert_lt(sim.entities.pos_x[own - 1], _at(5.0), "the owner left through the gate")
	var ex := Fixed.to_cells(sim.entities.pos_x[enemy - 1])
	var ey := Fixed.to_cells(sim.entities.pos_y[enemy - 1])
	assert_false(ex > 10 and ex < 18 and ey > 5 and ey < 13, "the enemy is still outside")


func test_enemies_break_in_to_reach_a_building_behind_the_wall() -> void:
	var sim := _open(30, 20)
	_join(sim, 1, GDL)
	_join(sim, 2, ORDER)
	_walled(sim, 10, 5, 18, 13, Vector2i(18, 9))  # the gate, which shoots, on the far side
	var house := _place(sim, 1, &"gdl_house", 13, 8)
	assert_ne(house, 0)
	var ring := sim.economy.buildings.count() - 1
	var knechts := PackedInt32Array()
	for i in 4:
		knechts.append(_spawn(sim, 2, KNECHT, 4.5, 7.5 + i))
	var cmd := SimCommand.on_building(sim.tick, 2, SimCommand.Kind.ASSAULT, knechts, house)
	sim.enqueue(cmd)
	var broken := -1
	for t in 4000:
		sim.step()
		if sim.economy.buildings.count() - 1 < ring:
			broken = t
			break
	assert_gt(broken, 0, "a piece of the ring (the gate or a stake) is broken")
	var hit := false
	for t in 4000:
		sim.step()
		if sim.economy.buildings.hp[house - 1] < sim.economy.buildings.max_hp[house - 1]:
			hit = true
			break
	assert_true(hit, "then they go on at the house through the gap")


func test_a_tower_or_gate_goes_into_an_own_palisade_line() -> void:
	var sim := _open(30, 20)
	_join(sim, 1, GDL)
	_join(sim, 2, GDL)
	for x in range(5, 11):
		_place(sim, 1, &"gdl_palisade", x, 5)
	var eco := sim.economy
	var tower := _db.building(&"gdl_tower")
	assert_eq(eco.placement.can_place(1, tower, 7, 5, false), EconomySystem.Fail.OK)
	assert_eq(
		eco.placement.can_place(2, tower, 7, 5, false),
		EconomySystem.Fail.OCCUPIED,
		"not into someone else's"
	)
	var count := eco.buildings.count()
	var t := _place(sim, 1, &"gdl_tower", 7, 5)
	assert_ne(t, 0)
	assert_eq(eco.buildings.count(), count, "the stake made way for the tower")
	assert_eq(eco.buildings.occupant[sim.nav.cell_at(7, 5)], t)
	assert_eq(sim.nav.blocked[sim.nav.cell_at(7, 5)], 1)
	var g := _place(sim, 1, &"gdl_gate", 9, 5)
	assert_ne(g, 0, "and a gate too")
	assert_eq(
		eco.placement.can_place(1, _db.building(&"gdl_house"), 5, 5, false),
		EconomySystem.Fail.OCCUPIED,
		"other buildings do not"
	)


func test_a_gateway_two_cells_wide_shoots_as_one_gate() -> void:
	var sim := _open(40, 20)
	_join(sim, 1, GDL)
	_join(sim, 2, ORDER)
	var a := _place(sim, 1, &"gdl_gate", 10, 10)
	var b := _place(sim, 1, &"gdl_gate", 10, 11)
	assert_ne(a, 0)
	assert_ne(b, 0)
	_passive(sim, _spawn(sim, 2, KNECHT, 13.5, 10.5))
	sim.run(5)
	var cd := sim.economy.buildings.cooldown
	assert_gt(cd[a - 1], 0, "the first cell shoots")
	assert_eq(cd[b - 1], 0, "the second is the same gateway")
