extends GutTest
## M2: the seeded generator gives the same sequence everywhere (values from Marsaglia's
## xorshift32 with shifts 13/17/5, checked against a Python reference).


func test_known_sequence_for_seed_1() -> void:
	var rng := SimRng.new(1)
	assert_eq(
		[rng.next_u32(), rng.next_u32(), rng.next_u32(), rng.next_u32()],
		[270369, 67634689, 2647435461, 307599695]
	)


func test_zero_seed_does_not_lock_up() -> void:
	var rng := SimRng.new(0)
	assert_eq(rng.next_u32(), 1359758873)
	assert_eq(rng.next_u32(), 3761132862)


func test_same_seed_same_sequence_different_seed_differs() -> void:
	var a := SimRng.new(20261015)
	var b := SimRng.new(20261015)
	var c := SimRng.new(20261016)
	var same := true
	var differs := false
	for i in 100:
		var va := a.next_u32()
		same = same and va == b.next_u32()
		differs = differs or va != c.next_u32()
	assert_true(same)
	assert_true(differs)


func test_next_below_stays_in_range_and_hits_every_value() -> void:
	var rng := SimRng.new(42)
	var seen := {}
	for i in 2000:
		var v := rng.next_below(7)
		assert_between(v, 0, 6)
		seen[v] = true
	assert_eq(seen.size(), 7)


func test_range_int_inclusive() -> void:
	var rng := SimRng.new(3)
	var lo_seen := false
	var hi_seen := false
	for i in 1000:
		var v := rng.range_int(-2, 2)
		assert_between(v, -2, 2)
		lo_seen = lo_seen or v == -2
		hi_seen = hi_seen or v == 2
	assert_true(lo_seen and hi_seen)


func test_state_round_trip_resumes_sequence() -> void:
	var rng := SimRng.new(9)
	rng.next_u32()
	var copy := SimRng.new()
	copy.state = rng.state
	assert_eq(copy.next_u32(), rng.next_u32())
