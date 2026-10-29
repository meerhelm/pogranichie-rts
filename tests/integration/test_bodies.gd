extends CombatTest
## Units have bodies: in a melee they do not heap up on each other, and no two bodies ever
## overlap by more than a half (Separation.MAX_OVERLAP).


## Two blocks charge each other: every tick, each pair the rule binds stays at least the least
## distance of its bodies apart, and the melee keeps most fighters well apart.
func test_a_melee_does_not_heap_up() -> void:
	var sim := _open(40, 30)
	var ours := PackedInt32Array()
	var theirs := PackedInt32Array()
	for i in 24:
		ours.append(_spawn(sim, 1, SPEARMAN, 8.5 + i % 4, 10.5 + i / 4))
	for i in 12:
		theirs.append(_spawn(sim, 2, KNECHT, 24.5 + i % 3, 12.5 + i / 3))
	for i in 4:
		theirs.append(_spawn(sim, 2, KNIGHT, 27.5, 12.5 + i))
	sim.enqueue(SimCommand.attack_move(sim.tick, 1, ours, _at(26.5), _at(14.5)))
	sim.enqueue(SimCommand.attack_move(sim.tick, 2, theirs, _at(8.5), _at(13.5)))
	var e := sim.entities
	var worst := 1000
	var close_pairs := 0
	var samples := 0
	for t in 900:
		sim.step()
		var ids := e.alive_ids
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				var a := ids[i] - 1
				var b := ids[j] - 1
				var d := Fixed.distance(e.pos_x[a], e.pos_y[a], e.pos_x[b], e.pos_y[b])
				var least := Separation.min_distance(e.move_class[a], e.move_class[b])
				if _bound(e, a, b):
					worst = mini(worst, d * 1000 / least)
				if d < Fixed.ONE / 4:
					close_pairs += 1
				samples += 1
	gut.p(
		(
			"worst pair distance %d permille of the least; pairs closer than 1/4 cell: %d of %d"
			% [worst, close_pairs, samples]
		)
	)
	assert_gte(worst, 1000, "no two bodies overlap by more than a half")
	assert_lt(close_pairs * 1000, samples, "under 0.1% of pairs closer than a quarter cell")


## Twenty men go for one knight: they ring him instead of standing in one spot.
func test_a_crowd_on_one_target_rings_it() -> void:
	var sim := _open(30, 30)
	var ours := PackedInt32Array()
	for i in 20:
		ours.append(_spawn(sim, 1, SPEARMAN, 5.5 + i % 5, 10.5 + i / 5))
	var knight := _spawn(sim, 2, KNIGHT, 15.5, 12.5)
	_passive(sim, knight)
	sim.enqueue(SimCommand.attack(sim.tick, 1, ours, knight))
	var e := sim.entities
	for t in 240:
		sim.step()
	var worst := 1000
	for i in ours.size():
		for j in range(i + 1, ours.size()):
			var a := ours[i] - 1
			var b := ours[j] - 1
			var d := Fixed.distance(e.pos_x[a], e.pos_y[a], e.pos_x[b], e.pos_y[b])
			worst = mini(
				worst, d * 1000 / Separation.min_distance(e.move_class[a], e.move_class[b])
			)
	assert_gte(worst, 1000, "no two of them overlap by more than a half")


## Whether the overlap rule binds the pair: either is fighting, or neither walks past the other
## standing (out of a fight a walker goes through standing units).
func _bound(e: EntityStore, a: int, b: int) -> bool:
	if e.target[a] != EntityStore.NO_ID or e.target[b] != EntityStore.NO_ID:
		return true
	return e.orders[a] == e.orders[b]
