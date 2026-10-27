class_name ResourceFlow
extends RefCounted
## What comes in and goes out of a player's stock, per minute of game time over the last
## minute, for the top bar's tooltips. Watches the stock from the interface side (the sim keeps
## no such account): what peasants bring home (PlayerState.gathered) is income, any other rise
## (salt works, a mission's gift) too, any fall is spending (prices, a mission's toll).

## The window the rates are averaged over, in ticks (one minute).
const WINDOW := 60 * Fixed.TICKS_PER_SECOND
## Before this much has been watched the rate is taken over this long, so the first seconds
## do not jump.
const MIN_SPAN := 10 * Fixed.TICKS_PER_SECOND
const BUCKET := Fixed.TICKS_PER_SECOND
const BUCKETS := WINDOW / BUCKET

var _start := -1
var _last := -1
var _stock := PackedInt64Array()
var _gathered := PackedInt64Array()
## Per second of game time (ring by tick / BUCKET): which second it is, and per resource the
## amounts in and out (4 each).
var _second := PackedInt64Array()
var _in := PackedInt64Array()
var _out := PackedInt64Array()


func _init() -> void:
	reset()


func reset() -> void:
	_start = -1
	_last = -1
	_second.resize(BUCKETS)
	_second.fill(-1)
	_in.resize(BUCKETS * 4)
	_in.fill(0)
	_out.resize(BUCKETS * 4)
	_out.fill(0)


## Takes the player's stock at this tick. A tick that goes back (a new game) starts over.
func sample(tick: int, state: PlayerState) -> void:
	if state == null:
		return
	if _last >= 0 and tick < _last:
		reset()
	if _last < 0:
		_start = tick
		_last = tick
		_stock = state.stock.duplicate()
		_gathered = state.gathered.duplicate()
		return
	if tick == _last:
		return
	var sec := tick / BUCKET
	var b := sec % BUCKETS
	if _second[b] != sec:
		_second[b] = sec
		for r in 4:
			_in[b * 4 + r] = 0
			_out[b * 4 + r] = 0
	for r in 4:
		var brought := maxi(state.gathered[r] - _gathered[r], 0)
		var other := state.stock[r] - _stock[r] - brought
		_in[b * 4 + r] += brought + maxi(other, 0)
		_out[b * 4 + r] += maxi(-other, 0)
	_last = tick
	_stock = state.stock.duplicate()
	_gathered = state.gathered.duplicate()


## Income of resource `r` per minute, over the last minute.
func income(r: int) -> int:
	return _rate(_in, r)


## Spending of resource `r` per minute, over the last minute.
func spending(r: int) -> int:
	return _rate(_out, r)


func _rate(sums: PackedInt64Array, r: int) -> int:
	if _last < 0:
		return 0
	var now := _last / BUCKET
	var total := 0
	for b in BUCKETS:
		if _second[b] >= 0 and now - _second[b] < BUCKETS:
			total += sums[b * 4 + r]
	var span := clampi(_last - _start, MIN_SPAN, WINDOW)
	return total * WINDOW / span
