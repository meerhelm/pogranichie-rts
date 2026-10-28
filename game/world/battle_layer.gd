class_name BattleLayer
extends Node2D
## What ВКЛ 8 (MissionBattle) shows on the map: the bridges of boats and logs over the Dnieper,
## plank by plank as each section is laid, with the section being built marked and its progress;
## while the army is set out at dawn, the outlines of the ravine and the forest's edge where the
## foot and the guns stay hidden. Everything is read from the simulation.

const PLANK := Color(0.52, 0.38, 0.22)
const PLANK_DARK := Color(0.33, 0.23, 0.13)
const ROPE := Color(0.72, 0.64, 0.46)
const MARK := Color(1.0, 0.86, 0.45, 0.9)
const COVER := Color(0.55, 0.85, 0.45, 0.75)
## Planks across a cell, and how thick a plank's edge line is.
const PLANKS := 4

var sim: Simulation
var local_player := 1

var _last_built := PackedInt32Array()
var _last_work := PackedInt32Array()
var _deploying := false


## Whether the mission has bridges or an ambush to show.
static func wanted(p_sim: Simulation) -> bool:
	var m := p_sim.mission
	return m != null and m.def.rules.has("battle")


func attach(p_sim: Simulation, clock: SimClock) -> void:
	sim = p_sim
	clock.advanced.connect(func(t: int, _s: int) -> void: _on_ticked(t))
	queue_redraw()


func _on_ticked(_tick: int) -> void:
	var b := sim.mission.battle
	var deploying := _is_deploying()
	if b.built != _last_built or b.work != _last_work or deploying != _deploying:
		_last_built = b.built.duplicate()
		_last_work = b.work.duplicate()
		_deploying = deploying
		queue_redraw()


## From dawn until the battle begins the player sets out the army.
func _is_deploying() -> bool:
	var f := sim.mission.fired
	return f.has("4") and not f.has("6")


func _draw() -> void:
	if sim == null:
		return
	var m := sim.mission
	var r: Dictionary = m.def.rules["battle"]
	var bridges: Array = r.get("bridges", [])
	for i in bridges.size():
		for c in m.battle.deck_cells(m, i):
			_deck(c)
		var bridge: Dictionary = bridges[i]
		var sections: int = bridge["sections"]
		if m.battle.built[i] < sections:
			_building(m, bridge, i)
	if _deploying:
		for cover: Array in r.get("cover", []):
			var rect := PackedInt32Array(cover)
			_outline(rect[0], rect[1], rect[2] + 1, rect[3] + 1, COVER)


## One cell of finished deck: planks across the stream, ropes along both edges.
func _deck(c: Vector2i) -> void:
	var x := float(c.x)
	var y := float(c.y)
	var poly := PackedVector2Array([_p(x, y), _p(x + 1.0, y), _p(x + 1.0, y + 1.0), _p(x, y + 1.0)])
	draw_colored_polygon(poly, PLANK)
	for k in range(1, PLANKS):
		var t := float(k) / PLANKS
		draw_line(_p(x, y + t), _p(x + 1.0, y + t), PLANK_DARK, 1.0)
	draw_line(_p(x, y), _p(x, y + 1.0), ROPE, 1.5)
	draw_line(_p(x + 1.0, y), _p(x + 1.0, y + 1.0), ROPE, 1.5)


## The next section of bridge i: its outline, and a bar of how far the work is.
func _building(m: MissionRuntime, b: Dictionary, i: int) -> void:
	var cells: Array = b["cells"]
	var rect := PackedInt32Array(cells)
	if (
		sim.vision.state(local_player, sim.nav.cell_at(rect[0], rect[3]))
		== (VisionSystem.State.UNEXPLORED)
	):
		return
	var rows := MissionBattle.section_rows(b)
	var bottom := rect[3] + 1 - m.battle.built[i] * rows
	var top := maxi(bottom - rows, rect[1])
	_outline(rect[0], top, rect[2] + 1, bottom, MARK)
	var done := float(m.battle.section_permille(m, i)) / 1000.0
	if done <= 0.0:
		return
	var y := float(bottom) - (bottom - top) * done
	var poly := PackedVector2Array(
		[
			_p(rect[0], y),
			_p(rect[2] + 1, y),
			_p(rect[2] + 1, bottom),
			_p(rect[0], bottom),
		]
	)
	draw_colored_polygon(poly, Color(PLANK, 0.6))


func _outline(x0: float, y0: float, x1: float, y1: float, color: Color) -> void:
	var pts := PackedVector2Array([_p(x0, y0), _p(x1, y0), _p(x1, y1), _p(x0, y1), _p(x0, y0)])
	draw_polyline(pts, color, 1.5)


func _p(x: float, y: float) -> Vector2:
	return Iso.cell_to_screen(Vector2(x, y))
