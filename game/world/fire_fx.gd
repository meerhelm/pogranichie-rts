class_name FireFx
extends Node2D
## Fire on a burning building (fire_fx.tscn): flames and smoke as CPUParticles2D, emitted from
## points over its roof. The flames grow as the building burns down. Only a picture: the
## particles' randomness is the engine's, never the simulation's.

## Flame size at full HP and when nearly burnt down, relative to the scene's.
const SMALL := 0.6
const LARGE := 1.4

var _flame_min := 0.0
var _flame_max := 0.0

@onready var _flames: CPUParticles2D = $Flames
@onready var _smoke: CPUParticles2D = $Smoke


func _ready() -> void:
	_flame_min = _flames.scale_amount_min
	_flame_max = _flames.scale_amount_max
	for p: CPUParticles2D in [_flames, _smoke]:
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
		p.emitting = false


## Burns from `points` (screen pixels from the node); `hp` 0..1 sizes the flames.
func burn(points: PackedVector2Array, hp: float) -> void:
	var grow := lerpf(LARGE, SMALL, clampf(hp, 0.0, 1.0))
	_flames.scale_amount_min = _flame_min * grow
	_flames.scale_amount_max = _flame_max * grow
	for p: CPUParticles2D in [_flames, _smoke]:
		if p.emission_points != points:
			p.emission_points = points
		p.emitting = true


func stop() -> void:
	for p: CPUParticles2D in [_flames, _smoke]:
		p.emitting = false


func burning() -> bool:
	return _flames.emitting
