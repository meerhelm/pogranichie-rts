extends EconomyTest
## Several peasants on one small source: they take different cells round a bog ore deposit or a
## silver mine and dig instead of pushing each other out of reach and walking back and forth,
## and two peasants meeting head-on near where they go do not stick nose to nose until they
## give up their work.


## A column of three bog ore deposits with the bog behind it, the mine to the west: 1, 2, 4
## and 6 peasants on the middle one.
func test_peasants_share_a_bog_ore_deposit() -> void:
	var cells := _fill({}, 13, 4, 15, 9, "b")
	for y: int in [6, 7, 8]:
		cells[Vector2i(12, y)] = "o"
	for n: int in [1, 2, 4, 6]:
		_check_crowd(cells, n, EconomySystem.IRON)


## A silver mine of two cells up on a hill: 2, 4 and 6 peasants on one of them.
func test_peasants_share_a_silver_mine() -> void:
	var cells := _fill({}, 11, 6, 14, 9, "h")
	cells[Vector2i(12, 7)] = "$"
	cells[Vector2i(13, 7)] = "$"
	for n: int in [2, 4, 6]:
		_check_crowd(cells, n, EconomySystem.SILVER)


## n peasants sent from one spot to the node at (12, 7) with the mine at (4, 6), for 150 s:
## each walks only there and back (a few walks a trip), none drops the work, and n of them
## bring in at least n loads.
func _check_crowd(cells: Dictionary, n: int, res: int) -> void:
	var sim := _drawn(30, 16, cells)
	_join(sim, 1, GDL)
	_place(sim, 1, &"gdl_mine", 4, 6)
	var node := sim.economy.nodes.at_cell(sim.nav.cell_at(12, 7))
	var ids := PackedInt32Array()
	for i in n:
		ids.append(_spawn(sim, 1, PEASANT, 9.5, 6.5 + i * 0.4))
	var before := _stock(sim, 1, res)
	sim.enqueue(SimCommand.gather(sim.tick, 1, ids, EconomySystem.Target.NODE, node))
	var walks := PackedInt32Array()
	walks.resize(n)
	var walking := PackedByteArray()
	walking.resize(n)
	for t in 3000:
		sim.step()
		for i in n:
			var moves := sim.entities.orders[ids[i] - 1] == EntityStore.Order.MOVE
			if moves and walking[i] == 0:
				walks[i] += 1
			walking[i] = 1 if moves else 0
	var gained := _stock(sim, 1, res) - before
	gut.p("%d peasants: %d brought in, walks %s" % [n, gained, walks])
	for i in n:
		var s := ids[i] - 1
		assert_eq(sim.economy.job[s], EconomySystem.Job.GATHER, "%d: peasant %d digs on" % [n, i])
		assert_lt(walks[i], 30, "%d: peasant %d does not walk back and forth" % [n, i])
	assert_gte(gained, n * _db.economy.carry, "%d peasants each brought a load or more" % n)


## Two peasants walk at each other along one line, each to a point just behind the other: they
## step aside and both get there.
func test_two_walkers_head_on_near_their_goals_pass() -> void:
	var sim := _drawn(20, 10)
	var a := _spawn(sim, 1, PEASANT, 8.0, 5.5)
	var b := _spawn(sim, 1, PEASANT, 9.0, 5.5)
	sim.enqueue(SimCommand.move(sim.tick, 1, _ids(a), _at(9.5), _at(5.5)))
	sim.enqueue(SimCommand.move(sim.tick, 1, _ids(b), _at(7.5), _at(5.5)))
	sim.run(200)
	for id: int in [a, b]:
		var s := id - 1
		assert_eq(sim.entities.orders[s], EntityStore.Order.IDLE, "peasant %d stopped" % id)
	assert_gt(sim.entities.pos_x[a - 1], _at(9.0), "a got past b")
	assert_lt(sim.entities.pos_x[b - 1], _at(8.0), "b got past a")


## On the Samogitia map: three woodcutters on the forest edge, one of them goes home first with
## a load. Before, two of them could meet head-on between the wood and the yard and stick until
## one gave up and stood idle; now all three keep cutting for five minutes, taking the next tree
## as each one is felled.
func test_woodcutters_keep_cutting_after_their_tree_is_felled() -> void:
	var text := FileAccess.get_file_as_string("res://maps/map_proto_samogitia/terrain.txt")
	var sim := _on_map(text)
	_join(sim, 1, GDL)
	var edge := Vector2i(40, 16)
	assert_gt(sim.economy.nodes.wood[sim.nav.cell_at(edge.x, edge.y)], 0, "forest at the edge")
	assert_ne(_place(sim, 1, &"gdl_lumber_yard", edge.x - 7, edge.y), 0)
	var ids := PackedInt32Array()
	for i in 3:
		ids.append(_spawn(sim, 1, PEASANT, edge.x - 1.5, edge.y + 0.5 + i * 0.5))
	sim.enqueue(SimCommand.gather_at(sim.tick, 1, ids, _cell(edge.x), _cell(edge.y)))
	sim.step()
	sim.economy.carry[ids[0] - 1] = 7
	sim.economy.carry_res[ids[0] - 1] = EconomySystem.WOOD
	var first := sim.economy.job_ref[ids[0] - 1]
	sim.run(6000)
	assert_eq(sim.economy.nodes.wood[first], 0, "the first tree is felled")
	for i in ids.size():
		var s := ids[i] - 1
		assert_eq(sim.economy.job[s], EconomySystem.Job.GATHER, "woodcutter %d cuts on" % i)
		assert_gt(sim.economy.nodes.wood[sim.economy.job_ref[s]], 0, "on a standing tree")
