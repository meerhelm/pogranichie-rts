extends GutTest
## M5 in the main scene: placing a building with its ghost and right-click gathering go through
## PlayerInput as simulation commands.

var _main: Node2D
var _input: PlayerInput
var _sim: Simulation


func before_each() -> void:
	var scene: PackedScene = load("res://game/main.tscn")
	_main = scene.instantiate()
	add_child_autofree(_main)
	_main.get_node("SimClock").paused = true
	_input = _main.get_node("UI/PlayerInput")
	_sim = _main.sim
	_sim.step()
	var peasants := PackedInt32Array()
	var points := PackedVector2Array()
	for id in _sim.entities.alive_ids:
		if _sim.entities.type_ids[id - 1] == &"gdl_peasant":
			peasants.append(id)
			points.append(Vector2.ZERO)
	_input.selection.box(Rect2(-1, -1, 2, 2), peasants, points, false)


func _screen_of_cell(c: Vector2i) -> Vector2:
	var world := Iso.cell_to_screen(Vector2(c) + Vector2(0.5, 0.5))
	return _input.get_viewport().get_canvas_transform() * world


func _click(button: MouseButton, at: Vector2, pressed: bool = true) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = at
	_input._mouse_button(ev)


func test_peasants_lay_a_house_where_the_ghost_is_green() -> void:
	assert_eq(_sim.economy.player(1).faction, &"gdl")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_B
	key.pressed = true
	_input._key(key)
	assert_not_null(_input.placing, "B starts placing")
	_input.placing = _sim.economy.db.building(&"gdl_house")
	var at := _screen_of_cell(Vector2i(20, 12))
	_input._update_ghost(at)
	assert_eq(_input.place_fail, EconomySystem.Fail.OK, "green on open grass")
	var b := _sim.economy.buildings.next_id
	_click(MOUSE_BUTTON_LEFT, at)
	_sim.step()
	assert_true(_sim.economy.buildings.is_alive(b))
	assert_eq(_sim.economy.buildings.type_ids[b - 1], &"gdl_house")
	assert_eq(
		Vector2i(_sim.economy.buildings.cell_x[b - 1], _sim.economy.buildings.cell_y[b - 1]),
		Vector2i(20, 12)
	)
	assert_null(_input.placing, "placing ends after a click without Shift")


func test_right_click_on_the_forest_sends_peasants_to_fell() -> void:
	var forest := -1
	for cell in _sim.nav.cell_count():
		if _sim.economy.nodes.wood[cell] > 0:
			forest = cell
			break
	assert_ne(forest, -1)
	var c := Vector2i(forest % _sim.nav.width, forest / _sim.nav.width)
	_click(MOUSE_BUTTON_RIGHT, _screen_of_cell(c))
	_sim.step()
	for id in _input.selection.ids:
		assert_eq(_sim.economy.job[id - 1], EconomySystem.Job.GATHER)


func test_buildings_sort_by_depth_with_units() -> void:
	var clock: SimClock = _main.get_node("SimClock")
	clock.advanced.emit(_sim.tick, 1)
	var b := _sim.economy.buildings
	var id := BuildingStore.NO_ID
	for i in b.alive_ids:
		if b.owners[i - 1] == 1 and b.blocks[i - 1] == 1:
			id = i
	var s := id - 1
	var box: BuildingView = _main.get_node("World/Units").get_node_or_null("Building_b%d" % id)
	assert_not_null(box, "a standing building lives among the y-sorted units")
	var a := Vector2(b.cell_x[s], b.cell_y[s])
	var e := a + Vector2(b.w[s], b.h[s])
	var behind := Iso.cell_to_screen(Vector2(a.x - 0.5, a.y + 1.5))
	var in_front := Iso.cell_to_screen(Vector2(a.x + 1.5, e.y + 0.5))
	assert_lt(behind.y, box.position.y, "a unit by a back face is drawn behind")
	assert_gt(in_front.y, box.position.y, "a unit by a front face is drawn in front")


func test_a_zaseka_is_taken_apart_with_a_click() -> void:
	var at := Vector2i(31, 3)
	var p := SkirmishAi.point(at)
	var b := _sim.economy.buildings.next_id
	_sim.apply_now(SimCommand.place(_sim.tick, 1, &"gdl_zaseka", p.x, p.y))
	assert_true(_sim.economy.buildings.is_alive(b), "a finished zaseka in the wood")
	_input.start_taking_apart()
	assert_true(_input.taking_apart)
	# Its felled trees stand up over the cell behind it: a click there takes it too.
	_click(MOUSE_BUTTON_LEFT, _screen_of_cell(at + Vector2i(1, -1)))
	_sim.step()
	assert_eq(_sim.economy.buildings.dismantling[b - 1], 1, "the peasants go to take it apart")
	assert_eq(_sim.economy.construction.salvage(b), PackedInt32Array([0, 0, 0, 0]), "it was free")
