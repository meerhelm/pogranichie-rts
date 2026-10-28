class_name MapView
extends TileMapLayer
## Draws the nav grid's terrain as isometric tiles. Each terrain has a PERIOD x PERIOD atlas of
## seamless diamonds (art/tiles, made by tools/art/pixel_tiles.py); a cell uses the tile
## (x % PERIOD, y % PERIOD), so the texture runs across cells without seams. A terrain without
## art falls back to a flat-coloured diamond (COLORS), which the minimap also uses. Art tiles
## reach past their cell with a ragged rim, so a bog melts into the grass instead of a zigzag.
## A shader (ground_tint.gdshader) lays large soft patches of colour over it all.
## The TileSet is a file, art/tiles/ground.tres (tools/art/make_tileset.gd): one atlas source
## per terrain, named by its id, and a terrain set with every terrain, so maps can be painted
## with the terrain brush in the editor (tools/maps/map_editor.tscn). Terrains missing from it
## get a source at run time.

## Placeholder colours by terrain id.
const COLORS := {
	&"t_grass": Color(0.44, 0.58, 0.30),
	&"t_field": Color(0.72, 0.66, 0.36),
	&"t_forest": Color(0.18, 0.38, 0.20),
	&"t_old_forest": Color(0.08, 0.22, 0.12),
	&"t_bog": Color(0.36, 0.40, 0.28),
	&"t_quagmire": Color(0.24, 0.26, 0.18),
	&"t_ford": Color(0.38, 0.56, 0.66),
	&"t_water": Color(0.18, 0.34, 0.56),
	&"t_ice": Color(0.80, 0.88, 0.92),
	&"t_road": Color(0.62, 0.52, 0.38),
	&"t_hill": Color(0.56, 0.60, 0.36),
	&"t_sand": Color(0.82, 0.76, 0.56),
	&"t_ash": Color(0.30, 0.28, 0.26),
}
const FALLBACK_COLOR := Color(1.0, 0.0, 1.0)
const TILES := "res://art/tiles"
## Cells per repeat of a terrain texture: each terrain atlas holds PERIOD x PERIOD tiles.
const PERIOD := 8
## Large soft patches of colour over the ground (see ground_tint.gdshader).
const TINT := preload("res://game/world/ground_tint.gdshader")
const TILE_SET := "res://art/tiles/ground.tres"
## Every neighbour of an isometric cell: its tiles match their own terrain all round.
const _PEERING_BITS: Array[TileSet.CellNeighbor] = [
	TileSet.CELL_NEIGHBOR_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,
	TileSet.CELL_NEIGHBOR_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE,
	TileSet.CELL_NEIGHBOR_TOP_CORNER,
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE,
]

var grid: NavGrid
## Terrain as last drawn and the grid version it was drawn at, to redraw only what changed
## (felled trees, zaseki).
var _drawn := PackedByteArray()
var _drawn_version := -1
## TileSet source id of each terrain index of the grid.
var _sources := PackedInt32Array()


func build(nav: NavGrid) -> void:
	grid = nav
	_drawn = nav.terrain.duplicate()
	_drawn_version = nav.version
	# TileMapLayer puts a diamond-down tile's centre half a tile right of Iso's; line them up.
	position = Vector2(-Iso.HALF_W, 0.0)
	tile_set = ground_tile_set(nav.terrain_ids)
	_sources = source_ids(tile_set, nav.terrain_ids)
	# Ground tiles are pixel art: no smoothing when the camera zooms.
	texture_filter = TEXTURE_FILTER_NEAREST
	var tint := ShaderMaterial.new()
	tint.shader = TINT
	material = tint
	clear()
	for y in nav.height:
		for x in nav.width:
			_put_tile(x, y, nav.terrain[nav.cell_at(x, y)])


func _put_tile(x: int, y: int, terrain: int) -> void:
	set_cell(Vector2i(x, y), _sources[terrain], Vector2i(x % PERIOD, y % PERIOD))


## The ground TileSet from TILE_SET with a source for each of `ids`: those the file lacks are
## added to a copy of it. Without the file it is built whole.
static func ground_tile_set(ids: Array[StringName]) -> TileSet:
	if not ResourceLoader.exists(TILE_SET):
		return build_tile_set(ids)
	var ts: TileSet = load(TILE_SET)
	var missing: Array[StringName] = []
	var have := source_ids(ts, ids)
	for i in ids.size():
		if have[i] < 0:
			missing.append(ids[i])
	if missing.is_empty():
		return ts
	ts = ts.duplicate()
	for id in missing:
		_add_terrain(ts, id)
	return ts


## Source id of each terrain id in `ts` (sources are named by terrain id), -1 when absent.
static func source_ids(ts: TileSet, ids: Array[StringName]) -> PackedInt32Array:
	var by_name: Dictionary[StringName, int] = {}
	for i in ts.get_source_count():
		var id := ts.get_source_id(i)
		by_name[StringName(ts.get_source(id).resource_name)] = id
	var out := PackedInt32Array()
	for t in ids:
		var source: int = by_name.get(t, -1)
		out.append(source)
	return out


## A ground TileSet for `ids`: isometric diamonds, a terrain set with one terrain per id
## (coloured as on the minimap), and an atlas source per id whose tiles all belong to it.
static func build_tile_set(ids: Array[StringName]) -> TileSet:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(Iso.TILE_W, Iso.TILE_H)
	ts.add_terrain_set()
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	for id in ids:
		_add_terrain(ts, id)
	return ts


## Adds terrain `id` to `ts`: a terrain in set 0 and an atlas source of PERIOD x PERIOD tiles.
static func _add_terrain(ts: TileSet, id: StringName) -> void:
	var terrain := ts.get_terrains_count(0)
	ts.add_terrain(0)
	ts.set_terrain_name(0, terrain, String(id))
	var color: Color = COLORS.get(id, FALLBACK_COLOR)
	ts.set_terrain_color(0, terrain, color)
	var source := TileSetAtlasSource.new()
	source.resource_name = String(id)
	var path := TILES.path_join("%s.png" % id)
	if ResourceLoader.exists(path):
		source.texture = load(path)
	else:
		var img := Image.create_empty(
			Iso.TILE_W * PERIOD, Iso.TILE_H * PERIOD, false, Image.FORMAT_RGBA8
		)
		var base: Color = COLORS.get(id, FALLBACK_COLOR)
		for v in PERIOD * PERIOD:
			_draw_diamond(img, (v % PERIOD) * Iso.TILE_W, (v / PERIOD) * Iso.TILE_H, base, id)
		source.texture = ImageTexture.create_from_image(img)
	# Art tiles are larger than the cell: a fading rim blends them into their neighbours.
	source.texture_region_size = Vector2i(source.texture.get_size()) / PERIOD
	var source_id := ts.add_source(source)
	for v in PERIOD * PERIOD:
		var at := Vector2i(v % PERIOD, v / PERIOD)
		source.create_tile(at)
		var data := source.get_tile_data(at, 0)
		data.terrain_set = 0
		data.terrain = terrain
		for bit in _PEERING_BITS:
			data.set_terrain_peering_bit(bit, terrain)
	ts.get_source(source_id).resource_name = String(id)


static func _draw_diamond(img: Image, left: int, top: int, base: Color, id: StringName) -> void:
	for y in Iso.TILE_H:
		for x in Iso.TILE_W:
			var dx := absf(x + 0.5 - Iso.HALF_W) / Iso.HALF_W
			var dy := absf(y + 0.5 - Iso.HALF_H) / Iso.HALF_H
			if dx + dy > 1.0:
				continue
			var c := base
			# A darker rim shows the grid; trees and reeds get speckles.
			if dx + dy > 0.92:
				c = base.darkened(0.18)
			elif (id == &"t_forest" or id == &"t_old_forest") and (x * 7 + y * 13) % 11 == 0:
				c = base.darkened(0.35)
			elif (id == &"t_bog" or id == &"t_quagmire") and (x * 5 + y * 3) % 9 == 0:
				c = Color(0.25, 0.42, 0.50)
			elif id == &"t_hill" and y < Iso.HALF_H:
				c = base.lightened(0.12)
			img.set_pixel(left + x, top + y, c)


## Redraws the cells whose terrain changed since the last call (after a tick).
func refresh() -> void:
	if grid == null or grid.version == _drawn_version:
		return
	_drawn_version = grid.version
	for cell in grid.cell_count():
		var t := grid.terrain[cell]
		if t != _drawn[cell]:
			_drawn[cell] = t
			_put_tile(cell % grid.width, cell / grid.width, t)
