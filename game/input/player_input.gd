class_name PlayerInput
extends Control
## Mouse and keyboard of the local player: select units (click, drag box, Shift, double click
## for all of a type on screen, Ctrl+1…9 groups) and give orders as simulation commands
## (right click: move in the chosen formation, or attack the enemy under the cursor; Ctrl+right
## click: attack-move; Shift+right click: rally point; H: stop; Z / X / C: aggressive, defensive,
## stand ground; T: «Литовский отход», G: «Разворот», V: dismount). Draws the drag box.
## Esc with nothing to cancel, or F10, asks for the game menu (M6); the HUD's buttons give the
## same orders through order_stop(), order_stance(), start_placing(), queue_item() and the rest.
## Economy (M5): with peasants selected, B picks a building to place (B again for the next one,
## F to turn it, left click to lay it, a drag for a palisade line, right click or Esc to stop);
## right click gathers (forest, deposit, own field or hive, an animal), builds or repairs an
## own building, or assaults an enemy one. A click on an own building selects it: Z X C V B N M
## queue its units, techs and the next age, Backspace cancels the last, right click sets
## where its units go.
## Magic (M7): a spell button of the selected casters casts one aimed at its caster at once; one
## aimed at a point waits for a left click on the map (right click or Esc cancels). A shrine is
## laid on the place of power nearest the cursor.
## Fire (M9): Alt+right click on an enemy building sends the selected units to set it on fire.
## Taking apart (2026-10): with peasants selected, Y (or Delete) and a left click on an own
## building order them to take it apart (right click or Esc cancels).
## Looking (2026-10): a left click on anything that is not the player's own (another side's or
## a wild unit, another side's building, a deposit, a carcass, a forest cell, a place of
## power) shows it in the card without selecting it for orders (`look`, `look_ref`).
## Idle workers (2026-10): . (or the HUD's button) selects the next idle peasant and centres the
## camera on it, the next one on each press; Shift+. selects all of them (IdleWorkers).

signal formation_changed(kind: Formation.Kind)
## The selected building, the building being placed or its place changed (for the HUD).
signal economy_changed
## Esc with nothing to cancel, or F10: open the game menu.
signal menu_requested

## What the card shows when nothing of the player's own is selected (a left click on it).
enum Look { NONE, UNIT, BUILDING, NODE, FOREST, PLACE }

## Keys that queue a selected building's items, by position in its list.
const QUEUE_KEYS: Array[Key] = [KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B, KEY_N, KEY_M]

## Drags shorter than this many pixels count as clicks.
const DRAG_THRESHOLD := 6.0
## A right click this close (pixels) to an enemy attacks it.
const PICK_RADIUS := 14.0
## Pressing a group's number twice within this many ms centres the camera on it.
const DOUBLE_TAP_MS := 400
## A shrine being placed snaps to a place of power this many cells from the cursor.
const SITE_SNAP := 3
## Taking apart: a click this many cells off an own thin building (zaseka, palisade) still
## picks it.
const THIN_PICK_CELLS := 1

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
## Spell waiting for its point (null when not aiming one).
var casting: SpellDef
## Peasants wait for a left click on the own building to take apart (Y); true after a click
## on the last capital, which cannot be.
var taking_apart := false
var take_apart_fail := false
## What is looked at (Look) and which: unit id, building id, node id, map cell or site index.
var look := Look.NONE
var look_ref := 0

var _drag_from := Vector2.ZERO
var _dragging := false
var _drag_to := Vector2.ZERO
var _last_group := -1
var _last_group_ms := 0
var _turned := false
var _wall_from := Vector2i(-1, -1)
var _cursor_cell := Vector2i.ZERO
## Alt was held on the right click being handled (an enemy building is set on fire).
var _torch := false
## The idle worker the last . went to, so the next press goes on to the one after it.
var _last_idle := 0


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
	if casting != null:
		_casting_click(mb)
	elif taking_apart:
		_take_apart_click(mb)
	elif placing != null:
		_placing_click(mb)
	else:
		_plain_click(mb)


## A click with no mode on: select, or order the selection.
func _plain_click(mb: InputEventMouseButton) -> void:
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_dragging = true
			_drag_from = mb.position
			_drag_to = mb.position
			if mb.double_click:
				_dragging = false
				var c := _candidates(true)
				var hit := _own_unit_under(mb.position)
				selection.same_type(mb.position, c[0], c[1], c[2], mb.shift_pressed, hit)
		elif _dragging:
			_dragging = false
			queue_redraw()
			var c := _candidates(false)
			if _drag_from.distance_to(mb.position) < DRAG_THRESHOLD:
				var hit := _own_unit_under(mb.position)
				selection.click(mb.position, c[0], c[1], mb.shift_pressed, hit)
				_select_building(mb.position if selection.ids.is_empty() else Vector2(-1, -1))
				var free := selection.ids.is_empty() and selected_building == BuildingStore.NO_ID
				_look_at(mb.position if free else Vector2(-1, -1))
			else:
				selection.box(
					Rect2(_drag_from, mb.position - _drag_from), c[0], c[1], mb.shift_pressed
				)
				_select_building(Vector2(-1, -1))
				_look_at(Vector2(-1, -1))
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
		_torch = mb.alt_pressed
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
	if key.physical_keycode in [KEY_PERIOD, KEY_KP_PERIOD]:
		select_idle_worker(key.shift_pressed)
		return
	if key.is_action(&"formation_line"):
		_set_formation(Formation.Kind.LINE)
	elif key.is_action(&"formation_column"):
		_set_formation(Formation.Kind.COLUMN)
	elif key.is_action(&"formation_wedge"):
		_set_formation(Formation.Kind.WEDGE)
	elif key.physical_keycode == KEY_F10:
		_request_menu()
	elif key.physical_keycode == KEY_ESCAPE:
		if casting != null:
			stop_casting()
		elif taking_apart:
			stop_taking_apart()
		elif placing != null:
			_stop_placing()
		elif look != Look.NONE:
			_look_at(Vector2(-1, -1))
		elif selection.ids.is_empty() and selected_building == BuildingStore.NO_ID:
			_request_menu()
		else:
			selection.clear()
			_select_building(Vector2(-1, -1))
	elif selection.ids.is_empty():
		_building_key(key)
	elif key.physical_keycode == KEY_B and builders().size() > 0:
		_next_building(-1 if key.shift_pressed else 1)
	elif key.physical_keycode in [KEY_Y, KEY_DELETE] and _peasants().size() > 0:
		start_taking_apart()
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
	elif key.physical_keycode == KEY_U:
		_order(SimCommand.order(sim.tick, player, SimCommand.Kind.TABOR, selection.ids))


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
	if taking_apart and _peasants().is_empty():
		stop_taking_apart()
	if look != Look.NONE and not _still_seen():
		_look_at(Vector2(-1, -1))


# --- looking at things -----------------------------------------------------------------------


## Looks at what is under the screen point (nothing for x < 0): another side's or a wild unit,
## another side's building the player has seen, a resource node, a forest cell or a place of
## power on explored ground, in that order.
func _look_at(screen_point: Vector2) -> void:
	var kind := Look.NONE
	var ref := 0
	if screen_point.x >= 0:
		var unit := _other_unit_at(screen_point)
		var c := Iso.screen_to_cell_index(_to_world(screen_point))
		if unit != EntityStore.NO_ID:
			kind = Look.UNIT
			ref = unit
		elif sim.nav.in_bounds(c.x, c.y):
			var cell := sim.nav.cell_at(c.x, c.y)
			var known := sim.vision.state(player, cell) != VisionSystem.State.UNEXPLORED
			var b := sim.economy.buildings.occupant[cell]
			var site := sim.magic.places.site_near(c.x, c.y, 1)
			if b != BuildingStore.NO_ID and _building_known(b):
				kind = Look.BUILDING
				ref = b
			elif known and sim.economy.nodes.at_cell(cell) != ResourceNodes.NO_ID:
				kind = Look.NODE
				ref = sim.economy.nodes.at_cell(cell)
			elif known and sim.economy.nodes.wood[cell] > 0:
				kind = Look.FOREST
				ref = cell
			elif known and site >= 0:
				kind = Look.PLACE
				ref = site
	look = kind
	look_ref = ref
	for id: int in units.views:
		units.views[id].looked = kind == Look.UNIT and id == ref
	if buildings != null:
		buildings.looked = ref if kind == Look.BUILDING else BuildingStore.NO_ID
		buildings.look_cells = _look_rect()
		buildings.queue_redraw()
	economy_changed.emit()


## Cells outlined for what is looked at on the ground (a node, a forest cell, a site).
func _look_rect() -> Rect2i:
	var w := sim.nav.width
	match look:
		Look.NODE:
			var cell := sim.economy.nodes.cells[look_ref - 1]
			return Rect2i(cell % w, cell / w, 1, 1)
		Look.FOREST:
			return Rect2i(look_ref % w, look_ref / w, 1, 1)
		Look.PLACE:
			var top := sim.magic.places.cells[look_ref]
			return Rect2i(top % w, top / w, PowerPlaces.SITE, PowerPlaces.SITE)
	return Rect2i()


## Whether what is looked at is still there for the player to see.
func _still_seen() -> bool:
	match look:
		Look.UNIT:
			var v: UnitView = units.views.get(look_ref)
			return sim.entities.is_alive(look_ref) and v != null and v.visible
		Look.BUILDING:
			return sim.economy.buildings.is_alive(look_ref)
		Look.NODE:
			return sim.economy.nodes.is_alive(look_ref)
		Look.FOREST:
			return sim.economy.nodes.wood[look_ref] > 0
	return true


## Whether the player knows building b: its own, or seen once (as BuildingLayer draws it).
func _building_known(b: int) -> bool:
	if sim.economy.buildings.owners[b - 1] == player:
		return true
	if buildings != null:
		return buildings.is_known(b)
	return sim.vision.sees_building(player, b)


## Of the views `accept` lets through, the one whose drawn figure is under the screen point;
## where figures overlap, the one drawn in front (lowest on screen). NO_ID if none.
func _unit_under(screen_point: Vector2, accept: Callable) -> int:
	var world := _to_world(screen_point)
	var best := EntityStore.NO_ID
	var best_y := -INF
	for id: int in units.views:
		var v := units.views[id]
		if not accept.call(v):
			continue
		var y := v.global_position.y
		if y < best_y or (y == best_y and id < best):
			continue
		if v.covers(world - v.global_position):
			best = id
			best_y = y
	return best


## The player's own unit whose figure is under the screen point, or NO_ID.
func _own_unit_under(screen_point: Vector2) -> int:
	return _unit_under(screen_point, func(v: UnitView) -> bool: return v.player == player)


## Another side's or a wild unit drawn under or near the screen point, or NO_ID.
func _other_unit_at(screen_point: Vector2) -> int:
	var under := _unit_under(
		screen_point, func(v: UnitView) -> bool: return v.player != player and v.visible
	)
	if under != EntityStore.NO_ID:
		return under
	var to_screen := get_viewport().get_canvas_transform()
	var best := EntityStore.NO_ID
	var best_d := PICK_RADIUS
	for id: int in units.views:
		var v := units.views[id]
		if v.player == player or not v.visible:
			continue
		var body := v.global_position + Vector2(0, -UnitView.RADIUS)
		var d := (to_screen * body).distance_to(screen_point)
		if d < best_d:
			best = id
			best_d = d
	return best


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
		cmd = _building_command(b, builders())
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
		if _torch:
			return SimCommand.ignite(sim.tick, player, selection.ids, b)
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


## A neutral animal under or near the screen point, or NO_ID.
func _animal_at(screen_point: Vector2) -> int:
	var under := _unit_under(screen_point, func(v: UnitView) -> bool: return v.player == 0)
	if under != EntityStore.NO_ID:
		return under
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


## Buildings the player may lay now, in catalog order (by id); priests alone lay only shrines.
func buildable() -> Array[BuildingDef]:
	var out: Array[BuildingDef] = []
	var state := sim.economy.player(player)
	if state == null:
		return out
	var shrines_only := _peasants().is_empty()
	var ids := PackedStringArray()
	for id: StringName in sim.economy.db.buildings:
		var def: BuildingDef = sim.economy.db.buildings[id]
		if shrines_only and not def.tags.has(&"power_place_only"):
			continue
		var campaign := def.campaign_only and not state.allowed.has(def.id)
		if def.faction == state.faction and not campaign and def.age <= state.age:
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


## Top-left cell of the ghost: the footprint centred on the cell under the cursor; a shrine
## snaps to the place of power within SITE_SNAP cells.
func _ghost_origin(size: Vector2i) -> Vector2i:
	if placing != null and placing.tags.has(&"power_place_only"):
		var places := sim.magic.places
		var i := places.site_near(_cursor_cell.x, _cursor_cell.y, SITE_SNAP)
		if i >= 0:
			return Vector2i(places.cells[i] % sim.nav.width, places.cells[i] / sim.nav.width)
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
	var workers := builders()
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
		_order(
			SimCommand.build(sim.tick, player, workers, placing.id, x, y, _turned, mb.shift_pressed)
		)
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
	var s := selected_building - 1
	if def.param(&"upgrade_power_rate_milli") > 0 and eco.buildings.upgraded[s] == 0:
		out.append(EconomyProduction.CHAPEL)
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


func _request_menu() -> void:
	# The key that opened the menu must not reach it too (it would close it again).
	get_viewport().set_input_as_handled()
	menu_requested.emit()


func _set_formation(kind: Formation.Kind) -> void:
	formation = kind
	formation_changed.emit(kind)


# --- orders from the HUD's buttons, the same as the keys -------------------------------------


func set_formation(kind: Formation.Kind) -> void:
	_set_formation(kind)


func order_stop() -> void:
	if not selection.ids.is_empty():
		_order(SimCommand.stop(sim.tick, player, selection.ids))


func order_stance(stance: EntityStore.Stance) -> void:
	if not selection.ids.is_empty():
		_order(SimCommand.set_stance(sim.tick, player, selection.ids, stance))


## RETREAT («Литовский отход»), TURN («Разворот») or DISMOUNT for the selection.
func order_kind(kind: SimCommand.Kind) -> void:
	if not selection.ids.is_empty():
		_order(SimCommand.order(sim.tick, player, kind, selection.ids))


## Starts placing a building with the selected peasants (as B does).
func start_placing(def: BuildingDef) -> void:
	if builders().is_empty():
		return
	taking_apart = false
	placing = def
	_wall_from = Vector2i(-1, -1)
	_update_ghost(get_viewport().get_mouse_position())


func queue_item(item: StringName) -> void:
	if selected_building != BuildingStore.NO_ID:
		_order(SimCommand.queue_item(sim.tick, player, selected_building, item))


func cancel_item(index: int) -> void:
	if selected_building != BuildingStore.NO_ID:
		_order(SimCommand.cancel_item(sim.tick, player, selected_building, index))


# --- taking apart --------------------------------------------------------------------------


## Y: the selected peasants wait for a left click on the own building to take apart.
func start_taking_apart() -> void:
	if _peasants().is_empty():
		return
	if placing != null:
		_stop_placing()
	casting = null
	taking_apart = true
	economy_changed.emit()


func stop_taking_apart() -> void:
	taking_apart = false
	take_apart_fail = false
	economy_changed.emit()


## The building clicked to take apart: the one on the cell, else an own thin one (a zaseka, a
## palisade, a wall piece: its picture stands up over the cells behind it) within
## THIN_PICK_CELLS of it, the nearest.
func _to_take_apart(c: Vector2i) -> int:
	var store := sim.economy.buildings
	var b := store.occupant[sim.nav.cell_at(c.x, c.y)]
	if b != BuildingStore.NO_ID:
		return b
	var best := BuildingStore.NO_ID
	var best_d := 0
	for y in range(c.y - THIN_PICK_CELLS, c.y + THIN_PICK_CELLS + 1):
		for x in range(c.x - THIN_PICK_CELLS, c.x + THIN_PICK_CELLS + 1):
			if not sim.nav.in_bounds(x, y):
				continue
			var o := store.occupant[sim.nav.cell_at(x, y)]
			if o == BuildingStore.NO_ID or store.owners[o - 1] != player:
				continue
			if mini(store.w[o - 1], store.h[o - 1]) != 1:
				continue
			var d := (x - c.x) * (x - c.x) + (y - c.y) * (y - c.y)
			if best == BuildingStore.NO_ID or d < best_d:
				best = o
				best_d = d
	return best


func _take_apart_click(mb: InputEventMouseButton) -> void:
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		var c := Iso.screen_to_cell_index(_to_world(mb.position))
		if sim.nav.in_bounds(c.x, c.y):
			var b := _to_take_apart(c)
			var workers := _peasants()
			var allowed := sim.economy.construction.can_dismantle(player, b)
			if b != BuildingStore.NO_ID and not allowed:
				# The last capital: say why and keep waiting for another building.
				take_apart_fail = sim.economy.construction.is_last_capital(b)
				economy_changed.emit()
				return
			if allowed and not workers.is_empty():
				_order(
					SimCommand.on_building(sim.tick, player, SimCommand.Kind.DISMANTLE, workers, b)
				)
	if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
		if not (mb.shift_pressed and mb.button_index == MOUSE_BUTTON_LEFT):
			stop_taking_apart()


# --- magic ---------------------------------------------------------------------------------


## Selected units that cast the spell.
func casters_of(spell: SpellDef) -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in selection.ids:
		if spell.casters.has(sim.entities.type_ids[id - 1]):
			out.append(id)
	return out


## Spells the selected units cast, by id.
func spells() -> Array[SpellDef]:
	var out: Array[SpellDef] = []
	for spell in sim.magic.spells:
		if spell.tags.has(&"passive"):
			continue
		if not casters_of(spell).is_empty():
			out.append(spell)
	return out


## The spell button: cast one aimed at its caster now, or wait for the point of another.
func start_casting(spell: SpellDef) -> void:
	var ids := casters_of(spell)
	if ids.is_empty():
		return
	if placing != null:
		_stop_placing()
	taking_apart = false
	if spell.tags.has(&"target_self"):
		_order(SimCommand.cast(sim.tick, player, ids, spell.id, 0, 0))
		return
	casting = spell
	economy_changed.emit()


func stop_casting() -> void:
	casting = null
	economy_changed.emit()


func _casting_click(mb: InputEventMouseButton) -> void:
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		var at := Iso.screen_to_fixed(_to_world(mb.position))
		var ids := casters_of(casting)
		if not ids.is_empty():
			_order(SimCommand.cast(sim.tick, player, ids, casting.id, at.x, at.y))
	if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
		stop_casting()


## Selected units that can gather and build.
func peasants() -> PackedInt32Array:
	return _peasants()


## Selected units that build: peasants, and the Crown's priests (shrines only).
func builders() -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in selection.ids:
		var def := sim.economy.unit_defs[id - 1]
		if def != null and (def.has_class(&"peasant") or def.tags.has(&"builds_shrine")):
			out.append(id)
	return out


## Selects the next idle worker and centres the camera on it (`all`: selects every idle worker
## and centres on them). False if there is none.
func select_idle_worker(all := false) -> bool:
	if sim == null:
		return false
	var idle := IdleWorkers.of(sim, player)
	if idle.is_empty():
		return false
	if casting != null:
		stop_casting()
	if taking_apart:
		stop_taking_apart()
	if placing != null:
		_stop_placing()
	if all:
		selection.set_ids(idle)
	else:
		_last_idle = IdleWorkers.next_after(idle, _last_idle)
		selection.set_ids(PackedInt32Array([_last_idle]))
	_select_building(Vector2(-1, -1))
	_look_at(Vector2(-1, -1))
	if camera != null:
		var sum := Vector2.ZERO
		for id in selection.ids:
			sum += Iso.fixed_to_screen(sim.entities.pos_x[id - 1], sim.entities.pos_y[id - 1])
		camera.look_at_point(sum / selection.ids.size())
	return true


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


## The visible enemy unit under the screen point, else the nearest within PICK_RADIUS, or NO_ID.
func _enemy_at(screen_point: Vector2) -> int:
	var under := _unit_under(
		screen_point,
		func(v: UnitView) -> bool: return v.player != player and v.player != 0 and v.visible
	)
	if under != EntityStore.NO_ID:
		return under
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
