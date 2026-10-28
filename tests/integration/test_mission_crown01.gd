# gdlint:ignore = max-public-methods
extends GutTest
## «Корона 1. Грюнвальд, 1410»: one test per trigger of the mission card (1-11) and per rule of
## MissionField (heat, the line, the great banner, captives, «The Pact» once a mission). The
## world is put into the trigger's condition and its events are checked; earlier triggers a
## test does not need are marked as fired by hand.

const MISSION := "crown_01"
const P := 1
const ORDER := 2
const KRAKOW := 3
const LITVA := 4
const KING := 5
const CHECK := MissionRuntime.CHECK_EVERY
const HILL := Vector2i(75, 139)

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


func _kill(sim: Simulation, group: String, keep: int = 0) -> void:
	var ids := sim.mission.alive_of(group)
	for k in ids.size() - keep:
		sim.remove_unit(ids[k])


func _jasko(sim: Simulation) -> int:
	return sim.mission.alive_of("jasko")[0]


## Gives objectives as the skipped triggers would have.
func _give(sim: Simulation, ids: Array[String]) -> void:
	for oid in ids:
		sim.mission.run({"do": "objective", "id": oid, "text": oid}, sim.tick)


## Drops the great banner where Marcin stands, as trigger 5 does.
func _drop(sim: Simulation) -> void:
	_skip(sim, ["1", "2", "3", "3b", "4", "5"])
	_give(sim, ["banner", "fast"])
	sim.mission.run({"do": "drop_banner"}, sim.tick)


# --- setup ----------------------------------------------------------------------------------


func test_the_field_of_grunwald_with_the_grove() -> void:
	var sim := _sim()
	var m := sim.mission
	assert_eq(sim.nav.width, 160)
	assert_eq(sim.nav.height, 176)
	for p: int in [KRAKOW, LITVA, KING]:
		assert_true(sim.sides.friendly(P, p), "player %d is on our side" % p)
		assert_true(sim.sides.hostile(p, ORDER))
	assert_eq(sim.economy.player(P).age, 2, "Хоругвь: «Богородица» is open")
	assert_eq(sim.economy.buildings.alive_ids.size(), 0, "a field battle: nobody has a base")
	for g: String in ["jasko", "lances_a", "priest", "marcin", "krakow", "jagiello", "wing"]:
		assert_gt(m.alive_of(g).size(), 0, "group %s is on the field" % g)
	assert_eq(sim.magic.places.count(), 3, "the oak, the spring and the kurgan of «ВКЛ 2»")
	assert_eq(sim.nav.terrain_at(sim.nav.cell_at(28, 126)), &"t_forest", "the oak grove")
	var gdl := MapText.load_map("map_gdl_02", _db)
	assert_eq(gdl.terrain_at(gdl.cell_at(28, 126)), &"t_grass", "only the grove is added")
	assert_eq(gdl.terrain_at(gdl.cell_at(64, 18)), sim.nav.terrain_at(sim.nav.cell_at(64, 18)))


func test_every_group_can_reach_the_wagenburg_and_the_hill() -> void:
	var sim := _sim()
	for goal: Vector2i in [Vector2i(66, 30), HILL]:
		var to := sim.nav.cell_at(goal.x, goal.y)
		for g: String in ["jasko", "lances_a", "lances_b", "crossbows", "priest", "krakow"]:
			var id := sim.mission.alive_of(g)[0]
			var from := sim.nav.cell_of(sim.entities.pos_x[id - 1], sim.entities.pos_y[id - 1])
			assert_eq(sim.nav.area(0, from), sim.nav.area(0, to), "%s can walk to %s" % [g, goal])


func test_the_great_banner_stands_over_the_whole_army() -> void:
	var sim := _sim()
	var m := sim.mission
	assert_eq(m.field.bearer, m.alive_of("marcin")[0], "Marcin carries the banner")
	assert_true(m.field.banner_up())
	sim.run(1)
	var lance := m.alive_of("lances_a")[0]
	var far := sim.combat.morale_bonus(lance - 1)
	assert_eq(sim.combat.crown.army_morale.get(P, 0), 10)
	assert_eq(sim.combat.crown.army_morale.get(KING, 0), 10)
	assert_false(sim.combat.crown.army_morale.has(ORDER))
	_drop(sim)
	assert_eq(sim.combat.morale_bonus(lance - 1), far - 10, "down, the whole army loses it")


func test_pact_is_locked_until_given() -> void:
	var sim := _sim()
	var jasko := _jasko(sim)
	assert_eq(sim.magic.can_cast(P, jasko, &"sp_pact"), MagicSystem.Cast.LOCKED)


# --- heat and the line ----------------------------------------------------------------------


func test_heat_tires_lances_in_the_sun_and_the_shade_cools_them() -> void:
	var sim := _sim()
	var m := sim.mission
	var sun := m.alive_of("lances_a")[0]
	var shade := m.alive_of("lances_a")[1]
	_put(sim, PackedInt32Array([shade]), 26, 121)
	assert_true(m.field.in_shade(m, sim.entities.pos_x[shade - 1], sim.entities.pos_y[shade - 1]))
	_put(sim, PackedInt32Array([sun]), 45, 110)
	assert_false(m.field.in_shade(m, sim.entities.pos_x[sun - 1], sim.entities.pos_y[sun - 1]))
	sim.run(2000)
	assert_eq(m.field.heat[sun], 200, "10 per 5 s in the sun")
	assert_eq(m.field.heat[shade], 0)
	var full := sim.combat.defs[sun - 1].morale * CombatSystem.MORALE_SCALE
	var morale := sim.entities.morale[sun - 1]
	assert_between(morale, full * 780 / 1000, full * 820 / 1000, "morale capped by the heat")
	assert_eq(sim.entities.morale[shade - 1], full)
	_put(sim, PackedInt32Array([sun]), 26, 121)
	sim.run(500)
	assert_eq(m.field.heat[sun], 0, "the grove cools them")


func test_the_order_has_stood_in_the_sun_since_morning() -> void:
	var sim := _sim()
	var m := sim.mission
	var knight := m.alive_of("wing")[1]
	assert_eq(m.field.heat[knight], 300)
	assert_false(m.field.heat.has(m.alive_of("wing")[0]), "heroes do not tire")
	assert_false(m.field.heat.has(m.alive_of("krakow")[0]), "the allies are left alone")
	assert_false(m.field.heat.has(m.alive_of("crossbows")[0]), "crossbowmen wear no plate")
	sim.run(CHECK + 1)
	var full := sim.combat.defs[knight - 1].morale * CombatSystem.MORALE_SCALE
	assert_lte(sim.entities.morale[knight - 1], full * 700 / 1000)


func test_2_crossing_the_line_before_the_order_sends_them_back() -> void:
	var sim := _sim()
	var m := sim.mission
	var lances := m.alive_of("lances_b")
	_put(sim, lances, 34, 100)
	_check(sim)
	assert_true(m.flags.has("line_crossed"))
	assert_true(m.fired.has("2"), "Zyndram: «Стоять!»")
	assert_true(_kinds(sim).has("dialogue"))
	sim.run(400)
	for id in lances:
		assert_gt(sim.entities.pos_y[id - 1], Fixed.from_cells(104), "back behind the line")


func test_after_the_order_the_line_is_open() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "3"])
	_put(sim, m.alive_of("lances_b"), 34, 100)
	_check(sim)
	assert_false(m.flags.has("line_crossed"))


# --- 1-4: the swords, the hymn, the wing, the Lithuanians -----------------------------------


func test_1_two_swords_and_the_objectives() -> void:
	var sim := _sim()
	_check(sim)
	assert_true(sim.mission.fired.has("1"))
	assert_true(_kinds(sim).has("cutscene"))
	assert_eq(_state(sim, "wait"), MissionRuntime.Objective.ACTIVE)
	assert_eq(_state(sim, "places"), MissionRuntime.Objective.ACTIVE)
	assert_eq(_state(sim, "captive"), MissionRuntime.Objective.ACTIVE)


func test_3_after_four_minutes_the_bombards_and_bogurodzica() -> void:
	var sim := _sim()
	sim.run(4790)
	assert_false(sim.mission.fired.has("3"))
	sim.run(30)
	assert_true(sim.mission.fired.has("3"))
	assert_eq(_state(sim, "wait"), MissionRuntime.Objective.DONE)
	assert_eq(_state(sim, "wing"), MissionRuntime.Objective.ACTIVE)
	assert_true(sim.mission._cast(P, &"sp_bogurodzica"), "the priest sings by himself")
	assert_eq(sim.economy.player(P).power, 0, "the hymn took the 150 Power of the start")
	var wing := sim.mission.alive_of("wing")[1]
	assert_eq(sim.entities.stance[wing - 1], EntityStore.Stance.AGGRESSIVE, "Lichtenstein comes")


func test_the_wing_is_thrown_back() -> void:
	var sim := _sim()
	_skip(sim, ["1", "3"])
	_give(sim, ["wing"])
	_kill(sim, "wing", 3)
	_kill(sim, "wing_foot", 4)
	_kill(sim, "guests", 1)
	_check(sim)
	assert_eq(_state(sim, "wing"), MissionRuntime.Objective.DONE)


func test_4_the_lithuanians_leave_and_spirits_fall() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1"])
	m.fired["3"] = sim.tick - 6000
	var lance := m.alive_of("lances_a")[0]
	var before := sim.entities.morale[lance - 1]
	_check(sim)
	assert_true(m.fired.has("4"))
	assert_lt(sim.entities.morale[lance - 1], before)
	_put(sim, m.alive_of("litva"), 138, 142)
	_put(sim, m.alive_of("wallenrode"), 139, 143)
	_check(sim)
	assert_eq(m.alive_of("litva").size(), 0, "they ride off the field")
	assert_eq(m.alive_of("wallenrode").size(), 0, "and lead the Germans away")


# --- captives -------------------------------------------------------------------------------


func test_a_beaten_guest_knight_gives_himself_up() -> void:
	var sim := _sim()
	var m := sim.mission
	var guest := m.alive_of("guests")[0]
	assert_true(sim.combat.hp_floor.has(guest))
	_put(sim, PackedInt32Array([guest]), 50, 90)
	_put(sim, m.alive_of("lances_a").slice(0, 1), 51, 90)
	sim.entities.hp[guest - 1] = sim.combat.hp_floor[guest]
	_check(sim)
	assert_false(sim.entities.is_alive(guest), "taken from the field")
	assert_eq(m.field.captured, 1)
	assert_true(m.flags.has("captive"))
	assert_eq(_state(sim, "captive"), MissionRuntime.Objective.DONE)


func test_a_guest_alone_is_not_taken() -> void:
	var sim := _sim()
	var m := sim.mission
	var guest := m.alive_of("guests")[0]
	_put(sim, PackedInt32Array([guest]), 50, 90)
	sim.entities.hp[guest - 1] = sim.combat.hp_floor[guest]
	_check(sim)
	assert_true(sim.entities.is_alive(guest))
	assert_eq(m.field.captured, 0)


# --- 5-6: the great banner and the stranger ------------------------------------------------


func test_5_the_banner_falls_after_two_minutes() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "2", "3", "3b"])
	m.fired["4"] = sim.tick - 2400
	_check(sim)
	assert_true(m.fired.has("5"))
	assert_false(m.field.banner_up())
	assert_eq(_state(sim, "banner"), MissionRuntime.Objective.ACTIVE)
	assert_gt(m.countdown_end, sim.tick, "60 seconds on the panel")
	assert_gt(m.alive_of("press").size(), 0, "the Order presses on the banner")


func test_the_banner_lying_a_minute_loses_the_battle() -> void:
	var sim := _sim()
	var m := sim.mission
	_drop(sim)
	sim.run(1190)
	assert_false(m.is_over())
	sim.run(30)
	assert_true(m.flags.has("royal_banner_lost"))
	assert_eq(m.outcome, MissionRuntime.Outcome.DEFEAT)


func test_6_jasko_raises_the_banner_and_is_given_the_pact() -> void:
	var sim := _sim()
	var m := sim.mission
	_drop(sim)
	var jasko := _jasko(sim)
	_put(sim, PackedInt32Array([jasko]), 62, 114)
	_check(sim)
	assert_true(m.fired.has("6"))
	assert_true(m.field.banner_up())
	assert_eq(m.field.bearer, m.alive_of("marcin")[0], "back in Marcin's hands")
	assert_eq(sim.combat.crown.army_morale.get(P, 0), 10)
	assert_eq(_state(sim, "banner"), MissionRuntime.Objective.DONE)
	assert_eq(_state(sim, "fast"), MissionRuntime.Objective.DONE, "within 30 seconds")
	assert_eq(m.countdown_end, -1)
	assert_eq(m.alive_of("stranger").size(), 1, "a hand in a red sleeve")
	assert_true(sim.combat.untouchable.has(m.alive_of("stranger")[0]))
	assert_eq(sim.magic.can_cast(P, jasko, &"sp_pact"), MagicSystem.Cast.OK)
	sim.run(220)
	assert_eq(m.alive_of("stranger").size(), 0, "nobody in red beside him")


func test_raising_it_late_fails_the_fast_objective() -> void:
	var sim := _sim()
	var m := sim.mission
	_drop(sim)
	sim.run(610)
	assert_eq(_state(sim, "fast"), MissionRuntime.Objective.FAILED)
	_put(sim, PackedInt32Array([_jasko(sim)]), 62, 114)
	_check(sim)
	assert_eq(_state(sim, "banner"), MissionRuntime.Objective.DONE)
	assert_eq(_state(sim, "fast"), MissionRuntime.Objective.FAILED)


func test_the_pact_once_a_mission() -> void:
	var sim := _sim()
	var m := sim.mission
	var jasko := _jasko(sim)
	m.run({"do": "unlock", "player": P, "items": ["sp_pact"]}, sim.tick)
	var x := sim.entities.pos_x[jasko - 1]
	var y := sim.entities.pos_y[jasko - 1]
	sim.enqueue(SimCommand.cast(sim.tick, P, PackedInt32Array([jasko]), &"sp_pact", x, y))
	_check(sim)
	assert_true(m.flags.has("pact"), "the debt grows")
	var lance := m.alive_of("lances_a")[0]
	_put(sim, PackedInt32Array([lance]), Fixed.to_cells(x), Fixed.to_cells(y) + 1)
	sim.run(2)
	assert_true(sim.combat.crown.pact.has(lance))
	assert_eq(sim.magic.can_cast(P, jasko, &"sp_pact"), MagicSystem.Cast.LOCKED, "only once")


# --- 7-11: the reserve, the king, the wagenburg ---------------------------------------------


func test_7_the_reserve_comes_out_and_the_king_sends_his_banners() -> void:
	var sim := _sim()
	var m := sim.mission
	_drop(sim)
	m.fired["6"] = sim.tick - 300
	_check(sim)
	assert_true(m.fired.has("7"))
	assert_eq(m.alive_of("reserve").size(), 12)
	assert_eq(m.alive_of("jungingen").size(), 1)
	assert_eq(m.alive_of("fresh").size(), 14)
	assert_eq(sim.entities.owners[m.alive_of("fresh")[0] - 1], P)
	assert_eq(_state(sim, "king"), MissionRuntime.Objective.ACTIVE)
	_put(sim, m.alive_of("reserve"), 12, 100)
	_check(sim)
	assert_true(m.fired.has("7b"), "round the wing, then at the king")


func test_8_a_knight_rides_at_the_king() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "3", "4", "5", "6", "7", "7b"])
	var reserve := {"group": "reserve", "player": 2, "at": [70, 125]}
	reserve["units"] = [["to_knight_brother", 3]]
	m._spawn_group(sim.tick, reserve)
	_check(sim)
	assert_true(m.fired.has("8"))
	assert_true(_kinds(sim).has("cutscene"))
	sim.run(100)
	assert_eq(m.alive_of("kokeritz").size(), 0, "Oleśnicki and the king strike him down")
	assert_eq(m.alive_of("jagiello").size(), 1)


func test_9_10_the_lithuanians_return_and_the_master_falls() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "3", "4", "5", "6", "7", "7b"])
	var reserve := {"group": "reserve", "player": 2, "at": [20, 60]}
	reserve["units"] = [["to_knight_brother", 6]]
	m._spawn_group(sim.tick, reserve)
	var master := {"group": "jungingen", "player": 2, "at": [24, 60]}
	master["units"] = [["hero_jungingen", 1]]
	m._spawn_group(sim.tick, master)
	m.fired["8"] = sim.tick - 3600
	_give(sim, ["king"])
	_check(sim)
	assert_true(m.fired.has("9"))
	assert_eq(m.alive_of("litva_back").size(), 16)
	_kill(sim, "reserve", 4)
	_check(sim)
	assert_true(m.fired.has("10"))
	assert_eq(m.alive_of("jungingen").size(), 0, "killed in the press, not by the player")
	assert_eq(_state(sim, "king"), MissionRuntime.Objective.DONE)
	assert_eq(_state(sim, "wagenburg"), MissionRuntime.Objective.ACTIVE)


func test_11_the_wagenburg_taken_wins() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["1", "3", "4", "5", "6", "7", "7b", "8", "9", "10"])
	_kill(sim, "wagon_guard")
	_check(sim)
	assert_true(m.fired.has("11"))
	assert_true(_kinds(sim).has("cutscene"))
	sim.run(120)
	assert_eq(m.outcome, MissionRuntime.Outcome.VICTORY)


func test_the_places_take_crosses() -> void:
	var sim := _sim()
	var m := sim.mission
	for i in 3:
		sim.magic.places.holders[i] = P
	_check(sim)
	assert_eq(_state(sim, "places"), MissionRuntime.Objective.DONE)


# --- defeats --------------------------------------------------------------------------------


func test_losing_the_king_or_jasko_loses() -> void:
	var sim := _sim()
	_kill(sim, "jagiello")
	_check(sim)
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.DEFEAT)
	var other := _sim()
	_kill(other, "jasko")
	_check(other)
	assert_eq(other.mission.outcome, MissionRuntime.Outcome.DEFEAT)


# --- state ----------------------------------------------------------------------------------


func test_save_and_load_keep_the_heat_and_the_banner() -> void:
	var sim := _sim()
	var m := sim.mission
	sim.run(400)
	_drop(sim)
	sim.run(30)
	var data := SimSave.capture(sim)
	var loaded := SimSave.restore(data, _db)
	assert_not_null(loaded)
	assert_eq(loaded.state_hash(), data["hash"])
	assert_eq(loaded.mission.field.heat, m.field.heat)
	assert_false(loaded.mission.field.banner_up())
	assert_false(loaded.combat.crown.army_morale.has(P))
	sim.run(600)
	loaded.run(600)
	assert_eq(loaded.state_hash(), sim.state_hash(), "and it plays on the same")


func test_the_field_changes_the_hash() -> void:
	var a := _sim()
	var b := _sim()
	b.mission.field.heat[b.mission.alive_of("lances_a")[0]] = 5
	assert_ne(a.state_hash(), b.state_hash())
