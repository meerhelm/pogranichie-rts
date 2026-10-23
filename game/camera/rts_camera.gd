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
## Over the interface (top bar, bottom panel, minimap, windows) only this thin strip at the
## very edge scrolls, so hovering a button near the edge does not move the map.
const EDGE_OVER_UI := 6.0
const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.0
const ZOOM_STEP := 0.1

## Screen-space rectangle of the map; the view's centre stays inside it.
var bounds := Rect2()
var edge_scroll := true
## Edge scrolling speed multiplier (GameSettings.EDGE_SPEEDS).
var edge_speed := 1.0
## The viewport keeps the last mouse position after the mouse leaves the window, so edge
## scrolling stops while it is outside.
var _mouse_inside := true


func _ready() -> void:
	GameInput.ensure_actions()


func _process(delta: float) -> void:
	var dir := Input.get_vector(&"cam_left", &"cam_right", &"cam_up", &"cam_down")
	if edge_scroll and dir == Vector2.ZERO and _mouse_inside and DisplayServer.window_is_focused():
		var over_ui := get_viewport().gui_get_hovered_control() != null
		dir = edge_direction(get_viewport().get_mouse_position(), get_viewport_rect().size, over_ui)
		dir *= edge_speed
	if dir != Vector2.ZERO:
		position += dir * SCROLL_SPEED * delta / zoom.x
	position = clamp_to_bounds(position, bounds)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_mouse_inside = false
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
