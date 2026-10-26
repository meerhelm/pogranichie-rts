class_name MagicLayer
extends Node2D
## Placeholder drawing of magic (M7): places of power as outlined sites in the holder's colour
## (grey while free) with a bar while someone takes one, «Болотный туман» as drifting clouds over
## a pale disc (mist_fx.tscn) and «Реликвия в строю» as a gold ring with rising sparks round its
## bearer (relic_fx.tscn). Only what the local player has explored or sees; everything is read
## from the simulation after every tick.

const FREE_COLOR := Color(0.85, 0.85, 0.8)
const MIST_COLOR := Color(0.78, 0.84, 0.82, 0.14)
const RELIC_COLOR := Color(1.0, 0.85, 0.3, 0.8)
## Points on a drawn circle.
const ROUND := 40
const MIST_SCENE := preload("res://game/world/mist_fx.tscn")
const RELIC_SCENE := preload("res://game/world/relic_fx.tscn")
## Screen pixels per cell of radius along the ellipse's long axis (a cell's diagonal halved).
const CELL_RADIUS := Iso.HALF_W * 1.41421356
## Mist clouds per square cell of the spell's area (at least MIST_MIN).
const MIST_DENSITY := 2.5
const MIST_MIN := 12

var sim: Simulation
var local_player := 1
## Particles of each running spell effect, by effect id.
var _fx: Dictionary[int, CPUParticles2D] = {}


func attach(p_sim: Simulation, clock: SimClock) -> void:
	sim = p_sim
	clock.advanced.connect(func(_t: int, _s: int) -> void: _on_ticked())


func _on_ticked() -> void:
	queue_redraw()
	var live: Dictionary[int, bool] = {}
	if sim.magic.enabled():
		for i in sim.magic.fx_ids.size():
			_effect_particles(i, live)
	for id: int in _fx.keys():
		if not live.has(id):
			_fx[id].queue_free()
			_fx.erase(id)


## Keeps the particles of effect `i` where it is and shown only when the player may see it.
func _effect_particles(i: int, live: Dictionary[int, bool]) -> void:
	var magic := sim.magic
	var spell := magic.spells[magic.fx_spell[i]]
	var mist := spell.tags.has(&"mist")
	if not mist and not spell.tags.has(&"relic"):
		return
	var id := magic.fx_ids[i]
	live[id] = true
	var r := float(magic.fx_radius[i])
	var p: CPUParticles2D = _fx.get(id)
	if p == null:
		p = (MIST_SCENE if mist else RELIC_SCENE).instantiate()
		p.emission_sphere_radius = r * CELL_RADIUS
		if mist:
			p.amount = maxi(MIST_MIN, roundi(PI * r * r * MIST_DENSITY))
		_fx[id] = p
		add_child(p)
	p.position = Iso.fixed_to_screen(magic.fx_x[i], magic.fx_y[i])
	if mist:
		var cell := sim.nav.cell_of(magic.fx_x[i], magic.fx_y[i])
		p.visible = sim.vision.state(local_player, cell) != VisionSystem.State.UNEXPLORED
	else:
		var bearer := magic.fx_caster[i]
		p.visible = bearer != 0 and sim.vision.sees_unit(local_player, bearer)


func _draw() -> void:
	if sim == null:
		return
	_blockade_posts()
	if not sim.magic.enabled():
		return
	var magic := sim.magic
	for i in magic.fx_ids.size():
		_effect(i)
	var places := magic.places
	var w := sim.nav.width
	for i in places.count():
		var cell := places.cells[i]
		if sim.vision.state(local_player, cell) == VisionSystem.State.UNEXPLORED:
			continue
		if places.is_gone(i) or places.hidden.has(i):
			continue
		var rect := Rect2(cell % w, cell / w, PowerPlaces.SITE, PowerPlaces.SITE)
		var c := FREE_COLOR if places.holders[i] == 0 else _color(places.holders[i])
		_outline(rect.grow(0.15), c, 3.0)
		if places.takers[i] != 0:
			var share := float(places.progress[i]) / maxf(sim.magic.rules.capture_ticks, 1.0)
			var top := Iso.cell_to_screen(rect.get_center()) - Vector2(16.0, 30.0)
			draw_rect(Rect2(top, Vector2(32.0, 4.0)), Color(0.1, 0.1, 0.1, 0.8))
			draw_rect(Rect2(top, Vector2(32.0 * share, 4.0)), _color(places.takers[i]))


## The mission's blockade posts (ВКЛ 1, phase 4): a ring in the player's colour when held,
## grey when not.
func _blockade_posts() -> void:
	var m := sim.mission
	if m == null or not m.blockade_on:
		return
	var b: Dictionary = m.def.rules["blockade"]
	var posts: Array = b["posts"]
	for i in posts.size():
		var at: Array = posts[i]
		var held := m.posts_held & (1 << i) != 0
		var c := _color(b["player"]) if held else FREE_COLOR
		var ring := _circle(Vector2(at[0], at[1]) + Vector2(0.5, 0.5), float(b["radius"]))
		ring.append(ring[0])
		draw_polyline(ring, c, 3.0 if held else 2.0)


func _effect(i: int) -> void:
	var magic := sim.magic
	var spell := magic.spells[magic.fx_spell[i]]
	var centre := Vector2(magic.fx_x[i], magic.fx_y[i]) / Fixed.ONE
	var r := float(magic.fx_radius[i])
	if spell.tags.has(&"mist"):
		var cell := sim.nav.cell_of(magic.fx_x[i], magic.fx_y[i])
		if sim.vision.state(local_player, cell) != VisionSystem.State.UNEXPLORED:
			draw_colored_polygon(_circle(centre, r), MIST_COLOR)
	elif spell.tags.has(&"relic"):
		var bearer := magic.fx_caster[i]
		if bearer != 0 and sim.vision.sees_unit(local_player, bearer):
			var ring := _circle(centre, r)
			ring.append(ring[0])
			draw_polyline(ring, RELIC_COLOR, 2.0)


func _color(player: int) -> Color:
	return UnitView.PLAYER_COLORS[player % UnitView.PLAYER_COLORS.size()]


## Screen points of a circle of `r` cells round a point in cells (an ellipse on screen).
static func _circle(centre: Vector2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in ROUND:
		var a := TAU * k / ROUND
		out.append(Iso.cell_to_screen(centre + Vector2(cos(a), sin(a)) * r))
	return out


func _outline(cells: Rect2, c: Color, width: float) -> void:
	var a := cells.position
	var e := cells.end
	var p := PackedVector2Array(
		[
			Iso.cell_to_screen(a),
			Iso.cell_to_screen(Vector2(e.x, a.y)),
			Iso.cell_to_screen(e),
			Iso.cell_to_screen(Vector2(a.x, e.y)),
			Iso.cell_to_screen(a),
		]
	)
	draw_polyline(p, c, width)
