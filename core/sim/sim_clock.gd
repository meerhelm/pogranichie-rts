class_name SimClock
extends Node
## Drives a Simulation from the game loop at 20 ticks per second, independent of frame rate.
## Real time is counted in whole microseconds so the float frame delta never reaches the sim.
## Rendering can use alpha_permille() to interpolate between the last two ticks.

signal ticked(tick: int)

## Ticks to catch up at most per frame; after a long stall the game slows down instead of
## freezing to simulate the backlog.
const MAX_TICKS_PER_FRAME := 5

var sim: Simulation
var paused := false
## Game speed in per-mille: 1000 is normal, 2000 double.
var speed_permille := 1000

var _accum_usec := 0


func _process(delta: float) -> void:
	if sim == null or paused:
		return
	_accum_usec += int(delta * 1_000_000.0) * speed_permille / 1000
	advance_accumulated()


## Steps the simulation for the time accumulated so far. Split out for tests.
func advance_accumulated() -> int:
	var steps := 0
	while _accum_usec >= Fixed.TICK_USEC and steps < MAX_TICKS_PER_FRAME:
		_accum_usec -= Fixed.TICK_USEC
		sim.step()
		steps += 1
		ticked.emit(sim.tick)
	if steps == MAX_TICKS_PER_FRAME:
		_accum_usec = mini(_accum_usec, Fixed.TICK_USEC)
	return steps


func add_time_usec(usec: int) -> void:
	_accum_usec += usec


## How far real time is into the next tick, 0..999.
func alpha_permille() -> int:
	return mini(_accum_usec * 1000 / Fixed.TICK_USEC, 999)
