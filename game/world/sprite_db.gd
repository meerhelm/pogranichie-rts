class_name SpriteDB
extends RefCounted
## Rendered sprites from art/sprites (made by tools/art: Blender scripts, see its README),
## looked up by catalog id. Each sprite comes in three passes: colour, a white team mask the
## game tints with the player colour, and the ground shadow drawn first. Sprites are rendered
## at twice the map scale (a 2 m cell is 128 px wide there, 64 px here) and drawn at half
## size, so they stay sharp when the camera zooms in. Ids without art keep the placeholders.

const ROOT := "res://art/sprites"
const SHADOW_ALPHA := 0.7
## Building stages, as tools/art/stages.py renders them.
const STAGES: Array[StringName] = [
	&"found", &"build_33", &"build_66", &"done", &"damaged_1", &"damaged_2", &"rubble"
]


## One view (a building or a tree) or a sheet of frames (a unit).
class Sprite:
	extends RefCounted
	var color: Texture2D
	var team: Texture2D
	var shadow: Texture2D
	## The frame pixel that sits on the anchor point, at render size.
	var pivot := Vector2.ZERO
	## Frame size at render size (a whole view for buildings and trees).
	var frame := Vector2.ZERO
	var scale := 0.5
	## Units: animation name -> {row, frames, fps}; 8 rows per animation, by facing.
	var anims: Dictionary = {}

	## Screen rectangle of a frame relative to the anchor.
	func dest() -> Rect2:
		return Rect2(-pivot * scale, frame * scale)

	## Source rectangle of frame `index` in row `row` of the sheet.
	func source(row: int, index: int) -> Rect2:
		return Rect2(Vector2(index * frame.x, row * frame.y), frame)

	## Draws shadow, colour and the team mask tinted by `tint` on `item` at the anchor.
	func draw(item: CanvasItem, src: Rect2, tint: Color, alpha := 1.0) -> void:
		var d := dest()
		item.draw_texture_rect_region(shadow, d, src, Color(1, 1, 1, SHADOW_ALPHA * alpha))
		item.draw_texture_rect_region(color, d, src, Color(1, 1, 1, alpha))
		if team != null:
			item.draw_texture_rect_region(team, d, src, Color(tint, alpha))


static var _cache: Dictionary[String, Sprite] = {}
static var _missing: Dictionary[String, bool] = {}


## Sprite sheet of a unit type, or null when it has no art yet.
static func unit(type_id: StringName) -> Sprite:
	return _load("units/%s/" % type_id, "units/%s/sheet.json" % type_id)


## A building's view in one of its stages (STAGES), or null.
static func building(def_id: StringName, stage: StringName = &"done") -> Sprite:
	return _load("buildings/%s_%s_" % [def_id, stage], "buildings/%s.json" % def_id)


## Stage of a building under construction (`progress` 0..1) or standing with `hp` 0..1.
static func building_stage(done: bool, progress: float, hp: float) -> StringName:
	if not done:
		if progress < 1.0 / 3.0:
			return &"found"
		return &"build_33" if progress < 2.0 / 3.0 else &"build_66"
	if hp > 0.66:
		return &"done"
	return &"damaged_1" if hp > 0.33 else &"damaged_2"


## A tree's view, or null.
static func tree(tree_id: StringName) -> Sprite:
	return _load("trees/%s_" % tree_id, "trees/%s.json" % tree_id)


static func _load(prefix: String, meta_name: String) -> Sprite:
	if _cache.has(prefix):
		return _cache[prefix]
	if _missing.has(prefix):
		return null
	var base := ROOT.path_join(prefix)
	var meta_path := ROOT.path_join(meta_name)
	if not ResourceLoader.exists(base + "color.png") or not FileAccess.file_exists(meta_path):
		_missing[prefix] = true
		return null
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
	var s := Sprite.new()
	s.color = load(base + "color.png")
	s.shadow = load(base + "shadow.png")
	if ResourceLoader.exists(base + "team.png"):
		s.team = load(base + "team.png")
	var pivot: Array = meta.get("pivot", [0, 0])
	s.pivot = Vector2(pivot[0], pivot[1])
	var size: Array = meta.get("frame", meta.get("size", [0, 0]))
	s.frame = Vector2(size[0], size[1])
	s.scale = meta.get("scale", 0.5)
	s.anims = meta.get("anims", {})
	_cache[prefix] = s
	return s
