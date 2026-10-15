class_name EconomyTest
extends CombatTest
## Helpers for the M5 economy tests: maps drawn from rows of text, players joined with the
## catalog's starting stock, finished buildings placed by map setup.

const GDL := &"gdl"
const ORDER := &"to"
const TO_PEASANT := &"to_peasant"


## A grass map w × h with the given cells drawn over it: {Vector2i(x, y): "f"}.
func _drawn(w: int, h: int, cells: Dictionary = {}) -> Simulation:
	var rows := PackedStringArray()
	for y in h:
		var row := ""
		for x in w:
			row += str(cells.get(Vector2i(x, y), "."))
		rows.append(row)
	return _on_map("\n".join(rows))


## Cells x0..x1, y0..y1 (inclusive) as `ch`, added to `cells`.
func _fill(cells: Dictionary, x0: int, y0: int, x1: int, y1: int, ch: String) -> Dictionary:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			cells[Vector2i(x, y)] = ch
	return cells


func _join(sim: Simulation, player: int, faction: StringName) -> PlayerState:
	sim.enqueue(SimCommand.join(sim.tick, player, faction))
	sim.step()
	return sim.economy.player(player)


## A finished building with its top-left cell at (cx, cy); its id, or 0 if it could not stand.
func _place(
	sim: Simulation, player: int, building: StringName, cx: int, cy: int, turned: bool = false
) -> int:
	var id := sim.economy.buildings.next_id
	sim.enqueue(SimCommand.place(sim.tick, player, building, _cell(cx), _cell(cy), turned))
	sim.step()
	return id if sim.economy.buildings.is_alive(id) else BuildingStore.NO_ID


## Peasants and others ordered to lay a foundation; its id, or 0 if none was laid.
func _build(
	sim: Simulation, player: int, units: PackedInt32Array, building: StringName, cx: int, cy: int
) -> int:
	var id := sim.economy.buildings.next_id
	sim.enqueue(SimCommand.build(sim.tick, player, units, building, _cell(cx), _cell(cy)))
	sim.step()
	return id if sim.economy.buildings.is_alive(id) else BuildingStore.NO_ID


## The centre of a cell, in fixed units.
func _cell(c: int) -> int:
	return Fixed.from_cells(c) + Fixed.HALF


func _stock(sim: Simulation, player: int, resource: int) -> int:
	return sim.economy.player(player).stock[resource]


func _units_of(sim: Simulation, player: int, type_id: StringName) -> int:
	var n := 0
	for id in sim.entities.alive_ids:
		if sim.entities.owners[id - 1] == player and sim.entities.type_ids[id - 1] == type_id:
			n += 1
	return n


## Steps until the building is finished, at most `limit` ticks; the ticks it took, or -1.
func _until_done(sim: Simulation, b: int, limit: int) -> int:
	for i in limit:
		if sim.economy.buildings.is_done(b):
			return i
		sim.step()
	return -1
