# gdlint:ignore = max-public-methods
extends GutTest
## «ВКЛ 7. Слуцк, 1508»: one test per trigger of the mission card and per rule of its own
## (MissionSiege: ladders raised, climbed and pushed off, the two belts of walls lost and won
## back, shooters on the walls, the townsmen's arms and water, the princess, food in a siege,
## the secret passage, the workshops and the fire arrows). The world is put into the condition
## and the result is checked; earlier triggers a test does not need are marked as fired by hand.

const MISSION := "gdl_07"
const P := 1
const REBELS := 2
const MOSCOW := 3
const CHECK := MissionRuntime.CHECK_EVERY
## Inside the Lower castle, in its middle; inside the Upper castle by the court.
const LOWER := Vector2i(50, 46)
const UPPER := Vector2i(32, 47)
## Outside the Lower castle's north wall (a ladder spot of the first assault: wall, foot).
const WALL := Vector2i(46, 32)
const FOOT := Vector2i(46, 31)
const TOP := Vector2i(46, 33)
const MOUTH := Vector2i(24, 41)
const EXIT := Vector2i(18, 27)
const PIER := Vector2i(23, 49)
const FAR := Vector2i(100, 80)

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


func _put(sim: Simulation, ids: PackedInt32Array, c: Vector2i) -> void:
	for id in ids:
		sim.entities.pos_x[id - 1] = _fx(c.x)
		sim.entities.pos_y[id - 1] = _fx(c.y)
		sim.entities.stop(id)


func _one(sim: Simulation, type: StringName, p: int, c: Vector2i) -> int:
	return sim.spawn_unit(type, p, _fx(c.x), _fx(c.y))


## Only the three heroes stay (far inside the Upper castle): what a test needs it puts there.
func _alone(sim: Simulation) -> void:
	var keep := PackedInt32Array()
	for g: String in ["andrei", "yuri", "lady"]:
		keep.append_array(sim.mission.alive_of(g))
	for id in sim.entities.alive_ids.duplicate():
		if not keep.has(id):
			sim.remove_unit(id)
	_put(sim, sim.mission.alive_of("andrei"), Vector2i(25, 56))
	_put(sim, sim.mission.alive_of("yuri"), Vector2i(26, 56))
	_put(sim, sim.mission.alive_of("lady"), Vector2i(24, 56))


func _b(sim: Simulation, name: String) -> int:
	return sim.mission.named.get(name, 0)


func _at(sim: Simulation, id: int) -> Vector2i:
	return Vector2i(
		Fixed.to_cells(sim.entities.pos_x[id - 1]), Fixed.to_cells(sim.entities.pos_y[id - 1])
	)


# --- setup ----------------------------------------------------------------------------------


func test_the_castle_the_posad_and_the_camp_are_set_up() -> void:
	var sim := _sim()
	var m := sim.mission
	sim.run(2)
	assert_eq(sim.nav.width, 150)
	assert_eq(sim.nav.height, 100)
	assert_true(sim.sides.hostile(P, REBELS) and sim.sides.hostile(P, MOSCOW))
	assert_true(sim.sides.friendly(REBELS, MOSCOW))
	assert_eq(sim.economy.player(REBELS).faction, &"gdl", "the rebels are the Duchy's own")
	for g: String in ["andrei", "yuri", "lady", "archers", "hakownica", "burghers", "spears"]:
		assert_gt(m.alive_of(g).size(), 0, "%s stands" % g)
	assert_eq(m.alive_of("burghers").size(), 20)
	assert_true(sim.combat.untouchable.has(m.alive_of("lady")[0]), "the princess does not fight")
	var walls := 0
	for b in sim.economy.buildings.alive_ids:
		if sim.economy.buildings.defs[b - 1].id == &"gdl_wall":
			walls += 1
	assert_gt(walls, 100, "both castles walled")
	for name: String in ["court", "gate_lower_n", "gate_upper_n", "alka", "posad_1", "workshop_3"]:
		assert_true(sim.economy.buildings.is_alive(_b(sim, name)), name)
	assert_eq(sim.magic.places.count(), 1, "the spring under the castle hill")
	assert_eq(sim.magic.places.holders[0], P, "held by the alka")
	assert_false(m.stealth.night, "a siege starts by day")
	assert_true(_has_event(sim, "cutscene", "the_princess"))
	assert_eq(_state(sim, "prepare"), MissionRuntime.Objective.ACTIVE)
	assert_eq(_state(sim, "never_lower"), MissionRuntime.Objective.ACTIVE)
	assert_eq(_state(sim, "keep_posad"), MissionRuntime.Objective.ACTIVE)


func test_the_walls_close_both_castles_but_the_gates_open_to_their_own() -> void:
	var sim := _sim()
	var nav := sim.nav
	var foot := NavGrid.MoveClass.FOOT
	assert_false(nav.passable(foot, nav.cell_at(46, 32)), "the north wall")
	assert_false(nav.passable(foot, nav.cell_at(62, 40)), "the east wall")
	assert_false(nav.passable(foot, nav.cell_at(38, 40)), "the wall between the castles")
	assert_false(nav.passable(foot, nav.cell_at(15, 48)), "the Sluch under the Upper castle")
	assert_true(sim.economy.buildings.defs[_b(sim, "gate_lower_n") - 1].base_id == &"gate")


# --- ladders --------------------------------------------------------------------------------


func _ladder(sim: Simulation, n := 1, tries := 2) -> PackedInt32Array:
	var m := sim.mission
	var ids := PackedInt32Array()
	for k in n:
		ids.append(_one(sim, &"gdl_spearman", REBELS, FOOT + Vector2i(k % 2, -1)))
	m.groups["party_t"] = ids
	var rules: Dictionary = m.def.rules["siege"]["ladder"]
	rules["tries"] = tries
	m.run(
		{
			"do": "ladders",
			"group": "party_t",
			"spots": [[WALL.x, WALL.y, FOOT.x, FOOT.y]],
			"goal": [LOWER.x, LOWER.y],
			"else": [70, 30]
		},
		sim.tick
	)
	return ids


func test_a_party_raises_its_ladder_and_climbs_over_one_at_a_time() -> void:
	var sim := _sim()
	_alone(sim)
	var m := sim.mission
	var party := _ladder(sim, 3)
	assert_eq(sim.entities.stance[party[0] - 1], EntityStore.Stance.PASSIVE, "carries, not fights")
	var raise := int(m.def.rules["siege"]["ladder"]["raise_ticks"])
	sim.run(raise + 4 * CHECK)
	assert_eq(m.siege.l_state[0], MissionSiege.Ladder.UP)
	assert_true(m.flags.has("ladder_up"))
	var climb := int(m.def.rules["siege"]["ladder"]["climb_ticks"])
	sim.run(climb + 2 * CHECK)
	assert_between(m.siege.climbed, 1, 2, "the first men over the wall, not all at once")
	var over := 0
	for id in party:
		if m.siege.belt_of(m, id) == "lower":
			over += 1
			assert_eq(sim.entities.stance[id - 1], EntityStore.Stance.AGGRESSIVE)
	assert_eq(over, m.siege.climbed)
	sim.run(3 * (climb + 2 * CHECK))
	assert_eq(m.siege.climbed, 3, "all three in")
	assert_true(m.siege.ladders_spent("party_t"), "a ladder with nobody left is done with")


func test_men_at_the_top_push_the_ladder_off_and_the_climber_falls() -> void:
	var sim := _sim()
	_alone(sim)
	var m := sim.mission
	var party := _ladder(sim, 2, 1)
	var raise := int(m.def.rules["siege"]["ladder"]["raise_ticks"])
	sim.run(raise + 3 * CHECK)
	assert_eq(m.siege.l_state[0], MissionSiege.Ladder.UP)
	# Three defenders right behind the wall, passive so they only push.
	var men := PackedInt32Array()
	for k in 3:
		men.append(_one(sim, &"gdl_spearman", P, TOP + Vector2i(k - 1, 1)))
		sim.entities.stance[men[k] - 1] = EntityStore.Stance.PASSIVE
	var push := int(m.def.rules["siege"]["ladder"]["push_ticks"])
	sim.run(push / 3 + 3 * CHECK)
	assert_eq(m.siege.pushed, 1)
	assert_true(m.flags.has("ladder_pushed"))
	assert_eq(m.siege.l_state[0], MissionSiege.Ladder.DONE, "no tries left")
	assert_true(m.siege.ladders_spent("party_t"))
	for id in party:
		if sim.entities.is_alive(id):
			assert_eq(sim.entities.stance[id - 1], EntityStore.Stance.AGGRESSIVE, "they go round")


func test_a_pushed_ladder_is_raised_again_while_tries_last() -> void:
	var sim := _sim()
	_alone(sim)
	var m := sim.mission
	_ladder(sim, 2, 2)
	var raise := int(m.def.rules["siege"]["ladder"]["raise_ticks"])
	sim.run(raise + 3 * CHECK)
	for k in 3:
		var id := _one(sim, &"gdl_spearman", P, TOP + Vector2i(k - 1, 1))
		sim.entities.stance[id - 1] = EntityStore.Stance.PASSIVE
	var push := int(m.def.rules["siege"]["ladder"]["push_ticks"])
	sim.run(push / 3 + 3 * CHECK)
	assert_eq(m.siege.pushed, 1)
	assert_eq(m.siege.l_state[0], MissionSiege.Ladder.RAISING, "up again")
	assert_eq(m.siege.l_tries[0], 1)


# --- belts ----------------------------------------------------------------------------------


func test_a_belt_is_lost_to_enemies_alone_in_it_and_won_back() -> void:
	var sim := _sim()
	_alone(sim)
	var m := sim.mission
	var foes := PackedInt32Array()
	for k in 3:
		foes.append(_one(sim, &"gdl_spearman", REBELS, LOWER + Vector2i(k, 0)))
		sim.entities.stance[foes[k] - 1] = EntityStore.Stance.PASSIVE
	_check(sim)
	assert_true(m.siege.lost["lower"])
	assert_eq(m.siege.falls["lower"], 1)
	assert_true(m.fired.has("8"), "«To the Upper!»")
	assert_eq(_state(sim, "never_lower"), MissionRuntime.Objective.FAILED)
	assert_false(sim.economy.buildings.is_alive(_b(sim, "alka")), "the spring is lost")
	for id in foes:
		sim.remove_unit(id)
	_one(sim, &"gdl_spearman", P, LOWER)
	_check(sim)
	assert_false(m.siege.lost["lower"], "won back")
	assert_false(m.is_over())


func test_the_upper_castle_lost_or_the_court_destroyed_is_defeat() -> void:
	var sim := _sim()
	sim.economy.destroy(_b(sim, "court"))
	_check(sim)
	assert_eq(sim.mission.outcome, MissionRuntime.Outcome.DEFEAT)


func test_any_of_the_three_heroes_killed_is_defeat() -> void:
	for g: String in ["andrei", "yuri", "lady"]:
		var sim := _sim()
		var id: int = sim.mission.alive_of(g)[0]
		sim.combat.untouchable.erase(id)
		sim.combat.lightning(id, REBELS, 10000)
		sim.run(CHECK * 3)
		assert_eq(sim.mission.outcome, MissionRuntime.Outcome.DEFEAT, g)


# --- the walls, the townsmen, water, the princess -------------------------------------------


func test_shooters_by_the_wall_shoot_further_and_are_harder_to_hit() -> void:
	var sim := _sim()
	_alone(sim)
	var m := sim.mission
	var a := _one(sim, &"gdl_castle_archer", P, TOP)
	var def := sim.economy.unit_defs[a - 1]
	_check(sim)
	assert_eq(sim.entities.up_range[a - 1], def.param(&"wall_range_bonus", 0))
	assert_eq(sim.entities.up_armor_p[a - 1], def.param(&"wall_armor_pierce", 0))
	assert_true(m.siege.test(m, {"type": "manned", "at_least": 1}))
	_put(sim, PackedInt32Array([a]), LOWER)
	_check(sim)
	assert_eq(sim.entities.up_range[a - 1], 0, "off the wall, no bonus")
	var g := _one(sim, &"gdl_hakownica", P, Vector2i(61, 47))
	_check(sim)
	assert_eq(sim.entities.up_range[g - 1], int(m.def.rules["siege"]["wall"]["range"]))


func test_the_townsmen_take_up_arms() -> void:
	var sim := _sim()
	var m := sim.mission
	var b: int = m.alive_of("burghers")[0]
	var def := sim.economy.unit_defs[b - 1]
	m.run({"do": "militia"}, sim.tick)
	assert_eq(def.damage + sim.entities.up_damage[b - 1], def.param(&"militia_damage", 0))
	m.run({"do": "militia"}, sim.tick)
	assert_eq(def.damage + sim.entities.up_damage[b - 1], 5, "only once")


func _douse_time(by_water: bool, townsman: bool) -> int:
	var sim := _sim()
	_alone(sim)
	_put(sim, sim.mission.alive_of("lady"), Vector2i(24, 40))
	var house := _b(sim, "posad_1") if not by_water else _b(sim, "granary_upper")
	var store := sim.economy.buildings
	var at := Vector2i(store.cell_x[house - 1], store.cell_y[house - 1] + 2)
	if not by_water:
		at = Vector2i(store.cell_x[house - 1], store.cell_y[house - 1] + 2)
	_one(sim, &"gdl_burgher" if townsman else &"gdl_spearman", P, at)
	sim.fire.ignite(house)
	var t := 0
	while sim.fire.is_burning(house) and t < 4000:
		sim.run(CHECK)
		t += CHECK
	return t


func test_townsmen_and_water_put_a_fire_out_quicker() -> void:
	var plain := _douse_time(false, false)
	var townsman := _douse_time(false, true)
	var by_well := _douse_time(true, true)
	assert_lt(townsman, plain, "a townsman with buckets")
	assert_lt(by_well, townsman, "and a well or barrels near")


func test_the_princess_stays_in_the_upper_castle_and_holds_hearts() -> void:
	var sim := _sim()
	_alone(sim)
	var m := sim.mission
	var her: int = m.alive_of("lady")[0]
	_put(sim, PackedInt32Array([her]), LOWER)
	_check(sim)
	assert_eq(sim.entities.orders[her - 1], EntityStore.Order.MOVE, "sent back home")
	_put(sim, PackedInt32Array([her]), UPPER)
	var s := _one(sim, &"gdl_spearman", P, UPPER + Vector2i(2, 0))
	var full := sim.economy.unit_defs[s - 1].morale * CombatSystem.MORALE_SCALE
	sim.entities.morale[s - 1] = 0
	_check(sim)
	assert_gte(sim.entities.morale[s - 1], full * 600 / 1000, "not below the floor near her")


func test_with_no_food_men_lose_heart_and_the_posad_and_boats_bring_food() -> void:
	var sim := _sim()
	var m := sim.mission
	var state := sim.economy.player(P)
	var before := state.stock[EconomySystem.FOOD]
	sim.run(1200 + CHECK)
	assert_gt(m.siege.food_in, 0, "the posad and a boat brought food")
	assert_true(m.flags.has("boat"))
	state.stock[EconomySystem.FOOD] = 0
	var b: int = m.alive_of("spears")[0]
	var was := sim.entities.morale[b - 1]
	m.siege.next_posad = sim.tick + 100000
	m.siege.next_boat = sim.tick + 100000
	_check(sim)
	assert_true(m.flags.has("starving"))
	assert_lt(sim.entities.morale[b - 1], was)
	assert_gt(before, 0)


func test_no_boat_lands_with_an_enemy_by_the_pier() -> void:
	var sim := _sim()
	var m := sim.mission
	var foe := _one(sim, &"gdl_spearman", REBELS, PIER + Vector2i(-1, 3))
	sim.entities.stance[foe - 1] = EntityStore.Stance.PASSIVE
	sim.combat.untouchable[foe] = true
	m.siege.next_posad = 100000
	sim.run(1200 + CHECK)
	assert_false(m.flags.has("boat"))
	assert_eq(m.siege.food_in, 0)


# --- the passage, the workshops, fire -------------------------------------------------------


func test_the_secret_passage_takes_men_out_and_back_once_open() -> void:
	var sim := _sim()
	_alone(sim)
	var m := sim.mission
	var r := _one(sim, &"gdl_light_horse", P, MOUTH)
	_check(sim)
	assert_eq(_at(sim, r), MOUTH, "shut until the sortie")
	m.run({"do": "tunnel", "on": true}, sim.tick)
	_check(sim)
	assert_eq(_at(sim, r), EXIT + Vector2i(1, 0), "out on the river bank")
	assert_true(m.siege.tunnel_used)
	assert_true(m.fired.has("5"), "the chronicler's line")
	_put(sim, PackedInt32Array([r]), EXIT)
	_check(sim)
	assert_eq(_at(sim, r), MOUTH + Vector2i(1, 0), "back by the court")


func test_every_workshop_burned_puts_the_assault_off() -> void:
	var sim := _sim()
	var m := sim.mission
	m.run({"do": "assault_at", "ticks": 1000}, sim.tick)
	var due := m.siege.assault_due(m)
	sim.fire.ignite(_b(sim, "workshop_1"))
	_check(sim)
	assert_eq(m.siege.assault_due(m), due + 1200)
	sim.economy.destroy(_b(sim, "workshop_2"))
	_check(sim)
	assert_eq(m.siege.assault_due(m), due + 2400)


func test_fire_arrows_set_roofs_alight_but_not_the_walls() -> void:
	var sim := _sim()
	var m := sim.mission
	sim.mission.groups["fire_archers"] = PackedInt32Array(
		[_one(sim, &"gdl_castle_archer", REBELS, FAR)]
	)
	m.run({"do": "fire_arrows", "on": true}, sim.tick)
	var every := int(m.def.rules["siege"]["fire_arrows"]["every_ticks"])
	sim.run(every + CHECK)
	assert_true(m.flags.has("fire_arrow"))
	assert_eq(sim.fire.burning.size(), 1)
	var b: int = sim.fire.burning.keys()[0]
	assert_false(MissionSiege.LINES.has(sim.economy.buildings.defs[b - 1].base_id))
	assert_ne(m.siege.belt_of(m, m.alive_of("lady")[0]), "", "inside a belt")


func test_a_fire_does_not_spread_to_the_walls() -> void:
	var sim := _sim()
	var b := _b(sim, "granary_lower")
	for w: int in sim.fire.no_spread:
		assert_true(MissionSiege.LINES.has(sim.economy.buildings.defs[w - 1].base_id))
	assert_gt(sim.fire.no_spread.size(), 100)
	_alone(sim)
	sim.fire.ignite(b)
	sim.run(1200)
	for w: int in sim.fire.burning:
		assert_false(sim.fire.no_spread.has(w), "no wall caught")


func test_the_storm_puts_out_the_players_fires_under_it() -> void:
	var sim := _sim()
	_alone(sim)
	var house := _b(sim, "posad_3")
	sim.fire.ignite(house)
	var w := _one(sim, &"gdl_znakharka", P, Vector2i(72, 44))
	sim.economy.player(P).power = 1000 * MagicSystem.POWER_UNIT
	var store := sim.economy.buildings
	var x := store.center_x(house)
	var y := store.center_y(house)
	sim.enqueue(SimCommand.cast(sim.tick, P, PackedInt32Array([w]), &"sp_perkunas", x, y))
	sim.run(CHECK * 4)
	assert_false(sim.fire.is_burning(house))
	assert_true(sim.mission.flags.has("rain_put_out"))


# --- the triggers ---------------------------------------------------------------------------


func test_1_prepared_is_done_with_shooters_on_the_walls_and_the_townsmen_in() -> void:
	var sim := _sim()
	var m := sim.mission
	sim.run(2)
	var archers := m.alive_of("archers")
	for k in archers.size():
		_put(sim, PackedInt32Array([archers[k]]), Vector2i(44 + k, 33))
	_put(sim, m.alive_of("burghers"), LOWER)
	_check(sim)
	assert_eq(_state(sim, "prepare"), MissionRuntime.Objective.DONE)


func test_2_the_rebels_come_burn_the_posad_edge_and_parley() -> void:
	var sim := _sim()
	var m := sim.mission
	sim.run(6 * 1200 + CHECK * 2)
	assert_true(m.fired.has("2"))
	assert_eq(_state(sim, "prepare"), MissionRuntime.Objective.FAILED, "not ready in time")
	assert_true(_has_event(sim, "cutscene", "parley_at_the_gate"))
	assert_true(
		(
			sim.fire.is_burning(_b(sim, "posad_7"))
			or not sim.economy.buildings.is_alive(_b(sim, "posad_7"))
		)
	)
	assert_gt(m.alive_of("party_1").size(), 0)
	assert_eq(m.alive_of("cannons").size(), 2)


func test_3_the_first_assault_brings_ladders_and_guns_on_the_gate() -> void:
	var sim := _sim()
	var m := sim.mission
	sim.run(6 * 1200 + 600 + CHECK * 2)
	assert_true(m.fired.has("3"))
	assert_eq(_state(sim, "first"), MissionRuntime.Objective.ACTIVE)
	assert_eq(m.siege.l_group.size(), 4, "four ladders on the Lower castle")
	assert_true(m.siege.militia)


func test_4_the_first_assault_beaten_back_opens_the_sortie() -> void:
	var sim := _sim()
	var m := sim.mission
	sim.run(6 * 1200 + 600 + CHECK * 2)
	for id in m.alive_of("party_1"):
		sim.remove_unit(id)
	_check(sim)
	assert_true(m.fired.has("4"))
	assert_eq(_state(sim, "first"), MissionRuntime.Objective.DONE)
	assert_eq(_state(sim, "sortie"), MissionRuntime.Objective.ACTIVE)
	assert_eq(_state(sim, "yuri"), MissionRuntime.Objective.ACTIVE)
	assert_true(m.siege.tunnel_on)
	assert_true(_has_event(sim, "cutscene", "yuri_asks"))
	assert_eq(m.siege.assault_due(m), m.fired["4"] + 6 * 1200)


func test_6_a_workshop_burned_raises_the_camp() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["2", "3", "4"])
	m.run(m.def.triggers[_trigger(m, "2")]["do"][1], sim.tick)
	sim.fire.ignite(_b(sim, "workshop_1"))
	_check(sim)
	assert_true(m.fired.has("6"))
	assert_eq(sim.entities.stance[m.alive_of("camp_guard")[0] - 1], EntityStore.Stance.AGGRESSIVE)


func test_yuri_back_unhurt_is_done_hurt_is_failed() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["2", "3", "4", "6", "yuri_out"])
	m.run({"do": "objective", "id": "yuri", "optional": true, "text": "x"}, sim.tick)
	_check(sim)
	assert_eq(_state(sim, "yuri"), MissionRuntime.Objective.DONE)
	var sim2 := _sim()
	var m2 := sim2.mission
	_skip(sim2, ["2", "3", "4", "yuri_out"])
	m2.run({"do": "objective", "id": "yuri", "optional": true, "text": "x"}, sim2.tick)
	var y: int = m2.alive_of("yuri")[0]
	sim2.entities.hp[y - 1] = sim2.entities.max_hp[y - 1] / 2
	_check(sim2)
	assert_eq(_state(sim2, "yuri"), MissionRuntime.Objective.FAILED)


func test_7_the_night_assault_comes_when_due_with_fire_arrows() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["2", "3", "4"])
	m.run({"do": "assault_at", "ticks": 0}, sim.tick)
	_check(sim)
	assert_true(m.fired.has("7"))
	assert_true(m.stealth.night, "it is night")
	assert_true(m.siege.arrows_on)
	assert_eq(_state(sim, "night"), MissionRuntime.Objective.ACTIVE)
	assert_eq(
		m.siege.l_group.size(),
		6,
		"three ladders on the Upper, two on the Lower, one more on normal"
	)
	assert_true(_has_event(sim, "cutscene", "night_assault"))


func test_7_on_easy_no_extra_party() -> void:
	var sim := _sim("easy")
	var m := sim.mission
	_skip(sim, ["2", "3", "4"])
	m.run({"do": "assault_at", "ticks": 0}, sim.tick)
	_check(sim)
	assert_eq(m.siege.l_group.size(), 5)
	assert_false(m.fired.has("7n"))


func test_9_the_night_beaten_back_brings_dawn_the_messenger_and_the_countdown() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["2", "3", "4"])
	m.run({"do": "assault_at", "ticks": 0}, sim.tick)
	_check(sim)
	for g: String in ["party_2u", "party_2l", "party_2x", "lances_2", "lances_2x", "fire_archers"]:
		for id in m.alive_of(g):
			sim.remove_unit(id)
	_check(sim)
	assert_true(m.fired.has("9"))
	assert_false(m.stealth.night, "dawn")
	assert_false(m.siege.arrows_on)
	assert_eq(_state(sim, "night"), MissionRuntime.Objective.DONE)
	assert_eq(_state(sim, "hold"), MissionRuntime.Objective.ACTIVE)
	assert_true(_has_event(sim, "cutscene", "messenger"))
	assert_eq(m.countdown_end, m.fired["9"] + 4 * 1200)


func test_10_the_rebels_leave_and_slutsk_has_held() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["2", "3", "4", "6", "7", "9"])
	m.fired["9"] = sim.tick - 4 * 1200
	sim.run(CHECK * 12)
	assert_true(m.fired.has("10"))
	assert_true(_has_event(sim, "cutscene", "smoke_over_the_sluch"))
	assert_eq(m.outcome, MissionRuntime.Outcome.VICTORY)
	assert_eq(_state(sim, "never_lower"), MissionRuntime.Objective.DONE)
	assert_eq(_state(sim, "keep_posad"), MissionRuntime.Objective.DONE)


func test_half_the_posad_burned_fails_the_optional_objective() -> void:
	var sim := _sim()
	var m := sim.mission
	_skip(sim, ["2"])
	for k in range(1, 7):
		sim.economy.destroy(_b(sim, "posad_%d" % k))
	_check(sim)
	assert_eq(_state(sim, "keep_posad"), MissionRuntime.Objective.FAILED)
	assert_lt(m.siege.standing_permille(m, m.def.rules["siege"]["posad"]["buildings"]), 501)


func _trigger(m: MissionRuntime, tid: String) -> int:
	for i in m.def.triggers.size():
		if m.def.triggers[i]["id"] == tid:
			return i
	return -1


# --- state ----------------------------------------------------------------------------------


func test_save_and_load_keep_the_ladders_belts_and_the_passage() -> void:
	var sim := _sim()
	_alone(sim)
	var m := sim.mission
	_ladder(sim, 3)
	m.run({"do": "tunnel", "on": true}, sim.tick)
	m.run({"do": "militia"}, sim.tick)
	m.run({"do": "assault_at", "ticks": 5000}, sim.tick)
	sim.run(150)
	var data := SimSave.capture(sim)
	var loaded := SimSave.restore(data, _db)
	assert_not_null(loaded)
	assert_eq(loaded.state_hash(), data["hash"])
	assert_eq(loaded.mission.siege.l_group.size(), 1)
	assert_true(loaded.mission.siege.tunnel_on)
	assert_eq(loaded.fire.no_spread.size(), sim.fire.no_spread.size())
	sim.run(1200)
	loaded.run(1200)
	assert_eq(loaded.state_hash(), sim.state_hash(), "and it plays on the same")
	assert_eq(loaded.mission.siege.climbed, sim.mission.siege.climbed)


func test_the_siege_changes_the_hash() -> void:
	var a := _sim()
	var b := _sim()
	b.mission.siege.pushed += 1
	assert_ne(a.state_hash(), b.state_hash())
	var c := _sim()
	c.mission.siege.lost["lower"] = true
	assert_ne(a.state_hash(), c.state_hash())
	var d := _sim()
	d.fire.no_spread.erase(d.fire.no_spread.keys()[0])
	assert_ne(a.state_hash(), d.state_hash())


static func _fx(cell: int) -> int:
	return Fixed.from_cells(cell) + Fixed.HALF
