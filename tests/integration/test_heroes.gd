extends MagicTest
## M9 heroes and mission rules in the core: each hero's aura comes from its catalog template
## (Gintaut, mounted: +15 within 8 cells; Rumbaudas, light: +10 within 6); units a mission makes
## untouchable are neither attacked nor picked as targets; not_targeted units are left alone;
## items a mission locks cannot be built, trained or researched; a site consecrated by a castle
## gives its holder less Сила while the castle stands.

const GINTAUT := &"hero_gintaut"
const RUMBAUDAS := &"hero_rumbaudas"
const KEEPER := &"hero_keeper"
const CONSECRATION_WAIT := PowerPlaces.CONSECRATION_EVERY * 2


func test_hero_numbers_come_from_the_catalog_templates() -> void:
	var gintaut := _db.unit(GINTAUT)
	assert_eq(gintaut.hp, 400, "template «Конный»")
	assert_eq(gintaut.param(&"aura_morale"), 15)
	assert_eq(gintaut.param(&"aura_radius"), 8)
	assert_true(gintaut.never_flees)
	var rumbaudas := _db.unit(RUMBAUDAS)
	assert_eq(rumbaudas.hp, 280, "template «Лёгкий»")
	assert_eq(rumbaudas.param(&"aura_morale"), 10)
	assert_eq(rumbaudas.param(&"aura_radius"), 6)
	assert_true(rumbaudas.tags.has(&"arsonist"))
	var keeper := _db.unit(KEEPER)
	assert_eq(keeper.damage, 0, "template «Мирный»")
	assert_true(keeper.tags.has(&"not_targeted"))
	assert_eq(_db.unit(&"hero_kuchmeister").faction, &"to")


func test_gintaut_gives_15_within_8_cells() -> void:
	var sim := _open()
	var near := _spawn(sim, 1, SPEARMAN, 17.6, 10.5)
	var far := _spawn(sim, 1, SPEARMAN, 1.5, 10.5)
	_spawn(sim, 1, GINTAUT, 10.5, 10.5)
	sim.step()
	assert_eq(sim.combat.effective_morale(near - 1), 40 + 15, "7.1 cells from Gintaut")
	assert_eq(sim.combat.effective_morale(far - 1), 40, "9 cells away")


func test_rumbaudas_gives_10_within_6_cells_and_the_best_aura_counts() -> void:
	var sim := _open()
	var near := _spawn(sim, 1, SPEARMAN, 15.5, 10.5)
	var outside := _spawn(sim, 1, SPEARMAN, 17.6, 10.5)
	_spawn(sim, 1, RUMBAUDAS, 10.5, 10.5)
	sim.step()
	assert_eq(sim.combat.effective_morale(near - 1), 40 + 10, "5 cells from Rumbaudas")
	assert_eq(sim.combat.effective_morale(outside - 1), 40, "7.1 cells: outside his 6")
	_spawn(sim, 1, GINTAUT, 12.5, 10.5)
	sim.step()
	assert_eq(sim.combat.effective_morale(near - 1), 40 + 15, "auras do not add up")


func test_an_enemy_heros_aura_does_not_count() -> void:
	var sim := _open()
	var unit := _spawn(sim, 2, KNECHT, 12.5, 10.5)
	_spawn(sim, 1, GINTAUT, 10.5, 10.5)
	_passive(sim, unit)
	assert_eq(sim.combat.effective_morale(unit - 1), _db.unit(KNECHT).morale)


func test_untouchable_units_are_not_attacked() -> void:
	var sim := _open()
	var collector := _spawn(sim, 2, &"to_tithe_collector", 12.5, 10.5)
	var spear := _spawn(sim, 1, SPEARMAN, 10.5, 10.5)
	sim.combat.untouchable[collector] = true
	_passive(sim, collector)
	sim.enqueue(SimCommand.attack(sim.tick, 1, _ids(spear), collector))
	sim.run(200)
	assert_eq(sim.entities.hp[collector - 1], _db.unit(&"to_tithe_collector").hp)
	assert_eq(sim.entities.target[spear - 1], EntityStore.NO_ID, "the order is refused")


func test_not_targeted_units_are_left_alone() -> void:
	var sim := _open()
	var keeper := _spawn(sim, 1, KEEPER, 12.5, 10.5)
	_spawn(sim, 2, KNECHT, 10.5, 10.5)
	sim.run(200)
	assert_eq(sim.entities.hp[keeper - 1], _db.unit(KEEPER).hp)


func test_locked_items_cannot_be_built_or_trained() -> void:
	var sim := _world()
	var state := sim.economy.player(1)
	var tc := _place(sim, 1, &"gdl_town_center", 20, 20)
	var site := _db.building(ALKA)
	state.locked[&"gdl_peasant"] = true
	var prod := sim.economy.production
	assert_eq(prod.can_queue(1, tc, &"gdl_peasant"), EconomySystem.Fail.LOCKED)
	state.locked.erase(&"gdl_peasant")
	assert_eq(prod.can_queue(1, tc, &"gdl_peasant"), EconomySystem.Fail.OK)
	state.locked[ALKA] = true
	var fail := sim.economy.placement.can_place(1, site, SITE.x, SITE.y, false)
	assert_eq(fail, EconomySystem.Fail.LOCKED)
	assert_ne(UiText.fail(EconomySystem.Fail.LOCKED), "")


func test_a_site_consecrated_by_a_castle_gives_less_while_it_stands() -> void:
	var sim := _world()
	var places := sim.magic.places
	var castle := _place(sim, 2, &"to_castle", 30, 20)
	places.consecrated_by[0] = castle
	_spawn(sim, 1, SPEARMAN, 11.5, 12.5)
	sim.run(_db.magic.capture_ticks + 2)
	var shrine := _place(sim, 1, ALKA, SITE.x, SITE.y)
	assert_ne(shrine, BuildingStore.NO_ID)
	sim.run(CONSECRATION_WAIT)
	assert_eq(places.consecrated[0], 1, "the castle consecrates the site from afar")
	var low := places.rate_milli(0)
	sim.economy.destroy(castle)
	sim.run(CONSECRATION_WAIT)
	assert_eq(places.consecrated[0], 0)
	assert_gt(places.rate_milli(0), low)
