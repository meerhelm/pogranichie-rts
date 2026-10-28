extends GutTest
## M2: fixed-point helpers. The sim never uses floats, so rounding rules are pinned here.


func test_one_cell_is_1024_units() -> void:
	assert_eq(Fixed.ONE, 1024)
	assert_eq(Fixed.from_cells(3), 3072)
	assert_eq(Fixed.to_cells(3071), 2)
	assert_eq(Fixed.to_cells(-1), -1, "to_cells rounds down, also below zero")


func test_speed_per_tick_from_catalog_milli() -> void:
	# 1.25 cells/s = 1280 units/s = 64 units per tick at 20 ticks/s.
	assert_eq(Fixed.speed_per_tick(1250), 64)
	assert_eq(Fixed.speed_per_tick(1000), 51, "51.2 rounds down")
	assert_eq(Fixed.speed_per_tick(0), 0)


func test_mul_and_div() -> void:
	assert_eq(Fixed.mul(Fixed.from_cells(3), Fixed.HALF), 1536)
	assert_eq(Fixed.div(Fixed.from_cells(3), Fixed.from_cells(2)), 1536)
	assert_eq(Fixed.mul(-3, Fixed.HALF), -2, "mul rounds toward negative infinity")


func test_floor_div_rounds_down_for_every_sign() -> void:
	var cases := [[7, 2, 3], [-7, 2, -4], [7, -2, -4], [-7, -2, 3], [6, 3, 2], [-6, 3, -2]]
	for c: Array in cases:
		assert_eq(Fixed.floor_div(Num.of(c[0]), Num.of(c[1])), c[2], "%d // %d" % [c[0], c[1]])


func test_isqrt_exact_and_floor() -> void:
	var cases := [[0, 0], [1, 1], [2, 1], [3, 1], [4, 2], [15, 3], [16, 4], [17, 4]]
	for c: Array in cases:
		assert_eq(Fixed.isqrt(Num.of(c[0])), c[1], "isqrt(%d)" % c[0])
	# Largest squared distance on a 160×160 map stays exact.
	var far := Fixed.from_cells(160)
	var n := 2 * far * far
	var r := Fixed.isqrt(n)
	assert_true(r * r <= n and (r + 1) * (r + 1) > n)


func test_distance_three_four_five() -> void:
	assert_eq(Fixed.distance(0, 0, Fixed.from_cells(3), Fixed.from_cells(4)), Fixed.from_cells(5))
