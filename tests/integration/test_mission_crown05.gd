# gdlint:ignore = max-public-methods
extends GutTest
## «Корона 5. Серебро для Мальборка, 1457»: one test per trigger of the mission card and per rule
## of MissionSilver (silver carried by wagon and boat, the mercenaries' patience and their wages,
## Gdańsk's discontent, the loans and the crowd, the village taxes and the rumours, the Order's
## riders, the seasons, the piles of the old bridge and the brothers who leave the castle). The
## world is put into the condition and the result is checked; earlier triggers a test does not
## need are marked as fired by hand.

const MISSION := "crown_05"
const P := 1
const ORDER := 2
const GDANSK := 3
const MERCS := 4
const CHECK := MissionRuntime.CHECK_EVERY
const STATION := Vector2i(66, 50)
const PIER := Vector2i(112, 40)
const PIER_WATER := Vector2i(114, 41)
const GATE := Vector2i(107, 93)
const YARD := Vector2i(113, 96)
const HALL := Vector2i(14, 18)
const VILLAGE := Vector2i(52, 36)
## In the polders, away from the villages, the towns and the roads the riders take.
const FAR := Vector2i(60, 66)

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


func _state(sim: Simulation, oid: String) -> int:
	return sim.mission.objective_state.get(oid, -1)


func _put(sim: Simulation, ids: PackedInt32Array, c: Vector2i) -> void:
	for id in ids:
		sim.entities.pos_x[id - 1] = _fx(c.x)
		sim.entities.pos_y[id - 1] = _fx(c.y)
		sim.entities.stop(id)


func _one(sim: Simulation, type: StringName, p: int, c: Vector2i) -> int:
	return sim.spawn_unit(type, p, _fx(c.x), _fx(c.y))


## A finished building of player p with its top-left cell at c; its id or 0.
func _place(sim: Simulation, p: int, type: StringName, c: Vector2i) -> int:
	var id := sim.economy.buildings.next_id
	sim.apply_now(SimCommand.place(sim.tick, p, type, _fx(c.x), _fx(c.y)))
	return id if sim.economy.buildings.is_alive(id) else 0


func _silver(sim: Simulation) -> int:
	return sim.economy.player(P).stock[EconomySystem.SILVER]


func _set_silver(sim: Simulation, n: int) -> void:
	sim.economy.player(P).stock[EconomySystem.SILVER] = n


## Everybody of the player's but Barbara (whose loss ends the mission) off the map; she waits far.
func _clear(sim: Simulation) -> void:
	var barbara := sim.mission.alive_of("barbara")[0]
	for id in sim.entities.alive_ids.duplicate():
		if sim.entities.owners[id - 1] == P and id != barbara:
			sim.remove_unit(id)
	_put(sim, PackedInt32Array([barbara]), FAR)


## The boats wait by the pier and would load whatever comes into the treasury.
func _no_boats(sim: Simulation) -> void:
	for id in sim.mission.alive_of("boats"):
		sim.remove_unit(id)


func _rules(sim: Simulation) -> Dictionary:
	return sim.mission.def.rules["silver"]


# --- setup ----------------------------------------------------------------------------------


func test_crown_5_is_made_and_playable() -> void:
	assert_true(CampaignProgress.is_made("crown_05"))
	assert_eq(CampaignProgress.title_key("crown_05"), "Crown 5. Silver for Malbork, 1457")


func test_the_delta_the_towns_and_the_sides_are_set_up() -> void:
	var sim := _sim()
	var m := sim.mission
	assert_eq(sim.nav.width, 150)
	assert_eq(sim.nav.height, 120)
	assert_true(m.silver.on)
	assert_true(sim.sides.friendly(P, GDANSK), "Gdańsk is ours")
	assert_true(sim.sides.hostile(P, ORDER))
	assert_false(sim.sides.hostile(P, MERCS), "the mercenaries in the castles are nobody's enemy")
	assert_false(sim.sides.hostile(ORDER, MERCS))
	assert_false(sim.sides.hostile(MERCS, P))
	assert_eq(m.silver.patience, 600)
	assert_eq(m.silver.discontent, 100)
	assert_eq(_silver(sim), 0, "the Crown's treasury is empty")
	var pier: int = m.named["pier"]
	assert_eq(sim.economy.buildings.type_ids[pier - 1], &"pl_dock")
	assert_eq(sim.economy.buildings.owners[pier - 1], P)
	assert_eq(sim.nav.terrain_at(sim.nav.cell_at(104, 92)), &"t_road", "the castle bridge")
	assert_eq(sim.nav.terrain_at(sim.nav.cell_at(110, 70)), &"t_water", "the Nogat")
	assert_eq(sim.magic.places.count(), 2, "the cross by the ferry and the chapel on the dike")


func test_boats_sail_the_water_and_wagons_keep_to_land() -> void:
	var sim := _sim()
	var boat := sim.mission.alive_of("boats")[0]
	var wagon := sim.mission.alive_of("wagons")[0]
	assert_eq(sim.entities.move_class[boat - 1], NavGrid.MoveClass.BOAT)
	var water := sim.nav.cell_at(110, 70)
	var land := sim.nav.cell_at(FAR.x, FAR.y)
	assert_true(sim.nav.passable(NavGrid.MoveClass.BOAT, water))
	assert_false(sim.nav.passable(NavGrid.MoveClass.BOAT, land))
	assert_false(sim.nav.passable(sim.entities.move_class[wagon - 1], water))
	assert_true(sim.nav.passable(sim.entities.move_class[wagon - 1], land))
	sim.apply_now(SimCommand.move(sim.tick, P, PackedInt32Array([boat]), _fx(116), _fx(60)))
	sim.run(400)
	assert_lt(absi(Fixed.to_cells(sim.entities.pos_y[boat - 1]) - 60), 3, "down the Nogat")


# --- the start, the station and the first payment --------------------------------------------


func test_1_and_2_the_station_by_the_ferry_brings_the_first_convoy() -> void:
	var sim := _sim()
	var m := sim.mission
	_check(sim)
	assert_true(m.fired.has("1"))
	assert_eq(_state(sim, "station"), MissionRuntime.Objective.ACTIVE)
	_place(sim, P, &"pl_town_center", STATION)
	_check(sim)
	assert_true(m.fired.has("2"))
	assert_eq(_state(sim, "station"), MissionRuntime.Objective.DONE)
	var convoy := m.alive_of("first_convoy")
	assert_eq(convoy.size(), 2)
	for id in convoy:
		assert_eq(m.silver.cargo[id], 125, "25 000 florins in two wagons")
	assert_eq(m.silver.on_the_road(m), 250)


func test_3_the_convoy_at_the_pier_goes_into_hyneks_boat() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1"])
	m.run(
		{
			"do": "spawn",
			"group": "first_convoy",
			"player": P,
			"units": [["pl_wagon", 2]],
			"at": [PIER.x, PIER.y]
		},
		sim.tick
	)
	m.run({"do": "cargo", "group": "first_convoy", "silver": 125}, sim.tick)
	_skip(sim, ["2"])
	_check(sim)
	assert_true(m.fired.has("3"))
	assert_eq(m.silver.on_the_road(m), 0, "the chests are in Hynek's boat now")
	assert_eq(m.silver.delivered, 0)
	assert_eq(m.alive_of("hynek_boat").size(), 1)


func test_4_hyneks_boat_sinks_at_the_piles_and_the_long_wait_begins() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "2", "3"])
	m.run(
		{
			"do": "spawn",
			"group": "hynek_boat",
			"player": MERCS,
			"units": [["pl_river_boat", 1]],
			"at": [105, 81]
		},
		sim.tick
	)
	_check(sim)
	assert_true(m.fired.has("4"))
	assert_true(m.alive_of("hynek_boat").is_empty(), "the boat is gone")
	assert_eq(m.silver.patience, 400, "the first payment never came")
	for oid: String in ["sum", "patience", "riot", "no_twice", "no_loss", "chapels", "no_swedes"]:
		assert_eq(_state(sim, oid), MissionRuntime.Objective.ACTIVE, oid)
	assert_false(sim.economy.player(P).locked.has(&"pl_shrine"), "chapels may be built")


func test_the_patience_runs_down_after_4_and_ends_the_mission_at_zero() -> void:
	var sim := _sim()
	var m := sim.mission
	sim.run(200)
	assert_eq(m.silver.patience, 600, "not before the boat sinks")
	_skip(sim, ["1", "4"])
	sim.run(400)
	assert_lt(m.silver.patience, 600)
	assert_gt(m.silver.patience, 570)
	m.silver.patience = 0
	_check(sim)
	assert_eq(m.outcome, MissionRuntime.Outcome.DEFEAT)


# --- carrying the silver ---------------------------------------------------------------------


func test_a_wagon_by_the_pier_loads_what_there_is_and_hands_it_over_at_the_gate() -> void:
	var sim := _sim()
	var m := sim.mission
	_no_boats(sim)
	_skip(sim, ["1", "4"])
	var wagon := m.alive_of("wagons")[0]
	_set_silver(sim, 150)
	_put(sim, PackedInt32Array([wagon]), PIER + Vector2i(0, 2))
	_check(sim)
	assert_eq(m.silver.cargo.get(wagon, 0), 150, "no more than the treasury holds")
	assert_eq(_silver(sim), 0)
	m.silver.patience = 300
	_put(sim, PackedInt32Array([wagon]), GATE)
	_check(sim)
	assert_false(m.silver.cargo.has(wagon))
	assert_eq(m.silver.delivered, 150)
	assert_almost_eq(m.silver.patience, 450, 2, "every load raises the patience")
	assert_true(m.fired.has("delivered"))


func test_tczew_takes_the_silver_too_and_a_boat_carries_more() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "4"])
	var boat := m.alive_of("boats")[0]
	_set_silver(sim, 1000)
	_put(sim, PackedInt32Array([boat]), PIER_WATER)
	_check(sim)
	assert_eq(m.silver.cargo.get(boat, 0), 300)
	var wagon := m.alive_of("wagons")[0]
	m.silver.cargo[wagon] = 200
	_put(sim, PackedInt32Array([wagon]), Vector2i(25, 102))
	_check(sim)
	assert_eq(m.silver.delivered, 200, "the gate of Tczew")


func test_a_loaded_wagon_lost_loses_its_silver_and_the_optional_objective() -> void:
	var sim := _sim()
	var m := sim.mission
	_check(sim)
	_skip(sim, ["4"])
	m.run({"do": "objective", "id": "no_loss", "text": "x", "optional": true}, sim.tick)
	var wagon := m.alive_of("wagons")[0]
	m.silver.cargo[wagon] = 200
	sim.remove_unit(wagon)
	_check(sim)
	_check(sim)
	assert_eq(m.silver.lost, 200)
	assert_eq(_state(sim, "no_loss"), MissionRuntime.Objective.FAILED)


# --- loans and the crowd ---------------------------------------------------------------------


func test_barbara_at_the_town_hall_is_offered_a_loan_that_angers_the_town() -> void:
	var sim := _sim()
	var m := sim.mission
	_no_boats(sim)
	_skip(sim, ["1", "4"])
	var barbara := m.alive_of("barbara")
	_put(sim, barbara, HALL)
	_check(sim)
	assert_true(m.choices.has("loan_1"))
	sim.enqueue(SimCommand.choose(sim.tick, P, &"loan_1", 1))
	_check(sim)
	assert_eq(_silver(sim), 600, "60 000 florins")
	assert_eq(m.silver.loans, 1)
	var l: Dictionary = _rules(sim)["loans"]
	var grow: int = Num.of(l["sums"][1][1]) * Num.of(l["hero_permille"]) / 1000
	assert_almost_eq(m.silver.discontent, 100 + grow, 2)
	# The next one is offered after a while, and costs more.
	sim.run(Num.of(l["wait_ticks"]) + CHECK)
	assert_true(m.choices.has("loan_2"))
	var before := m.silver.discontent
	sim.enqueue(SimCommand.choose(sim.tick, P, &"loan_2", 0))
	_check(sim)
	assert_eq(_silver(sim), 900)
	var more: int = (
		(Num.of(l["sums"][0][1]) + Num.of(l["interest"])) * Num.of(l["hero_permille"]) / 1000
	)
	assert_almost_eq(m.silver.discontent, before + more, 2)


func test_not_now_takes_nothing() -> void:
	var sim := _sim()
	var m := sim.mission
	_no_boats(sim)
	_skip(sim, ["1", "4"])
	_put(sim, m.alive_of("barbara"), HALL)
	_check(sim)
	sim.enqueue(SimCommand.choose(sim.tick, P, &"loan_1", 2))
	_check(sim)
	assert_eq(_silver(sim), 0)
	assert_eq(m.silver.loans, 0)


func test_no_loans_before_4_or_far_from_the_hall() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1"])
	_put(sim, m.alive_of("barbara"), HALL)
	_check(sim)
	assert_false(m.choices.has("loan_1"), "not before the boat sinks")
	_skip(sim, ["4"])
	_put(sim, m.alive_of("barbara"), FAR)
	_check(sim)
	assert_false(m.choices.has("loan_1"))


func test_the_angry_town_raises_a_crowd_and_the_guard_sends_it_home() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1"])
	m.silver.discontent = 520
	_check(sim)
	assert_true(m.fired.has("8"))
	assert_eq(m.alive_of("crowd_1").size(), 6)
	assert_true(m.choices.has("crowd_1"))
	sim.enqueue(SimCommand.choose(sim.tick, P, &"crowd_1", 2))
	_check(sim)
	assert_true(m.alive_of("crowd_1").is_empty())
	assert_almost_eq(m.silver.discontent, 370, 2)
	m.silver.discontent = 520
	_check(sim)
	assert_true(m.alive_of("crowd_2").is_empty(), "not again before the town calms down")


func test_a_concession_calms_the_town_but_closes_the_loans() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "4"])
	m.silver.discontent = 620
	_check(sim)
	sim.enqueue(SimCommand.choose(sim.tick, P, &"crowd_1", 0))
	_check(sim)
	assert_lt(m.silver.discontent, 425)
	assert_false(m.silver.loans_open(m))
	_put(sim, m.alive_of("barbara"), HALL)
	_check(sim)
	assert_false(m.choices.has("loan_1"))


func test_money_for_the_poor_comes_out_of_the_treasury() -> void:
	var sim := _sim()
	var m := sim.mission
	_no_boats(sim)
	_skip(sim, ["1"])
	_set_silver(sim, 400)
	m.silver.discontent = 520
	_check(sim)
	sim.enqueue(SimCommand.choose(sim.tick, P, &"crowd_1", 1))
	_check(sim)
	assert_eq(_silver(sim), 250)
	assert_almost_eq(m.silver.discontent, 270, 2)


func test_a_rising_in_gdansk_ends_the_mission() -> void:
	var sim := _sim()
	sim.mission.silver.discontent = 1020
	_check(sim)
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.DEFEAT)


# --- villages and rumours --------------------------------------------------------------------


func test_5_barbara_standing_in_a_village_collects_the_tax() -> void:
	var sim := _sim()
	var m := sim.mission
	_no_boats(sim)
	_skip(sim, ["1"])
	var food := sim.economy.player(P).stock[EconomySystem.FOOD]
	_put(sim, m.alive_of("barbara"), VILLAGE)
	sim.run(140)
	assert_eq(_silver(sim), 60)
	assert_eq(sim.economy.player(P).stock[EconomySystem.FOOD], food + 30)
	assert_eq(m.silver.taxes, 1)
	assert_true(m.fired.has("5"))


func test_a_wagon_passing_through_collects_nothing() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1"])
	var wagon := m.alive_of("wagons")[0]
	_put(sim, PackedInt32Array([wagon]), VILLAGE + Vector2i(-4, 0))
	for _k in 20:
		sim.apply_now(
			SimCommand.move(
				sim.tick, P, PackedInt32Array([wagon]), _fx(VILLAGE.x + 6), _fx(VILLAGE.y)
			)
		)
		sim.run(CHECK)
		sim.apply_now(
			SimCommand.move(
				sim.tick, P, PackedInt32Array([wagon]), _fx(VILLAGE.x - 6), _fx(VILLAGE.y)
			)
		)
		sim.run(CHECK)
	assert_eq(m.silver.taxes, 0)


func test_taxing_a_village_twice_in_a_season_fails_the_optional_objective() -> void:
	var sim := _sim()
	var m := sim.mission
	_no_boats(sim)
	_check(sim)
	_skip(sim, ["4"])
	m.run({"do": "objective", "id": "no_twice", "text": "x", "optional": true}, sim.tick)
	_put(sim, m.alive_of("barbara"), VILLAGE)
	sim.run(140)
	assert_eq(m.silver.taxes, 1)
	sim.run(Num.of(_rules(sim)["villages"]["again_ticks"]))
	assert_eq(m.silver.taxes, 2)
	assert_eq(m.silver.twice, 1)
	_check(sim)
	assert_eq(_state(sim, "no_twice"), MissionRuntime.Objective.FAILED)


func test_7_a_rumour_halves_the_tax_and_the_priest_ends_it() -> void:
	var sim := _sim()
	var m := sim.mission
	_no_boats(sim)
	_skip(sim, ["1", "4"])
	sim.run(Num.of(_rules(sim)["rumours"]["every_ticks"]) + CHECK)
	assert_eq(m.silver.rumours, 1)
	assert_true(m.fired.has("7"))
	var i := m.silver.rumour.find(1)
	assert_gte(i, 0)
	var at: Array = _rules(sim)["villages"]["at"][i]
	var v := Vector2i(Num.of(at[0]), Num.of(at[1]))
	_put(sim, m.alive_of("barbara"), v)
	sim.run(140)
	assert_eq(_silver(sim), 30, "half the tax")
	_put(sim, m.alive_of("priest"), v)
	sim.run(140)
	assert_eq(m.silver.rumour[i], 0)


func test_a_chapel_keeps_rumours_away() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "4"])
	var shrine := _place(sim, P, &"pl_shrine", Vector2i(60, 86))
	assert_ne(shrine, 0)
	for _k in 7:
		sim.run(Num.of(_rules(sim)["rumours"]["every_ticks"]))
	var near: Array = [3, 4]
	for i: int in near:
		assert_eq(m.silver.rumour[i], 0, "village %d is near the chapel" % i)


# --- the Order's riders ----------------------------------------------------------------------


func test_riders_come_over_the_nogat_and_plunder_a_village() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "4"])
	_clear(sim)
	sim.run(2400 + CHECK)
	assert_eq(m.silver.raids.size(), 1)
	assert_true(m.fired.has("raid"))
	assert_eq(m.alive_of("raid_0").size(), 4, "three Prussian riders and a mercenary on normal")
	for _k in 120:
		if m.silver.plundered.has(0):
			break
		sim.run(100)
	assert_true(m.silver.plundered.has(0), "a village is plundered")
	var i := m.silver.plundered.find(0)
	var at: Array = _rules(sim)["villages"]["at"][i]
	var barbara := m.alive_of("barbara")
	for id in m.alive_of("raid_0"):
		sim.remove_unit(id)
	_put(sim, barbara, Vector2i(Num.of(at[0]), Num.of(at[1])))
	sim.run(160)
	assert_eq(m.silver.taxes, 0, "a plundered village pays nothing this season")


func test_on_easy_the_raid_is_smaller() -> void:
	var sim := _sim("easy")
	var m := sim.mission
	_skip(sim, ["1", "4"])
	sim.run(2400 + CHECK)
	assert_eq(m.alive_of("raid_0").size(), 3)


func test_riders_go_for_a_loaded_wagon_and_a_dead_rider_pays_a_trophy() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "4"])
	_clear(sim)
	sim.run(2400 + CHECK)
	var riders := m.alive_of("raid_0")
	var wagon := _one(sim, &"pl_wagon", P, Vector2i(130, 20))
	m.silver.cargo[wagon] = 200
	_put(sim, riders, Vector2i(140, 20))
	sim.run(60)
	assert_eq(sim.entities.target[riders[0] - 1], wagon, "they go for the silver")
	sim.remove_unit(riders[0])
	sim.run(CHECK + 1)
	assert_eq(_silver(sim), 10, "1 000 florins of booty")


func test_the_riders_go_home_once_the_silver_is_in() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "4"])
	_clear(sim)
	sim.run(2400 + CHECK)
	_skip(sim, ["10"])
	sim.run(60)
	assert_eq(m.silver.raid_target[0], -2)
	sim.run(3000)
	assert_true(m.alive_of("raid_0").is_empty(), "they left over the Nogat")
	assert_eq(_silver(sim), 0, "and paid no trophy")


# --- seasons ---------------------------------------------------------------------------------


func test_6_the_winter_freezes_the_rivers_and_the_spring_floods_the_polders() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "4"])
	var river := sim.nav.cell_at(110, 70)
	var polder := sim.nav.cell_at(60, 68)
	assert_ne(sim.nav.terrain_at(polder), &"t_water")
	var wagon := m.alive_of("wagons")[0]
	sim.tick = m.fired["4"] + 6000 - 1
	_check(sim)
	assert_true(m.fired.has("6"))
	assert_eq(m.silver.season, MissionSilver.Season.WINTER)
	assert_eq(sim.nav.terrain_at(river), &"t_ice")
	assert_true(sim.nav.passable(sim.entities.move_class[wagon - 1], river), "over the ice")
	_put(sim, PackedInt32Array([wagon]), Vector2i(60, 68))
	sim.tick = m.fired["6"] + 7200 - 1
	_check(sim)
	assert_true(m.fired.has("spring"))
	assert_eq(m.silver.season, MissionSilver.Season.SPRING)
	assert_eq(sim.nav.terrain_at(river), &"t_water")
	assert_eq(sim.nav.terrain_at(polder), &"t_water", "the flood")
	var at := sim.nav.cell_of(sim.entities.pos_x[wagon - 1], sim.entities.pos_y[wagon - 1])
	assert_true(sim.nav.passable(sim.entities.move_class[wagon - 1], at), "the wagon got ashore")


func test_the_autumn_mud_slows_the_wagons() -> void:
	var sim := _sim()
	var m := sim.mission
	var wagon := m.alive_of("wagons")[0]
	_check(sim)
	var full := Fixed.speed_per_tick(m.combat.defs[wagon - 1].speed_milli)
	assert_eq(
		sim.entities.speed[wagon - 1],
		Fixed.speed_per_tick(m.combat.defs[wagon - 1].speed_milli * 700 / 1000)
	)
	m.run({"do": "season", "to": 1}, sim.tick)
	_check(sim)
	assert_eq(sim.entities.speed[wagon - 1], full)


# --- wages, the piles ------------------------------------------------------------------------


func test_unpaid_mercenaries_leave_on_payday() -> void:
	var sim := _sim()
	var m := sim.mission
	_no_boats(sim)
	_check(sim)
	var men := m.alive_of("horse").size() + m.alive_of("foot").size()
	sim.run(1300)
	assert_eq(m.silver.deserted, 0, "no wages before the boat sinks")
	_skip(sim, ["4"])
	_set_silver(sim, 5)
	sim.run(1200 + 2 * CHECK)
	assert_gt(m.silver.deserted, 0)
	assert_lt(m.alive_of("horse").size() + m.alive_of("foot").size(), men)
	assert_eq(_silver(sim), 0)
	assert_true(m.fired.has("deserted"))


func test_paid_mercenaries_stay() -> void:
	var sim := _sim()
	var m := sim.mission
	_no_boats(sim)
	_skip(sim, ["1", "4"])
	_check(sim)
	var due := m.silver.wages_due(m)
	assert_eq(due, 4 * 2 + 4 * 1)
	_set_silver(sim, 100)
	sim.run(1200 + 2 * CHECK)
	assert_eq(m.silver.deserted, 0)
	assert_eq(_silver(sim), 100 - due)


func test_the_piles_of_the_old_bridge_hole_a_boat_unless_a_tower_watches_them() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "4"])
	var boat := m.alive_of("boats")[0]
	_put(sim, PackedInt32Array([boat]), Vector2i(105, 81))
	var hp := sim.entities.hp[boat - 1]
	_check(sim)
	assert_lt(sim.entities.hp[boat - 1], hp)
	assert_true(m.fired.has("piles"))
	var tower := _place(sim, P, &"pl_tower", Vector2i(101, 80))
	assert_ne(tower, 0)
	hp = sim.entities.hp[boat - 1]
	_check(sim)
	assert_eq(sim.entities.hp[boat - 1], hp)


# --- the Swedish loan, the spring, the brothers -----------------------------------------------


func test_9_the_swedish_kings_loan_when_the_patience_runs_low() -> void:
	var sim := _sim()
	var m := sim.mission
	_no_boats(sim)
	_skip(sim, ["1", "4", "6"])
	m.run({"do": "objective", "id": "no_swedes", "text": "x", "optional": true}, sim.tick)
	m.silver.patience = 300
	_check(sim)
	assert_true(m.fired.has("9"))
	assert_true(m.choices.has("swedes"))
	sim.enqueue(SimCommand.choose(sim.tick, P, &"swedes", 0))
	_check(sim)
	assert_eq(_silver(sim), 20, "2 000 florins")
	assert_eq(_state(sim, "no_swedes"), MissionRuntime.Objective.FAILED)


func test_10_with_the_ransom_in_the_brothers_come_out_in_the_spring() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "4", "6"])
	m.silver.delivered = 1900
	_check(sim)
	assert_false(m.fired.has("10"), "not before the spring")
	m.silver.season = MissionSilver.Season.SPRING
	_check(sim)
	assert_true(m.fired.has("10"))
	assert_eq(m.alive_of("brothers").size(), 9)
	assert_eq(_state(sim, "garrison"), MissionRuntime.Objective.ACTIVE)


func test_11_and_12_the_garrison_at_the_gate_lets_the_brothers_out_and_takes_the_castle() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "4", "6", "spring"])
	m.silver.delivered = 1900
	m.silver.season = MissionSilver.Season.SPRING
	_check(sim)
	var men := m.alive_of("horse") + m.alive_of("foot")
	sim.apply_now(SimCommand.set_stance(sim.tick, P, men, EntityStore.Stance.PASSIVE))
	_put(sim, men, GATE)
	_check(sim)
	assert_true(m.fired.has("11"))
	assert_eq(_state(sim, "brothers"), MissionRuntime.Objective.ACTIVE)
	# Wages for payday: the brothers take about a minute to clear the gate (wider bodies), and
	# unpaid men would desert meanwhile.
	_set_silver(sim, 1000)
	for _k in 60:
		if m.alive_of("brothers").is_empty():
			break
		sim.run(200)
	assert_true(m.alive_of("brothers").is_empty(), "the brothers left the map")
	assert_false(m.flags.has("brothers_hurt"))
	_put(sim, men, YARD)
	_check(sim)
	assert_true(m.fired.has("12"))
	assert_eq(m.alive_of("king").size(), 2)
	sim.run(100)
	assert_eq(m.outcome, MissionRuntime.Outcome.VICTORY)


func test_striking_a_brother_ends_the_mission() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "4", "6", "spring"])
	m.silver.delivered = 1900
	m.silver.season = MissionSilver.Season.SPRING
	_check(sim)
	var brother := m.alive_of("brothers")[0]
	sim.entities.hp[brother - 1] -= 5
	_check(sim)
	assert_eq(m.outcome, MissionRuntime.Outcome.DEFEAT)


func test_defeat_when_barbara_falls() -> void:
	var sim := _sim()
	sim.remove_unit(sim.mission.alive_of("barbara")[0])
	_check(sim)
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.DEFEAT)


# --- the panel ------------------------------------------------------------------------------


func test_the_panel_shows_the_ransom_in_florins_and_after_4_the_patience() -> void:
	var sim := _sim()
	var m := sim.mission
	_no_boats(sim)
	_check(sim)
	var clock := SimClock.new()
	clock.sim = sim
	add_child_autofree(clock)
	var panel := MissionPanel.new()
	add_child_autofree(panel)
	panel.attach(sim, clock, null)
	panel.poll()
	assert_eq(
		panel.march_text(), "Ransom brought: 0 of 190 000 florins\nTreasury: 0 florins\nAutumn 1456"
	)
	_skip(sim, ["4"])
	m.silver.delivered = 1100
	m.silver.patience = 455
	m.silver.discontent = 120
	_set_silver(sim, 35)
	panel.poll()
	assert_eq(
		panel.march_text(),
		(
			"\n"
			. join(
				[
					"Ransom brought: 110 000 of 190 000 florins",
					"Treasury: 3 500 florins",
					"Autumn 1456",
					"Mercenaries' patience: 45%",
					"Wages each month: 1 200 florins",
					"Discontent in Gdańsk: 12%",
				]
			)
		)
	)


# --- state ----------------------------------------------------------------------------------


func test_save_and_load_keep_the_silver_and_the_winter() -> void:
	var sim := _sim()
	var m := sim.mission
	_no_boats(sim)
	_skip(sim, ["1", "4"])
	_set_silver(sim, 500)
	m.silver.cargo[m.alive_of("wagons")[0]] = 200
	m.run({"do": "season", "to": 1}, sim.tick)
	sim.run(300)
	var data := SimSave.capture(sim)
	var loaded := SimSave.restore(data, _db)
	assert_not_null(loaded)
	assert_eq(loaded.state_hash(), data["hash"])
	assert_eq(loaded.mission.silver.season, MissionSilver.Season.WINTER)
	assert_eq(loaded.nav.terrain_at(loaded.nav.cell_at(110, 70)), &"t_ice")
	assert_eq(loaded.mission.silver.on_the_road(loaded.mission), 200)
	sim.run(600)
	loaded.run(600)
	assert_eq(loaded.state_hash(), sim.state_hash(), "and it plays on the same")


func test_the_silver_changes_the_hash() -> void:
	var a := _sim()
	var b := _sim()
	b.mission.silver.discontent += 1
	assert_ne(a.state_hash(), b.state_hash())
	var c := _sim()
	c.mission.silver.cargo[c.mission.alive_of("wagons")[0]] = 1
	assert_ne(a.state_hash(), c.state_hash())


static func _fx(cell: int) -> int:
	return Fixed.from_cells(cell) + Fixed.HALF
