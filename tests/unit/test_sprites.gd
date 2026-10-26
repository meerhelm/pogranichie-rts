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
	var v: UnitView = UnitLayer.VIEW_SCENE.instantiate()
	v.type_id = &"no_such_unit"
	add_child_autofree(v)
	assert_null(v.sprite)
	assert_false(v.is_processing(), "placeholders do not animate")


func test_walker_stands_after_still_ticks() -> void:
	var v: UnitView = UnitLayer.VIEW_SCENE.instantiate()
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
	var n := MapView.PERIOD + 2
	var grid := NavGrid.new(n, n)
	layer.build(grid)
	assert_eq(layer.get_cell_atlas_coords(Vector2i(n - 1, 2)), Vector2i(1, 2))
	var source := layer.tile_set.get_source(layer.get_cell_source_id(Vector2i(n - 1, 2)))
	assert_eq(source.resource_name, String(grid.terrain_at(grid.cell_at(n - 1, 2))))
	layer.free()


func test_saved_frames_match_the_sheets() -> void:
	# tools/art/make_frames.gd writes frames.tres; a re-rendered sheet needs them written again.
	var root := "res://art/sprites/units"
	for id in DirAccess.get_directories_at(root):
		var path := root.path_join(id).path_join("frames.tres")
		assert_true(ResourceLoader.exists(path), "%s has frames.tres" % id)
		if not ResourceLoader.exists(path):
			continue
		var s := SpriteDB.unit(StringName(id))
		var f: SpriteFrames = load(path)
		for anim: String in s.anims:
			var a: Dictionary = s.anims[anim]
			for dir in SpriteDB.FACINGS:
				var name := SpriteDB.anim_name(anim, dir)
				assert_true(f.has_animation(name), "%s %s" % [id, name])
				if not f.has_animation(name):
					continue
				assert_eq(f.get_frame_count(name), int(a["frames"]), "%s %s" % [id, name])
				assert_eq(f.get_animation_speed(name), float(a["fps"]))
				var last: AtlasTexture = f.get_frame_texture(name, int(a["frames"]) - 1)
				assert_eq(
					last.region, s.source(int(a["row"]) + dir, int(a["frames"]) - 1), "%s" % name
				)


func test_unit_view_plays_the_action_toward_its_facing() -> void:
	var v: UnitView = UnitLayer.VIEW_SCENE.instantiate()
	v.type_id = &"gdl_peasant"
	v.player = 3
	add_child_autofree(v)
	var body: AnimatedSprite2D = v.get_node("Body")
	var team: AnimatedSprite2D = v.get_node("Team")
	assert_eq(body.animation, &"idle_2", "stands facing south")
	assert_true(body.is_playing())
	assert_eq(team.self_modulate, UnitView.PLAYER_COLORS[3], "mask in the owner's colour")
	v.set_moving(true)
	v.facing = 0
	assert_eq(body.animation, &"walk_0")
	assert_eq(team.animation, &"walk_0", "passes follow the body")
	v.set_working(true)
	for i in UnitView.STILL_TICKS:
		v.set_moving(false)
	assert_eq(body.animation, &"work_0")
	v.strike()
	assert_eq(body.animation, &"attack_0")
	assert_false(body.sprite_frames.get_animation_loop(&"attack_0"), "a blow plays once")


func test_a_burning_building_shows_fire_particles() -> void:
	var v: BuildingView = BuildingLayer.VIEW_SCENE.instantiate()
	add_child_autofree(v)
	v.set_box(Rect2(2, 2, 2, 2), Color.WHITE, 20.0, false, -1.0)
	var fire: FireFx = v.get_node("Fire")
	assert_false(fire.burning(), "no fire at first")
	v.set_fire(0.8, 1)
	assert_true(fire.burning())
	var flames: CPUParticles2D = fire.get_node("Flames")
	assert_eq(flames.emission_points.size(), 9, "two points per cell and one more")
	var small := flames.scale_amount_max
	v.set_fire(0.1, 2)
	assert_gt(flames.scale_amount_max, small, "flames grow as it burns down")
	v.set_fire(-1.0, 3)
	assert_false(fire.burning(), "put out")
