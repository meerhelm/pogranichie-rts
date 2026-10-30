class_name WorkSpots
extends RefCounted
## Where a worker stands to work on a rectangle of cells (a building, a deposit), split out of
## EconomySystem. Peasants sent to one small deposit take different cells round it, so they do
## not stand on each other, push each other out of reach and walk back and forth.

## A cell another worker on the same thing already stands on or walks to counts as this much
## further away (fixed units): more than the whole ring round a deposit, so any free cell of
## the ring comes first, and a crowd bigger than the ring shares the cells evenly.
const TAKEN := Fixed.ONE * 4


## On the rectangle if it can be walked on (the cell of it nearest to the unit), else the
## nearest open cell round it within `rings` rings, nearest to the unit, ties by cell index;
## each worker's cell in `taken` (one entry per worker) counts as TAKEN further.
static func stand_point(
	e: EntityStore,
	nav: NavGrid,
	id: int,
	rect: Rect2i,
	blocking: bool,
	rings: int,
	taken: PackedInt32Array = PackedInt32Array()
) -> Vector2i:
	var px := e.pos_x[id - 1]
	var py := e.pos_y[id - 1]
	var x0 := rect.position.x
	var y0 := rect.position.y
	var w := rect.size.x
	var h := rect.size.y
	if not blocking:
		var cx := clampi(Fixed.to_cells(px), x0, x0 + w - 1)
		var cy := clampi(Fixed.to_cells(py), y0, y0 + h - 1)
		var c := nav.cell_at(cx, cy)
		return Vector2i(nav.center_x(c), nav.center_y(c))
	var cls: int = e.move_class[id - 1]
	for r in range(1, rings + 1):
		var best := NavGrid.NO_CELL
		var best_d := 0
		for y in range(y0 - r, y0 + h + r):
			for x in range(x0 - r, x0 + w + r):
				var ring := x == x0 - r or x == x0 + w + r - 1 or y == y0 - r or y == y0 + h + r - 1
				if not ring or not nav.in_bounds(x, y):
					continue
				var c := nav.cell_at(x, y)
				if not nav.passable(cls, c):
					continue
				var d := Fixed.distance(px, py, nav.center_x(c), nav.center_y(c))
				for t in taken:
					if t == c:
						d += TAKEN
				if best == NavGrid.NO_CELL or d < best_d:
					best = c
					best_d = d
		if best != NavGrid.NO_CELL:
			return Vector2i(nav.center_x(best), nav.center_y(best))
	return Vector2i(Fixed.from_cells(x0) + Fixed.HALF, Fixed.from_cells(y0) + Fixed.HALF)


## Squared distance (fixed units) from a point to the nearest edge of a rectangle of cells;
## 0 inside it.
static func rect_distance_sq(px: int, py: int, x0: int, y0: int, w: int, h: int) -> int:
	var ax := Fixed.from_cells(x0)
	var ay := Fixed.from_cells(y0)
	var dx := maxi(maxi(ax - px, 0), px - (ax + Fixed.from_cells(w)))
	var dy := maxi(maxi(ay - py, 0), py - (ay + Fixed.from_cells(h)))
	return dx * dx + dy * dy
