# gdlint:ignore = max-public-methods
extends GutTest
## «Корона 2. Мальборк, 1410»: one test per trigger of the mission card and per rule of
## MissionBesiege (the castle that mends itself by morning, the hunger, the castle's guns and
## the burned walls, the night sorties of the Gdańsk shipmen, spiking and the forge, the plague
## and the lazaret, the towns' envoys, the road to Sztum). The world is put into the condition
## and the result is checked; earlier triggers a test does not need are marked as fired by hand.

const MISSION := "crown_02"
const P := 1
const ORDER := 2
const KING := 3
const LITVA := 4
const MAZOVIA := 5
const CHECK := MissionRuntime.CHECK_EVERY
## Out of reach of the castle's towers and of its guns; east of the castle within its guns'
## reach; the church by the castle wall; the king's tent; Sztum.
const FAR := Vector2i(110, 60)
const EAST := Vector2i(58, 40)
const CHURCH := Vector2i(36, 55)
const TENT := Vector2i(45, 96)
const SZTUM := Vector2i(100, 117)

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


## Everyone of the player's but Jaśko out of the way, far from the castle.
func _clear(sim: Simulation) -> void:
	var jasko := sim.mission.alive_of("jasko")[0]
	for id in sim.entities.alive_ids.duplicate():
		if sim.entities.owners[id - 1] == P and id != jasko:
			sim.remove_unit(id)
	_put(sim, PackedInt32Array([jasko]), FAR)


## A finished building of player p with its top-left cell at c; its id or 0.
func _place(sim: Simulation, p: int, type: StringName, c: Vector2i) -> int:
	var id := sim.economy.buildings.next_id
	sim.apply_now(SimCommand.place(sim.tick, p, type, _fx(c.x), _fx(c.y)))
	return id if sim.economy.buildings.is_alive(id) else 0


func _b(sim: Simulation, name: String) -> int:
	return sim.mission.named.get(name, 0)


## Runs on to the next nightfall (the nights begin after trigger 4).
func _to_night(sim: Simulation) -> void:
	for _k in 400:
		if sim.mission.stealth.night:
			return
		sim.run(CHECK)
	fail_test("no night came")


# --- setup ----------------------------------------------------------------------------------


func test_the_castle_the_burned_town_and_the_camps_are_set_up() -> void:
	var sim := _sim()
	var m := sim.mission
	assert_eq(sim.nav.width, 140)
	assert_eq(sim.nav.height, 120)
	for p: int in [KING, LITVA, MAZOVIA]:
		assert_true(sim.sides.friendly(P, p), "player %d is on our side" % p)
		assert_true(sim.sides.hostile(p, ORDER))
	assert_true(m.besiege.on)
	assert_false(m.stealth.night, "the mission starts by day")
	assert_gt(m.besiege.castle.size(), 20, "towers, gates, walls and both castles")
	var store := sim.economy.buildings
	var high := _b(sim, "high_castle")
	assert_true(m.besiege.castle.has(high))
	assert_eq(store.hp_floor[high], store.max_hp[high - 1] * 300 / 1000)
	assert_false(m.besiege.castle.has(_b(sim, "town_gate")), "the town wall is not the castle")
	assert_eq(sim.nav.terrain_at(sim.nav.cell_at(19, 38)), &"t_road", "the bridge over the Nogat")
	assert_eq(sim.nav.terrain_at(sim.nav.cell_at(19, 30)), &"t_water")
	assert_eq(sim.magic.places.count(), 2, "the wayside cross and the well")
	assert_eq(sim.economy.player(P).power, 0)
	assert_eq(sim.economy.player(P).age, 2)
	for g: String in ["jasko", "lances", "crossbows", "foot", "servants", "priest", "guns"]:
		assert_gt(m.alive_of(g).size(), 0, "group %s is in the camp" % g)
	assert_true(sim.combat.untouchable.has(m.alive_of("plauen")[0]))


func test_the_lazaret_is_the_players_but_waits_for_the_plague() -> void:
	var sim := _sim()
	var state := sim.economy.player(P)
	var def := _db.building(&"pl_lazaret")
	assert_true(def.campaign_only)
	assert_true(state.allowed.has(&"pl_lazaret"))
	assert_true(state.locked.has(&"pl_lazaret"), "locked until trigger 10")
	assert_false(state.locked.has(&"pl_battery"))
	assert_false(state.locked.has(&"pl_smithy"), "the field forge")


func test_every_group_can_reach_the_batteries_and_sztum() -> void:
	var sim := _sim()
	sim.mission.run({"do": "destroy", "building": "town_gate"}, sim.tick)
	for goal: Vector2i in [EAST, SZTUM, CHURCH]:
		var to := sim.nav.cell_at(goal.x, goal.y)
		for g: String in ["jasko", "lances", "guns", "servants"]:
			var id := sim.mission.alive_of(g)[0]
			var from := sim.nav.cell_of(sim.entities.pos_x[id - 1], sim.entities.pos_y[id - 1])
			var cls := sim.entities.move_class[id - 1]
			assert_eq(sim.nav.area(cls, from), sim.nav.area(cls, to), "%s to %s" % [g, goal])


# --- the ransom ------------------------------------------------------------------------------


func test_the_ransom_of_the_guest_knight_pays_100_silver() -> void:
	var sim := _sim()
	var m := sim.mission
	assert_true(m.choices.has("mark:crown_01:captive"), "the question is open from the start")
	var silver := sim.economy.player(P).stock[EconomySystem.SILVER]
	sim.enqueue(SimCommand.choose(sim.tick, P, &"mark:crown_01:captive", 0))
	_check(sim)
	assert_true(m.fired.has("ransom"))
	assert_eq(sim.economy.player(P).stock[EconomySystem.SILVER], silver + 100)


func test_without_the_mark_there_is_no_ransom() -> void:
	var sim := _sim()
	sim.run(400)
	assert_false(sim.mission.fired.has("ransom"))


# --- 1-4: the camp, the trophies, the town wall, the king's order ---------------------------


func test_1_the_town_without_a_town_and_the_objectives() -> void:
	var sim := _sim()
	_check(sim)
	assert_true(sim.mission.fired.has("1"))
	assert_true(_has_event(sim, "cutscene", "town_without_town"))
	assert_eq(_state(sim, "batteries"), MissionRuntime.Objective.ACTIVE)
	assert_eq(_state(sim, "chapels"), MissionRuntime.Objective.ACTIVE)
	assert_eq(_state(sim, "no_pact"), MissionRuntime.Objective.ACTIVE)


func test_2_the_first_battery_brings_the_trophy_bombards() -> void:
	var sim := _sim()
	_check(sim)
	assert_gt(_place(sim, P, &"pl_battery", Vector2i(60, 40)), 0)
	_check(sim)
	assert_true(sim.mission.fired.has("2"))
	assert_eq(sim.mission.alive_of("trophies").size(), 4)
	assert_true(_has_event(sim, "dialogue", "trophies"))


func test_3_three_batteries_send_jakub_over_the_town_wall() -> void:
	var sim := _sim()
	_check(sim)
	for k in 3:
		assert_gt(_place(sim, P, &"pl_battery", Vector2i(60, 30 + k * 6)), 0)
	_check(sim)
	var m := sim.mission
	assert_true(m.fired.has("3"))
	assert_eq(_state(sim, "batteries"), MissionRuntime.Objective.DONE)
	assert_eq(_state(sim, "town"), MissionRuntime.Objective.ACTIVE)
	assert_true(_has_event(sim, "cutscene", "town_wall"))
	sim.run(400)
	assert_true(m.fired.has("3b"))
	assert_false(sim.economy.buildings.is_alive(_b(sim, "town_gate")), "opened from inside")


func test_4_at_the_church_the_king_forbids_the_breach_and_the_bridge_burns() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "2", "3", "3b"])
	m.run({"do": "objective", "id": "town", "text": "town"}, sim.tick)
	var lances := m.alive_of("lances")
	_put(sim, lances, Vector2i(36, 53))
	var on_bridge := _one(sim, &"to_knecht", ORDER, Vector2i(20, 38))
	_check(sim)
	assert_true(m.fired.has("4"))
	assert_true(_has_event(sim, "dialogue", "kings_order"))
	assert_true(_has_event(sim, "cutscene", "bridge_burns"))
	assert_eq(_state(sim, "town"), MissionRuntime.Objective.DONE)
	assert_eq(_state(sim, "guns"), MissionRuntime.Objective.ACTIVE)
	assert_eq(sim.nav.terrain_at(sim.nav.cell_at(19, 38)), &"t_water", "the bridge is gone")
	assert_false(sim.entities.is_alive(on_bridge), "who stood on it fell into the Nogat")
	for name: String in ["town_tower_w", "town_tower_e", "town_gate_e"]:
		assert_false(sim.economy.buildings.is_alive(_b(sim, name)), "%s is ours" % name)
	sim.run(100)
	for id in lances:
		assert_gt(sim.entities.pos_y[id - 1], _fx(54), "they fall back from the breach")


# --- the castle: hunger, mending, guns, burned walls ----------------------------------------


func test_the_castle_mends_by_morning_and_never_falls() -> void:
	var sim := _sim()
	var m := sim.mission
	var store := sim.economy.buildings
	var wall := _b(sim, "gate_e")
	sim.economy.hit_building(wall, store.max_hp[wall - 1] * 2)
	assert_true(store.is_alive(wall), "a castle building stands at its floor")
	assert_eq(store.hp[wall - 1], store.hp_floor[wall])
	_skip(sim, ["1", "2", "3", "3b", "4"])
	_to_night(sim)
	assert_eq(store.hp[wall - 1], store.hp_floor[wall], "not mended at night")
	sim.run(1200 + CHECK)
	assert_false(m.stealth.night, "dawn")
	assert_eq(store.hp[wall - 1], store.max_hp[wall - 1], "mended by morning")


func test_hunger_grows_from_the_siege_and_the_shot() -> void:
	var sim := _sim()
	var m := sim.mission
	sim.run(400)
	assert_eq(m.besiege.hunger, 0, "nothing before the town is taken")
	_skip(sim, ["1", "2", "3", "3b", "4"])
	sim.run(400)
	var slow := m.besiege.hunger
	assert_eq(slow, 10, "5 a point every 10 s")
	var store := sim.economy.buildings
	for b in m.besiege.castle.slice(0, 4):
		sim.economy.hit_building(b, 400)
	sim.run(200)
	assert_eq(m.besiege.hunger - slow, 5 + 4, "and a point for every 400 HP shot off")
	assert_gt(store.hp_floor.size(), 0)


func test_hunger_stops_short_of_the_end() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "2", "3", "3b", "4"])
	m.besiege.hunger = 935
	sim.run(400)
	assert_eq(m.besiege.hunger, 940, "fifteen days short")


func test_the_castles_guns_answer_the_nearest_battery() -> void:
	var sim := _sim()
	var m := sim.mission
	_clear(sim)
	var battery := _place(sim, P, &"pl_battery", Vector2i(52, 38))
	var store := sim.economy.buildings
	var hp := store.hp[battery - 1]
	var gunner := _one(sim, &"pl_foot_servant", P, Vector2i(53, 39))
	sim.run(400 + CHECK)
	assert_eq(m.besiege.shots, 1)
	assert_lt(store.hp[battery - 1], hp, "the battery is hit")
	assert_lt(sim.entities.hp[gunner - 1], _db.unit(&"pl_foot_servant").hp, "and its men")


func test_the_church_covers_a_battery_by_it() -> void:
	var sim := _sim()
	var m := sim.mission
	_clear(sim)
	var store := sim.economy.buildings
	var open := _place(sim, P, &"pl_battery", Vector2i(34, 55))
	var hp := store.hp[open - 1]
	sim.run(400 + CHECK)
	var lost := hp - store.hp[open - 1]
	assert_eq(lost, 80 * 400 / 1000, "the church's stone takes most of it")
	assert_eq(m.besiege.shots, 1)


func test_a_ball_by_a_burned_wall_brings_it_down_on_who_stands_there() -> void:
	var sim := _sim()
	var m := sim.mission
	_clear(sim)
	# The ruin at (53, 43); a man under it, a battery two cells off for the guns to aim at.
	var under := _one(sim, &"pl_foot_servant", P, Vector2i(53, 44))
	var away := _one(sim, &"pl_foot_servant", P, Vector2i(58, 50))
	sim.combat.untouchable[away] = true
	_place(sim, P, &"pl_battery", Vector2i(53, 42))
	sim.run(400 + CHECK * 2)
	assert_true(m.flags.has("ruin_fell"))
	assert_eq(m.besiege.fallen.size(), 1)
	assert_false(sim.entities.is_alive(under), "crushed")
	_check(sim)
	assert_true(m.fired.has("6"))
	assert_true(_has_event(sim, "dialogue", "burned_wall"))


# --- the night sorties, spiking and the forge -----------------------------------------------


func test_5_the_first_night_brings_the_shipmen_out_for_the_guns() -> void:
	var sim := _sim()
	var m := sim.mission
	_clear(sim)
	_skip(sim, ["1", "2", "3", "3b", "4"])
	var gun := _one(sim, &"pl_bombard", P, EAST)
	sim.combat.untouchable[gun] = true
	_to_night(sim)
	assert_eq(m.besiege.nights, 1)
	sim.run(600 + CHECK * 2)
	assert_eq(m.alive_of("shipmen_0").size(), 4, "four shipmen the first night")
	_check(sim)
	assert_true(m.fired.has("5"))
	assert_true(_has_event(sim, "dialogue", "not_knechts"))
	assert_eq(_state(sim, "shipmen"), MissionRuntime.Objective.ACTIVE)


func test_a_shipman_by_a_bombard_spikes_it_and_the_forge_mends_it() -> void:
	var sim := _sim()
	var m := sim.mission
	_clear(sim)
	var gun := _one(sim, &"pl_bombard", P, Vector2i(106, 64))
	sim.combat.untouchable[gun] = true
	var shipman := _one(sim, &"nt_gdansk_shipwright", ORDER, Vector2i(107, 64))
	sim.entities.stance[shipman - 1] = EntityStore.Stance.PASSIVE
	sim.combat.untouchable[shipman] = true
	sim.run(160 + CHECK * 2)
	assert_true(m.besiege.spiked.has(gun))
	assert_true(sim.combat.crown.spiked.has(gun))
	assert_false(sim.combat.crown.may_fire(gun - 1), "a spiked gun fires no more")
	assert_eq(m.besiege.spiked_total, 1)
	sim.remove_unit(shipman)
	var forge := _place(sim, P, &"pl_smithy", Vector2i(103, 65))
	assert_gt(forge, 0)
	sim.run(1200 + CHECK * 2)
	assert_false(m.besiege.spiked.has(gun), "the smith drilled it out")
	assert_false(sim.combat.crown.spiked.has(gun))


func test_more_than_half_spiked_fails_the_guns() -> void:
	var sim := _sim()
	var m := sim.mission
	m.run({"do": "objective", "id": "guns", "text": "guns"}, sim.tick)
	m.besiege.spiked_total = 5
	_check(sim)
	assert_true(m.fired.has("guns_failed"))
	assert_eq(_state(sim, "guns"), MissionRuntime.Objective.FAILED)


func test_shipmen_cut_off_far_from_their_gate_give_themselves_up() -> void:
	var sim := _sim()
	var m := sim.mission
	_clear(sim)
	_skip(sim, ["1", "2", "3", "3b", "4", "5"])
	m.run({"do": "objective", "id": "shipmen", "text": "shipmen"}, sim.tick)
	var gun := _one(sim, &"pl_bombard", P, Vector2i(70, 40))
	sim.combat.untouchable[gun] = true
	_to_night(sim)
	sim.run(600 + CHECK * 2)
	var ids := m.alive_of("shipmen_0")
	assert_eq(ids.size(), 4)
	var one := ids[0]
	_put(sim, PackedInt32Array([one]), Vector2i(66, 46))
	sim.entities.hp[one - 1] = 10
	_one(sim, &"pl_kopia", P, Vector2i(67, 46))
	sim.run(CHECK * 3)
	assert_eq(m.besiege.taken, 1)
	assert_false(sim.entities.is_alive(one), "led away captive")
	_check(sim)
	assert_eq(_state(sim, "shipmen"), MissionRuntime.Objective.DONE)


func test_by_their_gate_the_shipmen_cannot_be_taken() -> void:
	var sim := _sim()
	var m := sim.mission
	_clear(sim)
	_skip(sim, ["1", "2", "3", "3b", "4"])
	var gun := _one(sim, &"pl_bombard", P, Vector2i(52, 38))
	sim.combat.untouchable[gun] = true
	_to_night(sim)
	sim.run(600 + CHECK * 2)
	var one := m.alive_of("shipmen_0")[0]
	_put(sim, PackedInt32Array([one]), Vector2i(51, 38))
	sim.entities.hp[one - 1] = 10
	_one(sim, &"pl_kopia", P, Vector2i(52, 39))
	sim.run(CHECK * 3)
	assert_eq(m.besiege.taken, 0)


func test_the_shipmen_run_back_in_before_dawn() -> void:
	var sim := _sim()
	var m := sim.mission
	_clear(sim)
	_skip(sim, ["1", "2", "3", "3b", "4"])
	var gun := _one(sim, &"pl_bombard", P, Vector2i(56, 40))
	sim.combat.untouchable[gun] = true
	_to_night(sim)
	sim.run(600 + 900 + 1200)
	assert_eq(m.alive_of("shipmen_0").size(), 0, "gone in at the gate")


# --- 7, 8: the helmet, the stranger's advice ------------------------------------------------


func test_7_by_the_round_tower_the_helmet_of_piotr() -> void:
	var sim := _sim()
	_skip(sim, ["1", "2", "3", "3b", "4"])
	_put(sim, sim.mission.alive_of("lances"), Vector2i(48, 52))
	_check(sim)
	assert_true(sim.mission.fired.has("7"))
	assert_true(_has_event(sim, "cutscene", "helmet"))


func test_8_jasko_alone_by_his_battery_at_night_meets_the_stranger() -> void:
	var sim := _sim()
	var m := sim.mission
	_clear(sim)
	_skip(sim, ["1", "2", "3", "3b", "4", "5"])
	_place(sim, P, &"pl_battery", Vector2i(100, 60))
	_put(sim, m.alive_of("jasko"), Vector2i(102, 62))
	m.stealth.night = true
	_check(sim)
	assert_true(m.fired.has("8"))
	assert_true(_has_event(sim, "dialogue", "strangers_advice"))
	assert_true(_has_event(sim, "dialogue", "kings_council"))


func test_8_not_by_day() -> void:
	var sim := _sim()
	var m := sim.mission
	_clear(sim)
	_skip(sim, ["1", "2", "3", "3b", "5"])
	_place(sim, P, &"pl_battery", Vector2i(100, 60))
	_put(sim, m.alive_of("jasko"), Vector2i(102, 62))
	_check(sim)
	assert_false(m.fired.has("8"))


# --- 9: the towns' envoys ---------------------------------------------------------------------


func test_9_the_envoys_come_with_powder_and_two_more_bombards() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "2", "3", "3b"])
	m.fired["4"] = sim.tick - 7200
	var iron := sim.economy.player(P).stock[EconomySystem.IRON]
	_check(sim)
	assert_true(m.fired.has("9"))
	assert_true(m.besiege.envoys_walk)
	for g: String in ["envoy_gdansk", "envoy_torun", "envoy_elblag", "envoy_braniewo"]:
		assert_eq(m.alive_of(g).size(), 1, g)
		assert_eq(m.besiege.towns[g], 0)
	assert_eq(m.alive_of("elblag_guns").size(), 2)
	assert_gte(sim.economy.player(P).stock[EconomySystem.IRON], iron + 120)
	assert_eq(_state(sim, "envoys"), MissionRuntime.Objective.ACTIVE)


func test_an_envoy_at_the_tent_swears_and_his_town_sends_supplies() -> void:
	var sim := _sim()
	var m := sim.mission
	m.run(
		{
			"do": "spawn",
			"group": "envoy_torun",
			"player": KING,
			"at": [80, 80],
			"units": [["hero_town_envoys", 1]]
		},
		sim.tick
	)
	m.run({"do": "envoys_go"}, sim.tick)
	_put(sim, m.alive_of("envoy_torun"), TENT)
	_check(sim)
	assert_eq(m.besiege.towns["envoy_torun"], 1, "Toruń has sworn")
	assert_eq(m.alive_of("envoy_torun").size(), 0)
	var food := sim.economy.player(P).stock[EconomySystem.FOOD]
	sim.run(1200 + CHECK)
	assert_gte(sim.economy.player(P).stock[EconomySystem.FOOD], food + 40, "Toruń's grain")


func test_an_envoy_with_a_hunter_at_him_and_no_guard_is_taken() -> void:
	var sim := _sim()
	var m := sim.mission
	m.run(
		{
			"do": "spawn",
			"group": "envoy_gdansk",
			"player": KING,
			"at": [120, 10],
			"units": [["hero_town_envoys", 1]]
		},
		sim.tick
	)
	m.run(
		{
			"do": "spawn",
			"group": "envoy_elblag",
			"player": KING,
			"at": [120, 14],
			"units": [["hero_town_envoys", 1]]
		},
		sim.tick
	)
	m.run({"do": "envoys_go"}, sim.tick)
	var lost := m.alive_of("envoy_gdansk")[0]
	var kept := m.alive_of("envoy_elblag")[0]
	_put(sim, PackedInt32Array([lost]), Vector2i(120, 10))
	_put(sim, PackedInt32Array([kept]), Vector2i(120, 20))
	for at: Vector2i in [Vector2i(121, 10), Vector2i(121, 20)]:
		var h := _one(sim, &"to_halfbrother", ORDER, at)
		sim.entities.stance[h - 1] = EntityStore.Stance.PASSIVE
	var guard := _one(sim, &"pl_kopia", P, Vector2i(118, 21))
	sim.entities.stance[guard - 1] = EntityStore.Stance.PASSIVE
	for id: int in [lost, kept]:
		sim.entities.stop(id)
	sim.run(120 + CHECK)
	assert_false(sim.entities.is_alive(lost), "taken by the hunter")
	_check(sim)
	assert_eq(m.besiege.towns["envoy_gdansk"], -1)
	assert_eq(m.besiege.towns["envoy_elblag"], 0, "a lance by him keeps him")


func test_three_towns_sworn_are_done_and_two_lost_fail() -> void:
	var sim := _sim()
	var m := sim.mission
	m.run({"do": "objective", "id": "envoys", "text": "envoys"}, sim.tick)
	m.besiege.towns = {"a": 1, "b": 1, "c": 1, "d": 0}
	_check(sim)
	assert_eq(_state(sim, "envoys"), MissionRuntime.Objective.DONE)
	var other := _sim()
	other.mission.run({"do": "objective", "id": "envoys", "text": "envoys"}, other.tick)
	other.mission.besiege.towns = {"a": -1, "b": -1, "c": 0, "d": 0}
	_check(other)
	assert_eq(_state(other, "envoys"), MissionRuntime.Objective.FAILED)


# --- 10: the plague -------------------------------------------------------------------------


func test_the_plague_grows_with_the_crowd_and_the_heat() -> void:
	var sim := _sim()
	var m := sim.mission
	sim.run(200 + CHECK)
	var units := 0
	var priests := 0
	for id in sim.entities.alive_ids:
		if sim.entities.owners[id - 1] == P:
			units += 1
			if sim.entities.type_ids[id - 1] == &"pl_priest":
				priests += 1
	assert_eq(m.besiege.plague, 4 + units / 15 + 3 - priests * 2)


func test_men_below_the_town_on_the_canal_raise_it_faster() -> void:
	var a := _sim()
	var b := _sim()
	_put(b, b.mission.alive_of("foot"), Vector2i(60, 74))
	a.run(200 + CHECK)
	b.run(200 + CHECK)
	var foot := b.mission.alive_of("foot").size()
	assert_eq(b.mission.besiege.plague - a.mission.besiege.plague, foot / 4)


func test_10_half_way_opens_the_lazaret_and_it_brings_the_plague_down() -> void:
	var sim := _sim()
	var m := sim.mission
	m.besiege.plague = 500
	_check(sim)
	assert_true(m.fired.has("10"))
	assert_true(_has_event(sim, "dialogue", "plague"))
	assert_false(sim.economy.player(P).locked.has(&"pl_lazaret"))
	assert_eq(_state(sim, "plague"), MissionRuntime.Objective.ACTIVE)
	var lazarets := 0
	for at: Vector2i in [Vector2i(90, 40), Vector2i(95, 40), Vector2i(100, 40)]:
		if _place(sim, P, &"pl_lazaret", at) > 0:
			lazarets += 1
	assert_eq(lazarets, 3)
	var before := m.besiege.plague
	sim.run(200)
	assert_lt(m.besiege.plague, before)
	m.besiege.plague = 160
	sim.run(400)
	assert_eq(m.besiege.plague, 150, "but never below its floor")


func test_a_sick_camp_does_not_heal_and_wastes_away() -> void:
	var sim := _sim()
	var m := sim.mission
	m.besiege.plague = 760
	var foot := m.alive_of("foot")[0]
	var full := sim.entities.hp[foot - 1]
	var gun := m.alive_of("guns")[0]
	sim.run(200 + CHECK)
	assert_true(sim.magic.no_heal.has(P))
	assert_eq(sim.entities.hp[foot - 1], full - 3)
	assert_eq(sim.entities.hp[gun - 1], _db.unit(&"pl_bombard").hp, "the guns are not sick")


func test_the_plague_at_its_limit_is_defeat() -> void:
	var sim := _sim()
	sim.mission.besiege.plague = 999
	sim.run(200 + CHECK * 2)
	assert_true(sim.mission.flags.has("plague_max"))
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.DEFEAT)


func test_a_lazaret_heals_the_men_by_it() -> void:
	var sim := _sim()
	var m := sim.mission
	m.run({"do": "unlock", "player": P, "items": ["pl_lazaret"]}, sim.tick)
	var lz := _place(sim, P, &"pl_lazaret", Vector2i(90, 40))
	assert_gt(lz, 0)
	var man := _one(sim, &"pl_foot_servant", P, Vector2i(91, 43))
	sim.entities.hp[man - 1] = 20
	sim.run(200)
	assert_gt(sim.entities.hp[man - 1], 20)


# --- 11-15: the Livonians, Vytautas leaves, the red cap, the road to Sztum ------------------


func test_11_the_livonians_come_and_only_vincke_goes_in() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "2", "3", "3b", "4"])
	m.fired["9"] = sim.tick - 6000
	_check(sim)
	assert_true(m.fired.has("11"))
	assert_true(_has_event(sim, "cutscene", "truce"))
	assert_eq(m.alive_of("vincke").size(), 1)
	assert_true(sim.combat.untouchable.has(m.alive_of("livonians")[0]), "the truce")


func test_12_vytautas_the_tatars_and_the_masovians_leave_the_map() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "2", "3", "3b", "4", "9"])
	m.fired["11"] = sim.tick - 1800
	_check(sim)
	assert_true(m.fired.has("12"))
	assert_true(_has_event(sim, "cutscene", "vytautas_leaves"))
	for g: String in ["vytautas", "litva", "tatars", "mazovia"]:
		assert_true(m.exits.has(g), "%s leaves" % g)


func test_13_a_shot_after_vytautas_leaves_shows_the_red_cap() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "2", "3", "3b", "4", "9", "11", "12"])
	_check(sim)
	assert_false(m.fired.has("13"), "no shot yet")
	m.besiege.last_shot = sim.tick + 1
	_check(sim)
	assert_true(m.fired.has("13"))
	assert_true(_has_event(sim, "dialogue", "red_cap"))


func test_14_the_siege_is_lifted_and_the_garrison_comes_after_us() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "2", "3", "3b", "4", "9", "11"])
	m.run({"do": "objective", "id": "guns", "text": "guns"}, sim.tick)
	m.fired["12"] = sim.tick - 3000
	_check(sim)
	assert_true(m.fired.has("14"))
	assert_true(_has_event(sim, "cutscene", "siege_lifted"))
	assert_eq(_state(sim, "guns"), MissionRuntime.Objective.DONE)
	assert_eq(_state(sim, "sztum"), MissionRuntime.Objective.ACTIVE)
	assert_false(m.stealth.night)
	sim.run(900)
	assert_true(m.fired.has("14b"))
	assert_eq(m.alive_of("pursuit").size(), 14)


func test_bombards_at_sztum_are_brought_and_four_win() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "2", "3", "3b", "4", "9", "11", "12", "14"])
	m.run({"do": "objective", "id": "sztum", "text": "sztum"}, sim.tick)
	var guns := m.alive_of("guns")
	for k in 4:
		var g := _one(sim, &"pl_bombard", P, SZTUM + Vector2i(k, 0))
		guns.append(g)
	sim.run(CHECK * 2)
	assert_eq(m.besiege.brought, 4, "the four at Sztum")
	_put(sim, m.alive_of("guns"), SZTUM)
	sim.run(CHECK * 2)
	assert_eq(m.besiege.brought, 6)
	sim.run(CHECK * 2)
	assert_true(m.fired.has("15"), "no bombards left on the field")
	assert_true(_has_event(sim, "cutscene", "fifteen_days"))
	sim.run(100 + CHECK * 2)
	assert_eq(m.outcome, MissionRuntime.Outcome.VICTORY)


func test_fewer_than_four_at_sztum_when_time_is_up_is_defeat() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "2", "3", "3b", "4", "9", "11", "12"])
	m.fired["14"] = sim.tick - 7200
	m.fired["14b"] = sim.tick
	m.besiege.brought = 3
	sim.run(100 + CHECK * 3)
	assert_eq(m.outcome, MissionRuntime.Outcome.DEFEAT)


func test_defeat_when_the_kings_tent_is_ruined_or_jasko_falls() -> void:
	var sim := _sim()
	var tent := _b(sim, "tent")
	sim.economy.hit_building(tent, sim.economy.buildings.max_hp[tent - 1] * 2)
	_check(sim)
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.DEFEAT)
	var other := _sim()
	other.remove_unit(other.mission.alive_of("jasko")[0])
	_check(other)
	assert_eq(other.mission.outcome, MissionRuntime.Outcome.DEFEAT)


func test_the_pact_cast_fails_the_objective_and_is_carried() -> void:
	var sim := _sim()
	var m := sim.mission
	assert_eq(m.def.carry, PackedStringArray(["pact"]))
	_check(sim)
	m.run({"do": "flag", "flag": "pact"}, sim.tick)
	m.run({"do": "objective", "id": "no_pact", "state": "failed"}, sim.tick)
	m.run({"do": "objective", "id": "no_pact", "state": "done"}, sim.tick)
	assert_eq(_state(sim, "no_pact"), MissionRuntime.Objective.FAILED, "stays failed")


# --- state ----------------------------------------------------------------------------------


func test_save_and_load_keep_the_siege() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "2", "3", "3b", "4"])
	_to_night(sim)
	m.besiege.plague = 300
	m.besiege.spiked[m.alive_of("guns")[0]] = true
	sim.combat.crown.spiked[m.alive_of("guns")[0]] = true
	sim.run(700)
	var data := SimSave.capture(sim)
	var loaded := SimSave.restore(data, _db)
	assert_not_null(loaded)
	assert_eq(loaded.state_hash(), data["hash"])
	assert_eq(loaded.mission.besiege.nights, 1)
	assert_true(loaded.mission.besiege.spiked.has(m.alive_of("guns")[0]))
	sim.run(1200)
	loaded.run(1200)
	assert_eq(loaded.state_hash(), sim.state_hash(), "and it plays on the same")


func test_the_siege_changes_the_hash() -> void:
	var a := _sim()
	var b := _sim()
	b.mission.besiege.plague += 1
	assert_ne(a.state_hash(), b.state_hash())
	var c := _sim()
	c.mission.besiege.towns["x"] = 1
	assert_ne(a.state_hash(), c.state_hash())


static func _fx(cell: int) -> int:
	return Fixed.from_cells(cell) + Fixed.HALF
