@tool
extends Node2D
## Paints a map in the Godot editor (map_editor.tscn) and writes it back to its terrain.txt, the
## format the simulation reads (MapText). Open the scene, type the map id in the inspector and
## press «Загрузить карту»: the Ground layer gets the map's terrain from art/tiles/ground.tres,
## the Objects layer its ore, silver and salt cells, Places a marker per place of power. Paint
## Ground with the terrain brush (TileMap panel, Terrains tab, terrain set 0) or with tiles,
## put objects with the Objects layer's tiles, drag the markers (a new one needs metadata
## «kind», a PowerPlaceDef id). «Сохранить в terrain.txt» writes the map, keeping the comment
## lines at its top; «Очистить» empties the layers, so the scene stays small in git (save it
## empty). Only cells inside the loaded map's size are written; an empty one becomes grass.

const OBJECT_TILES := "res://tools/maps/objects.tres"
## Object markers by OBJECT_IDS index (the atlas column in OBJECT_TILES).
const OBJECT_COLORS: Array[Color] = [
	Color.TRANSPARENT,
	Color(0.45, 0.25, 0.15),
	Color(0.85, 0.87, 0.92),
	Color(0.95, 0.95, 1.0),
]

## The map to load and save: an id under maps/ or a res:// or user:// path to a terrain.txt.
@export var map_id := "map_proto_samogitia"
## Size of the loaded map in cells.
@export var map_size := Vector2i.ZERO
## Comment lines from the top of the loaded file, written back on save.
@export var header := PackedStringArray()
## Whether the file lists its places of power before the terrain rows (kept on save).
@export var places_first := false

@export_tool_button("Загрузить карту", "Load") var load_button := load_map
@export_tool_button("Сохранить в terrain.txt", "Save") var save_button := save_map
@export_tool_button("Очистить", "Clear") var clear_button := clear_map


## Fills the layers from the map's terrain.txt. False (with an error) when it cannot be read.
func load_map() -> bool:
	var path := _path()
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("cannot read map %s" % path)
		return false
	var grid := MapText.parse(text, CatalogDB.load_all())
	if grid == null:
		return false
	clear_map()
	header = PackedStringArray()
	places_first = false
	for line in text.split("\n"):
		if line.begins_with(";"):
			header.append(line)
		elif line.begins_with("@place "):
			places_first = true
		elif not line.strip_edges().is_empty():
			break
	map_size = Vector2i(grid.width, grid.height)
	var ground := _ground()
	ground.tile_set = MapView.ground_tile_set(grid.terrain_ids)
	var sources := MapView.source_ids(ground.tile_set, grid.terrain_ids)
	var objects := _objects()
	for y in grid.height:
		for x in grid.width:
			var cell := grid.cell_at(x, y)
			var at := Vector2i(x, y)
			var variant := Vector2i(x % MapView.PERIOD, y % MapView.PERIOD)
			ground.set_cell(at, sources[grid.terrain[cell]], variant)
			if grid.objects[cell] != NavGrid.NO_OBJECT:
				objects.set_cell(at, 0, Vector2i(grid.objects[cell], 0))
	var places := _places()
	for i in grid.place_kinds.size():
		var cell := grid.place_cells[i]
		var marker := Marker2D.new()
		marker.name = "%s_%d" % [grid.place_kinds[i], i + 1]
		marker.set_meta(&"kind", String(grid.place_kinds[i]))
		var site := Vector2(cell % grid.width, cell / grid.width) + Vector2.ONE * _half_site()
		marker.position = Iso.cell_to_screen(site)
		marker.gizmo_extents = 24.0
		places.add_child(marker)
		marker.owner = self
	print("map %s loaded: %d x %d" % [map_id, grid.width, grid.height])
	return true


## The map as terrain.txt text, or "" (with an error) when it is not a valid map.
func map_text() -> String:
	if map_size == Vector2i.ZERO:
		push_error("load a map first")
		return ""
	var ground := _ground()
	var char_of: Dictionary[String, String] = {}
	for ch: String in MapText.LEGEND:
		char_of[String(MapText.LEGEND[ch])] = ch
	var object_char: Dictionary[int, String] = {}
	for ch: String in MapText.OBJECTS:
		var obj: Array = MapText.OBJECTS[ch]
		object_char[NavGrid.OBJECT_IDS.find(obj[1])] = ch
	var lines := header.duplicate()
	var places := _place_lines()
	if places_first:
		lines.append_array(places)
	var objects := _objects()
	for y in map_size.y:
		var row := ""
		for x in map_size.x:
			var at := Vector2i(x, y)
			var ch := "."
			var source := ground.get_cell_source_id(at)
			if source >= 0:
				ch = char_of.get(ground.tile_set.get_source(source).resource_name, ".")
			if objects.get_cell_source_id(at) >= 0:
				ch = object_char.get(objects.get_cell_atlas_coords(at).x, ch)
			row += ch
		lines.append(row)
	if not places_first:
		lines.append_array(places)
	var text := "\n".join(lines) + "\n"
	if MapText.parse(text, CatalogDB.load_all()) == null:
		return ""
	return text


## `@place` lines of the markers, in their order under Places.
func _place_lines() -> PackedStringArray:
	var out := PackedStringArray()
	for marker: Node in _places().get_children():
		if not marker is Node2D:
			continue
		var cell := Iso.screen_to_cell((marker as Node2D).position) - Vector2.ONE * _half_site()
		var kind := String(marker.get_meta(&"kind", String(marker.name).get_slice("_", 0)))
		out.append("@place %s %d %d" % [kind, roundi(cell.x), roundi(cell.y)])
	return out


## Writes the map to `out` (default: the loaded map's terrain.txt). False when it is not valid.
func save_map(out := "") -> bool:
	var text := map_text()
	if text.is_empty():
		return false
	var path := out if not out.is_empty() else _path()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write %s" % path)
		return false
	f.store_string(text)
	f.close()
	print("map saved to %s" % path)
	return true


func clear_map() -> void:
	_ground().clear()
	_objects().clear()
	for marker in _places().get_children():
		_places().remove_child(marker)
		marker.queue_free()
	map_size = Vector2i.ZERO
	header = PackedStringArray()
	places_first = false


## The marker tiles of the Objects layer: a coloured diamond per map object.
static func build_object_tiles() -> TileSet:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(Iso.TILE_W, Iso.TILE_H)
	var n := NavGrid.OBJECT_IDS.size()
	var img := Image.create_empty(Iso.TILE_W * n, Iso.TILE_H, false, Image.FORMAT_RGBA8)
	for i in range(1, n):
		for y in Iso.TILE_H:
			for x in Iso.TILE_W:
				var d := (
					absf(x + 0.5 - Iso.HALF_W) / Iso.HALF_W
					+ absf(y + 0.5 - Iso.HALF_H) / Iso.HALF_H
				)
				if d <= 0.6:
					var c := OBJECT_COLORS[i] if d < 0.5 else Color.BLACK
					img.set_pixel(i * Iso.TILE_W + x, y, c)
	var source := TileSetAtlasSource.new()
	source.resource_name = "objects"
	source.texture = ImageTexture.create_from_image(img)
	source.texture_region_size = Vector2i(Iso.TILE_W, Iso.TILE_H)
	for i in range(1, n):
		source.create_tile(Vector2i(i, 0))
	ts.add_source(source, 0)
	return ts


func _path() -> String:
	if map_id.begins_with("res://") or map_id.begins_with("user://"):
		return map_id
	return MapText.path_for(map_id)


func _half_site() -> float:
	return PowerPlaces.SITE / 2.0


func _ground() -> TileMapLayer:
	return get_node("Ground")


func _objects() -> TileMapLayer:
	var layer: TileMapLayer = get_node("Objects")
	if layer.tile_set == null:
		layer.tile_set = load(OBJECT_TILES) if ResourceLoader.exists(OBJECT_TILES) else null
		if layer.tile_set == null:
			layer.tile_set = build_object_tiles()
	return layer


func _places() -> Node2D:
	return get_node("Places")
