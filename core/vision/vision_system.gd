class_name VisionSystem
extends RefCounted
## Fog of war (M6): one VisionGrid per player, kept up to date at the end of every tick from
## where the player's units and buildings stand. Integers and ascending ids only, so every
## machine (and the AI, which looks only through sees_*) gets the same answer.
##
## A unit sees its «обзор» (CombatRulesDef.sight_default without one), +2 on a hill; a finished
## building its params.sight from the footprint's edge, +«Караулы» for towers and walls; a
## foundation VisionRulesDef.foundation_sight. Units in cover (forest) are seen only from
## cover_reveal_cells away; buildings and the ground are not hidden by cover.
## Cells are UNEXPLORED until first seen, then EXPLORED, and VISIBLE while something sees them.
## «Болотный туман» (M7, MistField) hides its side's units and buildings like cover: seen only
## from cover_reveal_cells away, a unit until it attacks.

enum State { UNEXPLORED, EXPLORED, VISIBLE }

const NO_CELL := -1
## Neighbour steps in the order of _delta keys.
const DX: Array[int] = [1, 1, 0, -1, -1, -1, 0, 1]
const DY: Array[int] = [0, 1, 1, 1, 0, -1, -1, -1]

var entities: EntityStore
var nav: NavGrid
## The economy's buildings and players (not the EconomySystem itself: CombatSystem holds this
## object, and the economy holds combat, so a reference back would leak the cycle).
var buildings: BuildingStore
var players: Dictionary[int, PlayerState]
var rules: VisionRulesDef
## Where mists lie (set by Simulation from MagicSystem).
var mist := MistField.new()
## Sight of units without «обзор» in «Особое».
var sight_default := 0
## Grid by player (created when the player first has something that sees).
var grids: Dictionary[int, VisionGrid] = {}

## Per unit slot: its own sight in cells, and the cell and radius it is stamped with now
## (NO_CELL when not stamped).
var _unit_sight := PackedInt32Array()
var _unit_cell := PackedInt32Array()
var _unit_radius := PackedInt32Array()
## Per building slot: stamped centre cell and radius; and the ids stamped, ascending.
var _bld_cell := PackedInt32Array()
var _bld_radius := PackedInt32Array()
var _bld_stamped := PackedInt32Array()
var _forest := -1
var _hill := -1
## Disc offsets (dx, dy pairs) by radius, and the cells entering and leaving a disc of radius r
## that moves one step in direction d, keyed r * 8 + d.
var _discs: Dictionary[int, PackedInt32Array] = {}
var _enter: Dictionary[int, PackedInt32Array] = {}
var _leave: Dictionary[int, PackedInt32Array] = {}


func _init(p_entities: EntityStore, p_nav: NavGrid, db: CatalogDB, economy: EconomySystem) -> void:
	entities = p_entities
	nav = p_nav
	buildings = economy.buildings
	players = economy.players
	if db != null:
		rules = db.vision
		sight_default = db.rules.sight_default
	_forest = nav.terrain_index(&"t_forest")
	_hill = nav.terrain_index(&"t_hill")


## Without the catalog (tests without data) there is no fog: everyone sees everything.
func enabled() -> bool:
	return rules != null


func on_spawn(id: int, def: UnitDef) -> void:
	var slot := id - 1
	while _unit_sight.size() <= slot:
		_unit_sight.append(0)
		_unit_cell.append(NO_CELL)
		_unit_radius.append(0)
	_unit_sight[slot] = def.param(&"sight", sight_default) if def != null else sight_default


func on_remove(id: int) -> void:
	var slot := id - 1
	if slot >= _unit_cell.size() or _unit_cell[slot] == NO_CELL:
		return
	var g := grids[entities.owners[slot]]
	_stamp(g, _unit_cell[slot], _unit_radius[slot], -1)
	_unit_cell[slot] = NO_CELL


## Moves every stamp to where its unit or building is now. Run at the end of a tick.
func step() -> void:
	if not enabled():
		return
	var e := entities
	for id in e.alive_ids:
		var slot := id - 1
		var owner := e.owners[slot]
		if owner <= 0 or slot >= _unit_sight.size():
			continue
		var cell := nav.cell_of(e.pos_x[slot], e.pos_y[slot])
		var radius := _unit_sight[slot]
		if nav.terrain[cell] == _hill:
			radius += rules.hill_sight_bonus
		var old := _unit_cell[slot]
		var old_radius := _unit_radius[slot]
		if old == cell and old_radius == radius:
			continue
		var g := _grid(owner)
		if old != NO_CELL and old_radius == radius and _is_step(old, cell):
			_shift(g, old, cell, radius)
		else:
			if old != NO_CELL:
				_stamp(g, old, old_radius, -1)
			_stamp(g, cell, radius, 1)
		_unit_cell[slot] = cell
		_unit_radius[slot] = radius
	_step_buildings()


func _step_buildings() -> void:
	var store := buildings
	var kept := PackedInt32Array()
	for id in _bld_stamped:
		var slot := id - 1
		if store.is_alive(id):
			kept.append(id)
		else:
			_stamp(grids[store.owners[slot]], _bld_cell[slot], _bld_radius[slot], -1)
	_bld_stamped = kept
	while _bld_cell.size() < store.next_id - 1:
		_bld_cell.append(NO_CELL)
		_bld_radius.append(0)
	for id in store.alive_ids:
		var slot := id - 1
		var owner := store.owners[slot]
		if owner <= 0:
			continue
		var cx := store.cell_x[slot] + store.w[slot] / 2
		var cy := store.cell_y[slot] + store.h[slot] / 2
		var cell := nav.cell_at(cx, cy)
		var radius := building_sight(id) + maxi(store.w[slot], store.h[slot]) / 2
		var old := _bld_cell[slot]
		if old == cell and _bld_radius[slot] == radius:
			continue
		var g := _grid(owner)
		if old != NO_CELL:
			_stamp(g, old, _bld_radius[slot], -1)
		else:
			_bld_stamped.insert(_bld_stamped.bsearch(id), id)
		_stamp(g, cell, radius, 1)
		_bld_cell[slot] = cell
		_bld_radius[slot] = radius


## How far a building sees from its footprint's edge, in cells.
func building_sight(id: int) -> int:
	var store := buildings
	var slot := id - 1
	if store.done[slot] == 0:
		return rules.foundation_sight
	var def := store.defs[slot]
	var sight := def.param(&"sight", 0)
	var state: PlayerState = players.get(store.owners[slot])
	if state != null and def.tags.has(&"watch"):
		sight += state.wall_sight_bonus
	return sight


# --- what a player sees ---------------------------------------------------------------------


func state(player: int, cell: int) -> State:
	if not enabled():
		return State.VISIBLE
	var g: VisionGrid = grids.get(player)
	if g == null or g.explored[cell] == 0:
		return State.UNEXPLORED
	return State.VISIBLE if g.far[cell] > 0 else State.EXPLORED


## The ground (and buildings) in the cell are in sight of the player.
func sees_cell(player: int, cell: int) -> bool:
	if not enabled():
		return true
	var g: VisionGrid = grids.get(player)
	return g != null and g.far[cell] > 0


## A unit standing in the cell would be seen by the player: the cell is in sight, and when it
## is cover (forest) something of the player's is within cover_reveal_cells.
func sees_unit_at(player: int, cell: int) -> bool:
	if not enabled():
		return true
	var g: VisionGrid = grids.get(player)
	if g == null:
		return false
	if g.near[cell] > 0:
		return true
	return g.far[cell] > 0 and not in_cover(cell)


func sees_unit(player: int, id: int) -> bool:
	var slot := id - 1
	var owner := entities.owners[slot]
	if owner == player:
		return true
	var cell := nav.cell_of(entities.pos_x[slot], entities.pos_y[slot])
	if not mist.is_empty() and enabled():
		var w := nav.width
		if mist.hides(owner, cell % w, cell / w, entities.last_attack[slot]):
			return _sees_near(player, cell)
	return sees_unit_at(player, cell)


## Something of the player's is within cover_reveal_cells of the cell.
func _sees_near(player: int, cell: int) -> bool:
	var g: VisionGrid = grids.get(player)
	return g != null and g.near[cell] > 0


## Any cell of the building is in sight.
func sees_building(player: int, b: int) -> bool:
	var store := buildings
	var owner := store.owners[b - 1]
	if owner == player:
		return true
	var w := nav.width
	for cell in store.cells_of(b, w):
		if not mist.is_empty() and enabled() and mist.hides(owner, cell % w, cell / w, -1):
			if _sees_near(player, cell):
				return true
		elif sees_cell(player, cell):
			return true
	return false


## Cells that hide every unit from afar: forest. («Болотный туман» hides only its side's units
## and buildings, see MistField.)
func in_cover(cell: int) -> bool:
	return nav.terrain[cell] == _forest


## Alive units the player can see, own included, ascending: the filter for the AI.
func visible_units(player: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in entities.alive_ids:
		if sees_unit(player, id):
			out.append(id)
	return out


# --- stamps ---------------------------------------------------------------------------------


func _grid(player: int) -> VisionGrid:
	var g: VisionGrid = grids.get(player)
	if g == null:
		g = VisionGrid.new(nav.width, nav.height)
		grids[player] = g
	return g


func _is_step(a: int, b: int) -> bool:
	var w := nav.width
	return absi(a % w - b % w) <= 1 and absi(a / w - b / w) <= 1


func _stamp(g: VisionGrid, cell: int, radius: int, amount: int) -> void:
	var cx := cell % nav.width
	var cy := cell / nav.width
	g.add_far(cx, cy, _disc(radius), amount)
	g.add_near(cx, cy, _disc(mini(radius, rules.cover_reveal_cells)), amount)


## One step to a neighbouring cell: only the edges of the discs change.
func _shift(g: VisionGrid, from: int, to: int, radius: int) -> void:
	var w := nav.width
	var dx := to % w - from % w
	var dy := to / w - from / w
	var d := 0
	while DX[d] != dx or DY[d] != dy:
		d += 1
	var near_r := mini(radius, rules.cover_reveal_cells)
	_delta(radius, d)
	_delta(near_r, d)
	g.add_far(to % w, to / w, _enter[radius * 8 + d], 1)
	g.add_far(from % w, from / w, _leave[radius * 8 + d], -1)
	g.add_near(to % w, to / w, _enter[near_r * 8 + d], 1)
	g.add_near(from % w, from / w, _leave[near_r * 8 + d], -1)


## Cells within radius of the centre (Euclidean, dx² + dy² <= r²), as dx, dy pairs.
func _disc(radius: int) -> PackedInt32Array:
	var cached: PackedInt32Array = _discs.get(radius, PackedInt32Array())
	if not cached.is_empty() or radius < 0:
		return cached
	var out := PackedInt32Array()
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius:
				out.append(dx)
				out.append(dy)
	_discs[radius] = out
	return out


static func _inside(dx: int, dy: int, radius: int) -> bool:
	return dx * dx + dy * dy <= radius * radius


## Fills _enter and _leave for a disc of `radius` stepping in direction d: entering cells
## relative to the new centre, leaving ones relative to the old.
func _delta(radius: int, d: int) -> void:
	var key := radius * 8 + d
	if _enter.has(key):
		return
	var disc := _disc(radius)
	var enter := PackedInt32Array()
	var leave := PackedInt32Array()
	for i in range(0, disc.size(), 2):
		var ox := disc[i]
		var oy := disc[i + 1]
		if not _inside(ox + DX[d], oy + DY[d], radius):
			enter.append(ox)
			enter.append(oy)
		if not _inside(ox - DX[d], oy - DY[d], radius):
			leave.append(ox)
			leave.append(oy)
	_enter[key] = enter
	_leave[key] = leave


## The explored cells of every player, for the state hash. Counts follow from positions.
func write_to(buf: StreamPeerBuffer) -> void:
	var players := grids.keys()
	players.sort()
	buf.put_32(players.size())
	for p: int in players:
		buf.put_32(p)
		buf.put_data(grids[p].explored)
