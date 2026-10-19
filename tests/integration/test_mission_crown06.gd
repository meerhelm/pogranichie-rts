# gdlint:ignore = max-public-methods
extends GutTest
## «Корона 6. Свецино, 1462»: one test per trigger of the mission card and per rule of
## MissionSwiecino (hiring companies for silver and paying them, the ditch round the tabor, the
## horses tiring, the crossbows in the reeds, Dunin's command in Stach's hands, Raweneck's death
## and the prisoners). The world is put into the condition and the result is checked; earlier
## triggers a test does not need are marked as fired by hand.

const MISSION := "crown_06"
const P := 1
const ORDER := 2
const DUNIN_TENT := 3
const CHECK := MissionRuntime.CHECK_EVERY
const CAMP := Vector2i(46, 74)
const ORDER_CAMP := Vector2i(74, 20)
const FIELD := Vector2i(70, 45)
## Before the reeds, in the crossbows' zone.
const ZONE := Vector2i(40, 56)
const REEDS := Vector2i(32, 60)
## Out in the east, away from both camps and the zone.
const FAR := Vector2i(95, 50)

var _db: CatalogDB


func before_all() -> void:
	_db = CatalogDB.load_prototype()


func _sim(difficulty: String = "normal") -> Simulation:
	var sim := MissionSetup.new_simulation(MISSION, 1, _db, difficulty)
	assert_not_null(sim)
	return sim


func _skip(sim: Simulation, ids: Array[String]) -> void:
	for tid in ids:
		if not sim.mission.fired.has(tid):
			sim.mission.fired[tid] = sim.tick


func _check(sim: Simulation) -> void:
	sim.run(CHECK + 1)


func _has_event(sim: Simulation, kind: String, id: String = "") -> bool:
	for e: Dictionary in sim.mission.events:
		if e["kind"] == kind and (id.is_empty() or e.get("id", "") == id):
			return true
	return false


func _has_hint(sim: Simulation, text: String) -> bool:
	for e: Dictionary in sim.mission.events:
		if e["kind"] == "hint" and e.get("text", "") == text:
			return true
	return false


func _state(sim: Simulation, oid: String) -> int:
	return sim.mission.objective_state.get(oid, -1)


func _put(sim: Simulation, ids: PackedInt32Array, c: Vector2i) -> void:
	for id in ids:
		sim.entities.pos_x[id - 1] = _fx(c.x)
		sim.entities.pos_y[id - 1] = _fx(c.y)
		sim.entities.stop(id)


func _one(sim: Simulation, type: StringName, p: int, c: Vector2i) -> int:
	return sim.spawn_unit(type, p, _fx(c.x), _fx(c.y))


func _silver(sim: Simulation) -> int:
	return sim.economy.player(P).stock[EconomySystem.SILVER]


func _set_silver(sim: Simulation, n: int) -> void:
	sim.economy.player(P).stock[EconomySystem.SILVER] = n


func _rules(sim: Simulation) -> Dictionary:
	return sim.mission.def.rules["swiecino"]


## Fires the triggers by hand: runs their actions and marks them fired.
func _fire(sim: Simulation, ids: Array[String]) -> void:
	var m := sim.mission
	for tid in ids:
		for t: Dictionary in m.def.triggers:
			if t["id"] == tid and not m.fired.has(tid):
				m.fired[tid] = sim.tick
				for a: Dictionary in t["do"]:
					m.run(a, sim.tick)


## Past the night and the dawn, hiring over: the Order is not on the field yet.
func _morning(sim: Simulation) -> void:
	sim.run(220)
	sim.mission.run({"do": "hire", "on": false}, sim.tick)


## The Order's army on the field (trigger 3), the fight not begun.
func _order(sim: Simulation) -> void:
	_morning(sim)
	_fire(sim, ["3", "3_normal"])


## Answers the hire question now open with `option`.
func _hire(sim: Simulation, option: int) -> void:
	var q := sim.mission.swiecino.question
	assert_false(q.is_empty(), "a hire question is open")
	sim.enqueue(SimCommand.choose(sim.tick, P, StringName(q), option))
	_check(sim)


func _count(sim: Simulation, p: int, type: StringName) -> int:
	var n := 0
	for id in sim.entities.alive_ids:
		if sim.entities.owners[id - 1] == p and sim.entities.type_ids[id - 1] == type:
			n += 1
	return n


# --- setup ----------------------------------------------------------------------------------


func test_crown_6_is_made_and_playable() -> void:
	assert_true(CampaignProgress.is_made("crown_06"))
	assert_eq(CampaignProgress.title_key("crown_06"), "Crown 6. Świecino, 1462")


func test_the_field_the_camp_and_the_sides_are_set_up() -> void:
	var sim := _sim()
	var m := sim.mission
	assert_eq(sim.nav.width, 140)
	assert_eq(sim.nav.height, 100)
	assert_true(m.swiecino.on)
	assert_true(sim.sides.friendly(P, DUNIN_TENT), "Dunin's tent is ours")
	assert_true(sim.sides.hostile(P, ORDER))
	assert_eq(_silver(sim), 600)
	assert_eq(m.alive_of("wagons").size(), 8)
	assert_eq(m.alive_of("lances").size(), 4)
	assert_eq(m.alive_of("crossbows").size(), 4)
	assert_eq(m.alive_of("dunin").size(), 1)
	assert_eq(sim.magic.places.count(), 3, "the cross, the chapel, the boulder")
	assert_eq(sim.nav.terrain_at(sim.nav.cell_at(REEDS.x, REEDS.y)), &"t_bog", "the reeds")


func test_the_pact_is_closed_all_through_the_mission() -> void:
	var sim := _sim()
	assert_true(sim.economy.player(P).locked.has(&"sp_pact"))
	sim.run(300)
	assert_true(sim.economy.player(P).locked.has(&"sp_pact"))


# --- 1, 2: the night and the dawn -------------------------------------------------------------


func test_1_the_stranger_asks_stach_and_stach_says_grandfather_paid() -> void:
	var sim := _sim()
	_check(sim)
	assert_true(_has_event(sim, "cutscene", "last_reckoning"))
	var said := false
	for e: Dictionary in sim.mission.events:
		if e.get("id", "") == "last_reckoning":
			for line: Array in e["lines"]:
				said = said or (line[0] == "hero_stach" and line[1] == "Grandfather paid.")
	assert_true(said, "«Дед заплатил.»")
	assert_eq(sim.mission.alive_of("stranger").size(), 1)
	sim.run(200)
	assert_eq(sim.mission.alive_of("stranger").size(), 0, "he is gone with the candle")


func test_2_the_dawn_opens_the_hiring_and_the_chapels() -> void:
	var sim := _sim()
	sim.run(220)
	var m := sim.mission
	assert_true(m.fired.has("2"))
	assert_eq(_state(sim, "tabor"), MissionRuntime.Objective.ACTIVE)
	assert_eq(_state(sim, "hire"), MissionRuntime.Objective.ACTIVE)
	assert_true(m.swiecino.hiring)
	assert_true(m.choices.has(m.swiecino.question), "the captains are asked about")
	assert_false(sim.economy.player(P).locked.has(&"pl_shrine"))


# --- hiring and wages -------------------------------------------------------------------------


func test_hiring_a_company_takes_its_silver_and_asks_again() -> void:
	var sim := _sim()
	sim.run(220)
	var horse := _count(sim, P, &"pl_merc_horse")
	_hire(sim, 0)
	assert_eq(_count(sim, P, &"pl_merc_horse"), horse + 1)
	assert_eq(_silver(sim), 520)
	assert_eq(sim.mission.swiecino.hired_horse, 1)
	assert_eq(_state(sim, "hire"), MissionRuntime.Objective.DONE)
	assert_true(sim.mission.choices.has(sim.mission.swiecino.question), "asked again")
	_hire(sim, 3)
	assert_eq(_count(sim, P, &"pl_drab"), 3)
	assert_eq(sim.mission.swiecino.hired_foot, 1)
	assert_eq(_silver(sim), 485)


func test_no_more_than_five_horse_and_two_foot_are_hired() -> void:
	var sim := _sim()
	sim.run(220)
	_set_silver(sim, 2000)
	for k in 6:
		_hire(sim, 1)
	assert_eq(sim.mission.swiecino.hired_horse, 5)
	_check(sim)
	assert_true(_has_hint(sim, "No more horse can be hired on this silver."))
	for k in 3:
		_hire(sim, 3)
	assert_eq(sim.mission.swiecino.hired_foot, 2)
	_check(sim)
	assert_true(_has_hint(sim, "No more foot can be hired on this silver."))


func test_no_company_without_its_silver() -> void:
	var sim := _sim()
	sim.run(220)
	_set_silver(sim, 100)
	_hire(sim, 2)
	assert_eq(sim.mission.swiecino.hired_horse, 0, "a lance costs 120")
	assert_eq(_silver(sim), 100)
	_check(sim)
	assert_true(_has_hint(sim, "There is not enough silver in the company's chest."))


func test_enough_ends_the_hiring() -> void:
	var sim := _sim()
	sim.run(220)
	_hire(sim, 4)
	assert_false(sim.mission.swiecino.hiring)
	assert_true(sim.mission.flags.has("hiring_over"))
	assert_true(sim.mission.swiecino.question.is_empty())


func test_payday_pays_the_hired_and_the_company_every_second_time() -> void:
	var sim := _sim()
	sim.run(220)
	_hire(sim, 0)
	_hire(sim, 1)
	_hire(sim, 4)
	var s := sim.mission.swiecino
	assert_eq(s.wages_due(sim.mission), 37, "the morning: only the hired")
	_set_silver(sim, 200)
	sim.mission.run({"do": "payday"}, sim.tick)
	assert_eq(_silver(sim), 163)
	assert_eq(s.wages_due(sim.mission), 3 * 25 + 37, "at noon Stach's company too")
	sim.mission.run({"do": "payday"}, sim.tick)
	assert_eq(_silver(sim), 51)
	assert_eq(s.deserted, 0)


func test_unpaid_companies_leave_and_fail_the_optional_objective() -> void:
	var sim := _sim()
	sim.run(220)
	_hire(sim, 0)
	_hire(sim, 2)
	_hire(sim, 4)
	_set_silver(sim, 30)
	var units := sim.entities.alive_ids.size()
	sim.mission.run({"do": "payday"}, sim.tick)
	_check(sim)
	assert_eq(sim.mission.swiecino.deserted, 1, "the lance (40) cannot be paid after the horse")
	assert_eq(sim.entities.alive_ids.size(), units - 1)
	assert_eq(_state(sim, "no_deserters"), MissionRuntime.Objective.FAILED)


# --- the tabor and the ditch ------------------------------------------------------------------


func test_idle_foot_in_the_camp_digs_the_ditch_into_bog() -> void:
	var sim := _sim()
	_morning(sim)
	var m := sim.mission
	var s := m.swiecino
	var last := s.ditch_cells[s.ditch_cells.size() - 1]
	assert_ne(sim.nav.terrain_at(last), &"t_bog")
	var foot := m.alive_of("royal_foot") + m.alive_of("gdansk_foot")
	_put(sim, foot, CAMP)
	var work := s.work
	_check(sim)
	assert_gte(s.work, work + foot.size() * CHECK, "each idle man digs")
	s.work = int(_rules(sim)["ditch"]["need"]) - 1
	_check(sim)
	assert_eq(s.ditch_permille(m), 1000)
	assert_eq(s.dug, s.ditch_cells.size())
	assert_eq(sim.nav.terrain_at(last), &"t_bog")
	assert_true(m.flags.has("ditch_done"))
	var gap := sim.nav.cell_at(46, 68)
	assert_false(s.ditch_cells.has(gap), "the gate gaps stay open")


func test_foot_on_the_move_or_out_of_the_camp_does_not_dig() -> void:
	var sim := _sim()
	_morning(sim)
	var m := sim.mission
	var foot := m.alive_of("royal_foot") + m.alive_of("gdansk_foot")
	_put(sim, foot, FAR)
	_put(sim, m.alive_of("crossbows"), FAR)
	_check(sim)
	var work := m.swiecino.work
	_check(sim)
	assert_eq(m.swiecino.work, work)


func test_the_wagon_ring_and_the_ditch_make_the_tabor_and_chain_the_wagons() -> void:
	var sim := _sim()
	_morning(sim)
	var m := sim.mission
	var s := m.swiecino
	s.work = int(_rules(sim)["ditch"]["need"])
	sim.apply_now(SimCommand.order(sim.tick, P, SimCommand.Kind.TABOR, m.alive_of("wagons")))
	sim.run(400)
	assert_true(s.ring_at_camp(m))
	assert_true(s.tabor_ready(m))
	assert_eq(_state(sim, "tabor"), MissionRuntime.Objective.DONE)
	assert_true(sim.combat.untouchable.has(m.alive_of("wagons")[0]), "chained")
	assert_true(m.fired.has("3"), "the Order comes once the tabor stands")
	assert_eq(m.alive_of("raweneck").size(), 1)
	assert_eq(m.alive_of("order_horse").size(), 10)
	assert_eq(m.alive_of("order_horse_more").size(), 2, "normal")
	assert_eq(m.alive_of("order_wagons").size(), 8)


func test_3_the_order_comes_at_eight_without_the_tabor_and_on_easy_with_less_horse() -> void:
	var sim := _sim("easy")
	_morning(sim)
	_rules(sim)["day"]["start_minutes"] = 480
	_check(sim)
	assert_true(sim.mission.fired.has("3"))
	assert_false(sim.mission.fired.has("3_normal"))
	assert_eq(sim.mission.alive_of("order_horse_more").size(), 0)


func test_the_order_horse_loses_its_run_on_the_ditch() -> void:
	var sim := _sim()
	_order(sim)
	var m := sim.mission
	var s := m.swiecino
	s.work = int(_rules(sim)["ditch"]["need"]) - 1
	_check(sim)
	var rider := m.alive_of("order_horse")[0]
	var cell := s.ditch_cells[0]
	sim.entities.pos_x[rider - 1] = sim.nav.center_x(cell)
	sim.entities.pos_y[rider - 1] = sim.nav.center_y(cell)
	sim.entities.run[rider - 1] = 5000
	_check(sim)
	assert_lt(sim.entities.run[rider - 1], 5000)


func test_the_camp_is_lost_when_the_order_stands_in_it_alone() -> void:
	var sim := _sim()
	_order(sim)
	var m := sim.mission
	for id in sim.entities.alive_ids.duplicate():
		if sim.entities.owners[id - 1] == P and not m.alive_of("stach").has(id):
			if not m.alive_of("wagons").has(id):
				sim.remove_unit(id)
	_put(sim, m.alive_of("stach"), FAR)
	_put(sim, m.alive_of("order_horse").slice(0, 3), CAMP)
	sim.run(400 + 2 * CHECK)
	assert_eq(m.outcome, MissionRuntime.Outcome.DEFEAT)


# --- 4: the long fight ------------------------------------------------------------------------


func test_4_jasienski_opens_the_fight_and_the_order_charges() -> void:
	var sim := _sim()
	_order(sim)
	sim.mission.fired["3"] = sim.tick - 1200
	_check(sim)
	var m := sim.mission
	assert_true(m.fired.has("4"))
	assert_true(_has_event(sim, "cutscene", "lances_stood_too_long"))
	assert_false(m.swiecino.hiring)
	assert_true(m.swiecino.rotate_on)
	assert_true(m.swiecino.crossbows_on)
	assert_true(m.swiecino.charging.has("order_horse"))
	assert_eq(m.swiecino.paydays, 1, "the morning pay")
	assert_eq(_state(sim, "morning"), MissionRuntime.Objective.ACTIVE)
	var j := m.alive_of("jasienski")[0]
	assert_ne(sim.entities.orders[j - 1], EntityStore.Order.IDLE, "Jasieński rides out")


func test_horses_tire_in_the_fight_and_rest_best_by_their_wagons() -> void:
	var sim := _sim()
	_order(sim)
	var m := sim.mission
	var s := m.swiecino
	var rider := m.alive_of("royal_horse")[0]
	_put(sim, PackedInt32Array([rider]), FAR)
	sim.entities.calm[rider - 1] = 0
	_check(sim)
	assert_lt(s.stamina[rider], 1000, "tired by the fight")
	s.stamina[rider] = 100
	_check(sim)
	var far_rest: int = s.stamina[rider]
	assert_gt(far_rest, 100)
	_put(sim, PackedInt32Array([rider]), CAMP)
	_check(sim)
	assert_gt(s.stamina[rider] - far_rest, far_rest - 100, "faster by the wagons")


func test_a_tired_horse_has_less_heart_and_strikes_weaker() -> void:
	var sim := _sim()
	_order(sim)
	var m := sim.mission
	var rider := m.alive_of("royal_horse")[0]
	_put(sim, PackedInt32Array([rider]), FAR)
	m.swiecino.stamina[rider] = 0
	_skip(sim, ["6"])
	_check(sim)
	var full := sim.combat.defs[rider - 1].morale * CombatSystem.MORALE_SCALE
	assert_lte(sim.entities.morale[rider - 1], full * 400 / 1000)
	assert_eq(sim.combat.crown.mission_damage[rider], 750)


func test_till_noon_the_riders_skirmish_and_strike_seldom() -> void:
	var sim := _sim()
	_order(sim)
	var m := sim.mission
	var rider := m.alive_of("royal_horse")[0]
	_put(sim, PackedInt32Array([rider]), FAR)
	_check(sim)
	assert_eq(sim.combat.crown.mission_damage[rider], 300)
	_skip(sim, ["6"])
	_check(sim)
	assert_false(sim.combat.crown.mission_damage.has(rider), "full blows after noon")


func test_the_orders_tired_or_wounded_riders_go_back_to_their_wagons() -> void:
	var sim := _sim()
	_order(sim)
	var m := sim.mission
	var s := m.swiecino
	m.run({"do": "rotate", "on": true}, sim.tick)
	var horse := m.alive_of("order_horse")
	_put(sim, horse, FIELD)
	_check(sim)
	s.stamina[horse[0]] = 100
	sim.entities.hp[horse[1] - 1] = sim.entities.max_hp[horse[1] - 1] / 4
	_check(sim)
	assert_true(s.resting.has(horse[0]), "tired")
	assert_true(s.resting.has(horse[1]), "wounded")
	assert_false(s.resting.has(horse[2]))
	assert_eq(sim.entities.orders[horse[0] - 1], EntityStore.Order.MOVE)


func test_the_crossbows_in_the_reeds_shoot_into_the_field_before_them() -> void:
	var sim := _sim()
	_order(sim)
	var m := sim.mission
	m.run({"do": "crossbows", "on": true}, sim.tick)
	var rider := m.alive_of("order_horse")[0]
	_put(sim, PackedInt32Array([rider]), ZONE)
	var hp := sim.entities.hp[rider - 1]
	_put(sim, m.alive_of("crossbows"), FAR)
	sim.run(81)
	assert_eq(sim.entities.hp[rider - 1], hp, "nobody in the reeds")
	_put(sim, m.alive_of("crossbows"), REEDS)
	_put(sim, PackedInt32Array([rider]), ZONE)
	sim.run(81)
	assert_lt(sim.entities.hp[rider - 1], hp)
	assert_true(m.flags.has("volley"))
	assert_eq(m.swiecino.in_zone(m), 1)


# --- 5: Dunin wounded; the command ----------------------------------------------------------------


func test_dunin_holds_the_whole_army_and_wounded_only_those_by_stach() -> void:
	var sim := _sim()
	_order(sim)
	var m := sim.mission
	var crown := sim.combat.crown
	_check(sim)
	assert_eq(crown.army_morale.get(P, 0), 8, "Dunin commands")
	assert_false(m.swiecino.stand_in_commands(m))
	_skip(sim, ["4"])
	_rules(sim)["day"]["start_minutes"] = 600
	_check(sim)
	assert_true(m.fired.has("5"))
	var dunin := m.alive_of("dunin")[0]
	assert_eq(sim.entities.owners[dunin - 1], DUNIN_TENT)
	assert_true(m.swiecino.stand_in_commands(m))
	assert_eq(crown.army_morale.get(P, 0), 8, "his word holds for a minute")
	sim.run(1200)
	assert_false(crown.army_morale.has(P))
	var near := m.alive_of("stach")[0]
	var rider := m.alive_of("royal_horse")[0]
	_put(sim, PackedInt32Array([near]), FAR)
	_put(sim, PackedInt32Array([rider]), FAR + Vector2i(2, 0))
	var other := m.alive_of("royal_horse")[1]
	_put(sim, PackedInt32Array([other]), FIELD)
	_check(sim)
	assert_eq(crown.mission_morale.get(rider, 0), 8, "by Stach")
	assert_false(crown.mission_morale.has(other), "far from Stach")
	sim.run(700)
	assert_true(m.fired.has("5b"))
	dunin = m.alive_of("dunin")[0]
	assert_eq(sim.entities.owners[dunin - 1], P, "back in the saddle")


func test_dunin_cannot_fall() -> void:
	var sim := _sim()
	_order(sim)
	var dunin := sim.mission.alive_of("dunin")[0]
	_check(sim)
	sim.combat.lightning(dunin, ORDER, 100000)
	assert_true(sim.entities.is_alive(dunin))
	assert_gt(sim.entities.hp[dunin - 1], 0)


# --- 6, 7, 8: noon and the lure ---------------------------------------------------------------


func test_6_noon_rests_both_sides_and_teaches_falling_back() -> void:
	var sim := _sim()
	_order(sim)
	_fire(sim, ["4", "5", "5b"])
	var m := sim.mission
	m.run({"do": "rotate", "on": true}, sim.tick)
	_rules(sim)["day"]["start_minutes"] = 720
	_check(sim)
	assert_true(m.fired.has("6"))
	assert_eq(_state(sim, "morning"), MissionRuntime.Objective.DONE)
	assert_false(m.swiecino.rotate_on)
	assert_true(m.flags.has("fall_back"))
	var rider := m.alive_of("royal_horse")[0]
	assert_true(sim.combat.flags[rider - 1] & CombatSystem.F_RETREAT != 0)
	assert_true(sim.combat.untouchable.has(m.alive_of("order_horse")[0]), "the noon rest")
	assert_true(_has_event(sim, "cutscene", "fall_back_not_run"))
	sim.run(1200)
	assert_true(m.fired.has("7"))
	assert_false(sim.combat.untouchable.has(m.alive_of("order_horse")[0]))
	assert_true(m.swiecino.charging.has("order_horse"))


func test_8_the_orders_horse_in_the_zone_and_dunins_second_wound() -> void:
	var sim := _sim()
	_order(sim)
	_fire(sim, ["4", "5", "5b", "6", "7"])
	var m := sim.mission
	_put(sim, m.alive_of("order_horse").slice(0, 4), ZONE)
	_check(sim)
	assert_true(m.fired.has("8"))
	assert_eq(_state(sim, "lure"), MissionRuntime.Objective.DONE)
	assert_true(_has_event(sim, "dialogue", "hagen"))
	var r := m.alive_of("raweneck")[0]
	assert_lte(sim.entities.hp[r - 1], sim.entities.max_hp[r - 1] * 450 / 1000)
	assert_eq(sim.entities.owners[m.alive_of("dunin")[0] - 1], DUNIN_TENT)


func test_8_comes_too_if_the_orders_horse_is_spent_before_the_reeds() -> void:
	var sim := _sim()
	_order(sim)
	_fire(sim, ["4", "5", "5b", "6", "7"])
	var m := sim.mission
	for g: String in ["order_horse", "order_horse_more"]:
		for id in m.alive_of(g):
			sim.remove_unit(id)
	_check(sim)
	assert_true(m.fired.has("8"))


# --- 9, 10: Raweneck --------------------------------------------------------------------------


func test_raweneck_cannot_fall_before_his_second_charge() -> void:
	var sim := _sim()
	_order(sim)
	var m := sim.mission
	var r := m.alive_of("raweneck")[0]
	_check(sim)
	sim.combat.lightning(r, P, 100000)
	assert_true(sim.entities.is_alive(r))
	assert_gt(sim.entities.hp[r - 1], 0)


func test_10_raweneck_falls_his_men_lose_heart_and_the_horse_rides_off() -> void:
	var sim := _sim()
	_order(sim)
	_fire(sim, ["4", "5", "5b", "6", "7", "8", "8b", "9"])
	var m := sim.mission
	_check(sim)
	var foot := m.alive_of("order_foot")[0]
	var before := sim.entities.morale[foot - 1]
	sim.combat.lightning(m.alive_of("raweneck")[0], P, 100000)
	_check(sim)
	assert_true(m.flags.has("leader_dead"))
	assert_true(m.fired.has("10"))
	assert_lt(sim.entities.morale[foot - 1], before)
	assert_eq(_state(sim, "raweneck"), MissionRuntime.Objective.DONE)
	assert_eq(_state(sim, "order_tabor"), MissionRuntime.Objective.ACTIVE)
	assert_true(_has_event(sim, "cutscene", "to_the_wagons"))
	assert_true(sim.combat.untouchable.has(m.alive_of("nostitz")[0]), "Nostitz gets away")


func test_after_raweneck_the_runners_near_our_men_are_taken_for_ransom() -> void:
	var sim := _sim()
	_order(sim)
	var m := sim.mission
	m.flags["leader_dead"] = sim.tick
	var runner := m.alive_of("order_horse")[0]
	var brave := m.alive_of("order_horse")[1]
	_put(sim, PackedInt32Array([runner]), FIELD)
	_put(sim, PackedInt32Array([brave]), FIELD + Vector2i(0, 1))
	sim.entities.morale[runner - 1] = 0
	_put(sim, m.alive_of("royal_horse").slice(0, 1), FIELD + Vector2i(1, 0))
	_set_silver(sim, 0)
	_check(sim)
	assert_false(sim.entities.is_alive(runner))
	assert_true(sim.entities.is_alive(brave), "one who still fights is not taken")
	assert_eq(m.swiecino.prisoners, 1)
	assert_eq(_silver(sim), 20)


func test_the_foot_in_the_order_tabor_yields_one_by_one() -> void:
	var sim := _sim()
	_order(sim)
	var m := sim.mission
	m.flags["leader_dead"] = sim.tick
	_put(sim, m.alive_of("order_foot"), ORDER_CAMP)
	_put(sim, m.alive_of("royal_foot"), ORDER_CAMP + Vector2i(3, 3))
	_check(sim)
	assert_eq(m.alive_of("order_foot").size(), 3)
	sim.run(100)
	assert_eq(m.alive_of("order_foot").size(), 2)


func test_five_prisoners_win_the_optional_objective() -> void:
	var sim := _sim()
	_morning(sim)
	sim.mission.swiecino.prisoners = 5
	_check(sim)
	sim.run(200)
	assert_eq(_state(sim, "prisoners"), MissionRuntime.Objective.DONE)


# --- 11, 12: the Order's tabor, the peasants, the end -------------------------------------------


func test_11_the_tabor_taken_and_the_pomeranians_come_late_and_run() -> void:
	var sim := _sim()
	_order(sim)
	_fire(sim, ["4", "5", "5b", "6", "7", "8", "8b", "9", "10"])
	var m := sim.mission
	for id in m.alive_of("order_foot"):
		sim.remove_unit(id)
	_put(sim, m.alive_of("royal_horse"), ORDER_CAMP + Vector2i(0, 4))
	_check(sim)
	assert_true(m.fired.has("11"))
	assert_eq(_state(sim, "order_tabor"), MissionRuntime.Objective.DONE)
	assert_eq(sim.entities.owners[m.alive_of("order_wagons")[0] - 1], P, "the wagons are ours")
	assert_eq(m.alive_of("pomeranians").size(), 13)
	var peasant := m.alive_of("pomeranians")[0]
	assert_eq(sim.combat.defs[peasant - 1].id, &"nt_pomeranian")
	_put(sim, m.alive_of("pomeranians"), Vector2i(46, 23))
	_check(sim)
	assert_true(m.fired.has("11b"))
	assert_true(_has_event(sim, "dialogue", "where_are_the_germans"))
	assert_eq(sim.entities.morale[peasant - 1], 0, "they throw down their scythes")


func test_12_the_field_clear_ends_the_crown_campaign_in_torun() -> void:
	var sim := _sim()
	_order(sim)
	_fire(sim, ["4", "5", "5b", "6", "7", "8", "8b", "9", "10", "11", "11b"])
	var m := sim.mission
	for id in sim.entities.alive_ids.duplicate():
		if sim.entities.owners[id - 1] == ORDER:
			sim.remove_unit(id)
	_check(sim)
	assert_true(m.fired.has("12"))
	assert_true(_has_event(sim, "cutscene", "artus_court"))
	assert_eq(_state(sim, "peasants"), MissionRuntime.Objective.DONE)
	sim.run(120)
	assert_eq(m.outcome, MissionRuntime.Outcome.VICTORY)


# --- defeats --------------------------------------------------------------------------------


func test_defeat_when_stach_falls() -> void:
	var sim := _sim()
	_skip(sim, ["1"])
	sim.remove_unit(sim.mission.alive_of("stach")[0])
	_check(sim)
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.DEFEAT)


func test_defeat_when_half_the_army_runs() -> void:
	var sim := _sim()
	_order(sim)
	_skip(sim, ["4"])
	var m := sim.mission
	var s := m.swiecino
	for id in sim.entities.alive_ids:
		if sim.entities.owners[id - 1] == P and sim.combat.defs[id - 1].has_class(&"cavalry"):
			sim.combat.drive_off(id)
	sim.run(10)
	assert_gt(s.fleeing_permille(m), 500)
	sim.run(300)
	assert_eq(m.outcome, MissionRuntime.Outcome.DEFEAT)


# --- the panel ------------------------------------------------------------------------------


func test_the_panel_shows_the_clock_the_ditch_the_silver_and_the_command() -> void:
	var sim := _sim()
	sim.run(220)
	var m := sim.mission
	var clock := SimClock.new()
	clock.sim = sim
	add_child_autofree(clock)
	var panel := MissionPanel.new()
	add_child_autofree(panel)
	panel.attach(sim, clock, null)
	m.swiecino.work = 0
	panel.poll()
	assert_eq(
		panel.march_text(),
		"17 September 1462, 05:35\nDitch: 0%\nSilver: 600, next wages: 0",
	)
	_hire(sim, 0)
	_skip(sim, ["4"])
	m.swiecino.work = int(_rules(sim)["ditch"]["need"])
	m.swiecino.prisoners = 2
	m.run({"do": "transfer", "group": "dunin", "player": DUNIN_TENT}, sim.tick)
	panel.poll()
	var lines := panel.march_text().split("\n")
	assert_eq(lines.size(), 6)
	assert_eq(lines[1], "Silver: 520, next wages: 25")
	assert_eq(lines[2], "Hired: 1 horse, 0 foot")
	assert_string_starts_with(lines[3], "Horses' strength: ")
	assert_eq(lines[4], "Dunin is wounded: Stach commands")
	assert_eq(lines[5], "Prisoners: 2")


# --- state ----------------------------------------------------------------------------------


func test_save_and_load_keep_the_ditch_the_wages_and_the_tiring() -> void:
	var sim := _sim()
	sim.run(220)
	_hire(sim, 0)
	var m := sim.mission
	m.swiecino.work = int(_rules(sim)["ditch"]["need"]) - 1
	_put(sim, m.alive_of("royal_foot"), CAMP)
	sim.run(100)
	var data := SimSave.capture(sim)
	var loaded := SimSave.restore(data, _db)
	assert_not_null(loaded)
	assert_eq(loaded.state_hash(), data["hash"])
	assert_eq(loaded.mission.swiecino.hired_horse, 1)
	assert_eq(loaded.mission.swiecino.dug, m.swiecino.dug)
	var first := m.swiecino.ditch_cells[0]
	assert_eq(loaded.nav.terrain_at(first), &"t_bog")
	sim.run(600)
	loaded.run(600)
	assert_eq(loaded.state_hash(), sim.state_hash(), "and it plays on the same")


func test_the_swiecino_state_changes_the_hash() -> void:
	var a := _sim()
	var b := _sim()
	b.mission.swiecino.prisoners += 1
	assert_ne(a.state_hash(), b.state_hash())
	var c := _sim()
	c.mission.swiecino.stamina[c.mission.alive_of("company")[0]] = 10
	assert_ne(a.state_hash(), c.state_hash())


static func _fx(cell: int) -> int:
	return Fixed.from_cells(cell) + Fixed.HALF
