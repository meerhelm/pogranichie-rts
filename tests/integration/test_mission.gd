# gdlint:ignore = max-public-methods
extends GutTest
## M9 acceptance: «ВКЛ 1. Жемайтский огонь», phases 1-3. One test per trigger of the mission
## card (1.1-3.5) and per extra one (optional objectives, boats, convoy, defeats, the end): the
## world is put into the trigger's condition and the trigger's events are checked. Earlier
## triggers a test does not need are marked as fired by hand.

const MISSION := "gdl_01"
const P := 1
const ORDER := 2
const CHECK := MissionRuntime.CHECK_EVERY

var _db: CatalogDB


func before_all() -> void:
	_db = CatalogDB.load_prototype()


func _sim(difficulty: String = "normal") -> Simulation:
	var sim := MissionSetup.new_simulation(MISSION, 1, _db, difficulty)
	assert_not_null(sim)
	return sim


## Marks triggers as fired without running them.
func _skip(sim: Simulation, ids: Array[String]) -> void:
	for tid in ids:
		sim.mission.fired[tid] = sim.tick


## Runs to the next trigger check and a bit past it.
func _check(sim: Simulation) -> void:
	sim.run(CHECK + 1)


func _kinds(sim: Simulation) -> PackedStringArray:
	var out := PackedStringArray()
	for e: Dictionary in sim.mission.events:
		out.append(e["kind"])
	return out


func _state(sim: Simulation, oid: String) -> int:
	return sim.mission.objective_state.get(oid, -1)


func _food(sim: Simulation) -> int:
	return sim.economy.player(P).stock[EconomySystem.FOOD]


func _set_food(sim: Simulation, amount: int) -> void:
	sim.economy.player(P).stock[EconomySystem.FOOD] = amount


func _put(sim: Simulation, ids: PackedInt32Array, cx: int, cy: int) -> void:
	for id in ids:
		sim.entities.pos_x[id - 1] = Fixed.from_cells(cx) + Fixed.HALF
		sim.entities.pos_y[id - 1] = Fixed.from_cells(cy) + Fixed.HALF
		sim.entities.stop(id)


func _spawn(sim: Simulation, player: int, type: StringName, cx: int, cy: int) -> int:
	return sim.spawn_unit(type, player, Fixed.from_cells(cx) + Fixed.HALF, Fixed.from_cells(cy))


func _place(sim: Simulation, player: int, type: StringName, cx: int, cy: int) -> int:
	var id := sim.economy.buildings.next_id
	var x := Fixed.from_cells(cx) + Fixed.HALF
	var y := Fixed.from_cells(cy) + Fixed.HALF
	sim.apply_now(SimCommand.place(sim.tick, player, type, x, y))
	return id if sim.economy.buildings.is_alive(id) else 0


# --- setup ----------------------------------------------------------------------------------


func test_the_mission_sets_up_the_map_and_both_sides() -> void:
	var sim := _sim()
	var m := sim.mission
	assert_eq(sim.nav.width, 160, "plan M9: map 160×160")
	assert_eq(sim.magic.places.count(), 7, "seven places of power")
	for name: String in ["village_tc", "chapel", "skir_castle", "dub_castle"]:
		assert_true(sim.economy.buildings.is_alive(m.named.get(name, 0)), name)
	assert_true(sim.fire.wooden.has(m.named["skir_castle"]), "Skirsnemune is a wooden castle")
	assert_eq(m.alive_of("gintaut").size(), 1)
	assert_eq(m.alive_of("grove_guard").size(), 11, "priest, 6 knechts, 4 crossbows")
	assert_eq(m.alive_of("skir_garrison").size() + m.alive_of("skir_knights").size(), 27)
	var state := sim.economy.player(P)
	assert_true(state.locked.has(&"gdl_shrine"), "the alka comes with trigger 2.2")
	assert_true(state.locked.has(&"age_khorugv"), "the second age with 3.1")
	assert_false(sim.victory.enabled(), "the mission decides who wins")
	assert_eq(sim.magic.places.consecrated_by.size(), 2, "the two sites by the castles")


func test_the_same_seed_gives_the_same_mission() -> void:
	var a := _sim()
	var b := _sim()
	a.run(300)
	b.run(300)
	assert_eq(a.state_hash(), b.state_hash())


# --- phase 1 --------------------------------------------------------------------------------


func test_1_1_start_cutscene_hints_and_the_food_objective() -> void:
	var sim := _sim()
	sim.step()
	var kinds := _kinds(sim)
	assert_true(sim.mission.fired.has("1.1"))
	assert_true(kinds.has("cutscene"))
	assert_true(kinds.has("hint"))
	assert_true(kinds.has("dialogue"))
	assert_eq(_state(sim, "food"), MissionRuntime.Objective.ACTIVE)


func test_hunger_eats_food_until_1_4() -> void:
	var sim := _sim()
	_set_food(sim, 100)
	sim.run(201)
	assert_lt(_food(sim), 100, "the village eats")
	_skip(sim, ["1.4"])
	var now := _food(sim)
	sim.run(400)
	assert_eq(_food(sim), now, "no more hunger after 1.4")


func test_1_2_the_first_new_house_gives_a_hint() -> void:
	var sim := _sim()
	_check(sim)
	assert_false(sim.mission.fired.has("1.2"), "the houses of the setup do not count")
	assert_ne(_place(sim, P, &"gdl_house", 132, 24), 0)
	_check(sim)
	assert_true(sim.mission.fired.has("1.2"))


func test_1_3_the_tithe_collector_comes_at_150_food() -> void:
	var sim := _sim()
	_check(sim)
	assert_false(sim.mission.fired.has("1.3"))
	_set_food(sim, 160)
	_check(sim)
	var tithe := sim.mission.alive_of("tithe")
	assert_eq(tithe.size(), 5, "the collector and 4 knechts")
	for id in tithe:
		assert_true(sim.combat.untouchable.has(id), "the player cannot attack them")
		assert_eq(sim.entities.stance[id - 1], EntityStore.Stance.PASSIVE)
		assert_eq(sim.entities.orders[id - 1], EntityStore.Order.MOVE, "on the way")


func test_1_3_comes_after_four_minutes_anyway() -> void:
	var sim := _sim("easy")
	_set_food(sim, 0)
	sim.run(4800 + CHECK + 1)
	assert_true(sim.mission.fired.has("1.3"))


func test_1_3b_the_collector_takes_half_the_food_and_leaves() -> void:
	var sim := _sim()
	_set_food(sim, 160)
	_check(sim)
	var tithe := sim.mission.alive_of("tithe")
	_set_food(sim, 200)
	_put(sim, tithe, 124, 27)
	_check(sim)
	assert_true(sim.mission.fired.has("1.3b"))
	assert_eq(_food(sim), 100, "half of it")
	assert_true(_kinds(sim).has("dialogue"))
	_put(sim, sim.mission.alive_of("tithe"), 100, 116)
	_check(sim)
	assert_true(sim.mission.alive_of("tithe").is_empty(), "they leave at the castle gate")
	assert_true(sim.mission.fired.has("1.3b"))


func test_1_4_needs_the_tithe_first_then_300_food() -> void:
	var sim := _sim()
	_skip(sim, ["1.3"])
	_set_food(sim, 400)
	_check(sim)
	assert_false(sim.mission.fired.has("1.4"), "not before the collector came")
	_skip(sim, ["1.3b"])
	_check(sim)
	assert_true(sim.mission.fired.has("1.4"))
	assert_eq(_state(sim, "food"), MissionRuntime.Objective.DONE)
	assert_eq(_state(sim, "grove"), MissionRuntime.Objective.ACTIVE)
	assert_true(_kinds(sim).has("cutscene"), "«Дубы падают»")


## Foot soldiers from the village reach every place of power and every place the triggers send
## them (the grove hill once had no way in through its old oaks).
func test_the_village_can_walk_to_every_site_and_target() -> void:
	var sim := _sim()
	var nav := sim.nav
	var home := nav.area(0, nav.cell_at(126, 27))
	assert_gte(home, 0)
	var places := sim.magic.places
	var points: Array[Vector2i] = [Vector2i(97, 116), Vector2i(112, 140), Vector2i(53, 120)]
	for i in places.count():
		points.append(Vector2i(places.cells[i] % nav.width, places.cells[i] / nav.width))
	for at in points:
		# The point or a cell next to it (a site may carry a chapel).
		var reached := false
		for dy in range(-1, 3):
			for dx in range(-1, 3):
				if nav.in_bounds(at.x + dx, at.y + dy):
					reached = reached or nav.area(0, nav.cell_at(at.x + dx, at.y + dy)) == home
		assert_true(reached, "%s" % at)


# --- phase 2 --------------------------------------------------------------------------------


func test_2_1_near_the_grove_gives_the_forest_hint() -> void:
	var sim := _sim()
	_skip(sim, ["1.3", "1.3b", "1.4"])
	var scout := _spawn(sim, P, &"gdl_light_horse", 95, 76)
	_check(sim)
	assert_true(sim.mission.fired.has("2.1"))
	assert_true(sim.entities.is_alive(scout))


func test_2_2_the_chapel_burns_the_keeper_comes_and_the_alka_opens() -> void:
	var sim := _sim()
	_skip(sim, ["1.3", "1.3b", "1.4", "2.1"])
	sim.economy.destroy(sim.mission.named["chapel"])
	_check(sim)
	assert_true(sim.mission.fired.has("2.2"))
	var keeper := sim.mission.alive_of("keeper")
	assert_eq(keeper.size(), 1)
	assert_eq(sim.entities.owners[keeper[0] - 1], P)
	assert_false(sim.economy.player(P).locked.has(&"gdl_shrine"))


func test_2_3_the_alka_on_the_grove_completes_phase_2() -> void:
	var sim := _sim()
	_skip(sim, ["1.3", "1.3b", "1.4", "2.1", "2.2"])
	sim.mission.run(
		{
			"do": "objective",
			"id": "grove",
			"text": "Take back the sacred grove and lay an alka there"
		},
		sim.tick
	)
	sim.economy.destroy(sim.mission.named["chapel"])
	assert_ne(_place(sim, P, &"gdl_shrine", 79, 75), 0)
	_check(sim)
	assert_true(sim.mission.fired.has("2.3"))
	assert_eq(_state(sim, "grove"), MissionRuntime.Objective.DONE)
	assert_true(sim.mission.flags.has("show_power"), "Сила appears on the panel")
	assert_false(sim.economy.player(P).locked.has(&"gdl_znakharka"))
	var silver := sim.economy.player(P).stock[EconomySystem.SILVER]
	assert_gte(silver, 60, "silver for the first znakharka")
	assert_eq(_state(sim, "places"), MissionRuntime.Objective.ACTIVE)


func test_2_4_the_first_znakharka_and_the_spring_task() -> void:
	var sim := _sim()
	_skip(sim, ["1.3", "1.3b", "1.4", "2.1", "2.2", "2.3"])
	_spawn(sim, P, &"gdl_znakharka", 124, 30)
	_check(sim)
	assert_true(sim.mission.fired.has("2.4"))
	assert_eq(_state(sim, "spring"), MissionRuntime.Objective.ACTIVE)
	_spawn(sim, P, &"gdl_forest_archer", 113, 108)
	_check(sim)
	assert_eq(_state(sim, "spring"), MissionRuntime.Objective.DONE, "2.4c: archers at the spring")


func test_2_4b_the_first_mist_gets_the_chroniclers_line() -> void:
	var sim := _sim()
	_skip(sim, ["1.3", "1.3b", "1.4", "2.1", "2.2", "2.3"])
	var mist := _db.spell(&"sp_bog_mist")
	sim.magic._add_effect(mist, P, 0, Fixed.from_cells(120), Fixed.from_cells(30), 8)
	_check(sim)
	assert_true(sim.mission.fired.has("2.4b"))


func test_all_seven_places_complete_the_optional_objective() -> void:
	var sim := _sim()
	_skip(sim, ["1.3", "1.3b", "1.4", "2.1", "2.2"])
	sim.mission.run({"do": "objective", "id": "places", "text": "x", "optional": true}, 0)
	_skip(sim, ["2.3"])
	sim.magic.places.holders.fill(P)
	_check(sim)
	assert_eq(_state(sim, "places"), MissionRuntime.Objective.DONE)


# --- phase 3 --------------------------------------------------------------------------------


func _phase_3(sim: Simulation) -> void:
	_skip(sim, ["1.3", "1.3b", "1.4", "2.1", "2.2", "2.3", "2.4", "2.4b", "2.4c", "places"])
	sim.mission.fired["2.3"] = sim.tick - 3600
	_check(sim)


func test_3_1_rumbaudas_comes_with_8_riders_and_the_second_age_opens() -> void:
	var sim := _sim()
	_phase_3(sim)
	assert_true(sim.mission.fired.has("3.1"))
	var riders := sim.mission.alive_of("riders")
	assert_eq(riders.size(), 9)
	for id in riders:
		assert_eq(sim.entities.owners[id - 1], P, "given to the player")
	assert_false(sim.economy.player(P).locked.has(&"age_khorugv"))
	assert_eq(_state(sim, "burn"), MissionRuntime.Objective.ACTIVE)
	assert_gt(sim.mission.next_boat, sim.tick, "the boats start")


func test_boats_bring_4_knechts_until_the_pier_is_held() -> void:
	var sim := _sim()
	_phase_3(sim)
	var boats: Dictionary = sim.mission.def.rules["boats"]
	sim.mission.next_boat = sim.tick + 1
	_check(sim)
	var landed := 0
	for g: String in sim.mission.groups:
		if g.begins_with("boat_"):
			landed += sim.mission.alive_of(g).size()
	assert_eq(landed, 4)
	var pier: Array = boats["pier"]
	for g: String in sim.mission.groups:
		for id in sim.mission.alive_of(g):
			if sim.entities.owners[id - 1] == ORDER:
				_put(sim, PackedInt32Array([id]), 20, 20)
	for id in sim.entities.alive_ids:
		if sim.entities.owners[id - 1] == ORDER and _near(sim, id, pier, 8):
			_put(sim, PackedInt32Array([id]), 20, 20)
	_spawn(sim, P, &"gdl_spearman", pier[0], pier[1])
	_check(sim)
	assert_true(sim.mission.flags.has("pier_closed"))
	assert_eq(sim.mission.next_boat, -1, "no more boats")


func _near(sim: Simulation, id: int, at: Array, radius: int) -> bool:
	var dx := sim.entities.pos_x[id - 1] - Fixed.from_cells(at[0])
	var dy := sim.entities.pos_y[id - 1] - Fixed.from_cells(at[1])
	return dx * dx + dy * dy <= Fixed.from_cells(radius) * Fixed.from_cells(radius)


func test_the_grain_convoy_gives_200_food_when_caught() -> void:
	var sim := _sim()
	_phase_3(sim)
	sim.mission.fired["3.1"] = sim.tick - 2400
	_check(sim)
	var convoy := sim.mission.alive_of("convoy")
	assert_eq(convoy.size(), 3)
	_set_food(sim, 0)
	for id in convoy:
		sim.remove_unit(id)
	_check(sim)
	assert_eq(_state(sim, "convoy"), MissionRuntime.Objective.DONE)
	assert_eq(_food(sim), 200)


func test_the_grain_convoy_that_reaches_the_pier_is_lost() -> void:
	var sim := _sim()
	_phase_3(sim)
	sim.mission.fired["3.1"] = sim.tick - 2400
	_check(sim)
	_put(sim, sim.mission.alive_of("convoy"), 112, 139)
	_check(sim)
	_check(sim)
	assert_eq(_state(sim, "convoy"), MissionRuntime.Objective.FAILED)
	assert_false(sim.mission.fired.has("convoy_taken"))


func test_3_2_the_second_age_gives_the_lance_and_fire_hint() -> void:
	var sim := _sim()
	sim.economy.player(P).age = 2
	_check(sim)
	assert_true(sim.mission.fired.has("3.2"))


func test_3_3_near_the_pier_gives_the_pier_hint() -> void:
	var sim := _sim()
	_phase_3(sim)
	_spawn(sim, P, &"gdl_light_horse", 118, 136)
	_check(sim)
	assert_true(sim.mission.fired.has("3.3"))


func test_3_4_the_knights_ride_for_the_boats_when_the_castle_is_half_burnt() -> void:
	var sim := _sim()
	_phase_3(sim)
	var castle: int = sim.mission.named["skir_castle"]
	var store := sim.economy.buildings
	store.hp[castle - 1] = store.max_hp[castle - 1] / 2 - 1
	_check(sim)
	assert_true(sim.mission.fired.has("3.4"))
	var knights := sim.mission.alive_of("skir_knights")
	assert_eq(knights.size(), 2)
	for id in knights:
		assert_eq(sim.entities.stance[id - 1], EntityStore.Stance.AGGRESSIVE)
	assert_eq(_state(sim, "knights"), MissionRuntime.Objective.ACTIVE)
	_put(sim, knights, 113, 146)
	_check(sim)
	_check(sim)
	assert_eq(_state(sim, "knights"), MissionRuntime.Objective.FAILED, "they got away")


func test_3_4_knights_cut_down_complete_the_optional_objective() -> void:
	var sim := _sim()
	_phase_3(sim)
	var castle: int = sim.mission.named["skir_castle"]
	sim.economy.buildings.hp[castle - 1] = 100
	_check(sim)
	for id in sim.mission.alive_of("skir_knights"):
		sim.remove_unit(id)
	_check(sim)
	assert_eq(_state(sim, "knights"), MissionRuntime.Objective.DONE)


func test_a_lost_rider_fails_the_riders_objective() -> void:
	var sim := _sim()
	_phase_3(sim)
	var riders := sim.mission.alive_of("riders")
	sim.remove_unit(riders[1])
	_check(sim)
	assert_eq(_state(sim, "riders"), MissionRuntime.Objective.FAILED)


func test_3_5_skirsnemune_burnt_then_the_final_cutscene_and_victory() -> void:
	var sim := _sim()
	_phase_3(sim)
	sim.economy.destroy(sim.mission.named["skir_castle"])
	_check(sim)
	assert_true(sim.mission.fired.has("3.5"))
	assert_eq(_state(sim, "burn"), MissionRuntime.Objective.DONE)
	assert_eq(_state(sim, "riders"), MissionRuntime.Objective.DONE, "nobody of them lost")
	sim.run(200)
	assert_true(sim.mission.fired.has("final"))
	assert_true(sim.fire.is_burning(sim.mission.named["dub_castle"]), "the vogt burns Dubysa")
	sim.run(100)
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.VICTORY)
	assert_true(sim.victory.is_over())
	assert_eq(sim.victory.winner, P)
	assert_eq(sim.victory.reason, SkirmishVictory.Reason.MISSION)


# --- defeat ---------------------------------------------------------------------------------


func test_gintaut_wounded_is_defeat() -> void:
	var sim := _sim()
	sim.remove_unit(sim.mission.alive_of("gintaut")[0])
	_check(sim)
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.DEFEAT)
	assert_eq(sim.victory.winner, ORDER)


func test_the_village_burnt_is_defeat() -> void:
	var sim := _sim()
	sim.economy.destroy(sim.mission.named["village_tc"])
	_check(sim)
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.DEFEAT)


func test_starving_60_seconds_is_defeat_on_normal_only() -> void:
	for difficulty: String in ["easy", "normal"]:
		var sim := _sim(difficulty)
		_skip(sim, ["1.3"])
		_set_food(sim, 0)
		sim.run(1200 + 2 * CHECK)
		var lost := sim.mission.outcome == MissionRuntime.Outcome.DEFEAT
		assert_eq(lost, difficulty == "normal", difficulty)


func test_nothing_happens_after_the_end() -> void:
	var sim := _sim()
	sim.economy.destroy(sim.mission.named["village_tc"])
	_check(sim)
	var fired := sim.mission.fired.size()
	_set_food(sim, 500)
	sim.run(100)
	assert_eq(sim.mission.fired.size(), fired)


# --- saving ---------------------------------------------------------------------------------


func test_save_and_load_give_the_same_hash_and_play_on_the_same() -> void:
	var sim := _sim()
	_set_food(sim, 160)
	sim.run(400)
	var data := SimSave.capture(sim)
	var loaded := SimSave.restore(data, _db)
	assert_not_null(loaded)
	assert_eq(loaded.state_hash(), data["hash"], "plan M9: the same hash after loading")
	sim.run(300)
	loaded.run(300)
	assert_eq(loaded.state_hash(), sim.state_hash(), "and it plays on the same")
	assert_eq(loaded.mission.fired, sim.mission.fired)


func test_a_save_file_round_trip() -> void:
	var sim := _sim()
	sim.run(100)
	var path := "user://test_mission.save"
	assert_eq(SimSave.save(sim, path), OK)
	var head := SimSave.read_header(path)
	assert_eq(head["mission_id"], MISSION)
	assert_false(head.has("snapshot"))
	var loaded := SimSave.load_file(path, _db)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_not_null(loaded)
	assert_eq(loaded.state_hash(), sim.state_hash())
	assert_eq(loaded.tick, sim.tick)
