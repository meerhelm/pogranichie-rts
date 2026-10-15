class_name AiView
extends RefCounted
## What one AI player may know about the world (M8, plan section 2: «ИИ видит мир сквозь свой
## туман войны»): everything of its own, and of everyone else only what its fog of war shows.
## The AI reads the simulation only through this filter.
##
## Enemy and neutral units: only those visible now (VisionSystem.visible_units). Enemy
## buildings: seen at least once and remembered where they stood, until the AI sees the place
## empty again. Resources: forest and deposits on explored ground.

var sim: Simulation
var player: int
## Enemy buildings the AI has seen and not yet seen gone: id -> top-left cell when last seen.
var known_buildings: Dictionary[int, int] = {}

var _visible := PackedInt32Array()
## Cells that were forest at the start (forest only shrinks), and this think's answers of
## nearest_wood() by anchor cell.
var _wood_cells := PackedInt32Array()
var _wood_cache: Dictionary[int, int] = {}


func _init(p_sim: Simulation, p_player: int) -> void:
	sim = p_sim
	player = p_player


## Looks around once per think: who is in sight now, which buildings came into view or are
## seen gone.
func refresh() -> void:
	_visible = sim.vision.visible_units(player)
	_wood_cache.clear()
	var store := sim.economy.buildings
	for b in store.alive_ids:
		var owner := store.owners[b - 1]
		if owner != player and owner > 0 and sim.vision.sees_building(player, b):
			known_buildings[b] = sim.nav.cell_at(store.cell_x[b - 1], store.cell_y[b - 1])
	for b: int in known_buildings.keys():
		var cell := known_buildings[b]
		if sim.vision.sees_cell(player, cell) and not _still_there(b, cell):
			known_buildings.erase(b)


## Seen ground where a remembered building stood: it is there only if it still is.
func _still_there(b: int, cell: int) -> bool:
	return sim.economy.buildings.is_alive(b) and sim.economy.buildings.occupant[cell] == b


func my_units() -> PackedInt32Array:
	var result := PackedInt32Array()
	var e := sim.entities
	for id in e.alive_ids:
		if e.owners[id - 1] == player:
			result.append(id)
	return result


func my_buildings() -> PackedInt32Array:
	var result := PackedInt32Array()
	var store := sim.economy.buildings
	for b in store.alive_ids:
		if store.owners[b - 1] == player:
			result.append(b)
	return result


## Units of other players (not animals) the AI sees now, ascending.
func enemy_units() -> PackedInt32Array:
	var result := PackedInt32Array()
	for id in _visible:
		var owner := sim.entities.owners[id - 1]
		if owner != player and owner > 0:
			result.append(id)
	return result


## Animals the AI sees now.
func visible_animals() -> PackedInt32Array:
	var result := PackedInt32Array()
	for id in _visible:
		if sim.entities.owners[id - 1] == 0:
			result.append(id)
	return result


func sees_unit(id: int) -> bool:
	return sim.entities.is_alive(id) and sim.vision.sees_unit(player, id)


## Remembered enemy buildings, ascending ids.
func enemy_buildings() -> PackedInt32Array:
	var ids := PackedInt32Array(known_buildings.keys())
	ids.sort()
	return ids


func explored(cell: int) -> bool:
	return sim.vision.state(player, cell) != VisionSystem.State.UNEXPLORED


## The explored forest cell with wood nearest to the point (cells); -1 if none within
## `radius` cells (Chebyshev).
func nearest_wood(cx: int, cy: int, radius: int) -> int:
	var nav := sim.nav
	var key := nav.cell_at(cx, cy) * 256 + radius
	if _wood_cache.has(key):
		return _wood_cache[key]
	var wood := sim.economy.nodes.wood
	if _wood_cells.is_empty():
		for c in nav.cell_count():
			if wood[c] > 0:
				_wood_cells.append(c)
	var occupant := sim.economy.buildings.occupant
	var w := nav.width
	var best := -1
	var best_d := 0
	for c in _wood_cells:
		var dx := c % w - cx
		var dy := c / w - cy
		if absi(dx) > radius or absi(dy) > radius:
			continue
		var d := dx * dx + dy * dy
		if best >= 0 and d >= best_d:
			continue
		if wood[c] <= 0 or occupant[c] != 0 or not explored(c):
			continue
		best = c
		best_d = d
	_wood_cache[key] = best
	return best


## The explored deposit of the source (ResourceNodes.Source) nearest to the point, 0 if none.
func nearest_deposit(source: int, cx: int, cy: int) -> int:
	var nodes := sim.economy.nodes
	var best := 0
	var best_d := 0
	for n in nodes.alive_ids:
		if (
			nodes.sources[n - 1] != source
			or nodes.amounts[n - 1] <= 0
			or nodes.from_unit[n - 1] != 0
		):
			continue
		var c := nodes.cells[n - 1]
		if not explored(c):
			continue
		var dx := c % sim.nav.width - cx
		var dy := c / sim.nav.width - cy
		var d := dx * dx + dy * dy
		if best == 0 or d < best_d:
			best = n
			best_d = d
	return best
