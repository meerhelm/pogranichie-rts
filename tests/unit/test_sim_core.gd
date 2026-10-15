extends GutTest
## M2: entity store, command queue and the tick loop.

const KNIGHT := &"to_knight_brother"

var _db: CatalogDB


func before_all() -> void:
	_db = CatalogDB.load_prototype()


func _cell(n: int) -> int:
	return Fixed.from_cells(n)


func test_ids_ascend_and_are_never_reused() -> void:
	var store := EntityStore.new()
	var a := store.spawn(&"x", 1, 0, 0, 10, 5)
	var b := store.spawn(&"x", 1, 0, 0, 10, 5)
	store.remove(a)
	var c := store.spawn(&"x", 2, 0, 0, 10, 5)
	assert_eq([a, b, c], [1, 2, 3])
	assert_eq(store.alive_ids, PackedInt32Array([2, 3]))
	assert_false(store.is_alive(a))
	assert_false(store.is_alive(0))
	assert_false(store.is_alive(99))


func test_queue_orders_by_tick_then_player_then_arrival() -> void:
	var q := CommandQueue.new()
	q.push(SimCommand.stop(5, 2, PackedInt32Array([1])))
	q.push(SimCommand.stop(3, 2, PackedInt32Array([2])))
	q.push(SimCommand.stop(5, 1, PackedInt32Array([3])))
	q.push(SimCommand.stop(5, 1, PackedInt32Array([4])))
	assert_eq(q.take_due(4).size(), 1)
	var due := q.take_due(5)
	var first_ids: Array[int] = []
	for cmd in due:
		first_ids.append(cmd.ids[0])
	assert_eq(first_ids, [3, 4, 1])
	assert_eq(q.size(), 0)


func test_command_round_trips_through_json() -> void:
	var cmd := SimCommand.spawn(12, 2, KNIGHT, 1500, -3)
	var back := SimCommand.from_dict(JSON.parse_string(JSON.stringify(cmd.to_dict())))
	assert_eq(back.to_dict(), cmd.to_dict())
	assert_eq(typeof(back.x), TYPE_INT)
	var mv := SimCommand.move(4, 1, PackedInt32Array([3, 1]), 7, 8)
	assert_eq(SimCommand.from_dict(mv.to_dict()).ids, PackedInt32Array([3, 1]))


func test_spawn_takes_stats_from_catalog() -> void:
	var sim := Simulation.new(1, _db)
	sim.enqueue(SimCommand.spawn(0, 1, KNIGHT, _cell(5), _cell(5)))
	sim.step()
	assert_eq(sim.entities.count(), 1)
	assert_eq(sim.entities.hp[0], _db.unit(KNIGHT).hp)
	assert_eq(sim.entities.speed[0], Fixed.speed_per_tick(_db.unit(KNIGHT).speed_milli))


func test_unknown_unit_is_not_spawned() -> void:
	var sim := Simulation.new(1, _db)
	sim.enqueue(SimCommand.spawn(0, 1, &"no_such_unit", 0, 0))
	sim.step()
	assert_eq(sim.entities.count(), 0)


func test_command_applies_at_its_tick_not_before() -> void:
	var sim := Simulation.new(1, _db)
	sim.enqueue(SimCommand.spawn(3, 1, KNIGHT, 0, 0))
	sim.run(3)
	assert_eq(sim.entities.count(), 0)
	sim.step()
	assert_eq(sim.entities.count(), 1)


func test_command_for_past_tick_is_refused() -> void:
	var sim := Simulation.new(1, _db)
	sim.run(5)
	assert_false(sim.enqueue(SimCommand.spawn(4, 1, KNIGHT, 0, 0)))
	assert_true(sim.enqueue(SimCommand.spawn(5, 1, KNIGHT, 0, 0)))


func test_knight_walks_ten_cells_in_eight_seconds() -> void:
	# 1.25 cells/s → 64 units per tick; 10 cells = 10240 units = 160 ticks.
	var sim := Simulation.new(1, _db)
	sim.enqueue(SimCommand.spawn(0, 1, KNIGHT, _cell(10), _cell(10)))
	sim.enqueue(SimCommand.move(0, 1, PackedInt32Array([1]), _cell(20), _cell(10)))
	sim.run(159)
	assert_eq(sim.entities.pos_x[0], _cell(20) - 64, "one step short after 159 ticks")
	sim.step()
	assert_eq([sim.entities.pos_x[0], sim.entities.pos_y[0]], [_cell(20), _cell(10)])
	assert_eq(sim.entities.orders[0], EntityStore.Order.IDLE)


func test_diagonal_move_arrives_exactly() -> void:
	var sim := Simulation.new(1, _db)
	sim.enqueue(SimCommand.spawn(0, 1, KNIGHT, _cell(1), _cell(1)))
	sim.enqueue(SimCommand.move(0, 1, PackedInt32Array([1]), _cell(7), _cell(9)))
	sim.run(400)
	assert_eq([sim.entities.pos_x[0], sim.entities.pos_y[0]], [_cell(7), _cell(9)])


func test_players_cannot_order_foreign_or_dead_units() -> void:
	var sim := Simulation.new(1, _db)
	sim.enqueue(SimCommand.spawn(0, 1, KNIGHT, _cell(5), _cell(5)))
	# Far apart, so they do not see each other and start a fight (M4).
	sim.enqueue(SimCommand.spawn(0, 2, KNIGHT, _cell(60), _cell(60)))
	sim.step()
	sim.enqueue(SimCommand.move(1, 2, PackedInt32Array([1, 7, -1]), 0, 0))
	sim.enqueue(SimCommand.remove(1, 1, PackedInt32Array([2])))
	sim.run(20)
	assert_eq([sim.entities.pos_x[0], sim.entities.pos_y[0]], [_cell(5), _cell(5)])
	assert_eq(sim.entities.count(), 2)


func test_stop_and_remove() -> void:
	var sim := Simulation.new(1, _db)
	sim.enqueue(SimCommand.spawn(0, 1, KNIGHT, 0, 0))
	sim.enqueue(SimCommand.spawn(0, 1, KNIGHT, 0, _cell(4)))
	sim.enqueue(SimCommand.move(0, 1, PackedInt32Array([1]), _cell(50), 0))
	sim.enqueue(SimCommand.move(0, 1, PackedInt32Array([2]), _cell(50), _cell(4)))
	sim.enqueue(SimCommand.stop(10, 1, PackedInt32Array([1])))
	sim.enqueue(SimCommand.remove(10, 1, PackedInt32Array([2, 2])))
	sim.run(11)
	var stopped_at := [sim.entities.pos_x[0], sim.entities.pos_y[0]]
	sim.run(19)
	# Ten ticks at 64 units each (the route bends toward a cell centre first), then no more.
	var walked := Fixed.distance(0, 0, sim.entities.pos_x[0], sim.entities.pos_y[0])
	assert_between(walked, 600, 640)
	assert_eq([sim.entities.pos_x[0], sim.entities.pos_y[0]], stopped_at)
	assert_eq(sim.entities.orders[0], EntityStore.Order.IDLE)
	assert_eq(sim.entities.alive_ids, PackedInt32Array([1]))


func test_targets_are_clamped_to_the_map() -> void:
	var sim := Simulation.new(1, _db, 20, 10)
	sim.enqueue(SimCommand.spawn(0, 1, KNIGHT, -500, _cell(50)))
	sim.step()
	assert_eq([sim.entities.pos_x[0], sim.entities.pos_y[0]], [0, _cell(10) - 1])


func test_hash_is_stable_and_sees_every_change() -> void:
	var a := Simulation.new(1, _db)
	var b := Simulation.new(1, _db)
	assert_eq(a.state_hash(), b.state_hash())
	assert_eq(a.state_hash().length(), 64)
	a.enqueue(SimCommand.spawn(0, 1, KNIGHT, 0, 0))
	b.enqueue(SimCommand.spawn(0, 1, KNIGHT, 0, 0))
	a.step()
	b.step()
	assert_eq(a.state_hash(), b.state_hash())
	b.entities.hp[0] -= 1
	assert_ne(a.state_hash(), b.state_hash(), "hp")
	b.entities.hp[0] += 1
	b.rng.next_u32()
	assert_ne(a.state_hash(), b.state_hash(), "rng state")
	var c := Simulation.new(2, _db)
	c.enqueue(SimCommand.spawn(0, 1, KNIGHT, 0, 0))
	c.step()
	assert_ne(a.state_hash(), c.state_hash(), "seed")


func test_clock_runs_twenty_ticks_per_second() -> void:
	var clock := SimClock.new()
	clock.sim = Simulation.new(1, _db)
	clock.add_time_usec(Fixed.TICK_USEC * 3 + 10)
	assert_eq(clock.advance_accumulated(), 3)
	assert_eq(clock.sim.tick, 3)
	assert_eq(clock.alpha_permille(), 0)
	clock.add_time_usec(Fixed.TICK_USEC / 2)
	assert_eq(clock.advance_accumulated(), 0)
	assert_eq(clock.alpha_permille(), 500)
	clock.free()


func test_clock_caps_catch_up_after_a_stall() -> void:
	var clock := SimClock.new()
	clock.sim = Simulation.new(1, _db)
	clock.add_time_usec(1_000_000 * 10)
	assert_eq(clock.advance_accumulated(), SimClock.MAX_TICKS_PER_FRAME)
	assert_eq(clock.advance_accumulated(), 1, "backlog dropped, at most one tick left")
	clock.free()
