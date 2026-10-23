extends GutTest
## M3: isometric conversion, camera limits, selection rules. No window needed.

const IDS := [3, 5, 8, 9]
const TYPES: Array[StringName] = [
	&"gdl_spearman", &"gdl_spearman", &"gdl_lit_lance", &"gdl_spearman"
]


func test_iso_round_trip_and_tilemap_agree() -> void:
	for p: Vector2 in [Vector2(0, 0), Vector2(3.5, 7.25), Vector2(119.9, 0.1)]:
		var back := Iso.screen_to_cell(Iso.cell_to_screen(p))
		assert_almost_eq(back.x, p.x, 0.0001)
		assert_almost_eq(back.y, p.y, 0.0001)
	var layer := MapView.new()
	layer.build(NavGrid.new(4, 4))
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(3, 1), Vector2i(2, 3)]:
		var centre := Iso.cell_to_screen(Vector2(cell) + Vector2(0.5, 0.5))
		assert_eq(layer.position + layer.map_to_local(cell), centre, "tile %s centre" % cell)
		assert_eq(layer.local_to_map(centre - layer.position), cell)
		assert_eq(Iso.screen_to_cell_index(centre), cell)
	layer.free()


func test_screen_to_fixed_hits_the_cell() -> void:
	var centre := Iso.cell_to_screen(Vector2(10.5, 20.5))
	assert_eq(
		Iso.screen_to_fixed(centre),
		Vector2i(Fixed.from_cells(10) + 512, Fixed.from_cells(20) + 512)
	)


func test_map_rect_holds_all_corners() -> void:
	var r := Iso.map_rect(120, 80)
	for c: Vector2 in [Vector2(0, 0), Vector2(120, 0), Vector2(0, 80), Vector2(120, 80)]:
		assert_true(r.grow(0.01).has_point(Iso.cell_to_screen(c)), str(c))


func test_camera_stays_on_the_map_and_scrolls_at_edges() -> void:
	var r := Rect2(-100, 0, 200, 100)
	assert_eq(RtsCamera.clamp_to_bounds(Vector2(500, -20), r), Vector2(100, 0))
	assert_eq(RtsCamera.clamp_to_bounds(Vector2(10, 50), r), Vector2(10, 50))
	var screen := Vector2(1920, 1080)
	assert_almost_eq(RtsCamera.edge_zone(screen), 43.2, 0.01)
	assert_eq(RtsCamera.edge_direction(Vector2(0, 500), screen), Vector2(-1, 0))
	assert_eq(RtsCamera.edge_direction(Vector2(1919, 1079), screen), Vector2(1, 1))
	assert_eq(RtsCamera.edge_direction(Vector2(900, 500), screen), Vector2.ZERO)
	var inner := RtsCamera.edge_direction(Vector2(40, 500), screen)
	assert_between(inner.x, -0.5, -RtsCamera.EDGE_SLOW, "slow at the inner side of the zone")
	assert_lt(RtsCamera.edge_direction(Vector2(10, 500), screen).x, inner.x, "faster nearer")
	assert_eq(RtsCamera.edge_direction(Vector2(-5, 500), screen), Vector2(-1, 0), "just past")
	assert_eq(RtsCamera.edge_direction(Vector2(-300, 500), screen), Vector2.ZERO, "mouse gone")
	assert_eq(
		RtsCamera.edge_direction(Vector2(500, 30), screen, true), Vector2.ZERO, "over a button"
	)
	assert_eq(RtsCamera.edge_direction(Vector2(500, 1077), screen, true), Vector2(0, 1), "far edge")
	assert_eq(
		RtsCamera.edge_direction(Vector2(500, -10), screen, true), Vector2(0, -1), "overshoot"
	)


func test_edge_zone_narrows_only_over_controls() -> void:
	var panel := PanelContainer.new()
	var button := Button.new()
	var label := Label.new()
	panel.add_child(button)
	button.add_child(label)
	assert_false(RtsCamera.over_control(null), "the map")
	assert_false(RtsCamera.over_control(panel), "a panel's background")
	assert_true(RtsCamera.over_control(button))
	assert_true(RtsCamera.over_control(label), "a label inside a button")
	panel.free()


func test_camera_zoom_is_limited() -> void:
	var cam := RtsCamera.new()
	for i in 30:
		cam.zoom_by(RtsCamera.ZOOM_STEP)
	assert_eq(cam.zoom, Vector2(RtsCamera.ZOOM_MAX, RtsCamera.ZOOM_MAX))
	for i in 30:
		cam.zoom_by(-RtsCamera.ZOOM_STEP)
	assert_eq(cam.zoom, Vector2(RtsCamera.ZOOM_MIN, RtsCamera.ZOOM_MIN))
	cam.free()


func _points() -> PackedVector2Array:
	return PackedVector2Array(
		[Vector2(10, 10), Vector2(50, 10), Vector2(100, 100), Vector2(300, 300)]
	)


func test_click_selects_one_and_shift_toggles() -> void:
	var s := Selection.new()
	var ids := PackedInt32Array(IDS)
	s.click(Vector2(12, 12), ids, _points(), false)
	assert_eq(s.ids, PackedInt32Array([3]))
	s.click(Vector2(52, 9), ids, _points(), true)
	assert_eq(s.ids, PackedInt32Array([3, 5]))
	s.click(Vector2(10, 10), ids, _points(), true)
	assert_eq(s.ids, PackedInt32Array([5]), "shift-click on a selected unit drops it")
	s.click(Vector2(200, 200), ids, _points(), false)
	assert_eq(s.ids, PackedInt32Array(), "click on empty ground clears")


func test_box_selects_inside_and_shift_adds() -> void:
	var s := Selection.new()
	var ids := PackedInt32Array(IDS)
	s.box(Rect2(120, 120, -130, -130), ids, _points(), false)
	assert_eq(s.ids, PackedInt32Array([3, 5, 8]), "a box dragged up-left works too")
	s.box(Rect2(290, 290, 20, 20), ids, _points(), true)
	assert_eq(s.ids, PackedInt32Array([3, 5, 8, 9]))
	s.box(Rect2(290, 290, 20, 20), ids, _points(), false)
	assert_eq(s.ids, PackedInt32Array([9]))


func test_double_click_selects_the_type_on_screen() -> void:
	var s := Selection.new()
	s.same_type(Vector2(50, 10), PackedInt32Array(IDS), _points(), TYPES, false)
	assert_eq(s.ids, PackedInt32Array([3, 5, 9]))


func test_groups_remember_and_forget_the_dead() -> void:
	var s := Selection.new()
	s.box(Rect2(0, 0, 60, 60), PackedInt32Array(IDS), _points(), false)
	s.assign_group(1)
	s.clear()
	var alive := func(id: int) -> bool: return id != 3
	assert_true(s.recall_group(1, alive))
	assert_eq(s.ids, PackedInt32Array([5]))
	assert_false(s.recall_group(2, alive), "an empty group")
	assert_eq(s.ids, PackedInt32Array())


func test_unit_layer_sorts_by_depth() -> void:
	var layer := UnitLayer.new()
	add_child_autofree(layer)
	assert_true(layer.y_sort_enabled, "units lower on screen are drawn in front")


func test_click_on_a_figure_picks_it_over_the_nearest_feet() -> void:
	var s := Selection.new()
	# The click is nearest to unit 3's feet, but it lands on unit 8's drawn figure.
	s.click(Vector2(10, 10), PackedInt32Array(IDS), _points(), false, 8)
	assert_eq(s.ids, PackedInt32Array([8]))
	# A hit that is not a candidate (another side's unit) is ignored.
	s.click(Vector2(10, 10), PackedInt32Array(IDS), _points(), false, 42)
	assert_eq(s.ids, PackedInt32Array([3]))


func test_the_whole_drawn_figure_picks_a_unit() -> void:
	var view := UnitView.new()
	view.type_id = &"gdl_spearman"
	add_child_autofree(view)
	var top := float(view.sprite.meta["bar_y"])
	assert_true(view.covers(Vector2(0, -2)), "feet")
	assert_true(view.covers(Vector2(0, -top / 2)), "body")
	assert_true(view.covers(Vector2(0, -top * 0.6)), "head")
	assert_false(view.covers(Vector2(40, -top / 2)), "beside the figure")
	assert_false(view.covers(Vector2(0, -top - 20)), "above the figure")
	assert_false(view.covers(Vector2(0, 20)), "below the feet")
