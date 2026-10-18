extends MagicTest
## The Crown as a skirmish faction (2026-10-18): the tabor, the pavise, the tiring lance, the
## foot servant, the bombard's battery, the cross made a chapel, salt works on salt springs,
## the Crown's spells and a skirmish with the Crown on either side.

const PL := &"pl"
const WAGON := &"pl_wagon"
const PAVISE := &"pl_pavise"
const PL_CROSSBOW := &"pl_crossbow"
const PL_SPEARMAN := &"pl_spearman"
const KOPIA := &"pl_kopia"
const SERVANT := &"pl_foot_servant"
const BOMBARD := &"pl_bombard"
const BATTERY := &"pl_battery"
const PL_PRIEST := &"pl_priest"
const CROSS := &"pl_shrine"
const SALT := &"pl_salt_works"
const KMET := &"pl_kmet"


## Grass with the Crown as player 1 and the Order as player 2 (and a place of power at SITE).
func _crown(w: int = 40, h: int = 30) -> Simulation:
	var sim := _open(w, h)
	sim.magic.places.add(_db.power_places[&"pp_spring"], sim.nav.cell_at(SITE.x, SITE.y))
	_join(sim, 1, PL)
	_join(sim, 2, ORDER)
	return sim


## Four wagons round (cx, cy), two cells out.
func _ring(sim: Simulation, cx: float, cy: float, n: int = 4) -> PackedInt32Array:
	var ids := PackedInt32Array()
	var spots := [Vector2(2, 0), Vector2(0, 2), Vector2(-2, 0), Vector2(0, -2)]
	for i in n:
		var d: Vector2 = spots[i]
		ids.append(_spawn(sim, 1, WAGON, cx + d.x, cy + d.y))
	return ids


# --- tabor -----------------------------------------------------------------------------------


func test_four_wagons_standing_in_a_ring_make_a_tabor() -> void:
	var sim := _crown()
	_ring(sim, 15.5, 15.5)
	var inside := _spawn(sim, 1, PL_SPEARMAN, 15.5, 15.5)
	var crown := sim.combat.crown
	assert_eq(crown.armor_melee(inside - 1), 0, "not linked yet")
	sim.run(_rules.tabor_link_ticks + 2)
	assert_eq(crown.ring_owner.size(), 1)
	assert_eq(crown.armor_melee(inside - 1), _rules.tabor_armor)
	assert_eq(crown.armor_pierce(inside - 1), _rules.tabor_armor)
	assert_true(crown.ignores_flank(inside - 1))
	var outside := _spawn(sim, 1, PL_SPEARMAN, 25.5, 15.5)
	assert_eq(crown.armor_melee(outside - 1), 0)


func test_three_wagons_need_tabor_craft() -> void:
	var sim := _crown()
	_ring(sim, 15.5, 15.5, 3)
	var inside := _spawn(sim, 1, PL_SPEARMAN, 15.5, 15.5)
	sim.run(_rules.tabor_link_ticks + 2)
	assert_eq(sim.combat.crown.ring_owner.size(), 0, "three are too few")
	var state := sim.economy.player(1)
	state.tabor_wagons_bonus = -1
	state.tabor_armor_bonus = 1
	sim.step()
	assert_eq(sim.combat.crown.armor_melee(inside - 1), _rules.tabor_armor + 1)


func test_tabor_order_draws_the_wagons_into_a_ring() -> void:
	var sim := _crown()
	var ids := PackedInt32Array()
	for i in 4:
		ids.append(_spawn(sim, 1, WAGON, 10.5 + i, 10.5))
	sim.enqueue(SimCommand.order(sim.tick, 1, SimCommand.Kind.TABOR, ids))
	sim.run(_rules.tabor_link_ticks + 400)
	assert_eq(sim.combat.crown.ring_owner.size(), 1, "the wagons drove out and linked")


# --- pavise, lance, servant -------------------------------------------------------------------


func test_a_set_pavise_covers_the_shooters_behind_it() -> void:
	var sim := _crown()
	var pavisier := _spawn(sim, 1, PAVISE, 15.5, 15.5)
	_face(sim, pavisier, Fixed.ONE, 0)
	var behind := _spawn(sim, 1, PL_CROSSBOW, 14.5, 15.5)
	var ahead := _spawn(sim, 1, PL_CROSSBOW, 16.8, 15.5)
	var crown := sim.combat.crown
	var def := _db.unit(PAVISE)
	assert_eq(crown.armor_pierce(behind - 1), 0, "not set up yet")
	sim.run(def.param(&"pavise_ticks") + 2)
	_face(sim, pavisier, Fixed.ONE, 0)
	assert_true(crown.pavise_set(pavisier))
	assert_eq(crown.armor_pierce(behind - 1), def.param(&"pavise_armor"))
	assert_eq(crown.armor_pierce(ahead - 1), 0, "ahead of the shield")


func test_the_lance_tires_in_long_melee_until_it_charges_again() -> void:
	var sim := _crown()
	var lance := _spawn(sim, 1, KOPIA, 15.5, 15.5)
	var crown := sim.combat.crown
	var def := _db.unit(KOPIA)
	var slot := lance - 1
	crown.tick = 100
	assert_eq(crown.strike_penalty(slot, true), 0)
	crown.tick = 100 + def.param(&"melee_fatigue_ticks")
	assert_eq(crown.strike_penalty(slot, false), def.param(&"melee_fatigue_damage"))
	assert_eq(crown.strike_penalty(slot, true), 0, "a new charge starts over")
	assert_eq(crown.strike_penalty(slot, false), 0)


func test_the_foot_servant_takes_heart_beside_a_lance() -> void:
	var sim := _crown()
	var servant := _spawn(sim, 1, SERVANT, 15.5, 15.5)
	var alone := sim.combat.morale_bonus(servant - 1)
	_spawn(sim, 1, KOPIA, 16.5, 15.5)
	var escort := _db.unit(SERVANT).param(&"escort_morale")
	assert_eq(sim.combat.morale_bonus(servant - 1) - alone, escort)


func test_a_servant_in_close_order_halves_the_morale_lost_around_him() -> void:
	var sim := _crown()
	var men := PackedInt32Array()
	for i in _rules.formation_neighbours:
		men.append(_spawn(sim, 1, PL_SPEARMAN, 15.5 + i * 0.5, 16.0))
	_spawn(sim, 1, SERVANT, 15.5, 15.5)
	assert_eq(sim.combat.crown.morale_loss(men[0] - 1, 10), 5)
	var far := _spawn(sim, 1, PL_SPEARMAN, 30.5, 25.5)
	assert_eq(sim.combat.crown.morale_loss(far - 1, 10), 10)


# --- the bombard ------------------------------------------------------------------------------


func test_the_bombard_fires_only_dug_in_at_a_battery_and_pays_iron() -> void:
	var sim := _crown()
	var bombard := _spawn(sim, 1, BOMBARD, 5.5, 5.5)
	var crown := sim.combat.crown
	var def := _db.unit(BOMBARD)
	sim.run(def.param(&"deploy_ticks") + 2)
	assert_false(crown.may_fire(bombard - 1), "no battery")
	assert_true(crown.anchored(bombard - 1))
	var other := _spawn(sim, 1, BOMBARD, 12.5, 5.5)
	_place(sim, 1, BATTERY, 13, 6)
	sim.run(def.param(&"deploy_ticks") + 2)
	assert_eq(crown.deployed.get(other, 0), sim.economy.buildings.next_id - 1)
	var state := sim.economy.player(1)
	state.stock[EconomySystem.IRON] = 0
	assert_false(crown.may_fire(other - 1), "no iron for the powder")
	state.stock[EconomySystem.IRON] = 100
	assert_true(crown.may_fire(other - 1))
	crown.fired(other - 1)
	assert_eq(state.stock[EconomySystem.IRON], 100 - def.param(&"shot_iron"))


# --- chapel and salt -----------------------------------------------------------------------


func test_a_priest_by_the_cross_makes_it_a_chapel() -> void:
	var sim := _crown()
	var b := _place(sim, 1, CROSS, SITE.x, SITE.y)
	var state := sim.economy.player(1)
	state.stock = PackedInt64Array([0, 1000, 0, 1000])
	var prod := sim.economy.production
	assert_eq(prod.can_queue(1, b, EconomyProduction.CHAPEL), EconomySystem.Fail.CONDITION)
	_spawn(sim, 1, PL_PRIEST, 13.5, 11.5)
	assert_eq(prod.can_queue(1, b, EconomyProduction.CHAPEL), EconomySystem.Fail.OK)
	sim.enqueue(SimCommand.queue_item(sim.tick, 1, b, EconomyProduction.CHAPEL))
	sim.step()
	var def := _db.building(CROSS)
	assert_eq(state.stock[EconomySystem.WOOD], 1000 - def.param(&"upgrade_wood"))
	sim.run(def.build_ticks + 2)
	assert_eq(sim.economy.buildings.upgraded[b - 1], 1)
	assert_eq(sim.magic.places.rate_milli(0), def.param(&"upgrade_power_rate_milli"))
	assert_eq(prod.can_queue(1, b, EconomyProduction.CHAPEL), EconomySystem.Fail.CONDITION)


func test_a_priest_may_lay_a_cross_but_nothing_else() -> void:
	var sim := _crown()
	var priest := _spawn(sim, 1, PL_PRIEST, 9.5, 9.5)
	sim.economy.player(1).age = 2
	sim.economy.player(1).stock = PackedInt64Array([1000, 1000, 1000, 1000])
	var magic := sim.magic
	magic.places.holders[0] = 1
	var cross := _build(sim, 1, _ids(priest), CROSS, SITE.x, SITE.y)
	assert_ne(cross, BuildingStore.NO_ID)
	assert_eq(sim.economy.job[priest - 1], EconomySystem.Job.BUILD)
	var house := _build(sim, 1, _ids(priest), &"pl_house", 20, 20)
	assert_ne(house, BuildingStore.NO_ID, "the foundation is laid")
	assert_eq(sim.economy.job_ref[priest - 1], cross, "but the priest does not build a house")


func test_salt_works_stand_only_on_a_spring_and_give_silver() -> void:
	var cells := {Vector2i(10, 10): "%", Vector2i(20, 10): "%", Vector2i(30, 10): "%"}
	var sim := _drawn(40, 20, cells)
	_join(sim, 1, PL)
	_join(sim, 2, ORDER)
	var state := sim.economy.player(1)
	state.age = 2
	var place := sim.economy.placement
	var def := _db.building(SALT)
	assert_eq(place.can_place(1, def, 4, 4, false), EconomySystem.Fail.NO_SPRING)
	assert_eq(place.can_place(1, def, 10, 10, false), EconomySystem.Fail.OK)
	assert_eq(sim.economy.nodes.at_cell(sim.nav.cell_at(10, 10)) != ResourceNodes.NO_ID, true)
	var b := _place(sim, 1, SALT, 10, 10)
	assert_ne(b, BuildingStore.NO_ID)
	assert_eq(sim.economy.nodes.at_cell(sim.nav.cell_at(10, 10)), ResourceNodes.NO_ID)
	var before := state.stock[EconomySystem.SILVER]
	sim.run(10 * Fixed.TICKS_PER_SECOND)
	assert_eq(state.stock[EconomySystem.SILVER] - before, def.param(&"silver_milli") * 10 / 1000)
	_place(sim, 1, SALT, 20, 10)
	assert_eq(place.can_place(1, def, 30, 10, false), EconomySystem.Fail.TOO_MANY)
	assert_eq(
		sim.economy.placement.can_place(2, _db.building(&"to_house"), 30, 10, false),
		EconomySystem.Fail.OCCUPIED,
		"others mine the spring"
	)


# --- spells -----------------------------------------------------------------------------------


func test_bogurodzica_lifts_morale_and_turns_the_fleeing_back() -> void:
	var sim := _crown()
	var priest := _spawn(sim, 1, PL_PRIEST, 15.5, 15.5)
	var man := _spawn(sim, 1, PL_SPEARMAN, 16.5, 15.5)
	sim.economy.player(1).age = 2
	_give_power(sim, 1, 300)
	var before := sim.combat.morale_bonus(man - 1)
	sim.combat.lose_morale(man - 1, 1000)
	assert_true(sim.combat.is_fleeing(man))
	sim.enqueue(SimCommand.cast(sim.tick, 1, _ids(priest), &"sp_bogurodzica", 0, 0))
	sim.run(2)
	assert_false(sim.combat.is_fleeing(man), "he turns back")
	assert_eq(sim.combat.morale_bonus(man - 1) - before, _db.magic.hymn_morale)


func test_procession_makes_bogurodzica_cheaper() -> void:
	var sim := _crown()
	var spell := _db.spell(&"sp_bogurodzica")
	assert_eq(sim.magic.power_cost(1, spell), spell.power_cost)
	sim.economy.player(1).unit_mods[&"sp_bogurodzica.cost_permille"] = -300
	assert_eq(sim.magic.power_cost(1, spell), spell.power_cost * 7 / 10)


func test_the_banner_blessing_goes_on_one_unit() -> void:
	var sim := _crown()
	var priest := _spawn(sim, 1, PL_PRIEST, 15.5, 15.5)
	var blessed := _spawn(sim, 1, PL_SPEARMAN, 17.5, 15.5)
	var other := _spawn(sim, 1, PL_SPEARMAN, 17.5, 17.5)
	sim.economy.player(1).age = 2
	_give_power(sim, 1, 300)
	var at := Vector2i(_at(17.5), _at(15.5))
	sim.enqueue(SimCommand.cast(sim.tick, 1, _ids(priest), &"sp_banner_blessing", at.x, at.y))
	sim.run(2)
	var crown := sim.combat.crown
	assert_eq(crown.armor_melee(blessed - 1), _db.magic.blessing_armor)
	assert_eq(crown.armor_melee(other - 1), 0)


# --- skirmish --------------------------------------------------------------------------------


func test_the_crown_plays_a_skirmish_with_kmets() -> void:
	assert_eq(SkirmishSetup.peasant_of(_db, PL), KMET)
	assert_eq(SkirmishSetup.peasant_of(_db, GDL), &"gdl_peasant")
	var factions: Array[StringName] = [ORDER, PL]
	var sim := SkirmishSetup.new_simulation(3, _db, factions)
	sim.run(2)
	assert_eq(sim.economy.player(2).faction, PL)
	assert_eq(_units_of(sim, 2, KMET), SkirmishSetup.START_PEASANTS)
	assert_eq(SkirmishSetup.faction_of(2, factions), PL)
	assert_not_null(SkirmishSetup.ai_profile(PL, &"normal"))
	assert_not_null(SkirmishSetup.ai_profile(PL, &"easy"))
