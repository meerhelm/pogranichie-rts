class_name MapView
extends TileMapLayer
## Draws the nav grid's terrain as isometric tiles. Placeholder art: flat-coloured diamonds
## generated at start, one per catalog terrain, until the Blender tiles arrive.

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

var grid: NavGrid


func build(nav: NavGrid) -> void:
	grid = nav
	# TileMapLayer puts a diamond-down tile's centre half a tile right of Iso's; line them up.
	position = Vector2(-Iso.HALF_W, 0.0)
	tile_set = _make_tile_set(nav.terrain_ids)
	clear()
	for y in nav.height:
		for x in nav.width:
			set_cell(Vector2i(x, y), 0, Vector2i(nav.terrain[nav.cell_at(x, y)], 0))


static func _make_tile_set(ids: Array[StringName]) -> TileSet:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(Iso.TILE_W, Iso.TILE_H)
	var img := Image.create_empty(Iso.TILE_W * ids.size(), Iso.TILE_H, false, Image.FORMAT_RGBA8)
	for i in ids.size():
		var base: Color = COLORS.get(ids[i], FALLBACK_COLOR)
		_draw_diamond(img, i * Iso.TILE_W, base, ids[i])
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(img)
	source.texture_region_size = Vector2i(Iso.TILE_W, Iso.TILE_H)
	for i in ids.size():
		source.create_tile(Vector2i(i, 0))
	ts.add_source(source, 0)
	return ts


static func _draw_diamond(img: Image, left: int, base: Color, id: StringName) -> void:
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
			img.set_pixel(left + x, y, c)
