# gdlint:ignore = max-public-methods
extends GutTest
## «ВКЛ 8. Орша, 1514»: one test per trigger of the mission card and per rule of its own
## (MissionBattle: the bridges laid section by section, the patrol and its alarm, the ambush held
## and hidden, its volley, the false retreat to the rally point, the chase, the Kropivna, the
## captive commander and the old oak). The world is put into the condition and the result is
## checked; earlier triggers a test does not need are marked as fired by hand.

const MISSION := "gdl_08"
const P := 1
const MOSCOW := 2
const POLES := 3
const HETMAN := 4
const CHECK := MissionRuntime.CHECK_EVERY
## The heads of the two bridges on the south bank, the ford, the ravine, a cell in the open field.
const HEAD_0 := Vector2i(70, 94)
const FORD := Vector2i(123, 90)
const RAVINE := Vector2i(100, 65)
const FIELD := Vector2i(80, 50)
const NORTH := Vector2i(84, 82)
const FAR := Vector2i(30, 104)

## The objectives each trigger gives.
const OBJECTIVES := {
	"4": ["deploy"], "7": ["court"], "8": ["feint"], "10": ["camp", "kropivna", "chelyadnin"]
}

var _db: CatalogDB


func before_all() -> void:
	_db = CatalogDB.load_prototype()


func _sim(difficulty := "normal") -> Simulation:
	var sim := MissionSetup.new_simulation(MISSION, 1, _db, difficulty)
	assert_not_null(sim)
	sim.run(2)
	return sim


## Marks triggers fired, with what later triggers lean on: the objectives they gave, the
## question at dawn and the hetman's headquarters.
func _skip(sim: Simulation, ids: Array[String]) -> void:
	var m := sim.mission
	for tid in ids:
		m.fired[tid] = sim.tick
		for oid: String in OBJECTIVES.get(tid, []):
			m.run({"do": "objective", "id": oid, "text": oid}, sim.tick)
		if tid == "4" and _b(sim, "stavka") == 0:
			var place := {"do": "place", "player": HETMAN, "type": "gdl_field_camp"}
			place.merge({"at": [82, 80], "name": "stavka"})
			m.run(place, sim.tick)
			m.run({"do": "ask", "id": "deploy", "options": ["Begin the battle"]}, sim.tick)


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


func _put(sim: Simulation, ids: PackedInt32Array, c: Vector2i) -> void:
	for id in ids:
		sim.entities.pos_x[id - 1] = _fx(c.x)
		sim.entities.pos_y[id - 1] = _fx(c.y)
		sim.entities.stop(id)


func _one(sim: Simulation, type: StringName, p: int, c: Vector2i) -> int:
	return sim.spawn_unit(type, p, _fx(c.x), _fx(c.y))


## Only Andrei (far on the south bank) and the groups named stay.
func _alone(sim: Simulation, keep_groups: Array[String] = []) -> void:
	var keep := PackedInt32Array(sim.mission.alive_of("andrei"))
	for g in keep_groups:
		keep.append_array(sim.mission.alive_of(g))
	for id in sim.entities.alive_ids.duplicate():
		if not keep.has(id):
			sim.remove_unit(id)
	_put(sim, sim.mission.alive_of("andrei"), FAR)


func _b(sim: Simulation, name: String) -> int:
	return sim.mission.named.get(name, 0)


func _at(sim: Simulation, id: int) -> Vector2i:
	return Vector2i(
		Fixed.to_cells(sim.entities.pos_x[id - 1]), Fixed.to_cells(sim.entities.pos_y[id - 1])
	)


func _wood(sim: Simulation) -> int:
	return sim.economy.player(P).stock[1]


func _ids(sim: Simulation, g: String, n: int) -> PackedInt32Array:
	return sim.mission.alive_of(g).slice(0, n)


# --- setup ----------------------------------------------------------------------------------


func test_the_night_camp_the_allies_and_the_muscovite_army_are_set_up() -> void:
	var sim := _sim()
	var m := sim.mission
	sim.run(2)
	assert_eq(sim.nav.width, 160)
	assert_eq(sim.nav.height, 110)
	assert_true(sim.sides.hostile(P, MOSCOW))
	assert_true(sim.sides.friendly(P, POLES) and sim.sides.friendly(P, HETMAN))
	for g: String in ["andrei", "riders", "lances", "znakharka", "servants", "foot", "guns"]:
		assert_gt(m.alive_of(g).size(), 0, "%s stands" % g)
	for g: String in ["swierczowski", "sampolinski", "ostrogski", "maciej", "chelyadnin"]:
		assert_eq(m.alive_of(g).size(), 1, g)
	assert_eq(m.alive_of("ambush").size(), 12, "the foot and the guns are the ambush")
	assert_eq(m.alive_of("guns").size(), 4)
	assert_true(sim.combat.untouchable.has(m.alive_of("maciej")[0]), "the scribe does not fight")
	assert_true(m.stealth.night, "the crossing is at night")
	assert_eq(sim.magic.places.count(), 1, "the old oak")
	assert_true(sim.magic.places.hidden.has(0), "the oak is not known yet")
	var boyar := m.alive_of("chelyadnin")[0]
	assert_true(sim.combat.hp_floor.has(boyar), "Chelyadnin can be taken alive")
	assert_true(sim.economy.buildings.is_alive(_b(sim, "camp")))
	assert_true(sim.economy.buildings.is_alive(_b(sim, "camp_moscow")))
	assert_eq(m.battle.built, PackedInt32Array([0, 0]))
	assert_true(_has_event(sim, "cutscene", "two_gintovts"))
	assert_eq(_state(sim, "cross"), MissionRuntime.Objective.ACTIVE)
	assert_eq(_state(sim, "quiet"), MissionRuntime.Objective.ACTIVE)
	assert_eq(m.countdown_end, m.fired["1"] + 10800)


func test_the_dnieper_is_crossed_only_at_the_ford_and_not_by_the_guns() -> void:
	var sim := _sim()
	var nav := sim.nav
	var horse := NavGrid.MoveClass.CAVALRY
	var gun := NavGrid.MoveClass.SIEGE
	assert_false(nav.passable(horse, nav.cell_at(70, 90)), "deep water at the first bridge")
	assert_false(nav.passable(horse, nav.cell_at(84, 90)), "and at the second")
	assert_true(nav.passable(horse, nav.cell_at(FORD.x, FORD.y)), "the horse fords")
	assert_false(nav.passable(gun, nav.cell_at(FORD.x, FORD.y)), "the guns cannot")


func test_the_map_paths_from_the_camp_reach_the_field_and_the_muscovite_camp() -> void:
	var sim := _sim()
	var nav := sim.nav
	var horse := NavGrid.MoveClass.CAVALRY
	var from := nav.area(horse, nav.cell_at(96, 97))
	for to: Vector2i in [FORD, RAVINE, FIELD, Vector2i(79, 26), Vector2i(131, 83)]:
		assert_eq(nav.area(horse, nav.cell_at(to.x, to.y)), from, "the horse reaches %s" % to)


# --- the bridges ----------------------------------------------------------------------------


func test_servants_at_the_head_lay_a_bridge_section_by_section() -> void:
	var sim := _sim()
	_alone(sim, ["servants"])
	var m := sim.mission
	var crew := _ids(sim, "servants", 4)
	_put(sim, crew, HEAD_0)
	var wood := _wood(sim)
	_check(sim)
	assert_eq(m.battle.paid[0], 1, "the section is paid for when begun")
	assert_eq(_wood(sim), wood - 40)
	assert_gt(m.battle.work[0], 0)
	assert_eq(m.battle.work[0] % (4 * CHECK), 0, "four servants a check")
	assert_false(sim.nav.passable(NavGrid.MoveClass.FOOT, sim.nav.cell_at(70, 93)))
	m.battle.work[0] = 9600 - 1
	_check(sim)
	assert_eq(m.battle.built[0], 1)
	assert_true(m.flags.has("section_0_1"))
	for y: int in [92, 93]:
		assert_true(sim.nav.passable(NavGrid.MoveClass.FOOT, sim.nav.cell_at(70, y)), "deck %d" % y)
	assert_false(sim.nav.passable(NavGrid.MoveClass.FOOT, sim.nav.cell_at(70, 91)))
	assert_eq(MissionBattle.head(m.def.rules["battle"]["bridges"][0], 1), Vector2i(70, 92))
	assert_eq(m.battle.deck_cells(m, 0).size(), 4)


func test_the_last_section_finishes_the_bridge_and_guns_can_cross_it() -> void:
	var sim := _sim()
	_alone(sim, ["servants"])
	var m := sim.mission
	var crew := _ids(sim, "servants", 4)
	for k in 3:
		_put(sim, crew, MissionBattle.head(m.def.rules["battle"]["bridges"][0], k))
		_check(sim)
		m.battle.work[0] = 9600 - 1
		_check(sim)
	assert_eq(m.battle.built[0], 3)
	assert_true(m.flags.has("bridge_0"))
	assert_true(m.fired.has("bridge_0"), "the hint")
	var nav := sim.nav
	var gun := NavGrid.MoveClass.SIEGE
	assert_eq(
		nav.area(gun, nav.cell_at(70, 96)),
		nav.area(gun, nav.cell_at(70, 85)),
		"a gun goes over the bridge"
	)


func test_with_no_wood_the_section_is_not_begun() -> void:
	var sim := _sim()
	_alone(sim, ["servants"])
	var m := sim.mission
	sim.economy.player(P).stock[1] = 10
	_put(sim, _ids(sim, "servants", 4), HEAD_0)
	_check(sim)
	assert_eq(m.battle.work[0], 0)
	assert_eq(m.battle.paid[0], 0)
	assert_true(m.flags.has("no_wood"))
	_check(sim)
	assert_true(m.fired.has("no_wood"), "the hint about the wagons")


func test_both_bridges_bring_the_foot_and_guns_over_and_keep_quiet_done() -> void:
	var sim := _sim()
	var m := sim.mission
	sim.run(2)
	m.battle.built = PackedInt32Array([3, 3])
	_check(sim)
	assert_true(m.fired.has("3"))
	var gun := m.alive_of("guns")[0]
	assert_eq(sim.entities.orders[gun - 1], EntityStore.Order.MOVE, "the guns go north")
	_check(sim)
	assert_eq(_state(sim, "quiet"), MissionRuntime.Objective.DONE)


func test_the_cross_is_done_with_the_guns_and_the_horse_north_of_the_river() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["3"])
	_put(sim, _ids(sim, "guns", 2), NORTH)
	_check(sim)
	assert_false(m.fired.has("cross_done"), "the horse is still south")
	_put(sim, _ids(sim, "riders", 6), Vector2i(121, 83))
	_check(sim)
	assert_eq(_state(sim, "cross"), MissionRuntime.Objective.DONE)


# --- the night: the ford, the patrol, the oak -----------------------------------------------


func test_the_ford_brings_the_their_bridges_dialogue() -> void:
	var sim := _sim()
	_put(sim, sim.mission.alive_of("riders").slice(0, 1), FORD)
	_check(sim)
	assert_true(_has_event(sim, "dialogue", "their_bridges"))


func _watched(sim: Simulation, checks: int) -> void:
	var patrol := sim.mission.alive_of("patrol")
	var rider := sim.mission.alive_of("riders")[0]
	for k in checks:
		var at := _at(sim, patrol[0])
		_put(sim, PackedInt32Array([rider]), at + Vector2i(0, 3))
		_check(sim)


func test_the_patrol_raises_the_alarm_when_it_watches_a_rider_long_enough() -> void:
	var sim := _sim()
	_alone(sim, ["patrol", "riders", "orsha_guard"])
	var m := sim.mission
	_watched(sim, 5)
	assert_false(m.battle.alarm, "not at a glance")
	_watched(sim, 10)
	assert_true(m.battle.alarm)
	_check(sim)
	assert_true(m.fired.has("alarm"))
	assert_eq(_state(sim, "quiet"), MissionRuntime.Objective.FAILED)
	var guard := m.alive_of("orsha_guard")[0]
	assert_eq(sim.entities.attack_move[guard - 1], 1, "the guard at Orsha rides out")


func test_the_patrol_rides_its_route_and_sees_nothing_by_day() -> void:
	var sim := _sim()
	_alone(sim, ["patrol", "riders"])
	var m := sim.mission
	var lead := m.alive_of("patrol")[0]
	var from := _at(sim, lead)
	sim.run(400)
	assert_gt(_at(sim, lead).x, from.x + 5, "it rides east along the bank")
	m.run({"do": "daylight", "night": false}, sim.tick)
	_watched(sim, 15)
	assert_false(m.battle.alarm, "by day the patrol rides nowhere and raises nothing")


func test_a_patrol_cut_down_quickly_raises_no_alarm() -> void:
	var sim := _sim()
	_alone(sim, ["patrol", "riders"])
	var m := sim.mission
	_watched(sim, 4)
	for id in m.alive_of("patrol"):
		sim.remove_unit(id)
	sim.run(CHECK * 15)
	assert_false(m.battle.alarm)


func test_andrei_at_the_old_oak_finds_one_charge_of_power() -> void:
	var sim := _sim()
	var m := sim.mission
	var places := sim.magic.places
	var oak := Vector2i(Fixed.to_cells(places.center_x(0)), Fixed.to_cells(places.center_y(0)))
	var power := sim.economy.player(P).power
	_put(sim, m.alive_of("riders").slice(0, 1), oak)
	_check(sim)
	assert_false(m.battle.oak_found, "only Andrei knows the tree")
	_put(sim, m.alive_of("andrei"), oak)
	_check(sim)
	assert_true(m.battle.oak_found)
	assert_false(places.hidden.has(0))
	assert_eq(sim.economy.player(P).power, power + 100 * MagicSystem.POWER_UNIT)
	_check(sim)
	assert_true(_has_event(sim, "dialogue", "the_oak"))


# --- the dawn -------------------------------------------------------------------------------


func _dawn(sim: Simulation) -> void:
	_put(sim, sim.mission.alive_of("guns"), NORTH)
	sim.mission.fired["1"] = sim.tick - 10800
	_check(sim)


func test_dawn_puts_up_the_hetmans_headquarters_and_asks_to_begin() -> void:
	var sim := _sim()
	var m := sim.mission
	_dawn(sim)
	assert_true(m.fired.has("4"))
	assert_eq(m.outcome, MissionRuntime.Outcome.NONE)
	assert_false(m.stealth.night)
	assert_true(sim.economy.buildings.is_alive(_b(sim, "stavka")))
	assert_eq(sim.economy.buildings.owners[_b(sim, "stavka") - 1], HETMAN)
	assert_eq(_state(sim, "cross"), MissionRuntime.Objective.DONE)
	assert_eq(_state(sim, "quiet"), MissionRuntime.Objective.FAILED, "the bridges were not done")
	assert_eq(_state(sim, "deploy"), MissionRuntime.Objective.ACTIVE)
	assert_true(_has_event(sim, "choice", "deploy"))


func test_dawn_with_the_guns_still_south_is_defeat() -> void:
	var sim := _sim()
	var m := sim.mission
	m.fired["1"] = sim.tick - 10800
	_check(sim)
	assert_eq(m.outcome, MissionRuntime.Outcome.DEFEAT)


func test_the_mist_over_the_ravine_brings_the_haze_line() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["4"])
	sim.magic.mist.add(P, RAVINE.x, RAVINE.y, 5, sim.tick)
	_check(sim)
	assert_true(_has_event(sim, "dialogue", "haze"))


func test_begin_the_battle_holds_the_ambush_and_the_icon_is_carried() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["4"])
	sim.enqueue(SimCommand.choose(sim.tick, P, &"deploy", 0))
	sim.run(2)
	_check(sim)
	assert_true(m.fired.has("6"))
	assert_eq(_state(sim, "deploy"), MissionRuntime.Objective.DONE)
	assert_eq(m.battle.held.size(), 12)
	assert_true(_has_event(sim, "cutscene", "standing"))


func test_the_battle_begins_by_itself_when_the_player_waits_too_long() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["4"])
	m.fired["4"] = sim.tick - 4800
	_check(sim)
	assert_true(m.fired.has("6"))


# --- the ambush -----------------------------------------------------------------------------


func test_the_held_ambush_does_not_answer_to_the_player() -> void:
	var sim := _sim()
	var m := sim.mission
	var gun := m.alive_of("guns")[0]
	_put(sim, PackedInt32Array([gun]), RAVINE)
	m.run({"do": "hold", "on": true}, sim.tick)
	sim.enqueue(SimCommand.move(sim.tick, P, PackedInt32Array([gun]), _fx(80), _fx(50)))
	sim.run(100)
	assert_eq(_at(sim, gun), RAVINE, "the gun waits for the signal")
	m.run({"do": "hold", "on": false}, sim.tick)
	sim.enqueue(SimCommand.move(sim.tick, P, PackedInt32Array([gun]), _fx(80), _fx(50)))
	sim.run(100)
	assert_ne(_at(sim, gun), RAVINE, "after the signal it is the player's again")


func test_the_held_ambush_is_hidden_in_cover_and_under_mist_only() -> void:
	var sim := _sim()
	var m := sim.mission
	var guns := m.alive_of("guns")
	_put(sim, guns.slice(0, 1), RAVINE)
	_put(sim, guns.slice(1, 2), Vector2i(102, 75))
	_put(sim, guns.slice(2, 3), FIELD)
	_put(sim, guns.slice(3, 4), FIELD + Vector2i(-20, 0))
	sim.magic.mist.add(P, FIELD.x, FIELD.y, 4, sim.tick)
	m.run({"do": "hold", "on": true}, sim.tick)
	_check(sim)
	assert_true(m.battle.hidden.has(guns[0]), "in the ravine")
	assert_true(m.battle.hidden.has(guns[1]), "at the forest's edge")
	assert_true(m.battle.hidden.has(guns[2]), "under the mist")
	assert_false(m.battle.hidden.has(guns[3]), "in the open field")
	assert_true(sim.combat.untouchable.has(guns[0]))
	assert_false(sim.combat.untouchable.has(guns[3]))
	m.run({"do": "hold", "on": false}, sim.tick)
	assert_false(sim.combat.untouchable.has(guns[0]), "seen once it fires")
	assert_true(m.battle.held.is_empty())


func test_not_one_hidden_brings_the_hint() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["4"])
	_put(sim, m.alive_of("ambush"), FIELD + Vector2i(-20, 0))
	m.run({"do": "hold", "on": true}, sim.tick)
	_skip(sim, ["6"])
	m.fired["6"] = sim.tick - 20
	_check(sim)
	assert_true(m.fired.has("not_hidden"))


func test_the_volley_from_hiding_shakes_twice_as_hard() -> void:
	var sim := _sim()
	_alone(sim, ["guns"])
	var m := sim.mission
	var guns := m.alive_of("guns")
	_put(sim, guns.slice(0, 1), RAVINE)
	_put(sim, guns.slice(1, 2), FIELD)
	for id in guns.slice(2):
		sim.remove_unit(id)
	m.run({"do": "hold", "on": true}, sim.tick)
	var near_hidden := _one(sim, &"mo_syn_boyarsky", MOSCOW, RAVINE + Vector2i(0, -5))
	var near_open := _one(sim, &"mo_syn_boyarsky", MOSCOW, FIELD + Vector2i(0, -5))
	var far := _one(sim, &"mo_syn_boyarsky", MOSCOW, FIELD + Vector2i(0, -15))
	sim.run(1)
	for id: int in [near_hidden, near_open, far]:
		sim.entities.morale[id - 1] = 100 * CombatSystem.MORALE_SCALE
	var hp := sim.entities.hp[near_open - 1]
	m.run({"do": "ambush_fire", "radius": 7, "damage": 30, "morale": 30}, sim.tick)
	var scale := CombatSystem.MORALE_SCALE
	# The wound itself costs morale too; the hidden gun shakes them 30 points more.
	var by_hidden := 100 * scale - sim.entities.morale[near_hidden - 1]
	var by_open := 100 * scale - sim.entities.morale[near_open - 1]
	assert_gt(by_open, 30 * scale - 1, "30 lost to a gun in the open")
	assert_eq(by_hidden - by_open, 30 * scale, "twice the shock from a hidden gun")
	assert_eq(sim.entities.morale[far - 1], 100 * scale, "out of reach")
	assert_lt(sim.entities.hp[near_open - 1], hp)
	assert_true(m.flags.has("volley") and m.flags.has("volley_hidden"))
	assert_true(m.battle.held.is_empty(), "the hold ends with the volley")


# --- the battle -----------------------------------------------------------------------------


func test_7_the_right_hand_strikes_the_court_banners() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["4"])
	m.fired["6"] = sim.tick - 2400
	_check(sim)
	assert_true(m.fired.has("7"))
	assert_eq(m.alive_of("right_hand").size(), 20, "Bulgakov and his men")
	assert_eq(_state(sim, "court"), MissionRuntime.Objective.ACTIVE)
	assert_true(_has_event(sim, "dialogue", "not_from_fear"))
	var boyar := m.alive_of("right")[0]
	assert_eq(sim.entities.attack_move[boyar - 1], 1)


func test_the_court_banners_lost_fail_the_objective() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["4", "6", "7"])
	for id in m.alive_of("court"):
		sim.remove_unit(id)
	_check(sim)
	assert_eq(_state(sim, "court"), MissionRuntime.Objective.FAILED)


func test_8_the_right_hand_beaten_the_left_rides_at_our_horse() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["4", "6", "7"])
	m.run({"do": "merge", "group": "right_hand", "of": ["bulgakov", "right"]}, sim.tick)
	for id in m.alive_of("right").slice(4):
		sim.remove_unit(id)
	_check(sim)
	assert_true(m.fired.has("8"))
	assert_eq(_state(sim, "court"), MissionRuntime.Objective.DONE)
	assert_eq(_state(sim, "feint"), MissionRuntime.Objective.ACTIVE)
	assert_true(m.battle.chasing.has("left"))
	assert_true(m.battle.feint_on)
	assert_true(_has_event(sim, "dialogue", "to_the_forest"))


func _retreat_y(feint: bool) -> int:
	var sim := _sim()
	_alone(sim, ["riders"])
	var m := sim.mission
	var rider := m.alive_of("riders")[0]
	_put(sim, PackedInt32Array([rider]), Vector2i(100, 40))
	m.battle.feint_on = feint
	sim.enqueue(SimCommand.rally(sim.tick, P, _fx(100), _fx(76)))
	sim.run(2)
	sim.enqueue(SimCommand.order(sim.tick, P, SimCommand.Kind.RETREAT, PackedInt32Array([rider])))
	sim.run(600)
	return _at(sim, rider).y


func test_the_feint_rides_on_to_the_rally_point() -> void:
	var plain := _retreat_y(false)
	var feint := _retreat_y(true)
	assert_gt(feint, plain + 10, "the feint goes much further than a plain retreat")
	assert_gt(feint, 70, "all the way to the rally point")


func test_the_chase_goes_for_the_nearest_unit_it_can_see() -> void:
	var sim := _sim()
	_alone(sim, ["left", "riders", "maciej"])
	var m := sim.mission
	var riders := m.alive_of("riders")
	var lead := m.alive_of("left")[0]
	var at := _at(sim, lead)
	_put(sim, riders.slice(0, 1), at + Vector2i(0, 15))
	_put(sim, riders.slice(1), FAR)
	sim.combat.untouchable[riders[0]] = true
	m.run({"do": "chase", "group": "left", "on": true}, sim.tick)
	sim.run(MissionBattle.CHASE_EVERY + 1)
	assert_eq(sim.entities.attack_move[lead - 1], 0, "an unseen unit is not chased")
	sim.combat.untouchable.erase(riders[0])
	sim.run(MissionBattle.CHASE_EVERY + 1)
	assert_eq(sim.entities.attack_move[lead - 1], 1)
	assert_gt(Fixed.to_cells(sim.entities.target_y[lead - 1]), at.y + 10)


func test_9_the_chase_reaches_the_ambush_the_volley_and_the_press() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["4", "6", "7", "8"])
	m.run({"do": "hold", "on": true}, sim.tick)
	m.run({"do": "chase", "group": "left", "on": true}, sim.tick)
	_put(sim, m.alive_of("guns").slice(0, 1), RAVINE)
	_put(sim, m.alive_of("left").slice(0, 1), RAVINE + Vector2i(0, -4))
	_check(sim)
	assert_true(m.fired.has("9"))
	assert_true(m.flags.has("volley"))
	assert_eq(_state(sim, "feint"), MissionRuntime.Objective.DONE)
	assert_true(m.battle.chasing.is_empty())
	assert_true(m.battle.press_on)
	assert_true(_has_event(sim, "cutscene", "thunder_from_the_ravine"))


func test_9_late_the_chase_never_came_and_the_attack_goes_on() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["4", "6", "7", "8"])
	m.run({"do": "hold", "on": true}, sim.tick)
	m.fired["8"] = sim.tick - 6000
	_check(sim)
	assert_true(m.fired.has("9_late"))
	assert_eq(_state(sim, "feint"), MissionRuntime.Objective.FAILED)
	assert_true(m.battle.held.is_empty())
	_check(sim)
	assert_true(m.fired.has("10"))


func test_10_the_general_attack_the_reserve_and_the_muscovite_waves() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["4", "6", "7", "8"])
	m.fired["9"] = sim.tick - 200
	_check(sim)
	assert_true(m.fired.has("10"))
	assert_eq(m.alive_of("reserve").size(), 10)
	assert_eq(_state(sim, "camp"), MissionRuntime.Objective.ACTIVE)
	assert_eq(_state(sim, "kropivna"), MissionRuntime.Objective.ACTIVE)
	assert_eq(_state(sim, "chelyadnin"), MissionRuntime.Objective.ACTIVE)
	assert_gt(m.retreat.next_wave, sim.tick - CHECK, "Chelyadnin's reserves are coming")
	var count := sim.entities.alive_ids.size()
	sim.run(1000 + CHECK)
	assert_gt(sim.entities.alive_ids.size(), count - 1, "a wave rode in")
	m.fired["10"] = sim.tick - 4000
	_check(sim)
	assert_true(m.fired.has("reserves_spent"))
	assert_eq(m.retreat.next_wave, -1)


func test_the_left_hand_pressed_into_the_kropivna() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["10"])
	var left := m.alive_of("left")
	_put(sim, left.slice(0, 3), Vector2i(142, 40))
	_check(sim)
	assert_eq(m.battle.pressed.size(), 0, "not before the press is on")
	m.run({"do": "press", "on": true}, sim.tick)
	_check(sim)
	assert_eq(m.battle.pressed.size(), 3)
	assert_false(m.fired.has("kropivna_done"))
	_put(sim, left.slice(3, 4), Vector2i(141, 60))
	_check(sim)
	_check(sim)
	assert_eq(_state(sim, "kropivna"), MissionRuntime.Objective.DONE)


func test_chelyadnin_beaten_down_by_our_men_is_taken() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["10"])
	var boyar := m.alive_of("chelyadnin")[0]
	var at := _at(sim, boyar)
	_put(sim, m.alive_of("riders").slice(0, 1), at + Vector2i(1, 0))
	sim.entities.hp[boyar - 1] = sim.combat.hp_floor[boyar]
	_check(sim)
	assert_true(m.flags.has("taken:chelyadnin"))
	assert_false(sim.entities.is_alive(boyar), "led off the field")
	assert_eq(m.captives, 1)
	_check(sim)
	assert_eq(_state(sim, "chelyadnin"), MissionRuntime.Objective.DONE)


func test_chelyadnin_with_none_of_ours_by_rides_off() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["10"])
	var boyar := m.alive_of("chelyadnin")[0]
	sim.entities.hp[boyar - 1] = sim.combat.hp_floor[boyar]
	_check(sim)
	assert_true(m.flags.has("escaped:chelyadnin"))
	assert_true(sim.combat.untouchable.has(boyar))
	assert_eq(m.captives, 0)
	_check(sim)
	assert_eq(_state(sim, "chelyadnin"), MissionRuntime.Objective.FAILED)


func test_11_the_camp_taken_the_oak_and_the_end_of_the_campaign() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["4", "6", "7", "8", "9", "10", "reserves_spent"])
	sim.economy.destroy(_b(sim, "camp_moscow"))
	_check(sim)
	assert_true(m.fired.has("11"))
	assert_eq(_state(sim, "camp"), MissionRuntime.Objective.DONE)
	assert_true(_has_event(sim, "cutscene", "oak_over_kropivna"))
	assert_eq(m.alive_of("keeper").size(), 1)
	sim.run(CHECK * 10)
	assert_true(m.fired.has("12"))
	assert_eq(sim.magic.places.quenched[0], 0, "the last place of power is gone")
	assert_eq(m.alive_of("keeper").size(), 0, "nobody under the oak")
	assert_true(_has_event(sim, "cutscene", "epilogue"))
	assert_eq(m.outcome, MissionRuntime.Outcome.VICTORY)


func test_11_waits_for_chelyadnins_reserves() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["10"])
	sim.economy.destroy(_b(sim, "camp_moscow"))
	_check(sim)
	assert_false(m.fired.has("11"))


# --- defeats --------------------------------------------------------------------------------


func test_andrei_killed_is_defeat() -> void:
	var sim := _sim()
	for id in sim.mission.alive_of("andrei"):
		sim.remove_unit(id)
	_check(sim)
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.DEFEAT)


func test_the_headquarters_burned_is_defeat() -> void:
	var sim := _sim()
	_dawn(sim)
	sim.economy.destroy(_b(sim, "stavka"))
	_check(sim)
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.DEFEAT)


func test_the_army_thrown_back_is_defeat() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["4", "6"])
	var keep := PackedInt32Array(m.alive_of("andrei"))
	keep.append_array(m.alive_of("riders").slice(0, 7))
	for id in sim.entities.alive_ids.duplicate():
		if sim.entities.owners[id - 1] == P and not keep.has(id):
			sim.remove_unit(id)
	_check(sim)
	assert_eq(m.outcome, MissionRuntime.Outcome.NONE, "eight still stand")
	sim.remove_unit(keep[1])
	sim.remove_unit(keep[2])
	_check(sim)
	assert_eq(m.outcome, MissionRuntime.Outcome.DEFEAT)


# --- state ----------------------------------------------------------------------------------


func test_save_and_load_keep_the_bridges_the_hold_and_the_chase() -> void:
	var sim := _sim()
	var m := sim.mission
	_put(sim, _ids(sim, "servants", 4), HEAD_0)
	_put(sim, m.alive_of("guns").slice(0, 1), RAVINE)
	sim.run(150)
	m.battle.work[0] = 9600 - 1
	m.run({"do": "hold", "on": true}, sim.tick)
	m.run({"do": "chase", "group": "left", "on": true}, sim.tick)
	m.battle.feint_on = true
	sim.run(30)
	var data := SimSave.capture(sim)
	var loaded := SimSave.restore(data, _db)
	assert_not_null(loaded)
	assert_eq(loaded.state_hash(), data["hash"])
	assert_eq(loaded.mission.battle.built, m.battle.built)
	assert_eq(loaded.mission.battle.held.size(), 12)
	assert_true(loaded.mission.battle.chasing.has("left"))
	assert_true(loaded.mission.battle.feint_on)
	assert_eq(loaded.nav.terrain_at(sim.nav.cell_at(70, 93)), &"t_bog", "the deck is kept")
	sim.run(1200)
	loaded.run(1200)
	assert_eq(loaded.state_hash(), sim.state_hash(), "and it plays on the same")


func test_the_battle_changes_the_hash() -> void:
	var a := _sim()
	var b := _sim()
	b.mission.battle.work[1] += 10
	assert_ne(a.state_hash(), b.state_hash())
	var c := _sim()
	c.mission.battle.alarm = true
	assert_ne(a.state_hash(), c.state_hash())
	var d := _sim()
	d.mission.battle.chasing["left"] = true
	assert_ne(a.state_hash(), d.state_hash())


static func _fx(cell: int) -> int:
	return Fixed.from_cells(cell) + Fixed.HALF
