# gdlint:ignore = max-public-methods
extends GutTest
## «ВКЛ 6. Волчья тропа, 1507»: one test per trigger of the mission card and per rule of its own
## (MissionStealth: the watch's eyes, ears and dogs, the meter and the alarm, campfires and the
## forest, night and day, the horses, the stable, hidden places of power, «Волчья тропа», the
## Keeper's gať, the chase). The world is put into the condition and the result is checked;
## earlier triggers a test does not need are marked as fired by hand.

const MISSION := "gdl_06"
const P := 1
const MOSCOW := 2
const CHECK := MissionRuntime.CHECK_EVERY
## Open grass in the camp clearing, far from the campfires; forest south of the chapel.
const OPEN := Vector2i(140, 58)
const FOREST := Vector2i(120, 55)
const PINE := Vector2i(117, 31)
const STABLE_BY := Vector2i(93, 28)
const CHAPEL := Vector2i(130, 44)
const GAT := Vector2i(60, 60)
const FORD := Vector2i(19, 46)
const LITHUANIA := Vector2i(8, 45)

var _db: CatalogDB


func before_all() -> void:
	_db = CatalogDB.load_prototype()


func _sim(difficulty := "normal") -> Simulation:
	var sim := MissionSetup.new_simulation(MISSION, 1, _db, difficulty)
	assert_not_null(sim)
	return sim


func _skip(sim: Simulation, ids: Array[String]) -> void:
	for tid in ids:
		sim.mission.fired[tid] = sim.tick


func _check(sim: Simulation) -> void:
	sim.run(CHECK + 1)


func _events(sim: Simulation, kind: String) -> Array:
	var out := []
	for e: Dictionary in sim.mission.events:
		if e["kind"] == kind:
			out.append(e)
	return out


func _has_event(sim: Simulation, kind: String, id: String) -> bool:
	for e: Dictionary in _events(sim, kind):
		if e.get("id", "") == id:
			return true
	return false


func _state(sim: Simulation, oid: String) -> int:
	return sim.mission.objective_state.get(oid, -1)


func _put(sim: Simulation, ids: PackedInt32Array, cx: int, cy: int) -> void:
	for id in ids:
		sim.entities.pos_x[id - 1] = Fixed.from_cells(cx) + Fixed.HALF
		sim.entities.pos_y[id - 1] = Fixed.from_cells(cy) + Fixed.HALF
		sim.entities.stop(id)


func _one(sim: Simulation, type: StringName, p: int, cx: int, cy: int) -> int:
	return sim.spawn_unit(
		type, p, Fixed.from_cells(cx) + Fixed.HALF, Fixed.from_cells(cy) + Fixed.HALF
	)


func _prince(sim: Simulation) -> int:
	return sim.mission.alive_of("prince")[0]


## The watch taken off the map, the servants too: only the prince and what a test puts there.
func _alone(sim: Simulation) -> void:
	for id in sim.entities.alive_ids.duplicate():
		var o := sim.entities.owners[id - 1]
		if o == MOSCOW or sim.entities.type_ids[id - 1] == &"gdl_light_horse":
			sim.remove_unit(id)


## A watchman standing at (cx, cy) and facing (fx, fy), passive as the posts are.
func _watchman(sim: Simulation, cx: int, cy: int, fx: int, fy: int) -> int:
	var w := _one(sim, &"mo_storozha", MOSCOW, cx, cy)
	sim.entities.stance[w - 1] = EntityStore.Stance.PASSIVE
	var d := Fixed.isqrt(fx * fx + fy * fy)
	sim.entities.facing_x[w - 1] = fx * Fixed.ONE / d
	sim.entities.facing_y[w - 1] = fy * Fixed.ONE / d
	return w


func _terrain(sim: Simulation, c: Vector2i) -> StringName:
	return sim.nav.terrain_at(sim.nav.cell_at(c.x, c.y))


# --- setup ----------------------------------------------------------------------------------


func test_the_band_the_watch_and_the_map_are_set_up() -> void:
	var sim := _sim()
	var m := sim.mission
	sim.run(2)
	assert_eq(sim.nav.width, 160)
	assert_eq(sim.nav.height, 90)
	assert_true(sim.sides.hostile(P, MOSCOW))
	assert_eq(sim.economy.player(MOSCOW).faction, &"mo")
	assert_eq(m.alive_of("prince").size(), 1)
	assert_eq(sim.entities.type_ids[_prince(sim) - 1], &"hero_ostrogski_fugitive")
	assert_eq(m.alive_of("servants").size(), 3, "three servants on horseback")
	for g: String in ["post_camp_n", "post_gap", "post_ford", "patrol_camp", "patrol_road"]:
		assert_gt(m.alive_of(g).size(), 1, "%s stands" % g)
	assert_true(m.named.has("stable") and m.named.has("tower") and m.named.has("camp"))
	assert_eq(sim.magic.places.count(), 3, "the pine, the boulder, the island")
	assert_eq(sim.magic.places.hidden.size(), 3, "all three hidden")
	assert_true(m.stealth.on and m.stealth.night, "the watch looks, and it is night")
	assert_eq(m.stealth.stamina.size(), 4, "four horses")
	assert_true(_has_event(sim, "cutscene", "seven_years"))
	assert_eq(_state(sim, "leave"), MissionRuntime.Objective.ACTIVE)
	assert_eq(_state(sim, "quiet"), MissionRuntime.Objective.ACTIVE)


func test_the_zaseka_is_closed_but_for_the_gap_and_the_bog_but_for_the_road() -> void:
	var sim := _sim()
	var nav := sim.nav
	var foot := NavGrid.MoveClass.FOOT
	for y: int in [10, 20, 35, 52, 70, 85]:
		var shut := false
		for x in range(103, 112):
			shut = shut or not nav.passable(foot, nav.cell_at(x, y))
		assert_true(shut, "row %d of the zaseka is shut" % y)
	assert_true(nav.passable(foot, nav.cell_at(107, 46)), "the gap on the road")
	assert_false(nav.passable(foot, nav.cell_at(45, 30)), "the quagmire")
	assert_false(nav.passable(foot, nav.cell_at(50, 53)), "where the gať will be")
	assert_true(nav.passable(foot, nav.cell_at(15, 45)), "the border ford")
	assert_false(nav.passable(foot, nav.cell_at(15, 30)), "the river elsewhere")
	assert_false(nav.passable(foot, nav.cell_at(130, 43)), "the chapel stands on its cell")


# --- the watch ------------------------------------------------------------------------------


func test_a_watchman_sees_a_rider_in_front_of_him_not_behind() -> void:
	var sim := _sim()
	_alone(sim)
	var m := sim.mission
	var prince := _prince(sim)
	_put(sim, PackedInt32Array([prince]), OPEN.x, OPEN.y)
	var w := _watchman(sim, OPEN.x + 5, OPEN.y, 1, 0)
	_check(sim)
	assert_eq(m.stealth.meter, 0, "5 cells at night, beyond the dogs, but behind him")
	sim.entities.facing_x[w - 1] = -Fixed.ONE
	sim.entities.facing_y[w - 1] = 0
	_check(sim)
	assert_gt(m.stealth.meter, 0, "facing the prince he sees him")


func test_night_halves_the_sight_and_a_campfire_doubles_it() -> void:
	var sim := _sim()
	_alone(sim)
	var m := sim.mission
	var prince := _prince(sim)
	# Sight 10, at night 5: from 7 cells he is not seen.
	_put(sim, PackedInt32Array([prince]), OPEN.x, OPEN.y)
	_watchman(sim, OPEN.x + 7, OPEN.y, -1, 0)
	_check(sim)
	assert_eq(m.stealth.meter, 0, "7 cells at night")
	m.run({"do": "daylight", "night": false}, sim.tick)
	_check(sim)
	assert_gt(m.stealth.meter, 0, "by day he sees 10 cells")
	var sim2 := _sim()
	_alone(sim2)
	var p2 := _prince(sim2)
	# By the camp's campfire at (143, 47): within 3 cells the light doubles the sight.
	_put(sim2, PackedInt32Array([p2]), 143, 49)
	_watchman(sim2, 143, 57, 0, -1)
	_check(sim2)
	assert_gt(sim2.mission.stealth.meter, 0, "8 cells off, but in the fire's light")


func test_in_the_forest_the_prince_is_not_seen_a_servant_only_close_up() -> void:
	var sim := _sim()
	var m := sim.mission
	for id in sim.entities.alive_ids.duplicate():
		if sim.entities.owners[id - 1] == MOSCOW:
			sim.remove_unit(id)
	assert_eq(_terrain(sim, FOREST), NavGrid.FOREST)
	_put(sim, m.alive_of("servants"), 0, 0)
	_put(sim, PackedInt32Array([_prince(sim)]), FOREST.x, FOREST.y)
	# A rider without dogs: only his eyes.
	var w := _one(sim, &"mo_syn_boyarsky", MOSCOW, FOREST.x + 2, FOREST.y)
	sim.entities.facing_x[w - 1] = -Fixed.ONE
	sim.entities.facing_y[w - 1] = 0
	sim.enqueue(
		SimCommand.set_stance(sim.tick, MOSCOW, PackedInt32Array([w]), EntityStore.Stance.PASSIVE)
	)
	_check(sim)
	assert_eq(m.stealth.meter, 0, "the prince in the forest, 2 cells off")
	var servant := m.alive_of("servants")[0]
	_put(sim, PackedInt32Array([_prince(sim)]), 0, 2)
	_put(sim, PackedInt32Array([servant]), FOREST.x, FOREST.y)
	_check(sim)
	assert_gt(m.stealth.meter, 0, "a servant 2 cells off in the forest")


func test_dogs_smell_whoever_is_near_even_behind_and_a_trot_is_heard() -> void:
	var sim := _sim()
	_alone(sim)
	var m := sim.mission
	var prince := _prince(sim)
	_put(sim, PackedInt32Array([prince]), FOREST.x, FOREST.y)
	var w := _watchman(sim, FOREST.x + 3, FOREST.y, 1, 0)
	_check(sim)
	assert_gt(m.stealth.meter, 0, "the dogs smell him in the forest, behind the man")
	assert_lt(sim.entities.facing_x[w - 1], 0, "and the man turns that way")


func test_a_full_meter_raises_the_alarm_and_the_watch_rides_there() -> void:
	var sim := _sim()
	var m := sim.mission
	var prince := _prince(sim)
	m.stealth.meter = MissionStealth.FULL - 1
	var w := _watchman(sim, OPEN.x + 3, OPEN.y, -1, 0)
	_put(sim, PackedInt32Array([prince]), OPEN.x, OPEN.y)
	_check(sim)
	assert_eq(m.stealth.alarms, 1)
	assert_true(m.flags.has("alarm"))
	assert_true(m.stealth.roused.has(w), "the watchman near is roused")
	assert_eq(sim.entities.stance[w - 1], EntityStore.Stance.AGGRESSIVE)
	assert_eq(_state(sim, "quiet"), MissionRuntime.Objective.FAILED)
	assert_eq(_state(sim, "leave"), MissionRuntime.Objective.FAILED, "the alarm before leaving")
	assert_eq(m.stealth.meter, 300, "the meter falls back")
	_check(sim)
	assert_eq(m.stealth.meter, 300, "and does not rise again at once")
	assert_eq(m.stealth.alarms, 1)


func test_the_meter_decays_when_nobody_notices() -> void:
	var sim := _sim()
	_alone(sim)
	var m := sim.mission
	m.stealth.meter = 500
	_check(sim)
	assert_lt(m.stealth.meter, 500)


func test_leaving_the_camp_quietly_is_done() -> void:
	var sim := _sim()
	_alone(sim)
	_put(sim, PackedInt32Array([_prince(sim)]), 120, 40)
	_check(sim)
	assert_eq(_state(sim, "leave"), MissionRuntime.Objective.DONE)


# --- the horses -----------------------------------------------------------------------------


func test_leading_the_horses_is_quiet_slow_and_rests_them() -> void:
	var sim := _sim()
	_alone(sim)
	var m := sim.mission
	var prince := _prince(sim)
	var ids := PackedInt32Array([prince])
	sim.enqueue(SimCommand.order(sim.tick, P, SimCommand.Kind.DISMOUNT, ids))
	sim.run(2)
	assert_true(m.stealth.walking.has(prince))
	assert_true(m.stealth.at_walk(prince))
	assert_eq(m.stealth.speed(prince, 1000, m), 500)
	sim.enqueue(SimCommand.order(sim.tick, P, SimCommand.Kind.DISMOUNT, ids))
	sim.run(2)
	assert_false(m.stealth.walking.has(prince), "V again: ride")
	assert_eq(m.stealth.speed(prince, 1000, m), 1000)


func test_a_trot_tires_the_horse_and_a_tired_horse_walks() -> void:
	var sim := _sim()
	_alone(sim)
	var m := sim.mission
	var prince := _prince(sim)
	_put(sim, PackedInt32Array([prince]), 130, 58)
	sim.enqueue(SimCommand.move(sim.tick, P, PackedInt32Array([prince]), _fx(150), _fx(58)))
	sim.run(100)
	assert_lt(m.stealth.stamina[prince], MissionStealth.FULL)
	m.stealth.stamina[prince] = 5
	sim.enqueue(SimCommand.move(sim.tick, P, PackedInt32Array([prince]), _fx(120), _fx(58)))
	sim.run(30)
	assert_true(m.stealth.tired.has(prince))
	assert_true(m.stealth.at_walk(prince))
	m.stealth.stamina[prince] = 290
	sim.entities.stop(prince)
	_check(sim)
	assert_false(m.stealth.tired.has(prince), "rested enough, it may trot again")


func test_fresh_horses_at_the_stable_cost_the_alarm() -> void:
	var sim := _sim()
	var m := sim.mission
	var band := m.stealth.fugitives(m)
	for id in band:
		m.stealth.stamina[id] = 100
	_put(sim, band, STABLE_BY.x, STABLE_BY.y)
	_check(sim)
	assert_true(m.stealth.stable_used)
	assert_true(m.flags.has("fresh_horses"))
	assert_eq(m.stealth.alarms, 1)
	for id in band:
		assert_eq(m.stealth.stamina[id], MissionStealth.FULL)


# --- places of power and «Волчья тропа» -----------------------------------------------------


func test_3_the_old_pine_is_found_close_up_and_gives_one_charge() -> void:
	var sim := _sim()
	_alone(sim)
	var m := sim.mission
	_put(sim, PackedInt32Array([_prince(sim)]), PINE.x + 9, PINE.y)
	_check(sim)
	assert_false(m.stealth.found.has(0), "9 cells off it stays hidden")
	_put(sim, PackedInt32Array([_prince(sim)]), PINE.x + 4, PINE.y)
	_check(sim)
	assert_true(m.stealth.found.has(0))
	assert_false(sim.magic.places.hidden.has(0))
	assert_eq(sim.economy.player(P).power, 150 * MagicSystem.POWER_UNIT)
	assert_true(_has_event(sim, "dialogue", "cuts_on_the_pine"))


func test_the_wolf_trail_opens_through_old_forest_and_closes_again() -> void:
	var sim := _sim()
	_alone(sim)
	var m := sim.mission
	var prince := _prince(sim)
	var through := Vector2i(106, 25)
	assert_eq(_terrain(sim, through), &"t_old_forest")
	_put(sim, PackedInt32Array([prince]), PINE.x, PINE.y)
	_check(sim)
	var wolf := sim.magic.spells_of(prince).filter(
		func(s: SpellDef) -> bool: return s.id == &"sp_wolf_path"
	)
	assert_eq(wolf.size(), 1, "the prince may cast it on the place")
	var x := sim.entities.pos_x[prince - 1]
	var y := sim.entities.pos_y[prince - 1]
	var ids := PackedInt32Array([prince])
	sim.enqueue(SimCommand.cast(sim.tick, P, ids, &"sp_wolf_path", x, y))
	_check(sim)
	_check(sim)
	assert_true(m.flags.has("trail_0"))
	assert_eq(_terrain(sim, through), &"t_road", "the trail is open")
	assert_eq(sim.economy.player(P).power, 0, "the charge is spent")
	sim.run(1300)
	assert_eq(_terrain(sim, through), &"t_old_forest", "and closed again")
	assert_false(m.stealth.path_until.has(0))


func test_the_wolf_trail_is_cast_only_on_a_found_place() -> void:
	var sim := _sim()
	_alone(sim)
	var prince := _prince(sim)
	sim.economy.player(P).power = 150 * MagicSystem.POWER_UNIT
	_put(sim, PackedInt32Array([prince]), OPEN.x, OPEN.y)
	_check(sim)
	assert_true(sim.magic.spells_of(prince).is_empty(), "nothing to cast in the open")
	var ids := PackedInt32Array([prince])
	sim.enqueue(SimCommand.cast(sim.tick, P, ids, &"sp_wolf_path", _fx(OPEN.x), _fx(OPEN.y)))
	_check(sim)
	assert_eq(sim.economy.player(P).power, 150 * MagicSystem.POWER_UNIT, "nothing spent")


func test_dogs_find_no_scent_on_an_open_trail() -> void:
	var sim := _sim()
	_alone(sim)
	var m := sim.mission
	m.run({"do": "open_path", "place": 0, "ticks": -1}, sim.tick)
	_put(sim, PackedInt32Array([_prince(sim)]), 106, 25)
	_watchman(sim, 106, 28, 1, 0)
	_check(sim)
	assert_eq(m.stealth.meter, 0, "on the trail, 3 cells from the dogs")


# --- triggers -------------------------------------------------------------------------------


func test_2_the_prince_at_the_chapel() -> void:
	var sim := _sim()
	_alone(sim)
	_put(sim, PackedInt32Array([_prince(sim)]), CHAPEL.x + 2, CHAPEL.y + 2)
	_check(sim)
	assert_true(_has_event(sim, "cutscene", "kissing_the_cross"))


func test_4_past_the_zaseka_it_dawns() -> void:
	var sim := _sim()
	_alone(sim)
	var m := sim.mission
	_put(sim, PackedInt32Array([_prince(sim)]), 100, 40)
	_check(sim)
	assert_eq(_state(sim, "zaseka"), MissionRuntime.Objective.DONE)
	assert_eq(_state(sim, "ford"), MissionRuntime.Objective.ACTIVE)
	assert_false(m.stealth.night)
	assert_eq(m.countdown_text, "Sunset in %s")


func test_5_at_noon_they_find_him_gone_and_the_chase_is_due() -> void:
	var sim := _sim()
	_alone(sim)
	var m := sim.mission
	_check(sim)
	m.fired["4"] = sim.tick - 3000
	_check(sim)
	assert_true(_has_event(sim, "dialogue", "the_prince_is_gone"))
	assert_gt(m.stealth.pursuit_at, sim.tick + 7000)


func test_5_an_alarm_brings_the_chase_sooner() -> void:
	var sim := _sim()
	var m := sim.mission
	m.stealth.meter = MissionStealth.FULL
	_watchman(sim, OPEN.x + 2, OPEN.y, -1, 0)
	_put(sim, PackedInt32Array([_prince(sim)]), OPEN.x, OPEN.y)
	_check(sim)
	_check(sim)
	assert_true(m.fired.has("5"), "the alarm wakes the camp")
	var due := m.stealth.pursuit_at
	m.stealth.calm_until = 0
	m.stealth.meter = MissionStealth.FULL
	_check(sim)
	assert_eq(m.stealth.pursuit_at, maxi(due - 1200, sim.tick - CHECK), "each alarm cuts it")


func test_sunset_brings_the_second_night() -> void:
	var sim := _sim()
	_alone(sim)
	var m := sim.mission
	_check(sim)
	m.run({"do": "daylight", "night": false}, sim.tick)
	m.fired["4"] = sim.tick - 6000
	m.fired["5"] = sim.tick
	_check(sim)
	assert_true(m.stealth.night)


func test_6_the_keeper_leads_over_the_gat_at_night_only() -> void:
	var sim := _sim()
	_alone(sim)
	var m := sim.mission
	_check(sim)
	_put(sim, PackedInt32Array([_prince(sim)]), GAT.x, GAT.y)
	_check(sim)
	assert_false(m.fired.has("6"), "not on the first night")
	_skip(sim, ["4", "5", "sunset"])
	m.run({"do": "daylight", "night": true}, sim.tick)
	_check(sim)
	assert_true(m.fired.has("6"))
	assert_true(_has_event(sim, "cutscene", "the_guide"))
	assert_eq(m.alive_of("keeper").size(), 1)
	assert_eq(sim.entities.owners[m.alive_of("keeper")[0] - 1], 3, "she takes no orders")
	assert_eq(m.stealth.path_until[2], -1, "the gať stays open")
	assert_eq(_terrain(sim, Vector2i(52, 53)), &"t_road")
	assert_true(sim.nav.passable(NavGrid.MoveClass.FOOT, sim.nav.cell_at(52, 53)))


func test_near_the_keeper_the_watch_suspects_nothing() -> void:
	var sim := _sim()
	_alone(sim)
	var m := sim.mission
	var prince := _prince(sim)
	_put(sim, PackedInt32Array([prince]), OPEN.x, OPEN.y)
	var keeper := {
		"do": "spawn",
		"group": "keeper",
		"player": 3,
		"at": [OPEN.x + 1, OPEN.y],
		"untouchable": true,
		"units": [["hero_keeper", 1]],
	}
	m.run(keeper, sim.tick)
	_watchman(sim, OPEN.x + 3, OPEN.y, -1, 0)
	_check(sim)
	assert_eq(m.stealth.meter, 0)


func test_7_near_the_ford_andrei_takes_over() -> void:
	var sim := _sim()
	_alone(sim)
	var m := sim.mission
	_put(sim, PackedInt32Array([_prince(sim)]), 30, 47)
	_check(sim)
	assert_true(m.fired.has("7"))
	assert_eq(_state(sim, "ford"), MissionRuntime.Objective.DONE)
	assert_eq(_state(sim, "hold"), MissionRuntime.Objective.ACTIVE)
	assert_true(_has_event(sim, "cutscene", "the_other_bank"))
	for g: String in ["andrei", "lances", "riders", "archers"]:
		assert_gt(m.alive_of(g).size(), 0, "%s on the Lithuanian bank" % g)
		assert_eq(sim.entities.owners[m.alive_of(g)[0] - 1], P)
	assert_eq(m.alive_of("lances").size(), 6)
	assert_false(m.stealth.on, "no more hiding")
	assert_gte(m.stealth.pursuit_at, 0, "the chase comes now if it has not yet")


func test_the_chase_sets_out_when_due_scaled_by_difficulty() -> void:
	for d: String in ["easy", "normal"]:
		var sim := _sim(d)
		_alone(sim)
		var m := sim.mission
		m.run({"do": "pursuit", "ticks": 0}, sim.tick)
		_check(sim)
		var chase := m.alive_of("chase")
		assert_eq(chase.size(), 11 if d == "easy" else 15, d)
		assert_eq(sim.entities.type_ids[chase[0] - 1], &"hero_nezhdan")


func test_the_chase_holding_the_ford_before_the_prince_is_defeat() -> void:
	var sim := _sim()
	_alone(sim)
	var m := sim.mission
	_put(sim, PackedInt32Array([_prince(sim)]), 140, 58)
	m.run({"do": "pursuit", "ticks": 0}, sim.tick)
	_check(sim)
	_put(sim, m.alive_of("chase"), FORD.x, FORD.y)
	sim.run(500)
	assert_eq(m.outcome, MissionRuntime.Outcome.DEFEAT)


func test_9_the_prince_on_the_lithuanian_bank_wins() -> void:
	var sim := _sim()
	var m := sim.mission
	for id in sim.entities.alive_ids.duplicate():
		if sim.entities.owners[id - 1] == MOSCOW:
			sim.remove_unit(id)
	_put(sim, PackedInt32Array([_prince(sim)]), 30, 47)
	_check(sim)
	_put(sim, m.stealth.fugitives(m), LITHUANIA.x, LITHUANIA.y)
	_check(sim)
	assert_true(m.fired.has("9"))
	assert_eq(_state(sim, "hold"), MissionRuntime.Objective.DONE)
	assert_true(_has_event(sim, "cutscene", "at_the_ford"))
	sim.run(120)
	assert_eq(m.outcome, MissionRuntime.Outcome.VICTORY)
	assert_eq(_state(sim, "servants"), MissionRuntime.Objective.DONE)
	assert_eq(_state(sim, "quiet"), MissionRuntime.Objective.DONE)
	assert_eq(_state(sim, "places"), MissionRuntime.Objective.FAILED, "none was found")


func test_all_three_places_found_is_done() -> void:
	var sim := _sim()
	var m := sim.mission
	for i in 3:
		m.run({"do": "reveal", "place": i}, sim.tick)
	_check(sim)
	assert_eq(_state(sim, "places"), MissionRuntime.Objective.DONE)
	assert_eq(
		sim.economy.player(P).power,
		mini(450, sim.magic.rules.power_cap) * MagicSystem.POWER_UNIT,
		"a charge each, up to the cap"
	)


func test_a_servant_lost_fails_the_optional_objective() -> void:
	var sim := _sim()
	sim.remove_unit(sim.mission.alive_of("servants")[0])
	_check(sim)
	assert_eq(_state(sim, "servants"), MissionRuntime.Objective.FAILED)


func test_the_prince_killed_is_defeat() -> void:
	var sim := _sim()
	sim.remove_unit(_prince(sim))
	_check(sim)
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.DEFEAT)


# --- state ----------------------------------------------------------------------------------


func test_save_and_load_keep_the_watch_the_trails_and_the_horses() -> void:
	var sim := _sim()
	var m := sim.mission
	m.run({"do": "open_path", "place": 0, "ticks": 2000}, sim.tick)
	m.stealth.meter = 400
	m.stealth.stamina[_prince(sim)] = 321
	sim.run(50)
	var data := SimSave.capture(sim)
	var loaded := SimSave.restore(data, _db)
	assert_not_null(loaded)
	assert_eq(loaded.state_hash(), data["hash"])
	assert_eq(_terrain(loaded, Vector2i(106, 25)), &"t_road")
	assert_eq(loaded.mission.stealth.path_until[0], m.stealth.path_until[0])
	assert_eq(loaded.magic.places.hidden.size(), 3)
	sim.run(2400)
	loaded.run(2400)
	assert_eq(loaded.state_hash(), sim.state_hash(), "and it plays on the same")
	assert_eq(_terrain(loaded, Vector2i(106, 25)), &"t_old_forest")


func test_the_watch_and_hidden_places_change_the_hash() -> void:
	var a := _sim()
	var b := _sim()
	b.mission.stealth.meter += 1
	assert_ne(a.state_hash(), b.state_hash())
	var c := _sim()
	c.magic.places.hidden.erase(1)
	assert_ne(a.state_hash(), c.state_hash())
	var d := _sim()
	d.mission.stealth.walking[_prince(d)] = true
	assert_ne(a.state_hash(), d.state_hash())


static func _fx(cell: int) -> int:
	return Fixed.from_cells(cell) + Fixed.HALF
