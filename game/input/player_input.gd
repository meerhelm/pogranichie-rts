class_name PlayerInput
extends Control
## Mouse and keyboard of the local player: select units (click, drag box, Shift, double click
## for all of a type on screen, Ctrl+1…9 groups) and give orders as simulation commands
## (right click: move in the chosen formation, or attack the enemy under the cursor; Ctrl+right
## click: attack-move; Shift+right click: rally point; H: stop; Z / X / C: aggressive, defensive,
## stand ground; T: «Литовский отход», G: «Разворот», V: dismount). Draws the drag box.

signal formation_changed(kind: Formation.Kind)

## Drags shorter than this many pixels count as clicks.
const DRAG_THRESHOLD := 6.0
## A right click this close (pixels) to an enemy attacks it.
const PICK_RADIUS := 14.0
## Pressing a group's number twice within this many ms centres the camera on it.
const DOUBLE_TAP_MS := 400

var sim: Simulation
var units: UnitLayer
var camera: RtsCamera
var player := 1
var selection := Selection.new()
var formation := Formation.Kind.LINE

var _drag_from := Vector2.ZERO
var _dragging := false
var _drag_to := Vector2.ZERO
var _last_group := -1
var _last_group_ms := 0


func _ready() -> void:
	GameInput.ensure_actions()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	selection.changed.connect(_show_selection)


func attach(p_sim: Simulation, p_units: UnitLayer, p_camera: RtsCamera) -> void:
	sim = p_sim
	units = p_units
	camera = p_camera
	sim_ticked_cleanup()


func _unhandled_input(event: InputEvent) -> void:
	if sim == null:
		return
	var mb := event as InputEventMouseButton
	if mb != null:
		_mouse_button(mb)
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		_drag_to = motion.position
		queue_redraw()
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		_key(key)


func _mouse_button(mb: InputEventMouseButton) -> void:
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_dragging = true
			_drag_from = mb.position
			_drag_to = mb.position
			if mb.double_click:
				_dragging = false
				var c := _candidates(true)
				selection.same_type(mb.position, c[0], c[1], c[2], mb.shift_pressed)
		elif _dragging:
			_dragging = false
			queue_redraw()
			var c := _candidates(false)
			if _drag_from.distance_to(mb.position) < DRAG_THRESHOLD:
				selection.click(mb.position, c[0], c[1], mb.shift_pressed)
			else:
				selection.box(
					Rect2(_drag_from, mb.position - _drag_from), c[0], c[1], mb.shift_pressed
				)
	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		var at := Iso.screen_to_fixed(_to_world(mb.position))
		if mb.shift_pressed:
			_order(SimCommand.rally(sim.tick, player, at.x, at.y))
			return
		if selection.ids.is_empty():
			return
		var enemy := _enemy_at(mb.position)
		if enemy != EntityStore.NO_ID:
			_order(SimCommand.attack(sim.tick, player, selection.ids, enemy))
		elif mb.ctrl_pressed:
			_order(SimCommand.attack_move(sim.tick, player, selection.ids, at.x, at.y, formation))
		else:
			_order(SimCommand.move(sim.tick, player, selection.ids, at.x, at.y, formation))


func _key(key: InputEventKey) -> void:
	var digit := key.physical_keycode - KEY_0
	if digit >= 1 and digit <= 9:
		if key.ctrl_pressed:
			selection.assign_group(digit)
		else:
			var found := selection.recall_group(digit, sim.entities.is_alive)
			var now := Time.get_ticks_msec()
			if found and digit == _last_group and now - _last_group_ms < DOUBLE_TAP_MS:
				_center_on_selection()
			_last_group = digit
			_last_group_ms = now
		return
	if key.is_action(&"formation_line"):
		_set_formation(Formation.Kind.LINE)
	elif key.is_action(&"formation_column"):
		_set_formation(Formation.Kind.COLUMN)
	elif key.is_action(&"formation_wedge"):
		_set_formation(Formation.Kind.WEDGE)
	elif key.physical_keycode == KEY_ESCAPE:
		selection.clear()
	elif selection.ids.is_empty():
		pass
	elif key.is_action(&"stop"):
		_order(SimCommand.stop(sim.tick, player, selection.ids))
	elif key.is_action(&"stance_aggressive"):
		_order(
			SimCommand.set_stance(sim.tick, player, selection.ids, EntityStore.Stance.AGGRESSIVE)
		)
	elif key.is_action(&"stance_defensive"):
		_order(SimCommand.set_stance(sim.tick, player, selection.ids, EntityStore.Stance.DEFENSIVE))
	elif key.is_action(&"stance_stand"):
		_order(SimCommand.set_stance(sim.tick, player, selection.ids, EntityStore.Stance.STAND))
	elif key.is_action(&"lithuanian_retreat"):
		_order(SimCommand.order(sim.tick, player, SimCommand.Kind.RETREAT, selection.ids))
	elif key.is_action(&"turn_around"):
		_order(SimCommand.order(sim.tick, player, SimCommand.Kind.TURN, selection.ids))
	elif key.is_action(&"dismount"):
		_order(SimCommand.order(sim.tick, player, SimCommand.Kind.DISMOUNT, selection.ids))


func _draw() -> void:
	if _dragging and _drag_from.distance_to(_drag_to) >= DRAG_THRESHOLD:
		var r := Rect2(_drag_from, _drag_to - _drag_from).abs()
		draw_rect(r, Color(0.4, 1.0, 0.4, 0.12))
		draw_rect(r, Color(0.4, 1.0, 0.4, 0.9), false, 1.0)


## Called after ticks: units that died leave the selection and the groups.
func sim_ticked_cleanup() -> void:
	selection.forget_dead(sim.entities.is_alive)


func _set_formation(kind: Formation.Kind) -> void:
	formation = kind
	formation_changed.emit(kind)


func _order(cmd: SimCommand) -> void:
	sim.enqueue(cmd)


## The player's own units: [ids, screen points, types]; only those on screen if visible_only.
func _candidates(visible_only: bool) -> Array:
	var cand_ids := PackedInt32Array()
	var points := PackedVector2Array()
	var types: Array[StringName] = []
	var screen := get_viewport_rect()
	var to_screen := get_viewport().get_canvas_transform()
	for id: int in units.views:
		var v := units.views[id]
		if v.player != player:
			continue
		var p := to_screen * v.global_position
		if visible_only and not screen.has_point(p):
			continue
		cand_ids.append(id)
		points.append(p)
		types.append(v.type_id)
	return [cand_ids, points, types]


## The visible enemy unit nearest to the screen point within PICK_RADIUS, or NO_ID.
func _enemy_at(screen_point: Vector2) -> int:
	var to_screen := get_viewport().get_canvas_transform()
	var best := EntityStore.NO_ID
	var best_d := PICK_RADIUS
	for id: int in units.views:
		var v := units.views[id]
		if v.player == player or v.player == 0 or not v.visible:
			continue
		var d := (to_screen * (v.global_position + Vector2(0, -UnitView.RADIUS))).distance_to(
			screen_point
		)
		if d < best_d:
			best = id
			best_d = d
	return best


func _to_world(screen_point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_point


func _center_on_selection() -> void:
	var sum := Vector2.ZERO
	for id in selection.ids:
		sum += units.views[id].global_position
	camera.look_at_point(sum / selection.ids.size())


func _show_selection() -> void:
	for id: int in units.views:
		units.views[id].selected = selection.has(id)
