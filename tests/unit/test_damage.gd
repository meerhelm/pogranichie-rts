extends GutTest
## M4: the damage formula against hand-counted cases (plan, section 5 «Бой», and the catalog's
## «Урон»): max(1, damage − armor) + class bonus, × flank/rear, charge, wavering, siege; rounded
## down once after every multiplier.

var _db: CatalogDB


func before_all() -> void:
	_db = CatalogDB.load_all()


## Damage of one hit by catalog unit `attacker` on catalog unit `target`.
func _hit(
	attacker: StringName,
	target: StringName,
	side: int = Damage.Side.FRONT,
	multipliers: PackedInt32Array = PackedInt32Array()
) -> int:
	var a := _db.unit(attacker)
	var t := _db.unit(target)
	var hit := Damage.Hit.new()
	hit.damage = a.damage
	hit.damage_type = a.damage_type
	hit.bonus = Damage.bonus_against(a.bonuses, t.classes)
	hit.armor_melee = t.armor_melee
	hit.armor_pierce = t.armor_pierce
	hit.side = side
	hit.multipliers = multipliers
	return Damage.compute(hit, _db.rules)


func test_cases_from_the_plan() -> void:
	# Ополченец (4 Б, +6 к коннице) → брат-рыцарь (5/5) спереди: max(1, 4 − 5) + 6 = 7.
	assert_eq(_hit(&"gdl_spearman", &"to_knight_brother"), 7)
	# Арбалетчик (9 С, +8 к тяжёлой коннице) → лёгкий всадник (0/1): 9 − 1 = 8, бонуса нет.
	assert_eq(_hit(&"to_crossbow", &"gdl_light_horse"), 8)
	# Кнехт (5 Б) → ополченец (0/0) в тыл: 5 × 1,5 = 7,5 → 7.
	assert_eq(_hit(&"to_knecht", &"gdl_spearman", Damage.Side.REAR), 7)
	# Брат-рыцарь (14 Б, таран ×2,5) → крестьянин (0/0) после разгона: 35.
	var charge := _db.unit(&"to_knight_brother").param(&"charge_permille")
	assert_eq(charge, 2500)
	assert_eq(_hit(&"to_knight_brother", &"gdl_peasant", 0, PackedInt32Array([charge])), 35)


func test_armor_never_takes_below_one_and_never_cuts_the_bonus() -> void:
	# Крестьянин 3 Б по рыцарю 5/5: max(1, −2) = 1.
	assert_eq(_hit(&"gdl_peasant", &"to_knight_brother"), 1)
	# Арбалетчик по брату-рыцарю: max(1, 9 − 5) + 8 = 12.
	assert_eq(_hit(&"to_crossbow", &"to_knight_brother"), 12)
	# Бонус к коннице есть у каждой конницы: кнехт по полубрату (2/3): (5 − 2) + 6 = 9.
	assert_eq(_hit(&"to_knecht", &"to_halfbrother"), 9)


func test_flank_rear_and_wavering_multiply_then_round_down() -> void:
	# Лёгкий всадник 6 Б по арбалетчику 1/2 с фланга: 5 × 1,25 = 6,25 → 6.
	assert_eq(_hit(&"gdl_light_horse", &"to_crossbow", Damage.Side.FLANK), 6)
	# Колеблющийся ополченец по рыцарю: 7 × 0,8 = 5,6 → 5.
	var waver := PackedInt32Array([_db.rules.waver_damage_permille])
	assert_eq(_hit(&"gdl_spearman", &"to_knight_brother", 0, waver), 5)
	# В тыл и колеблясь: 7 × 1,5 × 0,8 = 8,4 → 8, округление одно, в самом конце.
	assert_eq(_hit(&"gdl_spearman", &"to_knight_brother", Damage.Side.REAR, waver), 8)
	# Литовское копьё (11 Б, ×2) по кнехту (1/1) с фланга после разгона: 10 × 1,25 × 2 = 25.
	var lance := PackedInt32Array([_db.unit(&"gdl_lit_lance").param(&"charge_permille")])
	assert_eq(_hit(&"gdl_lit_lance", &"to_knecht", Damage.Side.FLANK, lance), 25)


func test_firearms_count_half_the_pierce_armor() -> void:
	# Ручничник 16 О по рыцарю 5/5: броня 5 / 2 = 2 → 14; лук по нему же 4 − 5 → 1.
	assert_eq(_db.unit(&"to_handgunner").damage_type, Damage.FIREARM)
	assert_eq(_hit(&"to_handgunner", &"to_knight_brother"), 14)
	# По арбалетчику (броня от стрел 2): 16 − 1 = 15.
	assert_eq(_hit(&"to_handgunner", &"to_crossbow"), 15)


func test_siege_damage_on_units_is_quartered() -> void:
	# Бомбарда 200 Ос по ополченцу (0/0): 200 / 4 = 50; по рыцарю (5 Б-брони): 195 / 4 = 48.
	assert_eq(_db.unit(&"to_bombard").damage_type, Damage.SIEGE)
	assert_eq(_hit(&"to_bombard", &"gdl_spearman"), 50)
	assert_eq(_hit(&"to_bombard", &"to_knight_brother"), 48)


func test_side_of_a_hit() -> void:
	var one := Fixed.ONE
	# The target faces east (+x).
	assert_eq(Damage.side_of(one, 0, one, 0), Damage.Side.FRONT)
	assert_eq(Damage.side_of(one, one, one, 0), Damage.Side.FRONT, "45° still counts as front")
	assert_eq(Damage.side_of(0, one, one, 0), Damage.Side.FLANK)
	assert_eq(Damage.side_of(0, -one, one, 0), Damage.Side.FLANK)
	assert_eq(Damage.side_of(-one, one, one, 0), Damage.Side.FLANK, "135° is still the flank")
	assert_eq(Damage.side_of(-one, one / 2, one, 0), Damage.Side.REAR)
	assert_eq(Damage.side_of(-one, 0, one, 0), Damage.Side.REAR)
