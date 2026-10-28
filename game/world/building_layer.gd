class_name BuildingLayer
extends Node2D
## The economy on the map (M5): buildings (placeholders as raised diamonds over their cells in
## the owner's colour, foundations see-through, filled as they rise), HP bars, map deposits,
## carcasses of hunted animals, salvage heaps, and the ghost of a building being placed (green
## where it may stand, red where not). Everything is read from the simulation after each tick;
## each building and deposit is a BuildingView node (building_view.tscn) that redraws only when
## it changes.
## Fog of war (M6): others' buildings appear once the local player has seen them and stay as
## last seen; deposits and carcasses only on explored ground.
## Tall things (buildings and deposits that block their cells) are BuildingViews in
## `depth_layer`, the y-sorted unit layer, so units and buildings hide each other by depth. Flat
## ones (farms, open deposits) are BuildingViews on this ground layer under the units; salvage
## heaps and ghosts are drawn here. Without a depth layer tall things are drawn here too.
## Fire (M9): a burning building has flickering flames on top, more as its HP falls.
## Buildings with rendered art (SpriteDB) show their sprite instead of the box, in stages:
## foundation, rising walls, finished, damaged twice as HP falls; a finished building that is
## gone leaves ruins for RUBBLE_TICKS. Palisade cells grow arms toward their neighbours in
## the line (towers and gates included), gates turn along it, a zaseka placed along y uses its
## turned view (`<id>_v`). Flat buildings (farms, hives) show their art on the ground layer.

const DEPOSIT_COLORS := {
	ResourceNodes.Source.IRON: Color(0.35, 0.22, 0.16),
	ResourceNodes.Source.SILVER: Color(0.82, 0.84, 0.88),
	ResourceNodes.Source.HUNT: Color(0.55, 0.2, 0.15),
}
## Salvage heaps by resource: food sacks, logs, iron, silver.
const SALVAGE_COLORS: Array[Color] = [
	Color(0.85, 0.75, 0.5), Color(0.55, 0.38, 0.2), Color(0.4, 0.4, 0.45), Color(0.85, 0.87, 0.9)
]
const OK_COLOR := Color(0.3, 1.0, 0.3, 0.45)
const BAD_COLOR := Color(1.0, 0.25, 0.2, 0.45)
## Screen height of a building per cell of its smaller side.
const HEIGHT_PER_CELL := 10.0
## Ruins stay this long (60 s at 20 ticks a second).
const RUBBLE_TICKS := 1200
const FLAME_COLORS: Array[Color] = [Color(1.0, 0.55, 0.1, 0.85), Color(1.0, 0.85, 0.2, 0.75)]
## Buildings that make up lines and join their neighbours: palisades and walls reach out to
## gates and towers next to them, whoever's they are.
const LINE_BASES: Array[StringName] = [&"palisade", &"gate", &"wall", &"tower"]
const VIEW_SCENE := preload("res://game/world/building_view.tscn")

var sim: Simulation
## The building the local player has selected (BuildingStore id), outlined.
var selected := BuildingStore.NO_ID:
	set(value):
		selected = value
		_refresh()
## Another side's building the local player looks at, outlined in amber, and the cells of a
## ground thing looked at (a deposit, carcass, forest cell, place of power); size 0 for none.
var looked := BuildingStore.NO_ID:
	set(value):
		looked = value
		_refresh()
var look_cells := Rect2i()
## Where tall objects go as BuildingViews (the UnitLayer); null draws them on this layer.
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
## Views of buildings ("b<id>") and deposits ("n<id>"), tall ones in the depth layer, flat
## ones in _ground.
var _boxes: Dictionary[StringName, BuildingView] = {}
## Tall objects to draw here when there is no depth layer, gathered by _refresh().
var _inline: Array[Dictionary] = []
var _ground := Node2D.new()
var _ghosts := Node2D.new()
## Ruins of destroyed buildings and the tick they disappear at.
var _rubble: Dictionary[BuildingView, int] = {}
## The salvage heaps last drawn (node id -> cell), to redraw the layer only when they change.
var _salvage: Dictionary[int, int] = {}


func _ready() -> void:
	_ground.name = "Ground"  # notr
	add_child(_ground)
	_ghosts.z_index = 1
	_ghosts.draw.connect(_draw_ghosts)
	add_child(_ghosts)


func attach(p_sim: Simulation, clock: SimClock) -> void:
	sim = p_sim
	clock.advanced.connect(func(_t: int, _s: int) -> void: _refresh())
	_refresh()


func _exit_tree() -> void:
	for box: BuildingView in _boxes.values():
		if is_instance_valid(box):
			box.queue_free()
	_boxes.clear()
	for box: BuildingView in _rubble.keys():
		if is_instance_valid(box):
			box.queue_free()
	_rubble.clear()


## Brings the views up to date with the simulation.
func _refresh() -> void:
	_ghosts.queue_redraw()
	if sim == null:
		return
	if not _inline.is_empty():
		queue_redraw()
	_inline.clear()
	var live: Dictionary[StringName, bool] = {}
	var eco := sim.economy
	var salvage: Dictionary[int, int] = {}
	for n in eco.nodes.alive_ids:
		var cell := eco.nodes.cells[n - 1]
		if sim.vision.state(local_player, cell) == VisionSystem.State.UNEXPLORED:
			continue
		var source := eco.nodes.sources[n - 1]
		if ResourceNodes.is_salvage(source):
			salvage[n] = cell
			continue
		var c: Color = DEPOSIT_COLORS.get(source, Color.GRAY)
		var at := Vector2(cell % sim.nav.width, cell / sim.nav.width)
		var nkey := StringName("n%d" % n)
		if eco.nodes.blocks[n - 1] == 1:
			var rect := Rect2(at + Vector2(0.15, 0.15), Vector2(0.7, 0.7))
			_view(nkey, live, rect, c, 6.0, false, -1.0, -1.0, false)
			if _boxes.has(nkey):
				_boxes[nkey].set_sprite(_deposit_art(source, cell), Color.WHITE)
		else:
			var spot := Rect2(at + Vector2(0.4, 0.4), Vector2(0.2, 0.2))
			_view(nkey, live, spot, c, 0.0, false, -1.0, -1.0, true)
			_boxes[nkey].set_sprite(SpriteDB.deposit_at(source, cell), Color.WHITE)
	if salvage != _salvage:
		_salvage = salvage
		queue_redraw()
	var b := eco.buildings
	for id in b.alive_ids:
		var s := id - 1
		if not _shown(id):
			continue
		var flat := b.blocks[s] == 0
		var rect := Rect2(b.cell_x[s], b.cell_y[s], b.w[s], b.h[s])
		var c := _building_color(s)
		var height := HEIGHT_PER_CELL * mini(b.w[s], b.h[s])
		if flat:
			height = 2.0
		if not _standing(s):
			height *= _progress(s)
		var hp := float(b.hp[s]) / maxf(b.max_hp[s], 1.0)
		if hp >= 1.0 and id != selected:
			hp = -1.0
		var fire := _fire(id)
		var key := StringName("b%d" % id)
		_view(key, live, rect, c, height, id == selected, hp, fire, flat)
		if _boxes.has(key):
			var stage := SpriteDB.building_stage(
				_standing(s), _progress(s), float(b.hp[s]) / maxf(b.max_hp[s], 1.0)
			)
			var tint := UnitView.PLAYER_COLORS[b.owners[s] % UnitView.PLAYER_COLORS.size()]
			_boxes[key].def_id = _art_id(s)
			# One taken apart leaves no ruins.
			_boxes[key].done = _standing(s)
			_boxes[key].gate = b.defs[s].base_id == &"gate"
			var back: Array[SpriteDB.Sprite] = []
			var front: Array[SpriteDB.Sprite] = []
			if b.defs[s].base_id == &"palisade" or b.defs[s].base_id == &"wall":
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
			box.clear_marks()
			box.set_fire(-1.0, sim.tick)
			_rubble[box] = sim.tick + RUBBLE_TICKS
	for box: BuildingView in _rubble.keys():
		if sim.tick >= _rubble[box]:
			_rubble.erase(box)
			box.queue_free()


## Updates (or makes) the view under `key`: tall ones in the depth layer, flat ones on the
## ground; tall ones are drawn on this layer instead when there is no depth layer.
func _view(
	key: StringName,
	live: Dictionary[StringName, bool],
	rect: Rect2,
	c: Color,
	height: float,
	outlined: bool,
	hp: float,
	fire: float,
	flat: bool
) -> void:
	if depth_layer == null and not flat:
		_inline.append(
			{rect = rect, color = c, height = height, outlined = outlined, hp = hp, fire = fire}
		)
		queue_redraw()
		return
	live[key] = true
	var box: BuildingView = _boxes.get(key)
	if box == null:
		box = VIEW_SCENE.instantiate()
		box.name = "Building_%s" % key
		box.flat = flat
		_boxes[key] = box
		(_ground if flat else depth_layer).add_child(box)
	box.set_box(rect, c, height, outlined, hp)
	box.set_fire(fire, sim.tick)


## Whether the local player knows building `id`: its own, or another side's seen once.
func is_known(id: int) -> bool:
	return sim.economy.buildings.is_alive(id) and _shown(id)


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


## Art of a deposit: a salt spring has its own, others the source's (SpriteDB.deposit_at).
func _deposit_art(source: int, cell: int) -> SpriteDB.Sprite:
	if sim.nav.object_at(cell) == SaltWorks.SPRING:
		var spring := SpriteDB.deposit(SaltWorks.SPRING)
		if spring != null:
			return spring
	return SpriteDB.deposit_at(source, cell)


## Catalog id of the art of building slot `s`: the turned view (`<id>_v`) of a zaseka placed
## along y or of a gate in a line running along y, when it has one.
func _art_id(s: int) -> StringName:
	var b := sim.economy.buildings
	var id := b.defs[s].id
	var turned := b.w[s] < b.h[s]
	if b.upgraded[s] == 1 and SpriteDB.building(StringName("%s_chapel" % id)) != null:
		return StringName("%s_chapel" % id)
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


## Arms of a palisade or wall cell toward its neighbours in the line (both ways along x when alone):
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


## How far up slot `s` stands: construction done, or what is left while it is taken apart.
func _progress(s: int) -> float:
	var b := sim.economy.buildings
	if b.dismantling[s] == 1:
		return float(b.dismantle_left[s]) / maxf(b.dismantle_total[s], 1.0)
	return float(b.progress[s]) / maxf(b.work[s], 1.0)


## A finished building not being taken apart (taking apart shows the build stages backwards).
func _standing(s: int) -> bool:
	var b := sim.economy.buildings
	return b.done[s] == 1 and b.dismantling[s] == 0


func _building_color(s: int) -> Color:
	var b := sim.economy.buildings
	var base := UnitView.PLAYER_COLORS[b.owners[s] % UnitView.PLAYER_COLORS.size()]
	var c := base.darkened(0.25)
	if b.done[s] != 1:
		c.a = 0.35 + 0.5 * _progress(s)
	if b.defs[s].base_id == &"farm":
		c = Color(0.78, 0.7, 0.35, c.a)
	return c


## Salvage heaps, and the tall objects when there is no depth layer.
func _draw() -> void:
	if sim == null:
		return
	for n: int in _salvage:
		var cell := _salvage[n]
		var at := Vector2(cell % sim.nav.width, cell / sim.nav.width)
		var spot := Iso.cell_to_screen(at + Vector2(0.5, 0.5))
		draw_salvage(self, spot, sim.economy.nodes.sources[n - 1], cell)
	for t in _inline:
		var rect: Rect2 = t.rect
		var height: float = t.height
		var color: Color = t.color
		var fire: float = t.fire
		var hp: float = t.hp
		draw_box(self, rect, color, height)
		if t.outlined:
			draw_outline(self, rect, Color(0.4, 1.0, 0.4))
		if fire >= 0.0:
			draw_flames(self, rect, height, fire, sim.tick)
		_draw_hp(rect, height, hp)


func _draw_hp(rect: Rect2, height: float, hp: float) -> void:
	if hp < 0.0:
		return
	var top := Iso.cell_to_screen(rect.get_center()) - Vector2(16.0, height + 10.0)
	draw_rect(Rect2(top, Vector2(32.0, 3.0)), Color(0.15, 0.05, 0.05))
	draw_rect(Rect2(top, Vector2(32.0 * hp, 3.0)), Color(0.3, 0.85, 0.3))


## Placement ghosts, over the buildings and units (but under the fog).
func _draw_ghosts() -> void:
	var b := sim.economy.buildings if sim != null else null
	if b != null and b.is_alive(looked):
		var s := looked - 1
		draw_outline(_ghosts, Rect2(b.cell_x[s], b.cell_y[s], b.w[s], b.h[s]), UnitView.LOOK_COLOR)
	if look_cells.size != Vector2i.ZERO:
		draw_outline(_ghosts, Rect2(look_cells), UnitView.LOOK_COLOR)
	if ghost.size != Vector2i.ZERO:
		var col := OK_COLOR if ghost_ok else BAD_COLOR
		draw_box(_ghosts, Rect2(ghost.position, ghost.size), col, 0.0)
	for i in ghost_line.size():
		var col := OK_COLOR if ghost_line_ok[i] else BAD_COLOR
		draw_box(_ghosts, Rect2(ghost_line[i], Vector2.ONE), col, 0.0)
	if b != null and b.is_alive(selected) and b.has_rally[selected - 1] == 1:
		var s := selected - 1
		var from := Iso.cell_to_screen(Rect2(b.cell_x[s], b.cell_y[s], b.w[s], b.h[s]).get_center())
		var to := Iso.fixed_to_screen(b.rally_x[s], b.rally_y[s])
		var tint := UnitView.PLAYER_COLORS[b.owners[s] % UnitView.PLAYER_COLORS.size()]
		draw_rally_flag(_ghosts, from, to, tint)


## The rally point of the selected building: a dashed line from the building and a flag on a
## pole where its trained units gather, in the owner's colour.
static func draw_rally_flag(item: CanvasItem, from: Vector2, to: Vector2, tint: Color) -> void:
	item.draw_dashed_line(from, to, Color(1, 1, 1, 0.55), 1.5, 6.0)
	item.draw_set_transform(to, 0.0, Vector2(1.0, 0.5))
	item.draw_circle(Vector2.ZERO, 8.0, Color(0, 0, 0, 0.35))
	item.draw_set_transform(Vector2.ZERO)
	var top := to + Vector2(0, -44)
	item.draw_line(to, top, Color(0.25, 0.16, 0.08), 3.0)
	var cloth := PackedVector2Array(
		[top + Vector2(1, 0), top + Vector2(25, 8), top + Vector2(1, 16)]
	)
	item.draw_colored_polygon(cloth, tint)
	cloth.append(cloth[0])
	item.draw_polyline(cloth, tint.darkened(0.5), 1.0)


## A heap of what a building taken apart left: logs, sacks, iron bars or silver, by source.
static func draw_salvage(item: CanvasItem, spot: Vector2, source: int, cell: int) -> void:
	var res := ResourceNodes.SOURCE_RESOURCE[source]
	var c: Color = SALVAGE_COLORS[res]
	var turn := 1.0 if cell % 2 == 0 else -1.0
	# Shifted aside by resource, so piles sharing a cell do not cover each other.
	spot += Vector2((res - 1.5) * 7.0, (res % 2) * 4.0 - 2.0)
	item.draw_set_transform(spot, 0.0, Vector2(1.0, 0.5))
	item.draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.25))
	item.draw_set_transform(Vector2.ZERO)
	for i in 3:
		var at := spot + Vector2((i - 1) * 5.0 * turn, -2.0 - (i % 2) * 4.0)
		var piece := Rect2(at - Vector2(5, 3), Vector2(10, 5))
		item.draw_rect(piece, c.darkened(0.1 * i))
		item.draw_rect(piece, c.darkened(0.5), false, 1.0)


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
