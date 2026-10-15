extends MagicTest
## M7: spells. Costs, cooldowns, ages and range; «Болотный туман» hides its side's units until
## they attack; «Экзорцизм» lifts it; «Реликвия в строю» holds morale; знахарки heal.

# --- spells ----------------------------------------------------------------------------------


func test_cast_needs_power_and_then_cools_down() -> void:
	var sim := _world()
	var z := _spawn(sim, 1, ZNAKHARKA, 5.5, 5.5)
	var m := sim.magic
	assert_eq(m.can_cast(1, z, MIST), MagicSystem.Cast.POWER)
	assert_eq(m.can_cast(1, z, EXORCISM), MagicSystem.Cast.NOT_CASTER)
	assert_eq(m.can_cast(1, z, &"sp_perkunas"), MagicSystem.Cast.NOT_READY, "no effect yet")
	_give_power(sim, 1, 150)
	assert_eq(m.can_cast(1, z, MIST), MagicSystem.Cast.OK)
	sim.enqueue(SimCommand.cast(sim.tick, 1, _ids(z), MIST, _at(8.5), _at(5.5)))
	sim.step()
	assert_eq(sim.economy.player(1).power_points(), 50, "100 Сила paid")
	assert_eq(m.fx_ids.size(), 1)
	assert_eq(m.can_cast(1, z, MIST), MagicSystem.Cast.COOLDOWN)
	assert_eq(m.cooldown_ticks(z, MIST), _db.spell(MIST).cooldown_ticks - 1)
	_give_power(sim, 1, 200)
	sim.run(_db.spell(MIST).cooldown_ticks)
	assert_eq(m.can_cast(1, z, MIST), MagicSystem.Cast.OK, "after 90 s")
	assert_eq(m.fx_ids.size(), 0, "the mist lasted 60 s")


func test_order_spells_need_the_second_age() -> void:
	var sim := _world()
	var priest := _spawn(sim, 2, PRIEST, 5.5, 5.5)
	_give_power(sim, 2, 300)
	assert_eq(sim.magic.can_cast(2, priest, RELIC), MagicSystem.Cast.AGE)
	sim.economy.player(2).age = 2
	assert_eq(sim.magic.can_cast(2, priest, RELIC), MagicSystem.Cast.OK)
	assert_eq(
		sim.magic.can_cast(2, priest, &"sp_consecration"), MagicSystem.Cast.PASSIVE, "always on"
	)


func test_caster_walks_into_range_first() -> void:
	var sim := _world(&"pp_spring", 60, 20)
	var z := _spawn(sim, 1, ZNAKHARKA, 5.5, 10.5)
	_give_power(sim, 1, 100)
	var far := 5.5 + _db.magic.cast_range + 10
	sim.enqueue(SimCommand.cast(sim.tick, 1, _ids(z), MIST, _at(far), _at(10.5)))
	sim.step()
	assert_eq(sim.magic.fx_ids.size(), 0, "out of range: walks first")
	sim.run(600)
	assert_eq(sim.magic.fx_ids.size(), 1, "cast once in range")
	var x := Fixed.to_cells(sim.entities.pos_x[z - 1])
	assert_lt(x, int(far) - _db.magic.cast_range + 2, "stopped at the edge of its range")
	assert_eq(Fixed.to_cells(sim.magic.fx_x[0]), int(far), "landed where it was aimed")


func test_move_order_calls_the_cast_off() -> void:
	var sim := _world(&"pp_spring", 60, 20)
	var z := _spawn(sim, 1, ZNAKHARKA, 5.5, 10.5)
	_give_power(sim, 1, 100)
	sim.enqueue(SimCommand.cast(sim.tick, 1, _ids(z), MIST, _at(40.5), _at(10.5)))
	sim.step()
	sim.enqueue(SimCommand.move(sim.tick, 1, _ids(z), _at(5.5), _at(5.5)))
	sim.run(600)
	assert_eq(sim.magic.fx_ids.size(), 0)
	assert_eq(sim.economy.player(1).power_points(), 100, "nothing paid")


func test_one_caster_of_a_group_casts() -> void:
	var sim := _world()
	var a := _spawn(sim, 1, ZNAKHARKA, 5.5, 5.5)
	var b := _spawn(sim, 1, ZNAKHARKA, 8.5, 5.5)
	_give_power(sim, 1, 300)
	var both := PackedInt32Array([a, b])
	sim.enqueue(SimCommand.cast(sim.tick, 1, both, MIST, _at(9.5), _at(5.5)))
	sim.step()
	assert_eq(sim.economy.player(1).power_points(), 200, "paid once")
	assert_eq(sim.magic.cooldown_ticks(a, MIST), 0, "the farther one did not cast")
	assert_gt(sim.magic.cooldown_ticks(b, MIST), 0, "the nearer one did")


func test_alka_recharges_znakharki_faster() -> void:
	var sim := _world()
	_place(sim, 1, ALKA, SITE.x, SITE.y)
	var near := _spawn(sim, 1, ZNAKHARKA, 9.5, 12.5)
	var far := _spawn(sim, 1, ZNAKHARKA, 30.5, 25.5)
	_give_power(sim, 1, 300)
	sim.enqueue(SimCommand.cast(sim.tick, 1, _ids(near), MIST, _at(9.5), _at(14.5)))
	sim.enqueue(SimCommand.cast(sim.tick, 1, _ids(far), MIST, _at(30.5), _at(25.5)))
	sim.step()
	sim.run(1000)
	var cd := _db.spell(MIST).cooldown_ticks
	assert_eq(sim.magic.cooldown_ticks(far, MIST), cd - 1001)
	# 1,2 ticks of cooldown a tick near the alka.
	assert_eq(sim.magic.cooldown_ticks(near, MIST), cd - 1201)


# --- «Болотный туман» -------------------------------------------------------------------------


func test_mist_hides_units_until_they_attack() -> void:
	var sim := _world(&"pp_spring", 40, 20)
	var z := _spawn(sim, 1, ZNAKHARKA, 9.5, 11.5)
	_passive(sim, z)
	var archer := _spawn(sim, 1, ARCHER, 10.5, 10.5)
	_passive(sim, archer)
	var watcher := _spawn(sim, 2, KNECHT, 14.5, 10.5)
	_passive(sim, watcher)
	var cell := sim.nav.cell_at(10, 10)
	assert_true(sim.vision.sees_unit(2, archer), "4 cells away on open ground: seen")
	_give_power(sim, 1, 100)
	sim.enqueue(SimCommand.cast(sim.tick, 1, _ids(z), MIST, _at(10.5), _at(10.5)))
	sim.step()
	assert_true(sim.vision.sees_cell(2, cell), "the ground is in sight")
	assert_false(sim.vision.sees_unit(2, archer), "hidden in the mist")
	assert_true(sim.vision.sees_unit(1, watcher), "the mist does not hide the other side")
	sim.enqueue(SimCommand.attack(sim.tick, 1, _ids(archer), watcher))
	for i in 120:
		sim.step()
		if sim.entities.last_attack[archer - 1] >= 0:
			break
	assert_true(sim.entities.last_attack[archer - 1] >= 0, "the archer shot")
	assert_true(sim.vision.sees_unit(2, archer), "seen after its first attack")
	assert_false(sim.vision.sees_unit(2, z), "the znakharka still hidden")
	sim.enqueue(SimCommand.move(sim.tick, 2, _ids(watcher), _at(11.5), _at(11.5)))
	sim.run(80)
	assert_true(sim.vision.sees_unit(2, z), "within 2 cells: seen")


func test_mist_hides_buildings_and_lifts_after_a_minute() -> void:
	var sim := _world(&"pp_spring", 40, 20)
	var b := _place(sim, 1, &"gdl_house", 4, 9)
	var z := _spawn(sim, 1, ZNAKHARKA, 4.5, 12.5)
	_passive(sim, z)
	var watcher := _spawn(sim, 2, KNECHT, 9.5, 10.5)
	_passive(sim, watcher)
	assert_true(sim.vision.sees_building(2, b))
	_give_power(sim, 1, 100)
	sim.enqueue(SimCommand.cast(sim.tick, 1, _ids(z), MIST, _at(4.5), _at(10.5)))
	sim.step()
	assert_false(sim.vision.sees_building(2, b))
	sim.run(_db.spell(MIST).duration_ticks)
	assert_true(sim.vision.sees_building(2, b), "the mist is gone")
	assert_true(sim.vision.sees_unit(2, z))


# --- «Экзорцизм», «Реликвия в строю» ------------------------------------------------------------


func test_exorcism_lifts_the_enemy_mist() -> void:
	var sim := _world(&"pp_spring", 40, 20)
	var z := _spawn(sim, 1, ZNAKHARKA, 6.5, 10.5)
	_passive(sim, z)
	var priest := _spawn(sim, 2, PRIEST, 11.5, 10.5)
	_passive(sim, priest)
	_give_power(sim, 1, 100)
	_give_power(sim, 2, 100)
	sim.economy.player(2).age = 2
	sim.enqueue(SimCommand.cast(sim.tick, 1, _ids(z), MIST, _at(6.5), _at(10.5)))
	sim.step()
	assert_true(sim.vision.sees_cell(2, sim.nav.cell_at(6, 10)))
	assert_false(sim.vision.sees_unit(2, z))
	sim.enqueue(SimCommand.cast(sim.tick, 2, _ids(priest), EXORCISM, _at(11.5), _at(10.5)))
	sim.step()
	assert_eq(sim.magic.fx_ids.size(), 0, "the mist touched the exorcism's circle")
	assert_true(sim.magic.mist.is_empty())
	sim.run(10)
	assert_true(sim.vision.sees_unit(2, z), "seen again")


func test_exorcism_spares_own_effects_and_reaches_farther_with_reliquary() -> void:
	var sim := _world(&"pp_spring", 60, 20)
	var priest := _spawn(sim, 2, PRIEST, 10.5, 10.5)
	_give_power(sim, 2, 300)
	var state := sim.economy.player(2)
	state.age = 2
	var exorcism := _db.spell(EXORCISM)
	assert_eq(sim.magic.radius_of(2, exorcism), 5)
	sim.enqueue(SimCommand.cast(sim.tick, 2, _ids(priest), RELIC, 0, 0))
	sim.step()
	sim.enqueue(SimCommand.cast(sim.tick, 2, _ids(priest), EXORCISM, _at(10.5), _at(10.5)))
	sim.step()
	assert_eq(sim.magic.fx_ids.size(), 1, "own relic stays")
	state.unit_mods[&"sp_exorcism.radius"] = 2
	assert_eq(sim.magic.radius_of(2, exorcism), 7, "«Реликварий»: radius 7")


func test_relic_holds_own_morale_and_shakes_enemies() -> void:
	var sim := _world(&"pp_spring", 40, 20)
	var priest := _spawn(sim, 2, PRIEST, 10.5, 10.5)
	var knecht := _spawn(sim, 2, KNECHT, 12.5, 10.5)
	_passive(sim, knecht)
	var enemy := _spawn(sim, 1, SPEARMAN, 16.5, 10.5)
	_passive(sim, enemy)
	var outside := _spawn(sim, 1, SPEARMAN, 30.5, 10.5)
	_passive(sim, outside)
	_give_power(sim, 2, 120)
	sim.economy.player(2).age = 2
	var morale_before := sim.entities.morale[enemy - 1]
	sim.enqueue(SimCommand.cast(sim.tick, 2, _ids(priest), RELIC, 0, 0))
	sim.run(3)
	var lost := (morale_before - sim.entities.morale[enemy - 1]) / CombatSystem.MORALE_SCALE
	assert_eq(lost, _db.magic.relic_enemy_morale, "−10 once")
	sim.run(20)
	lost = (morale_before - sim.entities.morale[enemy - 1]) / CombatSystem.MORALE_SCALE
	assert_eq(lost, _db.magic.relic_enemy_morale, "not again while it stays near")
	assert_eq(sim.entities.morale[outside - 1], 40 * CombatSystem.MORALE_SCALE, "too far")
	sim.combat.lose_morale(knecht - 1, 100)
	assert_eq(sim.entities.morale[knecht - 1], 10 * CombatSystem.MORALE_SCALE, "holds at 10")
	assert_ne(sim.entities.intents[knecht - 1], EntityStore.Intent.FLEE, "does not flee")
	sim.combat.lose_morale(knecht - 1, 100)
	assert_eq(sim.entities.morale[knecht - 1], 0, "at 10 the relic no longer holds it")
	sim.run(_db.spell(RELIC).duration_ticks)
	assert_eq(sim.magic.fx_ids.size(), 0, "45 s")


func test_relic_ends_with_its_bearer() -> void:
	var sim := _world()
	var priest := _spawn(sim, 2, PRIEST, 10.5, 10.5)
	_give_power(sim, 2, 120)
	sim.economy.player(2).age = 2
	sim.enqueue(SimCommand.cast(sim.tick, 2, _ids(priest), RELIC, 0, 0))
	sim.step()
	assert_eq(sim.magic.fx_ids.size(), 1)
	sim.enqueue(SimCommand.remove(sim.tick, 2, _ids(priest)))
	sim.run(2)
	assert_eq(sim.magic.fx_ids.size(), 0)


# --- healers and techs ------------------------------------------------------------------------


func test_znakharka_heals_one_hp_a_second_and_two_with_herbs() -> void:
	var sim := _world()
	_spawn(sim, 1, ZNAKHARKA, 10.5, 10.5)
	var hurt := _spawn(sim, 1, SPEARMAN, 12.5, 10.5)
	var far := _spawn(sim, 1, SPEARMAN, 20.5, 10.5)
	sim.entities.hp[hurt - 1] = 10
	sim.entities.hp[far - 1] = 10
	sim.run(200)
	assert_eq(sim.entities.hp[hurt - 1], 20, "1 HP a second for 10 s")
	assert_eq(sim.entities.hp[far - 1], 10, "out of reach")
	sim.economy.player(1).unit_mods[&"gdl_znakharka.heal"] = 1
	sim.run(200)
	assert_eq(sim.entities.hp[hurt - 1], 40, "«Травничество»: 2 HP a second, up to full")
