extends CombatTest
## M4: faction mechanics in combat: сулица and «Литовский отход» of the GDL light horse,
## the forest archer hidden in the forest, the dismounting Prussian rider, the Samogitian in the
## forest.

# --- faction mechanics -----------------------------------------------------------------------


func test_javelin_is_thrown_within_three_cells_every_12_seconds() -> void:
	var sim := _open()
	var horse := _spawn(sim, 1, LIGHT_HORSE, 10.5, 10.5)
	var xbow := _spawn(sim, 2, CROSSBOW, 16.5, 10.5)
	_passive(sim, xbow)
	sim.enqueue(SimCommand.attack(sim.tick, 1, _ids(horse), xbow))
	var thrown_at := -1
	for i in 100:
		sim.step()
		if sim.combat.shots.size() > 0 and thrown_at < 0:
			thrown_at = sim.tick
			var d := Fixed.distance(
				sim.combat.shots.x[0], sim.combat.shots.y[0], _at(16.5), _at(10.5)
			)
			assert_lte(d, Fixed.from_cells(3))
			assert_gt(d, Fixed.from_cells(2), "thrown on the way in, before the melee")
	assert_gt(thrown_at, 0)
	assert_eq(sim.entities.javelin_cd[horse - 1] > 0, true)
	var cd := _db.unit(LIGHT_HORSE).param(&"javelin_cooldown_ticks")
	assert_eq(cd, 240)
	# Сулица 6 С по арбалетчику (броня от стрел 2): 4, плюс удары копьём.
	var hit := sim.combat._hit_from(horse - 1, xbow - 1, 6, Damage.PIERCE)
	hit.bonus = 0
	hit.side = Damage.Side.FRONT
	assert_eq(Damage.compute(hit, _rules), 4)


func test_lithuanian_retreat_and_turn() -> void:
	var sim := _open(60, 20)
	var horse := _spawn(sim, 1, LIGHT_HORSE, 30.5, 10.5)
	sim.enqueue(SimCommand.rally(sim.tick, 1, _at(2.5), _at(10.5)))
	var brother := _spawn(sim, 2, HALFBROTHER, 31.4, 10.5)
	sim.run(20)
	assert_eq(sim.entities.target[brother - 1], horse, "they fight")
	var morale_before := sim.entities.morale[horse - 1]
	sim.enqueue(SimCommand.order(sim.tick, 1, SimCommand.Kind.RETREAT, _ids(horse)))
	sim.step()
	assert_eq(sim.entities.intents[horse - 1], EntityStore.Intent.RETREAT)
	sim.combat._apply_hit(brother, 2, horse - 1, 20, Damage.Side.REAR, Damage.MELEE, false)
	assert_eq(sim.entities.morale[horse - 1], morale_before, "no morale lost in the retreat")
	var x0 := sim.entities.pos_x[horse - 1]
	sim.run(20)
	var per_tick := (x0 - sim.entities.pos_x[horse - 1]) / 20
	var normal := Fixed.speed_per_tick(_db.unit(LIGHT_HORSE).speed_milli)
	assert_almost_eq(per_tick, normal * 13 / 10, 2, "30% faster")
	sim.run(100)
	assert_almost_eq(
		x0 - sim.entities.pos_x[horse - 1],
		Fixed.from_cells(_rules.retreat_cells),
		Fixed.ONE,
		"8 cells toward the rally point"
	)
	assert_gt(sim.entities.disorder[brother - 1], 0, "the pursuer lost order")
	assert_eq(sim.combat._armor_melee(brother - 1), 2 - 2)
	# A second retreat waits for the cooldown.
	sim.enqueue(SimCommand.order(sim.tick, 1, SimCommand.Kind.RETREAT, _ids(horse)))
	sim.step()
	assert_ne(sim.entities.intents[horse - 1], EntityStore.Intent.RETREAT)
	# «Разворот»: +3 damage and ×1,25 on the next hit; one turn per retreat.
	sim.enqueue(SimCommand.order(sim.tick, 1, SimCommand.Kind.TURN, _ids(horse)))
	sim.step()
	assert_eq(sim.entities.turn_bonus[horse - 1], 1)
	assert_eq(sim.entities.target[horse - 1], brother)
	var hit := sim.combat._hit_from(horse - 1, brother - 1, 6, Damage.MELEE)
	assert_eq(hit.damage, 9)


func test_turn_bonus_on_the_hit() -> void:
	var sim := _open()
	var horse := _spawn(sim, 1, LIGHT_HORSE, 10.5, 10.5)
	var knecht := _spawn(sim, 2, KNECHT, 11.4, 10.5)
	_passive(sim, knecht)
	_face(sim, knecht, -Fixed.ONE, 0)
	sim.entities.turn_ticks[horse - 1] = 50
	sim.enqueue(SimCommand.order(sim.tick, 1, SimCommand.Kind.TURN, _ids(horse)))
	# Лёгкий всадник 5 + 3 по кнехту 1/1 спереди: 7 × 1,25 = 8,75 → 8.
	assert_eq(_first_damage(sim, knecht), 8)
	assert_eq(sim.entities.turn_bonus[horse - 1], 0)
	assert_eq(sim.entities.turn_ticks[horse - 1], 0, "used up")


func test_forest_archer_is_hidden_in_the_forest_until_it_shoots() -> void:
	var rows := PackedStringArray()
	for y in 20:
		rows.append(".".repeat(10) + "fff" + ".".repeat(27))
	var sim := _on_map("\n".join(rows))
	var archer := _spawn(sim, 1, &"gdl_forest_archer", 11.5, 10.5)
	_passive(sim, archer)
	var knecht := _spawn(sim, 2, KNECHT, 16.5, 10.5)
	sim.run(30)
	assert_true(sim.combat.is_hidden(archer))
	assert_eq(sim.entities.target[knecht - 1], EntityStore.NO_ID, "does not see it at 5 cells")
	# From the forest the archer shoots 5 + 1 cells.
	assert_eq(sim.combat._reach(archer - 1), Fixed.from_cells(6))
	sim.enqueue(SimCommand.attack(sim.tick, 1, _ids(archer), knecht))
	sim.run(15)
	assert_false(sim.combat.is_hidden(archer), "seen after the shot")
	assert_eq(sim.entities.target[knecht - 1], archer, "and attacked")


func test_samogitian_gets_armor_in_the_forest() -> void:
	var sim := _on_map("f..\n...")
	var in_forest := _spawn(sim, 1, &"gdl_samogitian", 0.5, 0.5)
	var outside := _spawn(sim, 1, &"gdl_samogitian", 2.5, 1.5)
	assert_eq(sim.combat._armor_melee(in_forest - 1), 2)
	assert_eq(sim.combat._armor_pierce(in_forest - 1), 2)
	assert_eq(sim.combat._armor_melee(outside - 1), 1)


func test_prussian_rider_dismounts() -> void:
	var sim := _open()
	var rider := _spawn(sim, 2, &"to_prussian_rider", 10.5, 10.5)
	var spear := _spawn(sim, 1, SPEARMAN, 20.5, 10.5)
	var slot := rider - 1
	assert_eq(sim.combat._armor_melee(slot), 0)
	var mounted := sim.combat._hit_from(spear - 1, slot, 4, Damage.MELEE)
	assert_eq(mounted.bonus, 7, "+7 к коннице")
	sim.enqueue(SimCommand.order(sim.tick, 2, SimCommand.Kind.DISMOUNT, _ids(rider)))
	sim.step()
	assert_eq(sim.entities.dismounted[slot], 1)
	assert_eq(sim.combat._armor_melee(slot), 1)
	assert_eq(sim.combat._armor_pierce(slot), 2)
	assert_eq(sim.entities.speed[slot], Fixed.speed_per_tick(_rules.dismount_speed_milli))
	assert_eq(sim.entities.move_class[slot], NavGrid.MoveClass.FOOT)
	var dismounted := sim.combat._hit_from(spear - 1, slot, 4, Damage.MELEE)
	assert_eq(dismounted.bonus, 0, "on foot it is infantry")
	sim.enqueue(SimCommand.order(sim.tick, 2, SimCommand.Kind.DISMOUNT, _ids(rider)))
	sim.step()
	assert_eq(sim.entities.move_class[slot], NavGrid.MoveClass.CAVALRY, "and mounts again")
