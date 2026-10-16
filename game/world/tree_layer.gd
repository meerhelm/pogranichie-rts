class_name TreeLayer
extends Node
## Trees on forest cells (rendered art from SpriteDB): one pine or birch per cell, a little off
## centre, as Sprite2Ds in the y-sorted unit layer so units walk behind and in front of them.
## Old forest is all pine and darker. A felled cell loses its tree when the grid changes, and
## trees on ground the local player has not explored yet stay hidden under the fog.
## Shadow and colour are merged into one texture per tree kind at start, so a forest of
## thousands of trees is one texture per kind and batches well.

const KINDS: Array[StringName] = [&"nt_pine", &"nt_birch"]
const OLD_TINT := Color(0.72, 0.8, 0.72)
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
var _version := -1


func attach(p_sim: Simulation, clock: SimClock, p_depth_layer: Node2D) -> void:
	sim = p_sim
	depth_layer = p_depth_layer
	for kind in KINDS:
		var art := SpriteDB.tree(kind)
		if art == null:
			return
		_textures.append(_merge(art))
		_pivots.append(art.pivot)
		_scales.append(art.scale)
	_plant()
	clock.ticked.connect(_on_ticked)


func _exit_tree() -> void:
	for t: Sprite2D in _trees.values():
		if is_instance_valid(t):
			t.queue_free()
	_trees.clear()


func count() -> int:
	return _trees.size()


func _on_ticked(tick: int) -> void:
	if sim.nav.version != _version:
		_fell()
	if tick % FOG_EVERY == 0:
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


func _is_forest(cell: int) -> bool:
	var id := sim.nav.terrain_ids[sim.nav.terrain[cell]]
	return id == NavGrid.FOREST or id == &"t_old_forest"


func _plant() -> void:
	_version = sim.nav.version
	var nav := sim.nav
	for cell in nav.cell_count():
		if not _is_forest(cell):
			continue
		var x := cell % nav.width
		var y := cell / nav.width
		var h := absi(hash(Vector2i(x, y)))
		var old := nav.terrain_ids[nav.terrain[cell]] == &"t_old_forest"
		var kind := 0 if old or h % 100 < 65 else 1
		var t := Sprite2D.new()
		t.texture = _textures[kind]
		t.centered = false
		t.offset = -_pivots[kind]
		t.scale = Vector2.ONE * _scales[kind] * (0.9 + (h >> 8) % 20 / 100.0)
		if old:
			t.modulate = OLD_TINT
		var jitter := Vector2(((h >> 4) % 31) / 100.0 - 0.15, ((h >> 12) % 31) / 100.0 - 0.15)
		t.position = Iso.cell_to_screen(Vector2(x + 0.5, y + 0.5) + jitter)
		t.name = "Tree%d" % cell
		_trees[cell] = t
		depth_layer.add_child(t)
	_fog()


func _fell() -> void:
	_version = sim.nav.version
	for cell: int in _trees.keys():
		if not _is_forest(cell):
			_trees[cell].queue_free()
			_trees.erase(cell)


func _fog() -> void:
	for cell: int in _trees:
		var seen := sim.vision.state(local_player, cell) != VisionSystem.State.UNEXPLORED
		_trees[cell].visible = seen
