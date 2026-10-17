# gdlint:ignore = max-public-methods
extends GutTest
## «ВКЛ 4. Вилькомир, 1435»: one test per trigger of the mission card and per rule of its own
## (camp supply, Tatar raids, the column on the march, captives, the spared brother). The world
## is put into the trigger's condition and its events are checked; earlier triggers a test does
## not need are marked as fired by hand.

const MISSION := "gdl_04"
const P := 1
const LIVONIANS := 2
const SVITRIGAILA := 3
const MIKHAIL := 4
const KOBYLANY := 5
const CHECK := MissionRuntime.CHECK_EVERY
const DAWN := 14400
const CUT := Vector2i(50, 46)
const CAUSEWAY := Vector2i(46, 34)
const KURGAN := Vector2i(52, 64)
const SPRING := Vector2i(85, 72)
const EXIT_N := Vector2i(25, 1)

var _db: CatalogDB


func before_all() -> void:
	_db = CatalogDB.load_prototype()


func _sim() -> Simulation:
	var sim := MissionSetup.new_simulation(MISSION, 1, _db, "normal")
	assert_not_null(sim)
	return sim


func _skip(sim: Simulation, ids: Array[String]) -> void:
	for tid in ids:
		sim.mission.fired[tid] = sim.tick


func _check(sim: Simulation) -> void:
	sim.run(CHECK + 1)


func _kinds(sim: Simulation) -> PackedStringArray:
	var out := PackedStringArray()
	for e: Dictionary in sim.mission.events:
		out.append(e["kind"])
	return out


func _state(sim: Simulation, oid: String) -> int:
	return sim.mission.objective_state.get(oid, -1)


func _put(sim: Simulation, ids: PackedInt32Array, cx: int, cy: int) -> void:
	for id in ids:
		sim.entities.pos_x[id - 1] = Fixed.from_cells(cx) + Fixed.HALF
		sim.entities.pos_y[id - 1] = Fixed.from_cells(cy) + Fixed.HALF
		sim.entities.stop(id)


func _kill(sim: Simulation, group: String, keep: int = 0) -> void:
	var ids := sim.mission.alive_of(group)
	for k in ids.size() - keep:
		sim.remove_unit(ids[k])


func _cell_of(sim: Simulation, id: int) -> int:
	return sim.nav.cell_at(
		Fixed.to_cells(sim.entities.pos_x[id - 1]), Fixed.to_cells(sim.entities.pos_y[id - 1])
	)


func _one(sim: Simulation, type: StringName, p: int, cx: int, cy: int) -> int:
	return sim.spawn_unit(
		type, p, Fixed.from_cells(cx) + Fixed.HALF, Fixed.from_cells(cy) + Fixed.HALF
	)


## The world at dawn: the first phase over, 2.1 fired on this check.
func _dawn(sim: Simulation) -> void:
	_check(sim)
	sim.mission.fired["1.1"] = sim.tick - DAWN
	_check(sim)
	assert_true(sim.mission.fired.has("2.1"))


# --- setup ----------------------------------------------------------------------------------


func test_the_two_camps_the_lake_and_the_places_are_set_up() -> void:
	var sim := _sim()
	var m := sim.mission
	sim.run(2)
	assert_eq(sim.nav.width, 160)
	assert_eq(sim.nav.height, 120)
	for p: int in [MIKHAIL, KOBYLANY]:
		assert_true(sim.sides.friendly(P, p), "player %d is on our side" % p)
	assert_true(sim.sides.friendly(LIVONIANS, SVITRIGAILA), "Livonians and Švitrigaila together")
	assert_true(sim.sides.hostile(P, SVITRIGAILA))
	assert_eq(sim.economy.player(P).age, 2, "Хоругвь, no age up")
	assert_true(sim.economy.player(P).pop_provided >= 140, "room for the camp's hires")
	assert_true(sim.economy.buildings.is_alive(m.named["camp"]), "the field camp")
	assert_eq(sim.magic.places.count(), 3, "the stone, the spring, the kurgan")
	assert_eq(sim.magic.places.holders[0], P, "the footprint stone is ours from the start")
	assert_eq(sim.magic.places.holders[2], LIVONIANS, "the kurgan's chapel is the enemy's")
	assert_eq(sim.magic.places.holders[1], 0, "the spring is nobody's")
	var expected: Array[String] = [
		"mikolaj",
		"lances",
		"riders",
		"strelets",
		"mikhail_army",
		"kobylany_army",
		"kerskorf",
		"nesselrode",
		"knights",
		"knechts",
		"prince_1",
		"yuri",
		"tatars",
		"patrol"
	]
	for g in expected:
		assert_gt(m.alive_of(g).size(), 0, "group %s is on the field" % g)
	for id in m.alive_of("guard"):
		assert_true(sim.combat.untouchable.has(id), "Švitrigaila's guard cannot be caught")
	var yuri := m.alive_of("yuri")[0]
	assert_eq(sim.entities.type_ids[yuri - 1], &"hero_jurij_gintovt")
	assert_eq(sim.combat.hp_floor.get(yuri, 0), sim.entities.max_hp[yuri - 1] / 5)


func test_the_lake_is_only_rounded_by_the_strip_and_the_column_can_reach_vilkomir() -> void:
	var sim := _sim()
	var m := sim.mission
	var cut := sim.nav.cell_at(CUT.x, CUT.y)
	var spring := sim.nav.cell_at(SPRING.x, SPRING.y)
	var exit := sim.nav.cell_at(EXIT_N.x, EXIT_N.y)
	for g: String in ["mikolaj", "lances", "strelets", "mikhail_army", "kobylany_army"]:
		var from := _cell_of(sim, m.alive_of(g)[0])
		assert_eq(sim.nav.area(0, from), sim.nav.area(0, cut), "%s can reach the road" % g)
		assert_eq(sim.nav.area(0, from), sim.nav.area(0, spring), "%s can wade to the spring" % g)
	for g: String in ["knechts", "prince_1", "wagons"]:
		var from := _cell_of(sim, m.alive_of(g)[0])
		assert_eq(sim.nav.area(0, from), sim.nav.area(0, exit), "%s can march away" % g)
	# The lake splits the map: from the east shore to the west shore there is no way south of the
	# lake's end, so a path has to go round by the strip.
	for y in range(40, 120):
		var row := ""
		for x in range(70, 100):
			row += (
				"~"
				if sim.nav.terrain[sim.nav.cell_at(x, y)] == sim.nav.terrain_index(&"t_water")
				else "."
			)
		assert_true(row.contains("~"), "lake at row %d" % y)


# --- phase 1: the two nights ---------------------------------------------------------------


func test_1_1_two_shores_and_the_countdown_to_dawn() -> void:
	var sim := _sim()
	_check(sim)
	var m := sim.mission
	assert_true(m.fired.has("1.1"))
	assert_true(_kinds(sim).has("cutscene"))
	assert_eq(_state(sim, "hold"), MissionRuntime.Objective.ACTIVE)
	assert_eq(m.countdown_end, DAWN, "two nights of six minutes")
	assert_eq(m.alive_of("vanguard").size(), 62, "Kerskorf, Nesselrode, 14 + 30 + 16")


func test_the_wagons_supply_the_camp_every_minute_while_it_stands() -> void:
	var sim := _sim()
	var stock := sim.economy.player(P).stock.duplicate()
	sim.run(1200 + CHECK)
	var now := sim.economy.player(P).stock
	assert_eq(now[0] - stock[0], 80)
	assert_eq(now[2] - stock[2], 30)
	sim.economy.destroy(sim.mission.named["camp"])
	var before := now.duplicate()
	sim.run(1300)
	assert_eq(sim.economy.player(P).stock, before, "no camp, no supply")
	assert_true(sim.mission.flags.has("supply_lost"))


func test_1_3_tatars_raid_round_the_lake_every_two_minutes() -> void:
	var sim := _sim()
	var m := sim.mission
	sim.run(2400 + CHECK)
	assert_eq(m.raids, 1)
	assert_eq(m.alive_of("raid_0").size(), 3)
	_check(sim)
	assert_true(m.fired.has("1.3"))
	assert_true(_kinds(sim).has("dialogue"))
	sim.run(2400)
	assert_eq(m.raids, 2)


func test_no_raids_after_dawn() -> void:
	var sim := _sim()
	var m := sim.mission
	_dawn(sim)
	m.next_raid = sim.tick
	sim.run(3 * CHECK)
	assert_eq(m.raids, 0)
	assert_eq(m.next_raid, -1)


func test_1_2_the_fires_across_the_water() -> void:
	var sim := _sim()
	_skip(sim, ["1.1"])
	_put(sim, sim.mission.alive_of("riders").slice(0, 1), 94, 60)
	_check(sim)
	assert_true(sim.mission.fired.has("1.2"))
	assert_true(_kinds(sim).has("hint"))


func test_1_4_the_spring_on_the_island() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1.1"])
	var riders := m.alive_of("riders").slice(0, 3)
	_put(sim, riders, SPRING.x, SPRING.y)
	_check(sim)
	assert_true(m.fired.has("1.4"))
	_kill(sim, "patrol")
	sim.run(400)
	assert_eq(sim.magic.places.holders[1], P)
	assert_true(m.fired.has("1.4b"), "«Голос из-за воды»")


func test_1_5_the_night_council() -> void:
	var sim := _sim()
	sim.run(10800 + 2 * CHECK)
	assert_true(sim.mission.fired.has("1.5"))
	assert_true(sim.mission.fired.has("night_2"))
	assert_false(sim.mission.fired.has("2.1"))


func test_early_crossing_brings_prince_michaels_word() -> void:
	var sim := _sim()
	_skip(sim, ["1.1"])
	_put(sim, sim.mission.alive_of("riders").slice(0, 1), 40, 70)
	_check(sim)
	assert_true(sim.mission.fired.has("early"))


# --- phase 2: the column -------------------------------------------------------------------


func test_2_1_dawn_the_column_marches_and_podlasie_comes() -> void:
	var sim := _sim()
	var m := sim.mission
	_dawn(sim)
	assert_eq(_state(sim, "hold"), MissionRuntime.Objective.DONE)
	assert_eq(_state(sim, "cut"), MissionRuntime.Objective.ACTIVE)
	assert_eq(_state(sim, "captives"), MissionRuntime.Objective.ACTIVE)
	assert_eq(_state(sim, "kurgan"), MissionRuntime.Objective.ACTIVE)
	assert_eq(m.countdown_end, -1)
	assert_eq(m.alive_of("podlasie").size(), 8)
	var knecht := m.alive_of("knechts")[0]
	assert_true(m.marching.has(knecht))
	assert_eq(sim.entities.orders[knecht - 1], EntityStore.Order.MOVE)


func test_marching_men_lose_armour_and_spirit_until_they_form_up() -> void:
	var sim := _sim()
	var m := sim.mission
	_dawn(sim)
	var knecht := m.alive_of("knechts")[0]
	var s := knecht - 1
	sim.run(CHECK)
	var full := sim.combat.defs[s].morale * CombatSystem.MORALE_SCALE
	assert_true(sim.entities.disorder[s] > 0, "lost order")
	assert_true(sim.entities.morale[s] <= full * 600 / 1000, "spirit held down")
	# Struck: it forms up 25 seconds later.
	sim.entities.calm[s] = 0
	sim.run(CHECK)
	assert_true(m.marching[knecht] > 0, "forming up")
	sim.run(500 + CHECK)
	assert_false(m.marching.has(knecht), "formed up")
	sim.run(2 * CHECK)
	assert_eq(sim.entities.disorder[s], 0)


func test_2_2_the_allies_ride_round_for_the_head() -> void:
	var sim := _sim()
	var m := sim.mission
	_dawn(sim)
	sim.run(400 + CHECK)
	assert_true(m.fired.has("2.2"))
	var lance := m.alive_of("mikhail_army")[0]
	assert_eq(sim.entities.orders[lance - 1], EntityStore.Order.MOVE)


func test_2_3_holding_the_road_a_minute_cuts_the_column() -> void:
	var sim := _sim()
	var m := sim.mission
	_dawn(sim)
	var ours := m.alive_of("lances")
	_put(sim, ours, CUT.x, CUT.y)
	sim.run(600)
	assert_false(m.fired.has("2.3"), "not yet")
	for id in ours:
		if sim.entities.is_alive(id):
			_put(sim, PackedInt32Array([id]), CUT.x, CUT.y)
	sim.run(660)
	if not m.fired.has("2.3"):
		# Struck down meanwhile: stand there again and wait the whole minute.
		_put(sim, m.alive_of("lances"), CUT.x, CUT.y)
		sim.run(1220)
	assert_true(m.fired.has("2.3"))
	assert_eq(_state(sim, "cut"), MissionRuntime.Objective.DONE)
	var knight := m.alive_of("knights")[0]
	assert_false(m.marching.has(knight), "the head turns round, out of the column")
	assert_eq(sim.entities.stance[knight - 1], EntityStore.Stance.AGGRESSIVE)


func test_2_1c_the_head_leaves_and_most_of_it_gone_is_defeat() -> void:
	var sim := _sim()
	var m := sim.mission
	_dawn(sim)
	sim.mission.fired["2.1"] = sim.tick - 4400
	_check(sim)
	assert_true(m.fired.has("2.1c"))
	assert_true(m.exits.has("vanguard"))
	m.exited["vanguard"] = 31
	_check(sim)
	assert_false(m.is_over())
	m.exited["vanguard"] = 32
	_check(sim)
	assert_eq(m.outcome, MissionRuntime.Outcome.DEFEAT)


func test_2_1c_not_after_the_cut() -> void:
	var sim := _sim()
	_dawn(sim)
	_skip(sim, ["2.3"])
	sim.mission.fired["2.1"] = sim.tick - 4400
	_check(sim)
	assert_false(sim.mission.fired.has("2.1c"))


func test_2_4_the_brothers_sign() -> void:
	var sim := _sim()
	var m := sim.mission
	_dawn(sim)
	var yuri := m.alive_of("yuri")[0]
	var x := Fixed.to_cells(sim.entities.pos_x[yuri - 1])
	var y := Fixed.to_cells(sim.entities.pos_y[yuri - 1])
	_put(sim, m.alive_of("mikolaj"), x + 4, y)
	_check(sim)
	assert_true(m.fired.has("2.4"))
	assert_true(_kinds(sim).has("dialogue"))


# --- captives -------------------------------------------------------------------------------


func test_a_beaten_man_surrounded_on_two_sides_surrenders() -> void:
	var sim := _sim()
	var m := sim.mission
	var lance := m.alive_of("prince_1")[0]
	_put(sim, PackedInt32Array([lance]), 100, 90)
	sim.entities.morale[lance - 1] = 5 * CombatSystem.MORALE_SCALE
	var a := _one(sim, &"gdl_light_horse", P, 98, 90)
	_check(sim)
	assert_true(sim.entities.is_alive(lance), "one side only: it fights on")
	var b := _one(sim, &"gdl_light_horse", MIKHAIL, 102, 90)
	sim.entities.morale[lance - 1] = 5 * CombatSystem.MORALE_SCALE
	_put(sim, PackedInt32Array([lance]), 100, 90)
	_put(sim, PackedInt32Array([a]), 98, 90)
	_put(sim, PackedInt32Array([b]), 102, 90)
	_check(sim)
	assert_false(sim.entities.is_alive(lance), "laid down his arms")
	assert_eq(m.captured.get("prince_1", 0), 1)
	assert_eq(m.captives, 1)


func test_a_man_in_good_spirit_or_a_livonian_does_not_surrender() -> void:
	var sim := _sim()
	var m := sim.mission
	var lance := m.alive_of("prince_2")[0]
	var knecht := m.alive_of("knechts")[0]
	_put(sim, PackedInt32Array([lance]), 100, 90)
	_put(sim, PackedInt32Array([knecht]), 100, 96)
	sim.entities.morale[knecht - 1] = 0
	for at: Vector2i in [Vector2i(98, 90), Vector2i(102, 90), Vector2i(98, 96), Vector2i(102, 96)]:
		_one(sim, &"gdl_light_horse", P, at.x, at.y)
	_check(sim)
	assert_true(sim.entities.is_alive(lance))
	assert_true(sim.entities.is_alive(knecht), "the brothers' men are not taken captive")


func test_five_banners_taken_is_the_extra_objective() -> void:
	var sim := _sim()
	var m := sim.mission
	_dawn(sim)
	for g: String in ["prince_1", "prince_2", "prince_3", "riders_1"]:
		m.captured[g] = 2
	_check(sim)
	assert_ne(_state(sim, "captives"), MissionRuntime.Objective.DONE, "four of five")
	m.captured["riders_2"] = 1
	_check(sim)
	assert_ne(_state(sim, "captives"), MissionRuntime.Objective.DONE, "one of four is not half")
	m.captured["riders_2"] = 2
	_check(sim)
	assert_eq(_state(sim, "captives"), MissionRuntime.Objective.DONE)


# --- the spared brother --------------------------------------------------------------------


func test_jurij_cannot_fall_below_a_fifth_and_then_rides_off_untouchable() -> void:
	var sim := _sim()
	var m := sim.mission
	var yuri := m.alive_of("yuri")[0]
	var s := yuri - 1
	sim.combat.lightning(yuri, P, sim.entities.max_hp[s] * 2)
	assert_eq(sim.entities.hp[s], sim.entities.max_hp[s] / 5, "held at the floor")
	_check(sim)
	assert_true(m.flags.has("spared:yuri"))
	assert_true(sim.combat.untouchable.has(yuri))
	assert_eq(sim.entities.stance[s], EntityStore.Stance.PASSIVE)
	assert_eq(sim.entities.orders[s], EntityStore.Order.MOVE)


func test_3_5_at_the_ford_when_jurij_is_spared_or_alone() -> void:
	var sim := _sim()
	var m := sim.mission
	_dawn(sim)
	sim.mission.fired["2.4"] = sim.tick - 200
	_kill(sim, "yuri", 1)
	_check(sim)
	assert_true(m.fired.has("3.5"))
	assert_true(_kinds(sim).has("cutscene"))
	for id in m.alive_of("yuri"):
		assert_true(sim.combat.untouchable.has(id))
	assert_true(m.exits.has("yuri"), "he rides east, to the Dnieper")


func test_3_5_waits_for_the_brothers_sign() -> void:
	var sim := _sim()
	_dawn(sim)
	_kill(sim, "yuri", 1)
	_check(sim)
	assert_false(sim.mission.fired.has("3.5"))


# --- phase 3: the Livonians ---------------------------------------------------------------


func test_3_1_the_head_comes_back_to_the_stream() -> void:
	var sim := _sim()
	var m := sim.mission
	_dawn(sim)
	_skip(sim, ["2.3"])
	_put(sim, m.alive_of("knights").slice(0, 1), CAUSEWAY.x, CAUSEWAY.y + 2)
	_check(sim)
	assert_true(m.fired.has("3.1"))
	assert_eq(_state(sim, "banners"), MissionRuntime.Objective.ACTIVE)


func test_3_2_the_marshals_banner_falls() -> void:
	var sim := _sim()
	var m := sim.mission
	_dawn(sim)
	var knecht := m.alive_of("knechts")[0]
	m.marching.erase(knecht)
	sim.entities.morale[knecht - 1] = sim.combat.defs[knecht - 1].morale * CombatSystem.MORALE_SCALE
	var before := sim.entities.morale[knecht - 1]
	_kill(sim, "nesselrode")
	_check(sim)
	assert_true(m.fired.has("3.2"))
	assert_true(sim.entities.morale[knecht - 1] < before, "−25% spirit")


func test_3_3_the_reserve_and_the_kurgan() -> void:
	var sim := _sim()
	var m := sim.mission
	_dawn(sim)
	_skip(sim, ["2.3"])
	sim.mission.fired["2.3"] = sim.tick - 3600
	_check(sim)
	assert_true(m.fired.has("3.3"))
	assert_eq(m.alive_of("reserve").size(), 10)
	assert_eq(_state(sim, "reserve"), MissionRuntime.Objective.ACTIVE)
	_put(sim, m.alive_of("reserve"), KURGAN.x, KURGAN.y)
	_check(sim)
	assert_eq(_state(sim, "reserve"), MissionRuntime.Objective.FAILED, "joined the tail")


func test_3_3_the_reserve_stopped() -> void:
	var sim := _sim()
	var m := sim.mission
	_dawn(sim)
	_skip(sim, ["2.3"])
	sim.mission.fired["2.3"] = sim.tick - 3600
	_check(sim)
	_kill(sim, "reserve")
	_check(sim)
	assert_eq(_state(sim, "reserve"), MissionRuntime.Objective.DONE)


func test_the_kurgan_taken() -> void:
	var sim := _sim()
	var m := sim.mission
	_dawn(sim)
	sim.economy.destroy(m.named["chapel"])
	_kill(sim, "chapel_guard")
	_put(sim, m.alive_of("riders").slice(0, 3), 59, 61)
	sim.run(400)
	assert_eq(sim.magic.places.holders[2], P)
	assert_eq(_state(sim, "kurgan"), MissionRuntime.Objective.DONE)


func test_3_4_kerskorf_falls_and_the_livonians_run_for_the_river() -> void:
	var sim := _sim()
	var m := sim.mission
	_dawn(sim)
	_skip(sim, ["2.3"])
	_kill(sim, "kerskorf")
	_check(sim)
	assert_true(m.fired.has("3.1"), "the banners objective comes with the Master's fall too")
	assert_true(m.fired.has("3.4"))
	assert_true(m.exits.has("vanguard"))
	assert_true(m.exits.has("guard"), "Švitrigaila gets away with his guard")
	m.exited["vanguard"] = 40
	_check(sim)
	assert_false(m.is_over(), "fleeing after the Master's death is no defeat")
	_kill(sim, "nesselrode")
	_check(sim)
	assert_eq(_state(sim, "banners"), MissionRuntime.Objective.DONE)


func test_victory_after_the_banners_and_the_ford() -> void:
	var sim := _sim()
	var m := sim.mission
	_dawn(sim)
	_skip(sim, ["2.3"])
	sim.mission.fired["2.4"] = sim.tick - 200
	_kill(sim, "kerskorf")
	_kill(sim, "nesselrode")
	_kill(sim, "yuri", 1)
	sim.run(3 * CHECK)
	assert_true(m.fired.has("3.5"))
	assert_true(m.fired.has("victory_scene"))
	sim.run(100 + 2 * CHECK)
	assert_eq(m.outcome, MissionRuntime.Outcome.VICTORY)


# --- defeats --------------------------------------------------------------------------------


func test_mikolaj_or_michael_fallen_is_defeat() -> void:
	var sim := _sim()
	_kill(sim, "mikolaj")
	_check(sim)
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.DEFEAT)
	var other := _sim()
	_kill(other, "mikhail")
	_check(other)
	assert_eq(other.mission.outcome, MissionRuntime.Outcome.DEFEAT)


func test_the_banner_cut_to_pieces_is_defeat() -> void:
	var sim := _sim()
	for id in sim.entities.alive_ids.duplicate():
		if sim.entities.owners[id - 1] == P and sim.entities.type_ids[id - 1] != &"hero_mikolaj":
			sim.remove_unit(id)
	_check(sim)
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.DEFEAT)


# --- save, hash, panel ----------------------------------------------------------------------


func test_save_and_load_keep_the_column_the_captives_and_the_countdown() -> void:
	var sim := _sim()
	_dawn(sim)
	sim.mission.captured["prince_1"] = 2
	sim.mission.captives = 2
	sim.run(300)
	var data := SimSave.capture(sim)
	var loaded := SimSave.restore(data, _db)
	assert_not_null(loaded)
	assert_eq(loaded.state_hash(), data["hash"])
	assert_eq(loaded.mission.marching, sim.mission.marching)
	assert_eq(loaded.mission.captured, sim.mission.captured)
	assert_eq(loaded.combat.hp_floor, sim.combat.hp_floor)
	sim.run(600)
	loaded.run(600)
	assert_eq(loaded.state_hash(), sim.state_hash(), "and it plays on the same")


func test_marching_and_captives_change_the_hash() -> void:
	var a := _sim()
	var b := _sim()
	b.mission.captives = 1
	assert_ne(a.state_hash(), b.state_hash())
	var c := _sim()
	c.mission.marching[c.mission.alive_of("knechts")[0]] = -1
	assert_ne(a.state_hash(), c.state_hash())


func test_the_panel_counts_down_to_dawn_and_the_captive_banners() -> void:
	var sim := _sim()
	_check(sim)
	var clock := SimClock.new()
	clock.sim = sim
	add_child_autofree(clock)
	var panel := MissionPanel.new()
	add_child_autofree(panel)
	panel.attach(sim, clock, null)
	panel.poll()
	assert_eq(panel.march_text(), "Dawn in %s" % UiText.clock(DAWN - sim.tick))
	sim.mission.fired["1.1"] = sim.tick - DAWN
	_check(sim)
	sim.mission.captured["prince_1"] = 3
	panel.poll()
	assert_eq(panel.march_text(), "Banners taken captive: 1")
