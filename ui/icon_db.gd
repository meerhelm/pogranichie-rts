class_name IconDB
extends RefCounted
## Icons of the HUD buttons by catalog id or order name (docs/07-ui-icons.md lists them all):
## buildings and units are tiles made from the rendered sprites (tools/art/icons.py,
## tools/art/portraits.py), orders, techs, ages and spells hand-drawn SVG
## (tools/art/ui_icons.py). An id without an icon gives null and its button shows only a name.

const ROOT := "res://ui/icons"
## Where each kind of icon lives, tried in this order for a catalog id.
const KINDS: Array[String] = [
	"buildings/%s.png", "units/%s.png", "techs/%s.svg", "ages/%s.svg", "spells/%s.svg"
]
## Top bar icons of the four resources (EconomySystem order) and of Power.
const RESOURCES: Array[String] = ["food", "wood", "iron", "silver"]

static var _cache: Dictionary[String, Texture2D] = {}


## The icon of a unit, building, tech, age or spell, or null.
static func of(id: StringName) -> Texture2D:
	var key := String(id)
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	# Buildings drawn with another's art have its icon too (SpriteDB.ALIASES).
	var art := String(SpriteDB.ALIASES.get(id, id))
	for kind in KINDS:
		var path := ROOT.path_join(kind % art)
		if ResourceLoader.exists(path):
			tex = load(path)
			break
	_cache[key] = tex
	return tex


## Path of the icon of `id`, for [img] in a tooltip ("" when there is none).
static func path_of(id: StringName) -> String:
	var tex := of(id)
	return tex.resource_path if tex != null else ""


## The icon of an order button (ui/icons/orders), or null: a pixel-art PNG where there is one
## (Retro Diffusion, art_src/pixel_iso), else the hand-drawn SVG.
static func order(name: String) -> Texture2D:
	for ext: String in ["png", "svg"]:
		var path := ROOT.path_join("orders/%s.%s" % [name, ext])
		if ResourceLoader.exists(path):
			return load(path)
	return null


## Path of a top bar icon: a resource (0..3), -1 for Power, or a name such as "time".
static func small(what: Variant) -> String:
	if what is int:
		var r: int = what
		return ROOT.path_join("%s.svg" % (RESOURCES[r] if r >= 0 and r < 4 else "power"))
	return ROOT.path_join("%s.svg" % what)
