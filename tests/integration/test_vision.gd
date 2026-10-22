extends EconomyTest
## M6: fog of war. Unexplored, explored and visible cells; the forest hides units from farther
## than 2 cells; a hill gives +2 sight; buildings see around them; units pick fights only with
## enemies their side sees; the AI's filter shows nothing from the fog.


func _cell_index(sim: Simulation, x: int, y: int) -> int:
	return sim.nav.cell_at(x, y)


func test_cells_are_unexplored_then_visible_then_explored() -> void:
	var sim := _open(60, 20)
	var far_cell := _cell_index(sim, 40, 10)
	assert_eq(sim.vision.state(1, far_cell), VisionSystem.State.UNEXPLORED)
	var scout := _spawn(sim, 1, SPEARMAN, 10.5, 10.5)
	var sight := _rules.sight_default
	assert_eq(sim.vision.state(1, _cell_index(sim, 10 + sight, 10)), VisionSystem.State.VISIBLE)
	assert_eq(
		sim.vision.state(1, _cell_index(sim, 10 + sight + 1, 10)), VisionSystem.State.UNEXPLORED
	)
	assert_eq(sim.vision.state(2, _cell_index(sim, 10, 10)), VisionSystem.State.UNEXPLORED)
	sim.enqueue(SimCommand.move(sim.tick, 1, _ids(scout), _at(40.5), _at(10.5), 0))
	sim.run(800)
	assert_eq(sim.vision.state(1, far_cell), VisionSystem.State.VISIBLE)
	assert_eq(sim.vision.state(1, _cell_index(sim, 10, 10)), VisionSystem.State.EXPLORED)


func test_unit_in_forest_is_not_seen_from_more_than_two_cells() -> void:
	var sim := _drawn(40, 20, _fill({}, 18, 0, 24, 19, "f"))
	var watcher := _spawn(sim, 1, SPEARMAN, 15.5, 10.5)
	_passive(sim, watcher)
	var hidden := _spawn(sim, 2, KNECHT, 19.5, 10.5)
	_passive(sim, hidden)
	var cell := _cell_index(sim, 19, 10)
	assert_true(sim.vision.sees_cell(1, cell), "the forest itself is in sight")
	assert_false(sim.vision.sees_unit(1, hidden), "4 cells away: hidden by the forest")
	sim.enqueue(SimCommand.move(sim.tick, 1, _ids(watcher), _at(16.5), _at(10.5), 0))
	sim.run(40)
	assert_false(sim.vision.sees_unit(1, hidden), "3 cells away: still hidden")
	sim.enqueue(SimCommand.move(sim.tick, 1, _ids(watcher), _at(17.5), _at(10.5), 0))
	sim.run(40)
	assert_true(sim.vision.sees_unit(1, hidden), "2 cells away: seen")
	assert_true(sim.vision.sees_unit(2, watcher), "the one in the forest sees out")


func test_unit_on_open_ground_is_seen_within_sight() -> void:
	var sim := _open(40, 20)
	_spawn(sim, 1, SPEARMAN, 10.5, 10.5)
	var enemy := _spawn(sim, 2, KNECHT, 10.5 + _rules.sight_default, 10.5)
	assert_true(sim.vision.sees_unit(1, enemy))
	var away := _spawn(sim, 2, KNECHT, 11.5 + _rules.sight_default, 10.5)
	assert_false(sim.vision.sees_unit(1, away))


func test_hill_gives_two_more_cells_of_sight() -> void:
	var sim := _drawn(40, 20, {Vector2i(10, 10): "h"})
	var unit := _spawn(sim, 1, SPEARMAN, 10.5, 10.5)
	var r := _rules.sight_default + _db.vision.hill_sight_bonus
	assert_eq(_db.vision.hill_sight_bonus, 2, "t_hill «+2 обзора»")
	assert_true(sim.vision.sees_cell(1, _cell_index(sim, 10 + r, 10)))
	assert_false(sim.vision.sees_cell(1, _cell_index(sim, 11 + r, 10)))
	sim.enqueue(SimCommand.move(sim.tick, 1, _ids(unit), _at(7.5), _at(10.5), 0))
	sim.run(60)
	assert_false(sim.vision.sees_cell(1, _cell_index(sim, 10 + r, 10)), "off the hill")


func test_light_horse_sees_its_obzor() -> void:
	var sim := _open(40, 20)
	_spawn(sim, 1, LIGHT_HORSE, 10.5, 10.5)
	var sight := _db.unit(LIGHT_HORSE).param(&"sight")
	assert_eq(sight, 8, "«обзор 8»")
	assert_true(sim.vision.sees_cell(1, _cell_index(sim, 18, 10)))
	assert_false(sim.vision.sees_cell(1, _cell_index(sim, 19, 10)))


func test_stamps_follow_moves_and_deaths() -> void:
	var sim := _open(60, 30)
	var ids := PackedInt32Array()
	for i in 6:
		ids.append(_spawn(sim, 1, LIGHT_HORSE, 5.5 + i, 5.5))
	sim.enqueue(SimCommand.move(sim.tick, 1, ids, _at(50.5), _at(25.5), 0))
	sim.run(200)
	sim.enqueue(SimCommand.remove(sim.tick, 1, PackedInt32Array([ids[0], ids[1]])))
	sim.run(100)
	# The counts must equal a fresh stamp of where the survivors stand now.
	var fresh := VisionSystem.new(sim.entities, sim.nav, _db, sim.economy)
	for id in sim.entities.alive_ids:
		fresh.on_spawn(id, _db.unit(sim.entities.type_ids[id - 1]))
	fresh.step()
	assert_eq(sim.vision.grids[1].far, fresh.grids[1].far)
	assert_eq(sim.vision.grids[1].near, fresh.grids[1].near)


func test_buildings_see_around_them_and_watch_adds_to_walls() -> void:
	var sim := _open(60, 40)
	var state := _join(sim, 1, GDL)
	var center := _place(sim, 1, &"gdl_town_center", 10, 10)
	assert_ne(center, BuildingStore.NO_ID)
	var sight := _db.building(&"gdl_town_center").param(&"sight")
	assert_eq(sight, 8)
	# 4×4 from (10, 10): the centre cell is (12, 12), radius sight + 2.
	assert_true(sim.vision.sees_cell(1, _cell_index(sim, 12 + sight + 2, 12)))
	assert_false(sim.vision.sees_cell(1, _cell_index(sim, 12 + sight + 3, 12)))
	var wall := _place(sim, 1, &"gdl_palisade", 40, 30)
	var wall_sight := sim.vision.building_sight(wall)
	state.wall_sight_bonus += 2
	sim.step()
	assert_eq(sim.vision.building_sight(wall), wall_sight + 2, "«Караулы»: +2 to walls")
	assert_eq(sim.vision.building_sight(center), sight, "not to the centre")
	assert_true(sim.vision.sees_cell(1, _cell_index(sim, 40 + wall_sight + 2, 30)))


func test_units_do_not_attack_what_their_side_cannot_see() -> void:
	var sim := _drawn(40, 20, _fill({}, 18, 0, 24, 19, "f"))
	var spear := _spawn(sim, 1, SPEARMAN, 14.5, 10.5)
	var hidden := _spawn(sim, 2, KNECHT, 19.5, 10.5)
	_passive(sim, hidden)
	sim.run(60)
	assert_eq(sim.entities.target[spear - 1], EntityStore.NO_ID, "hidden in the forest")
	var open := _spawn(sim, 2, KNECHT, 14.5, 15.5)
	_passive(sim, open)
	sim.run(20)
	assert_eq(sim.entities.target[spear - 1], open, "the one in the open is attacked")


func test_ai_filter_sees_nothing_in_the_fog() -> void:
	var sim := _drawn(60, 20, _fill({}, 30, 0, 34, 19, "f"))
	var own := _spawn(sim, 2, KNECHT, 50.5, 10.5)
	var near := _spawn(sim, 1, SPEARMAN, 45.5, 10.5)
	var far := _spawn(sim, 1, SPEARMAN, 5.5, 10.5)
	var in_forest := _spawn(sim, 1, SPEARMAN, 32.5, 10.5)
	var seen := sim.vision.visible_units(2)
	assert_true(seen.has(own))
	assert_true(seen.has(near))
	assert_false(seen.has(far), "out of sight")
	assert_false(seen.has(in_forest), "in sight but in the forest")


func test_vision_state_is_in_the_hash_and_deterministic() -> void:
	var a := _open(40, 20)
	var b := _open(40, 20)
	for sim: Simulation in [a, b]:
		var id := _spawn(sim, 1, LIGHT_HORSE, 5.5, 5.5)
		sim.enqueue(SimCommand.move(sim.tick, 1, _ids(id), _at(35.5), _at(15.5), 0))
		sim.run(200)
	assert_eq(a.state_hash(), b.state_hash())
	var before := a.state_hash()
	a.vision.grids[1].explored[0] = 1 - a.vision.grids[1].explored[0]
	assert_ne(a.state_hash(), before)


## Field battles (setup.known_map): the ground is known from the start, grey over the whole map,
## and enemy units are still seen only in sight. Missions about scouting keep the black fog.
func test_known_map_missions_start_explored() -> void:
	var db := CatalogDB.load_prototype()
	for mission: String in ["gdl_02", "gdl_05", "crown_01", "crown_06"]:
		var sim := MissionSetup.new_simulation(mission, 1, db, "normal")
		sim.run(1)
		var p := sim.mission.def.player
		var far := sim.nav.cell_at(sim.nav.width - 1, 0)
		var states: Array[int] = [sim.vision.state(p, 0), sim.vision.state(p, far)]
		for st: int in states:
			assert_ne(st, VisionSystem.State.UNEXPLORED, "%s: the whole map is explored" % mission)
		var hostile := 0
		var unseen := 0
		for id in sim.entities.alive_ids:
			var owner := sim.entities.owners[id - 1]
			if owner > 0 and sim.sides.hostile(owner, p):
				hostile += 1
				if not sim.vision.sees_unit(p, id):
					unseen += 1
		# Корона 6 brings the Order onto the field later.
		if hostile > 0:
			assert_gt(unseen, 0, "%s: enemies out of sight stay hidden" % mission)
	var dark := MissionSetup.new_simulation("gdl_03", 1, db, "normal")
	dark.run(1)
	var corner := dark.nav.cell_at(dark.nav.width - 1, 0)
	assert_eq(dark.vision.state(1, corner), VisionSystem.State.UNEXPLORED, "gdl_03 keeps black fog")
