# gdlint:ignore = max-public-methods
class_name NavGrid
extends RefCounted
## The logical map for movement: a square grid (isometry exists only in rendering) where each
## cell has a terrain from the catalog and may be blocked by a building or a zaseka.
## Speeds are per-mille multipliers from TerrainDef, looked up per movement class.
## Integers only; cells are indexed row by row: cell = y * width + x.

## How a unit is affected by terrain. Taken from its catalog classes and tags.
enum MoveClass { FOOT, CAVALRY, SIEGE, FOREST_FOOT }

const MOVE_CLASS_COUNT := 4
const NO_CELL := -1
## Step lengths in path-cost units, 100 per cell side (141 for a diagonal), before dividing by
## the speed: a step costs length * 1000 / speed per-mille.
const STRAIGHT := 100
const DIAGONAL := 141
## Largest grid the pathfinder's packed heap keys allow.
const MAX_CELLS := 1 << 16
## Terrain used when a map has none (tests, the open M2 fuzz map).
const DEFAULT_TERRAIN := &"t_grass"
const FOREST := &"t_forest"
const BOG := &"t_bog"

var width: int
var height: int
## Terrain index per cell (into terrain_ids).
var terrain := PackedByteArray()
## Number of blockers (buildings, zaseki) on each cell; a cell with any is impassable.
var blocked := PackedByteArray()
var terrain_ids: Array[StringName] = []
## Grows on every change, so paths planned on an older grid know to re-plan.
var version := 0

## enter[move_class][terrain index]: speed per-mille when entering that terrain, 0 = never.
var _enter: Array[PackedInt32Array] = []
## Per terrain: extra per-mille when entering from a terrain that is not a climb (hills).
var _uphill := PackedInt32Array()
var _hash_version := -1
var _hash := PackedByteArray()
## Step costs into each cell, per movement class (0 = closed), cached for the pathfinder:
## _costs[cls * 4 + k], k = 0 straight, 1 diagonal, 2 straight climbing, 3 diagonal climbing.
var _costs: Array[PackedInt32Array] = []
## 1 for cells that are a climb to enter (hills).
var _hills := PackedByteArray()
var _min_cost := PackedInt32Array()
var _costs_version := -1
## Connected areas per movement class: _areas[cls][cell] is an area number, -1 if closed.
var _areas: Array[PackedInt32Array] = []
var _areas_version := -1


## An all-grass grid, or of the given terrain defs. `terrains` maps id -> TerrainDef; when
## empty, every terrain is open at x1.0 (tests without the catalog).
func _init(
	w: int, h: int, terrains: Dictionary[StringName, TerrainDef] = {}, ids: Array[StringName] = []
) -> void:
	assert(w > 0 and h > 0 and w * h <= MAX_CELLS, "nav grid size out of range")
	width = w
	height = h
	if ids.is_empty():
		terrain_ids.append(DEFAULT_TERRAIN)
	else:
		terrain_ids.assign(ids)
	terrain.resize(w * h)
	terrain.fill(0)
	blocked.resize(w * h)
	blocked.fill(0)
	_build_tables(terrains)


static func for_catalog(w: int, h: int, db: CatalogDB) -> NavGrid:
	if db == null:
		return NavGrid.new(w, h)
	return NavGrid.new(w, h, db.terrains, sorted_terrain_ids(db))


## Terrain ids in a fixed order (sorted as String, never as StringName).
static func sorted_terrain_ids(db: CatalogDB) -> Array[StringName]:
	var names := PackedStringArray()
	for id: StringName in db.terrains:
		names.append(String(id))
	names.sort()
	var ids: Array[StringName] = []
	for n in names:
		ids.append(StringName(n))
	return ids


static func move_class_for(def: UnitDef) -> MoveClass:
	if def == null:
		return MoveClass.FOOT
	if def.has_class(&"cavalry"):
		return MoveClass.CAVALRY
	if def.has_class(&"siege"):
		return MoveClass.SIEGE
	if def.tags.has(&"forest_walker"):
		return MoveClass.FOREST_FOOT
	return MoveClass.FOOT


func cell_count() -> int:
	return width * height


func cell_at(cx: int, cy: int) -> int:
	return cy * width + cx


func in_bounds(cx: int, cy: int) -> bool:
	return cx >= 0 and cy >= 0 and cx < width and cy < height


## The cell under a fixed-point position (positions are clamped to the map by the sim).
func cell_of(x: int, y: int) -> int:
	var cx := clampi(Fixed.to_cells(x), 0, width - 1)
	var cy := clampi(Fixed.to_cells(y), 0, height - 1)
	return cy * width + cx


func center_x(cell: int) -> int:
	return Fixed.from_cells(cell % width) + Fixed.HALF


func center_y(cell: int) -> int:
	return Fixed.from_cells(cell / width) + Fixed.HALF


func terrain_index(id: StringName) -> int:
	return terrain_ids.find(id)


func terrain_at(cell: int) -> StringName:
	return terrain_ids[terrain[cell]]


func set_terrain(cell: int, index: int) -> void:
	assert(index >= 0 and index < terrain_ids.size(), "unknown terrain index")
	if terrain[cell] != index:
		terrain[cell] = index
		_changed(cell)


func set_blocked(cell: int, is_blocked: bool) -> void:
	var count := blocked[cell]
	var now := mini(count + 1, 255) if is_blocked else maxi(count - 1, 0)
	if now != count:
		blocked[cell] = now
		_changed(cell)


## Cached step costs for the pathfinder: kind 0 straight, 1 diagonal, 2 and 3 the same when
## climbing into the cell. Rebuilt when the grid changed outside set_terrain/set_blocked.
func step_costs(move_class: int, kind: int) -> PackedInt32Array:
	if _costs_version != version:
		_rebuild_costs()
	return _costs[move_class * 4 + kind]


func hill_cells() -> PackedByteArray:
	if _costs_version != version:
		_rebuild_costs()
	return _hills


## Cheapest straight (kind 0) or diagonal (kind 1) step anywhere on the map for this class,
## for an admissible A* heuristic.
func min_step_cost(move_class: int, kind: int) -> int:
	if _costs_version != version:
		_rebuild_costs()
	return _min_cost[move_class * 2 + kind]


func _changed(cell: int) -> void:
	var was_current := _costs_version == version
	version += 1
	if was_current:
		_update_costs(cell)
		_costs_version = version


func _rebuild_costs() -> void:
	var n := cell_count()
	_costs.clear()
	for i in MOVE_CLASS_COUNT * 4:
		var arr := PackedInt32Array()
		arr.resize(n)
		_costs.append(arr)
	_hills.resize(n)
	for cell in n:
		_update_costs(cell)
	_min_cost.resize(MOVE_CLASS_COUNT * 2)
	for cls in MOVE_CLASS_COUNT:
		for kind in 2:
			var best := 1 << 30
			for c: int in _costs[cls * 4 + kind]:
				if c > 0 and c < best:
					best = c
			_min_cost[cls * 2 + kind] = best if best < (1 << 30) else 1
	_costs_version = version


## Updates one cell's costs. The cached minimum is not lowered here: a cell made faster later
## (a burnt forest) can make a path slightly longer than best, never wrong.
func _update_costs(cell: int) -> void:
	var t := terrain[cell]
	var climb := _uphill[t]
	_hills[cell] = 1 if climb != 1000 else 0
	for cls in MOVE_CLASS_COUNT:
		var permille: int = _enter[cls][t] if blocked[cell] == 0 else 0
		var base := cls * 4
		if permille == 0:
			_costs[base][cell] = 0
			_costs[base + 1][cell] = 0
			_costs[base + 2][cell] = 0
			_costs[base + 3][cell] = 0
			continue
		var up := maxi(permille * climb / 1000, 1)
		_costs[base][cell] = STRAIGHT * 1000 / permille
		_costs[base + 1][cell] = DIAGONAL * 1000 / permille
		_costs[base + 2][cell] = STRAIGHT * 1000 / up
		_costs[base + 3][cell] = DIAGONAL * 1000 / up


func passable(move_class: int, cell: int) -> bool:
	return blocked[cell] == 0 and _enter[move_class][terrain[cell]] > 0


## Speed per-mille of moving from `from_cell` into the neighbouring `to_cell`; 0 = cannot.
## from_cell NO_CELL means "climbing in from below".
func edge_permille(move_class: int, from_cell: int, to_cell: int) -> int:
	if blocked[to_cell] != 0:
		return 0
	var base := _enter[move_class][terrain[to_cell]]
	if base > 0 and (from_cell == NO_CELL or is_climb(from_cell, to_cell)):
		return base * _uphill[terrain[to_cell]] / 1000
	return base


## True when stepping from one cell into the other goes uphill (into a hill from flat ground).
func is_climb(from_cell: int, to_cell: int) -> bool:
	return _uphill[terrain[to_cell]] != 1000 and _uphill[terrain[from_cell]] == 1000


## Speed per-mille inside one cell (no climbing).
func cell_permille(move_class: int, cell: int) -> int:
	return _enter[move_class][terrain[cell]] if blocked[cell] == 0 else 0


## Fastest multiplier any terrain gives this class, for an admissible A* heuristic.
func best_permille(move_class: int) -> int:
	var best := 1
	for v in _enter[move_class]:
		best = maxi(best, v)
	return best


## The passable cell nearest to `cell` (itself if passable), searching square rings outward in
## a fixed order; NO_CELL if there is none within max_radius. Cells in `taken` are skipped.
func nearest_passable(
	move_class: int, cell: int, max_radius: int = 16, taken: Dictionary = {}
) -> int:
	if passable(move_class, cell) and not taken.has(cell):
		return cell
	var cx := cell % width
	var cy := cell / width
	for r in range(1, max_radius + 1):
		var best := NO_CELL
		var best_d := 1 << 30
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r or not in_bounds(cx + dx, cy + dy):
					continue
				var c := cell_at(cx + dx, cy + dy)
				var d := dx * dx + dy * dy
				if d < best_d and passable(move_class, c) and not taken.has(c):
					best = c
					best_d = d
		if best != NO_CELL:
			return best
	return NO_CELL


## Which connected area a cell belongs to for a movement class (-1 for closed cells). Two
## cells in different areas have no path between them, which the pathfinder checks before it
## searches. Diagonal steps need both sides open, so areas are 4-connected.
func area(move_class: int, cell: int) -> int:
	if _areas_version != version:
		_rebuild_areas()
	return _areas[move_class][cell]


## The cell of `area_id` nearest to `cell`, searching square rings outward; NO_CELL if none.
func nearest_in_area(move_class: int, area_id: int, cell: int) -> int:
	if area(move_class, cell) == area_id:
		return cell
	var areas := _areas[move_class]
	var cx := cell % width
	var cy := cell / width
	for r in range(1, maxi(width, height)):
		var best := NO_CELL
		var best_d := 1 << 30
		for dy in range(-r, r + 1):
			var y := cy + dy
			if y < 0 or y >= height:
				continue
			var step := 1 if absi(dy) == r else 2 * r
			for dx in range(-r, r + 1, step):
				var x := cx + dx
				if x < 0 or x >= width:
					continue
				var c := y * width + x
				var d := dx * dx + dy * dy
				if areas[c] == area_id and d < best_d:
					best = c
					best_d = d
		if best != NO_CELL:
			return best
	return NO_CELL


func _rebuild_areas() -> void:
	var n := cell_count()
	_areas.clear()
	var queue := PackedInt32Array()
	queue.resize(n)
	for cls in MOVE_CLASS_COUNT:
		var open := step_costs(cls, 0)
		var areas := PackedInt32Array()
		areas.resize(n)
		areas.fill(-1)
		var next_area := 0
		for start in n:
			if areas[start] != -1 or open[start] == 0:
				continue
			areas[start] = next_area
			var head := 0
			var tail := 1
			queue[0] = start
			while head < tail:
				var c := queue[head]
				head += 1
				var x := c % width
				for nb: int in [
					c - width, c + width, c - 1 if x > 0 else -1, c + 1 if x < width - 1 else -1
				]:
					if nb >= 0 and nb < n and areas[nb] == -1 and open[nb] != 0:
						areas[nb] = next_area
						queue[tail] = nb
						tail += 1
			next_area += 1
		_areas.append(areas)
	_areas_version = version


## SHA-256 of terrain and blockers, cached until the grid changes. Part of the state hash.
func content_hash() -> PackedByteArray:
	if _hash_version != version:
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		var head := PackedInt32Array([width, height, terrain_ids.size()])
		ctx.update(head.to_byte_array())
		for id in terrain_ids:
			ctx.update(String(id).to_utf8_buffer())
		ctx.update(terrain)
		ctx.update(blocked)
		_hash = ctx.finish()
		_hash_version = version
	return _hash


func _build_tables(terrains: Dictionary[StringName, TerrainDef]) -> void:
	_enter.clear()
	for c in MOVE_CLASS_COUNT:
		_enter.append(PackedInt32Array())
	_uphill.clear()
	for id in terrain_ids:
		var def: TerrainDef = terrains.get(id)
		var foot := 1000
		var cav := 1000
		var climb := 1000
		var no_siege := false
		if not terrains.is_empty():
			assert(def != null, "unknown terrain %s" % id)
			foot = def.infantry_permille if def.passable else 0
			cav = def.cavalry_permille if def.passable else 0
			climb = def.uphill_permille if def.passable else 1000
			no_siege = def.siege_blocked
		_enter[MoveClass.FOOT].append(foot)
		_enter[MoveClass.CAVALRY].append(cav)
		_enter[MoveClass.SIEGE].append(0 if no_siege else foot)
		# «Лес и болото без штрафа» (gdl_samogitian).
		var free := foot > 0 and (id == FOREST or id == BOG)
		_enter[MoveClass.FOREST_FOOT].append(1000 if free else foot)
		_uphill.append(climb)
