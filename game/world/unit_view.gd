class_name UnitView
extends Node2D
## Placeholder unit sprite: shadow, a body in the owner's colour shaped by kind (circle for
## foot, wide oval for horse, box for carts), a tick showing which of 8 directions it faces,
## and a ring when selected. Above it, from M4: an HP bar once hurt or selected, a yellow mark
## while wavering and a white flag while fleeing. Position is set by UnitLayer, interpolated
## between ticks; UnitLayer also feeds the combat state with show_state().
## Types with rendered art (SpriteDB) show their sheet instead of the body, as AnimatedSprite2D
## nodes of unit_view.tscn playing the type's SpriteFrames: idle, walk, work (peasants at their
## job) or attack (once per blow or shot) in the facing direction, with the ground shadow under
## and the team mask, tinted with the owner's colour, over it.

enum Mood { STEADY, WAVERING, FLEEING }

const PLAYER_COLORS: Array[Color] = [
	Color(0.7, 0.7, 0.7),
	Color(0.85, 0.2, 0.15),
	Color(0.95, 0.95, 0.9),
	Color(0.2, 0.4, 0.9),
	Color(0.25, 0.6, 0.3),
	Color(0.9, 0.7, 0.2),
]
const RADIUS := 7.0
## Outline of what the player looks at (not his own: no orders).
const LOOK_COLOR := Color(1.0, 0.75, 0.25)
const BAR_WIDTH := 18.0
## Height of the HP bar over a sprite's anchor (a 1.75 m figure is about 35 px tall).
const SPRITE_BAR_Y := 46.0
## Ticks without moving before a walker switches to standing.
const STILL_TICKS := 3
## A click this close to the figure's rectangle (screen pixels at zoom 1) still picks it.
const PICK_SLACK := 3.0

var unit_id: int
var player: int
var move_class: int
var type_id: StringName
var selected := false:
	set(value):
		if selected != value:
			selected = value
			_redraw()
## Looked at by the player (another side's or a wild unit shown in the card): an amber ring.
var looked := false:
	set(value):
		if looked != value:
			looked = value
			_redraw()
var hp_permille := 1000
var mood := Mood.STEADY
## A hidden forest archer, drawn see-through for its owner.
var stealthed := false
## Rendered sheet of this type, or null for the placeholder body.
var sprite: SpriteDB.Sprite
## Walking (moved since the last tick) or standing, for the sheet's animation.
var moving := false
## At its job (gathering, building, taking apart) and standing: the sheet's work animation.
var working := false
## Screen direction in 8 steps: 0 east, 2 south, 4 west, 6 north (clockwise, y down).
var facing := 2:
	set(value):
		if facing != value:
			facing = value
			_play()
			queue_redraw()

var _still_ticks := 0
## The attack animation plays once per blow; true while it does.
var _striking := false

## The sheet's three passes as AnimatedSprite2D (unit_view.tscn): shadow under the colour
## frames, team mask over them. Body plays; the other two show its frame.
@onready var _shadow: AnimatedSprite2D = $Shadow
@onready var _body: AnimatedSprite2D = $Body
@onready var _team: AnimatedSprite2D = $Team
## HP bar and mood marks, over the sprite.
@onready var _overlay: Node2D = $Overlay


func _ready() -> void:
	sprite = SpriteDB.unit(type_id)
	set_process(false)
	_overlay.draw.connect(_draw_state)
	if sprite == null:
		for pass_sprite: AnimatedSprite2D in [_shadow, _body, _team]:
			pass_sprite.visible = false
		return
	# Pixel art (drawn 1:1) stays crisp when the camera zooms; rendered art is smoothed.
	if sprite.scale >= 1.0:
		texture_filter = TEXTURE_FILTER_NEAREST
	var frames := SpriteDB.unit_frames(type_id)
	for pass_sprite: AnimatedSprite2D in [_shadow, _body, _team]:
		pass_sprite.sprite_frames = frames
		pass_sprite.offset = -sprite.pivot
		pass_sprite.scale = Vector2(sprite.scale, sprite.scale)
	_shadow.material = SpriteDB.pass_material(sprite, &"shadow")
	_shadow.self_modulate = Color(1, 1, 1, SpriteDB.SHADOW_ALPHA)
	_team.material = SpriteDB.pass_material(sprite, &"team")
	_team.visible = _team.material != null
	_team.self_modulate = PLAYER_COLORS[player % PLAYER_COLORS.size()]
	_body.frame_changed.connect(_sync_passes)
	_body.animation_finished.connect(_on_animation_finished)
	_play(true)


## Walking wins (a rider throwing on the move keeps riding), then a blow, then work.
func _anim_name() -> String:
	if moving:
		return "walk"  # notr
	if _striking:
		return "attack"  # notr
	if working and sprite.anims.has("work"):
		return "work"  # notr
	return "idle"  # notr


func _anim() -> Dictionary:
	var a: Dictionary = sprite.anims.get(_anim_name(), {})
	if a.is_empty():
		a = sprite.anims.values()[0]
	return a


## Starts the animation for the current action and facing. A turn keeps the frame it was at,
## so a walker does not stumble; a new action (or `restart`) starts from the first frame.
func _play(restart := false) -> void:
	if sprite == null or not is_node_ready():
		return
	var anim := _anim_name()
	if not sprite.anims.has(anim):
		anim = sprite.anims.keys()[0]
	var name := SpriteDB.anim_name(anim, facing)
	if name == _body.animation and not restart:
		return
	var same_action := String(_body.animation).begins_with(anim + "_")
	var frame := _body.frame
	var progress := _body.frame_progress
	_body.play(name)
	if same_action and not restart:
		_body.set_frame_and_progress(frame, progress)
	for pass_sprite: AnimatedSprite2D in [_shadow, _team]:
		pass_sprite.animation = name
	_sync_passes()


func _sync_passes() -> void:
	_shadow.frame = _body.frame
	_team.frame = _body.frame


func _on_animation_finished() -> void:
	if _striking:
		_striking = false
		_play(true)


## Whether `local` (pixels from the anchor) is in the rectangle around the figure as drawn
## now, give or take PICK_SLACK: the whole sprite picks the unit, not just its feet.
func covers(local: Vector2) -> bool:
	if sprite == null:
		return local.distance_to(Vector2(0, -RADIUS)) <= RADIUS + PICK_SLACK
	var a := _anim()
	return sprite.covers(int(a["row"]) + facing, _body.frame, local, PICK_SLACK)


## Points on the figure as drawn (five heights from feet to head, three across), global:
## what has to stay in sight when something stands in front of the unit.
func figure_points() -> PackedVector2Array:
	var h := RADIUS * 2.0
	if sprite != null:
		h = float(sprite.meta.get("bar_y", SPRITE_BAR_Y)) - 6.0
	var out := PackedVector2Array()
	for k in 5:
		var y := -3.0 - (h - 3.0) * k / 4.0
		for x: float in [-5.0, 0.0, 5.0]:
			out.append(global_position + Vector2(x, y))
	return out


## Redraws the ring under the sprite and the bar and marks over it.
func _redraw() -> void:
	queue_redraw()
	if is_node_ready():
		_overlay.queue_redraw()


func _draw() -> void:
	var body := PLAYER_COLORS[player % PLAYER_COLORS.size()]
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	if sprite == null:
		draw_circle(Vector2.ZERO, RADIUS + 3.0, Color(0, 0, 0, 0.3))
	if selected or looked:
		var ring := RADIUS + 5.0
		if sprite != null and move_class in [NavGrid.MoveClass.CAVALRY, NavGrid.MoveClass.SIEGE]:
			ring *= 1.6
		var c := Color(0.4, 1.0, 0.4) if selected else LOOK_COLOR
		draw_arc(Vector2.ZERO, ring, 0.0, TAU, 32, c, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if sprite != null:
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


## On the overlay node, so it is drawn over the sprite.
func _draw_state() -> void:
	var o := _overlay
	var top := Vector2(-BAR_WIDTH / 2.0, -RADIUS * 2.0 - 8.0)
	if sprite != null:
		top.y = -float(sprite.meta.get("bar_y", SPRITE_BAR_Y))
	if selected or looked or hp_permille < 1000:
		o.draw_rect(Rect2(top, Vector2(BAR_WIDTH, 3.0)), Color(0.15, 0.05, 0.05))
		var w := BAR_WIDTH * hp_permille / 1000.0
		var c := Color(0.3, 0.85, 0.3) if hp_permille > 400 else Color(0.9, 0.3, 0.2)
		o.draw_rect(Rect2(top, Vector2(w, 3.0)), c)
	var mark := top + Vector2(BAR_WIDTH / 2.0, -4.0)
	if mood == Mood.WAVERING:
		o.draw_circle(mark, 2.5, Color(1.0, 0.85, 0.2))
	elif mood == Mood.FLEEING:
		o.draw_line(mark, mark + Vector2(0, -9), Color.BLACK, 1.0)
		o.draw_rect(Rect2(mark + Vector2(0, -9), Vector2(6, 4)), Color.WHITE)


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
	_redraw()


## Called every tick with whether the unit moved; it stands only after a few still ticks, so
## a slow walker does not flicker between the two animations.
func set_moving(value: bool) -> void:
	_still_ticks = 0 if value else _still_ticks + 1
	var walking := value or (moving and _still_ticks < STILL_TICKS)
	if walking == moving:
		return
	moving = walking
	if moving:
		_striking = false
	_play(true)


## Faces the direction of a move in grid units.
func face(dx: int, dy: int) -> void:
	if dx == 0 and dy == 0:
		return
	# Snap to 8 directions in screen space, so sprites (rendered in 8 directions) match.
	var screen := Iso.cell_to_screen(Vector2(dx, dy))
	var octant := wrapi(roundi(screen.angle() / (PI / 4.0)), 0, 8)
	facing = octant


## Plays the attack animation once from its start (a new blow restarts it).
func strike() -> void:
	if sprite == null or not sprite.anims.has("attack"):
		return
	_striking = true
	# A rider throwing on the move keeps his stride.
	_play(not moving)


func set_working(value: bool) -> void:
	if working == value:
		return
	working = value
	_play(true)
