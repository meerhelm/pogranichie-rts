class_name SpriteStack
extends Node2D
## One rendered view (SpriteDB.Sprite: a building stage, a palisade arm, a deposit) as Sprite2D
## nodes of sprite_stack.tscn: the ground shadow, the colour view, and the team mask tinted
## with the owner's colour over it.

@onready var _shadow: Sprite2D = $Shadow
@onready var _color: Sprite2D = $Color
@onready var _team: Sprite2D = $Team


## Shows `s` with its team mask in `tint`; null hides the stack.
func show_sprite(s: SpriteDB.Sprite, tint: Color) -> void:
	visible = s != null
	if s == null:
		return
	# Pixel art (drawn 1:1) stays crisp when the camera zooms; rendered art is smoothed.
	texture_filter = TEXTURE_FILTER_NEAREST if s.scale >= 1.0 else TEXTURE_FILTER_PARENT_NODE
	for part: Sprite2D in [_shadow, _color, _team]:
		part.offset = -s.pivot
		part.scale = Vector2(s.scale, s.scale)
	_shadow.texture = s.shadow
	_shadow.self_modulate = Color(1, 1, 1, SpriteDB.SHADOW_ALPHA)
	_color.texture = s.color
	_team.texture = s.team
	_team.visible = s.team != null
	_team.self_modulate = tint


## The colour view (whose opaque pixels hide what is behind it).
func color_sprite() -> Sprite2D:
	return _color
