extends SceneTree
## Writes the ground TileSet, art/tiles/ground.tres, from the terrain art in art/tiles (made by
## tools/art/pixel_tiles.py): an atlas source per catalog terrain, named by its id, and terrain
## set 0 with every terrain, for painting maps in the editor (tools/maps/map_editor.tscn). Also
## writes the map editor's object marker tiles, tools/maps/objects.tres. Run after new terrain
## art; tests/unit/test_map_editor.gd checks the file has every terrain.
##   godot --headless -s tools/art/make_tileset.gd

const OBJECTS := "res://tools/maps/objects.tres"


func _init() -> void:
	var ids := NavGrid.sorted_terrain_ids(CatalogDB.load_all())
	var ts := MapView.build_tile_set(ids)
	var err := ResourceSaver.save(ts, MapView.TILE_SET)
	if err == OK:
		var markers: Script = load("res://tools/maps/map_editor.gd")
		err = ResourceSaver.save(markers.build_object_tiles(), OBJECTS)
	if err != OK:
		push_error("cannot write the tile sets: %s" % error_string(err))
		quit(1)
		return
	print("ground tile set: %d terrains" % ids.size())
	quit(0)
