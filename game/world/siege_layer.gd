class_name SiegeLayer
extends Node2D
## What ВКЛ 7 (MissionSiege) shows on the map: the storming ladders. Each ladder is a node in
## the y-sorted unit layer, set at its foot, so a ladder against a wall the camera faces stands
## in front of it and one on a far wall behind it. While its party raises it the ladder swings
## up from the ground; once it stands, its top leans on the wall; a ladder done with is gone.
## Only ladders whose foot the local player has explored are drawn. Everything is read from the
## simulation.

## Screen pixels from a wall cell's centre up to its fighting walk (the art's crib top).
const WALL_TOP_PX := 64.0
const RAIL := Color(0.42, 0.3, 0.18)
const RUNG := Color(0.55, 0.42, 0.26)
## Half the ladder's width and the step between rungs, in screen pixels.
const HALF_W := 3.5
const STEP := 7.0

var sim: Simulation
var local_player := 1

var _depth: Node2D
var _views: Array[LadderView] = []


## One ladder against the wall, drawn from its foot (the node's position).
class LadderView:
	extends Node2D
	## The top relative to the foot, and how far up it is (0 lying, 1 standing).
	var top := Vector2.ZERO
	var raised := 0.0

	func _draw() -> void:
		var lying := top * Vector2(1.0, 0.0) + Vector2(0.0, top.y * 0.15)
		var tip := lying.lerp(top, raised)
		if tip.length() < 1.0:
			return
		var side := Vector2(-tip.y, tip.x).normalized() * HALF_W
		draw_line(side, tip + side, RAIL, 2.0)
		draw_line(-side, tip - side, RAIL, 2.0)
		var n := int(tip.length() / STEP)
		for k in range(1, n + 1):
			var at := tip * (float(k) / float(n + 1))
			draw_line(at - side, at + side, RUNG, 1.5)


## Whether the mission has ladders to show.
static func wanted(p_sim: Simulation) -> bool:
	var m := p_sim.mission
	return m != null and m.def.rules.has("siege")


func attach(p_sim: Simulation, clock: SimClock, depth_layer: Node2D) -> void:
	sim = p_sim
	_depth = depth_layer
	clock.advanced.connect(func(t: int, _s: int) -> void: _on_ticked(t))


func _exit_tree() -> void:
	for v in _views:
		if is_instance_valid(v):
			v.queue_free()
	_views.clear()


func _on_ticked(_tick: int) -> void:
	var s := sim.mission.siege
	var siege: Dictionary = sim.mission.def.rules["siege"]
	var lr: Dictionary = siege.get("ladder", {})
	var raise: float = lr.get("raise_ticks", 1)
	var raise_ticks := maxf(raise, 1.0)
	while _views.size() < s.l_group.size():
		var v := LadderView.new()
		v.name = "Ladder%d" % _views.size()
		_depth.add_child(v)
		_views.append(v)
	for i in s.l_group.size():
		var v := _views[i]
		var foot := s.l_foot[i]
		var seen := sim.vision.state(local_player, foot) != VisionSystem.State.UNEXPLORED
		v.visible = seen and s.l_state[i] != MissionSiege.Ladder.DONE
		if not v.visible:
			continue
		var f := _screen(foot)
		v.position = f
		v.top = _screen(s.l_wall[i]) - f - Vector2(0.0, WALL_TOP_PX)
		if s.l_state[i] == MissionSiege.Ladder.UP:
			v.raised = 1.0
		else:
			v.raised = clampf(float(s.l_raise[i]) / raise_ticks, 0.0, 1.0)
		v.queue_redraw()


func _screen(cell: int) -> Vector2:
	var w := sim.nav.width
	return Iso.cell_to_screen(Vector2(cell % w + 0.5, cell / w + 0.5))
