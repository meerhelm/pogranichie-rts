class_name CommandFuzzer
extends RefCounted
## Random but reproducible orders for determinism tests and benchmarks: spawns, moves (in
## random formations), attacks, attack-moves, stances, retreats, turns, dismounts, rally points,
## stops and removals for two players, drawn from its own SimRng so the simulation's generator
## is untouched. Use as the `orders` callable of Replay.record().
## With `economy` on (M5), the players also join with factions and town centres, gather, build,
## repair, assault buildings, queue and cancel units, techs and ages, and set rally points.
## With `magic` on as well (M7), some economy orders lay shrines on the map's places of power
## and cast spells.

const PLAYERS := 2
const MAX_UNITS := 200
const FACTIONS: Array[StringName] = [&"gdl", &"to"]
const PEASANTS: Array[StringName] = [&"gdl_peasant", &"to_peasant"]

var rng: SimRng
var unit_types: Array[StringName]
## Chance per tick, in per-mille, that the fuzzer issues a command at all.
var command_permille := 400
## Economy orders too; in per-mille of commands, how many are economy ones.
var economy := false
var economy_permille := 400
## Magic orders too (with economy); in per-mille of economy orders.
var magic := false
var magic_permille := 200


func _init(fuzz_seed: int, types: Array[StringName]) -> void:
	rng = SimRng.new(fuzz_seed)
	unit_types = types


func issue(sim: Simulation) -> void:
	if economy and sim.tick == 0:
		_set_up_economy(sim)
		return
	if not rng.chance_permille(command_permille):
		return
	var player := rng.range_int(1, PLAYERS)
	if economy and rng.chance_permille(economy_permille):
		if magic and rng.chance_permille(magic_permille):
			_magic_order(sim, player)
		else:
			_economy_order(sim, player)
		return
	var roll := rng.next_below(100)
	var mine := _units_of(sim, player)
	if mine.is_empty() or (roll < 30 and sim.entities.count() < MAX_UNITS):
		var unit := unit_types[rng.next_below(unit_types.size())]
		sim.enqueue(SimCommand.spawn(sim.tick, player, unit, _rand_x(sim), _rand_y(sim)))
	elif roll < 60:
		var group := _pick(mine)
		var shape := rng.next_below(3)
		sim.enqueue(SimCommand.move(sim.tick, player, group, _rand_x(sim), _rand_y(sim), shape))
	elif roll < 70:
		var group := _pick(mine)
		var shape := rng.next_below(3)
		var x := _rand_x(sim)
		var y := _rand_y(sim)
		sim.enqueue(SimCommand.attack_move(sim.tick, player, group, x, y, shape))
	elif roll < 78:
		var theirs := _units_of(sim, 3 - player)
		var enemy := theirs[rng.next_below(theirs.size())] if not theirs.is_empty() else 0
		sim.enqueue(SimCommand.attack(sim.tick, player, _pick(mine), enemy))
	elif roll < 82:
		var stance := rng.next_below(4)
		sim.enqueue(SimCommand.set_stance(sim.tick, player, _pick(mine), stance))
	elif roll < 86:
		var kinds := [SimCommand.Kind.RETREAT, SimCommand.Kind.TURN, SimCommand.Kind.DISMOUNT]
		var kind: SimCommand.Kind = kinds[rng.next_below(kinds.size())]
		sim.enqueue(SimCommand.order(sim.tick, player, kind, _pick(mine)))
	elif roll < 87:
		sim.enqueue(SimCommand.rally(sim.tick, player, _rand_x(sim), _rand_y(sim)))
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


func _set_up_economy(sim: Simulation) -> void:
	for p in range(1, PLAYERS + 1):
		var faction := FACTIONS[p - 1]
		sim.enqueue(SimCommand.join(sim.tick, p, faction))
		var center := StringName("%s_town_center" % faction)
		for i in 3:
			sim.enqueue(SimCommand.place(sim.tick, p, center, _rand_x(sim), _rand_y(sim)))
		for i in 4:
			var x := _rand_x(sim)
			var y := _rand_y(sim)
			sim.enqueue(SimCommand.spawn(sim.tick, p, PEASANTS[p - 1], x, y))


func _economy_order(sim: Simulation, player: int) -> void:
	var eco := sim.economy
	var mine := _units_of(sim, player)
	var faction := FACTIONS[player - 1]
	var roll := rng.next_below(100)
	var group := _pick(mine) if not mine.is_empty() else PackedInt32Array()
	var own := _buildings_of(sim, player)
	var x := _rand_x(sim)
	var y := _rand_y(sim)
	if roll < 15:
		var kinds := _faction_buildings(sim, faction)
		var kind := kinds[rng.next_below(kinds.size())]
		sim.enqueue(SimCommand.build(sim.tick, player, group, kind, x, y, rng.chance_permille(300)))
	elif roll < 20:
		var to := Vector2i(
			x + rng.range_int(-8, 8) * Fixed.ONE, y + rng.range_int(-8, 8) * Fixed.ONE
		)
		var wall := StringName("%s_palisade" % faction)
		sim.enqueue(SimCommand.wall(sim.tick, player, group, wall, Vector2i(x, y), to))
	elif roll < 40:
		sim.enqueue(SimCommand.gather_at(sim.tick, player, group, x, y))
	elif roll < 50:
		var what := rng.range_int(EconomySystem.Target.NODE, EconomySystem.Target.ANIMAL)
		var ref := rng.range_int(0, maxi(eco.nodes.next_id, sim.entities.next_id) + 2)
		sim.enqueue(SimCommand.gather(sim.tick, player, group, what, ref))
	elif roll < 58 and not own.is_empty():
		var b := own[rng.next_below(own.size())]
		sim.enqueue(SimCommand.on_building(sim.tick, player, SimCommand.Kind.WORK, group, b))
	elif roll < 64:
		var theirs := _buildings_of(sim, 3 - player)
		var b := theirs[rng.next_below(theirs.size())] if not theirs.is_empty() else 1
		sim.enqueue(SimCommand.on_building(sim.tick, player, SimCommand.Kind.ASSAULT, group, b))
	elif roll < 90 and not own.is_empty():
		var b := own[rng.next_below(own.size())]
		var items := _items_for(sim, b)
		if not items.is_empty():
			var item := items[rng.next_below(items.size())]
			sim.enqueue(SimCommand.queue_item(sim.tick, player, b, item))
	elif roll < 95 and not own.is_empty():
		var b := own[rng.next_below(own.size())]
		sim.enqueue(SimCommand.cancel_item(sim.tick, player, b, rng.range_int(-1, 5)))
	elif not own.is_empty():
		var b := PackedInt32Array([own[rng.next_below(own.size())]])
		sim.enqueue(SimCommand.building_rally(sim.tick, player, b, x, y))


## A shrine on a place of power (one the player holds when there is one), or a random spell at a
## random point.
func _magic_order(sim: Simulation, player: int) -> void:
	var mine := _units_of(sim, player)
	if mine.is_empty():
		return
	var group := _pick(mine)
	var places := sim.magic.places
	if rng.chance_permille(500) and places.count() > 0:
		var site := rng.next_below(places.count())
		var held := places.holders.find(player)
		if held >= 0 and rng.chance_permille(700):
			site = held
		var cell := places.cells[site]
		var x := Fixed.from_cells(cell % sim.nav.width) + Fixed.HALF
		var y := Fixed.from_cells(cell / sim.nav.width) + Fixed.HALF
		var shrine := StringName("%s_shrine" % FACTIONS[player - 1])
		sim.enqueue(SimCommand.build(sim.tick, player, group, shrine, x, y))
	elif not sim.magic.spells.is_empty():
		var spell := sim.magic.spells[rng.next_below(sim.magic.spells.size())]
		sim.enqueue(SimCommand.cast(sim.tick, player, group, spell.id, _rand_x(sim), _rand_y(sim)))


func _buildings_of(sim: Simulation, player: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	var store := sim.economy.buildings
	for b in store.alive_ids:
		if store.owners[b - 1] == player:
			result.append(b)
	return result


## The faction's buildings, sorted by id (as strings), so the pick is the same everywhere.
static func _faction_buildings(sim: Simulation, faction: StringName) -> Array[StringName]:
	var ids := PackedStringArray()
	for id: StringName in sim.economy.db.buildings:
		if sim.economy.db.buildings[id].faction == faction:
			ids.append(String(id))
	ids.sort()
	var result: Array[StringName] = []
	for id in ids:
		result.append(StringName(id))
	return result


## What the building could queue: its units, the techs of its kind and the next age.
static func _items_for(sim: Simulation, b: int) -> Array[StringName]:
	var def := sim.economy.buildings.defs[b - 1]
	var items: Array[StringName] = def.trains.duplicate()
	var techs := PackedStringArray()
	for id: StringName in sim.economy.db.techs:
		var t: TechDef = sim.economy.db.techs[id]
		if t.building == def.id or t.building == def.base_id:
			techs.append(String(id))
	techs.sort()
	for id in techs:
		items.append(StringName(id))
	items.append(&"age_khorugv")
	return items


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
