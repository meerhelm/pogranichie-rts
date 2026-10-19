# gdlint:ignore = max-public-methods
extends GutTest
## «Корона 4. Хойнице, 1454»: one test per trigger of the mission card and per rule of
## MissionChojnice (the clock of the long day, the lords arguing over their places, the levy
## that chases anyone who runs and loses heart early, the panic from the sortie, the king who
## is led off the field, the bog that drowns whoever runs off the causeway, the Łęczyca banner,
## Jaśko's debt and the men who get over the bog). The world is put into the condition and the
## result is checked; earlier triggers a test does not need are marked as fired by hand.

const MISSION := "crown_04"
const P := 1
const ORDER := 2
const LORDS := 3
const UNION := 4
const KING := 5
const REAR := 6
const CHECK := MissionRuntime.CHECK_EVERY
const LINE := Vector2i(58, 37)
const TENT := Vector2i(43, 69)
const BRIDGEHEAD := Vector2i(95, 65)
const EAST := Vector2i(147, 65)
## Far from everybody, in the stubble south-east of the field.
const FAR := Vector2i(70, 90)
## Where the king, Stach and the banner wait while a test does not need them (their loss ends
## the mission).
const ASIDE := Vector2i(78, 96)
## Beside the king's tent (the tent itself stands on 43, 69).
const BY_TENT := Vector2i(46, 64)

var _db: CatalogDB


func before_all() -> void:
	_db = CatalogDB.load_prototype()


func _sim() -> Simulation:
	var sim := MissionSetup.new_simulation(MISSION, 1, _db, "normal")
	assert_not_null(sim)
	return sim


## Marks the triggers fired; trigger 1 is let fire itself, for its objectives.
func _skip(sim: Simulation, ids: Array[String]) -> void:
	if ids.has("1") and not sim.mission.fired.has("1"):
		_check(sim)
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


func _state(sim: Simulation, oid: String) -> int:
	return sim.mission.objective_state.get(oid, -1)


func _put(sim: Simulation, ids: PackedInt32Array, c: Vector2i) -> void:
	for id in ids:
		sim.entities.pos_x[id - 1] = _fx(c.x)
		sim.entities.pos_y[id - 1] = _fx(c.y)
		sim.entities.stop(id)


func _one(sim: Simulation, type: StringName, p: int, c: Vector2i) -> int:
	return sim.spawn_unit(type, p, _fx(c.x), _fx(c.y))


## The clock of the mission set to `minutes` since midnight.
func _at_hour(sim: Simulation, minutes: int) -> void:
	var day: Dictionary = sim.mission.def.rules["chojnice"]["day"]
	var tick := (minutes - int(day["start_minutes"])) * int(day["ticks_per_hour"]) / 60
	sim.tick = maxi(sim.tick, tick - 1)


func _mark(sim: Simulation, question: String) -> void:
	sim.enqueue(SimCommand.choose(sim.tick, P, StringName(question), 0))


## Everybody but the named groups off the map, so nothing fights where the test looks; the
## king, Stach and the banner's bearer, whose loss ends the mission, wait aside. Nobody deploys.
func _only(sim: Simulation, keep: Array[String]) -> void:
	var stay := {}
	for g: String in keep + ["casimir", "stach", "bninski"]:
		for id in sim.mission.alive_of(g):
			stay[id] = true
			if not keep.has(g):
				_put(sim, PackedInt32Array([id]), ASIDE)
	for id in sim.entities.alive_ids.duplicate():
		if not stay.has(id):
			sim.remove_unit(id)
	sim.mission.chojnice.deploying = false


# --- setup ----------------------------------------------------------------------------------


func test_the_field_the_bog_and_the_sides_are_set_up() -> void:
	var sim := _sim()
	var m := sim.mission
	assert_eq(sim.nav.width, 150)
	assert_eq(sim.nav.height, 100)
	for p: int in [LORDS, UNION, KING, REAR]:
		assert_true(sim.sides.friendly(P, p), "player %d is on our side" % p)
	assert_true(sim.sides.hostile(P, ORDER))
	assert_true(m.chojnice.on)
	assert_eq(sim.magic.places.count(), 3, "the cross, the spring and the old oak")
	assert_eq(sim.nav.terrain_at(sim.nav.cell_at(96, 50)), &"t_bog")
	assert_eq(sim.nav.terrain_at(sim.nav.cell_at(120, 60)), &"t_quagmire")
	assert_eq(m.alive_of("leczyca").size(), 12)
	assert_eq(m.alive_of("camp_wagons").size(), 12)
	assert_eq(m.chojnice.bearer, m.alive_of("bninski")[0], "Bniński has the banner at first")
	assert_true(sim.economy.buildings.is_alive(m.named.get("king_tent", 0)))


func test_the_banner_can_reach_the_line_the_tent_and_the_east_bank() -> void:
	var sim := _sim()
	for goal: Vector2i in [LINE, BY_TENT, BRIDGEHEAD, EAST]:
		var to := sim.nav.cell_at(goal.x, goal.y)
		for g: String in ["jasko", "stach", "leczyca", "casimir"]:
			var id := sim.mission.alive_of(g)[0]
			var from := sim.nav.cell_of(sim.entities.pos_x[id - 1], sim.entities.pos_y[id - 1])
			var cls := sim.entities.move_class[id - 1]
			assert_eq(sim.nav.area(cls, from), sim.nav.area(cls, to), "%s to %s" % [g, goal])


func test_crown_4_is_made_and_playable() -> void:
	assert_true(CampaignProgress.is_made("crown_04"))
	assert_eq(CampaignProgress.title_key("crown_04"), "Crown 4. Chojnice, 1454")


# --- the long day ---------------------------------------------------------------------------


func test_1_the_day_begins_with_the_objectives_and_the_clock() -> void:
	var sim := _sim()
	var m := sim.mission
	assert_eq(m.chojnice.clock_text(m, 0), "08:00")
	_check(sim)
	assert_true(m.fired.has("1"))
	assert_true(_has_event(sim, "cutscene", "grandfather_and_grandson"))
	for oid: String in ["deploy", "strike", "chapels", "no_chase", "six"]:
		assert_eq(_state(sim, oid), MissionRuntime.Objective.ACTIVE, oid)
	assert_true(m.chojnice.deploying)
	assert_false(m.fired.has("veterans"), "no knights from 1433 without the mark")


func test_the_knights_of_1433_come_as_veterans() -> void:
	var sim := _sim()
	_mark(sim, "mark:crown_03:knights")
	_check(sim)
	assert_true(sim.mission.fired.has("veterans"))
	assert_eq(sim.mission.alive_of("veterans").size(), 4)


func test_2_the_lords_argue_over_precedence() -> void:
	var sim := _sim()
	_check(sim)
	sim.run(300)
	assert_true(sim.mission.fired.has("2"))
	assert_true(_has_event(sim, "dialogue", "precedence"))


func test_the_players_arguing_men_stay_until_a_hero_rides_up() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1"])
	var horse := m.alive_of("leczyca")
	var stubborn := horse[0]
	assert_true(m.chojnice.is_arguing(stubborn))
	assert_false(m.chojnice.is_arguing(horse[1]), "every other man of Łęczyca argues")
	_only(sim, ["leczyca", "jasko"])
	_put(sim, m.alive_of("jasko"), FAR)
	sim.enqueue(SimCommand.move(sim.tick, P, PackedInt32Array([stubborn]), _fx(58), _fx(37)))
	sim.run(200)
	assert_true(m.chojnice.is_arguing(stubborn))
	assert_eq(sim.entities.orders[stubborn - 1], EntityStore.Order.IDLE, "he will not go")
	var at := Vector2i(
		Fixed.to_cells(sim.entities.pos_x[stubborn - 1]),
		Fixed.to_cells(sim.entities.pos_y[stubborn - 1])
	)
	_put(sim, m.alive_of("jasko"), at + Vector2i(1, 0))
	_check(sim)
	assert_false(m.chojnice.is_arguing(stubborn), "Jaśko talks him round")


func test_the_allied_lords_argue_for_a_while_and_then_deploy() -> void:
	var sim := _sim()
	var m := sim.mission
	_check(sim)
	var men := m.alive_of("wielkopolska")
	assert_true(m.chojnice.is_arguing(men[0]))
	assert_eq(m.chojnice.arguing[men[0]], 700)
	assert_eq(m.chojnice.arguing[men[2]], 2100)
	sim.run(720)
	assert_false(m.chojnice.is_arguing(men[0]))
	assert_true(m.chojnice.sent.has(men[0]), "sent to its place in the line")
	assert_ne(sim.entities.orders[men[0] - 1], EntityStore.Order.IDLE)
	assert_true(m.chojnice.is_arguing(men[2]))


func test_3_at_noon_the_relief_comes_out_of_the_forest() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "2"])
	_at_hour(sim, 700)
	_check(sim)
	assert_false(m.fired.has("3"))
	_at_hour(sim, 720)
	_check(sim)
	assert_true(m.fired.has("3"))
	assert_eq(m.alive_of("order_horse").size(), 16)
	assert_eq(m.alive_of("order_foot").size(), 14)
	assert_eq(m.alive_of("zinnenberg").size(), 1)
	assert_true(sim.combat.untouchable.has(m.alive_of("wagenburg_0")[0]))


func test_4_the_banner_in_the_line_opens_the_chapels() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "2"])
	var horse := m.alive_of("leczyca")
	_put(sim, horse.slice(0, 7), LINE)
	_check(sim)
	assert_false(m.fired.has("4"), "seven are not the banner")
	_put(sim, horse.slice(0, 8), LINE)
	_check(sim)
	assert_true(m.fired.has("4"))
	assert_eq(_state(sim, "deploy"), MissionRuntime.Objective.DONE)
	assert_true(_has_event(sim, "dialogue", "bninski"))
	assert_false(sim.economy.player(P).locked.has(&"pl_shrine"))


func test_three_places_held_before_the_evening_keep_the_chapels() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "2", "3", "4"])
	var places := sim.magic.places
	for i in places.count():
		places.holders[i] = P
	_check(sim)
	assert_true(m.fired.has("chapels_done"))
	assert_eq(_state(sim, "chapels"), MissionRuntime.Objective.DONE)


func test_5_in_the_evening_the_battle_begins_and_late_chapels_fail() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "2"])
	_at_hour(sim, 721)
	_check(sim)
	_skip(sim, ["4"])
	_at_hour(sim, 1020)
	_check(sim)
	assert_true(m.fired.has("5"))
	assert_true(_has_event(sim, "cutscene", "evening"))
	assert_eq(_state(sim, "chapels"), MissionRuntime.Objective.FAILED)
	assert_false(m.chojnice.deploying)
	var horse := m.alive_of("order_horse")[0]
	assert_eq(sim.entities.stance[horse - 1], EntityStore.Stance.AGGRESSIVE)


# --- the levy -------------------------------------------------------------------------------


func test_the_levy_rides_after_anyone_who_runs_but_not_when_told_to_stand() -> void:
	var sim := _sim()
	var m := sim.mission
	_check(sim)
	_only(sim, ["kujawy"])
	var men := m.alive_of("kujawy")
	var free := men[1]
	var held := men[3]
	m.chojnice.arguing.clear()
	_put(sim, PackedInt32Array([free]), Vector2i(60, 80))
	_put(sim, PackedInt32Array([held]), Vector2i(60, 84))
	sim.entities.stance[held - 1] = EntityStore.Stance.STAND
	var runner := _one(sim, &"to_merc_horse", ORDER, Vector2i(64, 82))
	sim.combat.drive_off(runner)
	_check(sim)
	assert_eq(sim.entities.target[free - 1], runner, "the levy chases him")
	assert_ne(sim.entities.target[held - 1], runner, "standing men stay")


func test_the_levy_loses_heart_early() -> void:
	var sim := _sim()
	var m := sim.mission
	_check(sim)
	var man := m.alive_of("kujawy")[0]
	var unit := sim.combat.defs[man - 1]
	assert_gt(unit.param(&"flee_morale", 0), 0, "the levy has a breaking point")
	sim.entities.morale[man - 1] = 1
	_check(sim)
	assert_true(sim.combat.is_fleeing(man))


func test_6_the_order_horse_broken_ends_the_strike_and_zinnenberg_is_taken() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "2"])
	_at_hour(sim, 720)
	_check(sim)
	_skip(sim, ["4", "5"])
	var horse := m.alive_of("order_horse")
	for i in 7:
		sim.remove_unit(horse[i])
	_check(sim)
	assert_true(m.fired.has("6"))
	assert_eq(_state(sim, "strike"), MissionRuntime.Objective.DONE)
	assert_true(m.alive_of("rudolf").is_empty(), "Rudolf falls")
	var z := m.alive_of("zinnenberg")[0]
	assert_eq(sim.entities.owners[z - 1], LORDS, "Zinnenberg is a prisoner")


func test_chasing_to_the_walls_fails_the_restraint() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "2", "3", "4", "5", "6"])
	_put(sim, PackedInt32Array([m.alive_of("leczyca")[0]]), Vector2i(30, 45))
	_check(sim)
	assert_true(m.fired.has("no_chase_failed"))
	assert_eq(_state(sim, "no_chase"), MissionRuntime.Objective.FAILED)


func test_7_and_8_stach_wants_to_chase_and_the_sortie_comes_out() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "2", "3", "4", "5", "6"])
	sim.run(1200 + CHECK)
	assert_true(m.fired.has("7"))
	assert_true(_has_event(sim, "dialogue", "stach_wants_to_chase"))
	sim.run(600 + CHECK)
	assert_true(m.fired.has("8"))
	assert_eq(m.alive_of("sortie").size(), 5)
	assert_eq(_state(sim, "no_chase"), MissionRuntime.Objective.DONE)
	assert_eq(_state(sim, "panic"), MissionRuntime.Objective.ACTIVE)


# --- the panic and the bog ------------------------------------------------------------------


func test_the_panic_drives_off_all_but_who_stands_by_a_banner_a_hero_or_the_foot() -> void:
	var sim := _sim()
	var m := sim.mission
	_check(sim)
	_only(sim, ["kujawy", "foot", "jasko"])
	m.chojnice.arguing.clear()
	var men := m.alive_of("kujawy")
	_put(sim, PackedInt32Array([men[0]]), TENT + Vector2i(4, 0))
	_put(sim, PackedInt32Array([men[1]]), TENT + Vector2i(0, 5))
	_put(sim, PackedInt32Array([men[2]]), TENT + Vector2i(-5, 0))
	var foot := m.alive_of("foot")
	_put(sim, foot, TENT + Vector2i(0, 7))
	for id in foot:
		sim.entities.stance[id - 1] = EntityStore.Stance.STAND
	_put(sim, m.alive_of("jasko"), TENT + Vector2i(-7, 0))
	_skip(sim, ["1", "2", "3", "4", "5", "6", "7", "8"])
	sim.mission.run({"do": "panic", "at": [TENT.x, TENT.y]}, sim.tick)
	for i in 8:
		_check(sim)
	assert_true(sim.combat.is_fleeing(men[0]), "alone, he runs")
	assert_false(sim.combat.is_fleeing(men[1]), "the foot servants hold")
	assert_false(sim.combat.is_fleeing(men[2]), "Jaśko holds him")
	assert_true(m.flags.has("panicked"))


func test_8b_and_9_the_sortie_at_the_tent_starts_the_panic_and_the_camp_is_lost() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "2"])
	_at_hour(sim, 720)
	_check(sim)
	_skip(sim, ["4", "5", "6", "7"])
	sim.mission.fired["8"] = sim.tick - 600
	m.run(
		{
			"do": "spawn",
			"group": "sortie",
			"player": ORDER,
			"at": [43, 69],
			"units": [["to_knight_brother", 1]]
		},
		sim.tick
	)
	_check(sim)
	assert_true(m.fired.has("8b"))
	assert_eq(m.chojnice.front, 1)
	for i in 14:
		_check(sim)
	assert_true(m.fired.has("9"))
	assert_eq(sim.entities.owners[m.alive_of("camp_wagons")[0] - 1], ORDER)
	assert_eq(m.alive_of("chase").size(), 10)
	assert_eq(_state(sim, "king"), MissionRuntime.Objective.ACTIVE)
	assert_true(m.chojnice.pursuing.has("chase"))


func test_whoever_runs_into_the_bog_drowns_but_not_on_the_causeway() -> void:
	var sim := _sim()
	var m := sim.mission
	_check(sim)
	_only(sim, ["kujawy"])
	var men := m.alive_of("kujawy")
	_put(sim, PackedInt32Array([men[0]]), Vector2i(96, 50))
	_put(sim, PackedInt32Array([men[1]]), Vector2i(110, 65))
	_put(sim, PackedInt32Array([men[2]]), Vector2i(96, 52))
	sim.combat.drive_off(men[0])
	sim.combat.drive_off(men[1])
	_check(sim)
	assert_false(sim.entities.is_alive(men[0]) and sim.entities.hp[men[0] - 1] > 0, "drowned")
	assert_true(sim.entities.hp[men[1] - 1] > 0, "the causeway holds")
	assert_true(sim.entities.hp[men[2] - 1] > 0, "who does not run does not drown")
	assert_eq(m.chojnice.drowned, 1)
	assert_eq(m.chojnice.drowned_player, 0)


# --- the king -------------------------------------------------------------------------------


func _king_ready(sim: Simulation) -> void:
	_skip(sim, ["1", "2", "3", "4", "5", "6", "7", "8", "8b", "9"])
	_only(sim, ["casimir", "leczyca", "jasko", "stach", "bninski", "gorka"])


func test_the_king_goes_only_when_his_men_close_round_him_and_rides_the_road() -> void:
	var sim := _sim()
	var m := sim.mission
	_king_ready(sim)
	var king := m.alive_of("casimir")[0]
	_check(sim)
	assert_false(m.chojnice.led, "he will not leave the field alone")
	var at := Vector2i(
		Fixed.to_cells(sim.entities.pos_x[king - 1]), Fixed.to_cells(sim.entities.pos_y[king - 1])
	)
	_put(sim, m.alive_of("leczyca").slice(0, 3), at + Vector2i(1, 1))
	_check(sim)
	assert_true(m.chojnice.led)
	assert_eq(sim.entities.stance[king - 1], EntityStore.Stance.PASSIVE)
	assert_ne(sim.entities.orders[king - 1], EntityStore.Order.IDLE, "he rides to the road")


func test_at_the_end_of_his_road_the_king_is_out() -> void:
	var sim := _sim()
	var m := sim.mission
	_king_ready(sim)
	var king := m.alive_of("casimir")[0]
	m.chojnice.led = true
	m.chojnice.leg = 3
	_put(sim, PackedInt32Array([king]), EAST)
	_check(sim)
	assert_true(m.chojnice.king_out)
	assert_true(m.flags.has("king_out"))
	assert_false(m.is_over(), "the king out is no defeat")


func test_the_king_cut_off_and_beaten_down_is_taken() -> void:
	var sim := _sim()
	var m := sim.mission
	_only(sim, ["casimir", "jasko", "stach", "bninski"])
	var king := m.alive_of("casimir")[0]
	_put(sim, PackedInt32Array([king]), FAR)
	_one(sim, &"to_knight_brother", ORDER, FAR + Vector2i(1, 0))
	_check(sim)
	assert_eq(sim.combat.hp_floor.get(king, 0), sim.entities.max_hp[king - 1] / 4)
	sim.entities.hp[king - 1] = sim.combat.hp_floor[king]
	_check(sim)
	assert_true(m.flags.has("king_taken"))
	assert_eq(m.outcome, MissionRuntime.Outcome.DEFEAT)


func test_10_the_king_led_away_bninski_and_gorka_are_taken_and_jasko_has_the_banner() -> void:
	var sim := _sim()
	var m := sim.mission
	_king_ready(sim)
	m.chojnice.led = true
	_put(sim, m.alive_of("casimir"), Vector2i(60, 66))
	_check(sim)
	assert_true(m.fired.has("10"))
	assert_eq(sim.entities.owners[m.alive_of("bninski")[0] - 1], ORDER)
	assert_eq(sim.entities.owners[m.alive_of("gorka")[0] - 1], ORDER)
	assert_eq(m.chojnice.bearer, m.alive_of("jasko")[0])
	assert_eq(_state(sim, "causeway"), MissionRuntime.Objective.ACTIVE)


# --- the banner and the debt ----------------------------------------------------------------


func test_a_fallen_banner_is_raised_by_one_of_ours_nearby() -> void:
	var sim := _sim()
	var m := sim.mission
	_only(sim, ["casimir", "stach", "leczyca"])
	_check(sim)
	m.run({"do": "banner_to", "group": "leczyca"}, sim.tick)
	var men := m.alive_of("leczyca")
	_put(sim, PackedInt32Array([men[0], men[1]]), FAR)
	_check(sim)
	sim.remove_unit(men[0])
	_check(sim)
	assert_true(m.flags.has("banner_down"))
	assert_true(m.flags.has("banner_raised"))
	assert_eq(m.chojnice.bearer, men[1])


func test_a_banner_left_lying_is_taken_and_the_mission_lost() -> void:
	var sim := _sim()
	var m := sim.mission
	_only(sim, ["casimir", "stach", "bninski"])
	_check(sim)
	_put(sim, m.alive_of("bninski"), FAR)
	_check(sim)
	sim.remove_unit(m.alive_of("bninski")[0])
	_check(sim)
	assert_true(m.flags.has("banner_down"))
	sim.run(420)
	assert_true(m.flags.has("banner_taken"))
	assert_eq(m.outcome, MissionRuntime.Outcome.DEFEAT)


func test_11_jasko_stays_on_the_causeway_paying_his_debt_and_stach_has_the_banner() -> void:
	var sim := _sim()
	var m := sim.mission
	_mark(sim, "mark:crown_01:pact")
	_mark(sim, "mark:crown_03:knights")
	_check(sim)
	_king_ready(sim)
	_skip(sim, ["10"])
	_put(sim, m.alive_of("casimir"), BRIDGEHEAD)
	_check(sim)
	assert_true(m.fired.has("11"))
	var jasko := m.alive_of("jasko")[0]
	assert_eq(sim.entities.owners[jasko - 1], REAR)
	assert_eq(m.chojnice.bearer, m.alive_of("stach")[0])
	assert_eq(m.chojnice.debt, 1, "one pact made in the campaign")
	assert_eq(m.chojnice.stand_until, m.fired["11"] + 1200 + 600)
	assert_eq(m.alive_of("old_knights").size(), 3)
	assert_eq(_state(sim, "banner"), MissionRuntime.Objective.ACTIVE)
	_check(sim)
	assert_true(sim.combat.crown.pact.has(jasko) or m.chojnice._pact_on(m, jasko))
	sim.tick = m.chojnice.stand_until
	_check(sim)
	assert_true(m.chojnice.paid)
	assert_true(m.alive_of("jasko").is_empty(), "Jaśko falls")
	assert_true(m.alive_of("veterans").is_empty(), "and the knights of 1433 with him")
	assert_true(m.fired.has("11c"))
	assert_false(m.is_over())


func test_jasko_without_debts_holds_the_shortest_time() -> void:
	var sim := _sim()
	var m := sim.mission
	_check(sim)
	m.run({"do": "last_stand"}, sim.tick)
	assert_eq(m.chojnice.debt, 0)
	assert_eq(m.chojnice.stand_until, sim.tick + 1200)


# --- over the bog ---------------------------------------------------------------------------


func test_men_on_the_east_bank_leave_the_map_but_stach_waits() -> void:
	var sim := _sim()
	var m := sim.mission
	_check(sim)
	_only(sim, ["casimir", "stach", "leczyca"])
	m.run({"do": "banner_to", "group": "stach"}, sim.tick)
	_put(sim, m.alive_of("leczyca").slice(0, 6), EAST)
	_put(sim, m.alive_of("stach"), EAST)
	_check(sim)
	assert_eq(m.chojnice.escaped, 6)
	assert_eq(m.alive_of("stach").size(), 1)
	assert_true(m.fired.has("six_done"))


func test_12_stach_over_the_bog_wins_and_six_men_make_the_full_victory() -> void:
	for six: bool in [false, true]:
		var sim := _sim()
		var m := sim.mission
		_king_ready(sim)
		_skip(sim, ["10", "11", "11c"])
		m.flags["king_out"] = sim.tick
		m.chojnice.escaped = 6 if six else 2
		_put(sim, m.alive_of("stach"), EAST)
		_check(sim)
		assert_true(m.fired.has("12"))
		assert_true(_has_event(sim, "cutscene", "road_to_torun"))
		sim.run(120)
		assert_eq(m.outcome, MissionRuntime.Outcome.VICTORY)
		var six_state := MissionRuntime.Objective.DONE if six else MissionRuntime.Objective.FAILED
		assert_eq(_state(sim, "six"), six_state)


# --- defeats --------------------------------------------------------------------------------


func test_defeat_when_the_king_or_stach_falls() -> void:
	for g: String in ["casimir", "stach"]:
		var sim := _sim()
		for id in sim.mission.alive_of(g):
			sim.remove_unit(id)
		_check(sim)
		assert_eq(sim.mission.outcome, MissionRuntime.Outcome.DEFEAT, g)


# --- state ----------------------------------------------------------------------------------


func test_save_and_load_keep_the_day() -> void:
	var sim := _sim()
	var m := sim.mission
	_check(sim)
	m.run({"do": "panic", "at": [TENT.x, TENT.y]}, sim.tick)
	sim.run(300)
	var data := SimSave.capture(sim)
	var loaded := SimSave.restore(data, _db)
	assert_not_null(loaded)
	assert_eq(loaded.state_hash(), data["hash"])
	assert_eq(loaded.mission.chojnice.front, m.chojnice.front)
	assert_eq(loaded.mission.chojnice.arguing.size(), m.chojnice.arguing.size())
	sim.run(600)
	loaded.run(600)
	assert_eq(loaded.state_hash(), sim.state_hash(), "and it plays on the same")


func test_the_day_changes_the_hash() -> void:
	var a := _sim()
	var b := _sim()
	b.mission.chojnice.escaped += 1
	assert_ne(a.state_hash(), b.state_hash())
	var c := _sim()
	c.mission.chojnice.arguing.erase(c.mission.chojnice.arguing.keys()[0])
	assert_ne(a.state_hash(), c.state_hash())


static func _fx(cell: int) -> int:
	return Fixed.from_cells(cell) + Fixed.HALF
