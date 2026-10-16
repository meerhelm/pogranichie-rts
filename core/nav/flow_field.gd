class_name FlowField
extends RefCounted
## Shared route for a big group (8 units and more): one Dijkstra from the goal gives every
## cell the next cell toward it, so the group needs one search instead of one per unit.
## The search stops once every cell the group stands on is settled.

var grid: NavGrid
var move_class: int
## The group's player: its own gates are open to it.
var player := 0
var goal: int
## Grid closing_version the field was built for; a closed or slower cell makes it stale.
var version: int
## Next cell toward the goal; NO_CELL at the goal and where the search did not reach.
var next := PackedInt32Array()
## Cost to the goal in path-cost units; -1 where not reached.
var dist := PackedInt32Array()

## True once every starting cell is settled (or nothing more can be reached). The simulation
## builds a field a slice at a time (build()); its units wait until then.
var done := false

# The open search: settled cells, the frontier, starting cells not settled yet and the box
# around the starting cells (the heuristic aims at it).
var _settled := PackedByteArray()
var _heap := MinHeap.new()
var _waiting := {}
var _bx0 := 0
var _by0 := 0
var _bx1 := -1
var _by1 := -1


func _init(
	nav: NavGrid, p_move_class: int, goal_cell: int, starts: PackedInt32Array, p_player: int = 0
) -> void:
	grid = nav
	move_class = p_move_class
	player = p_player
	goal = goal_cell
	version = nav.closing_version
	var n := nav.cell_count()
	next.resize(n)
	next.fill(NavGrid.NO_CELL)
	dist.resize(n)
	dist.fill(-1)
	var w := grid.width
	_bx0 = w
	_by0 = grid.height
	for c in starts:
		_waiting[c] = true
		_bx0 = mini(_bx0, c % w)
		_bx1 = maxi(_bx1, c % w)
		_by0 = mini(_by0, c / w)
		_by1 = maxi(_by1, c / w)
	done = _waiting.is_empty()
	if done:
		return
	_settled.resize(n)
	_settled.fill(0)
	dist[goal] = 0
	_heap.push(0, goal)


func reached(cell: int) -> bool:
	return dist[cell] >= 0


func is_stale() -> bool:
	return version != grid.closing_version


## Dijkstra from the goal outward, steered toward the group (A* with the distance to the box
## around the starting cells as heuristic), until every starting cell is settled. With a
## consistent heuristic each settled cell has its true cost, so only a corridor between the
## goal and the group is searched instead of the whole map. Settles up to `budget` cells and
## returns how many it settled.
func build(budget: int) -> int:
	if done:
		return 0
	var w := grid.width
	var w_max := w - 1
	var h_max := grid.height - 1
	var waiting := _waiting
	var bx0 := _bx0
	var by0 := _by0
	var bx1 := _bx1
	var by1 := _by1
	var straight := grid.step_costs_for(player, move_class, 0)
	var diagonal := grid.step_costs_for(player, move_class, 1)
	var climb_straight := grid.step_costs_for(player, move_class, 2)
	var climb_diagonal := grid.step_costs_for(player, move_class, 3)
	var hills := grid.hill_cells()
	var min_s := grid.min_step_cost(move_class, 0)
	var min_d := grid.min_step_cost(move_class, 1)
	var settled := _settled
	var heap := _heap
	var count := 0
	while not heap.is_empty() and count < budget:
		var b := heap.pop()
		if settled[b] == 1:
			continue
		settled[b] = 1
		count += 1
		if waiting.erase(b) and waiting.is_empty():
			break
		var cx := b % w
		var cy := b / w
		var high := hills[b] == 1
		# Neighbours a that are open; a diagonal neighbour also needs both shared sides open.
		var n_ok := cy > 0 and straight[b - w] > 0
		var e_ok := cx < w_max and straight[b + 1] > 0
		var s_ok := cy < h_max and straight[b + w] > 0
		var w_ok := cx > 0 and straight[b - 1] > 0
		# The eight neighbours written out, as in Pathfinder.find_path. The unit steps from a
		# into b, so the cost is b's, climbing if b is a hill and a is not.
		var db := dist[b]
		var a: int
		var nd: int
		var ax: int
		var ay: int
		var dx: int
		var dy: int
		var h: int
		if n_ok:
			a = b - w
			if settled[a] == 0 and straight[a] > 0:
				nd = db + (climb_straight[b] if high and hills[a] == 0 else straight[b])
				if dist[a] < 0 or nd < dist[a]:
					dist[a] = nd
					next[a] = b
					ax = a % w
					ay = a / w
					dx = 0 if ax >= bx0 and ax <= bx1 else mini(absi(ax - bx0), absi(ax - bx1))
					dy = 0 if ay >= by0 and ay <= by1 else mini(absi(ay - by0), absi(ay - by1))
					h = (
						dx * min_d + (dy - dx) * min_s
						if dx < dy
						else dy * min_d + (dx - dy) * min_s
					)
					heap.push((nd + h) << Pathfinder.H_BITS | mini(h, Pathfinder.H_MASK), a)
		if e_ok:
			a = b + 1
			if settled[a] == 0 and straight[a] > 0:
				nd = db + (climb_straight[b] if high and hills[a] == 0 else straight[b])
				if dist[a] < 0 or nd < dist[a]:
					dist[a] = nd
					next[a] = b
					ax = a % w
					ay = a / w
					dx = 0 if ax >= bx0 and ax <= bx1 else mini(absi(ax - bx0), absi(ax - bx1))
					dy = 0 if ay >= by0 and ay <= by1 else mini(absi(ay - by0), absi(ay - by1))
					h = (
						dx * min_d + (dy - dx) * min_s
						if dx < dy
						else dy * min_d + (dx - dy) * min_s
					)
					heap.push((nd + h) << Pathfinder.H_BITS | mini(h, Pathfinder.H_MASK), a)
		if s_ok:
			a = b + w
			if settled[a] == 0 and straight[a] > 0:
				nd = db + (climb_straight[b] if high and hills[a] == 0 else straight[b])
				if dist[a] < 0 or nd < dist[a]:
					dist[a] = nd
					next[a] = b
					ax = a % w
					ay = a / w
					dx = 0 if ax >= bx0 and ax <= bx1 else mini(absi(ax - bx0), absi(ax - bx1))
					dy = 0 if ay >= by0 and ay <= by1 else mini(absi(ay - by0), absi(ay - by1))
					h = (
						dx * min_d + (dy - dx) * min_s
						if dx < dy
						else dy * min_d + (dx - dy) * min_s
					)
					heap.push((nd + h) << Pathfinder.H_BITS | mini(h, Pathfinder.H_MASK), a)
		if w_ok:
			a = b - 1
			if settled[a] == 0 and straight[a] > 0:
				nd = db + (climb_straight[b] if high and hills[a] == 0 else straight[b])
				if dist[a] < 0 or nd < dist[a]:
					dist[a] = nd
					next[a] = b
					ax = a % w
					ay = a / w
					dx = 0 if ax >= bx0 and ax <= bx1 else mini(absi(ax - bx0), absi(ax - bx1))
					dy = 0 if ay >= by0 and ay <= by1 else mini(absi(ay - by0), absi(ay - by1))
					h = (
						dx * min_d + (dy - dx) * min_s
						if dx < dy
						else dy * min_d + (dx - dy) * min_s
					)
					heap.push((nd + h) << Pathfinder.H_BITS | mini(h, Pathfinder.H_MASK), a)
		if n_ok and e_ok:
			a = b - w + 1
			if settled[a] == 0 and straight[a] > 0:
				nd = db + (climb_diagonal[b] if high and hills[a] == 0 else diagonal[b])
				if dist[a] < 0 or nd < dist[a]:
					dist[a] = nd
					next[a] = b
					ax = a % w
					ay = a / w
					dx = 0 if ax >= bx0 and ax <= bx1 else mini(absi(ax - bx0), absi(ax - bx1))
					dy = 0 if ay >= by0 and ay <= by1 else mini(absi(ay - by0), absi(ay - by1))
					h = (
						dx * min_d + (dy - dx) * min_s
						if dx < dy
						else dy * min_d + (dx - dy) * min_s
					)
					heap.push((nd + h) << Pathfinder.H_BITS | mini(h, Pathfinder.H_MASK), a)
		if s_ok and e_ok:
			a = b + w + 1
			if settled[a] == 0 and straight[a] > 0:
				nd = db + (climb_diagonal[b] if high and hills[a] == 0 else diagonal[b])
				if dist[a] < 0 or nd < dist[a]:
					dist[a] = nd
					next[a] = b
					ax = a % w
					ay = a / w
					dx = 0 if ax >= bx0 and ax <= bx1 else mini(absi(ax - bx0), absi(ax - bx1))
					dy = 0 if ay >= by0 and ay <= by1 else mini(absi(ay - by0), absi(ay - by1))
					h = (
						dx * min_d + (dy - dx) * min_s
						if dx < dy
						else dy * min_d + (dx - dy) * min_s
					)
					heap.push((nd + h) << Pathfinder.H_BITS | mini(h, Pathfinder.H_MASK), a)
		if s_ok and w_ok:
			a = b + w - 1
			if settled[a] == 0 and straight[a] > 0:
				nd = db + (climb_diagonal[b] if high and hills[a] == 0 else diagonal[b])
				if dist[a] < 0 or nd < dist[a]:
					dist[a] = nd
					next[a] = b
					ax = a % w
					ay = a / w
					dx = 0 if ax >= bx0 and ax <= bx1 else mini(absi(ax - bx0), absi(ax - bx1))
					dy = 0 if ay >= by0 and ay <= by1 else mini(absi(ay - by0), absi(ay - by1))
					h = (
						dx * min_d + (dy - dx) * min_s
						if dx < dy
						else dy * min_d + (dx - dy) * min_s
					)
					heap.push((nd + h) << Pathfinder.H_BITS | mini(h, Pathfinder.H_MASK), a)
		if n_ok and w_ok:
			a = b - w - 1
			if settled[a] == 0 and straight[a] > 0:
				nd = db + (climb_diagonal[b] if high and hills[a] == 0 else diagonal[b])
				if dist[a] < 0 or nd < dist[a]:
					dist[a] = nd
					next[a] = b
					ax = a % w
					ay = a / w
					dx = 0 if ax >= bx0 and ax <= bx1 else mini(absi(ax - bx0), absi(ax - bx1))
					dy = 0 if ay >= by0 and ay <= by1 else mini(absi(ay - by0), absi(ay - by1))
					h = (
						dx * min_d + (dy - dx) * min_s
						if dx < dy
						else dy * min_d + (dx - dy) * min_s
					)
					heap.push((nd + h) << Pathfinder.H_BITS | mini(h, Pathfinder.H_MASK), a)
	if waiting.is_empty() or heap.is_empty():
		done = true
		# The search is over: free its working arrays.
		_settled = PackedByteArray()
		heap.clear()
	return count
