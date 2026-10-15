class_name Fixed
extends RefCounted
## Fixed-point math for the simulation: 1 cell = 1024 units, no floats anywhere in the sim.
## GDScript ints are 64-bit; positions stay far below the overflow range of mul().
## Division rounds toward negative infinity so results don't depend on the sign of the input.

const SHIFT := 10
const ONE := 1 << SHIFT
const HALF := ONE >> 1
const TICKS_PER_SECOND := 20
const TICK_USEC := 1_000_000 / TICKS_PER_SECOND


static func from_cells(cells: int) -> int:
	return cells * ONE


## Whole cells, rounded down.
static func to_cells(value: int) -> int:
	return value >> SHIFT


## Thousandths of a cell (catalog style, e.g. speed_milli) to fixed units, rounded down.
static func from_milli(milli: int) -> int:
	return floor_div(milli * ONE, 1000)


## Catalog speed (thousandths of a cell per second) to fixed units per tick, rounded down.
static func speed_per_tick(speed_milli: int) -> int:
	return floor_div(speed_milli * ONE, 1000 * TICKS_PER_SECOND)


static func seconds_to_ticks(seconds: int) -> int:
	return seconds * TICKS_PER_SECOND


static func mul(a: int, b: int) -> int:
	return (a * b) >> SHIFT


static func div(a: int, b: int) -> int:
	assert(b != 0, "Fixed.div by zero")
	return floor_div(a << SHIFT, b)


## Integer division rounded toward negative infinity (GDScript '/' truncates toward zero).
static func floor_div(a: int, b: int) -> int:
	assert(b != 0, "Fixed.floor_div by zero")
	var q := a / b
	if (a % b != 0) and ((a < 0) != (b < 0)):
		q -= 1
	return q


## Largest r with r * r <= n, for n >= 0.
static func isqrt(n: int) -> int:
	assert(n >= 0, "Fixed.isqrt of a negative number")
	if n < 2:
		return n
	var x := n
	var y := (x + 1) >> 1
	while y < x:
		x = y
		y = (x + n / x) >> 1
	return x


## Euclidean distance between two fixed-point points, in fixed units (rounded down).
static func distance(ax: int, ay: int, bx: int, by: int) -> int:
	var dx := bx - ax
	var dy := by - ay
	return isqrt(dx * dx + dy * dy)
