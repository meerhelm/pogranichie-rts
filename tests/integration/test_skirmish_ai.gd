extends GutTest
## M8: the skirmish AI on the prototype map. It sees the world only through its own fog of war
## (plan: «ИИ не получает данные из тумана»), builds up an economy from the bare start, and gives
## commands the way a player does, so its games are deterministic and replay.

const ORDER := 2
## Far from both bases, where neither side sees at the start.
const MIDDLE := Vector2i(60, 40)
## Beside the Order's town centre (cells (108, 96) and on).
const ORDER_DOOR := Vector2i(106, 100)
## A GDL barracks in the open middle of the map, fenced round (cells RING_FROM..RING_TO), and
## the Order's wave west of it.
const RING_FROM := Vector2i(66, 21)
const RING_TO := Vector2i(74, 29)
const WAVE_AT := Vector2i(59, 25)

var _db: CatalogDB


func before_all() -> void:
	_db = CatalogDB.load_prototype()


func _start(sim_seed: int = 1) -> Simulation:
	var sim := SkirmishSetup.new_simulation(sim_seed, _db)
	sim.step()
	return sim


func _ai(sim: Simulation, player: int, difficulty: StringName = &"normal") -> SkirmishAi:
	var ai := SkirmishAi.new()
	var faction := SkirmishSetup.faction_of(player)
	ai.setup(sim, player, SkirmishSetup.ai_profile(faction, difficulty), 1)
	autofree(ai)
	return ai


func _spawn(sim: Simulation, type_id: StringName, player: int, cell: Vector2i) -> int:
	var p := SkirmishAi.point(cell)
	return sim.spawn_unit(type_id, player, p.x, p.y)


func test_profiles_name_only_what_the_prototype_has() -> void:
	for faction: StringName in [&"gdl", &"to"]:
		for difficulty: StringName in [&"easy", &"normal"]:
			var prof := SkirmishSetup.ai_profile(faction, difficulty)
			assert_eq(prof.faction, faction)
			for unit: StringName in prof.army:
				assert_not_null(_db.unit(unit), "%s_%s trains %s" % [faction, difficulty, unit])
			for step: StringName in prof.build_order:
				if step != &"age":
					var id := StringName("%s_%s" % [faction, step])
					assert_not_null(_db.building(id), "%s_%s builds %s" % [faction, difficulty, id])


func test_hidden_enemy_is_not_seen_and_does_not_threaten() -> void:
	var sim := _start()
	var ai := _ai(sim, ORDER)
	var raider := _spawn(sim, &"gdl_spearman", 1, MIDDLE)
	sim.run(3)
	ai.think()
	assert_false(ai.view.enemy_units().has(raider), "out in the fog")
	assert_false(ai.military_ai.base_threatened())
	var close := _spawn(sim, &"gdl_spearman", 1, ORDER_DOOR)
	sim.run(3)
	ai.think()
	assert_true(ai.view.enemy_units().has(close), "seen by the town centre")
	assert_false(ai.view.enemy_units().has(raider))
	assert_true(ai.military_ai.base_threatened())


func test_peasants_in_sight_are_no_threat() -> void:
	var sim := _start()
	var ai := _ai(sim, ORDER)
	var peasant := _spawn(sim, &"gdl_peasant", 1, ORDER_DOOR)
	sim.run(3)
	ai.think()
	assert_true(ai.view.enemy_units().has(peasant))
	assert_false(ai.military_ai.base_threatened())


func test_enemy_buildings_are_remembered_until_seen_gone() -> void:
	var sim := _start()
	var ai := _ai(sim, ORDER)
	var hidden := _place(sim, 1, &"gdl_house", MIDDLE)
	var seen := _place(sim, 1, &"gdl_house", ORDER_DOOR + Vector2i(-3, 0))
	sim.run(3)
	ai.think()
	assert_false(ai.view.known_buildings.has(hidden))
	assert_true(ai.view.known_buildings.has(seen))
	assert_eq(ai.view.enemy_buildings(), PackedInt32Array([seen]))
	sim.economy.destroy(seen)
	sim.run(3)
	ai.think()
	assert_false(ai.view.known_buildings.has(seen), "its cell is in sight and empty")


func test_builds_up_from_the_bare_start() -> void:
	var sim := _start()
	var ai := _ai(sim, ORDER)
	while sim.tick < 12 * 1200:
		ai.issue()
		sim.step()
	ai.think()
	assert_gt(ai.peasants.size(), SkirmishSetup.START_PEASANTS * 2)
	for base: StringName in [&"house", &"farm", &"lumber_yard", &"barracks"]:
		assert_false(ai.buildings_of(base).is_empty(), "has a %s" % base)
	var st := sim.economy.player(ORDER)
	assert_gt(st.gathered[EconomySystem.FOOD], 0)
	assert_gt(st.gathered[EconomySystem.WOOD], 0)
	assert_eq(st.trained, ai.peasants.size() - SkirmishSetup.START_PEASANTS)


func test_easy_thinks_half_as_often() -> void:
	var sim := _start()
	var normal := _ai(sim, ORDER)
	var easy := _ai(sim, 1, &"easy")
	for i in 400:
		normal.issue()
		easy.issue()
		sim.step()
	assert_eq(normal.thinks, 40)
	assert_eq(easy.thinks, 20)


func test_ai_games_are_deterministic_and_replay() -> void:
	var ticks := 3000
	var hashes: Array[String] = []
	for run in 2:
		var sim := SkirmishSetup.new_simulation(7, _db)
		var ais: Array[SkirmishAi] = [_ai(sim, 1), _ai(sim, ORDER)]
		for i in ticks:
			for ai in ais:
				ai.issue()
			sim.step()
		hashes.append(sim.state_hash())
	assert_eq(hashes[0], hashes[1])
	var ais: Array[SkirmishAi] = []
	var orders := func(sim: Simulation) -> void:
		if sim.tick == 0:
			SkirmishSetup.set_up(sim)
			ais.append(_ai(sim, 1))
			ais.append(_ai(sim, ORDER))
		for ai in ais:
			ai.issue()
	var replay := Replay.record(7, _db, ticks, orders, 100, 0, 0, SkirmishSetup.MAP_ID)
	assert_gt(replay.commands.size(), 30, "the AIs gave orders")
	assert_eq(replay.final_hash, hashes[0], "the same game as without recording")
	var back := replay.play(_db)
	assert_true(back.ok, back.message)


func _place(sim: Simulation, player: int, type_id: StringName, cell: Vector2i) -> int:
	var p := SkirmishAi.point(cell)
	sim.enqueue(SimCommand.place(sim.tick, player, type_id, p.x, p.y))
	sim.step()
	var store := sim.economy.buildings
	var last := 0
	for b in store.alive_ids:
		if store.owners[b - 1] == player and store.defs[b - 1].id == type_id:
			last = maxi(last, b)
	return last


# --- palisades, gates and towers in the way ---------------------------------------------------


## The ring of `palisade` with `special` pieces at their cells and `gap` cells left open.
func _fenced(
	sim: Simulation, special: Dictionary = {}, gap: Array[Vector2i] = []
) -> Dictionary[Vector2i, int]:
	var pieces: Dictionary[Vector2i, int] = {}
	for y in range(RING_FROM.y, RING_TO.y + 1):
		for x in range(RING_FROM.x, RING_TO.x + 1):
			var c := Vector2i(x, y)
			var edge := x == RING_FROM.x or x == RING_TO.x or y == RING_FROM.y or y == RING_TO.y
			if not edge or gap.has(c):
				continue
			pieces[c] = _place(sim, 1, str(special.get(c, &"gdl_palisade")), c)
			assert_ne(pieces[c], 0, "piece at %s" % c)
	return pieces


## The Order's wave of `count` units, sent at `target`, pressing the attack for `ticks`.
func _press(
	sim: Simulation, target: int, count: int, ticks: int, unit: StringName = &"to_knecht"
) -> SkirmishAi:
	var ai := _ai(sim, ORDER)
	var wave := PackedInt32Array()
	for i in count:
		wave.append(_spawn(sim, unit, ORDER, WAVE_AT + Vector2i(i % 3, i / 3)))
	sim.run(3)
	ai.view.refresh()
	ai._sort_own()
	var mil := ai.military_ai
	var store := sim.economy.buildings
	# Scouted before: the AI remembers where the target stands.
	var at := sim.nav.cell_at(store.cell_x[target - 1], store.cell_y[target - 1])
	ai.view.known_buildings[target] = at
	mil.wave = wave
	mil.target_building = target
	mil.target_cell = Vector2i(store.cell_x[target - 1], store.cell_y[target - 1])
	mil._staged = true
	for i in ticks:
		if i % 10 == 0:
			ai.view.refresh()
			ai._sort_own()
			mil.press_attack()
		sim.step()
	return ai


func _dead(sim: Simulation, pieces: Dictionary[Vector2i, int]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in pieces:
		if not sim.economy.buildings.is_alive(pieces[c]):
			out.append(c)
	return out


func test_a_wave_breaks_a_gap_of_three_into_a_closed_fence() -> void:
	var sim := _start()
	var pieces := _fenced(sim)
	var barracks := _place(sim, 1, &"gdl_barracks", Vector2i(69, 24))
	assert_ne(barracks, 0)
	_press(sim, barracks, 9, 3000)
	var dead := _dead(sim, pieces)
	assert_gte(dead.size(), 3, "a gap of three, not one hole: %s" % [dead])
	var store := sim.economy.buildings
	assert_true(
		not store.is_alive(barracks) or store.hp[barracks - 1] < store.max_hp[barracks - 1],
		"then on at the barracks"
	)


func test_a_small_wave_breaks_one_piece() -> void:
	var sim := _start()
	var pieces := _fenced(sim)
	var barracks := _place(sim, 1, &"gdl_barracks", Vector2i(69, 24))
	_press(sim, barracks, 3, 1500)
	assert_eq(_dead(sim, pieces).size(), 1)


func test_a_gate_in_the_way_is_left_when_three_palisades_hold_less() -> void:
	var sim := _start()
	var gate_at := Vector2i(RING_FROM.x, 25)
	var pieces := _fenced(sim, {gate_at: &"gdl_gate"})
	var barracks := _place(sim, 1, &"gdl_barracks", Vector2i(69, 24))
	_press(sim, barracks, 9, 3000)
	var dead := _dead(sim, pieces)
	assert_false(dead.has(gate_at), "250 HP a palisade, 1200 the gate")
	assert_gte(dead.size(), 3)


func test_one_gate_is_enough_where_no_palisade_is_near() -> void:
	var sim := _start()
	var gates := {}
	for y in range(RING_FROM.y + 1, RING_TO.y):
		gates[Vector2i(RING_FROM.x, y)] = &"gdl_gate"
	var pieces := _fenced(sim, gates)
	var barracks := _place(sim, 1, &"gdl_barracks", Vector2i(69, 24))
	_press(sim, barracks, 9, 4000, &"to_halfbrother")
	var dead := _dead(sim, pieces)
	assert_eq(dead.size(), 1, "one gate: %s" % [dead])
	assert_true(gates.has(dead[0]) if not dead.is_empty() else false)


func test_a_wave_walks_through_a_gap_it_sees() -> void:
	var sim := _start()
	var gap: Array[Vector2i] = [Vector2i(RING_FROM.x, 24), Vector2i(RING_FROM.x, 25)]
	var pieces := _fenced(sim, {}, gap)
	var barracks := _place(sim, 1, &"gdl_barracks", Vector2i(69, 24))
	_press(sim, barracks, 9, 2000)
	assert_eq(_dead(sim, pieces).size(), 0, "nothing broken")
	var store := sim.economy.buildings
	assert_true(not store.is_alive(barracks) or store.hp[barracks - 1] < store.max_hp[barracks - 1])


func test_a_gap_it_has_not_seen_does_not_count() -> void:
	var sim := _start()
	var gap: Array[Vector2i] = [Vector2i(RING_TO.x, 24), Vector2i(RING_TO.x, 25)]
	var pieces := _fenced(sim, {}, gap)
	var barracks := _place(sim, 1, &"gdl_barracks", Vector2i(69, 24))
	var ai := _ai(sim, ORDER)
	sim.run(3)
	ai.view.refresh()
	assert_false(ai.view.explored(sim.nav.cell_at(RING_TO.x + 1, 24)), "the far side is unseen")
	_press(sim, barracks, 9, 3000)
	assert_gte(_dead(sim, pieces).size(), 3, "breaks in on its own side")


func test_a_wave_puts_down_a_tower_that_shoots_at_it() -> void:
	var sim := _start()
	var tower := _place(sim, 1, &"gdl_tower", WAVE_AT + Vector2i(6, 1))
	var house := _place(sim, 1, &"gdl_house", WAVE_AT + Vector2i(30, 0))
	assert_ne(tower, 0)
	_press(sim, house, 12, 2400, &"to_halfbrother")
	assert_false(sim.economy.buildings.is_alive(tower), "the tower is down")
