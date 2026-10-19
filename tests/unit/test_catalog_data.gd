extends GutTest
## M1: the exported catalog loads in Godot and carries the catalog's numbers.

var _db: CatalogDB


func before_all() -> void:
	_db = CatalogDB.load_all()


func test_index_counts_match_catalog() -> void:
	assert_eq(_db.index.exported_on, "2026-10-15")
	assert_eq(_db.factions.size(), 4)
	assert_eq(_db.units.size(), _db.index.units.size())
	# 70 faction units, 11 special neutral units, 5 animals, 49 campaign heroes (M9) and
	# Ostrogski as the lone fugitive of ВКЛ 6.
	assert_eq(_db.units.size(), 137)
	assert_eq(_db.spells.size(), 14)
	assert_eq(_db.ages.size(), 3)


func test_every_resource_has_its_own_id() -> void:
	for id: StringName in _db.units:
		assert_eq(_db.units[id].id, id)
	for id: StringName in _db.buildings:
		assert_eq(_db.buildings[id].id, id)
	for id: StringName in _db.techs:
		assert_eq(_db.techs[id].id, id)


func test_knight_brother_numbers() -> void:
	var u := _db.unit(&"to_knight_brother")
	assert_eq(u.hp, 200)
	assert_eq(u.damage, 14)
	assert_eq(u.damage_type, &"melee")
	assert_eq([u.armor_melee, u.armor_pierce], [5, 5])
	assert_eq([u.cost_food, u.cost_wood, u.cost_iron, u.cost_silver], [120, 0, 90, 55])
	assert_eq(u.train_ticks, 900, "45 s at 20 ticks/s")
	assert_eq(u.reload_ticks, 40)
	assert_eq(u.speed_milli, 1250)
	assert_eq(u.morale, 100)
	assert_true(u.has_class(&"heavy_cavalry"))
	assert_true(u.has_class(&"cavalry"))
	assert_eq(u.param(&"charge_permille"), 2500)
	assert_eq(u.param(&"charge_distance"), 4)
	assert_eq(u.param(&"limit_per_castle"), 12)
	assert_true(u.tags.has(&"no_pursuit"))
	assert_eq(u.trained_at, [&"to_castle"] as Array[StringName])


func test_bonus_and_ranged_units() -> void:
	var spear := _db.unit(&"gdl_spearman")
	assert_eq(spear.bonuses, {&"cavalry": 7, &"creature": 4} as Dictionary[StringName, int])
	var xbow := _db.unit(&"to_crossbow")
	assert_eq(xbow.damage_type, &"pierce")
	assert_eq(xbow.attack_range, 6)
	assert_eq(xbow.bonuses[&"heavy_cavalry"], 8)
	assert_eq(xbow.bonuses[&"spearman"], 5)
	var bombard := _db.unit(&"to_bombard")
	assert_eq([bombard.attack_range, bombard.min_range], [12, 4])
	assert_eq(bombard.damage_type, &"siege")


func test_znakharka_never_flees_and_heals() -> void:
	var z := _db.unit(&"gdl_znakharka")
	assert_true(z.never_flees)
	assert_eq(z.param(&"heal_radius"), 3)
	assert_eq(z.param(&"limit"), 3)
	assert_eq(z.trained_at, [&"gdl_shrine"] as Array[StringName])


func test_common_buildings_expand_per_faction() -> void:
	for f: StringName in [&"gdl", &"pl", &"to", &"mo"]:
		var b := _db.building(_db.faction(f).building_for(&"barracks"))
		assert_not_null(b, "%s has barracks" % f)
		assert_eq(b.base_id, &"barracks")
		assert_eq(b.hp, 1200)
	assert_eq(_db.building(&"gdl_farm").cost_wood, 40, "ВКЛ подсека is cheaper")
	assert_eq(_db.building(&"gdl_farm").param(&"food_capacity"), 250)
	assert_eq(_db.building(&"to_farm").param(&"food_capacity"), 300)
	assert_eq(_db.building(&"gdl_shrine").power_rate_milli, 600)
	assert_eq(_db.building(&"to_shrine").power_rate_milli, 300)
	assert_eq(_db.building(&"gdl_town_center").pop_provided, 5)
	assert_true(_db.building(&"gdl_stable").trains.has(&"gdl_lit_lance"))


func test_gdl_has_no_three_field_system() -> void:
	assert_false(_db.faction(&"gdl").tech_ids.has(&"t_three_field"))
	assert_true(_db.faction(&"to").tech_ids.has(&"t_three_field"))
	assert_eq(_db.faction(&"pl").tech_cost_permille[&"t_three_field"], 667)


func test_spell_and_age() -> void:
	var mist := _db.spell(&"sp_bog_mist")
	assert_eq(mist.power_cost, 100)
	assert_eq(mist.cooldown_ticks, 1800)
	assert_eq(mist.duration_ticks, 1200)
	assert_eq(mist.casters, [&"gdl_znakharka"] as Array[StringName])
	var age: AgeDef = _db.ages[&"age_khorugv"]
	assert_eq(age.cost_food, 500)
	assert_eq(age.research_ticks, 2600)


func test_prototype_loads_only_prototype() -> void:
	var proto := CatalogDB.load_prototype()
	assert_eq(
		proto.factions.keys(), [&"gdl", &"to", &"pl", &"mo"], "Muscovy only for missions (ВКЛ 5)"
	)
	assert_not_null(proto.unit(&"pl_kmet"), "the Crown plays skirmishes")
	assert_false(proto.unit(&"pl_kopia").campaign_only)
	assert_true(proto.unit(&"pl_hussar").campaign_only, "the hussar only for ВКЛ 8")
	assert_not_null(proto.unit(&"gdl_lit_lance"))
	assert_null(proto.unit(&"gdl_merc_infantry"), "Держава units stay out of the prototype")
	var hook := proto.unit(&"gdl_hakownica")
	assert_true(hook != null and hook.campaign_only, "...the hook gun only for ВКЛ 7")
	assert_true(proto.building(&"gdl_wall").campaign_only, "and the log wall")
	var late := proto.unit(&"gdl_szlachta_lance")
	assert_true(late != null and late.campaign_only, "...but for the missions that need them")
	assert_null(proto.tech(&"t_mo_big_regiment"), "no Muscovite techs")
	assert_not_null(proto.unit(&"pl_kopia"), "the Crown allies of ВКЛ 2 are in")
	var hussar := proto.unit(&"pl_hussar")
	assert_true(hussar != null and hussar.campaign_only, "the Serbian horse of ВКЛ 8 only")
	var merc := proto.unit(&"pl_merc_horse")
	assert_true(merc != null and merc.campaign_only, "the Crown's hired horse only for Корона 5")
	for id: StringName in proto.techs:
		assert_true(proto.techs[id].age <= 2, "%s is within Удел and Хоругвь" % id)
