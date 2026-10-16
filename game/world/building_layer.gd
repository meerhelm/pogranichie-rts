class_name BuildingLayer
extends Node2D
## Placeholder drawing of the economy (M5): buildings as raised diamonds over their cells in
## the owner's colour (foundations see-through, filled as they rise), HP bars, map deposits,
## carcasses of hunted animals, and the ghost of a building being placed (green where it may
## stand, red where not). Redrawn every tick; everything is read from the simulation.
## Fog of war (M6): others' buildings appear once the local player has seen them and stay as
## last seen; deposits and carcasses only on explored ground.
## Tall things (buildings and deposits that block their cells) are BoxViews in `depth_layer`,
## the y-sorted unit layer, so units and buildings hide each other by depth. Flat ones (farms,
## open deposits, ghosts) stay on this ground layer under the units. Without a depth layer
## everything is drawn here.
## Fire (M9): a burning building has flickering flames on top, more as its HP falls.
## Buildings with rendered art (SpriteDB) show their sprite instead of the box, in stages:
## foundation, rising walls, finished, damaged twice as HP falls; a finished building that is
## gone leaves ruins for RUBBLE_TICKS. Palisade cells grow arms toward their neighbours in
## the line, gates turn along it, a zaseka placed along y uses its turned view (`<id>_v`).
## Flat buildings (farms, gates) draw their art on the ground layer.

const DEPOSIT_COLORS := {
	ResourceNodes.Source.IRON: Color(0.35, 0.22, 0.16),
	ResourceNodes.Source.SILVER: Color(0.82, 0.84, 0.88),
	ResourceNodes.Source.HUNT: Color(0.55, 0.2, 0.15),
}
const OK_COLOR := Color(0.3, 1.0, 0.3, 0.45)
const BAD_COLOR := Color(1.0, 0.25, 0.2, 0.45)
## Screen height of a building per cell of its smaller side.
const HEIGHT_PER_CELL := 10.0
## Ruins stay this long (60 s at 20 ticks a second).
const RUBBLE_TICKS := 1200
const FLAME_COLORS: Array[Color] = [Color(1.0, 0.55, 0.1, 0.85), Color(1.0, 0.85, 0.2, 0.75)]
## Buildings that make up lines and join their neighbours.
const LINE_BASES: Array[StringName] = [&"palisade", &"gate", &"wall"]

var sim: Simulation
## The building the local player has selected (BuildingStore id), outlined.
var selected := BuildingStore.NO_ID:
	set(value):
		selected = value
		_refresh()
## Where tall objects go as BoxViews (the UnitLayer); null draws them on this layer.
var depth_layer: Node2D
## Ghost cells (top-left, size) and whether it may stand there; size 0 means no ghost.
var ghost := Rect2i()
var ghost_ok := false
## Ghost of a palisade line: its cells, and per cell whether it may stand there.
var ghost_line: Array[Vector2i] = []
var ghost_line_ok: Array[bool] = []
## The player at this screen.
var local_player := 1
## Others' buildings the local player has seen (they stay drawn in the fog).
var _known: Dictionary[int, bool] = {}
## Tall objects in the depth layer: "b<id>" for buildings, "n<id>" for deposits.
var _boxes: Dictionary[StringName, BoxView] = {}
## Tall objects to draw here when there is no depth layer, gathered by _refresh().
var _inline: Array[Dictionary] = []
var _ghosts := Node2D.new()
## Ruins of destroyed buildings and the tick they disappear at.
var _rubble: Dictionary[BoxView, int] = {}


func _ready() -> void:
	_ghosts.z_index = 1
	_ghosts.draw.connect(_draw_ghosts)
	add_child(_ghosts)


func attach(p_sim: Simulation, clock: SimClock) -> void:
	sim = p_sim
	clock.ticked.connect(func(_t: int) -> void: _refresh())
	_refresh()


func _exit_tree() -> void:
	for box: BoxView in _boxes.values():
		if is_instance_valid(box):
			box.queue_free()
	_boxes.clear()
	for box: BoxView in _rubble.keys():
		if is_instance_valid(box):
			box.queue_free()
	_rubble.clear()


## Brings the tall objects up to date with the simulation and redraws the ground.
func _refresh() -> void:
	queue_redraw()
	_ghosts.queue_redraw()
	if sim == null:
		return
	_inline.clear()
	var live: Dictionary[StringName, bool] = {}
	var eco := sim.economy
	for n in eco.nodes.alive_ids:
		var cell := eco.nodes.cells[n - 1]
		if eco.nodes.blocks[n - 1] != 1:
			continue
		if sim.vision.state(local_player, cell) == VisionSystem.State.UNEXPLORED:
			continue
		var c: Color = DEPOSIT_COLORS.get(eco.nodes.sources[n - 1], Color.GRAY)
		var at := Vector2(cell % sim.nav.width, cell / sim.nav.width)
		var rect := Rect2(at + Vector2(0.15, 0.15), Vector2(0.7, 0.7))
		var nkey := StringName("n%d" % n)
		_tall(nkey, live, rect, c, 6.0, false, -1.0, -1.0)
		if _boxes.has(nkey):
			_boxes[nkey].set_sprite(
				SpriteDB.deposit_at(eco.nodes.sources[n - 1], cell), Color.WHITE
			)
	var b := eco.buildings
	for id in b.alive_ids:
		var s := id - 1
		if b.blocks[s] == 0:
			continue
		if not _shown(id):
			continue
		var rect := Rect2(b.cell_x[s], b.cell_y[s], b.w[s], b.h[s])
		var c := _building_color(s)
		var height := HEIGHT_PER_CELL * mini(b.w[s], b.h[s])
		if b.done[s] != 1:
			height *= _progress(s)
		var hp := float(b.hp[s]) / maxf(b.max_hp[s], 1.0)
		if hp >= 1.0 and id != selected:
			hp = -1.0
		var fire := _fire(id)
		var key := StringName("b%d" % id)
		_tall(key, live, rect, c, height, id == selected, hp, fire)
		if _boxes.has(key):
			var stage := SpriteDB.building_stage(
				b.done[s] == 1, _progress(s), float(b.hp[s]) / maxf(b.max_hp[s], 1.0)
			)
			var tint := UnitView.PLAYER_COLORS[b.owners[s] % UnitView.PLAYER_COLORS.size()]
			_boxes[key].def_id = _art_id(s)
			_boxes[key].done = b.done[s] == 1
			var back: Array[SpriteDB.Sprite] = []
			var front: Array[SpriteDB.Sprite] = []
			if b.defs[s].base_id == &"palisade":
				_arms(s, stage, back, front)
			_boxes[key].set_sprite(SpriteDB.building(_art_id(s), stage), tint, back, front)
	for key: StringName in _boxes.keys():
		if not live.has(key):
			var box := _boxes[key]
			_boxes.erase(key)
			var rubble := SpriteDB.building(box.def_id, &"rubble") if box.done else null
			if rubble == null:
				box.queue_free()
				continue
			# A finished building that is gone leaves its ruins for a while.
			box.set_sprite(rubble, box.tint)
			box.outlined = false
			box.hp = -1.0
			box.set_fire(-1.0, sim.tick)
			box.queue_redraw()
			_rubble[box] = sim.tick + RUBBLE_TICKS
	for box: BoxView in _rubble.keys():
		if sim.tick >= _rubble[box]:
			_rubble.erase(box)
			box.queue_free()


func _tall(
	key: StringName,
	live: Dictionary[StringName, bool],
	rect: Rect2,
	c: Color,
	height: float,
	outlined: bool,
	hp: float,
	fire: float
) -> void:
	if depth_layer == null:
		_inline.append(
			{rect = rect, color = c, height = height, outlined = outlined, hp = hp, fire = fire}
		)
		return
	live[key] = true
	var box: BoxView = _boxes.get(key)
	if box == null:
		box = BoxView.new()
		box.name = "Box_%s" % key
		_boxes[key] = box
		depth_layer.add_child(box)
	box.set_box(rect, c, height, outlined, hp)
	box.set_fire(fire, sim.tick)


## Whether the local player may see building `id` (others' stay as last seen).
func _shown(id: int) -> bool:
	var b := sim.economy.buildings
	if b.owners[id - 1] == local_player or _known.has(id):
		return true
	if not sim.vision.sees_building(local_player, id):
		return false
	_known[id] = true
	return true


## HP fraction of a burning building (for its flames), or -1 when it is not on fire.
func _fire(id: int) -> float:
	var b := sim.economy.buildings
	if not sim.fire.is_burning(id):
		return -1.0
	return float(b.hp[id - 1]) / maxf(b.max_hp[id - 1], 1.0)


## Catalog id of the art of building slot `s`: the turned view (`<id>_v`) of a zaseka placed
## along y or of a gate in a line running along y, when it has one.
func _art_id(s: int) -> StringName:
	var b := sim.economy.buildings
	var id := b.defs[s].id
	var turned := b.w[s] < b.h[s]
	if b.defs[s].base_id == &"gate":
		var n := _line_neighbours(s)
		turned = (n[2] or n[3]) and not (n[0] or n[1])
	if turned and SpriteDB.building(StringName("%s_v" % id)) != null:
		return StringName("%s_v" % id)
	return id


## Whether the cells east, west, south (cell y + 1) and north of slot `s` hold line pieces.
func _line_neighbours(s: int) -> Array[bool]:
	var b := sim.economy.buildings
	var out: Array[bool] = []
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var x := b.cell_x[s] + d.x
		var y := b.cell_y[s] + d.y
		var other := BuildingStore.NO_ID
		if x >= 0 and y >= 0 and x < sim.nav.width and y < sim.nav.height:
			other = b.occupant[y * sim.nav.width + x]
		out.append(other != BuildingStore.NO_ID and LINE_BASES.has(b.defs[other - 1].base_id))
	return out


## Arms of a palisade cell toward its neighbours in the line (both ways along x when alone):
## the ones toward the back of the screen go behind the post, the others in front.
func _arms(
	s: int, stage: StringName, back: Array[SpriteDB.Sprite], front: Array[SpriteDB.Sprite]
) -> void:
	var n := _line_neighbours(s)
	if not n.has(true):
		n = [true, true, false, false]
	var id := sim.economy.buildings.defs[s].id
	# East (+x) and south (+y) come toward the viewer; west and north go away.
	var arms: Array[String] = ["e", "w", "s", "n"]
	for i in 4:
		if not n[i]:
			continue
		var piece := SpriteDB.building(StringName("%s_%s" % [id, arms[i]]), stage)
		if piece == null:
			continue
		if i == 0 or i == 2:
			front.append(piece)
		else:
			back.append(piece)


func _progress(s: int) -> float:
	var b := sim.economy.buildings
	return float(b.progress[s]) / maxf(b.work[s], 1.0)


func _building_color(s: int) -> Color:
	var b := sim.economy.buildings
	var base := UnitView.PLAYER_COLORS[b.owners[s] % UnitView.PLAYER_COLORS.size()]
	var c := base.darkened(0.25)
	if b.done[s] != 1:
		c.a = 0.35 + 0.5 * _progress(s)
	if b.defs[s].base_id == &"farm":
		c = Color(0.78, 0.7, 0.35, c.a)
	return c


func _draw() -> void:
	if sim == null:
		return
	var eco := sim.economy
	for n in eco.nodes.alive_ids:
		var cell := eco.nodes.cells[n - 1]
		if eco.nodes.blocks[n - 1] == 1:
			continue
		if sim.vision.state(local_player, cell) == VisionSystem.State.UNEXPLORED:
			continue
		var c: Color = DEPOSIT_COLORS.get(eco.nodes.sources[n - 1], Color.GRAY)
		var at := Vector2(cell % sim.nav.width, cell / sim.nav.width)
		var spot := Iso.cell_to_screen(at + Vector2(0.5, 0.5))
		var art := SpriteDB.deposit_at(eco.nodes.sources[n - 1], cell)
		if art != null:
			draw_set_transform(spot)
			art.draw(self, Rect2(Vector2.ZERO, art.frame), Color.WHITE)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_circle(spot, 4.0, c)
	var b := eco.buildings
	for id in b.alive_ids:
		var s := id - 1
		if b.blocks[s] != 0 or not _shown(id):
			continue
		var rect := Rect2(b.cell_x[s], b.cell_y[s], b.w[s], b.h[s])
		var height := 2.0 * (_progress(s) if b.done[s] != 1 else 1.0)
		var art := SpriteDB.building(
			_art_id(s),
			SpriteDB.building_stage(
				b.done[s] == 1, _progress(s), float(b.hp[s]) / maxf(b.max_hp[s], 1.0)
			)
		)
		if art != null:
			var tint := UnitView.PLAYER_COLORS[b.owners[s] % UnitView.PLAYER_COLORS.size()]
			draw_set_transform(Iso.cell_to_screen(rect.get_center()))
			art.draw(self, Rect2(Vector2.ZERO, art.frame), tint)
			draw_set_transform(Vector2.ZERO)
			height = 16.0
		else:
			draw_box(self, rect, _building_color(s), height)
		if id == selected:
			draw_outline(self, rect, Color(0.4, 1.0, 0.4))
		var hp := float(b.hp[s]) / maxf(b.max_hp[s], 1.0)
		var fire := _fire(id)
		if fire >= 0.0:
			draw_flames(self, rect, height, fire, sim.tick)
		if hp >= 1.0 and id != selected:
			hp = -1.0
		_draw_hp(rect, height, hp)
	for t in _inline:
		var rect: Rect2 = t.rect
		var height: float = t.height
		draw_box(self, rect, t.color, height)
		if t.outlined:
			draw_outline(self, rect, Color(0.4, 1.0, 0.4))
		if t.fire >= 0.0:
			draw_flames(self, rect, height, t.fire, sim.tick)
		_draw_hp(rect, height, t.hp)


func _draw_hp(rect: Rect2, height: float, hp: float) -> void:
	if hp < 0.0:
		return
	var top := Iso.cell_to_screen(rect.get_center()) - Vector2(16.0, height + 10.0)
	draw_rect(Rect2(top, Vector2(32.0, 3.0)), Color(0.15, 0.05, 0.05))
	draw_rect(Rect2(top, Vector2(32.0 * hp, 3.0)), Color(0.3, 0.85, 0.3))


## Placement ghosts, over the buildings and units (but under the fog).
func _draw_ghosts() -> void:
	if ghost.size != Vector2i.ZERO:
		var col := OK_COLOR if ghost_ok else BAD_COLOR
		draw_box(_ghosts, Rect2(ghost.position, ghost.size), col, 0.0)
	for i in ghost_line.size():
		var col := OK_COLOR if ghost_line_ok[i] else BAD_COLOR
		draw_box(_ghosts, Rect2(ghost_line[i], Vector2.ONE), col, 0.0)


## Flames over the top of a burning building on `item`, a few per cell, taller as it burns
## down (`hp` 0..1); `tick` makes them flicker.
static func draw_flames(
	item: CanvasItem, cells: Rect2, height: float, hp: float, tick: int
) -> void:
	var count := int(cells.size.x * cells.size.y) + 1
	for i in count:
		var fx := fposmod(i * 0.618, 1.0)
		var fy := fposmod(i * 0.382 + 0.17, 1.0)
		var at := Iso.cell_to_screen(cells.position + cells.size * Vector2(fx, fy))
		at.y -= height
		var flicker := 0.6 + 0.4 * sin(tick * 0.7 + i * 1.3)
		var tall := (8.0 + 10.0 * (1.0 - hp)) * flicker
		var c := FLAME_COLORS[(tick / 3 + i) % FLAME_COLORS.size()]
		item.draw_colored_polygon(
			PackedVector2Array([at + Vector2(-4, 0), at + Vector2(0, -tall), at + Vector2(4, 0)]), c
		)


## A box over the cells on `item`: its top `height` pixels up, with darker sides.
static func draw_box(item: CanvasItem, cells: Rect2, c: Color, height: float) -> void:
	var p := _corners(cells)
	var up := Vector2(0.0, -height)
	if height > 0.0:
		item.draw_colored_polygon(
			PackedVector2Array([p[3], p[2], p[2] + up, p[3] + up]), c.darkened(0.3)
		)
		item.draw_colored_polygon(
			PackedVector2Array([p[2], p[1], p[1] + up, p[2] + up]), c.darkened(0.15)
		)
	item.draw_colored_polygon(PackedVector2Array([p[0] + up, p[1] + up, p[2] + up, p[3] + up]), c)


static func draw_outline(item: CanvasItem, cells: Rect2, c: Color) -> void:
	var p := _corners(cells)
	p.append(p[0])
	item.draw_polyline(p, c, 2.0)


## Screen corners of a cell rectangle: top, right, bottom, left.
static func _corners(cells: Rect2) -> PackedVector2Array:
	var a := cells.position
	var e := cells.end
	return PackedVector2Array(
		[
			Iso.cell_to_screen(a),
			Iso.cell_to_screen(Vector2(e.x, a.y)),
			Iso.cell_to_screen(e),
			Iso.cell_to_screen(Vector2(a.x, e.y)),
		]
	)
