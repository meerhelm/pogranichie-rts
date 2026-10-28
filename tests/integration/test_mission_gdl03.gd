# gdlint:ignore = max-public-methods
extends GutTest
## «ВКЛ 3. Крещение, 1413–1417»: one test per trigger of the mission card and per rule of its
## own (baptism, evidence, spies, quenched places, questions). The world is put into the
## trigger's condition and its events are checked; earlier triggers a test does not need are
## marked as fired by hand.

const MISSION := "gdl_03"
const P := 1
const ORDER := 2
const PAGANS := 3
const ENVOYS := 4
const CHECK := MissionRuntime.CHECK_EVERY
const CHURCH_AT := Vector2i(100, 84)
const TALK_AT := Vector2i(56, 137)
const VILLAGES: Array[Vector2i] = [Vector2i(50, 104), Vector2i(104, 112), Vector2i(132, 92)]
const GROVE_PASS := Vector2i(75, 82)
const ALKA := Vector2i(67, 81)
const FOOD := 0
const SILVER := 3

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
		out.append(str(e["kind"]))
	return out


func _state(sim: Simulation, oid: String) -> int:
	return sim.mission.objective_state.get(oid, -1)


func _put(sim: Simulation, ids: PackedInt32Array, cx: int, cy: int) -> void:
	for id in ids:
		sim.entities.pos_x[id - 1] = Fixed.from_cells(cx) + Fixed.HALF
		sim.entities.pos_y[id - 1] = Fixed.from_cells(cy) + Fixed.HALF
		sim.entities.stop(id)


func _cell_of(sim: Simulation, id: int) -> int:
	return sim.nav.cell_at(
		Fixed.to_cells(sim.entities.pos_x[id - 1]), Fixed.to_cells(sim.entities.pos_y[id - 1])
	)


func _peasants(sim: Simulation) -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in sim.entities.alive_ids:
		if sim.entities.owners[id - 1] == P and sim.entities.type_ids[id - 1] == &"gdl_peasant":
			out.append(id)
	return out


func _stock(sim: Simulation, res: int, amount: int) -> void:
	sim.economy.player(P).stock[res] = amount


## A finished Temple of the player as near `near` as it fits.
func _temple(sim: Simulation, near: Vector2i) -> int:
	var def := _db.building(&"gdl_temple")
	for r in range(0, 16):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := near + Vector2i(dx, dy)
				if (
					sim.economy.placement.can_place(P, def, c.x, c.y, false)
					!= EconomySystem.Fail.OK
				):
					continue
				var before := sim.economy.buildings.next_id
				sim.apply_now(
					SimCommand.place(
						sim.tick,
						P,
						&"gdl_temple",
						Fixed.from_cells(c.x) + Fixed.HALF,
						Fixed.from_cells(c.y) + Fixed.HALF
					)
				)
				if sim.economy.buildings.next_id > before:
					return before
	fail_test("no room for a temple near %s" % near)
	return 0


## A spy of the Order standing at the cell.
func _spy(sim: Simulation, cx: int, cy: int) -> int:
	var m := sim.mission
	m.spies_wanted = 1
	sim.run(2 * CHECK)
	assert_eq(m.spies.size(), 1)
	var spy := m.spies[0]
	_put(sim, PackedInt32Array([spy]), cx, cy)
	return spy


func _baptize(sim: Simulation, n: int) -> void:
	var ids := _peasants(sim)
	for k in n:
		sim.mission.baptized[ids[k]] = true


func _choose(sim: Simulation, question: String, option: int) -> void:
	sim.apply_now(SimCommand.choose(sim.tick, P, StringName(question), option))


func _znakharka(sim: Simulation, cx: int, cy: int) -> int:
	var z := sim.spawn_unit(
		&"gdl_znakharka", P, Fixed.from_cells(cx) + Fixed.HALF, Fixed.from_cells(cy) + Fixed.HALF
	)
	sim.apply_now(
		SimCommand.set_stance(sim.tick, P, PackedInt32Array([z]), EntityStore.Stance.PASSIVE)
	)
	sim.economy.player(P).power = 200 * MagicSystem.POWER_UNIT
	return z


func _mist(sim: Simulation, z: int, cx: int, cy: int) -> void:
	sim.apply_now(
		SimCommand.cast(
			sim.tick,
			P,
			PackedInt32Array([z]),
			&"sp_bog_mist",
			Fixed.from_cells(cx) + Fixed.HALF,
			Fixed.from_cells(cy) + Fixed.HALF
		)
	)


# --- setup ----------------------------------------------------------------------------------


func test_the_yard_the_pagans_and_the_places_are_set_up() -> void:
	var sim := _sim()
	var m := sim.mission
	assert_eq(sim.nav.width, 160)
	assert_eq(sim.nav.height, 160)
	assert_true(sim.sides.friendly(P, ENVOYS), "the envoys are on our side")
	assert_true(sim.sides.hostile(P, ORDER))
	assert_true(sim.sides.hostile(P, PAGANS), "the pagans are a side of their own")
	assert_true(sim.sides.hostile(ORDER, PAGANS))
	assert_eq(sim.economy.player(P).age, 2)
	assert_true(sim.economy.player(P).locked.has(&"gdl_wagon"), "the cart is the script's")
	assert_eq(sim.magic.places.count(), 5, "the card's five places of power")
	assert_true(sim.economy.buildings.is_alive(m.named["yard"]))
	assert_true(sim.economy.buildings.is_alive(m.named["alka"]))
	for g: String in ["gintaut", "samogitians", "boyars", "pagans", "stone_guard"]:
		assert_gt(m.alive_of(g).size(), 0, "group %s is on the map" % g)
	assert_eq(_peasants(sim).size(), 15)
	assert_true(_db.unit(&"gdl_samogitian").campaign_only, "Samogitians come only with Gintaut")
	assert_eq(m.evidence, 0)
	assert_eq(m.spies.size(), 0, "no spies before the first sign of Сила")


func test_every_place_on_the_story_can_be_reached() -> void:
	var sim := _sim()
	var foot := NavGrid.MoveClass.FOOT
	var home := _cell_of(sim, sim.mission.alive_of("gintaut")[0])
	var goals: Array[Vector2i] = [
		Vector2i(31, 101), TALK_AT, GROVE_PASS, Vector2i(76, 126), Vector2i(158, 80)
	]
	goals.append_array(VILLAGES)
	for at: Array in sim.mission.def.rules["spies"]["route"]:
		goals.append(Vector2i(Num.of(at[0]), Num.of(at[1])))
	for g in goals:
		assert_eq(sim.nav.area(foot, home), sim.nav.area(foot, sim.nav.cell_at(g.x, g.y)), "%s" % g)
	var siege := NavGrid.MoveClass.SIEGE
	assert_eq(
		sim.nav.area(siege, sim.nav.cell_at(104, 79)),
		sim.nav.area(siege, sim.nav.cell_at(45, 1)),
		"the cart can roll from the yard to the trail's end"
	)


# --- chapter 1: the church and the baptism --------------------------------------------------


func test_1_the_princes_on_the_river() -> void:
	var sim := _sim()
	_check(sim)
	assert_true(sim.mission.fired.has("1"))
	assert_true(_kinds(sim).has("cutscene"))
	for oid: String in ["church", "baptize", "places", "peace", "trust"]:
		assert_eq(_state(sim, oid), MissionRuntime.Objective.ACTIVE, oid)


func test_2_the_church_is_built_and_gintaut_named_jan() -> void:
	var sim := _sim()
	_check(sim)
	assert_false(sim.mission.fired.has("2"))
	var church := _temple(sim, CHURCH_AT)
	_check(sim)
	assert_true(sim.mission.fired.has("2"))
	assert_eq(sim.mission.named["church"], church)
	assert_eq(_state(sim, "church"), MissionRuntime.Objective.DONE)
	assert_true(_kinds(sim).has("dialogue"))


func test_the_church_baptizes_one_peasant_near_it_every_ten_seconds() -> void:
	var sim := _sim()
	_temple(sim, CHURCH_AT)
	var ids := _peasants(sim)
	_put(sim, ids.slice(1), 140, 60)
	_put(sim, ids.slice(0, 1), CHURCH_AT.x, CHURCH_AT.y + 4)
	sim.run(1000)
	assert_eq(sim.mission.baptized_alive(), 1, "only the one near the church")
	_put(sim, ids, CHURCH_AT.x, CHURCH_AT.y + 4)
	sim.run(1000)
	assert_eq(sim.mission.baptized_alive(), 6, "one in every 200 ticks")


func test_4_ten_baptized_end_the_first_chapter() -> void:
	var sim := _sim()
	_skip(sim, ["1"])
	_baptize(sim, 10)
	_check(sim)
	assert_false(sim.mission.fired.has("4"), "the church first")
	_skip(sim, ["2"])
	_check(sim)
	assert_true(sim.mission.fired.has("4"))
	assert_eq(_state(sim, "delegation"), MissionRuntime.Objective.ACTIVE)


func test_hill_the_church_on_the_hill_puts_out_the_place_for_good() -> void:
	var sim := _sim()
	sim.run(400)
	var places := sim.magic.places
	_temple(sim, Vector2i(96, 52))
	_check(sim)
	assert_true(sim.mission.fired.has("hill"))
	assert_true(places.is_gone(1))
	assert_eq(places.rate_milli(1), 0)
	assert_false(places.site_free_for(P, 92, 47), "no shrine can stand there any more")
	assert_eq(sim.mission.baptism_every, 100, "faith grows twice as fast")
	assert_eq(_state(sim, "places"), MissionRuntime.Objective.FAILED)


func test_3_the_first_spy_comes_with_the_first_spell() -> void:
	var sim := _sim()
	_check(sim)
	var z := _znakharka(sim, 110, 80)
	_mist(sim, z, 110, 80)
	sim.run(3 * CHECK)
	assert_true(sim.mission.flags.has("power_spent"))
	assert_true(sim.mission.fired.has("3"))
	assert_eq(sim.mission.spies.size(), 1)
	assert_eq(sim.mission.evidence, 0, "nobody saw it")
	var spy := sim.mission.spies[0]
	assert_eq(sim.entities.owners[spy - 1], ORDER)
	assert_eq(sim.entities.stance[spy - 1], EntityStore.Stance.PASSIVE)


func test_3_also_two_minutes_after_the_start_at_the_latest() -> void:
	var sim := _sim()
	_check(sim)
	sim.mission.fired["1"] = sim.tick - 7200
	_check(sim)
	assert_true(sim.mission.fired.has("3"))


# --- evidence and spies ---------------------------------------------------------------------


func test_a_spy_at_the_alka_writes_down_the_rite() -> void:
	var sim := _sim()
	_spy(sim, ALKA.x + 2, ALKA.y)
	var before := sim.mission.evidence
	sim.run(CHECK)
	assert_eq(sim.mission.evidence - before, 100, "a tenth of a point a check")
	assert_true(sim.mission.flags.has("rite_seen"))


func test_the_baptized_slow_the_evidence_down_to_the_floor() -> void:
	var sim := _sim()
	_baptize(sim, 10)
	_spy(sim, ALKA.x + 2, ALKA.y)
	var before := sim.mission.evidence
	sim.run(CHECK)
	assert_eq(sim.mission.evidence - before, 75, "10 baptized take a quarter off")
	sim.mission.faith_bonus = 100
	before = sim.mission.evidence
	sim.run(CHECK)
	assert_eq(sim.mission.evidence - before, 40, "never below 40 %")


func test_a_spell_a_spy_sees_is_ten_points() -> void:
	var sim := _sim()
	_spy(sim, 112, 80)
	var z := _znakharka(sim, 110, 80)
	_mist(sim, z, 110, 80)
	sim.run(2 * CHECK)
	assert_eq(sim.mission.evidence, 10000)
	assert_true(sim.mission.flags.has("rite_seen"))


func test_the_mist_hides_the_alka_from_a_spy_not_right_beside_it() -> void:
	var sim := _sim()
	var z := _znakharka(sim, ALKA.x + 1, ALKA.y + 2)
	_mist(sim, z, ALKA.x, ALKA.y)
	sim.run(2 * CHECK)
	assert_true(sim.magic.mist.hides(P, ALKA.x, ALKA.y, -1))
	var spy := _spy(sim, ALKA.x + 5, ALKA.y)
	var before := sim.mission.evidence
	sim.run(CHECK)
	assert_eq(sim.mission.evidence, before, "5 cells off in the mist: nothing seen")
	_put(sim, PackedInt32Array([spy]), ALKA.x, ALKA.y + 1)
	sim.run(CHECK)
	assert_gt(sim.mission.evidence, before, "right beside it: seen")


func test_a_killed_spy_is_evidence_too_and_another_comes() -> void:
	var sim := _sim()
	var spy := _spy(sim, 120, 60)
	sim.remove_unit(spy)
	sim.run(CHECK)
	assert_eq(sim.mission.evidence, 10000)
	assert_eq(sim.mission.spies_killed, 1)
	assert_eq(sim.mission.spies.size(), 0)
	sim.run(1100)
	assert_eq(sim.mission.spies.size(), 0, "the next denunciation takes a minute")
	sim.run(200)
	assert_eq(sim.mission.spies.size(), 1)


func test_nobody_strikes_a_spy_without_an_order() -> void:
	var sim := _sim()
	var spy := _spy(sim, 106, 80)
	_put(sim, sim.mission.alive_of("samogitians"), 107, 80)
	sim.apply_now(
		SimCommand.set_stance(
			sim.tick, P, sim.mission.alive_of("samogitians"), EntityStore.Stance.AGGRESSIVE
		)
	)
	_put(sim, PackedInt32Array([spy]), 106, 80)
	var hp := sim.entities.hp[spy - 1]
	sim.run(200)
	assert_true(sim.entities.is_alive(spy))
	assert_eq(sim.entities.hp[spy - 1], hp)
	assert_eq(sim.mission.evidence, 0)


func test_the_spies_walk_their_round() -> void:
	var sim := _sim()
	sim.mission.spies_wanted = 1
	sim.run(2 * CHECK)
	var spy := sim.mission.spies[0]
	var start := sim.entities.pos_x[spy - 1]
	sim.run(400)
	assert_ne(sim.entities.pos_x[spy - 1], start)
	assert_ne(sim.entities.orders[spy - 1], EntityStore.Order.IDLE)


func test_full_evidence_is_defeat() -> void:
	var sim := _sim()
	sim.mission.evidence = 100000
	_check(sim)
	assert_true(sim.mission.fired.has("defeat_evidence"))
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.DEFEAT)


func test_gintaut_fallen_is_defeat() -> void:
	var sim := _sim()
	sim.remove_unit(sim.mission.alive_of("gintaut")[0])
	_check(sim)
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.DEFEAT)


# --- the pagans -----------------------------------------------------------------------------


func _talk(sim: Simulation, question: String) -> void:
	_put(sim, sim.mission.alive_of("gintaut"), TALK_AT.x, TALK_AT.y)
	_check(sim)
	assert_true(sim.mission.choices.has(question), "the elder asks")
	assert_true(_kinds(sim).has("choice"))


func test_talk_1_food_buys_a_truce() -> void:
	var sim := _sim()
	_skip(sim, ["1"])
	_talk(sim, "pagans_1")
	_choose(sim, "pagans_1", 0)
	assert_false(sim.mission.choices.has("pagans_1"), "the question closes")
	assert_true(_kinds(sim).has("chosen"))
	_check(sim)
	assert_true(sim.mission.fired.has("truce_1_food"))
	assert_true(sim.mission.flags.has("truce_1"))
	assert_eq(sim.economy.player(P).stock[FOOD], 50)


func test_talk_1_silver_buys_a_truce() -> void:
	var sim := _sim()
	_skip(sim, ["1"])
	_stock(sim, SILVER, 130)
	_talk(sim, "pagans_1")
	_choose(sim, "pagans_1", 1)
	_check(sim)
	assert_true(sim.mission.flags.has("truce_1"))
	assert_eq(sim.economy.player(P).stock[SILVER], 30)


func test_talk_1_promising_what_you_lack_buys_nothing_even_later() -> void:
	var sim := _sim()
	_skip(sim, ["1"])
	_stock(sim, FOOD, 100)
	_talk(sim, "pagans_1")
	_choose(sim, "pagans_1", 0)
	_check(sim)
	assert_true(sim.mission.fired.has("short_1_food"))
	_stock(sim, FOOD, 500)
	_check(sim)
	assert_false(sim.mission.flags.has("truce_1"))
	assert_eq(sim.economy.player(P).stock[FOOD], 500, "nothing is taken later either")


func test_an_answer_to_a_question_not_asked_is_ignored() -> void:
	var sim := _sim()
	_choose(sim, "pagans_1", 0)
	_choose(sim, "oak", 0)
	_check(sim)
	assert_false(sim.mission.flags.has(MissionRuntime.choice_flag("pagans_1", 0)))
	assert_false(sim.mission.fired.has("11a"), "the oak stands")
	_talk(sim, "pagans_1")
	sim.apply_now(SimCommand.choose(sim.tick, ORDER, &"pagans_1", 0))
	_choose(sim, "pagans_1", 7)
	assert_true(sim.mission.choices.has("pagans_1"), "only the player, only a real option")


func test_p1_without_a_truce_the_pagans_come_for_the_church() -> void:
	var sim := _sim()
	_skip(sim, ["1"])
	var church := _temple(sim, CHURCH_AT)
	_check(sim)
	sim.mission.fired["2"] = sim.tick - 6000
	_check(sim)
	assert_true(sim.mission.fired.has("p1"))
	var raid := sim.mission.alive_of("pagan_raid_1")
	assert_eq(raid.size(), 5)
	assert_eq(sim.entities.owners[raid[0] - 1], PAGANS)
	assert_ne(sim.entities.orders[raid[0] - 1], EntityStore.Order.IDLE, "going for the church")
	assert_true(sim.economy.buildings.is_alive(church))


func test_p1_a_truce_keeps_them_home() -> void:
	var sim := _sim()
	_skip(sim, ["1"])
	sim.mission.flags["truce_1"] = sim.tick
	sim.mission.fired["2"] = sim.tick - 6000
	_check(sim)
	assert_false(sim.mission.fired.has("p1"))


func test_killing_a_pagan_loses_the_peace() -> void:
	var sim := _sim()
	_check(sim)
	sim.remove_unit(sim.mission.alive_of("stone_guard")[0])
	_check(sim)
	assert_true(sim.mission.fired.has("peace_lost"))
	assert_eq(_state(sim, "peace"), MissionRuntime.Objective.FAILED)


# --- chapter 2: the cart ----------------------------------------------------------------------


func _chapter_2(sim: Simulation) -> void:
	_skip(sim, ["1", "2", "3"])
	_check(sim)
	_skip(sim, ["4"])
	_stock(sim, SILVER, 450)
	_stock(sim, FOOD, 260)
	_check(sim)
	assert_true(sim.mission.fired.has("5"))


func test_5_the_journey_paid_and_the_cart_sets_off() -> void:
	var sim := _sim()
	_chapter_2(sim)
	assert_eq(sim.economy.player(P).stock[SILVER], 50)
	assert_eq(sim.economy.player(P).stock[FOOD], 60)
	var cart := sim.mission.alive_of("delegation")
	assert_eq(cart.size(), 1)
	assert_eq(sim.entities.type_ids[cart[0] - 1], &"gdl_wagon")
	assert_eq(_state(sim, "cart"), MissionRuntime.Objective.ACTIVE)
	sim.run(200)
	assert_ne(sim.entities.orders[cart[0] - 1], EntityStore.Order.IDLE, "it goes by itself")


func test_5b_prussian_riders_by_the_northern_ford() -> void:
	var sim := _sim()
	_chapter_2(sim)
	_put(sim, sim.mission.alive_of("delegation"), 56, 40)
	_check(sim)
	assert_true(sim.mission.fired.has("5b"))
	assert_eq(sim.mission.alive_of("trail_patrol").size(), 3)


func test_the_cart_destroyed_is_defeat() -> void:
	var sim := _sim()
	_chapter_2(sim)
	sim.remove_unit(sim.mission.alive_of("delegation")[0])
	_check(sim)
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.DEFEAT)


func test_6_the_cart_leaves_by_the_trail() -> void:
	var sim := _sim()
	_chapter_2(sim)
	_put(sim, sim.mission.alive_of("delegation"), 45, 1)
	_check(sim)
	_check(sim)
	assert_true(sim.mission.fired.has("6"))
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.NONE, "gone, not destroyed")
	assert_eq(_state(sim, "cart"), MissionRuntime.Objective.DONE)
	assert_eq(_state(sim, "raid"), MissionRuntime.Objective.ACTIVE)
	assert_eq(sim.mission.spies_wanted, 2)


# --- chapter 3: the raid --------------------------------------------------------------------


func _chapter_3(sim: Simulation) -> int:
	_check(sim)
	_skip(sim, ["2", "3", "4", "5"])
	var church := _temple(sim, CHURCH_AT)
	sim.mission.named["church"] = church
	sim.mission.fired["6"] = sim.tick - 2400
	sim.mission.run({"do": "objective", "id": "raid", "text": "x"}, sim.tick)
	sim.mission.run(
		{"do": "objective", "id": "church_stands", "text": "x", "optional": true}, sim.tick
	)
	_check(sim)
	assert_true(sim.mission.fired.has("6b"))
	return church


func test_6b_the_order_comes_across_the_ford_for_the_church() -> void:
	var sim := _sim()
	_chapter_3(sim)
	var raid := sim.mission.alive_of("raid")
	assert_eq(raid.size(), 9)
	assert_eq(sim.entities.owners[raid[0] - 1], ORDER)
	assert_ne(sim.entities.orders[raid[0] - 1], EntityStore.Order.IDLE)


func test_7b_a_burned_church_is_evidence() -> void:
	var sim := _sim()
	var church := _chapter_3(sim)
	var before := sim.mission.evidence
	sim.economy.destroy(church)
	_check(sim)
	assert_true(sim.mission.fired.has("7b"))
	assert_eq(sim.mission.evidence - before, 25000)
	assert_eq(_state(sim, "church_stands"), MissionRuntime.Objective.FAILED)


func test_7_the_raid_beaten_back() -> void:
	var sim := _sim()
	_chapter_3(sim)
	for id in sim.mission.alive_of("raid"):
		sim.remove_unit(id)
	_check(sim)
	assert_true(sim.mission.fired.has("7"))
	assert_eq(_state(sim, "raid"), MissionRuntime.Objective.DONE)
	assert_eq(_state(sim, "church_stands"), MissionRuntime.Objective.DONE)


func test_p3_the_pagans_come_again_without_a_truce() -> void:
	var sim := _sim()
	_chapter_3(sim)
	sim.mission.fired["6"] = sim.tick - 4800
	_check(sim)
	assert_true(sim.mission.fired.has("p3"))
	assert_eq(sim.mission.alive_of("pagan_raid_3").size(), 6)


func test_talk_3_the_elder_asks_again() -> void:
	var sim := _sim()
	_chapter_3(sim)
	_talk(sim, "pagans_3")
	_choose(sim, "pagans_3", 0)
	_check(sim)
	assert_true(sim.mission.flags.has("truce_3"))


func test_8_and_9_the_fire_goes_underground_and_the_envoys_come() -> void:
	var sim := _sim()
	_chapter_3(sim)
	_skip(sim, ["7"])
	sim.run(300 + CHECK)
	assert_true(sim.mission.fired.has("8"))
	assert_eq(sim.mission.alive_of("keeper").size(), 1)
	assert_true(sim.combat.untouchable.has(sim.mission.alive_of("keeper")[0]))
	assert_eq(sim.magic.places.quenched[0], 500, "the grove gives half its Сила")
	assert_false(sim.magic.places.is_gone(0))
	sim.run(600)
	assert_true(sim.mission.fired.has("9"))
	assert_eq(sim.mission.alive_of("envoys").size(), 1)
	assert_eq(sim.mission.alive_of("vilnius").size(), 2)
	assert_eq(_state(sim, "envoys"), MissionRuntime.Objective.ACTIVE)
	assert_eq(_state(sim, "village_1"), MissionRuntime.Objective.ACTIVE)


# --- chapter 4: the envoys ------------------------------------------------------------------


func _chapter_4(sim: Simulation) -> void:
	_chapter_3(sim)
	_skip(sim, ["7", "8"])
	sim.mission.fired["8"] = sim.tick - 600
	_check(sim)
	assert_true(sim.mission.fired.has("9"))


func _envoys(sim: Simulation) -> PackedInt32Array:
	return sim.mission.alive_of("envoys")


func test_10_1_the_envoys_wait_for_a_church_in_the_village() -> void:
	var sim := _sim()
	_chapter_4(sim)
	_put(sim, _envoys(sim), VILLAGES[0].x, VILLAGES[0].y)
	_check(sim)
	assert_false(sim.mission.fired.has("10.1"), "no church there yet")
	_temple(sim, VILLAGES[0] + Vector2i(3, 3))
	_check(sim)
	assert_true(sim.mission.fired.has("10.1"))
	assert_eq(sim.mission.faith_bonus, 5)
	assert_eq(_state(sim, "village_1"), MissionRuntime.Objective.DONE)
	assert_ne(sim.entities.orders[_envoys(sim)[0] - 1], EntityStore.Order.IDLE)


func _at_the_grove(sim: Simulation) -> void:
	_chapter_4(sim)
	_skip(sim, ["10.1"])
	_put(sim, _envoys(sim), GROVE_PASS.x, GROVE_PASS.y)


func test_11_the_envoys_see_the_oak() -> void:
	var sim := _sim()
	_at_the_grove(sim)
	_check(sim)
	assert_true(sim.mission.fired.has("11"))
	assert_true(sim.mission.choices.has("oak"))


func test_11m_the_mist_hides_the_oak() -> void:
	var sim := _sim()
	_chapter_4(sim)
	_skip(sim, ["10.1"])
	var z := _znakharka(sim, ALKA.x + 1, ALKA.y + 2)
	_mist(sim, z, ALKA.x, ALKA.y)
	sim.run(2 * CHECK)
	_put(sim, _envoys(sim), GROVE_PASS.x, GROVE_PASS.y)
	_check(sim)
	assert_true(sim.mission.fired.has("11m"))
	assert_false(sim.mission.fired.has("11"))
	assert_false(sim.mission.choices.has("oak"))


func test_11a_the_oak_cut_down() -> void:
	var sim := _sim()
	_at_the_grove(sim)
	_check(sim)
	sim.mission.evidence = 30000
	_choose(sim, "oak", 0)
	_check(sim)
	assert_true(sim.mission.fired.has("11a"))
	assert_true(sim.magic.places.is_gone(0))
	assert_false(sim.economy.buildings.is_alive(sim.mission.named["alka"]), "the alka with it")
	assert_lt(sim.mission.evidence, 30000 - 19000, "20 points off (spies may add a little)")
	assert_eq(sim.mission.alive_of("pagans_angry").size(), 4)
	assert_eq(_state(sim, "places"), MissionRuntime.Objective.FAILED)


func test_11b_c_d_round_the_grove_over_the_hills_into_an_ambush() -> void:
	var sim := _sim()
	_at_the_grove(sim)
	_check(sim)
	_choose(sim, "oak", 1)
	_check(sim)
	assert_true(sim.mission.fired.has("11b"))
	assert_false(sim.magic.places.is_gone(0), "the oak stands")
	_put(sim, _envoys(sim), 76, 126)
	_check(sim)
	assert_true(sim.mission.fired.has("11c"))
	assert_eq(sim.mission.alive_of("ambush").size(), 6)
	assert_true(sim.mission.fired.has("11d"))
	assert_ne(sim.entities.orders[_envoys(sim)[0] - 1], EntityStore.Order.IDLE, "on to village 2")


func test_11c_no_ambush_under_a_truce() -> void:
	var sim := _sim()
	_at_the_grove(sim)
	sim.mission.flags["truce_4"] = sim.tick
	_check(sim)
	_choose(sim, "oak", 1)
	_check(sim)
	_put(sim, _envoys(sim), 76, 126)
	_check(sim)
	assert_false(sim.mission.fired.has("11c"))


func test_talk_4_and_p4() -> void:
	var sim := _sim()
	_chapter_4(sim)
	_talk(sim, "pagans_4")
	_skip(sim, ["10.1"])
	sim.mission.fired["10.1"] = sim.tick - 1200
	_check(sim)
	assert_true(sim.mission.fired.has("p4"), "no answer, no truce")
	assert_eq(sim.mission.alive_of("pagan_raid_4").size(), 6)


func test_10_2_10_3_and_12_the_road_to_medininkai_and_victory() -> void:
	var sim := _sim()
	_chapter_4(sim)
	_skip(sim, ["10.1", "11", "11b", "11d"])
	sim.mission.flags["truce_4"] = sim.tick
	for v: Vector2i in [VILLAGES[1], VILLAGES[2]]:
		_temple(sim, v + Vector2i(3, 3))
		_put(sim, _envoys(sim), v.x, v.y)
		_check(sim)
	assert_true(sim.mission.fired.has("10.2"))
	assert_true(sim.mission.fired.has("10.3"))
	assert_eq(sim.mission.faith_bonus, 10)
	_put(sim, _envoys(sim), 158, 80)
	_check(sim)
	_check(sim)
	assert_true(sim.mission.fired.has("12"))
	assert_true(sim.mission.fired.has("trust_ok"))
	assert_true(sim.mission.fired.has("places_ok"))
	assert_true(sim.mission.fired.has("peace_ok"))
	sim.run(300 + CHECK)
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.VICTORY)
	assert_eq(sim.victory.winner, P)


func test_trust_lost_with_thirty_points() -> void:
	var sim := _sim()
	_chapter_4(sim)
	sim.mission.evidence = 35000
	_skip(sim, ["12"])
	_check(sim)
	assert_true(sim.mission.fired.has("trust_lost"))
	assert_eq(_state(sim, "trust"), MissionRuntime.Objective.FAILED)


func test_the_envoys_killed_is_defeat() -> void:
	var sim := _sim()
	_chapter_4(sim)
	sim.remove_unit(_envoys(sim)[0])
	_check(sim)
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.DEFEAT)


# --- saving and the panel -------------------------------------------------------------------


func test_save_and_load_keep_the_spies_the_evidence_and_the_question() -> void:
	var sim := _sim()
	_skip(sim, ["1"])
	_spy(sim, ALKA.x + 2, ALKA.y)
	_baptize(sim, 3)
	_temple(sim, CHURCH_AT)
	_talk(sim, "pagans_1")
	sim.run(300)
	var data := SimSave.capture(sim)
	var loaded := SimSave.restore(data, _db)
	assert_not_null(loaded)
	assert_eq(loaded.state_hash(), data["hash"])
	assert_eq(loaded.mission.evidence, sim.mission.evidence)
	assert_eq(loaded.mission.spies, sim.mission.spies)
	assert_true(loaded.mission.choices.has("pagans_1"))
	_choose(sim, "pagans_1", 0)
	loaded.apply_now(SimCommand.choose(loaded.tick, P, &"pagans_1", 0))
	sim.run(600)
	loaded.run(600)
	assert_eq(loaded.state_hash(), sim.state_hash(), "and it plays on the same")
	assert_eq(loaded.mission.fired, sim.mission.fired)


func test_a_quenched_place_changes_the_hash() -> void:
	var a := _sim()
	var b := _sim()
	b.mission.run({"do": "quench", "place": 0, "permille": 500}, b.tick)
	assert_ne(a.state_hash(), b.state_hash())


func test_the_panel_shows_the_evidence_and_asks_the_question() -> void:
	var sim := _sim()
	_skip(sim, ["1"])
	var clock := SimClock.new()
	clock.sim = sim
	add_child_autofree(clock)
	var panel := MissionPanel.new()
	add_child_autofree(panel)
	panel.attach(sim, clock, null)
	sim.mission.evidence = 12500
	_baptize(sim, 2)
	panel.poll()
	assert_eq(panel.evidence_text(), "Evidence: 12 of 100\nBaptized: 2")
	_talk(sim, "pagans_1")
	panel.poll()
	assert_eq(panel.asking(), "pagans_1")
	panel.answer(0)
	assert_eq(panel.asking(), "")
	sim.run(2 * CHECK)
	assert_true(sim.mission.flags.has("truce_1"))
