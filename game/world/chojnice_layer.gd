class_name ChojniceLayer
extends Node2D
## What «Корона 4» (MissionChojnice) shows on the map: a speech bubble over every unit that
## argues over its place in the line (the card's «спорят» mark), and a ring on the ground under
## whoever carries the Łęczyca banner. Only what the local player sees is drawn; everything is
## read from the simulation.

const BUBBLE := Color(0.97, 0.95, 0.88, 0.92)
const BUBBLE_EDGE := Color(0.25, 0.2, 0.15, 0.9)
const DOTS := Color(0.25, 0.2, 0.15)
const BANNER := Color(0.95, 0.82, 0.3, 0.85)
## Screen pixels from a unit's foot up to the bubble.
const RISE := 46.0

var sim: Simulation
var local_player := 1

var _shown := PackedInt32Array()
var _bearer := 0


## Whether the mission has the Chojnice rules.
static func wanted(p_sim: Simulation) -> bool:
	var m := p_sim.mission
	return m != null and m.def.rules.has("chojnice")


func attach(p_sim: Simulation, clock: SimClock) -> void:
	sim = p_sim
	clock.advanced.connect(func(t: int, _s: int) -> void: _on_ticked(t))
	queue_redraw()


func _on_ticked(_tick: int) -> void:
	# Arguing units stand still, so the marks only move when the set or the bearer changes,
	# but the bearer walks: redraw while he lives.
	var now := _arguing_seen()
	var c := sim.mission.chojnice
	if now != _shown or c.bearer != _bearer or c.bearer != 0:
		_shown = now
		_bearer = c.bearer
		queue_redraw()


func _arguing_seen() -> PackedInt32Array:
	var out := PackedInt32Array()
	var e := sim.entities
	for id: int in sim.mission.chojnice.arguing:
		if e.is_alive(id) and _seen(id):
			out.append(id)
	out.sort()
	return out


func _seen(id: int) -> bool:
	var e := sim.entities
	var cell := sim.nav.cell_of(e.pos_x[id - 1], e.pos_y[id - 1])
	return sim.vision.state(local_player, cell) == VisionSystem.State.VISIBLE


func _draw() -> void:
	if sim == null:
		return
	var e := sim.entities
	var b := sim.mission.chojnice.bearer
	if b != 0 and e.is_alive(b) and _seen(b):
		var at := Iso.fixed_to_screen(e.pos_x[b - 1], e.pos_y[b - 1])
		draw_set_transform(at, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 32, BANNER, 2.0)
		draw_set_transform(Vector2.ZERO)
	for id in _shown:
		if e.is_alive(id):
			_bubble(Iso.fixed_to_screen(e.pos_x[id - 1], e.pos_y[id - 1]) - Vector2(0.0, RISE))


func _bubble(at: Vector2) -> void:
	var rect := Rect2(at - Vector2(11.0, 6.0), Vector2(22.0, 12.0))
	draw_rect(rect, BUBBLE)
	draw_rect(rect, BUBBLE_EDGE, false, 1.0)
	draw_colored_polygon(
		PackedVector2Array(
			[at + Vector2(-3.0, 6.0), at + Vector2(2.0, 6.0), at + Vector2(-4.0, 11.0)]
		),
		BUBBLE
	)
	for k in 3:
		draw_circle(at + Vector2(-6.0 + 6.0 * k, 0.5), 1.6, DOTS)
