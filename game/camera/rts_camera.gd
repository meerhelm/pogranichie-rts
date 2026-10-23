class_name RtsCamera
extends Camera2D
## RTS camera: scroll with WASD or the arrows, or by pushing the mouse to the screen edge;
## zoom with the wheel; never leaves the map.

const SCROLL_SPEED := 900.0
## Edge zone width as a share of the view's shorter side (about 43 px at 1080 lines),
## never thinner than EDGE_MIN pixels.
const EDGE_SHARE := 0.04
const EDGE_MIN := 16.0
## Speed share at the inner side of the edge zone; it grows to full at the very edge.
const EDGE_SLOW := 0.3
## Over a button, list or the minimap only this thin strip at the very edge scrolls, so
## pointing at a control near the edge does not move the map. Panel backgrounds (the top
## bar, the bottom panel) do not count: there the whole edge zone works.
const EDGE_OVER_UI := 10.0
const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.0
const ZOOM_STEP := 0.1

## Screen-space rectangle of the map; the view's centre stays inside it.
var bounds := Rect2()
var edge_scroll := true
## Edge scrolling speed multiplier (GameSettings.EDGE_SPEEDS).
var edge_speed := 1.0
## Scroll while the mouse is outside the window: it left across an edge zone (a windowed
## game, the hand overshot), so the map goes on moving that way until it comes back.
var _outside_dir := Vector2.ZERO
var _mouse_inside := true


func _ready() -> void:
	GameInput.ensure_actions()


func _process(delta: float) -> void:
	var dir := Input.get_vector(&"cam_left", &"cam_right", &"cam_up", &"cam_down")
	if edge_scroll and dir == Vector2.ZERO and DisplayServer.window_is_focused():
		if _mouse_inside:
			var over_ui := over_control(get_viewport().gui_get_hovered_control())
			var mouse := get_viewport().get_mouse_position()
			dir = edge_direction(mouse, get_viewport_rect().size, over_ui)
		else:
			dir = _outside_dir
		dir *= edge_speed
	if dir != Vector2.ZERO:
		position += dir * SCROLL_SPEED * delta / zoom.x
	position = clamp_to_bounds(position, bounds)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_mouse_inside = false
		var d := edge_direction(get_viewport().get_mouse_position(), get_viewport_rect().size)
		_outside_dir = d.sign()
	elif what == NOTIFICATION_WM_MOUSE_ENTER:
		_mouse_inside = true


func _unhandled_input(event: InputEvent) -> void:
	var wheel := event as InputEventMouseButton
	if wheel == null or not wheel.pressed:
		return
	if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_by(ZOOM_STEP)
	elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_by(-ZOOM_STEP)


func zoom_by(step: float) -> void:
	var z := clampf(zoom.x + step, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(z, z)


func look_at_point(p: Vector2) -> void:
	position = clamp_to_bounds(p, bounds)


## Whether the mouse points at a control the player uses (a button, a list, a slider, the
## minimap) rather than at a panel's background or a label.
static func over_control(hovered: Control) -> bool:
	var c: Node = hovered
	for i in 4:
		if c == null:
			return false
		if c is BaseButton or c is Range or c is ItemList or c is LineEdit or c is Minimap:
			return true
		c = c.get_parent()
	return false


## Width of the edge zone in pixels for a window (or screen) of this size.
static func edge_zone(screen: Vector2) -> float:
	return maxf(EDGE_MIN, minf(screen.x, screen.y) * EDGE_SHARE)


## Scroll from the mouse near the screen edge: each axis from -1 to 1, slow at the inner
## side of the edge zone and full at the edge; (0, 0) away from the edges. A point just past
## the edge (by less than the zone) counts as the edge; further out, as gone.
## Over the interface the zone is only EDGE_OVER_UI pixels wide, at full speed.
static func edge_direction(mouse: Vector2, screen: Vector2, over_ui := false) -> Vector2:
	var zone := edge_zone(screen)
	if not Rect2(Vector2.ZERO, screen).grow(zone).has_point(mouse):
		return Vector2.ZERO
	var slow := EDGE_SLOW
	if over_ui:
		zone = EDGE_OVER_UI
		slow = 1.0
	return Vector2(
		_edge_axis(mouse.x, screen.x, zone, slow), _edge_axis(mouse.y, screen.y, zone, slow)
	)


static func _edge_axis(at: float, length: float, zone: float, slow: float) -> float:
	if at < zone:
		return -_edge_strength(at, zone, slow)
	if at > length - 1.0 - zone:
		return _edge_strength(length - 1.0 - at, zone, slow)
	return 0.0


static func _edge_strength(dist: float, zone: float, slow: float) -> float:
	if dist <= 0.0:
		return 1.0
	return lerpf(1.0, slow, dist / zone)


static func clamp_to_bounds(p: Vector2, rect: Rect2) -> Vector2:
	if rect.size == Vector2.ZERO:
		return p
	return Vector2(
		clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y)
	)
