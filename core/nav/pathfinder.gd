class_name Pathfinder
extends RefCounted
## A* over a NavGrid for one unit: 8 directions, no cutting corners past impassable cells,
## step cost = length / terrain speed, so a unit takes the fastest route for its movement class
## (cavalry keeps to roads, forest walkers go through the forest, carts look for a ford).
## Integer costs and a heap that breaks ties by cell index make the result the same everywhere.

## Neighbour order: four sides first, then diagonals (N, E, S, W, NE, SE, SW, NW).
const DX: Array[int] = [0, 1, 0, -1, 1, 1, -1, -1]
const DY: Array[int] = [-1, 0, 1, 0, -1, 1, 1, -1]
## A* key packing: f in the high bits, h in the low 20 bits (lower h first on equal f).
const H_BITS := 20
const H_MASK := (1 << H_BITS) - 1
## How far the goal may be moved to the nearest passable cell.
const GOAL_SNAP_RADIUS := 16

var grid: NavGrid
## Cells expanded by the last search and by all searches, and the number of searches, for
## tests and benchmarks.
var last_expanded := 0
var total_expanded := 0
var searches := 0
## True when no search is open (the last one finished).
var done := true

var _g := PackedInt32Array()
var _parent := PackedInt32Array()
var _seen := PackedInt32Array()
var _closed := PackedInt32Array()
var _stamp := 0
var _heap := MinHeap.new()
# The open search: movement class, start, target, best cell so far and its heuristic, A* cost
# floors, and whether the target was reached.
var _s_class := 0
var _s_start := 0
var _s_target := 0
var _s_best := 0
var _s_best_h := 0
var _s_min_s := 0
var _s_min_d := 0
var _s_found := false


func _init(nav: NavGrid) -> void:
	grid = nav
	var n := nav.cell_count()
	_g.resize(n)
	_parent.resize(n)
	_seen.resize(n)
	_seen.fill(0)
	_closed.resize(n)
	_closed.fill(0)


## Cost of one step from a cell in direction dir (0..7), or 0 when the step is not allowed.
## The same rules as the search loops below, for tests and path costs.
static func step_cost(nav: NavGrid, move_class: int, from_cell: int, dir: int) -> int:
	var w := nav.width
	var cx := from_cell % w + DX[dir]
	var cy := from_cell / w + DY[dir]
	if not nav.in_bounds(cx, cy):
		return 0
	var to_cell := cy * w + cx
	var diag := 1 if dir >= 4 else 0
	if diag == 1:
		# A diagonal step needs both side cells open: no squeezing between two corners.
		var straight := nav.step_costs(move_class, 0)
		if straight[cy * w + from_cell % w] == 0 or straight[(from_cell / w) * w + cx] == 0:
			return 0
	var hills := nav.hill_cells()
	var kind := diag + (2 if hills[to_cell] == 1 and hills[from_cell] == 0 else 0)
	return nav.step_costs(move_class, kind)[to_cell]


static func neighbour(nav: NavGrid, cell: int, dir: int) -> int:
	return nav.cell_at(cell % nav.width + DX[dir], cell / nav.width + DY[dir])


## Cells to walk through from `start` (excluded) to `goal` (included). An impassable goal is
## moved to the nearest passable cell; when the goal cannot be reached, the path leads to the
## reachable cell closest to it (by straight distance). Empty when already there.
## The whole search at once; the simulation runs it in slices with begin() and resume().
func find_path(move_class: int, start: int, goal: int) -> PackedInt32Array:
	begin(move_class, start, goal)
	var expanded := 0
	while not done:
		expanded += resume(1 << 30)
	last_expanded = expanded
	return result()


## Starts a search that resume() carries on, a slice at a time. Only one search is open at once.
func begin(move_class: int, start: int, goal: int) -> void:
	var target := grid.nearest_passable(move_class, goal, GOAL_SNAP_RADIUS)
	if target == NavGrid.NO_CELL:
		target = goal
	var start_area := grid.area(move_class, start)
	if start_area >= 0 and grid.area(move_class, target) != start_area:
		# Across water or a thicket with no way round: aim for the closest reachable cell
		# instead of searching the whole area to find out.
		target = grid.nearest_in_area(move_class, start_area, target)
	last_expanded = 0
	_s_class = move_class
	_s_start = start
	_s_target = target
	_s_found = false
	done = start == target
	if done:
		return
	_stamp += 1
	var w := grid.width
	# Heuristic at open-ground speed, not the map's fastest: roads (x1,2) make it overestimate a
	# little, so a path may be up to 20% longer than the best one where roads matter, but the
	# search no longer floods every field when the map has a single road on it.
	_s_min_s = maxi(grid.min_step_cost(move_class, 0), NavGrid.STRAIGHT)
	_s_min_d = maxi(grid.min_step_cost(move_class, 1), NavGrid.DIAGONAL)
	_heap.clear()
	_g[start] = 0
	_parent[start] = NavGrid.NO_CELL
	_seen[start] = _stamp
	_s_best = start
	_s_best_h = _octile(start % w - target % w, start / w - target / w, _s_min_s, _s_min_d)
	_heap.push(_s_best_h << H_BITS | mini(_s_best_h, H_MASK), start)


## Expands up to `budget` cells of the open search; returns how many it expanded. `done` turns
## true when the search has finished.
func resume(budget: int) -> int:
	if done:
		return 0
	var stamp := _stamp
	var w := grid.width
	var h_max := grid.height - 1
	var w_max := w - 1
	var move_class := _s_class
	var straight := grid.step_costs(move_class, 0)
	var diagonal := grid.step_costs(move_class, 1)
	var climb_straight := grid.step_costs(move_class, 2)
	var climb_diagonal := grid.step_costs(move_class, 3)
	var hills := grid.hill_cells()
	var min_s := _s_min_s
	var min_d := _s_min_d
	var target := _s_target
	var tx := target % w
	var ty := target / w
	var g := _g
	var parent := _parent
	var seen := _seen
	var closed := _closed
	var heap := _heap
	var best := _s_best
	var best_h := _s_best_h
	var found := false
	var expanded := 0
	while not heap.is_empty() and expanded < budget:
		var cur := heap.pop()
		if closed[cur] == stamp:
			continue
		closed[cur] = stamp
		expanded += 1
		if cur == target:
			found = true
			break
		var cx := cur % w
		var cy := cur / w
		var cur_h := _octile(cx - tx, cy - ty, min_s, min_d)
		if cur_h < best_h or (cur_h == best_h and g[cur] < g[best]):
			best = cur
			best_h = cur_h
		var cur_g := g[cur]
		var low := hills[cur] == 0
		var nb: int
		var cost: int
		var ng: int
		var dx: int
		var dy: int
		var h: int
		# Which sides exist and are open; diagonals need both of their sides.
		var n_ok := cy > 0 and straight[cur - w] > 0
		var e_ok := cx < w_max and straight[cur + 1] > 0
		var s_ok := cy < h_max and straight[cur + w] > 0
		var w_ok := cx > 0 and straight[cur - 1] > 0
		# The eight neighbours, written out (N, E, S, W, NE, SE, SW, NW): a loop with a match
		# per step costs about twice as much in GDScript. Each block is the same relaxation.
		if n_ok:
			nb = cur - w
			if closed[nb] != stamp:
				cost = climb_straight[nb] if low and hills[nb] == 1 else straight[nb]
				ng = cur_g + cost
				if cost > 0 and (seen[nb] != stamp or ng < g[nb]):
					seen[nb] = stamp
					g[nb] = ng
					parent[nb] = cur
					dx = absi(nb % w - tx)
					dy = absi(nb / w - ty)
					h = (
						dx * min_d + (dy - dx) * min_s
						if dx < dy
						else dy * min_d + (dx - dy) * min_s
					)
					heap.push((ng + h) << H_BITS | mini(h, H_MASK), nb)
		if e_ok:
			nb = cur + 1
			if closed[nb] != stamp:
				cost = climb_straight[nb] if low and hills[nb] == 1 else straight[nb]
				ng = cur_g + cost
				if cost > 0 and (seen[nb] != stamp or ng < g[nb]):
					seen[nb] = stamp
					g[nb] = ng
					parent[nb] = cur
					dx = absi(nb % w - tx)
					dy = absi(nb / w - ty)
					h = (
						dx * min_d + (dy - dx) * min_s
						if dx < dy
						else dy * min_d + (dx - dy) * min_s
					)
					heap.push((ng + h) << H_BITS | mini(h, H_MASK), nb)
		if s_ok:
			nb = cur + w
			if closed[nb] != stamp:
				cost = climb_straight[nb] if low and hills[nb] == 1 else straight[nb]
				ng = cur_g + cost
				if cost > 0 and (seen[nb] != stamp or ng < g[nb]):
					seen[nb] = stamp
					g[nb] = ng
					parent[nb] = cur
					dx = absi(nb % w - tx)
					dy = absi(nb / w - ty)
					h = (
						dx * min_d + (dy - dx) * min_s
						if dx < dy
						else dy * min_d + (dx - dy) * min_s
					)
					heap.push((ng + h) << H_BITS | mini(h, H_MASK), nb)
		if w_ok:
			nb = cur - 1
			if closed[nb] != stamp:
				cost = climb_straight[nb] if low and hills[nb] == 1 else straight[nb]
				ng = cur_g + cost
				if cost > 0 and (seen[nb] != stamp or ng < g[nb]):
					seen[nb] = stamp
					g[nb] = ng
					parent[nb] = cur
					dx = absi(nb % w - tx)
					dy = absi(nb / w - ty)
					h = (
						dx * min_d + (dy - dx) * min_s
						if dx < dy
						else dy * min_d + (dx - dy) * min_s
					)
					heap.push((ng + h) << H_BITS | mini(h, H_MASK), nb)
		if n_ok and e_ok:
			nb = cur - w + 1
			if closed[nb] != stamp:
				cost = climb_diagonal[nb] if low and hills[nb] == 1 else diagonal[nb]
				ng = cur_g + cost
				if cost > 0 and (seen[nb] != stamp or ng < g[nb]):
					seen[nb] = stamp
					g[nb] = ng
					parent[nb] = cur
					dx = absi(nb % w - tx)
					dy = absi(nb / w - ty)
					h = (
						dx * min_d + (dy - dx) * min_s
						if dx < dy
						else dy * min_d + (dx - dy) * min_s
					)
					heap.push((ng + h) << H_BITS | mini(h, H_MASK), nb)
		if s_ok and e_ok:
			nb = cur + w + 1
			if closed[nb] != stamp:
				cost = climb_diagonal[nb] if low and hills[nb] == 1 else diagonal[nb]
				ng = cur_g + cost
				if cost > 0 and (seen[nb] != stamp or ng < g[nb]):
					seen[nb] = stamp
					g[nb] = ng
					parent[nb] = cur
					dx = absi(nb % w - tx)
					dy = absi(nb / w - ty)
					h = (
						dx * min_d + (dy - dx) * min_s
						if dx < dy
						else dy * min_d + (dx - dy) * min_s
					)
					heap.push((ng + h) << H_BITS | mini(h, H_MASK), nb)
		if s_ok and w_ok:
			nb = cur + w - 1
			if closed[nb] != stamp:
				cost = climb_diagonal[nb] if low and hills[nb] == 1 else diagonal[nb]
				ng = cur_g + cost
				if cost > 0 and (seen[nb] != stamp or ng < g[nb]):
					seen[nb] = stamp
					g[nb] = ng
					parent[nb] = cur
					dx = absi(nb % w - tx)
					dy = absi(nb / w - ty)
					h = (
						dx * min_d + (dy - dx) * min_s
						if dx < dy
						else dy * min_d + (dx - dy) * min_s
					)
					heap.push((ng + h) << H_BITS | mini(h, H_MASK), nb)
		if n_ok and w_ok:
			nb = cur - w - 1
			if closed[nb] != stamp:
				cost = climb_diagonal[nb] if low and hills[nb] == 1 else diagonal[nb]
				ng = cur_g + cost
				if cost > 0 and (seen[nb] != stamp or ng < g[nb]):
					seen[nb] = stamp
					g[nb] = ng
					parent[nb] = cur
					dx = absi(nb % w - tx)
					dy = absi(nb / w - ty)
					h = (
						dx * min_d + (dy - dx) * min_s
						if dx < dy
						else dy * min_d + (dx - dy) * min_s
					)
					heap.push((ng + h) << H_BITS | mini(h, H_MASK), nb)
	_s_best = best
	_s_best_h = best_h
	total_expanded += expanded
	if found or heap.is_empty():
		_s_found = found
		done = true
		searches += 1
	return expanded


## The path of the finished search.
func result() -> PackedInt32Array:
	if _s_start == _s_target:
		return PackedInt32Array()
	return _trace(_s_target if _s_found else _s_best, _s_start)


## Total cost of walking a path from `start`, in path-cost units (100 per open cell).
func path_cost(move_class: int, start: int, path: PackedInt32Array) -> int:
	var total := 0
	var prev := start
	for cell in path:
		var dir := _dir_between(prev, cell)
		assert(dir >= 0, "path cells are not neighbours")
		total += step_cost(grid, move_class, prev, dir)
		prev = cell
	return total


func _dir_between(a: int, b: int) -> int:
	var dx := b % grid.width - a % grid.width
	var dy := b / grid.width - a / grid.width
	for dir in 8:
		if DX[dir] == dx and DY[dir] == dy:
			return dir
	return -1


## Octile distance at the given step costs.
static func _octile(dx: int, dy: int, min_s: int, min_d: int) -> int:
	dx = absi(dx)
	dy = absi(dy)
	if dx < dy:
		return dx * min_d + (dy - dx) * min_s
	return dy * min_d + (dx - dy) * min_s


func _trace(end: int, start: int) -> PackedInt32Array:
	var path := PackedInt32Array()
	var cur := end
	while cur != start and cur != NavGrid.NO_CELL:
		path.append(cur)
		cur = _parent[cur]
	path.reverse()
	return path
