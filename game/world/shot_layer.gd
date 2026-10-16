class_name ShotLayer
extends Node2D
## Draws arrows, bolts and javelins in flight (CombatSystem projectiles) as short dark strokes
## from the shooter's launch point to the target, moved along between ticks like the units.
## Towers shoot from their top.

const LENGTH := 10.0
const ARC := 18.0
## Screen height of a tower's fighting platform.
const TOWER_TOP := 56.0

var sim: Simulation
var clock: SimClock
var units: UnitLayer


func attach(p_sim: Simulation, p_clock: SimClock, p_units: UnitLayer) -> void:
	sim = p_sim
	clock = p_clock
	units = p_units
	z_index = 1


func _process(_delta: float) -> void:
	if sim != null:
		queue_redraw()


func _draw() -> void:
	var c := sim.combat
	var now := float(sim.tick) + (clock.alpha_permille() / 1000.0 if not clock.paused else 0.0)
	for i in c.shots.size():
		var span := maxf(c.shots.lands[i] - c.shots.launched[i], 1.0)
		var t := clampf((now - c.shots.launched[i]) / span, 0.0, 1.0)
		# A tower's arrows (shooter = minus its id) leave from the top of it.
		var lift := TOWER_TOP if c.shots.from[i] < 0 else UnitView.RADIUS
		var a := Iso.fixed_to_screen(c.shots.x[i], c.shots.y[i]) + Vector2(0, -lift)
		var target := units.view(c.shots.target[i])
		var seen := sim.vision.sees_cell(
			units.local_player, sim.nav.cell_of(c.shots.x[i], c.shots.y[i])
		)
		if not (seen or units.reveal_all) and (target == null or not target.visible):
			continue
		var b := target.position + Vector2(0, -UnitView.RADIUS) if target != null else a
		var p := a.lerp(b, t) + Vector2(0, -ARC * 4.0 * t * (1.0 - t))
		var dir := (b - a).normalized()
		draw_line(p - dir * LENGTH * 0.5, p + dir * LENGTH * 0.5, Color(0.1, 0.08, 0.05), 1.5)
