class_name PlayerInput
extends Control
## Mouse and keyboard of the local player: select units (click, drag box, Shift, double click
## for all of a type on screen, Ctrl+1…9 groups) and give orders as simulation commands
## (right click: move in the chosen formation, or attack the enemy under the cursor; Ctrl+right
## click: attack-move; Shift+right click: rally point; H: stop; Z / X / C: aggressive, defensive,
## stand ground; T: «Литовский отход», G: «Разворот», V: dismount). Draws the drag box.
## Economy (M5): with peasants selected, B picks a building to place (B again for the next one,
## F to turn it, left click to lay it, a drag for a palisade line, right click or Esc to stop);
## right click gathers (forest, deposit, own field or hive, an animal), builds or repairs an
## own building, or assaults an enemy one. A click on an own building selects it: Z X C V B N M
## queue its units, techs and the next age, Backspace cancels the last, right click sets
## where its units go.

signal formation_changed(kind: Formation.Kind)
## The selected building, the building being placed or its place changed (for the status line).
signal economy_changed

## Keys that queue a selected building's items, by position in its list.
const QUEUE_KEYS: Array[Key] = [KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B, KEY_N, KEY_M]

## Drags shorter than this many pixels count as clicks.
const DRAG_THRESHOLD := 6.0
## A right click this close (pixels) to an enemy attacks it.
const PICK_RADIUS := 14.0
## Pressing a group's number twice within this many ms centres the camera on it.
const DOUBLE_TAP_MS := 400

var sim: Simulation
var units: UnitLayer
var camera: RtsCamera
var buildings: BuildingLayer
var player := 1
var selection := Selection.new()
var formation := Formation.Kind.LINE
## The local player's selected building (BuildingStore id).
var selected_building := BuildingStore.NO_ID
## Building being placed (null when not placing), and EconomySystem.Fail at the cursor; below,
## whether it is turned on its side and where a palisade drag started (x < 0 when not).
var placing: BuildingDef
var place_fail := 0

var _drag_from := Vector2.ZERO
var _dragging := false
var _drag_to := Vector2.ZERO
var _last_group := -1
var _last_group_ms := 0
var _turned := false
var _wall_from := Vector2i(-1, -1)
var _cursor_cell := Vector2i.ZERO


func _ready() -> void:
	GameInput.ensure_actions()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	selection.changed.connect(_show_selection)


func attach(
	p_sim: Simulation, p_units: UnitLayer, p_camera: RtsCamera, p_buildings: BuildingLayer = null
) -> void:
	sim = p_sim
	units = p_units
	camera = p_camera
	buildings = p_buildings
	sim_ticked_cleanup()


func _unhandled_input(event: InputEvent) -> void:
	if sim == null:
		return
	var mb := event as InputEventMouseButton
	if mb != null:
		_mouse_button(mb)
		return
	var motion := event as InputEventMouseMotion
	if motion != null and placing != null:
		_update_ghost(motion.position)
		return
	if motion != null and _dragging:
		_drag_to = motion.position
		queue_redraw()
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		_key(key)


func _mouse_button(mb: InputEventMouseButton) -> void:
	if placing != null:
		_placing_click(mb)
		return
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
				_select_building(mb.position if selection.ids.is_empty() else Vector2(-1, -1))
			else:
				selection.box(
					Rect2(_drag_from, mb.position - _drag_from), c[0], c[1], mb.shift_pressed
				)
				_select_building(Vector2(-1, -1))
	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		var at := Iso.screen_to_fixed(_to_world(mb.position))
		if mb.shift_pressed:
			_order(SimCommand.rally(sim.tick, player, at.x, at.y))
			return
		if selected_building != BuildingStore.NO_ID and selection.ids.is_empty():
			var b := PackedInt32Array([selected_building])
			_order(SimCommand.building_rally(sim.tick, player, b, at.x, at.y))
			return
		if selection.ids.is_empty():
			return
		if _economy_order(mb.position, at):
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
		if placing != null:
			_stop_placing()
		else:
			selection.clear()
			_select_building(Vector2(-1, -1))
	elif selection.ids.is_empty():
		_building_key(key)
	elif key.physical_keycode == KEY_B and _peasants().size() > 0:
		_next_building(-1 if key.shift_pressed else 1)
	elif key.physical_keycode == KEY_F and placing != null:
		_turned = not _turned
		_update_ghost(get_viewport().get_mouse_position())
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
	if (
		selected_building != BuildingStore.NO_ID
		and not sim.economy.buildings.is_alive(selected_building)
	):
		_select_building(Vector2(-1, -1))
	if placing != null:
		_update_ghost(get_viewport().get_mouse_position())


# --- economy ---------------------------------------------------------------------------------


## Selected units that can gather and build.
func _peasants() -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in selection.ids:
		var def := sim.economy.unit_defs[id - 1]
		if def != null and def.has_class(&"peasant"):
			out.append(id)
	return out


## Right click with units: work on what is under the cursor. False if it is plain ground.
func _economy_order(screen_point: Vector2, at: Vector2i) -> bool:
	var cell_xy := Vector2i(Fixed.to_cells(at.x), Fixed.to_cells(at.y))
	if not sim.economy.enabled() or not sim.nav.in_bounds(cell_xy.x, cell_xy.y):
		return false
	var cell := sim.nav.cell_at(cell_xy.x, cell_xy.y)
	var workers := _peasants()
	var cmd: SimCommand = null
	var b := sim.economy.buildings.occupant[cell]
	if b != BuildingStore.NO_ID:
		cmd = _building_command(b, workers)
	elif not workers.is_empty():
		cmd = _gather_command(screen_point, cell, at, workers)
	if cmd != null:
		_order(cmd)
	return cmd != null


## An enemy building is assaulted; an own one is built, repaired, or worked (field, hive).
func _building_command(b: int, workers: PackedInt32Array) -> SimCommand:
	var store := sim.economy.buildings
	var s := b - 1
	if store.owners[s] != player:
		return SimCommand.on_building(sim.tick, player, SimCommand.Kind.ASSAULT, selection.ids, b)
	if workers.is_empty():
		return null
	var whole := store.done[s] == 1 and store.hp[s] >= store.max_hp[s]
	if whole and sim.economy.building_source(player, b) >= 0:
		return SimCommand.gather(sim.tick, player, workers, EconomySystem.Target.BUILDING, b)
	return SimCommand.on_building(sim.tick, player, SimCommand.Kind.WORK, workers, b)


## Hunt the animal under the cursor, or gather from the deposit or forest cell there.
func _gather_command(
	screen_point: Vector2, cell: int, at: Vector2i, workers: PackedInt32Array
) -> SimCommand:
	var animal := _animal_at(screen_point)
	if animal != EntityStore.NO_ID:
		return SimCommand.gather(sim.tick, player, workers, EconomySystem.Target.ANIMAL, animal)
	var node := sim.economy.nodes.at_cell(cell)
	if node != ResourceNodes.NO_ID:
		return SimCommand.gather(sim.tick, player, workers, EconomySystem.Target.NODE, node)
	if sim.economy.nodes.wood[cell] > 0:
		return SimCommand.gather_at(sim.tick, player, workers, at.x, at.y)
	return null


## A neutral animal near the screen point, or NO_ID.
func _animal_at(screen_point: Vector2) -> int:
	var to_screen := get_viewport().get_canvas_transform()
	var best := EntityStore.NO_ID
	var best_d := PICK_RADIUS
	for id: int in units.views:
		var v := units.views[id]
		if v.player != 0:
			continue
		var d := (to_screen * v.global_position).distance_to(screen_point)
		if d < best_d:
			best = id
			best_d = d
	return best


## Buildings the player may lay now, in catalog order (by id).
func buildable() -> Array[BuildingDef]:
	var out: Array[BuildingDef] = []
	var state := sim.economy.player(player)
	if state == null:
		return out
	var ids := PackedStringArray()
	for id: StringName in sim.economy.db.buildings:
		var def: BuildingDef = sim.economy.db.buildings[id]
		if def.faction == state.faction and not def.campaign_only and def.age <= state.age:
			if not def.tags.has(&"power_place_only"):
				ids.append(String(id))
	ids.sort()
	for id in ids:
		out.append(sim.economy.db.building(StringName(id)))
	return out


func _next_building(step: int) -> void:
	var list := buildable()
	if list.is_empty():
		return
	var i := list.find(placing) if placing != null else -1
	placing = list[wrapi(i + step, 0, list.size())] if i >= 0 or step > 0 else list[-1]
	_wall_from = Vector2i(-1, -1)
	_update_ghost(get_viewport().get_mouse_position())


func _stop_placing() -> void:
	placing = null
	_wall_from = Vector2i(-1, -1)
	if buildings != null:
		buildings.ghost = Rect2i()
		buildings.ghost_line.clear()
		buildings.ghost_line_ok.clear()
		buildings.queue_redraw()
	economy_changed.emit()


## Top-left cell of the ghost: the footprint centred on the cell under the cursor.
func _ghost_origin(size: Vector2i) -> Vector2i:
	return _cursor_cell - Vector2i((size.x - 1) / 2, (size.y - 1) / 2)


func _update_ghost(screen_point: Vector2) -> void:
	if placing == null or buildings == null:
		return
	_cursor_cell = Iso.screen_to_cell_index(_to_world(screen_point))
	var eco := sim.economy
	buildings.ghost_line.clear()
	buildings.ghost_line_ok.clear()
	if BuildingPlacement.is_wall(placing) and _wall_from.x >= 0:
		buildings.ghost = Rect2i()
		var line := BuildingPlacement.wall_cells(
			_wall_from.x, _wall_from.y, _cursor_cell.x, _cursor_cell.y
		)
		for c in line:
			buildings.ghost_line.append(c)
			buildings.ghost_line_ok.append(
				eco.placement.can_place(player, placing, c.x, c.y, false) == EconomySystem.Fail.OK
			)
		place_fail = EconomySystem.Fail.OK
	else:
		var size := eco.placement.footprint(placing, _turned)
		var origin := _ghost_origin(size)
		place_fail = eco.placement.can_place(player, placing, origin.x, origin.y, _turned)
		if place_fail == EconomySystem.Fail.OK:
			var cost := eco.placement.building_cost(player, placing)
			if not eco.player(player).can_pay(cost):
				place_fail = EconomySystem.Fail.COST
		buildings.ghost = Rect2i(origin, size)
		buildings.ghost_ok = place_fail == EconomySystem.Fail.OK
	buildings.queue_redraw()
	economy_changed.emit()


func _placing_click(mb: InputEventMouseButton) -> void:
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		_stop_placing()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	_update_ghost(mb.position)
	var workers := _peasants()
	if BuildingPlacement.is_wall(placing):
		if mb.pressed:
			_wall_from = _cursor_cell
			_update_ghost(mb.position)
			return
		if _wall_from.x < 0:
			return
		var a := Vector2i(Fixed.from_cells(_wall_from.x), Fixed.from_cells(_wall_from.y))
		var b := Vector2i(Fixed.from_cells(_cursor_cell.x), Fixed.from_cells(_cursor_cell.y))
		var half := Vector2i(Fixed.HALF, Fixed.HALF)
		_order(SimCommand.wall(sim.tick, player, workers, placing.id, a + half, b + half))
		_wall_from = Vector2i(-1, -1)
	else:
		if not mb.pressed or place_fail != EconomySystem.Fail.OK:
			return
		var origin := _ghost_origin(sim.economy.placement.footprint(placing, _turned))
		var x := Fixed.from_cells(origin.x) + Fixed.HALF
		var y := Fixed.from_cells(origin.y) + Fixed.HALF
		_order(SimCommand.build(sim.tick, player, workers, placing.id, x, y, _turned))
	if not mb.shift_pressed:
		_stop_placing()


## Left click on nothing but an own building selects it (any other click clears it).
func _select_building(screen_point: Vector2) -> void:
	var picked := BuildingStore.NO_ID
	if screen_point.x >= 0:
		var c := Iso.screen_to_cell_index(_to_world(screen_point))
		if sim.nav.in_bounds(c.x, c.y):
			var b := sim.economy.buildings.occupant[sim.nav.cell_at(c.x, c.y)]
			if b != BuildingStore.NO_ID and sim.economy.buildings.owners[b - 1] == player:
				picked = b
	selected_building = picked
	if buildings != null:
		buildings.selected = picked
		buildings.queue_redraw()
	economy_changed.emit()


## What the selected building can queue: its units, techs of its kind, the next age.
func queue_items() -> Array[StringName]:
	var out: Array[StringName] = []
	if selected_building == BuildingStore.NO_ID:
		return out
	var eco := sim.economy
	var def := eco.buildings.defs[selected_building - 1]
	var state := eco.player(player)
	for u in def.trains:
		var ud := eco.db.unit(u)
		if ud != null and ud.faction == state.faction and not ud.campaign_only:
			out.append(u)
	var techs := PackedStringArray()
	var fac := eco.db.faction(state.faction)
	for id: StringName in eco.db.techs:
		var t: TechDef = eco.db.techs[id]
		var here := t.building == def.id or t.building == def.base_id
		if here and fac != null and fac.tech_ids.has(id) and not t.effects.is_empty():
			techs.append(String(id))
	techs.sort()
	for id in techs:
		out.append(StringName(id))
	if def.base_id == EconomySystem.TOWN_CENTER:
		var next := eco.db.age_by_index(state.age + 1)
		if next != null:
			out.append(next.id)
	return out


func _building_key(key: InputEventKey) -> void:
	if selected_building == BuildingStore.NO_ID:
		return
	if key.physical_keycode == KEY_BACKSPACE:
		var q: Array = sim.economy.buildings.queues[selected_building - 1]
		if not q.is_empty():
			_order(SimCommand.cancel_item(sim.tick, player, selected_building, q.size() - 1))
		return
	var i := QUEUE_KEYS.find(key.physical_keycode)
	var items := queue_items()
	if i >= 0 and i < items.size():
		_order(SimCommand.queue_item(sim.tick, player, selected_building, items[i]))


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
