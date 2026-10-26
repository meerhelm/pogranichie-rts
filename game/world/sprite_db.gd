class_name SpriteDB
extends RefCounted
## Rendered sprites from art/sprites (made by tools/art: Blender scripts, see its README),
## looked up by catalog id. Each sprite comes in three passes: colour, a white team mask the
## game tints with the player colour, and the ground shadow drawn first. Sprites are rendered
## at twice the map scale (a 2 m cell is 128 px wide there, 64 px here) and drawn at half
## size, so they stay sharp when the camera zooms in. Ids without art keep the placeholders.

const ROOT := "res://art/sprites"
const SHADOW_ALPHA := 0.7
## Draws a team mask or shadow sheet over the colour frames (pass_material()).
const PASS_SHADER := preload("res://game/world/sheet_pass.gdshader")
## Directions per unit animation, one SpriteFrames animation each ("walk_2").
const FACINGS := 8
## Building stages, as tools/art/stages.py renders them.
const STAGES: Array[StringName] = [
	&"found", &"build_33", &"build_66", &"done", &"damaged_1", &"damaged_2", &"rubble"
]
## Buildings and units drawn with another's art: Muscovite village and border buildings (ВКЛ 6)
## are of the same timber as the Duchy's; the Crown's field gun, camp servant and field camp
## are the Duchy's models and its bombard the Order's; the shrine's chapel (an upgrade item,
## not a catalog id) is the upgraded shrine's art; the Muscovite service Tatar is the same
## steppe horse archer as the Duchy's (ВКЛ 8); the Crown's hired horse (Корона 5) is the
## Order's mercenary horseman of Chojnice, the same men selling their swords to either side.
const ALIASES: Dictionary[StringName, StringName] = {
	&"mo_house": &"gdl_house",
	&"mo_stable": &"gdl_stable",
	&"mo_field_camp": &"gdl_field_camp",
	&"mo_zaseka": &"gdl_zaseka",
	&"mo_zaseka_v": &"gdl_zaseka_v",
	&"pl_field_gun": &"gdl_field_gun",
	&"pl_camp_servant": &"gdl_camp_servant",
	&"pl_bombard": &"to_bombard",
	&"pl_field_camp": &"gdl_field_camp",
	&"chapel": &"pl_shrine_chapel",
	&"mo_tatar": &"nt_steppe_archer",
	&"pl_merc_horse": &"to_merc_horse",
}


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
	## The whole JSON description.
	var meta: Dictionary = {}
	## Units: pick.json beside the sheet (tools/art/pick.py, a box per frame), read on the
	## first covers().
	var pick_path := ""
	## Units: one animation per action and facing, frames cut from the colour sheet
	## (unit_frames()).
	var frames: SpriteFrames
	## Shadow and team mask materials by pass name (pass_material()).
	var materials: Dictionary[StringName, ShaderMaterial] = {}
	var _pick_boxes: Array = []
	var _pick_cols := 0

	## Screen rectangle of a frame relative to the anchor.
	func dest() -> Rect2:
		return Rect2(-pivot * scale, frame * scale)

	## Source rectangle of frame `index` in row `row` of the sheet.
	func source(row: int, index: int) -> Rect2:
		return Rect2(Vector2(index * frame.x, row * frame.y), frame)

	## Whether `local` (screen pixels from the anchor) lies in the rectangle around the figure
	## drawn in frame `index` of row `row`, grown by `slack` pixels. Without pick.json, the frame.
	func covers(row: int, index: int, local: Vector2, slack: float) -> bool:
		if not _read_pick():
			return dest().grow(slack).has_point(local)
		var k := row * _pick_cols + index
		if k < 0 or k >= _pick_boxes.size():
			return false
		var b: Array = _pick_boxes[k]
		if b.is_empty():
			return false
		var rect := Rect2(
			(Vector2(b[0], b[1]) - pivot) * scale, Vector2(b[2] - b[0], b[3] - b[1]) * scale
		)
		return rect.grow(slack).has_point(local)

	func _read_pick() -> bool:
		if _pick_cols > 0:
			return true
		if pick_path.is_empty() or not FileAccess.file_exists(pick_path):
			pick_path = ""
			return false
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(pick_path))
		_pick_boxes = data["boxes"]
		_pick_cols = int(data["cols"])
		return true

	## Draws shadow, colour and the team mask tinted by `tint` on `item` at the anchor.
	func draw(item: CanvasItem, src: Rect2, tint: Color, alpha := 1.0) -> void:
		var d := dest()
		item.draw_texture_rect_region(shadow, d, src, Color(1, 1, 1, SHADOW_ALPHA * alpha))
		item.draw_texture_rect_region(color, d, src, Color(1, 1, 1, alpha))
		if team != null:
			item.draw_texture_rect_region(team, d, src, Color(tint, alpha))


static var _cache: Dictionary[String, Sprite] = {}
static var _missing: Dictionary[String, bool] = {}
## Unit sheet folders whose textures prefetch_unit() asked for.
static var _prefetched: Dictionary[String, bool] = {}


## Name of the SpriteFrames animation of `anim` ("walk") toward `facing` (0 east, clockwise).
static func anim_name(anim: String, facing: int) -> StringName:
	return StringName("%s_%d" % [anim, facing])


## Sprite sheet of a unit type, or null when it has no art yet.
static func unit(type_id: StringName) -> Sprite:
	var id: StringName = ALIASES.get(type_id, type_id)
	var s := _load("units/%s/" % id, "units/%s/sheet.json" % id)
	if s != null and s.pick_path.is_empty() and s._pick_cols == 0:
		s.pick_path = ROOT.path_join("units/%s/pick.json" % id)
	return s


## Starts loading a unit's sheets on a worker thread, so the first such unit on the map does
## not stall the game while its big textures are read (a unit put in a training queue).
## Does nothing for an id without art (a technology) or one already loaded.
static func prefetch_unit(type_id: StringName) -> void:
	var id: StringName = ALIASES.get(type_id, type_id)
	var base := ROOT.path_join("units/%s/" % id)
	if _cache.has("units/%s/" % id) or _prefetched.has(base):
		return
	_prefetched[base] = true
	for part: String in ["color.png", "shadow.png", "team.png", "frames.tres"]:
		if ResourceLoader.exists(base + part):
			ResourceLoader.load_threaded_request(base + part)


## Animations of a unit type for AnimatedSprite2D, or null when it has no art. They come from
## frames.tres beside the sheet (tools/art/make_frames.gd writes it, the editor can open and
## tune it); without that file they are cut from the sheet as sheet.json describes.
static func unit_frames(type_id: StringName) -> SpriteFrames:
	var s := unit(type_id)
	if s == null:
		return null
	if s.frames == null:
		var id: StringName = ALIASES.get(type_id, type_id)
		var base := ROOT.path_join("units/%s/" % id)
		if ResourceLoader.exists(base + "frames.tres"):
			s.frames = _resource(base, "frames.tres") as SpriteFrames
		if s.frames == null:
			s.frames = build_frames(s)
	return s.frames


## SpriteFrames of a unit sheet: animation "<anim>_<facing>" per sheet row, at the sheet's fps;
## all loop but the attack, which plays once per blow.
static func build_frames(s: Sprite) -> SpriteFrames:
	var f := SpriteFrames.new()
	f.remove_animation(&"default")
	for anim: String in s.anims:
		var a: Dictionary = s.anims[anim]
		for dir in FACINGS:
			var name := anim_name(anim, dir)
			f.add_animation(name)
			f.set_animation_speed(name, float(a["fps"]))
			f.set_animation_loop(name, anim != "attack")  # notr
			for i in int(a["frames"]):
				var t := AtlasTexture.new()
				t.atlas = s.color
				t.region = s.source(int(a["row"]) + dir, i)
				f.add_frame(name, t)
	return f


## Material drawing a sprite's `pass` sheet (&"shadow" or &"team") over its colour frames, or
## null when the sprite has no such sheet.
static func pass_material(s: Sprite, pass_name: StringName) -> ShaderMaterial:
	var tex := s.shadow if pass_name == &"shadow" else s.team
	if tex == null:
		return null
	if not s.materials.has(pass_name):
		var m := ShaderMaterial.new()
		m.shader = PASS_SHADER
		m.set_shader_parameter(&"pass_tex", tex)
		s.materials[pass_name] = m
	return s.materials[pass_name]


## A building's view in one of its stages (STAGES), or null.
static func building(def_id: StringName, stage: StringName = &"done") -> Sprite:
	var id: StringName = ALIASES.get(def_id, def_id)
	return _load("buildings/%s_%s_" % [id, stage], "buildings/%s.json" % id)


## Stage of a building under construction (`progress` 0..1) or standing with `hp` 0..1.
static func building_stage(done: bool, progress: float, hp: float) -> StringName:
	if not done:
		if progress < 1.0 / 3.0:
			return &"found"
		return &"build_33" if progress < 2.0 / 3.0 else &"build_66"
	if hp > 0.66:
		return &"done"
	return &"damaged_1" if hp > 0.33 else &"damaged_2"


## A map resource (o_bog_ore, o_silver_mine, carcass) in variant `variant`, or null.
static func deposit(id: StringName, variant: int = 0) -> Sprite:
	return _load("deposits/%s_%d_" % [id, variant], "deposits/%s.json" % id)


## Catalog id of a ResourceNodes source's map art.
static func deposit_id(source: int) -> StringName:
	match source:
		ResourceNodes.Source.IRON:
			return &"o_bog_ore"
		ResourceNodes.Source.SILVER:
			return &"o_silver_mine"
		ResourceNodes.Source.HUNT:
			return &"carcass"
	return &""


## Art of a resource node on `cell`: its variant is picked by the cell, so neighbours differ.
static func deposit_at(source: int, cell: int) -> Sprite:
	var id := deposit_id(source)
	if id.is_empty():
		return null
	var first := deposit(id, 0)
	if first == null:
		return null
	var count := int(first.meta.get("variants", 1))
	return deposit(id, absi(hash(cell)) % count)


## A tree's view, or null.
static func tree(tree_id: StringName) -> Sprite:
	return _load("trees/%s_" % tree_id, "trees/%s.json" % tree_id)


## A map prop's view (prop_chapel, prop_campfire: mission setup props), or null.
static func prop(prop_id: StringName) -> Sprite:
	return _load("props/%s_" % prop_id, "props/%s.json" % prop_id)


## A texture of a sheet folder: taken from the worker thread if prefetch_unit() asked for it
## (waits if it is still loading), else loaded now.
static func _texture(base: String, file: String) -> Texture2D:
	return _resource(base, file) as Texture2D


static func _resource(base: String, file: String) -> Resource:
	var path := base + file
	if _prefetched.has(base):
		var status := ResourceLoader.load_threaded_get_status(path)
		if status != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			var got := ResourceLoader.load_threaded_get(path)
			if got != null:
				return got
	return load(path)


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
	s.color = _texture(base, "color.png")
	s.shadow = _texture(base, "shadow.png")
	if ResourceLoader.exists(base + "team.png"):
		s.team = _texture(base, "team.png")
	var pivot: Array = meta.get("pivot", [0, 0])
	s.pivot = Vector2(pivot[0], pivot[1])
	var size: Array = meta.get("frame", meta.get("size", [0, 0]))
	s.frame = Vector2(size[0], size[1])
	s.scale = meta.get("scale", 0.5)
	s.anims = meta.get("anims", {})
	s.meta = meta
	_cache[prefix] = s
	return s
