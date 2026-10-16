class_name BoxView
extends Node2D
## One tall placeholder object on the map (a building or a deposit that blocks its cells),
## drawn as a raised box. Lives among the unit views in the y-sorted UnitLayer, so a unit
## behind a building is hidden by it and a unit in front covers it. The node sits at the
## screen point of the footprint's centre: for a square footprint a unit next to a back face
## sorts behind, next to a front face in front. BuildingLayer fills and updates it.

## Footprint in cells, relative to the centre (the node's position).
var cells := Rect2()
var color := Color.WHITE
## Screen height of the top above the ground.
var height := 0.0
var outlined := false
## HP bar fill 0..1; below zero means no bar.
var hp := -1.0
## On fire (M9): HP fraction for the flames, below zero when not burning; and the tick they
## flicker with.
var fire := -1.0
var fire_tick := 0


func set_box(
	p_cells: Rect2, p_color: Color, p_height: float, p_outlined: bool, p_hp: float
) -> void:
	var centre := p_cells.get_center()
	position = Iso.cell_to_screen(centre)
	var local := Rect2(p_cells.position - centre, p_cells.size)
	if (
		local == cells
		and p_color == color
		and p_height == height
		and p_outlined == outlined
		and p_hp == hp
	):
		return
	cells = local
	color = p_color
	height = p_height
	outlined = p_outlined
	hp = p_hp
	queue_redraw()


## Flames flicker every tick while the building burns.
func set_fire(p_fire: float, tick: int) -> void:
	if p_fire < 0.0 and fire < 0.0:
		return
	fire = p_fire
	fire_tick = tick
	queue_redraw()


func _draw() -> void:
	BuildingLayer.draw_box(self, cells, color, height)
	if outlined:
		BuildingLayer.draw_outline(self, cells, Color(0.4, 1.0, 0.4))
	if fire >= 0.0:
		BuildingLayer.draw_flames(self, cells, height, fire, fire_tick)
	if hp >= 0.0:
		var top := Vector2(-16.0, -height - 10.0)
		draw_rect(Rect2(top, Vector2(32.0, 3.0)), Color(0.15, 0.05, 0.05))
		draw_rect(Rect2(top, Vector2(32.0 * hp, 3.0)), Color(0.3, 0.85, 0.3))
