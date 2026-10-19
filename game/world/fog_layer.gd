class_name FogLayer
extends Node2D
## Fog of war of the local player over the map (M6): black where nothing was ever seen, dimmed
## where it was seen but is not in sight now. One texel per map cell (VisionGrid.shade) drawn
## through a shader; the node's transform turns cell coordinates into the isometric screen, so
## the texture lies exactly over the tiles. The texture is updated only when the grid changed.

const SHADER := preload("res://game/world/fog.gdshader")

var sim: Simulation
var player := 1

var _sprite := Sprite2D.new()
var _image: Image
var _texture: ImageTexture
var _drawn_version := -1


func _ready() -> void:
	# Cell (x, y) -> screen ((x - y) * HALF_W, (x + y) * HALF_H), as in Iso.cell_to_screen.
	transform = Transform2D(
		Vector2(Iso.HALF_W, Iso.HALF_H), Vector2(-Iso.HALF_W, Iso.HALF_H), Vector2.ZERO
	)
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	_sprite.material = mat
	add_child(_sprite)


func attach(p_sim: Simulation, clock: SimClock, p_player: int) -> void:
	sim = p_sim
	player = p_player
	visible = sim.vision.enabled()
	var w := sim.nav.width
	var h := sim.nav.height
	_image = Image.create_empty(w, h, false, Image.FORMAT_L8)
	_texture = ImageTexture.create_from_image(_image)
	_sprite.texture = _texture
	clock.advanced.connect(func(_t: int, _s: int) -> void: refresh())
	refresh()


## Copies the player's grid into the texture if it changed since the last call.
func refresh() -> void:
	if sim == null or not visible:
		return
	var g: VisionGrid = sim.vision.grids.get(player)
	if g == null:
		return
	if g.version == _drawn_version:
		return
	_drawn_version = g.version
	_image.set_data(g.width, g.height, false, Image.FORMAT_L8, g.shade)
	_texture.update(_image)
