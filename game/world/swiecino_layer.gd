class_name SwiecinoLayer
extends Node2D
## What «Корона 6» (MissionSwiecino) shows on the map: the ground before the reeds where the
## Gdańsk crossbowmen reach (a dashed outline, filled faintly while they shoot), and a strength
## bar under every horse the local player sees: green when rested, yellow when tiring, red when
## tired and striking weaker. Everything is read from the simulation.

const ZONE := Color(0.95, 0.85, 0.35, 0.55)
const ZONE_FILL := Color(0.95, 0.85, 0.35, 0.08)
const BAR_BACK := Color(0.1, 0.1, 0.1, 0.7)
const RESTED := Color(0.4, 0.8, 0.35)
const TIRING := Color(0.9, 0.8, 0.3)
const TIRED := Color(0.9, 0.3, 0.2)
## Screen pixels below a rider's foot to the bar, and its size.
const DROP := 10.0
const BAR := Vector2(26.0, 3.0)

var sim: Simulation
var local_player := 1


## Whether the mission has the Świecino rules.
static func wanted(p_sim: Simulation) -> bool:
	var m := p_sim.mission
	return m != null and m.def.rules.has("swiecino")


func attach(p_sim: Simulation, clock: SimClock) -> void:
	sim = p_sim
	clock.advanced.connect(func(t: int, _s: int) -> void: _on_ticked(t))
	queue_redraw()


func _on_ticked(_tick: int) -> void:
	# The riders move all the time; the layer is small, so it is redrawn every tick.
	queue_redraw()


func _seen(id: int) -> bool:
	var e := sim.entities
	var cell := sim.nav.cell_of(e.pos_x[id - 1], e.pos_y[id - 1])
	return sim.vision.state(local_player, cell) == VisionSystem.State.VISIBLE


func _draw() -> void:
	if sim == null:
		return
	var s := sim.mission.swiecino
	var rules: Dictionary = sim.mission.def.rules["swiecino"]
	var zone: Array = rules.get("crossbows", {}).get("zone", [])
	if zone.size() == 4:
		_zone(zone, s.crossbows_on)
	var f: Dictionary = rules.get("fatigue", {})
	var tired := int(f.get("tired", 400))
	var e := sim.entities
	for id: int in s.stamina:
		if not e.is_alive(id) or not _seen(id):
			continue
		var left: int = s.stamina[id]
		var at := Iso.fixed_to_screen(e.pos_x[id - 1], e.pos_y[id - 1]) + Vector2(0.0, DROP)
		var rect := Rect2(at - Vector2(BAR.x / 2.0, 0.0), BAR)
		draw_rect(rect, BAR_BACK)
		var color := RESTED
		if left < tired:
			color = TIRED
		elif left < 700:
			color = TIRING
		draw_rect(Rect2(rect.position, Vector2(BAR.x * left / 1000.0, BAR.y)), color)


## The rectangle [x0, y0, x1, y1] (cells, inclusive) as a diamond on the ground.
func _zone(r: Array, shooting: bool) -> void:
	var corners := PackedVector2Array(
		[
			Iso.cell_to_screen(Vector2(r[0], r[1])),
			Iso.cell_to_screen(Vector2(r[2] + 1, r[1])),
			Iso.cell_to_screen(Vector2(r[2] + 1, r[3] + 1)),
			Iso.cell_to_screen(Vector2(r[0], r[3] + 1)),
		]
	)
	if shooting:
		draw_colored_polygon(corners, ZONE_FILL)
	for k in 4:
		draw_dashed_line(corners[k], corners[(k + 1) % 4], ZONE, 2.0, 10.0)
