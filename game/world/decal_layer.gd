class_name DecalLayer
extends Node2D
## Small ground details scattered over the map: flowers and tussocks on meadows, sedge, reeds
## and puddles on bogs, mushrooms, ferns, stumps and dead wood in forests, stones anywhere dry.
## Pixel art from art/sprites/decals (tools/art/pixel_iso.py: one atlas + JSON). The pick for
## a cell depends only on the cell, so a map always looks the same. Drawn on the ground, under
## buildings and units; roads, water and fords get none. Without the atlas it draws nothing.

const ATLAS := "res://art/sprites/decals/decals.png"
const META := "res://art/sprites/decals/decals.json"
## Share of cells (in percent) that get a detail, by kind of ground.
const DENSITY := {&"grass": 30, &"bog": 45, &"forest": 35, &"any": 8}
## Terrain id -> kind of ground (decals of that kind, and "any" ones, grow there).
const GROUND := {
	&"t_grass": &"grass",
	&"t_hill": &"grass",
	&"t_field": &"any",
	&"t_sand": &"any",
	&"t_ash": &"any",
	&"t_bog": &"bog",
	&"t_quagmire": &"bog",
	&"t_forest": &"forest",
	&"t_old_forest": &"forest",
}

var grid: NavGrid
var _atlas: Texture2D
## Kind of ground -> Array of [Rect2 region, Vector2 pivot].
var _by_ground: Dictionary = {}
var _version := -1


func build(nav: NavGrid) -> void:
	grid = nav
	if not ResourceLoader.exists(ATLAS) or not FileAccess.file_exists(META):
		return
	_atlas = load(ATLAS)
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(META))
	for id: String in meta:
		var d: Dictionary = meta[id]
		var r: Array = d["rect"]
		var p: Array = d["pivot"]
		var g := StringName(d["ground"])
		if not _by_ground.has(g):
			_by_ground[g] = []
		_by_ground[g].append([Rect2(r[0], r[1], r[2], r[3]), Vector2(p[0], p[1])])
	texture_filter = TEXTURE_FILTER_NEAREST
	_version = nav.version
	queue_redraw()


## Redraws when the terrain changed (felled forest, zaseki).
func refresh() -> void:
	if grid == null or _atlas == null or grid.version == _version:
		return
	_version = grid.version
	queue_redraw()


func _draw() -> void:
	if _atlas == null:
		return
	for y in grid.height:
		for x in grid.width:
			var tid: StringName = grid.terrain_ids[grid.terrain[grid.cell_at(x, y)]]
			var ground: StringName = GROUND.get(tid, &"")
			if ground.is_empty():
				continue
			var h := absi(hash(Vector2i(x * 7 + 3, y * 13 + 5)))
			if h % 100 >= DENSITY[ground]:
				continue
			var pool: Array = _by_ground.get(ground, [])
			# Now and then a dry-ground detail (a stone) instead.
			if (h >> 7) % 5 == 0 and _by_ground.has(&"any"):
				pool = _by_ground[&"any"]
			if pool.is_empty():
				continue
			var item: Array = pool[(h >> 10) % pool.size()]
			var region: Rect2 = item[0]
			var pivot: Vector2 = item[1]
			var off := Vector2(((h >> 3) % 50) / 100.0 + 0.25, ((h >> 15) % 50) / 100.0 + 0.25)
			var at := Iso.cell_to_screen(Vector2(x, y) + off).round()
			draw_texture_rect_region(_atlas, Rect2(at - pivot, region.size), region)
