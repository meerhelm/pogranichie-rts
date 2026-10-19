class_name StealthLayer
extends Node2D
## What ВКЛ 6 (MissionStealth) shows on the map: the mission's props (setup.props: the chapel,
## the campfires) as sprites in the y-sorted unit layer, the glow round each campfire, the view
## cone of every watcher the local player sees (pale while it only looks, red once roused), and
## the night as a dark blue tint over the world. A watcher out of the player's sight still shows
## his cone when he carries a torch or stands by a campfire, as a light seen from afar would.
## Everything is read from the simulation.

const CONE_COLOR := Color(1.0, 0.92, 0.55, 0.2)
const CONE_EDGE := Color(1.0, 0.92, 0.55, 0.55)
const ROUSED_COLOR := Color(1.0, 0.3, 0.2, 0.24)
const ROUSED_EDGE := Color(1.0, 0.3, 0.2, 0.65)
const GLOW_COLOR := Color(1.0, 0.62, 0.25, 0.16)
const NIGHT := Color(0.5, 0.56, 0.78)
const DAY := Color(1, 1, 1)
## Seconds the light takes to change between night and day.
const DAWN_SECONDS := 3.0
const ARC := 16

var sim: Simulation
var local_player := 1

var _tint := CanvasModulate.new()
var _props: Array[Sprite2D] = []
## The setup.props index of each sprite in _props (props without art have no sprite).
var _prop_index := PackedInt32Array()


## Whether the mission has anything for this layer.
static func wanted(p_sim: Simulation) -> bool:
	var m := p_sim.mission
	return m != null and (m.def.rules.has("stealth") or m.def.setup.has("props"))


func attach(p_sim: Simulation, clock: SimClock, depth_layer: Node2D) -> void:
	sim = p_sim
	var all: Array = sim.mission.def.setup.get("props", [])
	for k in all.size():
		var p: Dictionary = all[k]
		var art := SpriteDB.prop(StringName(p["kind"]))
		if art == null:
			continue
		var at: Array = p["at"]
		var s := Sprite2D.new()
		s.texture = art.color
		s.centered = false
		s.offset = -art.pivot
		s.scale = Vector2.ONE * art.scale
		s.position = Iso.cell_to_screen(Vector2(at[0] + 0.5, at[1] + 0.5))
		s.name = "Prop%d" % _props.size()
		var shadow := Sprite2D.new()
		shadow.texture = art.shadow
		shadow.centered = false
		shadow.offset = -art.pivot
		shadow.modulate = Color(1, 1, 1, SpriteDB.SHADOW_ALPHA)
		shadow.show_behind_parent = true
		s.add_child(shadow)
		depth_layer.add_child(s)
		_props.append(s)
		_prop_index.append(k)
	_tint.color = NIGHT if sim.mission.stealth.night else DAY
	add_child(_tint)
	clock.advanced.connect(func(t: int, _s: int) -> void: _on_ticked(t))


func _exit_tree() -> void:
	for s in _props:
		if is_instance_valid(s):
			s.queue_free()
	_props.clear()
	_prop_index.clear()


func _on_ticked(_tick: int) -> void:
	var want := NIGHT if sim.mission.stealth.night else DAY
	if _tint.color != want and not _tint.has_meta("to"):
		_tint.set_meta("to", want)
		var tw := create_tween()
		tw.tween_property(_tint, "color", want, DAWN_SECONDS)
		tw.finished.connect(func() -> void: _tint.remove_meta("to"))
	for i in _props.size():
		var k := _prop_index[i]
		var at: Array = sim.mission.def.setup["props"][k]["at"]
		var cell := sim.nav.cell_at(at[0], at[1])
		var seen := sim.vision.state(local_player, cell) != VisionSystem.State.UNEXPLORED
		# Корона 2: a burned wall a ball brought down is gone.
		_props[i].visible = seen and not sim.mission.besiege.fallen.has(k)
	queue_redraw()


func _draw() -> void:
	if sim == null or sim.mission == null:
		return
	var m := sim.mission
	var r: Dictionary = m.def.rules.get("stealth", {})
	var light := float(r.get("light_radius", 0))
	if light > 0.0:
		for p: Dictionary in m.def.setup.get("props", []):
			if p["kind"] != "prop_campfire":
				continue
			var at: Array = p["at"]
			var cell := sim.nav.cell_at(at[0], at[1])
			if sim.vision.state(local_player, cell) == VisionSystem.State.UNEXPLORED:
				continue
			var c := Vector2(at[0] + 0.5, at[1] + 0.5)
			draw_colored_polygon(MagicLayer._circle(c, light), GLOW_COLOR)
	if not m.stealth.on or r.is_empty():
		return
	var half := acos(clampf(float(r.get("cone_permille", 500)) / 1000.0, -1.0, 1.0))
	var players: Array = r.get("watchers", [])
	var e := sim.entities
	for id in e.alive_ids:
		var s := id - 1
		if not players.has(e.owners[s]) or e.hp[s] <= 0:
			continue
		if not sim.vision.sees_unit(local_player, id) and not _shows(m, r, id):
			continue
		var reach := float(m.stealth.sight_of(m, id)) / Fixed.ONE
		var face := Vector2(e.facing_x[s], e.facing_y[s]) / Fixed.ONE
		if face.length_squared() < 0.01:
			continue
		var roused := m.stealth.roused.has(id)
		_cone(Vector2(e.pos_x[s], e.pos_y[s]) / Fixed.ONE, face.angle(), half, reach, roused)


## Whether a watcher out of sight gives himself away: a torch, or a campfire he stands by.
func _shows(m: MissionRuntime, r: Dictionary, id: int) -> bool:
	for g: String in r.get("torches", []):
		if m.groups.get(g, PackedInt32Array()).has(id):
			return true
	var reach := float(r.get("light_radius", 0)) + 1.0
	var at := Vector2(sim.entities.pos_x[id - 1], sim.entities.pos_y[id - 1]) / Fixed.ONE
	for p: Dictionary in m.def.setup.get("props", []):
		var c: Array = p["at"]
		if p["kind"] == "prop_campfire" and at.distance_to(Vector2(c[0], c[1])) <= reach:
			return true
	return false


## A view cone from `at` (cells) toward `angle`, `half` either side, `reach` cells long.
func _cone(at: Vector2, angle: float, half: float, reach: float, roused: bool) -> void:
	var pts := PackedVector2Array([Iso.cell_to_screen(at)])
	for k in ARC + 1:
		var a := angle - half + 2.0 * half * k / ARC
		pts.append(Iso.cell_to_screen(at + Vector2(cos(a), sin(a)) * reach))
	draw_colored_polygon(pts, ROUSED_COLOR if roused else CONE_COLOR)
	pts.append(pts[0])
	draw_polyline(pts, ROUSED_EDGE if roused else CONE_EDGE, 1.5)
