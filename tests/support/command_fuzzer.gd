class_name CommandFuzzer
extends RefCounted
## Random but reproducible orders for determinism tests and benchmarks: spawns, moves (in
## random formations), stops and removals for two players, drawn from its own SimRng so the
## simulation's generator is untouched. Use as the `orders` callable of Replay.record().

const PLAYERS := 2
const MAX_UNITS := 200

var rng: SimRng
var unit_types: Array[StringName]
## Chance per tick, in per-mille, that the fuzzer issues a command at all.
var command_permille := 400


func _init(fuzz_seed: int, types: Array[StringName]) -> void:
	rng = SimRng.new(fuzz_seed)
	unit_types = types


func issue(sim: Simulation) -> void:
	if not rng.chance_permille(command_permille):
		return
	var player := rng.range_int(1, PLAYERS)
	var roll := rng.next_below(100)
	var mine := _units_of(sim, player)
	if mine.is_empty() or (roll < 30 and sim.entities.count() < MAX_UNITS):
		var unit := unit_types[rng.next_below(unit_types.size())]
		sim.enqueue(SimCommand.spawn(sim.tick, player, unit, _rand_x(sim), _rand_y(sim)))
	elif roll < 80:
		var group := _pick(mine)
		var shape := rng.next_below(3)
		sim.enqueue(SimCommand.move(sim.tick, player, group, _rand_x(sim), _rand_y(sim), shape))
	elif roll < 92:
		sim.enqueue(SimCommand.stop(sim.tick, player, _pick(mine)))
	elif roll < 97:
		var one := PackedInt32Array([mine[rng.next_below(mine.size())]])
		sim.enqueue(SimCommand.remove(sim.tick, player, one))
	else:
		# Foreign or dead ids must be ignored by the simulation, not crash it.
		var bogus := PackedInt32Array([rng.range_int(0, sim.entities.next_id + 5)])
		sim.enqueue(SimCommand.move(sim.tick, player, bogus, _rand_x(sim), _rand_y(sim)))


## Enough units moving at once to measure a busy tick.
static func populate(sim: Simulation, types: Array[StringName], units: int, fuzz_seed: int) -> void:
	var fuzz := CommandFuzzer.new(fuzz_seed, types)
	for i in units:
		var unit := types[i % types.size()]
		var player := 1 + i % PLAYERS
		sim.enqueue(SimCommand.spawn(sim.tick, player, unit, fuzz._rand_x(sim), fuzz._rand_y(sim)))


func _units_of(sim: Simulation, player: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	for id in sim.entities.alive_ids:
		if sim.entities.owners[id - 1] == player:
			result.append(id)
	return result


func _pick(ids: PackedInt32Array) -> PackedInt32Array:
	var group := PackedInt32Array()
	var size := rng.range_int(1, mini(12, ids.size()))
	for i in size:
		group.append(ids[rng.next_below(ids.size())])
	return group


func _rand_x(sim: Simulation) -> int:
	# A little outside the map too, to exercise clamping.
	return rng.range_int(-Fixed.ONE, sim.map_width + Fixed.ONE)


func _rand_y(sim: Simulation) -> int:
	return rng.range_int(-Fixed.ONE, sim.map_height + Fixed.ONE)
