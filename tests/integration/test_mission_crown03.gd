# gdlint:ignore = max-public-methods
extends GutTest
## «Корона 3. Балтийская вода, 1433»: one test per trigger of the mission card and per rule of
## MissionBaltic (the concord and the orphans' mutiny, the orphans following their leaders, the
## wagenburg at the camps, the wind and the fire at Tczew, the garrison giving itself up, the
## prisoners, the villages, the chapels, hunger, the knighting on the shore) and for the Hussite
## war wagons and flailmen. The world is put into the condition and the result is checked;
## earlier triggers a test does not need are marked as fired by hand.

const MISSION := "crown_03"
const P := 1
const ORDER := 2
const MIKOLAJ := 3
const ORPHANS := 4
const GDANSK := 5
const CHECK := MissionRuntime.CHECK_EVERY
const CAMPS: Array[Vector2i] = [
	Vector2i(50, 168), Vector2i(50, 140), Vector2i(44, 104), Vector2i(52, 46)
]
## Far from everybody, in the fields west of the road.
const FAR := Vector2i(30, 90)
const TOWN := Vector2i(79, 103)
const BOULDER := Vector2i(47, 11)

var _db: CatalogDB


func before_all() -> void:
	_db = CatalogDB.load_prototype()


## The mission at its start; `quiet`: without the Chojnice sortie (trigger 1b) coming at Jaśko.
func _sim(quiet: bool = true) -> Simulation:
	var sim := MissionSetup.new_simulation(MISSION, 1, _db, "normal")
	assert_not_null(sim)
	if quiet:
		sim.mission.fired["1b"] = 0
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


func _b(sim: Simulation, name: String) -> int:
	return sim.mission.named.get(name, 0)


## Jaśko alone of the player's army, far away from everybody (the lost wagons do not end the
## mission).
func _clear(sim: Simulation) -> void:
	_skip(sim, ["defeat_wagons", "leave_lost"])
	var jasko := sim.mission.alive_of("jasko")[0]
	for id in sim.entities.alive_ids.duplicate():
		if sim.entities.owners[id - 1] == P and id != jasko:
			sim.remove_unit(id)
	_put(sim, PackedInt32Array([jasko]), FAR)


## The wagons of the group standing in a ring of radius 4 round `at`.
func _ring(sim: Simulation, ids: PackedInt32Array, at: Vector2i) -> void:
	for i in ids.size():
		var a := TAU * i / ids.size()
		sim.entities.pos_x[ids[i] - 1] = _fx(at.x) + int(cos(a) * 4.0 * Fixed.ONE)
		sim.entities.pos_y[ids[i] - 1] = _fx(at.y) + int(sin(a) * 4.0 * Fixed.ONE)
		sim.entities.stop(ids[i])


# --- setup ----------------------------------------------------------------------------------


func test_the_long_map_the_towns_and_the_sides_are_set_up() -> void:
	var sim := _sim()
	var m := sim.mission
	assert_eq(sim.nav.width, 100)
	assert_eq(sim.nav.height, 220)
	for p: int in [MIKOLAJ, ORPHANS]:
		assert_true(sim.sides.friendly(P, p), "player %d is on our side" % p)
	for p: int in [ORDER, GDANSK]:
		assert_true(sim.sides.hostile(P, p), "player %d is the enemy" % p)
	assert_true(m.baltic.on)
	assert_eq(m.baltic.concord, 700)
	assert_eq(m.baltic.suburb.size(), 11, "the wooden suburb of Tczew")
	assert_true(sim.fire.wooden.has(_b(sim, "tczew_gate")), "the gate burns")
	assert_eq(sim.magic.places.count(), 3, "the cross, the monks' well and the boulder")
	assert_eq(m.alive_of("wagons").size(), 12)
	assert_eq(m.alive_of("orphan_wagons").size(), 8)
	assert_eq(sim.nav.terrain_at(sim.nav.cell_at(46, 2)), &"t_water", "the sea in the north")
	assert_eq(sim.economy.player(P).age, 2)
	for v in 8:
		assert_true(sim.economy.buildings.is_alive(_b(sim, "village_%d" % (v + 1))))


func test_the_army_can_reach_every_camp_and_the_shore() -> void:
	var sim := _sim()
	for goal: Vector2i in CAMPS + [TOWN, BOULDER + Vector2i(0, 2)]:
		var to := sim.nav.cell_at(goal.x, goal.y)
		for g: String in ["jasko", "lances", "wagons", "orphan_wagons", "mikolaj"]:
			var id := sim.mission.alive_of(g)[0]
			var from := sim.nav.cell_of(sim.entities.pos_x[id - 1], sim.entities.pos_y[id - 1])
			var cls := sim.entities.move_class[id - 1]
			if goal == TOWN:
				continue
			assert_eq(sim.nav.area(cls, from), sim.nav.area(cls, to), "%s to %s" % [g, goal])


func test_crown_3_is_made_and_playable() -> void:
	assert_true(CampaignProgress.is_made("crown_03"))
	assert_eq(CampaignProgress.title_key("crown_03"), "Crown 3. Baltic Water, 1433")
	var def := MissionDef.load_id("crown_03")
	assert_eq(def.carry, PackedStringArray(["knights", "pact"]))


# --- Chojnice -------------------------------------------------------------------------------


func test_1_six_weeks_and_the_objectives() -> void:
	var sim := _sim()
	_check(sim)
	assert_true(_has_event(sim, "cutscene", "six_weeks"))
	assert_eq(_state(sim, "leave"), MissionRuntime.Objective.ACTIVE)
	for oid: String in ["monks", "chapels", "concord_half", "knights"]:
		assert_true(sim.mission.objective_optional[oid], oid)


func test_1b_the_commander_sends_his_horse_after_the_wagons() -> void:
	var sim := _sim(false)
	sim.run(520)
	assert_true(sim.mission.fired.has("1b"))
	assert_eq(sim.mission.alive_of("fishborn").size(), 6)


func test_2_the_wagons_out_of_the_trenches_send_mikolaj_to_the_first_camp() -> void:
	var sim := _sim()
	_check(sim)
	_put(sim, sim.mission.alive_of("wagons"), Vector2i(50, 176))
	_check(sim)
	var m := sim.mission
	assert_true(m.fired.has("2"))
	assert_eq(_state(sim, "leave"), MissionRuntime.Objective.DONE)
	assert_eq(_state(sim, "camps"), MissionRuntime.Objective.ACTIVE)
	assert_true(_has_event(sim, "dialogue", "wheel_to_wheel"))


func test_a_wagon_lost_before_the_road_fails_the_leaving() -> void:
	var sim := _sim()
	_check(sim)
	sim.remove_unit(sim.mission.alive_of("wagons")[0])
	_check(sim)
	assert_eq(_state(sim, "leave"), MissionRuntime.Objective.FAILED)


func test_the_orphans_follow_capek_and_capek_follows_mikolaj_once_on_the_march() -> void:
	var sim := _sim()
	var m := sim.mission
	var capek := m.alive_of("capek")[0]
	sim.run(MissionBaltic.FOLLOW_EVERY + 1)
	assert_eq(sim.entities.orders[capek - 1], EntityStore.Order.IDLE, "not before the march")
	_skip(sim, ["1", "2"])
	sim.run(MissionBaltic.FOLLOW_EVERY + 1)
	assert_ne(sim.entities.orders[capek - 1], EntityStore.Order.IDLE, "he rides to Mikołaj")


# --- the camps ------------------------------------------------------------------------------


func test_a_ring_of_wagons_at_a_camp_holds_it_and_brings_the_night_raid() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "1b", "2"])
	_ring(sim, m.alive_of("wagons"), CAMPS[0])
	sim.run(sim.combat.rules.tabor_link_ticks + 2 * CHECK)
	assert_true(m.baltic.camps_now & 1 != 0, "the first camp is held")
	assert_true(m.flags.has("camp_0"))
	assert_eq(m.baltic.camps_count(), 1)
	_check(sim)
	assert_true(m.fired.has("3"), "the Order's riders come at night")
	assert_eq(m.alive_of("raiders").size(), 9)


func test_wagons_standing_apart_hold_no_camp() -> void:
	var sim := _sim()
	var m := sim.mission
	var wagons := m.alive_of("wagons")
	for i in wagons.size():
		_put(sim, PackedInt32Array([wagons[i]]), CAMPS[0] + Vector2i(i * 5 - 30, 0))
	sim.run(260)
	assert_eq(m.baltic.camps_count(), 0)


func test_the_tabor_action_draws_the_orphans_wagons_into_a_ring() -> void:
	var sim := _sim()
	var m := sim.mission
	m.run({"do": "tabor", "group": "orphan_wagons"}, sim.tick)
	sim.run(400)
	var crown := sim.combat.crown
	assert_true(crown.ring_owner.has(ORPHANS), "the orphans' tabor stands")
	var i := crown.ring_owner.find(ORPHANS)
	assert_eq(crown.ring_melee[i], 4, "+4/+4 inside a Hussite tabor")
	assert_eq(crown.ring_pierce[i], 4)


func test_a_flailman_by_his_wagon_strikes_cavalry_harder() -> void:
	var sim := _sim()
	_clear(sim)
	var flail := _one(sim, &"nt_hussite_flail", ORPHANS, FAR + Vector2i(0, 10))
	var cav: Array[StringName] = [&"heavy_cavalry", &"cavalry"]
	sim.run(2)
	assert_eq(sim.combat.crown.wagon_bonus(flail - 1, cav), 0, "no wagon by him")
	_one(sim, &"nt_hussite_wagon", ORPHANS, FAR + Vector2i(1, 10))
	sim.run(2)
	assert_eq(sim.combat.crown.wagon_bonus(flail - 1, cav), 4)
	var foot: Array[StringName] = [&"infantry"]
	assert_eq(sim.combat.crown.wagon_bonus(flail - 1, foot), 0, "only against cavalry")


# --- Pelplin and the wages ------------------------------------------------------------------


func test_4_at_pelplin_the_monks_come_out_and_the_orphans_go_with_torches() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "1b", "2", "3", "3b"])
	_put(sim, m.alive_of("jasko"), Vector2i(40, 140))
	_check(sim)
	assert_true(m.fired.has("4"))
	assert_true(_has_event(sim, "cutscene", "pelplin"))
	assert_eq(m.alive_of("monks").size(), 4)
	assert_eq(sim.entities.owners[m.alive_of("monks")[0] - 1], P, "the player leads them")
	assert_eq(m.alive_of("burners").size(), 6)


func test_monks_brought_to_the_camp_are_saved_and_pelplin_burns_anyway() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "1b", "2", "3", "3b"])
	_put(sim, m.alive_of("jasko"), Vector2i(40, 140))
	_check(sim)
	_put(sim, m.alive_of("monks"), CAMPS[1])
	_check(sim)
	_check(sim)
	assert_eq(_state(sim, "monks"), MissionRuntime.Objective.DONE)
	sim.run(1200)
	assert_true(m.fired.has("4b"))
	assert_true(sim.fire.is_burning(_b(sim, "pelplin")), "the abbey burns")


func test_monks_left_behind_fail_when_the_abbey_burns() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "1b", "2", "3", "3b"])
	_put(sim, m.alive_of("jasko"), Vector2i(40, 140))
	_check(sim)
	m.fired["4"] = sim.tick - 1200
	_check(sim)
	_check(sim)
	assert_eq(_state(sim, "monks"), MissionRuntime.Objective.FAILED)


func _to_wages(sim: Simulation) -> void:
	var m := sim.mission
	_skip(sim, ["1", "1b", "2", "3", "3b"])
	m.fired["4"] = sim.tick - 500
	_put(sim, m.alive_of("mikolaj"), CAMPS[1])
	_check(sim)
	assert_true(m.fired.has("5"))
	assert_true(m.choices.has("wages_1"))


func test_5_paid_wages_cost_100_silver_and_raise_the_concord() -> void:
	var sim := _sim()
	_to_wages(sim)
	var silver := sim.economy.player(P).stock[EconomySystem.SILVER]
	sim.enqueue(SimCommand.choose(sim.tick, P, &"wages_1", 0))
	_check(sim)
	assert_eq(sim.economy.player(P).stock[EconomySystem.SILVER], silver - 100)
	assert_eq(sim.mission.baltic.concord, 800)
	assert_true(sim.mission.flags.has("concord_shown"))


func test_5_refused_wages_cost_the_concord() -> void:
	var sim := _sim()
	_to_wages(sim)
	sim.enqueue(SimCommand.choose(sim.tick, P, &"wages_1", 1))
	_check(sim)
	assert_eq(sim.mission.baltic.concord, 400)


func test_5_wages_without_the_silver_count_as_a_refusal() -> void:
	var sim := _sim()
	_to_wages(sim)
	sim.economy.player(P).stock[EconomySystem.SILVER] = 50
	sim.enqueue(SimCommand.choose(sim.tick, P, &"wages_1", 0))
	_check(sim)
	assert_eq(sim.mission.baltic.concord, 450)
	assert_eq(sim.economy.player(P).stock[EconomySystem.SILVER], 50)


# --- the concord ----------------------------------------------------------------------------


func test_concord_at_nothing_is_a_mutiny_that_passes() -> void:
	var sim := _sim()
	var m := sim.mission
	_check(sim)
	m.baltic.add_concord(m, -1000, sim.tick)
	sim.run(2)
	assert_eq(m.baltic.mutinies, 1)
	assert_true(m.flags.has("mutiny"))
	var flail := m.alive_of("orphans")[0]
	assert_eq(sim.entities.stance[flail - 1], EntityStore.Stance.STAND, "the orphans stand")
	m.baltic.add_concord(m, 300, sim.tick)
	assert_eq(m.baltic.concord, 0, "nothing moves it during the mutiny")
	sim.run(2400 + CHECK)
	assert_eq(m.baltic.concord, 400, "it starts again from 40%")
	assert_true(m.flags.has("mutiny_over"))
	assert_eq(sim.entities.stance[flail - 1], EntityStore.Stance.AGGRESSIVE)
	assert_eq(_state(sim, "concord_half"), MissionRuntime.Objective.FAILED)


func test_a_second_mutiny_sends_the_orphans_home() -> void:
	var sim := _sim()
	var m := sim.mission
	_check(sim)
	m.baltic.mutinies = 1
	m.baltic.add_concord(m, -1000, sim.tick)
	_check(sim)
	assert_true(m.is_over())
	assert_eq(m.outcome, MissionRuntime.Outcome.DEFEAT)


# --- Tczew ----------------------------------------------------------------------------------


func test_6_before_tczew_the_west_wind() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "1b", "2", "3", "3b", "4", "4b", "5", "6go"])
	_put(sim, m.alive_of("jasko"), CAMPS[2])
	_check(sim)
	assert_true(m.fired.has("6"))
	assert_true(_has_event(sim, "cutscene", "west_wind"))
	assert_eq(_state(sim, "tczew"), MissionRuntime.Objective.ACTIVE)


func test_the_wind_carries_the_fire_east_and_not_west() -> void:
	var sim := _sim()
	var first := _b(sim, "suburb_1")
	var east := _b(sim, "suburb_5")
	var south := _b(sim, "suburb_2")
	sim.fire.ignite(first)
	sim.run(MissionBaltic.WIND_EVERY + 1)
	assert_true(sim.fire.is_burning(east), "downwind, east of it")
	assert_false(sim.fire.is_burning(south), "beside it, not ahead")
	var sim2 := _sim()
	sim2.fire.ignite(_b(sim2, "suburb_8"))
	sim2.run(2 * MissionBaltic.WIND_EVERY + 1)
	assert_false(sim2.fire.is_burning(_b(sim2, "suburb_1")), "never upwind")


func test_the_smoke_burns_who_stands_downwind() -> void:
	var sim := _sim()
	_clear(sim)
	var b := _b(sim, "suburb_2")
	var east := _one(sim, &"pl_crossbow", P, Vector2i(60, 101))
	var west := _one(sim, &"pl_crossbow", P, Vector2i(55, 101))
	sim.fire.ignite(b)
	sim.run(MissionBaltic.WIND_EVERY + 1)
	assert_lt(sim.entities.hp[east - 1], sim.entities.max_hp[east - 1])
	assert_eq(sim.entities.hp[west - 1], sim.entities.max_hp[west - 1])


func test_a_burned_suburb_sets_the_gate_alight() -> void:
	var sim := _sim()
	var m := sim.mission
	for n in 8:
		sim.economy.destroy(_b(sim, "suburb_%d" % (n + 1)))
	sim.run(MissionBaltic.WIND_EVERY + 1)
	assert_true(m.flags.has("suburb_burnt"))
	assert_true(sim.fire.is_burning(_b(sim, "tczew_gate")))


func test_7_the_gate_burns_down_and_the_garrison_gives_itself_up() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "1b", "2", "3", "3b", "4", "4b", "5", "6go", "6"])
	sim.economy.destroy(_b(sim, "tczew_gate"))
	_check(sim)
	assert_true(m.fired.has("7"))
	var before := m.alive_of("tczew_all").size()
	sim.run(200)
	assert_eq(m.baltic.surrendered, 0, "nobody of ours in the town yet")
	_put(sim, m.alive_of("jasko"), TOWN)
	sim.run(110)
	assert_eq(m.baltic.surrendered, 2)
	assert_lt(m.alive_of("tczew_all").size(), before)


func _take_tczew(sim: Simulation) -> void:
	var m := sim.mission
	_skip(sim, ["1", "1b", "2", "3", "3b", "4", "4b", "5", "6go"])
	_put(sim, m.alive_of("jasko"), CAMPS[2])
	_check(sim)
	assert_true(m.fired.has("6"))
	_skip(sim, ["7"])
	for id in m.alive_of("tczew_all"):
		sim.remove_unit(id)
	_check(sim)
	assert_true(m.fired.has("8"))


func test_8_tczew_taken_brings_the_prisoners_and_the_tar_barrel() -> void:
	var sim := _sim()
	var m := sim.mission
	_take_tczew(sim)
	assert_eq(_state(sim, "tczew"), MissionRuntime.Objective.DONE)
	assert_eq(m.alive_of("prisoners").size(), 6)
	assert_eq(sim.entities.owners[m.alive_of("prisoners")[0] - 1], P)
	assert_eq(m.alive_of("barrel").size(), 5)
	assert_gt(m.countdown_end, sim.tick)
	assert_true(_has_event(sim, "cutscene", "prisoners"))


func test_a_prisoner_brought_to_mikolaj_is_ransomed() -> void:
	var sim := _sim()
	var m := sim.mission
	_take_tczew(sim)
	var silver := sim.economy.player(P).stock[EconomySystem.SILVER]
	var mik := m.alive_of("mikolaj")[0]
	var at := Vector2i(
		Fixed.to_cells(sim.entities.pos_x[mik - 1]), Fixed.to_cells(sim.entities.pos_y[mik - 1])
	)
	var one := m.alive_of("prisoners")[0]
	_put(sim, PackedInt32Array([one]), at)
	_check(sim)
	assert_eq(m.baltic.ransomed, 1)
	assert_false(sim.entities.is_alive(one))
	assert_eq(sim.economy.player(P).stock[EconomySystem.SILVER], silver + 15)


func test_the_orphans_kill_the_prisoners_they_reach_after_the_countdown() -> void:
	var sim := _sim()
	var m := sim.mission
	_take_tczew(sim)
	var prisoner := m.alive_of("prisoners")[0]
	var at := Vector2i(
		Fixed.to_cells(sim.entities.pos_x[prisoner - 1]),
		Fixed.to_cells(sim.entities.pos_y[prisoner - 1])
	)
	_put(sim, m.alive_of("barrel"), at + Vector2i(1, 0))
	_check(sim)
	assert_eq(m.baltic.killed, 0, "not before the countdown runs out")
	sim.run(600)
	assert_true(m.fired.has("8b"))
	assert_gt(m.baltic.killed, 0)


func test_9_killed_prisoners_fail_the_objective_and_cost_the_concord() -> void:
	var sim := _sim()
	var m := sim.mission
	_take_tczew(sim)
	var held := m.alive_of("prisoners")
	m.baltic.killed = 1
	for id in held:
		sim.remove_unit(id)
	_check(sim)
	_check(sim)
	assert_true(m.fired.has("9"))
	assert_eq(_state(sim, "prisoners"), MissionRuntime.Objective.FAILED)
	assert_eq(m.baltic.concord, 550)
	assert_eq(m.alive_of("czech_hirelings").size(), 6, "the Czech hirelings join Jaśko")
	assert_eq(m.alive_of("trophy_wagons").size(), 3)


func test_9_all_ransomed_is_done() -> void:
	var sim := _sim()
	var m := sim.mission
	_take_tczew(sim)
	for id in m.alive_of("prisoners"):
		sim.remove_unit(id)
	_check(sim)
	_check(sim)
	assert_eq(_state(sim, "prisoners"), MissionRuntime.Objective.DONE)
	assert_eq(m.baltic.concord, 700)


# --- Gdańsk ---------------------------------------------------------------------------------


func test_10_on_the_bishops_hill_the_townsmen_come_out() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "1b", "2", "3", "3b", "4", "4b", "5", "6go", "6", "7", "8", "9", "10go"])
	_put(sim, m.alive_of("jasko"), CAMPS[3])
	_check(sim)
	assert_true(m.fired.has("10"))
	assert_true(m.retreat.next_wave >= 0, "the sorties are on")
	assert_eq(m.alive_of("foragers").size(), 6)
	_put(sim, m.alive_of("jasko"), FAR)
	sim.run(3600 + 2 * CHECK)
	assert_true(m.fired.has("11"))
	assert_true(sim.fire.is_burning(_b(sim, "oliwa")), "Oliwa burns")
	assert_true(m.choices.has("wages_2"))


func test_a_village_gives_food_and_silver_to_whoever_comes_first() -> void:
	var sim := _sim()
	var m := sim.mission
	_clear(sim)
	var stock := sim.economy.player(P).stock.duplicate()
	_one(sim, &"pl_kopia", P, Vector2i(65, 163))
	_check(sim)
	assert_eq(m.baltic.villages.get("village_1", 0), 1)
	assert_eq(sim.economy.player(P).stock[EconomySystem.FOOD], stock[EconomySystem.FOOD] + 60)
	assert_eq(sim.economy.player(P).stock[EconomySystem.SILVER], stock[EconomySystem.SILVER] + 25)
	_check(sim)
	assert_eq(sim.economy.player(P).stock[EconomySystem.SILVER], stock[EconomySystem.SILVER] + 25)
	_one(sim, &"nt_hussite_flail", ORPHANS, Vector2i(35, 169))
	_check(sim)
	assert_eq(m.baltic.villages.get("village_2", 0), 2, "the orphans plunder it")
	assert_true(sim.fire.is_burning(_b(sim, "village_2")), "and burn it")
	assert_eq(m.baltic.foraged(1), 1)
	assert_eq(m.baltic.foraged(2), 1)


func test_a_chapel_nobody_guards_is_broken_by_the_orphans() -> void:
	var sim := _sim()
	var m := sim.mission
	_clear(sim)
	var places := sim.magic.places
	var site := Vector2i(48, 116)
	var b := sim.economy.buildings.next_id
	sim.apply_now(SimCommand.place(sim.tick, P, &"pl_shrine", _fx(site.x), _fx(site.y)))
	sim.run(2)
	assert_true(sim.economy.buildings.is_alive(b))
	assert_eq(places.shrines[0], b)
	var flail := _one(sim, &"nt_hussite_flail", ORPHANS, site + Vector2i(3, 0))
	sim.entities.stance[flail - 1] = EntityStore.Stance.STAND
	sim.run(300 + 2 * CHECK)
	assert_false(sim.economy.buildings.is_alive(b))
	assert_true(m.flags.has("chapel_broken"))
	_check(sim)
	assert_eq(_state(sim, "chapels"), MissionRuntime.Objective.FAILED)


func test_a_chapel_with_our_men_by_it_stands() -> void:
	var sim := _sim()
	var m := sim.mission
	_clear(sim)
	var site := Vector2i(48, 116)
	var b := sim.economy.buildings.next_id
	sim.apply_now(SimCommand.place(sim.tick, P, &"pl_shrine", _fx(site.x), _fx(site.y)))
	_one(sim, &"nt_hussite_flail", ORPHANS, site + Vector2i(3, 0))
	_one(sim, &"pl_crossbow", P, site + Vector2i(-2, 0))
	sim.run(400)
	assert_true(sim.economy.buildings.is_alive(b))
	assert_false(m.flags.has("chapel_broken"))


func test_without_food_the_men_lose_heart() -> void:
	var sim := _sim()
	var m := sim.mission
	var lance := m.alive_of("lances")[0]
	var full := sim.entities.morale[lance - 1]
	sim.economy.player(P).stock[EconomySystem.FOOD] = 0
	sim.run(210)
	assert_true(m.flags.has("starving"))
	assert_lt(sim.entities.morale[lance - 1], full)


# --- the sea --------------------------------------------------------------------------------


func _to_sea(sim: Simulation) -> void:
	var m := sim.mission
	_skip(
		sim,
		["1", "1b", "2", "3", "3b", "4", "4b", "5", "6go", "6", "7", "8", "9", "10go", "10", "11"]
	)
	m.fired["11b"] = sim.tick
	_put(sim, m.alive_of("jasko"), Vector2i(46, 12))
	_check(sim)
	assert_true(m.fired.has("12"))


func test_12_on_the_shore_three_banners_kneel_and_are_carried() -> void:
	var sim := _sim()
	var m := sim.mission
	_to_sea(sim)
	assert_true(_has_event(sim, "cutscene", "sea_water"))
	for k in 3:
		var q := StringName("knight_%d" % (k + 1))
		assert_true(m.choices.has(String(q)), "asked %s" % q)
		sim.enqueue(SimCommand.choose(sim.tick, P, q, k))
		_check(sim)
		_check(sim)
	assert_eq(m.baltic.knights, PackedStringArray(["lances", "crossbows", "foot"]))
	assert_true(m.flags.has("knights"))
	assert_true(m.fired.has("knights_done"))
	assert_eq(_state(sim, "knights"), MissionRuntime.Objective.DONE)


func test_nobody_more_ends_the_knighting() -> void:
	var sim := _sim()
	var m := sim.mission
	_to_sea(sim)
	sim.enqueue(SimCommand.choose(sim.tick, P, &"knight_1", 3))
	_check(sim)
	_check(sim)
	assert_true(m.fired.has("knights_done"))
	assert_false(m.choices.has("knight_2"))
	assert_eq(m.baltic.knights.size(), 0)
	assert_eq(_state(sim, "knights"), MissionRuntime.Objective.FAILED)


func test_13_jasko_at_the_boulder_meets_the_stranger_and_the_mission_is_won() -> void:
	var sim := _sim()
	var m := sim.mission
	_to_sea(sim)
	sim.enqueue(SimCommand.choose(sim.tick, P, &"knight_1", 3))
	_check(sim)
	_check(sim)
	_put(sim, m.alive_of("jasko"), BOULDER)
	_check(sim)
	assert_true(m.fired.has("13"))
	assert_true(_has_event(sim, "cutscene", "second_bottle"))
	assert_eq(_state(sim, "concord_half"), MissionRuntime.Objective.DONE)
	sim.run(420)
	assert_true(m.fired.has("14"))
	assert_true(m.is_over())
	assert_eq(m.outcome, MissionRuntime.Outcome.VICTORY)


# --- defeats --------------------------------------------------------------------------------


func test_defeat_when_jasko_or_mikolaj_falls_or_the_wagons_are_lost() -> void:
	for g: String in ["jasko", "mikolaj"]:
		var sim := _sim()
		for id in sim.mission.alive_of(g):
			sim.remove_unit(id)
		_check(sim)
		assert_eq(sim.mission.outcome, MissionRuntime.Outcome.DEFEAT, g)
	var sim := _sim()
	var wagons := sim.mission.alive_of("wagons")
	for i in 6:
		sim.remove_unit(wagons[i])
	_check(sim)
	assert_false(sim.mission.is_over(), "half of them is not yet the end")
	sim.remove_unit(wagons[6])
	_check(sim)
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.DEFEAT)


# --- state ----------------------------------------------------------------------------------


func test_save_and_load_keep_the_march() -> void:
	var sim := _sim()
	var m := sim.mission
	_check(sim)
	m.baltic.add_concord(m, -200, sim.tick)
	m.baltic.villages["village_3"] = 2
	m.baltic.knights.append("lances")
	sim.run(300)
	var data := SimSave.capture(sim)
	var loaded := SimSave.restore(data, _db)
	assert_not_null(loaded)
	assert_eq(loaded.state_hash(), data["hash"])
	assert_eq(loaded.mission.baltic.concord, 500)
	assert_eq(loaded.mission.baltic.villages.get("village_3", 0), 2)
	sim.run(600)
	loaded.run(600)
	assert_eq(loaded.state_hash(), sim.state_hash(), "and it plays on the same")


func test_the_march_changes_the_hash() -> void:
	var a := _sim()
	var b := _sim()
	b.mission.baltic.concord += 1
	assert_ne(a.state_hash(), b.state_hash())
	var c := _sim()
	c.mission.baltic.villages["village_1"] = 1
	assert_ne(a.state_hash(), c.state_hash())


static func _fx(cell: int) -> int:
	return Fixed.from_cells(cell) + Fixed.HALF
