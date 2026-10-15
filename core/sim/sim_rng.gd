class_name SimRng
extends RefCounted
## Seeded xorshift32 generator for the simulation. Never use randi()/randf() in the sim:
## the same seed must give the same sequence on every machine.
## The state is a 32-bit value kept in a 64-bit int; it is never 0.

const MASK := 0xFFFF_FFFF
## Used instead of 0, which would lock xorshift at 0 forever.
const ZERO_SEED_REPLACEMENT := 0x9E37_79B9

var state: int


func _init(seed_value: int = 1) -> void:
	reseed(seed_value)


func reseed(seed_value: int) -> void:
	# Fold the 64-bit seed into 32 bits so large seeds still differ.
	state = (seed_value ^ (seed_value >> 32)) & MASK
	if state == 0:
		state = ZERO_SEED_REPLACEMENT


## Next raw value in [1, 2^32 - 1].
func next_u32() -> int:
	var x := state
	x ^= (x << 13) & MASK
	x ^= x >> 17
	x ^= (x << 5) & MASK
	state = x
	return x


## Uniform int in [0, n), n > 0. Uses rejection so there is no modulo bias.
func next_below(n: int) -> int:
	assert(n > 0 and n <= MASK, "SimRng.next_below: n out of range")
	# next_u32() - 1 is uniform over MASK values; keep only a whole multiple of n of them.
	var limit := MASK - (MASK % n)
	var x := next_u32() - 1
	while x >= limit:
		x = next_u32() - 1
	return x % n


## Uniform int in [lo, hi], inclusive.
func range_int(lo: int, hi: int) -> int:
	assert(hi >= lo, "SimRng.range_int: hi < lo")
	return lo + next_below(hi - lo + 1)


## True with probability permille / 1000.
func chance_permille(permille: int) -> bool:
	return next_below(1000) < permille
