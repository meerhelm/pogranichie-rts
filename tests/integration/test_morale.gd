extends CombatTest
## M4: morale (catalog «Боевой дух»): losses, wavering, flight to the rally point, units that
## never flee, hero aura and close order, recovery out of combat.

# --- morale ----------------------------------------------------------------------------------


func test_losing_thirty_percent_hp_costs_three_morale() -> void:
	var sim := _open()
	var knight := _spawn(sim, 2, KNIGHT, 10.5, 10.5)
	_passive(sim, knight)
	sim.combat._apply_hit(0, 1, knight - 1, 60, Damage.Side.FRONT, Damage.MELEE, false)
	assert_eq(_morale(sim, knight), 100 - 3, "60 of 200 HP")
	sim.combat._apply_hit(0, 1, knight - 1, 9, Damage.Side.FRONT, Damage.MELEE, false)
	assert_eq(_morale(sim, knight), 97, "34.5% lost: still three tenths")


func test_wavering_at_25_takes_a_fifth_of_the_damage() -> void:
	var sim := _open()
	var spear := _spawn(sim, 1, SPEARMAN, 10.5, 10.5)
	var knight := _spawn(sim, 2, KNIGHT, 11.4, 10.5)
	_face(sim, knight, -Fixed.ONE, 0)
	sim.entities.morale[spear - 1] = 26 * CombatSystem.MORALE_SCALE
	assert_false(sim.combat.wavering(spear - 1))
	sim.entities.morale[spear - 1] = 25 * CombatSystem.MORALE_SCALE
	assert_true(sim.combat.wavering(spear - 1))
	var hit := sim.combat._hit_from(spear - 1, knight - 1, 4, Damage.MELEE)
	assert_eq(Array(hit.multipliers), [800])
	assert_eq(Damage.compute(hit, _rules), 6, "8 × 0,8")


func test_at_zero_a_unit_flees_to_the_rally_point_and_ignores_orders() -> void:
	var sim := _open(60, 20)
	var spear := _spawn(sim, 1, SPEARMAN, 30.5, 10.5)
	sim.enqueue(SimCommand.rally(sim.tick, 1, _at(5.5), _at(10.5)))
	sim.step()
	sim.entities.morale[spear - 1] = 5 * CombatSystem.MORALE_SCALE
	sim.combat._apply_hit(0, 2, spear - 1, 1, Damage.Side.REAR, Damage.MELEE, false)
	assert_eq(sim.entities.intents[spear - 1], EntityStore.Intent.FLEE)
	sim.enqueue(SimCommand.move(sim.tick, 1, _ids(spear), _at(50.5), _at(10.5)))
	sim.run(200)
	assert_lt(
		sim.entities.pos_x[spear - 1], _at(30.5), "runs to the rally point, not where it was sent"
	)
	sim.run(_rules.flee_ticks - 200 + 2)
	assert_eq(sim.entities.intents[spear - 1], EntityStore.Intent.NONE, "20 s later")
	var x := sim.entities.pos_x[spear - 1]
	sim.enqueue(SimCommand.move(sim.tick, 1, _ids(spear), _at(50.5), _at(10.5)))
	sim.run(20)
	assert_gt(sim.entities.pos_x[spear - 1], x, "obeys again")


func test_spiritual_units_never_flee() -> void:
	var sim := _open()
	var healer := _spawn(sim, 1, &"gdl_znakharka", 10.5, 10.5)
	for i in 3:
		sim.combat._apply_hit(0, 2, healer - 1, 5, Damage.Side.REAR, Damage.MELEE, false)
	assert_eq(sim.entities.intents[healer - 1], EntityStore.Intent.NONE)
	assert_false(sim.combat.wavering(healer - 1))


func test_hero_aura_gives_15_only_within_8_cells() -> void:
	var db := CatalogDB.load_all()
	var hero := db.unit(KNIGHT).duplicate() as UnitDef
	hero.id = &"hero_test"
	hero.classes = [&"hero"]
	db.units[hero.id] = hero
	var sim := Simulation.new(1, db, 40, 20)
	var near := _spawn(sim, 1, SPEARMAN, 17.6, 10.5)
	var far := _spawn(sim, 1, SPEARMAN, 1.5, 10.5)
	_spawn(sim, 1, hero.id, 10.5, 10.5)
	sim.step()
	assert_eq(sim.combat.effective_morale(near - 1), 40 + 15, "7.1 cells from the hero")
	assert_eq(sim.combat.effective_morale(far - 1), 40, "9 cells away")
	assert_eq(sim.entities.morale[sim.entities.next_id - 2], 0, "the hero has no morale to lose")


func test_infantry_in_close_order_gets_5() -> void:
	var sim := _open()
	var block := PackedInt32Array()
	for i in 4:
		block.append(_spawn(sim, 1, SPEARMAN, 10.5 + i % 2, 10.5 + i / 2))
	var pair := _spawn(sim, 1, SPEARMAN, 30.5, 10.5)
	_spawn(sim, 1, SPEARMAN, 31.5, 10.5)
	sim.step()
	for id in block:
		assert_eq(sim.combat.effective_morale(id - 1), 45, "three neighbours within 1.5 cells")
	assert_eq(sim.combat.effective_morale(pair - 1), 40, "one neighbour is not close order")


func test_morale_comes_back_two_a_second_out_of_combat() -> void:
	var sim := _open()
	var spear := _spawn(sim, 1, SPEARMAN, 10.5, 10.5)
	sim.combat._apply_hit(0, 2, spear - 1, 1, Damage.Side.FLANK, Damage.MELEE, false)
	var low := sim.entities.morale[spear - 1]
	assert_eq(low, 30 * CombatSystem.MORALE_SCALE)
	sim.run(_rules.out_of_combat_ticks - 1)
	assert_eq(sim.entities.morale[spear - 1], low, "still in combat")
	sim.run(1 + Fixed.TICKS_PER_SECOND)
	assert_eq(sim.entities.morale[spear - 1], low + 2 * CombatSystem.MORALE_SCALE)
	sim.run(Fixed.TICKS_PER_SECOND * 10)
	assert_eq(_morale(sim, spear), 40, "never above the starting morale")


func test_a_neighbour_dying_costs_ten() -> void:
	var sim := _open()
	var a := _spawn(sim, 1, SPEARMAN, 10.5, 10.5)
	var b := _spawn(sim, 1, SPEARMAN, 12.5, 10.5)
	var c := _spawn(sim, 1, SPEARMAN, 20.5, 10.5)
	sim.step()
	sim.combat._apply_hit(0, 2, a - 1, 100, Damage.Side.FRONT, Damage.MELEE, false)
	sim.step()
	assert_false(sim.entities.is_alive(a))
	assert_eq(_morale(sim, b), 30, "2 cells away")
	assert_eq(_morale(sim, c), 40, "10 cells away")
