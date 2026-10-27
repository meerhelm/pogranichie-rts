class_name CoverFade
extends Node
## Trees and buildings standing in front of one of the local player's units and covering its
## figure turn see-through, so the player sees his men in a forest or behind a house: together
## they are 80 % clear over the unit (one tree alone FADED_ALPHA, several in a row each a bit
## clearer, so a deep forest does not stay dark); they fade back once nobody of his is behind
## them. Only the opaque pixels of the
## colour view count (not the ground shadow), checked at a few points of each figure several
## times a second. Drawing only: the simulation is not touched.

## How opaque all that covers the player's unit is together (80 % see-through).
const FADED_ALPHA := 0.2
## Alpha change per second, both ways.
const FADE_SPEED := 4.0
## Seconds between looks for what covers whom.
const CHECK_EVERY := 0.1
## Trees that can cover a unit: up to TREE_ROWS rows lower on screen (trees are about 165 px
## tall, a row 16 px) and up to TREE_SIDE half tiles to either side.
const TREE_ROWS := 11
const TREE_SIDE := 2
## A pixel this opaque hides what is behind (the merged tree shadow stays under it).
const SOLID := 0.8
## Buildings are looked up by screen squares of this size.
const BUCKET := 256.0

var units: UnitLayer
var trees: TreeLayer
var local_player := 1

## Opaque pixels by texture, shared by all trees and buildings with it.
var _masks: Dictionary[Texture2D, BitMap] = {}
## Trees and buildings faded or coming back, with the alpha they go to.
var _target: Dictionary[CanvasItem, float] = {}
var _wait := 0.0
## Cell steps from a unit to the cells whose trees may cover it.
var _front: Array[Vector2i] = []


func _init() -> void:
	for rows in TREE_ROWS + 1:
		for side in range(-TREE_SIDE, TREE_SIDE + 1):
			if (rows + side) % 2 == 0 and rows + side >= 0 and rows - side >= 0:
				_front.append(Vector2i((rows + side) / 2, (rows - side) / 2))


func _process(delta: float) -> void:
	if units == null or units.sim == null:
		return
	_wait -= delta
	if _wait <= 0.0:
		_wait = CHECK_EVERY
		refresh()
	_animate(delta)


## Finds what covers the local player's units now.
func refresh() -> void:
	var now := covering()
	for item: CanvasItem in _target.keys():
		_target[item] = now.get(item, 1.0)
	for item: CanvasItem in now:
		_target[item] = now[item]


## The trees and buildings in front of the local player's units that hide part of a figure,
## with the alpha each goes to.
func covering() -> Dictionary[CanvasItem, float]:
	var out: Dictionary[CanvasItem, float] = {}
	var buckets := _building_buckets()
	var sim := units.sim
	var nav := sim.nav
	for id: int in units.views:
		var v := units.views[id]
		if v.player != local_player or not v.visible:
			continue
		var points := v.figure_points()
		var y := v.global_position.y
		var over: Array[CanvasItem] = []
		if trees != null:
			var cell := nav.cell_of(sim.entities.pos_x[id - 1], sim.entities.pos_y[id - 1])
			var cx := cell % nav.width
			var cy := cell / nav.width
			for d: Vector2i in _front:
				if not nav.in_bounds(cx + d.x, cy + d.y):
					continue
				var t := trees.tree_at(nav.cell_at(cx + d.x, cy + d.y))
				if t == null or not t.visible or t.global_position.y <= y:
					continue
				if covers(t, points):
					over.append(t)
		for b: BuildingView in buckets.get(_bucket(v.global_position), []):
			if b.global_position.y <= y:
				continue
			for stack in b.stacks():
				if covers(stack.color_sprite(), points):
					over.append(b)
					break
		if over.is_empty():
			continue
		var alpha := 1.0 - pow(1.0 - FADED_ALPHA, 1.0 / over.size())
		for item in over:
			out[item] = minf(out.get(item, 1.0), alpha)
	return out


## Whether any of `points` (global) falls on an opaque pixel of `s` (not centred).
func covers(s: Sprite2D, points: PackedVector2Array) -> bool:
	if s.texture == null or not s.is_visible_in_tree():
		return false
	var mask := _mask(s.texture)
	var size := mask.get_size()
	for p in points:
		var px := Vector2i((s.to_local(p) - s.offset).floor())
		if px.x >= 0 and px.y >= 0 and px.x < size.x and px.y < size.y and mask.get_bitv(px):
			return true
	return false


func _mask(tex: Texture2D) -> BitMap:
	var mask: BitMap = _masks.get(tex)
	if mask == null:
		mask = BitMap.new()
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		mask.create_from_image_alpha(img, SOLID)
		_masks[tex] = mask
	return mask


## Tall buildings among the units, by the screen squares their art reaches into.
func _building_buckets() -> Dictionary[Vector2i, Array]:
	var out: Dictionary[Vector2i, Array] = {}
	for child in units.get_children():
		var b := child as BuildingView
		if b == null or not b.visible:
			continue
		for stack in b.stacks():
			var s := stack.color_sprite()
			if s.texture == null:
				continue
			var rect := Rect2(s.to_global(s.offset), s.texture.get_size() * s.global_scale)
			var from := _bucket(rect.position)
			var to := _bucket(rect.end)
			for by in range(from.y, to.y + 1):
				for bx in range(from.x, to.x + 1):
					var list: Array = out.get_or_add(Vector2i(bx, by), [])
					if not list.has(b):
						list.append(b)
	return out


static func _bucket(p: Vector2) -> Vector2i:
	return Vector2i((p / BUCKET).floor())


func _animate(delta: float) -> void:
	var step := FADE_SPEED * delta
	for item: CanvasItem in _target.keys():
		if not is_instance_valid(item):
			_target.erase(item)
			continue
		item.modulate.a = move_toward(item.modulate.a, _target[item], step)
		if item.modulate.a == 1.0 and _target[item] == 1.0:
			_target.erase(item)
