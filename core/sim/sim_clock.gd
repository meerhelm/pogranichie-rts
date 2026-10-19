class_name SimClock
extends Node
## Drives a Simulation from the game loop at 20 ticks per second, independent of frame rate.
## Real time is counted in whole microseconds so the float frame delta never reaches the sim.
## Rendering can use alpha_permille() to interpolate between the last two ticks.
##
## `ticked` comes after every tick, for what must see each one (the AI's orders, mission
## dialogues). `advanced` comes once a frame after all of that frame's ticks, for drawing: at
## 8x a frame runs many ticks and the views are refreshed once, not once a tick.

signal ticked(tick: int)
## After a frame's ticks: the sim's tick now and how many ticks this frame ran (at least 1).
signal advanced(tick: int, steps: int)

## Ticks to catch up at most per frame; after a long stall the game slows down instead of
## freezing to simulate the backlog.
const MAX_TICKS_PER_FRAME := 5
## Real time a frame may spend on ticks. When the ticks of a late game cost more than that
## (the machine cannot run 8x), the game runs slower than asked instead of dropping to a few
## frames a second, and the backlog is dropped as after a stall.
const FRAME_BUDGET_USEC := 25_000

var sim: Simulation
var paused := false
## Game speed in per-mille: 1000 is normal, 2000 double. Speed only changes how many ticks
## run per real second; every tick is the same, so replays and lockstep stay deterministic.
var speed_permille := 1000

## FRAME_BUDGET_USEC; tests set it.
var budget_usec := FRAME_BUDGET_USEC

var _accum_usec := 0


func _process(delta: float) -> void:
	if sim == null or paused:
		return
	_accum_usec += int(delta * 1_000_000.0) * speed_permille / 1000
	advance_accumulated()


## Steps the simulation for the time accumulated so far. Split out for tests.
func advance_accumulated() -> int:
	var steps := 0
	var max_steps := max_ticks_per_frame()
	var start := Time.get_ticks_usec()
	var over := false
	var was_paused := paused
	while _accum_usec >= Fixed.TICK_USEC and steps < max_steps:
		_accum_usec -= Fixed.TICK_USEC
		sim.step()
		steps += 1
		ticked.emit(sim.tick)
		# A dialogue or cutscene that paused the game stops the frame's ticks right there.
		if paused and not was_paused:
			break
		if Time.get_ticks_usec() - start >= budget_usec:
			over = true
			break
	if steps == max_steps or over:
		_accum_usec = mini(_accum_usec, Fixed.TICK_USEC)
	if steps > 0:
		advanced.emit(sim.tick, steps)
	return steps


## The catch-up limit grows with the speed, so 8x still runs 8x at 30 frames a second.
func max_ticks_per_frame() -> int:
	return MAX_TICKS_PER_FRAME * maxi(1, speed_permille / 2000)


func add_time_usec(usec: int) -> void:
	_accum_usec += usec


## How far real time is into the next tick, 0..999.
func alpha_permille() -> int:
	return mini(_accum_usec * 1000 / Fixed.TICK_USEC, 999)
