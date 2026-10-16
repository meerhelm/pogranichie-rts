extends GutTest
## Rendered art (SpriteDB, tools/art): sheets load with their layout, views without art fall
## back to the placeholders.


func test_unit_sheet_loads() -> void:
	var s := SpriteDB.unit(&"gdl_peasant")
	assert_not_null(s, "the peasant has rendered art")
	assert_not_null(s.team, "with a team mask")
	assert_true(s.anims.has("walk") and s.anims.has("idle"))
	var walk: Dictionary = s.anims["walk"]
	var rows := s.color.get_height() / int(s.frame.y)
	assert_true(int(walk["row"]) + 8 <= rows, "8 directions of walk fit in the sheet")
	assert_eq(s.color.get_size(), s.team.get_size())
	assert_eq(s.color.get_size(), s.shadow.get_size())


func test_missing_art_keeps_placeholder() -> void:
	assert_null(SpriteDB.unit(&"to_knight_brother_no_such_art"))
	var v := UnitView.new()
	v.type_id = &"no_such_unit"
	add_child_autofree(v)
	assert_null(v.sprite)
	assert_false(v.is_processing(), "placeholders do not animate")


func test_walker_stands_after_still_ticks() -> void:
	var v := UnitView.new()
	v.type_id = &"gdl_spearman"
	add_child_autofree(v)
	assert_not_null(v.sprite)
	v.set_moving(true)
	assert_true(v.moving)
	for i in UnitView.STILL_TICKS - 1:
		v.set_moving(false)
	assert_true(v.moving, "a short stop keeps walking")
	v.set_moving(false)
	assert_false(v.moving)


func test_buildings_and_trees_have_views() -> void:
	for id: StringName in [&"gdl_house", &"gdl_town_center"]:
		for stage in SpriteDB.STAGES:
			var b := SpriteDB.building(id, stage)
			assert_not_null(b, "%s %s" % [id, stage])
			assert_eq(b.frame, Vector2(b.color.get_size()), "a building is one view")
	var t := SpriteDB.tree(&"nt_pine")
	assert_not_null(t)
	assert_null(t.team, "trees take no player colour")


func test_building_stage_follows_progress_and_hp() -> void:
	assert_eq(SpriteDB.building_stage(false, 0.1, 1.0), &"found")
	assert_eq(SpriteDB.building_stage(false, 0.5, 1.0), &"build_33")
	assert_eq(SpriteDB.building_stage(false, 0.9, 1.0), &"build_66")
	assert_eq(SpriteDB.building_stage(true, 1.0, 0.9), &"done")
	assert_eq(SpriteDB.building_stage(true, 1.0, 0.5), &"damaged_1")
	assert_eq(SpriteDB.building_stage(true, 1.0, 0.2), &"damaged_2")


func test_resources_have_map_art() -> void:
	for source: int in [ResourceNodes.Source.IRON, ResourceNodes.Source.SILVER]:
		for cell: int in [0, 1, 2, 77]:
			assert_not_null(SpriteDB.deposit_at(source, cell), "source %d" % source)
	assert_not_null(SpriteDB.deposit_at(ResourceNodes.Source.HUNT, 5), "a carcass")
	assert_null(SpriteDB.deposit_at(ResourceNodes.Source.WOOD, 5), "wood is the trees")


func test_terrain_tiles_repeat_every_period() -> void:
	var layer := MapView.new()
	var grid := NavGrid.new(6, 6)
	layer.build(grid)
	assert_eq(layer.get_cell_atlas_coords(Vector2i(5, 2)), Vector2i(1, 2))
	assert_eq(layer.get_cell_source_id(Vector2i(5, 2)), grid.terrain[grid.cell_at(5, 2)])
	layer.free()
