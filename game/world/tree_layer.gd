class_name TreeLayer
extends Node
## Trees on forest cells (rendered art from SpriteDB): one pine or birch per cell, a little off
## centre, as Sprite2Ds in the y-sorted unit layer so units walk behind and in front of them.
## Old forest is all pine and darker. A felled cell loses its tree when the grid changes (a cell
## that turns back to forest gets one again), and trees on ground the local player has not
## explored yet stay hidden under the fog.
## Each tree gets its own slight tint, lighter or darker and warmer or cooler, picked from its
## cell, so a forest is not one flat green and looks the same every game.
## Shadow and colour are merged into one texture per tree kind at start, so a forest of
## thousands of trees is one texture per kind and batches well.

const KINDS: Array[StringName] = [&"nt_pine", &"nt_birch"]
## Extra kinds used when they have art (pixel set): a forest cell picks by weight, old forest
## from OLD_MIX. Missing ones are skipped.
const MIX: Dictionary[StringName, int] = {
	&"nt_pine": 40, &"nt_pine_2": 25, &"nt_birch": 15, &"nt_birch_2": 10, &"nt_spruce": 10
}
const OLD_MIX: Dictionary[StringName, int] = {&"nt_spruce": 50, &"nt_oak": 20, &"nt_pine": 30}
const OLD_TINT := Color(0.72, 0.8, 0.72)
## Per-tree tint: brightness up to ±TINT_LIGHT, warm (redder, less blue) or cool up to
## ±TINT_WARM.
const TINT_LIGHT := 0.12
const TINT_WARM := 0.08
## Ticks between fog checks of the trees.
const FOG_EVERY := 10

var sim: Simulation
var local_player := 1
## Where the tree sprites go (the UnitLayer).
var depth_layer: Node2D

## Tree sprite by cell index.
var _trees: Dictionary[int, Sprite2D] = {}
var _textures: Array[Texture2D] = []
var _pivots: Array[Vector2] = []
var _scales: Array[float] = []
## Kind index by name, and the weighted pick lists (kind indices) for forest and old forest.
var _kind_of: Dictionary[StringName, int] = {}
var _pick: Array[int] = []
var _pick_old: Array[int] = []
## Old forest is darkened only for the two rendered kinds; pixel kinds have their own species.
var _tint_old := true
var _version := -1


func attach(p_sim: Simulation, clock: SimClock, p_depth_layer: Node2D) -> void:
	sim = p_sim
	depth_layer = p_depth_layer
	for kind in KINDS:
		if SpriteDB.tree(kind) == null:
			return
	for kind: StringName in MIX.keys() + OLD_MIX.keys():
		var art := SpriteDB.tree(kind)
		if art == null or _kind_of.has(kind):
			continue
		_kind_of[kind] = _textures.size()
		_textures.append(_merge(art))
		_pivots.append(art.pivot)
		_scales.append(art.scale)
	_pick = _weighted(MIX)
	_pick_old = _weighted(OLD_MIX)
	if _pick_old.is_empty():
		_pick_old = [_kind_of[&"nt_pine"]]
	_tint_old = SpriteDB.tree(&"nt_spruce") == null
	_plant()
	clock.advanced.connect(_on_advanced)


func _exit_tree() -> void:
	for t: Sprite2D in _trees.values():
		if is_instance_valid(t):
			t.queue_free()
	_trees.clear()


func count() -> int:
	return _trees.size()


func _on_advanced(tick: int, steps: int) -> void:
	if sim.nav.version != _version:
		_fell()
	if tick / FOG_EVERY != (tick - steps) / FOG_EVERY:
		_fog()


static func _merge(art: SpriteDB.Sprite) -> Texture2D:
	var img := art.shadow.get_image()
	img.convert(Image.FORMAT_RGBA8)
	var a := img.get_size()
	for y in a.y:
		for x in a.x:
			var c := img.get_pixel(x, y)
			c.a *= SpriteDB.SHADOW_ALPHA
			img.set_pixel(x, y, c)
	var color := art.color.get_image()
	color.convert(Image.FORMAT_RGBA8)
	img.blend_rect(color, Rect2i(Vector2i.ZERO, a), Vector2i.ZERO)
	return ImageTexture.create_from_image(img)


func _weighted(mix: Dictionary[StringName, int]) -> Array[int]:
	var out: Array[int] = []
	for kind: StringName in mix:
		if _kind_of.has(kind):
			for i in mix[kind]:
				out.append(_kind_of[kind])
	return out


func _is_forest(cell: int) -> bool:
	var id := sim.nav.terrain_ids[sim.nav.terrain[cell]]
	return id == NavGrid.FOREST or id == &"t_old_forest"


func _plant() -> void:
	_version = sim.nav.version
	for cell in sim.nav.cell_count():
		if _is_forest(cell):
			_plant_cell(cell)
	_fog()


func _plant_cell(cell: int) -> void:
	var nav := sim.nav
	var x := cell % nav.width
	var y := cell / nav.width
	var h := absi(hash(Vector2i(x, y)))
	var old := nav.terrain_ids[nav.terrain[cell]] == &"t_old_forest"
	var kind: int
	if _textures.size() == 2:
		kind = 0 if old or h % 100 < 65 else 1
	else:
		var pick := _pick_old if old else _pick
		kind = pick[h % pick.size()]
	var t := Sprite2D.new()
	t.texture = _textures[kind]
	t.centered = false
	t.offset = -_pivots[kind]
	if _scales[kind] >= 1.0:
		# Pixel art stays 1:1 and crisp (no random scale, it would smear the pixels).
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		t.scale = Vector2.ONE * _scales[kind] * (0.9 + (h >> 8) % 20 / 100.0)
	t.modulate = tint(x, y)
	if old and _tint_old:
		t.modulate *= OLD_TINT
	var jitter := Vector2(((h >> 4) % 31) / 100.0 - 0.15, ((h >> 12) % 31) / 100.0 - 0.15)
	t.position = Iso.cell_to_screen(Vector2(x + 0.5, y + 0.5) + jitter)
	t.name = "Tree%d" % cell
	_trees[cell] = t
	depth_layer.add_child(t)


## The tint of the tree on cell x, y: the same for a cell every time (its own hash, not the
## tree's pick), around white.
static func tint(x: int, y: int) -> Color:
	var h := absi(hash(Vector3i(x, y, 7)))
	var light := 1.0 + ((h % 1001) / 500.0 - 1.0) * TINT_LIGHT
	var warm := (((h / 1001) % 1001) / 500.0 - 1.0) * TINT_WARM
	return Color(light * (1.0 + warm), light * (1.0 + warm * 0.3), light * (1.0 - warm))


func _fell() -> void:
	_version = sim.nav.version
	for cell: int in _trees.keys():
		if not _is_forest(cell):
			_trees[cell].queue_free()
			_trees.erase(cell)
	# A forest that comes back (a «Волчья тропа» closing, ВКЛ 6) gets its trees again.
	for cell in sim.nav.cell_count():
		if not _trees.has(cell) and _is_forest(cell):
			_plant_cell(cell)
	_fog()


func _fog() -> void:
	for cell: int in _trees:
		var seen := sim.vision.state(local_player, cell) != VisionSystem.State.UNEXPLORED
		_trees[cell].visible = seen
