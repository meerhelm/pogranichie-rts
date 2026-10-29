class_name Separation
extends RefCounted
## Keeps units from standing on each other (M3): every tick units closer than their bodies allow
## push each other apart. Two walkers that meet head-on also step aside to their right, so a
## side's peasants going to the forest and coming back slip past each other. Split out of
## Simulation; holds only scratch arrays, nothing of the world's state.

## Body width of a man on foot (fixed units). Two units closer than the mean of their bodies
## push each other apart, a quarter of the overlap a tick. 3/4 since the pixel sprites (0.3.0):
## they are as tall as the Blender men but wider, a half cell let them heap up.
const SEPARATION := Fixed.ONE * 3 / 4
## Body width of a rider (a horse is longer than a man is wide); a cell, as big as the pixel
## horses, and no more, or two riders would stand out of each other's melee reach.
const BODY_CAVALRY := Fixed.ONE
## Body width of a cart, a gun or a boat.
const BODY_LARGE := Fixed.ONE
## However they were ordered, two bodies never overlap by more than a half: units closer than
## this share of their mean body are set apart at once, whatever they are doing.
const MAX_OVERLAP_NUM := 1
const MAX_OVERLAP_DEN := 2
## Two walking units that meet head-on each step this far a tick to their own right (fixed
## units), so they slip past each other instead of pushing back and forth in place.
const SIDESTEP := Fixed.ONE / 32
## Within this distance of its target a moving unit is not pushed and pushes nobody.
const SETTLE_DISTANCE := Fixed.ONE * 3 / 2

var entities: EntityStore
var _max_x := 0
var _max_y := 0
# Scratch arrays, kept between ticks to avoid reallocating.
var _sep_head := PackedInt32Array()
var _sep_next := PackedInt32Array()
var _sep_cell := PackedInt32Array()
var _push_x := PackedInt64Array()
var _push_y := PackedInt64Array()
var _side_x := PackedInt64Array()
var _side_y := PackedInt64Array()
var _body := PackedInt64Array()


## Units closer than their mean body (body_of) push each other apart, a quarter of the overlap
## each per tick: walking units among themselves and standing units among themselves. A
## walking unit passes standing ones without shoving them, so a formation that has arrived keeps
## its slots while the rest of the group files in; but in a fight (either has a target) bodies
## push whatever the orders, so a melee does not heap up. Bodies overlapping by more than
## MAX_OVERLAP are set apart in full at once, but for a walker passing a standing unit out of a
## fight: it goes through, so one man standing on a bridge does not shut it. Two walking units
## meeting head-on also sidestep to their right (SIDESTEP), or they would push each other back
## in place until they give up. Pushes are summed first and applied after, in id order, never
## into a closed cell.
func run(e: EntityStore, nav: NavGrid) -> void:
	entities = e
	_max_x = nav.width * Fixed.ONE - 1
	_max_y = nav.height * Fixed.ONE - 1
	var n := e.next_id - 1
	if _sep_head.size() != nav.cell_count():
		_sep_head.resize(nav.cell_count())
	_sep_head.fill(0)
	_sep_next.resize(n)
	_sep_cell.resize(n)
	_push_x.resize(n)
	_push_x.fill(0)
	_push_y.resize(n)
	_push_y.fill(0)
	_side_x.resize(n)
	_side_x.fill(0)
	_side_y.resize(n)
	_side_y.fill(0)
	_body.resize(n)
	# Bucket units by cell: _sep_head[cell] is the last id put there, _sep_next chains the rest.
	for id in e.alive_ids:
		var cell := nav.cell_of(e.pos_x[id - 1], e.pos_y[id - 1])
		_sep_cell[id - 1] = cell
		_body[id - 1] = body_of(e.move_class[id - 1])
		_sep_next[id - 1] = _sep_head[cell]
		_sep_head[cell] = id
	var w := nav.width
	for id in e.alive_ids:
		var a := id - 1
		var cell := _sep_cell[a]
		var cx := cell % w
		var cy := cell / w
		for ny in range(maxi(cy - 1, 0), mini(cy + 2, nav.height)):
			for nx in range(maxi(cx - 1, 0), mini(cx + 2, w)):
				var other := _sep_head[ny * w + nx]
				while other != 0:
					if other > id:
						_push_pair(a, other - 1)
					other = _sep_next[other - 1]
	for id in e.alive_ids:
		var slot := id - 1
		var sx := _side_x[slot]
		var sy := _side_y[slot]
		if _push_x[slot] == 0 and _push_y[slot] == 0 and sx == 0 and sy == 0:
			continue
		# A sidestep blocked by trees or water is tried to the other side, then dropped.
		for side: int in [1, -1, 0]:
			var nx := clampi(e.pos_x[slot] + _push_x[slot] + sx * side, 0, _max_x)
			var ny := clampi(e.pos_y[slot] + _push_y[slot] + sy * side, 0, _max_y)
			if nav.passable(e.move_class[slot], nav.cell_of(nx, ny)):
				e.pos_x[slot] = nx
				e.pos_y[slot] = ny
				break
			if sx == 0 and sy == 0:
				break


## Body width of a unit of move class `move_class` (fixed units).
static func body_of(move_class: int) -> int:
	match move_class:
		NavGrid.MoveClass.CAVALRY:
			return BODY_CAVALRY
		NavGrid.MoveClass.SIEGE, NavGrid.MoveClass.BOAT:
			return BODY_LARGE
	return SEPARATION


## The nearest two units of these move classes may stand (fixed units): half their mean body,
## so they overlap by at most MAX_OVERLAP.
static func min_distance(class_a: int, class_b: int) -> int:
	var mean := (body_of(class_a) + body_of(class_b)) / 2
	return mean * (MAX_OVERLAP_DEN - MAX_OVERLAP_NUM) / MAX_OVERLAP_DEN


func _push_pair(a: int, b: int) -> void:
	var e := entities
	var dx := e.pos_x[b] - e.pos_x[a]
	var dy := e.pos_y[b] - e.pos_y[a]
	var sep := (_body[a] + _body[b]) / 2
	if absi(dx) >= sep or absi(dy) >= sep:
		return
	var d2 := dx * dx + dy * dy
	if d2 >= sep * sep:
		return
	var d := Fixed.isqrt(d2)
	var amount := (sep - d) / 4
	var least := sep * (MAX_OVERLAP_DEN - MAX_OVERLAP_NUM) / MAX_OVERLAP_DEN
	# Overlapping by more than MAX_OVERLAP: each takes half the way back out (and a little more,
	# so a crowd pushing from all sides does not leave it just short), on top.
	var hard := (least + least / 8 - d) / 2 if d < least else 0
	if d == 0:
		# Same spot: split along a direction picked from the ids, the same on every machine.
		var dir := (a + b) % 4
		dx = Pathfinder.DX[dir] * Fixed.ONE
		dy = Pathfinder.DY[dir] * Fixed.ONE
		d = Fixed.ONE
	var a_moves := e.orders[a] == EntityStore.Order.MOVE
	var b_moves := e.orders[b] == EntityStore.Order.MOVE
	var soft := true
	if e.target[a] == EntityStore.NO_ID and e.target[b] == EntityStore.NO_ID:
		if a_moves != b_moves:
			# Out of a fight a walker goes through standing units (a formation keeps its slots,
			# a bridge or a lane between trees is not shut by one man standing on it).
			return
		if a_moves and (_settling(a) or _settling(b)):
			# Stepping into its slot: slots are a cell apart, so let it through.
			soft = false
	if not soft:
		amount = 0
	amount += hard
	if amount == 0:
		return
	var px := dx * amount / d
	var py := dy * amount / d
	_push_x[a] -= px
	_push_y[a] -= py
	_push_x[b] += px
	_push_y[b] += py
	if soft and a_moves and b_moves and _head_on(a, b, dx, dy):
		_side_x[a] = -e.facing_y[a] * SIDESTEP / Fixed.ONE
		_side_y[a] = e.facing_x[a] * SIDESTEP / Fixed.ONE
		_side_x[b] = -e.facing_y[b] * SIDESTEP / Fixed.ONE
		_side_y[b] = e.facing_x[b] * SIDESTEP / Fixed.ONE


## Whether two walking units come at each other: they face opposite ways and each has the
## other ahead of it (`dx`, `dy`: from a to b). Then each steps to its own right.
func _head_on(a: int, b: int, dx: int, dy: int) -> bool:
	var e := entities
	var ax := e.facing_x[a]
	var ay := e.facing_y[a]
	var bx := e.facing_x[b]
	var by := e.facing_y[b]
	return ax * bx + ay * by < 0 and ax * dx + ay * dy > 0 and bx * dx + by * dy < 0


## A moving unit this close to its target is taking its place in the formation.
func _settling(slot: int) -> bool:
	var e := entities
	var dx := absi(e.target_x[slot] - e.pos_x[slot])
	var dy := absi(e.target_y[slot] - e.pos_y[slot])
	return maxi(dx, dy) < SETTLE_DISTANCE
