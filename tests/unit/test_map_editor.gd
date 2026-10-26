extends GutTest
## The ground TileSet file and the map editor scene (tools/maps/map_editor.tscn): a map loaded
## into the editor and saved again is the same map.

const SCENE := "res://tools/maps/map_editor.tscn"


func test_ground_tile_set_has_every_terrain_in_its_terrain_set() -> void:
	var ts: TileSet = load(MapView.TILE_SET)
	var ids := NavGrid.sorted_terrain_ids(CatalogDB.load_all())
	var sources := MapView.source_ids(ts, ids)
	assert_eq(ts.get_terrains_count(0), ids.size(), "one terrain per catalog terrain")
	for i in ids.size():
		assert_true(sources[i] >= 0, "%s has a source" % ids[i])
		if sources[i] < 0:
			continue
		var source: TileSetAtlasSource = ts.get_source(sources[i])
		var data := source.get_tile_data(Vector2i(3, 5), 0)
		assert_eq(ts.get_terrain_name(0, data.terrain), String(ids[i]), "tiles paint %s" % ids[i])


func test_a_map_survives_the_editor() -> void:
	for map_id in DirAccess.get_directories_at("res://maps"):
		var editor: Node2D = load(SCENE).instantiate()
		add_child_autofree(editor)
		editor.map_id = map_id
		assert_true(editor.load_map(), map_id)
		var original := FileAccess.get_file_as_string(MapText.path_for(map_id))
		assert_eq(editor.map_text(), original, "%s comes back unchanged" % map_id)


func test_painted_cells_and_moved_places_are_saved() -> void:
	var editor: Node2D = load(SCENE).instantiate()
	add_child_autofree(editor)
	editor.map_id = "map_proto_samogitia"
	editor.load_map()
	var ground: TileMapLayer = editor.get_node("Ground")
	var water := MapView.source_ids(ground.tile_set, [&"t_water"] as Array[StringName])[0]
	ground.set_cell(Vector2i(0, 0), water, Vector2i.ZERO)
	var objects: TileMapLayer = editor.get_node("Objects")
	objects.set_cell(Vector2i(1, 0), 0, Vector2i(NavGrid.OBJECT_IDS.find(&"o_bog_ore"), 0))
	var marker: Node2D = editor.get_node("Places").get_child(0)
	marker.position = Iso.cell_to_screen(Vector2(11, 21))
	var grid := MapText.parse(editor.map_text(), CatalogDB.load_all())
	assert_eq(grid.terrain_at(grid.cell_at(0, 0)), &"t_water", "painted water")
	assert_eq(grid.object_at(grid.cell_at(1, 0)), &"o_bog_ore", "a new ore cell")
	assert_eq(grid.terrain_at(grid.cell_at(1, 0)), &"t_bog", "ore lies in a bog")
	assert_eq(grid.place_cells[0], grid.cell_at(10, 20), "the place moved with its marker")
	editor.clear_map()
	assert_eq(ground.get_used_cells().size(), 0, "cleared")
