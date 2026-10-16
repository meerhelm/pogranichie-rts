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
		var b := SpriteDB.building(id)
		assert_not_null(b, String(id))
		assert_eq(b.frame, Vector2(b.color.get_size()), "a building is one view")
	var t := SpriteDB.tree(&"nt_pine")
	assert_not_null(t)
	assert_null(t.team, "trees take no player colour")
