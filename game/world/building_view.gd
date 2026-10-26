class_name BuildingView
extends Node2D
## One object of the economy on the map (building_view.tscn): a building or a deposit. Tall
## ones live among the unit views in the y-sorted UnitLayer, so a unit behind a building is
## hidden by it and a unit in front covers it; flat ones (farms, open deposits) lie on the
## ground under the units. The node sits at the screen point of the footprint's centre: for a
## square footprint a unit next to a back face sorts behind, next to a front face in front.
## BuildingLayer fills and updates it, and nothing is redrawn while nothing changes.
## With art the view is SpriteStack nodes: palisade arms toward the back (Back), the stage's
## view (Main), arms toward the viewer (Front). Without art a raised box is drawn in its place.
## Over it all: fire while it burns (FireFx particles), then Overlay with the HP bar and the
## outline of a flat one.

## Screen height of a flat building's top (a farm's fence) for its bar and flames.
const FLAT_TOP := 16.0
const STACK_SCENE := preload("res://game/world/sprite_stack.tscn")

## Footprint in cells, relative to the centre (the node's position).
var cells := Rect2()
var color := Color.WHITE
## Screen height of the top above the ground.
var height := 0.0
var outlined := false
## HP bar fill 0..1; below zero means no bar.
var hp := -1.0
## On fire (M9): HP fraction for the flames, below zero when not burning.
var fire := -1.0
## Rendered view shown instead of the box (buildings with art), and its team tint.
var sprite: SpriteDB.Sprite
var tint := Color.WHITE
## Pieces shown with the sprite: behind it and in front of it (palisade arms toward the
## neighbours).
var back: Array[SpriteDB.Sprite] = []
var front: Array[SpriteDB.Sprite] = []
## Lies on the ground (farm, open deposit): bar and flames low, outline over the art.
var flat := false
## Catalog id of the building and whether it was finished (for its ruins).
var def_id: StringName
var done := false

@onready var _back: Node2D = $Back
@onready var _main: SpriteStack = $Main
@onready var _front: Node2D = $Front
@onready var _fire: FireFx = $Fire
@onready var _overlay: Node2D = $Overlay


func _ready() -> void:
	_overlay.draw.connect(_draw_overlay)
	_show_art()
	if fire >= 0.0:
		_fire.burn(_flame_points(), fire)


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
	_redraw()


## Ruins: no outline, no bar.
func clear_marks() -> void:
	outlined = false
	hp = -1.0
	_redraw()


## Burning with `p_fire` HP left (0..1), or not when below zero.
func set_fire(p_fire: float, _tick: int) -> void:
	if p_fire < 0.0 and fire < 0.0:
		return
	fire = p_fire
	if not is_node_ready():
		return
	if fire < 0.0:
		_fire.stop()
	else:
		_fire.burn(_flame_points(), fire)


## Where flames rise from: a few points per cell over the top of the building.
func _flame_points() -> PackedVector2Array:
	var y := height
	if sprite != null:
		y = FLAT_TOP if flat else -_sprite_top() * 0.6
	var out := PackedVector2Array()
	for i in int(cells.size.x * cells.size.y) * 2 + 1:
		var f := Vector2(fposmod(i * 0.618, 1.0), fposmod(i * 0.382 + 0.17, 1.0))
		out.append(Iso.cell_to_screen(cells.position + cells.size * f) - Vector2(0.0, y))
	return out


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
	back = p_back
	front = p_front
	_show_art()
	_redraw()


func _show_art() -> void:
	if not is_node_ready():
		return
	var none: Array[SpriteDB.Sprite] = []
	_main.show_sprite(sprite, tint)
	_show_pieces(_back, back if sprite != null else none)
	_show_pieces(_front, front if sprite != null else none)


## Fills `holder` with one SpriteStack per piece, reusing the ones it has.
func _show_pieces(holder: Node2D, pieces: Array[SpriteDB.Sprite]) -> void:
	while holder.get_child_count() < pieces.size():
		holder.add_child(STACK_SCENE.instantiate())
	for i in holder.get_child_count():
		var stack: SpriteStack = holder.get_child(i)
		stack.show_sprite(pieces[i] if i < pieces.size() else null, tint)


func _redraw() -> void:
	queue_redraw()
	if is_node_ready():
		_overlay.queue_redraw()


## Under the art: the outline of a tall one's footprint, or the placeholder box.
func _draw() -> void:
	if sprite == null:
		BuildingLayer.draw_box(self, cells, color, height)
	if outlined and not flat:
		BuildingLayer.draw_outline(self, cells, Color(0.4, 1.0, 0.4))


func _draw_overlay() -> void:
	var top_y := -height
	if sprite != null:
		top_y = -FLAT_TOP if flat else _sprite_top()
	if outlined and flat:
		BuildingLayer.draw_outline(_overlay, cells, Color(0.4, 1.0, 0.4))
	if hp >= 0.0:
		var top := Vector2(-16.0, top_y - 10.0)
		_overlay.draw_rect(Rect2(top, Vector2(32.0, 3.0)), Color(0.15, 0.05, 0.05))
		_overlay.draw_rect(Rect2(top, Vector2(32.0 * hp, 3.0)), Color(0.3, 0.85, 0.3))


## Screen height of the sprite's top over the anchor, less the frame's empty margin.
func _sprite_top() -> float:
	return sprite.dest().position.y + 24.0
