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
## Rendered view drawn instead of the box (finished buildings with art), and its team tint.
var sprite: SpriteDB.Sprite
var tint := Color.WHITE
## Pieces drawn with the sprite: behind it and in front of it (palisade arms toward the
## neighbours).
var back: Array[SpriteDB.Sprite] = []
var front: Array[SpriteDB.Sprite] = []
## Catalog id of the building and whether it was finished (for its ruins).
var def_id: StringName
var done := false


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


func set_sprite(
	p_sprite: SpriteDB.Sprite,
	p_tint: Color,
	p_back: Array[SpriteDB.Sprite] = [],
	p_front: Array[SpriteDB.Sprite] = []
) -> void:
	if p_sprite == sprite and p_tint == tint and p_back == back and p_front == front:
		return
	sprite = p_sprite
	tint = p_tint
	# Pixel art (drawn 1:1) stays crisp when the camera zooms; rendered art is smoothed.
	var pixel := sprite != null and sprite.scale >= 1.0
	texture_filter = TEXTURE_FILTER_NEAREST if pixel else TEXTURE_FILTER_PARENT_NODE
	back = p_back
	front = p_front
	queue_redraw()


func _draw() -> void:
	var top_y := -height
	if sprite != null:
		if outlined:
			BuildingLayer.draw_outline(self, cells, Color(0.4, 1.0, 0.4))
		for piece in back:
			piece.draw(self, Rect2(Vector2.ZERO, piece.frame), tint)
		sprite.draw(self, Rect2(Vector2.ZERO, sprite.frame), tint)
		for piece in front:
			piece.draw(self, Rect2(Vector2.ZERO, piece.frame), tint)
		top_y = _sprite_top()
	else:
		BuildingLayer.draw_box(self, cells, color, height)
		if outlined:
			BuildingLayer.draw_outline(self, cells, Color(0.4, 1.0, 0.4))
	if fire >= 0.0:
		BuildingLayer.draw_flames(
			self, cells, -top_y * 0.6 if sprite != null else height, fire, fire_tick
		)
	if hp >= 0.0:
		var top := Vector2(-16.0, top_y - 10.0)
		draw_rect(Rect2(top, Vector2(32.0, 3.0)), Color(0.15, 0.05, 0.05))
		draw_rect(Rect2(top, Vector2(32.0 * hp, 3.0)), Color(0.3, 0.85, 0.3))


## Screen height of the sprite's top over the anchor, less the frame's empty margin.
func _sprite_top() -> float:
	return sprite.dest().position.y + 24.0
