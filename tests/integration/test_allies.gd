extends MagicTest
## Allies (Sides), khorugv banners and «Гнев Перкуна», added for mission «ВКЛ 2. Грюнвальд»:
## allied players never fight and share sight, a banner bearer lifts morale around it, the storm
## strikes the heaviest enemies and silences bows and crossbows under it.

const PERKUNAS := &"sp_perkunas"


## Grass with players 1 and 3 on one side, 2 on the other.
func _allied() -> Simulation:
	var sim := _world()
	_join(sim, 3, GDL)
	sim.sides.team[1] = 1
	sim.sides.team[3] = 1
	sim.sides.team[2] = 2
	return sim


func test_sides_without_teams_are_everyone_against_everyone() -> void:
	var s := Sides.new()
	assert_true(s.hostile(1, 2))
	assert_false(s.hostile(1, 1))
	assert_false(s.hostile(0, 2), "nature is nobody's enemy")
	s.team[1] = 1
	s.team[3] = 1
	assert_false(s.hostile(1, 3))
	assert_true(s.friendly(1, 3))
	assert_true(s.hostile(3, 2))


func test_allies_do_not_fight_each_other() -> void:
	var sim := _allied()
	var a := _spawn(sim, 1, LANCE, 10.5, 5.5)
	var b := _spawn(sim, 3, LANCE, 11.5, 5.5)
	sim.run(200)
	assert_eq(sim.entities.hp[a - 1], sim.entities.max_hp[a - 1])
	assert_eq(sim.entities.hp[b - 1], sim.entities.max_hp[b - 1])
	sim.enqueue(SimCommand.attack(sim.tick, 1, _ids(a), b))
	sim.run(200)
	assert_eq(
		sim.entities.hp[b - 1], sim.entities.max_hp[b - 1], "an order to hit an ally is ignored"
	)


func test_an_ally_fights_the_common_enemy() -> void:
	var sim := _allied()
	var ally := _spawn(sim, 3, LANCE, 10.5, 5.5)
	var enemy := _spawn(sim, 2, KNECHT, 11.5, 5.5)
	sim.run(200)
	assert_lt(sim.entities.hp[enemy - 1], sim.entities.max_hp[enemy - 1])
	assert_true(sim.entities.is_alive(ally))


func test_allies_share_their_sight() -> void:
	var sim := _allied()
	_spawn(sim, 3, LANCE, 30.5, 20.5)
	sim.run(5)
	var cell := sim.nav.cell_at(30, 20)
	assert_true(sim.vision.sees_cell(1, cell), "player 1 sees what its ally sees")
	assert_false(sim.vision.sees_cell(2, cell))


func test_a_banner_lifts_the_morale_of_units_around_it() -> void:
	var sim := _allied()
	var bearer := _spawn(sim, 1, LANCE, 10.5, 10.5)
	var near := _spawn(sim, 1, SPEARMAN, 12.5, 10.5)
	var far := _spawn(sim, 1, SPEARMAN, 35.5, 25.5)
	var before := sim.combat.morale_bonus(near - 1)
	sim.combat.banners.bearers[bearer] = true
	assert_eq(sim.combat.morale_bonus(near - 1) - before, sim.combat.rules.banner_morale)
	var far_with := sim.combat.morale_bonus(far - 1)
	sim.combat.banners.bearers.clear()
	assert_eq(sim.combat.morale_bonus(far - 1), far_with, "too far to see the banner")


func test_perkunas_needs_the_second_age_and_strikes_the_heaviest() -> void:
	var sim := _allied()
	var z := _spawn(sim, 1, ZNAKHARKA, 13.5, 4.5)
	_give_power(sim, 1, 300)
	assert_eq(sim.magic.can_cast(1, z, PERKUNAS), MagicSystem.Cast.AGE)
	sim.economy.player(1).age = 2
	assert_eq(sim.magic.can_cast(1, z, PERKUNAS), MagicSystem.Cast.OK)
	var knights: Array[int] = []
	for i in 3:
		knights.append(_spawn(sim, 2, KNIGHT, 12.5 + i, 8.5))
	var knecht := _spawn(sim, 2, KNECHT, 12.5, 10.5)
	var ally := _spawn(sim, 3, LANCE, 13.5, 10.5)
	var held := knights.duplicate()
	held.append_array([knecht, ally])
	_hold(sim, held)
	sim.enqueue(SimCommand.cast(sim.tick, 1, _ids(z), PERKUNAS, _at(13.5), _at(9.5)))
	sim.step()
	for id in knights:
		assert_eq(
			sim.entities.hp[id - 1],
			sim.entities.max_hp[id - 1] - sim.magic.rules.storm_damage,
			"each of the 3 heaviest is struck"
		)
	assert_eq(sim.entities.hp[knecht - 1], sim.entities.max_hp[knecht - 1])
	assert_eq(sim.entities.hp[ally - 1], sim.entities.max_hp[ally - 1], "lightning spares allies")


func test_crossbows_are_silent_in_the_storm_rain() -> void:
	var sim := _allied()
	var z := _spawn(sim, 1, ZNAKHARKA, 16.5, 5.5)
	sim.economy.player(1).age = 2
	_give_power(sim, 1, 300)
	var target := _spawn(sim, 1, SPEARMAN, 25.5, 10.5)
	_hold(sim, [target, z])
	sim.enqueue(SimCommand.cast(sim.tick, 1, _ids(z), PERKUNAS, _at(20.5), _at(10.5)))
	for k in 100:
		if sim.magic.fx_ids.size() > 0:
			break
		sim.step()
	assert_eq(sim.magic.fx_ids.size(), 1, "the storm is up")
	var xbow := _spawn(sim, 2, CROSSBOW, 20.5, 10.5)
	sim.run(200)
	assert_true(sim.magic.silenced(xbow - 1))
	assert_eq(sim.entities.hp[target - 1], sim.entities.max_hp[target - 1], "no bolt in the rain")
	sim.run(_db.spell(PERKUNAS).duration_ticks)
	assert_false(sim.magic.silenced(xbow - 1), "the storm has passed")
	sim.run(400)
	assert_lt(sim.entities.hp[target - 1], sim.entities.max_hp[target - 1], "shoots again after")


## Passive stance for all the units at once, so nobody starts a fight meanwhile.
func _hold(sim: Simulation, ids: Array[int]) -> void:
	var by_owner: Dictionary[int, PackedInt32Array] = {}
	for id in ids:
		var o := sim.entities.owners[id - 1]
		if not by_owner.has(o):
			by_owner[o] = PackedInt32Array()
		by_owner[o].append(id)
	for o: int in by_owner:
		sim.enqueue(SimCommand.set_stance(sim.tick, o, by_owner[o], 3))
	sim.step()
