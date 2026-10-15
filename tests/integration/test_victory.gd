extends MagicTest
## M8: how a skirmish ends (concept doc «Победа в схватке»): a side whose capital and castles
## are all gone is out and the last side standing wins; holding every place of power for five
## minutes wins at once. And the statistics the end screen shows.


## Both sides joined on a grass map with one place of power, each with a finished town centre.
func _skirmish() -> Simulation:
	var sim := _world(&"pp_spring", 60, 30)
	_place(sim, 1, &"gdl_town_center", 2, 2)
	_place(sim, 2, &"to_town_center", 50, 20)
	return sim


func _capital(sim: Simulation, player: int) -> int:
	var store := sim.economy.buildings
	for b in store.alive_ids:
		if store.owners[b - 1] == player and store.defs[b - 1].base_id == &"town_center":
			return b
	return 0


func test_losing_the_capital_loses_the_game() -> void:
	var sim := _skirmish()
	sim.run(5)
	assert_false(sim.victory.is_over())
	sim.economy.destroy(_capital(sim, 2))
	sim.step()
	assert_true(sim.victory.is_over())
	assert_eq(sim.victory.winner, 1)
	assert_eq(sim.victory.reason, SkirmishVictory.Reason.CONQUEST)
	assert_true(sim.victory.is_out(2))
	assert_eq(sim.victory.end_tick, sim.tick - 1)


func test_a_castle_keeps_a_side_in_the_game() -> void:
	var sim := _skirmish()
	var st := sim.economy.player(2)
	st.age = 2
	var castle := _place(sim, 2, &"to_castle", 40, 10)
	assert_ne(castle, 0)
	sim.economy.destroy(_capital(sim, 2))
	sim.run(3)
	assert_false(sim.victory.is_over(), "«столица и замки»: the castle still stands")
	sim.economy.destroy(castle)
	sim.step()
	assert_eq(sim.victory.winner, 1)


func test_destroyed_by_combat_counts_too() -> void:
	var sim := _skirmish()
	var b := _capital(sim, 2)
	sim.economy.hit_building(b, sim.economy.buildings.hp[b - 1])
	sim.step()
	assert_eq(sim.victory.winner, 1)


func test_a_side_that_never_had_a_capital_is_not_out() -> void:
	var sim := _world(&"pp_spring", 60, 30)
	_place(sim, 1, &"gdl_town_center", 2, 2)
	sim.run(20)
	assert_false(sim.victory.is_over(), "player 2 has not set up a town centre yet")
	assert_false(sim.victory.is_out(2))


func test_an_unfinished_capital_does_not_count() -> void:
	var sim := _skirmish()
	sim.economy.player(2).stock = PackedInt64Array([0, 1000, 1000, 0])
	var peasant := _spawn(sim, 2, TO_PEASANT, 30.5, 10.5)
	var foundation := _build(sim, 2, _ids(peasant), &"to_town_center", 30, 6)
	assert_ne(foundation, 0)
	sim.economy.destroy(_capital(sim, 2))
	sim.step()
	assert_eq(sim.victory.winner, 1, "a foundation is not a capital")


func test_holding_every_place_of_power_for_five_minutes_wins() -> void:
	var sim := _skirmish()
	var hold := _db.skirmish.hold_all_places_ticks
	assert_eq(hold, 6000, "5 minutes at 20 ticks a second")
	var places := sim.magic.places
	places.holders[0] = 1
	sim.run(hold - 1)
	assert_false(sim.victory.is_over())
	assert_eq(sim.victory.holder, 1)
	sim.step()
	assert_true(sim.victory.is_over())
	assert_eq(sim.victory.winner, 1)
	assert_eq(sim.victory.reason, SkirmishVictory.Reason.PLACES)


func test_losing_a_place_starts_the_count_over() -> void:
	var sim := _world(&"pp_spring", 60, 30)
	sim.magic.places.add(_db.power_places[&"pp_kurgan"], sim.nav.cell_at(30, 20))
	_place(sim, 1, &"gdl_town_center", 2, 2)
	_place(sim, 2, &"to_town_center", 50, 20)
	var places := sim.magic.places
	places.holders[0] = 1
	places.holders[1] = 1
	sim.run(3000)
	places.holders[1] = 2
	sim.step()
	assert_eq(sim.victory.holder, 0, "one place lost: nobody holds them all")
	assert_eq(sim.victory.held_ticks, 0)
	places.holders[1] = 1
	sim.run(_db.skirmish.hold_all_places_ticks - 1)
	assert_false(sim.victory.is_over(), "the full five minutes again")
	sim.step()
	assert_eq(sim.victory.winner, 1)


func test_a_lone_player_never_wins() -> void:
	var sim := _open(30, 20)
	_join(sim, 1, GDL)
	_place(sim, 1, &"gdl_town_center", 2, 2)
	sim.run(10)
	assert_false(sim.victory.is_over())


func test_victory_is_part_of_the_state_hash() -> void:
	var a := _skirmish()
	var b := _skirmish()
	assert_eq(a.state_hash(), b.state_hash())
	b.magic.places.holders[0] = 1
	a.magic.places.holders[0] = 1
	a.step()
	b.step()
	b.victory.held_ticks += 1
	assert_ne(a.state_hash(), b.state_hash())


# --- statistics ---------------------------------------------------------------------------------


func test_units_killed_and_lost_are_counted() -> void:
	var sim := _skirmish()
	var knight := _spawn(sim, 2, KNIGHT, 20.5, 10.5)
	var peasant := _spawn(sim, 1, PEASANT, 21.5, 10.5)
	sim.enqueue(SimCommand.attack(sim.tick, 2, _ids(knight), peasant))
	for i in 600:
		if not sim.entities.is_alive(peasant):
			break
		sim.step()
	assert_false(sim.entities.is_alive(peasant))
	assert_eq(sim.economy.player(2).killed, 1)
	assert_eq(sim.economy.player(1).lost, 1)
	assert_eq(sim.economy.player(1).killed, 0)
	assert_eq(sim.economy.player(2).lost, 0)


func test_trained_built_gathered_and_buildings_lost_are_counted() -> void:
	var sim := _skirmish()
	var st := sim.economy.player(1)
	var center := _capital(sim, 1)
	sim.enqueue(SimCommand.queue_item(sim.tick, 1, center, PEASANT))
	sim.run(_db.unit(PEASANT).train_ticks + 5)
	assert_eq(st.trained, 1, "one peasant out of the town centre")
	assert_eq(st.built, 0, "a town centre placed at setup was not built")
	var peasant := sim.entities.next_id - 1
	var house := _build(sim, 1, _ids(peasant), &"gdl_house", 10, 2)
	assert_ne(_until_done(sim, house, 4000), -1)
	assert_eq(st.built, 1)
	var cells := {}
	_fill(cells, 12, 8, 14, 10, "f")
	var forest := _drawn(30, 20, cells)
	_join(forest, 1, GDL)
	_place(forest, 1, &"gdl_town_center", 2, 2)
	var cutter := _spawn(forest, 1, PEASANT, 11.5, 9.5)
	forest.enqueue(SimCommand.gather_at(forest.tick, 1, _ids(cutter), _at(12.5), _at(9.5)))
	forest.run(1200)
	var fst := forest.economy.player(1)
	assert_gt(fst.gathered[EconomySystem.WOOD], 0)
	assert_eq(fst.gathered[EconomySystem.WOOD], fst.stock[EconomySystem.WOOD] - 200, "all of it")
	sim.economy.destroy(house)
	assert_eq(st.buildings_lost, 1)
