extends CombatTest
## M4: fights in the running simulation: charge, flank and rear, projectiles, stances, pursuit,
## and whole battles in the balance arena.

# --- strikes -------------------------------------------------------------------------------


func test_charge_after_a_run_up_and_none_without() -> void:
	# Литовское копьё 2/2, 140 HP, стоит и смотрит на рыцаря: (14 − 2) × 2,5 = 30.
	var sim := _open()
	var lance := _spawn(sim, 1, LANCE, 10.5, 10.5)
	sim.enqueue(SimCommand.set_stance(sim.tick, 1, _ids(lance), EntityStore.Stance.STAND))
	_face(sim, lance, Fixed.ONE, 0)
	var knight := _spawn(sim, 2, KNIGHT, 20.5, 10.5)
	sim.enqueue(SimCommand.attack(sim.tick, 2, _ids(knight), lance))
	assert_eq(_first_damage(sim, lance), 30, "first hit after 9 cells of run-up")
	assert_eq(_first_damage(sim, lance), 12, "the next hit has no run-up")

	var close := _open()
	var lance2 := _spawn(close, 1, LANCE, 10.5, 10.5)
	close.enqueue(SimCommand.set_stance(close.tick, 1, _ids(lance2), EntityStore.Stance.STAND))
	_face(close, lance2, Fixed.ONE, 0)
	var knight2 := _spawn(close, 2, KNIGHT, 11.4, 10.5)
	close.enqueue(SimCommand.attack(close.tick, 2, _ids(knight2), lance2))
	assert_eq(_first_damage(close, lance2), 12, "no charge from a standstill")


func test_a_hit_from_behind_costs_damage_and_morale() -> void:
	# Ополченец смотрит на восток, кнехт бьёт с запада: 5 × 1,5 = 7; дух 40 − 1 (17% HP) − 20.
	var sim := _open()
	var spear := _spawn(sim, 1, SPEARMAN, 10.5, 10.5)
	_passive(sim, spear)
	_face(sim, spear, Fixed.ONE, 0)
	var knecht := _spawn(sim, 2, KNECHT, 9.6, 10.5)
	sim.enqueue(SimCommand.attack(sim.tick, 2, _ids(knecht), spear))
	assert_eq(_first_damage(sim, spear), 7)
	assert_eq(_morale(sim, spear), 40 - 1 - 20)


func test_flank_hit() -> void:
	var sim := _open()
	var spear := _spawn(sim, 1, SPEARMAN, 10.5, 10.5)
	_passive(sim, spear)
	_face(sim, spear, Fixed.ONE, 0)
	var knecht := _spawn(sim, 2, KNECHT, 10.5, 11.4)
	sim.enqueue(SimCommand.attack(sim.tick, 2, _ids(knecht), spear))
	# 5 × 1,25 = 6,25 → 6; дух 40 − 1 − 10.
	assert_eq(_first_damage(sim, spear), 6)
	assert_eq(_morale(sim, spear), 40 - 1 - 10)


func test_projectile_flies_then_hits() -> void:
	# Арбалетчик по лёгкому всаднику с 5 клеток: болт летит ceil(5 / 8 × 20) = 13 тиков, 9 − 1 = 8.
	var sim := _open()
	var horse := _spawn(sim, 1, LIGHT_HORSE, 15.5, 10.5)
	_passive(sim, horse)
	_face(sim, horse, -Fixed.ONE, 0)
	var xbow := _spawn(sim, 2, CROSSBOW, 10.5, 10.5)
	sim.enqueue(SimCommand.attack(sim.tick, 2, _ids(xbow), horse))
	sim.step()
	assert_eq(sim.combat.shots.size(), 1, "the bolt is in the air")
	var flight := sim.combat.shots.lands[0] - sim.combat.shots.launched[0]
	assert_eq(flight, 13)
	assert_eq(_first_damage(sim, horse), 8)
	assert_eq(sim.combat.shots.size(), 0)


func test_shots_at_a_target_in_the_forest_miss_a_quarter() -> void:
	# Зубр в лесу, вокруг 60 арбалетчиков стреляют залпом: промахов около 25%.
	var rows := PackedStringArray()
	for y in 24:
		rows.append(".".repeat(11) + ("f" if y == 12 else ".") + ".".repeat(12))
	var sim := _on_map("\n".join(rows))
	var bison := _spawn(sim, 0, &"nt_bison", 11.5, 12.5)
	var xbows := PackedInt32Array()
	for i in 60:
		var a := TAU * i / 60.0
		var x := _at(11.5 + 4.5 * cos(a))
		var y := _at(12.5 + 4.5 * sin(a))
		sim.enqueue(SimCommand.spawn(sim.tick, 2, CROSSBOW, x, y))
		xbows.append(bison + 1 + i)
	sim.step()
	sim.enqueue(SimCommand.attack(sim.tick, 2, xbows, bison))
	sim.step()
	var misses := 0
	for f in sim.combat.shots.flags:
		misses += 1 if f & Projectiles.MISS else 0
	assert_eq(sim.combat.shots.size(), 60)
	assert_between(misses, 8, 22, "about 15 of 60")


func test_shooting_from_a_hill_reaches_one_cell_farther() -> void:
	var sim := _on_map("h" + ".".repeat(19) + "\n" + ".".repeat(20))
	var on_hill := _spawn(sim, 2, CROSSBOW, 0.5, 0.5)
	var below := _spawn(sim, 2, CROSSBOW, 0.5, 1.5)
	for id: int in [on_hill, below]:
		sim.enqueue(SimCommand.set_stance(sim.tick, 2, _ids(id), EntityStore.Stance.STAND))
	var target := _spawn(sim, 1, PEASANT, 7.3, 0.9)
	sim.step()
	var shooters := {}
	for i in 30:
		sim.step()
		for s in sim.combat.shots.from:
			shooters[s] = true
	assert_true(shooters.has(on_hill), "6 + 1 cells from the hill")
	assert_false(shooters.has(below), "6.8 cells is out of range on flat ground")
	assert_true(sim.entities.is_alive(target))


# --- stances and pursuit ---------------------------------------------------------------------


func test_aggressive_units_attack_what_they_see() -> void:
	var sim := _open()
	var spear := _spawn(sim, 1, SPEARMAN, 10.5, 10.5)
	var peasant := _spawn(sim, 2, &"to_peasant", 15.5, 10.5)
	sim.run(400)
	assert_false(sim.entities.is_alive(peasant), "5 cells is within sight 6")
	assert_true(sim.entities.is_alive(spear))


func test_defensive_units_follow_a_little_and_come_back() -> void:
	var sim := _open(60, 20)
	var spear := _spawn(sim, 1, SPEARMAN, 10.5, 10.5)
	sim.enqueue(SimCommand.set_stance(sim.tick, 1, _ids(spear), EntityStore.Stance.DEFENSIVE))
	var horse := _spawn(sim, 2, LIGHT_HORSE, 15.5, 10.5)
	_passive(sim, horse)
	sim.enqueue(SimCommand.move(sim.tick + 30, 2, _ids(horse), _at(55.5), _at(10.5)))
	var farthest := 0
	for i in 600:
		sim.step()
		var d := Fixed.distance(sim.entities.pos_x[spear - 1], 0, _at(10.5), 0)
		farthest = maxi(farthest, d)
	assert_gt(farthest, Fixed.ONE, "went after it")
	assert_lt(farthest, Fixed.from_cells(_rules.defensive_leash_cells + 1))
	assert_lt(Fixed.distance(sim.entities.pos_x[spear - 1], 0, _at(10.5), 0), Fixed.ONE)


func test_stand_ground_never_moves() -> void:
	var sim := _open()
	var xbow := _spawn(sim, 2, CROSSBOW, 10.5, 10.5)
	sim.enqueue(SimCommand.set_stance(sim.tick, 2, _ids(xbow), EntityStore.Stance.STAND))
	var horse := _spawn(sim, 1, LIGHT_HORSE, 18.5, 10.5)
	_passive(sim, horse)
	sim.run(100)
	assert_eq(sim.entities.pos_x[xbow - 1], _at(10.5), "8 cells: out of range, stays")
	assert_eq(sim.combat.shots.size(), 0)
	sim.enqueue(SimCommand.move(sim.tick, 1, _ids(horse), _at(15.5), _at(10.5)))
	var shot := false
	for i in 200:
		sim.step()
		shot = shot or sim.combat.shots.size() > 0
	assert_true(shot, "shoots once it is in range")
	assert_eq(sim.entities.pos_x[xbow - 1], _at(10.5))


func test_pursuit_of_a_fleeing_target_ends_after_pursuit_cells() -> void:
	var sim := _open(80, 20)
	var hunter := _spawn(sim, 1, &"gdl_light_horse", 40.5, 10.5)
	var prey := _spawn(sim, 2, SPEARMAN, 41.4, 10.5)
	_passive(sim, prey)
	sim.enqueue(SimCommand.rally(sim.tick, 2, _at(78.5), _at(10.5)))
	sim.enqueue(SimCommand.attack(sim.tick, 1, _ids(hunter), prey))
	sim.step()
	sim.entities.morale[prey - 1] = 1 * CombatSystem.MORALE_SCALE
	sim.run(60)
	assert_eq(sim.entities.intents[prey - 1], EntityStore.Intent.FLEE)
	# The rider is faster: it would ride the prey down, but an auto-target is let go after
	# pursuit_cells; an ordered one is followed. Make it automatic and watch it stop.
	sim.entities.target_kind[hunter - 1] = EntityStore.TargetKind.AUTO
	var start := sim.entities.pos_x[hunter - 1]
	sim.entities.chase_x[hunter - 1] = start
	sim.run(400)
	var went := sim.entities.pos_x[hunter - 1] - start
	assert_lt(went, Fixed.from_cells(_rules.pursuit_cells + 2))
	assert_eq(sim.entities.target[hunter - 1], EntityStore.NO_ID)


func test_knight_brothers_do_not_pursue() -> void:
	var sim := _open(80, 20)
	var knight := _spawn(sim, 2, KNIGHT, 40.5, 10.5)
	var prey := _spawn(sim, 1, SPEARMAN, 41.4, 10.5)
	_passive(sim, prey)
	sim.run(10)
	assert_eq(sim.entities.target[knight - 1], prey, "picked the spearman itself")
	sim.entities.morale[prey - 1] = 0
	sim.combat._flee(prey - 1)
	sim.run(2)
	assert_eq(sim.entities.target[knight - 1], EntityStore.NO_ID)


# --- whole battles ---------------------------------------------------------------------------


func test_a_battle_ends_and_is_the_same_every_time() -> void:
	var arena := BalanceArena.new(_db)
	var a := arena.battle(3, SPEARMAN, KNIGHT, false, false)
	var b := arena.battle(3, SPEARMAN, KNIGHT, false, false)
	assert_ne(a.winner, 0, "someone wins within 3 minutes")
	assert_eq([a.winner, a.ticks, Array(a.hp_left)], [b.winner, b.ticks, Array(b.hp_left)])


func test_arena_report_row() -> void:
	var arena := BalanceArena.new(_db)
	assert_eq(arena.army_size(SPEARMAN), 24, "1200 / 50")
	assert_eq(arena.army_size(KNIGHT), 3, "120 + 90 × 1,5 + 55 × 2 = 365")
	var row := arena.run_pair(BalanceArena.DEFAULT_PAIRS[0], 2)
	assert_eq(row.split(",").size(), BalanceArena.CSV_HEADER.split(",").size())
	assert_string_starts_with(row, "crossbow_vs_spear,to_crossbow,gdl_spearman,open,-,2,12,24,")
