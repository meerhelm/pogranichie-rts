class_name UnitView
extends Node2D
## Placeholder unit sprite: shadow, a body in the owner's colour shaped by kind (circle for
## foot, wide oval for horse, box for carts), a tick showing which of 8 directions it faces,
## and a ring when selected. Above it, from M4: an HP bar once hurt or selected, a yellow mark
## while wavering and a white flag while fleeing. Position is set by UnitLayer, interpolated
## between ticks; UnitLayer also feeds the combat state with show_state().
## Types with rendered art (SpriteDB) draw their sprite sheet instead of the body: idle or walk
## in the facing direction, the team mask tinted with the owner's colour.

enum Mood { STEADY, WAVERING, FLEEING }

const PLAYER_COLORS: Array[Color] = [
	Color(0.7, 0.7, 0.7), Color(0.85, 0.2, 0.15), Color(0.95, 0.95, 0.9), Color(0.2, 0.4, 0.9)
]
const RADIUS := 7.0
const BAR_WIDTH := 18.0
## Height of the HP bar over a sprite's anchor (a 1.75 m figure is about 35 px tall).
const SPRITE_BAR_Y := 46.0
## Ticks without moving before a walker switches to standing.
const STILL_TICKS := 3

var unit_id: int
var player: int
var move_class: int
var type_id: StringName
var selected := false:
	set(value):
		if selected != value:
			selected = value
			queue_redraw()
var hp_permille := 1000
var mood := Mood.STEADY
## A hidden forest archer, drawn see-through for its owner.
var stealthed := false
## Rendered sheet of this type, or null for the placeholder body.
var sprite: SpriteDB.Sprite
## Walking (moved since the last tick) or standing, for the sheet's animation.
var moving := false
## Screen direction in 8 steps: 0 east, 2 south, 4 west, 6 north (clockwise, y down).
var facing := 2:
	set(value):
		if facing != value:
			facing = value
			queue_redraw()

var _anim_time := 0.0
var _still_ticks := 0
var _anim_frame := -1


func _ready() -> void:
	sprite = SpriteDB.unit(type_id)
	set_process(sprite != null)


func _process(delta: float) -> void:
	_anim_time += delta
	var frame := _frame()
	if frame != _anim_frame:
		_anim_frame = frame
		queue_redraw()


func _anim() -> Dictionary:
	var a: Dictionary = sprite.anims.get("walk" if moving else "idle", {})
	if a.is_empty():
		a = sprite.anims.values()[0]
	return a


func _frame() -> int:
	var a := _anim()
	return int(_anim_time * float(a["fps"])) % int(a["frames"])


func _draw() -> void:
	var body := PLAYER_COLORS[player % PLAYER_COLORS.size()]
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	if sprite == null:
		draw_circle(Vector2.ZERO, RADIUS + 3.0, Color(0, 0, 0, 0.3))
	if selected:
		var ring := RADIUS + 5.0
		if sprite != null and move_class in [NavGrid.MoveClass.CAVALRY, NavGrid.MoveClass.SIEGE]:
			ring *= 1.6
		draw_arc(Vector2.ZERO, ring, 0.0, TAU, 32, Color(0.4, 1.0, 0.4), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if sprite != null:
		var a := _anim()
		sprite.draw(self, sprite.source(int(a["row"]) + facing, maxi(_anim_frame, 0)), body)
		_draw_state()
		return
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
	_draw_state()


func _draw_state() -> void:
	var top := Vector2(-BAR_WIDTH / 2.0, -RADIUS * 2.0 - 8.0)
	if sprite != null:
		top.y = -float(sprite.meta.get("bar_y", SPRITE_BAR_Y))
	if selected or hp_permille < 1000:
		draw_rect(Rect2(top, Vector2(BAR_WIDTH, 3.0)), Color(0.15, 0.05, 0.05))
		var w := BAR_WIDTH * hp_permille / 1000.0
		var c := Color(0.3, 0.85, 0.3) if hp_permille > 400 else Color(0.9, 0.3, 0.2)
		draw_rect(Rect2(top, Vector2(w, 3.0)), c)
	var mark := top + Vector2(BAR_WIDTH / 2.0, -4.0)
	if mood == Mood.WAVERING:
		draw_circle(mark, 2.5, Color(1.0, 0.85, 0.2))
	elif mood == Mood.FLEEING:
		draw_line(mark, mark + Vector2(0, -9), Color.BLACK, 1.0)
		draw_rect(Rect2(mark + Vector2(0, -9), Vector2(6, 4)), Color.WHITE)


## Combat state for drawing; redraws only when something visible changed.
func show_state(p_hp_permille: int, p_mood: Mood, p_hidden: bool, p_move_class: int) -> void:
	if (
		p_hp_permille == hp_permille
		and p_mood == mood
		and p_hidden == stealthed
		and p_move_class == move_class
	):
		return
	hp_permille = p_hp_permille
	mood = p_mood
	stealthed = p_hidden
	move_class = p_move_class
	modulate.a = 0.45 if stealthed else 1.0
	queue_redraw()


## Called every tick with whether the unit moved; it stands only after a few still ticks, so
## a slow walker does not flicker between the two animations.
func set_moving(value: bool) -> void:
	_still_ticks = 0 if value else _still_ticks + 1
	var walking := value or (moving and _still_ticks < STILL_TICKS)
	if walking == moving:
		return
	moving = walking
	_anim_time = 0.0
	queue_redraw()


## Faces the direction of a move in grid units.
func face(dx: int, dy: int) -> void:
	if dx == 0 and dy == 0:
		return
	# Snap to 8 directions in screen space, so sprites (rendered in 8 directions) match.
	var screen := Iso.cell_to_screen(Vector2(dx, dy))
	var octant := wrapi(roundi(screen.angle() / (PI / 4.0)), 0, 8)
	facing = octant
