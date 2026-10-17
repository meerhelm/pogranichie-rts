# gdlint:ignore = max-public-methods
extends GutTest
## «ВКЛ 5. Ведроша, 1500»: one test per trigger of the mission card and per rule of its own (the
## bridge, the ford, the men brought back over the river, the waves, the icon, captives taken
## from the player). The world is put into the trigger's condition and its events are checked;
## earlier triggers a test does not need are marked as fired by hand.

const MISSION := "gdl_05"
const P := 1
const MOSCOW := 2
const HOST := 3
const CHECK := MissionRuntime.CHECK_EVERY
const BRIDGE := Vector2i(72, 49)
const BRIDGE_E := Vector2i(76, 49)
const FORD := Vector2i(72, 74)
const RIGHT := Vector2i(100, 68)
const AMBUSH := Vector2i(101, 16)
const WEST := Vector2i(60, 52)
const EAST := Vector2i(90, 60)

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


func _one(sim: Simulation, type: StringName, p: int, cx: int, cy: int) -> int:
	return sim.spawn_unit(
		type, p, Fixed.from_cells(cx) + Fixed.HALF, Fixed.from_cells(cy) + Fixed.HALF
	)


func _cell_of(sim: Simulation, id: int) -> int:
	return sim.nav.cell_at(
		Fixed.to_cells(sim.entities.pos_x[id - 1]), Fixed.to_cells(sim.entities.pos_y[id - 1])
	)


## Everyone but Andrei taken off the map, so nothing else stirs the triggers.
func _quiet(sim: Simulation) -> void:
	for id in sim.entities.alive_ids.duplicate():
		var t := sim.entities.type_ids[id - 1]
		if sim.entities.owners[id - 1] == P and t != &"hero_andrei":
			sim.remove_unit(id)


## The world as the ambush strikes: the battle fired by hand, trigger 6 on this check.
func _strike(sim: Simulation) -> void:
	_check(sim)
	_skip(sim, ["1.2", "2", "4", "5", "5.1", "5.2", "5.3", "warn"])
	sim.mission.run({"do": "objective", "id": "right", "text": "x"}, sim.tick)
	sim.mission.fired["3"] = sim.tick - 9600
	_check(sim)
	assert_true(sim.mission.fired.has("6"))


## The world as the bridge falls (trigger 8 on this check).
func _bridge_down(sim: Simulation) -> void:
	_strike(sim)
	for oid: String in ["out", "fifteen"]:
		sim.mission.run({"do": "objective", "id": oid, "text": oid}, sim.tick)
	sim.mission.fired["7"] = sim.tick
	sim.mission.retreat.bridge_from = sim.tick
	sim.mission.run({"do": "bridge", "on": false}, sim.tick)
	_check(sim)
	assert_true(sim.mission.fired.has("8"))


# --- setup ----------------------------------------------------------------------------------


func test_the_army_the_regiments_and_the_map_are_set_up() -> void:
	var sim := _sim()
	var m := sim.mission
	sim.run(2)
	assert_eq(sim.nav.width, 160)
	assert_eq(sim.nav.height, 100)
	assert_true(sim.sides.friendly(P, HOST), "Ostrogski's army is on our side")
	assert_true(sim.sides.hostile(P, MOSCOW))
	assert_eq(sim.economy.player(MOSCOW).faction, &"mo", "Muscovy joins as itself")
	assert_eq(sim.economy.player(P).age, 2)
	assert_eq(sim.magic.places.count(), 2, "the kurgan and the spring")
	assert_eq(sim.economy.player(MOSCOW).power, 300 * MagicSystem.POWER_UNIT, "Сила for the icon")
	var expected: Array[String] = [
		"andrei",
		"lances",
		"riders",
		"strelets",
		"ostrogski",
		"host_lances",
		"orphans",
		"forward",
		"main",
		"icon",
		"ambush",
		"axemen",
		"shchenya"
	]
	for g in expected:
		assert_gt(m.alive_of(g).size(), 0, "group %s is on the field" % g)
	for g: String in ["ambush", "axemen", "shchenya"]:
		for id in m.alive_of(g):
			assert_true(sim.combat.untouchable.has(id), "%s cannot be touched yet" % g)
	assert_eq(sim.entities.type_ids[m.alive_of("andrei")[0] - 1], &"hero_andrei")
	assert_eq(m.alive_of("lances").size(), 10, "ten noble lances")
	assert_eq(sim.economy.db.unit(&"gdl_szlachta_lance").age, 3, "a Держава unit, mission only")
	assert_true(sim.economy.db.unit(&"mo_syn_boyarsky").campaign_only)


func test_the_trosna_is_crossed_only_by_the_bridge_and_the_ford() -> void:
	var sim := _sim()
	var nav := sim.nav
	var water := nav.terrain_index(&"t_water")
	for y in nav.height:
		var crossing := true
		for x in range(71, 74):
			crossing = crossing and nav.terrain[nav.cell_at(x, y)] != water
		var expected := y in [49, 50, 74, 75]
		assert_eq(crossing, expected, "row %d crosses the Trosna: %s" % [y, expected])
	var west := nav.cell_at(WEST.x, WEST.y)
	var east := nav.cell_at(EAST.x, EAST.y)
	assert_eq(nav.area(0, west), nav.area(0, east), "the two banks are joined")
	var ambush := _cell_of(sim, sim.mission.alive_of("ambush")[0])
	assert_eq(nav.area(0, ambush), nav.area(0, east), "the ambush can ride out of the forest")
	assert_eq(nav.terrain_at(nav.cell_at(72, 74)), &"t_ford")
	assert_eq(nav.terrain_at(nav.cell_at(72, 49)), &"t_road", "the bridge")


func test_1_1_review_at_yelnya_and_the_scouting_objective() -> void:
	var sim := _sim()
	_check(sim)
	var m := sim.mission
	assert_true(m.fired.has("1.1"))
	assert_true(_kinds(sim).has("cutscene"))
	assert_eq(_state(sim, "scout"), MissionRuntime.Objective.ACTIVE)
	assert_true(m.objective_optional["spot"])
	assert_eq(m.alive_of("host").size(), 36, "16 lances, 16 riders, 4 without a standard-bearer")
	for id in m.alive_of("ostrogski"):
		assert_true(sim.combat.untouchable.has(id), "the hetman is not killed in battle")


# --- phase 1: the forward regiment -----------------------------------------------------------


func test_1_2_scouts_at_the_trosna_find_the_forward_regiment_and_the_army_strikes() -> void:
	var sim := _sim()
	_check(sim)
	assert_false(sim.mission.fired.has("1.2"))
	_put(sim, sim.mission.alive_of("riders").slice(0, 1), 48, 48)
	_check(sim)
	assert_true(sim.mission.fired.has("1.2"))
	assert_eq(_state(sim, "scout"), MissionRuntime.Objective.DONE)
	assert_eq(_state(sim, "forward"), MissionRuntime.Objective.ACTIVE)
	var lance := sim.mission.alive_of("host_lances")[0]
	assert_eq(sim.entities.stance[lance - 1], EntityStore.Stance.AGGRESSIVE)


func test_1_2_the_prince_goes_anyway_after_six_minutes() -> void:
	var sim := _sim()
	_check(sim)
	sim.mission.fired["1.1"] = sim.tick - 7200
	_check(sim)
	assert_true(sim.mission.fired.has("1.2"))


func test_3_the_forward_regiment_falls_back_and_hiring_ends() -> void:
	var sim := _sim()
	_check(sim)
	_put(sim, sim.mission.alive_of("riders").slice(0, 1), 48, 48)
	_check(sim)
	assert_true(sim.mission.fired.has("1.2"))
	_kill(sim, "forward", 6)
	_check(sim)
	var m := sim.mission
	assert_true(m.fired.has("3"))
	assert_eq(_state(sim, "forward"), MissionRuntime.Objective.DONE)
	assert_eq(_state(sim, "right"), MissionRuntime.Objective.ACTIVE)
	assert_true(sim.economy.player(P).locked.has(&"gdl_light_horse"), "no more hiring")
	var f := m.alive_of("forward")[0]
	assert_eq(sim.entities.stance[f - 1], EntityStore.Stance.PASSIVE, "they leave in order")
	sim.mission.fired["3"] = sim.tick - 600
	_check(sim)
	assert_true(m.fired.has("4"), "the Large Regiment comes on")
	assert_eq(m.retreat.next_wave, m.fired["4"] + 1800, "waves every 90 seconds")


# --- the ambush -----------------------------------------------------------------------------


func test_2_a_light_horseman_in_the_forest_sees_the_ambush() -> void:
	var sim := _sim()
	_check(sim)
	var rider := sim.mission.alive_of("riders")[0]
	_put(sim, PackedInt32Array([rider]), AMBUSH.x, AMBUSH.y + 9)
	_check(sim)
	assert_true(sim.mission.fired.has("2"))
	assert_eq(_state(sim, "spot"), MissionRuntime.Objective.DONE)
	assert_true(sim.mission.flags.has("spotted"))


func test_2_an_archer_far_off_does_not_but_one_close_does() -> void:
	var sim := _sim()
	_check(sim)
	var archer := sim.mission.alive_of("strelets")[0]
	_put(sim, PackedInt32Array([archer]), AMBUSH.x, AMBUSH.y + 9)
	_check(sim)
	assert_false(sim.mission.fired.has("2"), "only light horse see that far into the forest")
	_put(sim, PackedInt32Array([archer]), AMBUSH.x, AMBUSH.y + 5)
	_check(sim)
	assert_true(sim.mission.fired.has("2"))


func test_warn_half_a_minute_before_the_strike_only_if_spotted() -> void:
	var sim := _sim()
	_check(sim)
	_skip(sim, ["1.2", "2", "4", "5", "5.1", "5.2", "5.3"])
	sim.mission.fired["3"] = sim.tick - 9000
	_check(sim)
	assert_false(sim.mission.fired.has("warn"))
	sim.mission.flags["spotted"] = sim.tick
	_check(sim)
	assert_true(sim.mission.fired.has("warn"))


func test_6_the_forest_moves_and_the_right_edge_is_judged() -> void:
	var sim := _sim()
	_put(sim, sim.mission.alive_of("lances"), RIGHT.x, RIGHT.y)
	_strike(sim)
	_check(sim)
	var m := sim.mission
	for id in m.alive_of("ambush"):
		assert_false(sim.combat.untouchable.has(id), "the ambush can be fought now")
	var a := m.alive_of("ambush")[0]
	assert_eq(sim.entities.stance[a - 1], EntityStore.Stance.AGGRESSIVE)
	assert_true(_kinds(sim).has("cutscene"))
	assert_eq(_state(sim, "right"), MissionRuntime.Objective.DONE)
	assert_eq(_state(sim, "spot"), MissionRuntime.Objective.FAILED, "too late to spot it")


func test_6_away_from_the_right_edge_fails_it() -> void:
	var sim := _sim()
	_strike(sim)
	_check(sim)
	assert_eq(_state(sim, "right"), MissionRuntime.Objective.FAILED)


# --- the icon -------------------------------------------------------------------------------


func test_5_the_icon_holds_muscovite_morale_at_half() -> void:
	var sim := _sim()
	_check(sim)
	_skip(sim, ["1.2", "3", "4"])
	sim.mission.fired["5"] = sim.tick - 200
	_check(sim)
	var m := sim.mission
	assert_true(m.fired.has("5.1"))
	assert_true(m._cast(MOSCOW, &"sp_icon"), "the monk raised the icon")
	var inok := m.alive_of("icon")[0]
	var near := _one(sim, &"mo_syn_boyarsky", MOSCOW, 0, 0)
	sim.entities.pos_x[near - 1] = sim.entities.pos_x[inok - 1]
	sim.entities.pos_y[near - 1] = sim.entities.pos_y[inok - 1]
	sim.combat.lose_morale(near - 1, 1000)
	var half := sim.combat.defs[near - 1].morale / 2
	assert_eq(sim.entities.morale[near - 1], half * CombatSystem.MORALE_SCALE, "not below half")
	var far := _one(sim, &"mo_syn_boyarsky", MOSCOW, 20, 90)
	sim.combat.lose_morale(far - 1, 1000)
	assert_eq(sim.entities.morale[far - 1], 0, "away from the icon it falls as usual")


# --- the bridge -----------------------------------------------------------------------------


func test_7_axemen_ride_for_the_bridge_and_wreck_it_while_they_stand_there() -> void:
	var sim := _sim()
	_strike(sim)
	sim.mission.fired["6"] = sim.tick - 300
	_check(sim)
	var m := sim.mission
	assert_true(m.fired.has("7"))
	assert_eq(_state(sim, "out"), MissionRuntime.Objective.ACTIVE)
	assert_true(m.retreat.bridge_from >= 0, "the wrecking has begun")
	var axemen := m.alive_of("axemen")
	assert_false(sim.combat.untouchable.has(axemen[0]))
	_put(sim, axemen, BRIDGE_E.x, BRIDGE_E.y)
	var before := m.retreat.bridge_hp
	_check(sim)
	assert_eq(m.retreat.bridge_hp, before - axemen.size(), "a point a check for each axeman")
	_put(sim, axemen, 100, 30)
	before = m.retreat.bridge_hp
	_check(sim)
	assert_eq(m.retreat.bridge_hp, before, "driven off, they do no harm")


func test_the_bridge_falls_after_fall_ticks_whatever_happens() -> void:
	var sim := _sim()
	_strike(sim)
	var m := sim.mission
	m.run({"do": "bridge", "on": true}, sim.tick)
	_kill(sim, "axemen")
	sim.run(2900)
	assert_false(m.retreat.bridge_fell)
	sim.run(200)
	assert_true(m.retreat.bridge_fell, "it cannot be saved")


func test_8_the_bridge_falls_into_the_water_with_the_men_on_it() -> void:
	var sim := _sim()
	_strike(sim)
	var m := sim.mission
	var on := m.alive_of("lances").slice(0, 2)
	_put(sim, on, BRIDGE.x, BRIDGE.y)
	m.retreat.bridge_from = sim.tick
	m.run({"do": "bridge", "on": false}, sim.tick)
	sim.run(2)
	for id in on:
		assert_false(sim.entities.is_alive(id), "unit %d went down with the bridge" % id)
	assert_eq(m.retreat.drowned, 2)
	assert_eq(sim.nav.terrain_at(sim.nav.cell_at(BRIDGE.x, BRIDGE.y)), &"t_water")
	var west := sim.nav.cell_at(WEST.x, WEST.y)
	var east := sim.nav.cell_at(EAST.x, EAST.y)
	assert_eq(sim.nav.area(0, west), sim.nav.area(0, east), "the ford still joins the banks")
	_check(sim)
	assert_true(m.fired.has("8"))


func test_8_the_ford_opens_the_orphan_banner_joins_and_the_ring_holds() -> void:
	var sim := _sim()
	_bridge_down(sim)
	var m := sim.mission
	assert_true(m.retreat.ford_on)
	assert_eq(m.retreat.next_wave, -1, "no more waves")
	var orphans := m.alive_of("orphans")
	assert_eq(orphans.size(), 4)
	for id in orphans:
		assert_eq(sim.entities.owners[id - 1], P, "the banner without a standard-bearer is ours")
	assert_eq(m.countdown_end, m.fired["8"] + 6000, "five minutes")
	assert_eq(m.alive_of("ring").size(), 12)
	for id in m.alive_of("hetman_guard"):
		assert_true(sim.combat.untouchable.has(id), "the guard holds by the script")
	assert_eq(_state(sim, "orphans"), MissionRuntime.Objective.ACTIVE)


# --- the ford -------------------------------------------------------------------------------


func test_two_in_the_ford_cross_three_and_the_last_one_drowns() -> void:
	var sim := _sim()
	_check(sim)
	_quiet(sim)
	var m := sim.mission
	m.run({"do": "ford", "on": true}, sim.tick)
	var a := _one(sim, &"gdl_light_horse", P, FORD.x, FORD.y)
	var b := _one(sim, &"gdl_light_horse", P, FORD.x + 1, FORD.y)
	_check(sim)
	assert_eq(sim.entities.hp[a - 1], sim.entities.max_hp[a - 1])
	assert_eq(sim.entities.hp[b - 1], sim.entities.max_hp[b - 1], "two at a time is safe")
	var c := _one(sim, &"gdl_light_horse", P, FORD.x - 1, FORD.y + 1)
	_check(sim)
	assert_eq(sim.entities.hp[a - 1], sim.entities.max_hp[a - 1], "the first ones are fine")
	assert_lt(sim.entities.hp[c - 1], sim.entities.max_hp[c - 1], "the third goes under")
	assert_true(m.flags.has("crowding"))
	for k in 8:
		if sim.entities.is_alive(c):
			_put(sim, PackedInt32Array([a, b, c]), FORD.x, FORD.y)
			_check(sim)
	assert_false(sim.entities.is_alive(c), "and drowns if it stays")
	assert_eq(m.retreat.drowned, 1)


func test_the_ford_is_safe_before_it_opens() -> void:
	var sim := _sim()
	_check(sim)
	_quiet(sim)
	var ids: Array[int] = []
	for k in 4:
		ids.append(_one(sim, &"gdl_light_horse", P, FORD.x - 1 + k % 3, FORD.y + k / 3))
	_check(sim)
	for id in ids:
		assert_eq(sim.entities.hp[id - 1], sim.entities.max_hp[id - 1])


# --- the rescue and the end -----------------------------------------------------------------


func test_only_men_that_crossed_and_came_back_count() -> void:
	var sim := _sim()
	_check(sim)
	var m := sim.mission
	var went := m.alive_of("riders")[0]
	var stayed := m.alive_of("riders")[1]
	_put(sim, PackedInt32Array([went]), EAST.x, EAST.y)
	_check(sim)
	assert_eq(m.retreat.saved(m), 0, "over there, not back yet")
	_put(sim, PackedInt32Array([went]), WEST.x, WEST.y)
	_put(sim, PackedInt32Array([stayed]), WEST.x, WEST.y + 1)
	_check(sim)
	assert_eq(m.retreat.saved(m), 1, "the one that never crossed does not count")


func _to_the_end(sim: Simulation, west: int) -> void:
	_bridge_down(sim)
	var m := sim.mission
	var crossed := 0
	for id in sim.entities.alive_ids:
		if sim.entities.owners[id - 1] == P and m.retreat.crossed.has(id):
			crossed += 1
	var units := PackedInt32Array()
	for id in sim.entities.alive_ids:
		var t := sim.entities.type_ids[id - 1]
		if sim.entities.owners[id - 1] == P and t != &"gdl_camp_servant" and t != &"hero_andrei":
			units.append(id)
	_put(sim, units, EAST.x, EAST.y)
	_check(sim)
	_put(sim, units.slice(0, west), WEST.x, WEST.y)
	_put(sim, m.alive_of("andrei"), WEST.x - 2, WEST.y)
	m.fired["8"] = sim.tick - 6000
	_check(sim)
	assert_true(m.fired.has("10"), "the ring breaks")
	m.fired["10"] = sim.tick - 100
	_check(sim)
	assert_true(m.fired.has("11"), "the list")
	m.fired["11"] = sim.tick - 100
	_check(sim)


func test_10_11_andrei_and_enough_men_over_the_river_end_the_mission() -> void:
	var sim := _sim()
	_to_the_end(sim, 16)
	var m := sim.mission
	assert_eq(m.outcome, MissionRuntime.Outcome.VICTORY, m.outcome_text)
	assert_eq(_state(sim, "fifteen"), MissionRuntime.Objective.DONE, "16 men brought back")
	assert_true(m.alive_of("ostrogski").is_empty() or m.exits.has("ostrogski"), "taken away")
	assert_eq(sim.victory.winner, P)


func test_10_11_fewer_than_five_is_defeat() -> void:
	var sim := _sim()
	_to_the_end(sim, 4)
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.DEFEAT)
	assert_string_contains(sim.mission.outcome_text, "Fewer than five")


func test_10_11_andrei_left_on_the_far_bank_is_defeat() -> void:
	var sim := _sim()
	_bridge_down(sim)
	var m := sim.mission
	_put(sim, m.alive_of("andrei"), EAST.x, EAST.y)
	m.fired["8"] = sim.tick - 6000
	_check(sim)
	m.fired["10"] = sim.tick - 100
	_check(sim)
	m.fired["11"] = sim.tick - 100
	_check(sim)
	assert_eq(m.outcome, MissionRuntime.Outcome.DEFEAT)
	assert_string_contains(m.outcome_text, "far bank")


func test_andrei_killed_is_defeat() -> void:
	var sim := _sim()
	_check(sim)
	_kill(sim, "andrei")
	_check(sim)
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.DEFEAT)


func test_the_player_can_be_taken_captive() -> void:
	var sim := _sim()
	_check(sim)
	_quiet(sim)
	var m := sim.mission
	var rider := _one(sim, &"gdl_light_horse", P, 90, 60)
	sim.entities.morale[rider - 1] = 0
	_one(sim, &"mo_syn_boyarsky", MOSCOW, 89, 60)
	_one(sim, &"mo_syn_boyarsky", MOSCOW, 91, 60)
	_check(sim)
	assert_false(sim.entities.is_alive(rider), "beaten and surrounded, he is led away")
	assert_eq(m.captives, 1)


# --- state ----------------------------------------------------------------------------------


func test_save_and_load_keep_the_bridge_the_ford_and_the_rescue() -> void:
	var sim := _sim()
	_bridge_down(sim)
	sim.run(300)
	var data := SimSave.capture(sim)
	var loaded := SimSave.restore(data, _db)
	assert_not_null(loaded)
	assert_eq(loaded.state_hash(), data["hash"])
	assert_true(loaded.mission.retreat.bridge_fell)
	assert_eq(loaded.mission.retreat.crossed, sim.mission.retreat.crossed)
	assert_eq(
		loaded.nav.terrain_at(loaded.nav.cell_at(BRIDGE.x, BRIDGE.y)), &"t_water", "still down"
	)
	sim.run(600)
	loaded.run(600)
	assert_eq(loaded.state_hash(), sim.state_hash(), "and it plays on the same")


func test_the_bridge_and_the_ford_change_the_hash() -> void:
	var a := _sim()
	var b := _sim()
	b.mission.retreat.bridge_hp -= 1
	assert_ne(a.state_hash(), b.state_hash())
	var c := _sim()
	c.mission.retreat.ford_in[1] = 0
	assert_ne(a.state_hash(), c.state_hash())
