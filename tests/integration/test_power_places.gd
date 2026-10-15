extends MagicTest
## M7: places of power and Сила. Capture takes 15 s and starts over when an enemy comes near;
## shrines go only on a held site; Сила comes in at the shrine's rate times the place's, halved
## by the Order's consecration, up to 500.

# --- capture ---------------------------------------------------------------------------------


func test_capture_takes_fifteen_seconds_with_nobody_else_near() -> void:
	var sim := _world()
	var rules := _db.magic
	assert_eq(rules.capture_ticks, 300, "plan M7: 15 seconds")
	var places := sim.magic.places
	_spawn(sim, 1, SPEARMAN, 11.5, 12.5)
	sim.run(rules.capture_ticks - 2)
	assert_eq(places.holders[0], 0, "not yet")
	assert_eq(places.takers[0], 1)
	sim.run(2)
	assert_eq(places.holders[0], 1, "held after 15 s")
	assert_eq(places.progress[0], 0)


func test_capture_is_interrupted_by_an_enemy() -> void:
	var sim := _world()
	var places := sim.magic.places
	var own := _spawn(sim, 1, SPEARMAN, 11.5, 12.5)
	_passive(sim, own)
	sim.run(200)
	assert_gt(places.progress[0], 150)
	var enemy := _spawn(sim, 2, KNECHT, 13.5, 11.5)
	_passive(sim, enemy)
	assert_eq(places.progress[0], 0, "an enemy in the radius starts it over")
	sim.run(400)
	assert_eq(places.holders[0], 0, "nobody takes it while both stand there")
	sim.enqueue(SimCommand.remove(sim.tick, 2, _ids(enemy)))
	sim.run(_db.magic.capture_ticks - 5)
	assert_eq(places.holders[0], 0, "the full 15 s again after the enemy left")
	sim.run(10)
	assert_eq(places.holders[0], 1)


func test_units_outside_the_radius_do_not_count() -> void:
	var sim := _world()
	var r := _db.magic.capture_radius
	_spawn(sim, 1, SPEARMAN, 11.5 + r + 1, 11.5)
	sim.run(_db.magic.capture_ticks + 10)
	assert_eq(sim.magic.places.holders[0], 0)


func test_held_site_is_taken_by_the_other_side() -> void:
	var sim := _world()
	var places := sim.magic.places
	places.holders[0] = 1
	var enemy := _spawn(sim, 2, KNECHT, 11.5, 12.5)
	_passive(sim, enemy)
	sim.run(_db.magic.capture_ticks + 2)
	assert_eq(places.holders[0], 2)


# --- shrines ----------------------------------------------------------------------------------


func test_shrine_only_on_a_held_free_site() -> void:
	var sim := _world()
	var eco := sim.economy
	var alka := _db.building(ALKA)
	assert_eq(
		eco.placement.can_place(1, alka, SITE.x, SITE.y, false), EconomySystem.Fail.POWER_PLACE
	)
	sim.magic.places.holders[0] = 1
	assert_eq(eco.placement.can_place(1, alka, SITE.x, SITE.y, false), EconomySystem.Fail.OK)
	assert_eq(
		eco.placement.can_place(1, alka, SITE.x + 1, SITE.y, false),
		EconomySystem.Fail.POWER_PLACE,
		"only on the site itself"
	)
	assert_eq(
		eco.placement.can_place(2, _db.building(CHAPEL), SITE.x, SITE.y, false),
		EconomySystem.Fail.POWER_PLACE,
		"not on the other side's site"
	)
	var house := _db.building(&"gdl_house")
	assert_eq(
		eco.placement.can_place(1, house, SITE.x - 1, SITE.y - 1, false),
		EconomySystem.Fail.OCCUPIED,
		"nothing else covers a site"
	)
	var peasant := _spawn(sim, 1, PEASANT, 8.5, 8.5)
	var b := _build(sim, 1, _ids(peasant), ALKA, SITE.x, SITE.y)
	assert_ne(b, BuildingStore.NO_ID, "peasants lay the alka")
	sim.step()
	assert_eq(sim.magic.places.shrines[0], b)
	assert_eq(
		eco.placement.can_place(1, alka, SITE.x, SITE.y, false),
		EconomySystem.Fail.POWER_PLACE,
		"one shrine per site"
	)


func test_destroyed_shrine_frees_the_site() -> void:
	var sim := _world()
	var b := _place(sim, 1, ALKA, SITE.x, SITE.y)
	sim.step()
	var places := sim.magic.places
	assert_eq(places.holders[0], 1, "the shrine's owner holds the site")
	var enemy := _spawn(sim, 2, KNECHT, 11.5, 12.5)
	_passive(sim, enemy)
	sim.run(_db.magic.capture_ticks + 5)
	assert_eq(places.holders[0], 1, "no capture while the shrine stands")
	sim.economy.destroy(b)
	sim.run(_db.magic.capture_ticks + 5)
	assert_eq(places.shrines[0], BuildingStore.NO_ID)
	assert_eq(places.holders[0], 2, "taken once the shrine is down")


# --- Сила -------------------------------------------------------------------------------------


func test_alka_gives_its_rate_times_the_place() -> void:
	var sim := _world(&"pp_oak_grove")
	_place(sim, 1, ALKA, SITE.x, SITE.y)
	sim.step()
	var before := _power(sim, 1)
	sim.run(200)
	# 0,6 a second × 1,2 for the oak grove, 10 seconds: 7,2 points.
	assert_eq(_power(sim, 1) - before, 7200 * Fixed.TICKS_PER_SECOND)
	assert_eq(sim.economy.player(1).power_points(), 7)


func test_chapel_gives_its_rate() -> void:
	var sim := _world(&"pp_spring")
	_place(sim, 2, CHAPEL, SITE.x, SITE.y)
	sim.step()
	var before := _power(sim, 2)
	sim.run(200)
	assert_eq(_power(sim, 2) - before, 3 * MagicSystem.POWER_UNIT, "0,3 a second")


func test_consecration_halves_alka_near_a_chapel_or_priest() -> void:
	var sim := _world(&"pp_spring", 60, 30)
	var r := _db.spell(&"sp_consecration").radius
	assert_eq(r, 6)
	var site2 := sim.magic.places.add(_db.power_places[&"pp_spring"], sim.nav.cell_at(16, 10))
	_place(sim, 1, ALKA, SITE.x, SITE.y)
	_place(sim, 2, CHAPEL, 16, 10)
	sim.run(PowerPlaces.CONSECRATION_EVERY)
	assert_eq(sim.magic.places.holders[site2], 2)
	assert_eq(sim.magic.places.consecrated[0], 1, "the chapel is 6 cells from the alka")
	assert_eq(sim.magic.places.consecrated[site2], 0, "own shrines are not consecrated")
	var before := _power(sim, 1)
	sim.run(200)
	assert_eq(_power(sim, 1) - before, 3 * MagicSystem.POWER_UNIT, "half of 6 points")
	sim.economy.destroy(sim.magic.places.shrines[site2])
	sim.run(PowerPlaces.CONSECRATION_EVERY)
	before = _power(sim, 1)
	sim.run(200)
	assert_eq(_power(sim, 1) - before, 6 * MagicSystem.POWER_UNIT, "full without the chapel")
	var priest := _spawn(sim, 2, PRIEST, 11.0 + r - 0.5, 11.0)
	_passive(sim, priest)
	sim.run(PowerPlaces.CONSECRATION_EVERY)
	before = _power(sim, 1)
	sim.run(200)
	assert_eq(_power(sim, 1) - before, 3 * MagicSystem.POWER_UNIT, "a brother-priest in reach")
	sim.enqueue(SimCommand.move(sim.tick, 2, _ids(priest), _at(11.0 + r + 3), _at(11.0)))
	sim.run(200)
	before = _power(sim, 1)
	sim.run(200)
	assert_eq(_power(sim, 1) - before, 6 * MagicSystem.POWER_UNIT, "the priest walked away")


func test_power_stops_at_the_cap() -> void:
	var sim := _world()
	_place(sim, 1, ALKA, SITE.x, SITE.y)
	_give_power(sim, 1, _db.magic.power_cap - 1)
	sim.run(100)
	assert_eq(sim.economy.player(1).power_points(), 500)
	assert_eq(_power(sim, 1), 500 * MagicSystem.POWER_UNIT)


func test_samogitia_has_five_places_of_power_each_fit_for_a_shrine() -> void:
	var grid := MapText.load_map("map_proto_samogitia", _db)
	var sim := Simulation.new(1, _db, 0, 0, grid)
	var places := sim.magic.places
	assert_eq(places.count(), 5)
	sim.enqueue(SimCommand.join(0, 1, GDL))
	sim.enqueue(SimCommand.join(0, 2, ORDER))
	sim.step()
	for i in places.count():
		var cx := places.cells[i] % grid.width
		var cy := places.cells[i] / grid.width
		for p: int in [1, 2]:
			places.holders[i] = p
			var shrine := _db.building(ALKA if p == 1 else CHAPEL)
			assert_eq(
				sim.economy.placement.can_place(p, shrine, cx, cy, false),
				EconomySystem.Fail.OK,
				"site %d (%d, %d) for player %d" % [i, cx, cy, p]
			)
	assert_eq(places.defs[0].id, &"pp_oak_grove", "the grove in the middle")
