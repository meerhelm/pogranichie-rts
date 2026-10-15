class_name Iso
extends RefCounted
## Cell <-> screen conversion for the isometric view. The simulation's grid is square; only
## drawing is isometric: a cell is a 2:1 diamond, x runs down-right and y down-left on screen.
## Matches TileMapLayer with TILE_SHAPE_ISOMETRIC and TILE_LAYOUT_DIAMOND_DOWN.
## Floats are fine here: rendering never writes back into the simulation.

const TILE_W := 64
const TILE_H := 32
const HALF_W := TILE_W / 2.0
const HALF_H := TILE_H / 2.0


## Screen position of a point in cell units (cell (0, 0) spans 0..1 on both axes).
static func cell_to_screen(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * HALF_W, (cell.x + cell.y) * HALF_H)


static func screen_to_cell(p: Vector2) -> Vector2:
	var a := p.x / HALF_W
	var b := p.y / HALF_H
	return Vector2((a + b) / 2.0, (b - a) / 2.0)


static func fixed_to_screen(x: int, y: int) -> Vector2:
	return cell_to_screen(Vector2(float(x) / Fixed.ONE, float(y) / Fixed.ONE))


## The simulation point under a screen position (rounded down to fixed units).
static func screen_to_fixed(p: Vector2) -> Vector2i:
	var c := screen_to_cell(p)
	return Vector2i(floori(c.x * Fixed.ONE), floori(c.y * Fixed.ONE))


## Cell index pair (column, row) under a screen position.
static func screen_to_cell_index(p: Vector2) -> Vector2i:
	var c := screen_to_cell(p)
	return Vector2i(floori(c.x), floori(c.y))


## Screen rectangle around a map of w x h cells (a diamond inside it).
static func map_rect(w: int, h: int) -> Rect2:
	var left := cell_to_screen(Vector2(0, h)).x
	var right := cell_to_screen(Vector2(w, 0)).x
	var bottom := cell_to_screen(Vector2(w, h)).y
	return Rect2(left, 0.0, right - left, bottom)
