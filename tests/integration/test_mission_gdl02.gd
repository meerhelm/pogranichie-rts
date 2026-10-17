# gdlint:ignore = max-public-methods
extends GutTest
## «ВКЛ 2. Грюнвальд, 1410»: one test per trigger of the mission card (1-12) and per extra one
## (banner, defeats, optional objectives). The world is put into the trigger's condition and its
## events are checked; earlier triggers a test does not need are marked as fired by hand.

const MISSION := "gdl_02"
const P := 1
const ORDER := 2
const CROWN := 3
const SMOLENSK := 4
const VYTAUTAS := 5
const CHECK := MissionRuntime.CHECK_EVERY
const FOREST := Vector2i(138, 142)

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


func _units_of(sim: Simulation, player: int) -> int:
	var n := 0
	for id in sim.entities.alive_ids:
		if sim.entities.owners[id - 1] == player:
			n += 1
	return n


# --- setup ----------------------------------------------------------------------------------


func test_the_field_is_set_up_with_allies_and_no_base() -> void:
	var sim := _sim()
	var m := sim.mission
	assert_eq(sim.nav.width, 160)
	assert_eq(sim.nav.height, 176)
	for p: int in [CROWN, SMOLENSK, VYTAUTAS]:
		assert_true(sim.sides.friendly(P, p), "player %d is on our side" % p)
		assert_true(sim.sides.hostile(p, ORDER))
	assert_eq(sim.economy.player(P).age, 2, "Хоругвь: «Гнев Перкуна» is open")
	assert_eq(sim.economy.buildings.alive_ids.size(), 0, "a field battle: nobody has a base")
	var expected: Array[String] = [
		"gintaut", "banner", "riders", "smolensk_1", "crown", "wallenrode", "wagon_guard"
	]
	for g in expected:
		assert_gt(m.alive_of(g).size(), 0, "group %s is on the field" % g)
	assert_eq(m.bearer, m.alive_of("banner")[0], "the lance beside Gintaut carries the banner")
	assert_true(sim.combat.untouchable.has(m.alive_of("vytautas")[0]), "Vytautas cannot fall")
	assert_eq(sim.magic.places.count(), 3, "the oak, the spring and the kurgan")


func test_every_group_can_reach_the_wagenburg() -> void:
	var sim := _sim()
	var goal := sim.nav.cell_at(66, 30)
	for g: String in ["gintaut", "riders", "lances", "crown", "smolensk_2", "tatars"]:
		var id := sim.mission.alive_of(g)[0]
		var from := sim.nav.cell_at(
			Fixed.to_cells(sim.entities.pos_x[id - 1]), Fixed.to_cells(sim.entities.pos_y[id - 1])
		)
		assert_eq(sim.nav.area(0, from), sim.nav.area(0, goal), "%s can walk to the wagons" % g)


# --- 1-3: the cannonade and the attack ----------------------------------------------------


func test_1_two_swords_and_the_oak() -> void:
	var sim := _sim()
	_check(sim)
	assert_true(sim.mission.fired.has("1"))
	assert_true(_kinds(sim).has("cutscene"))
	assert_eq(_state(sim, "places"), MissionRuntime.Objective.ACTIVE)


func test_2_the_bombards_fire_after_three_minutes() -> void:
	var sim := _sim()
	sim.run(3500)
	assert_false(sim.mission.fired.has("2"))
	sim.run(120)
	assert_true(sim.mission.fired.has("2"))
	assert_true(_kinds(sim).has("dialogue"))


func test_2_also_when_the_player_crosses_the_line() -> void:
	var sim := _sim()
	_check(sim)
	_put(sim, sim.mission.alive_of("riders"), 118, 86)
	_check(sim)
	assert_true(sim.mission.fired.has("2"), "wet powder: the volley comes at once")


func test_2b_and_3_the_second_volley_and_the_order_to_attack() -> void:
	var sim := _sim()
	_skip(sim, ["1"])
	sim.mission.fired["1"] = sim.tick - 3600
	sim.run(CHECK + 1 + 300 + 200 + CHECK)
	assert_true(sim.mission.fired.has("2b"))
	assert_true(sim.mission.fired.has("3"))
	assert_eq(_state(sim, "attack"), MissionRuntime.Objective.ACTIVE)
	assert_eq(_state(sim, "bombards"), MissionRuntime.Objective.ACTIVE)
	var tatar := sim.mission.alive_of("tatars")[0]
	assert_eq(sim.entities.stance[tatar - 1], EntityStore.Stance.AGGRESSIVE, "the Tatars charge")


func test_the_bombards_taken() -> void:
	var sim := _sim()
	_phase_2(sim)
	_kill(sim, "bombards")
	_check(sim)
	assert_eq(_state(sim, "bombards"), MissionRuntime.Objective.DONE)


# --- 4-8: the retreat ----------------------------------------------------------------------


## Trigger 3 has just fired: the attack is on.
func _phase_2(sim: Simulation) -> void:
	_skip(sim, ["1", "2"])
	sim.mission.fired["2b"] = sim.tick - 200
	_check(sim)
	assert_true(sim.mission.fired.has("3"))


func test_4_the_khan_leaves_and_the_retreat_begins() -> void:
	var sim := _sim()
	_phase_2(sim)
	var since := sim.mission.fired["3"]
	sim.run(since + 6000 - CHECK - sim.tick)
	assert_false(sim.mission.fired.has("4"))
	sim.run(2 * CHECK)
	assert_true(sim.mission.fired.has("4"))
	assert_eq(_state(sim, "attack"), MissionRuntime.Objective.DONE)
	assert_eq(_state(sim, "retreat"), MissionRuntime.Objective.ACTIVE)
	var tatar := sim.mission.alive_of("tatars")[0]
	assert_eq(sim.entities.stance[tatar - 1], EntityStore.Stance.PASSIVE)


func test_5_the_lithuanian_retreat_draws_the_knights() -> void:
	var sim := _sim()
	_phase_2(sim)
	_skip(sim, ["4"])
	_check(sim)
	assert_false(sim.mission.fired.has("5"), "nobody is retreating yet")
	var riders := sim.mission.alive_of("riders")
	sim.apply_now(SimCommand.order(sim.tick, P, SimCommand.Kind.RETREAT, riders))
	_check(sim)
	assert_true(sim.mission.fired.has("5"))
	assert_eq(_state(sim, "smolensk"), MissionRuntime.Objective.ACTIVE)
	var knight := sim.mission.alive_of("pursuit")[0]
	assert_eq(sim.entities.stance[knight - 1], EntityStore.Stance.AGGRESSIVE)


func test_5_also_when_half_the_riders_are_lost() -> void:
	var sim := _sim()
	_phase_2(sim)
	_skip(sim, ["4"])
	_kill(sim, "riders", 8)
	_check(sim)
	assert_true(sim.mission.fired.has("5"))


func test_6_and_7_pursuers_scatter_and_the_first_smolensk_banner_falls() -> void:
	var sim := _sim()
	_phase_2(sim)
	_skip(sim, ["4", "5"])
	sim.run(600 + CHECK)
	assert_true(sim.mission.fired.has("6"))
	sim.run(600)
	assert_true(sim.mission.fired.has("7"))
	assert_eq(sim.mission.alive_of("smolensk_1").size(), 0, "falls by the script")
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.NONE, "two still stand")


func test_losing_a_second_smolensk_banner_fails_the_optional_objective() -> void:
	var sim := _sim()
	sim.mission.run({"do": "objective", "id": "smolensk2", "text": "x", "optional": true}, 0)
	_kill(sim, "smolensk_2")
	_check(sim)
	assert_eq(_state(sim, "smolensk2"), MissionRuntime.Objective.FAILED)


func test_8_back_at_the_forest_the_poles_sing() -> void:
	var sim := _sim()
	_phase_2(sim)
	sim.mission.run({"do": "objective", "id": "retreat", "text": "x"}, sim.tick)
	_skip(sim, ["4", "5"])
	sim.mission.fired["4"] = sim.tick - 2400
	_put(sim, sim.mission.alive_of("gintaut"), FOREST.x, FOREST.y)
	_check(sim)
	assert_true(sim.mission.fired.has("8"))
	assert_eq(_state(sim, "retreat"), MissionRuntime.Objective.DONE)
	assert_true(_kinds(sim).has("cutscene"))


# --- 9-12: the reserve and the wagenburg ---------------------------------------------------


func _phase_3(sim: Simulation) -> void:
	_phase_2(sim)
	_skip(sim, ["4", "5", "6", "7"])
	sim.mission.run({"do": "objective", "id": "smolensk", "text": "x"}, sim.tick)
	sim.mission.fired["8"] = sim.tick
	sim.run(100 + CHECK)
	assert_true(sim.mission.fired.has("9"))


func test_9_the_grand_master_leads_the_reserve_and_fresh_banners_come() -> void:
	var sim := _sim()
	var mine := _units_of(sim, P)
	_phase_3(sim)
	assert_eq(sim.mission.alive_of("jungingen").size(), 1)
	assert_eq(sim.mission.alive_of("reserve").size(), 12)
	assert_eq(_units_of(sim, P), mine + 14, "two fresh Lithuanian banners")
	assert_eq(_state(sim, "flank"), MissionRuntime.Objective.ACTIVE)


func test_the_reserve_breaks_the_centre_if_nobody_comes() -> void:
	var sim := _sim()
	_phase_3(sim)
	sim.mission.fired["9"] = sim.tick - 7200
	_check(sim)
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.DEFEAT)


func test_10_and_11_the_master_falls_and_the_reserve_breaks() -> void:
	var sim := _sim()
	_phase_3(sim)
	_kill(sim, "reserve", 8)
	_check(sim)
	assert_true(sim.mission.fired.has("10"))
	assert_eq(_state(sim, "flank"), MissionRuntime.Objective.DONE)
	assert_eq(sim.mission.alive_of("jungingen").size(), 0, "falls in the melee")
	assert_false(sim.mission.fired.has("11"))
	_kill(sim, "reserve", 3)
	_check(sim)
	assert_true(sim.mission.fired.has("11"))
	assert_eq(_state(sim, "wagenburg"), MissionRuntime.Objective.ACTIVE)
	assert_eq(_state(sim, "smolensk"), MissionRuntime.Objective.DONE)


func test_12_the_wagenburg_taken_is_victory() -> void:
	var sim := _sim()
	_phase_3(sim)
	_kill(sim, "reserve", 3)
	_check(sim)
	_check(sim)
	_kill(sim, "wagon_guard")
	_check(sim)
	assert_true(sim.mission.fired.has("12"))
	assert_eq(_state(sim, "wagenburg"), MissionRuntime.Objective.DONE)
	sim.run(100 + CHECK)
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.VICTORY)
	assert_eq(sim.victory.winner, P)


func test_9b_the_kurgan_brings_the_storm_story() -> void:
	var sim := _sim()
	_phase_3(sim)
	assert_eq(sim.magic.places.defs[2].id, &"pp_kurgan")
	sim.magic.places.holders[2] = P
	_check(sim)
	assert_true(sim.mission.fired.has("9b"))


# --- the banner and the defeats -----------------------------------------------------------


func test_the_banner_falls_and_a_rider_raises_it() -> void:
	var sim := _sim()
	var m := sim.mission
	var first := m.bearer
	_put(sim, m.alive_of("gintaut"), 30, 150)
	sim.remove_unit(first)
	_check(sim)
	assert_true(m.flags.has("banner_down"))
	assert_true(m.fired.has("banner_down"))
	var rider := m.alive_of("riders")[0]
	_put(sim, PackedInt32Array([rider]), m.banner_x / Fixed.ONE, m.banner_y / Fixed.ONE)
	_check(sim)
	assert_eq(m.bearer, rider)
	assert_true(m.flags.has("banner_raised"))
	assert_eq(m.outcome, MissionRuntime.Outcome.NONE)


func test_the_banner_not_raised_is_defeat() -> void:
	var sim := _sim()
	var m := sim.mission
	for g in m.groups:
		if sim.entities.owners[m.groups[g][0] - 1] == P and g != "banner":
			_put(sim, m.alive_of(g), 20, 160)
	sim.remove_unit(m.bearer)
	sim.run(400 + 2 * CHECK)
	assert_true(m.flags.has("banner_lost"))
	assert_eq(m.outcome, MissionRuntime.Outcome.DEFEAT)


func test_all_smolensk_banners_fallen_is_defeat() -> void:
	var sim := _sim()
	for g: String in ["smolensk_1", "smolensk_2", "smolensk_3"]:
		_kill(sim, g)
	_check(sim)
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.DEFEAT)


func test_gintaut_wounded_is_defeat() -> void:
	var sim := _sim()
	sim.remove_unit(sim.mission.alive_of("gintaut")[0])
	_check(sim)
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.DEFEAT)


func test_the_khorugv_cut_to_pieces_is_defeat() -> void:
	var sim := _sim()
	for id in sim.entities.alive_ids.duplicate():
		var t := sim.entities.type_ids[id - 1]
		if sim.entities.owners[id - 1] == P and t != &"hero_gintaut" and id != sim.mission.bearer:
			sim.remove_unit(id)
	_check(sim)
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.DEFEAT)
