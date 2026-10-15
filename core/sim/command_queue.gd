class_name CommandQueue
extends RefCounted
## Commands waiting for their tick, kept sorted by (tick, player, seq), which is the order
## the simulation applies them in.

var _pending: Array[SimCommand] = []
var _next_seq := 0


func size() -> int:
	return _pending.size()


func push(cmd: SimCommand) -> void:
	cmd.seq = _next_seq
	_next_seq += 1
	var at := _pending.bsearch_custom(cmd, _before)
	_pending.insert(at, cmd)


## Removes and returns every command due at the given tick, in apply order.
func take_due(tick: int) -> Array[SimCommand]:
	var due: Array[SimCommand] = []
	while not _pending.is_empty() and _pending[0].tick <= tick:
		due.append(_pending.pop_front())
	return due


static func _before(a: SimCommand, b: SimCommand) -> bool:
	if a.tick != b.tick:
		return a.tick < b.tick
	if a.player != b.player:
		return a.player < b.player
	return a.seq < b.seq
