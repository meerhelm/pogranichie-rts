class_name Minimap
extends Control
## The map in small, as a diamond like the isometric view (M6): terrain, the local player's fog
## of war, buildings and units it sees as dots in their owner's colour, and the camera's view as
## a frame. Click or drag to move the camera there. Attacks on the player blink red three times
## with a red glow along the inner edge, a finished building blinks green once (MinimapAlerts).
## Terrain and fog are textures blended by a shader, so redrawing costs no loop over the map;
## dots are redrawn a few times a second.

const SHADER := preload("res://ui/minimap.gdshader")
## Redraw the dots every this many ticks.
const REDRAW_TICKS := 4
const DOT := 2.0
const ATTACK_COLOR := Color(1.0, 0.15, 0.1)
const BUILT_COLOR := Color(0.35, 1.0, 0.3)
## Seconds of one blink, and blinks per alert.
const BLINK := 0.5
const ATTACK_BLINKS := 3
const BUILT_BLINKS := 1
const HALO_SHADER := preload("res://ui/minimap_halo.gdshader")

var sim: Simulation
var camera: RtsCamera
var player := 1

## Terrain sprite under the cell -> local transform, with the fog shader; dots are drawn by
## _marks on top of it, and the camera frame by _frame, which alone follows the camera every
## frame (M10: the dots are not redrawn 60 times a second).
var _ground := Node2D.new()
var _ground_sprite := Sprite2D.new()
var _marks := Node2D.new()
var _frame := Node2D.new()
## Camera position and zoom the frame was last drawn for.
var _framed := Rect2()
var _terrain_image: Image
var _terrain := ImageTexture.new()
var _fog_image: Image
var _fog := ImageTexture.new()
var _fog_version := -1
var _terrain_version := -1
## Cell space -> local pixels.
var _to_local := Transform2D()
var _map_rect := Rect2()
var _scale := 1.0
var _dragging := false
var _alerts: MinimapAlerts
## Blinking alerts: {kind, cell, age (seconds)}.
var _pings: Array[Dictionary] = []
var _ping_layer := Node2D.new()
var _halo := ColorRect.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	_ground_sprite.material = mat
	_ground_sprite.centered = false
	_ground.add_child(_ground_sprite)
	add_child(_ground)
	add_child(_marks)
	add_child(_ping_layer)
	add_child(_frame)
	var halo_mat := ShaderMaterial.new()
	halo_mat.shader = HALO_SHADER
	_halo.material = halo_mat
	_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_halo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_halo.visible = false
	add_child(_halo)
	_marks.draw.connect(_draw_marks)
	_ping_layer.draw.connect(_draw_pings)
	_frame.draw.connect(_draw_camera)
	resized.connect(_fit)


func attach(p_sim: Simulation, clock: SimClock, p_camera: RtsCamera, p_player: int) -> void:
	sim = p_sim
	camera = p_camera
	player = p_player
	var w := sim.nav.width
	var h := sim.nav.height
	_terrain_image = Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	_fog_image = Image.create_empty(w, h, false, Image.FORMAT_L8)
	if not sim.vision.enabled():
		_fog_image.fill(Color.WHITE)
	_fog = ImageTexture.create_from_image(_fog_image)
	_paint_terrain()
	(_ground_sprite.material as ShaderMaterial).set_shader_parameter(&"fog", _fog)
	_alerts = MinimapAlerts.new(sim, player)
	clock.advanced.connect(_on_advanced)
	_fit()


func _on_advanced(tick: int, steps: int) -> void:
	if sim.nav.version != _terrain_version:
		_paint_terrain()
	var g: VisionGrid = sim.vision.grids.get(player)
	if g != null and g.version != _fog_version:
		_fog_version = g.version
		_fog_image.set_data(g.width, g.height, false, Image.FORMAT_L8, g.shade)
		_fog.update(_fog_image)
	if tick / REDRAW_TICKS != (tick - steps) / REDRAW_TICKS:
		_marks.queue_redraw()
		for alert in _alerts.poll(tick):
			_pings.append({"kind": alert["kind"], "cell": alert["cell"], "age": 0.0})


## Starts a blink at a map cell by hand (for tests and screenshots).
func ping(kind: MinimapAlerts.Kind, cell: Vector2) -> void:
	_pings.append({"kind": kind, "cell": cell, "age": 0.0})


func _process(delta: float) -> void:
	if not _pings.is_empty() or _halo.visible:
		_age_pings(delta)
	# The camera frame follows the camera: redrawn when it moved or zoomed.
	if camera != null and is_visible_in_tree():
		var at := Rect2(camera.position, camera.zoom)
		if at != _framed:
			_framed = at
			_frame.queue_redraw()


func _paint_terrain() -> void:
	var nav := sim.nav
	_terrain_version = nav.version
	var colors: Array[Color] = []
	for id in nav.terrain_ids:
		colors.append(MapView.COLORS.get(id, MapView.FALLBACK_COLOR))
	for cell in nav.cell_count():
		_terrain_image.set_pixel(cell % nav.width, cell / nav.width, colors[nav.terrain[cell]])
	if _terrain.get_width() == 0:
		_terrain = ImageTexture.create_from_image(_terrain_image)
		_ground_sprite.texture = _terrain
	else:
		_terrain.update(_terrain_image)


## Fits the map's diamond into the control, keeping its 2:1 shape.
func _fit() -> void:
	if sim == null:
		return
	_map_rect = Iso.map_rect(sim.nav.width, sim.nav.height)
	_scale = minf(size.x / _map_rect.size.x, size.y / _map_rect.size.y)
	var offset := (size - _map_rect.size * _scale) / 2.0 - _map_rect.position * _scale
	_to_local = Transform2D(
		Vector2(Iso.HALF_W, Iso.HALF_H) * _scale, Vector2(-Iso.HALF_W, Iso.HALF_H) * _scale, offset
	)
	_ground.transform = _to_local
	_marks.queue_redraw()
	_frame.queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))


func _draw_marks() -> void:
	if sim == null:
		return
	_draw_buildings()
	_draw_units()


func _draw_buildings() -> void:
	var b := sim.economy.buildings
	for id in b.alive_ids:
		var s := id - 1
		if b.owners[s] != player and not sim.vision.sees_building(player, id):
			continue
		var c := UnitView.PLAYER_COLORS[b.owners[s] % UnitView.PLAYER_COLORS.size()]
		var at := _to_local * Vector2(b.cell_x[s] + b.w[s] / 2.0, b.cell_y[s] + b.h[s] / 2.0)
		var half := maxf(DOT, b.w[s] * _scale * Iso.HALF_W / 2.0)
		_marks.draw_rect(
			Rect2(at - Vector2(half, half / 2.0), Vector2(half * 2.0, half)), c.darkened(0.2)
		)


func _draw_units() -> void:
	var e := sim.entities
	for id in e.alive_ids:
		var s := id - 1
		var who := e.owners[s]
		if who != player and not sim.vision.sees_unit(player, id):
			continue
		if who != player and sim.combat.enabled() and sim.combat.is_hidden(id):
			continue
		var c := UnitView.PLAYER_COLORS[who % UnitView.PLAYER_COLORS.size()]
		var at := _to_local * Vector2(float(e.pos_x[s]) / Fixed.ONE, float(e.pos_y[s]) / Fixed.ONE)
		_marks.draw_rect(Rect2(at - Vector2(DOT, DOT) / 2.0, Vector2(DOT, DOT)), c)


func _age_pings(delta: float) -> void:
	var halo := 0.0
	var left: Array[Dictionary] = []
	for p in _pings:
		var age: float = p["age"] + delta
		if age >= _ping_length(p["kind"]):
			continue
		p["age"] = age
		left.append(p)
		if p["kind"] == MinimapAlerts.Kind.ATTACK:
			halo = maxf(halo, _blink(age))
	_pings = left
	_halo.visible = halo > 0.0
	(_halo.material as ShaderMaterial).set_shader_parameter(&"strength", halo)
	(_halo.material as ShaderMaterial).set_shader_parameter(&"size", size)
	_ping_layer.queue_redraw()


static func _ping_length(kind: int) -> float:
	return BLINK * (ATTACK_BLINKS if kind == MinimapAlerts.Kind.ATTACK else BUILT_BLINKS)


## 0 -> 1 -> 0 within each blink.
static func _blink(age: float) -> float:
	return sin(fmod(age, BLINK) / BLINK * PI)


func _draw_pings() -> void:
	for p in _pings:
		var age: float = p["age"]
		var on := _blink(age)
		var attack: bool = p["kind"] == MinimapAlerts.Kind.ATTACK
		var c := ATTACK_COLOR if attack else BUILT_COLOR
		var at := _to_local * (p["cell"] as Vector2)
		var grow := fmod(age, BLINK) / BLINK
		var dot := 3.0 + 3.0 * on
		var box := Rect2(at - Vector2(dot, dot), Vector2(dot, dot) * 2.0)
		_ping_layer.draw_rect(box.grow(1.0), Color(0, 0, 0, on))
		_ping_layer.draw_rect(box, Color(c.lightened(0.3 * on), on))
		var ring := Color(c, 1.0 - grow * 0.7)
		_ping_layer.draw_arc(at, 5.0 + 14.0 * grow, 0.0, TAU, 32, ring, 2.0)
		if attack:
			_ping_layer.draw_arc(at, 3.0 + 7.0 * grow, 0.0, TAU, 24, Color(ring, ring.a * 0.6), 1.5)


func _draw_camera() -> void:
	if camera == null:
		return
	var view := camera.get_viewport_rect().size / camera.zoom
	var r := Rect2(camera.position - view / 2.0, view)
	var to_local := Transform2D(0.0, Vector2(_scale, _scale), 0.0, _to_local.origin)
	var p := PackedVector2Array(
		[
			to_local * r.position,
			to_local * Vector2(r.end.x, r.position.y),
			to_local * r.end,
			to_local * Vector2(r.position.x, r.end.y),
			to_local * r.position,
		]
	)
	_frame.draw_polyline(p, Color(1, 1, 1, 0.9), 1.0)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		_dragging = mb.pressed
		if mb.pressed:
			_look(mb.position)
		accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		_look(motion.position)
		accept_event()


## Centres the camera on the map point under a local position.
func _look(local: Vector2) -> void:
	if camera == null or _scale <= 0.0:
		return
	camera.look_at_point(screen_point(local))


## The world (screen-space) point under a local position of the minimap.
func screen_point(local: Vector2) -> Vector2:
	return (local - _to_local.origin) / _scale


## Local position of a cell point (for tests).
func local_of_cell(cell: Vector2) -> Vector2:
	return _to_local * cell
