class_name DecalLayer
extends Node2D
## Small ground details scattered over the map: flowers and tussocks on meadows, sedge, reeds
## and puddles on bogs, mushrooms, ferns, stumps and dead wood in forests, stones anywhere dry.
## Pixel art from art/sprites/decals (tools/art/pixel_iso.py: one atlas + JSON). The pick for
## a cell depends only on the cell, so a map always looks the same. Details come in clumps: their
## density follows a smooth noise (a flowery glade here, bare grass there) and neighbouring cells
## mostly share a kind. Now and then a larger thing (a boulder, a log, a bush) on open ground and
## in forests. Drawn on the ground, under buildings and units; roads, water, fords and trodden
## ground (WearLayer) get none. Without the atlas it draws nothing.

const ATLAS := "res://art/sprites/decals/decals.png"
const META := "res://art/sprites/decals/decals.json"
## Share of cells (in percent) that get a detail, by kind of ground.
const DENSITY := {&"grass": 30, &"bog": 45, &"forest": 35, &"any": 8}
## Per mille of cells of open ground and forest with a larger thing.
const BIG_PER_MILLE := 14
## Cells per step of the clump noise, and per block that shares one kind of detail.
const CLUMP := 6
const KIND_BLOCK := 3
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
## Trodden ground, where no details grow (null: none).
var wear: WearLayer
var _atlas: Texture2D
## Kind of ground -> Array of [Rect2 region, Vector2 pivot].
var _by_ground: Dictionary = {}
var _version := -1
var _wear_version := -1


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
	if grid == null or _atlas == null:
		return
	var wv := wear.changes if wear != null else 0
	if grid.version == _version and wv == _wear_version:
		return
	_version = grid.version
	_wear_version = wv
	queue_redraw()


func _draw() -> void:
	if _atlas == null:
		return
	for y in grid.height:
		for x in grid.width:
			var cell := grid.cell_at(x, y)
			var tid: StringName = grid.terrain_ids[grid.terrain[cell]]
			var ground: StringName = GROUND.get(tid, &"")
			if ground.is_empty():
				continue
			if wear != null and wear.level_at(cell) >= 2:
				continue
			var h := absi(hash(Vector2i(x * 7 + 3, y * 13 + 5)))
			var item := _pick(x, y, h, ground)
			if item.is_empty():
				continue
			var region: Rect2 = item[0]
			var pivot: Vector2 = item[1]
			var off := Vector2(((h >> 3) % 50) / 100.0 + 0.25, ((h >> 15) % 50) / 100.0 + 0.25)
			var at := Iso.cell_to_screen(Vector2(x, y) + off).round()
			draw_texture_rect_region(_atlas, Rect2(at - pivot, region.size), region)


## The detail of cell x, y ([region, pivot]), or [] for none.
func _pick(x: int, y: int, h: int, ground: StringName) -> Array:
	var clump := _noise(x, y)
	if ground != &"bog" and ground != &"any" and _by_ground.has(&"big"):
		if (h >> 5) % 1000 < BIG_PER_MILLE * (0.4 + clump):
			var big: Array = _by_ground[&"big"]
			return big[(h >> 11) % big.size()]
	# Density follows the clump noise: 0 in bare stretches, up to twice the mean in clumps.
	var density: float = DENSITY[ground] * clampf(clump * 2.6 - 0.5, 0.0, 2.0)
	if h % 100 >= density:
		return []
	var pool: Array = _by_ground.get(ground, [])
	# Now and then a dry-ground detail (a stone) instead.
	if (h >> 7) % 5 == 0 and _by_ground.has(&"any"):
		pool = _by_ground[&"any"]
	if pool.is_empty():
		return []
	# Mostly the kind of the block, so flowers of one colour grow together.
	var block := absi(hash(Vector2i(floori(x / float(KIND_BLOCK)), floori(y / float(KIND_BLOCK)))))
	var k := block if (h >> 10) % 4 != 0 else (h >> 12)
	return pool[k % pool.size()]


## Smooth value noise in 0..1 over cells (a clump is some CLUMP cells across).
static func _noise(x: int, y: int) -> float:
	var fx := x / float(CLUMP)
	var fy := y / float(CLUMP)
	var ix := floori(fx)
	var iy := floori(fy)
	var tx := smoothstep(0.0, 1.0, fx - ix)
	var ty := smoothstep(0.0, 1.0, fy - iy)
	var a := lerpf(_lattice(ix, iy), _lattice(ix + 1, iy), tx)
	var b := lerpf(_lattice(ix, iy + 1), _lattice(ix + 1, iy + 1), tx)
	return lerpf(a, b, ty)


static func _lattice(x: int, y: int) -> float:
	return (absi(hash(Vector2i(x * 31 + 11, y * 47 + 29))) % 1000) / 1000.0
