class_name WearLayer
extends TileMapLayer
## Trodden ground: bare earth around buildings and along paths from them to their side's town
## centre, so a settlement looks lived in. Drawn over the terrain, under the ground details.
## Only for buildings the local player knows (BuildingLayer.is_known), so it gives nothing
## away. Pure drawing: the simulation does not know about it. Tiles: art/tiles/wear_1..3.png
## (tools/art/pixel_tiles.py), three levels of cover; without them it draws nothing.

const TILES := "res://art/tiles/wear_%d.png"
const LEVELS := 3
## Terrain where ground gets trodden.
const GROUND: Array[StringName] = [&"t_grass", &"t_hill", &"t_sand", &"t_forest", &"t_ash"]
## Buildings that tread no ground: lines and gates.
const NO_WEAR: Array[StringName] = [&"palisade", &"wall", &"zaseka", &"gate"]
## Buildings paths run to.
const HUBS: Array[StringName] = [&"town_center", &"castle"]
## Buildings without a path of their own (they stand on the line or in the field).
const NO_PATH: Array[StringName] = [&"tower", &"watchtower", &"farm"]
## Ticks between checks of which buildings are known.
const CHECK_TICKS := 20

var grid: NavGrid
var buildings: BuildingLayer
## Grows each time the drawn wear changes (DecalLayer redraws then).
var changes := 0
## Wear level per cell as drawn (0 none .. LEVELS).
var _drawn := PackedByteArray()
var _key := -1
var _checked_tick := -CHECK_TICKS
var _ok := false


func build(nav: NavGrid, layer: BuildingLayer) -> void:
	grid = nav
	buildings = layer
	position = Vector2(-Iso.HALF_W, 0.0)
	texture_filter = TEXTURE_FILTER_NEAREST
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(Iso.TILE_W, Iso.TILE_H)
	for level in range(1, LEVELS + 1):
		var path := TILES % level
		if not ResourceLoader.exists(path):
			return
		var source := TileSetAtlasSource.new()
		source.texture = load(path)
		source.texture_region_size = Vector2i(source.texture.get_size()) / MapView.PERIOD
		for v in MapView.PERIOD * MapView.PERIOD:
			source.create_tile(Vector2i(v % MapView.PERIOD, v / MapView.PERIOD))
		ts.add_source(source, level - 1)
	tile_set = ts
	var tint := ShaderMaterial.new()
	tint.shader = MapView.TINT
	material = tint
	_drawn.resize(nav.cell_count())
	_drawn.fill(0)
	_ok = true


## Redraws when the known buildings or the terrain changed.
func refresh(tick: int) -> void:
	if not _ok or buildings == null or buildings.sim == null:
		return
	if tick - _checked_tick < CHECK_TICKS:
		return
	_checked_tick = tick
	var b := buildings.sim.economy.buildings
	var key := grid.version
	for id in b.alive_ids:
		if buildings.is_known(id):
			key = key * 31 + id
	if key == _key:
		return
	_key = key
	var wear := levels()
	changes += 1
	for cell in wear.size():
		if wear[cell] != _drawn[cell]:
			_drawn[cell] = wear[cell]
			var at := Vector2i(cell % grid.width, cell / grid.width)
			if wear[cell] == 0:
				erase_cell(at)
			else:
				set_cell(at, wear[cell] - 1, Vector2i(at.x % MapView.PERIOD, at.y % MapView.PERIOD))


## Wear level of every cell from the known buildings.
func levels() -> PackedByteArray:
	var wear := PackedByteArray()
	wear.resize(grid.cell_count())
	var b := buildings.sim.economy.buildings
	var hubs: Array[Vector2i] = []
	var hub_owner: Array[int] = []
	for id in b.alive_ids:
		var s := id - 1
		if buildings.is_known(id) and _kind(b, s) in HUBS:
			hubs.append(Vector2i(b.cell_x[s] + b.w[s] / 2, b.cell_y[s] + b.h[s] / 2))
			hub_owner.append(b.owners[s])
	for id in b.alive_ids:
		var s := id - 1
		var base := _kind(b, s)
		if not buildings.is_known(id) or base in NO_WEAR:
			continue
		var x0 := b.cell_x[s]
		var y0 := b.cell_y[s]
		for y in range(y0 - 2, y0 + b.h[s] + 2):
			for x in range(x0 - 2, x0 + b.w[s] + 2):
				var ring := maxi(
					maxi(x0 - x, x - (x0 + b.w[s] - 1)), maxi(y0 - y, y - (y0 + b.h[s] - 1))
				)
				var level := LEVELS if ring <= 0 else (2 if ring == 1 else 1)
				if ring == 2 and _hash(x, y) % 3 == 0:
					continue
				_put(wear, x, y, level)
		if base in HUBS or base in NO_PATH:
			continue
		# A path from the building's front to its side's nearest hub.
		var from := Vector2i(x0 + b.w[s], y0 + b.h[s])
		var best := -1
		for i in hubs.size():
			if hub_owner[i] != b.owners[s]:
				continue
			if best < 0 or _dist(from, hubs[i]) < _dist(from, hubs[best]):
				best = i
		if best >= 0:
			_path(wear, from, hubs[best])
	return wear


func _path(wear: PackedByteArray, from: Vector2i, to: Vector2i) -> void:
	var at := from
	var steps := 0
	while at != to and steps < 200:
		steps += 1
		var d := to - at
		# Mostly straight, a diagonal step now and then, so the path wanders a little.
		var step := Vector2i(signi(d.x), signi(d.y))
		if step.x != 0 and step.y != 0 and _hash(at.x, at.y) % 3 != 0:
			if absi(d.x) > absi(d.y):
				step.y = 0
			else:
				step.x = 0
		at += step
		_put(wear, at.x, at.y, 2)
		if _hash(at.x + 5, at.y) % 4 == 0:
			_put(wear, at.x + 1, at.y, 1)


func _put(wear: PackedByteArray, x: int, y: int, level: int) -> void:
	if not grid.in_bounds(x, y):
		return
	var cell := grid.cell_at(x, y)
	if grid.terrain_ids[grid.terrain[cell]] not in GROUND:
		return
	wear[cell] = maxi(wear[cell], level)


## Wear level of `cell` as drawn (DecalLayer skips trodden cells).
func level_at(cell: int) -> int:
	return _drawn[cell] if cell < _drawn.size() else 0


## The building's common id (house, tower), or for one of a kind its id without the faction.
static func _kind(b: BuildingStore, s: int) -> StringName:
	var base := b.defs[s].base_id
	if base.is_empty():
		var id := String(b.type_ids[s])
		return StringName(id.substr(id.find("_") + 1))
	return base


static func _dist(a: Vector2i, c: Vector2i) -> int:
	return absi(a.x - c.x) + absi(a.y - c.y)


static func _hash(x: int, y: int) -> int:
	return absi(hash(Vector2i(x * 11 + 7, y * 17 + 3)))
