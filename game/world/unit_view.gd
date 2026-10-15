class_name UnitView
extends Node2D
## Placeholder unit sprite: shadow, a body in the owner's colour shaped by kind (circle for
## foot, wide oval for horse, box for carts), a tick showing which of 8 directions it faces,
## and a ring when selected. Position is set by UnitLayer, interpolated between ticks.

const PLAYER_COLORS: Array[Color] = [
	Color(0.7, 0.7, 0.7), Color(0.85, 0.2, 0.15), Color(0.95, 0.95, 0.9), Color(0.2, 0.4, 0.9)
]
const RADIUS := 7.0

var unit_id: int
var player: int
var move_class: int
var type_id: StringName
var selected := false:
	set(value):
		if selected != value:
			selected = value
			queue_redraw()
## Screen direction in 8 steps: 0 east, 2 south, 4 west, 6 north (clockwise, y down).
var facing := 2:
	set(value):
		if facing != value:
			facing = value
			queue_redraw()


func _draw() -> void:
	var body := PLAYER_COLORS[player % PLAYER_COLORS.size()]
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, RADIUS + 3.0, Color(0, 0, 0, 0.3))
	if selected:
		draw_arc(Vector2.ZERO, RADIUS + 5.0, 0.0, TAU, 32, Color(0.4, 1.0, 0.4), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var center := Vector2(0, -RADIUS)
	match move_class:
		NavGrid.MoveClass.CAVALRY:
			draw_set_transform(center, 0.0, Vector2(1.5, 1.0))
			draw_circle(Vector2.ZERO, RADIUS, body)
			draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, Color.BLACK, 1.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		NavGrid.MoveClass.SIEGE:
			var r := Rect2(
				center - Vector2(RADIUS, RADIUS * 0.8), Vector2(RADIUS * 2, RADIUS * 1.6)
			)
			draw_rect(r, body)
			draw_rect(r, Color.BLACK, false, 1.0)
		_:
			draw_circle(center, RADIUS, body)
			draw_arc(center, RADIUS, 0.0, TAU, 24, Color.BLACK, 1.0)
	var dir := Vector2.from_angle(facing * PI / 4.0)
	draw_line(center, center + dir * (RADIUS + 4.0), Color.BLACK, 2.0)


## Faces the direction of a move in grid units.
func face(dx: int, dy: int) -> void:
	if dx == 0 and dy == 0:
		return
	# Snap to 8 directions in screen space, so sprites (rendered in 8 directions) match.
	var screen := Iso.cell_to_screen(Vector2(dx, dy))
	var octant := wrapi(roundi(screen.angle() / (PI / 4.0)), 0, 8)
	facing = octant
