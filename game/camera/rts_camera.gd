class_name RtsCamera
extends Camera2D
## RTS camera: scroll with WASD or the arrows, or by pushing the mouse to the screen edge;
## zoom with the wheel; never leaves the map.

const SCROLL_SPEED := 900.0
const EDGE_MARGIN := 8.0
const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.0
const ZOOM_STEP := 0.1

## Screen-space rectangle of the map; the view's centre stays inside it.
var bounds := Rect2()
var edge_scroll := true


func _ready() -> void:
	GameInput.ensure_actions()


func _process(delta: float) -> void:
	var dir := Input.get_vector(&"cam_left", &"cam_right", &"cam_up", &"cam_down")
	if edge_scroll and dir == Vector2.ZERO and DisplayServer.window_is_focused():
		dir = edge_direction(get_viewport().get_mouse_position(), get_viewport_rect().size)
	if dir != Vector2.ZERO:
		position += dir * SCROLL_SPEED * delta / zoom.x
	position = clamp_to_bounds(position, bounds)


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


## Scroll direction from the mouse near the screen edge, (0, 0) when it is not.
static func edge_direction(mouse: Vector2, screen: Vector2) -> Vector2:
	var d := Vector2.ZERO
	if mouse.x < 0 or mouse.y < 0 or mouse.x > screen.x or mouse.y > screen.y:
		return d
	if mouse.x <= EDGE_MARGIN:
		d.x = -1
	elif mouse.x >= screen.x - EDGE_MARGIN:
		d.x = 1
	if mouse.y <= EDGE_MARGIN:
		d.y = -1
	elif mouse.y >= screen.y - EDGE_MARGIN:
		d.y = 1
	return d


static func clamp_to_bounds(p: Vector2, rect: Rect2) -> Vector2:
	if rect.size == Vector2.ZERO:
		return p
	return Vector2(
		clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y)
	)
