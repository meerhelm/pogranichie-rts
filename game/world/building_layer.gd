class_name BuildingLayer
extends Node2D
## Placeholder drawing of the economy (M5): buildings as raised diamonds over their cells in
## the owner's colour (foundations see-through, filled as they rise), HP bars, map deposits,
## carcasses of hunted animals, and the ghost of a building being placed (green where it may
## stand, red where not). Redrawn every tick; everything is read from the simulation.

const DEPOSIT_COLORS := {
	ResourceNodes.Source.IRON: Color(0.35, 0.22, 0.16),
	ResourceNodes.Source.SILVER: Color(0.82, 0.84, 0.88),
	ResourceNodes.Source.HUNT: Color(0.55, 0.2, 0.15),
}
const OK_COLOR := Color(0.3, 1.0, 0.3, 0.45)
const BAD_COLOR := Color(1.0, 0.25, 0.2, 0.45)
## Screen height of a building per cell of its smaller side.
const HEIGHT_PER_CELL := 10.0

var sim: Simulation
## The building the local player has selected (BuildingStore id), outlined.
var selected := BuildingStore.NO_ID
## Ghost cells (top-left, size) and whether it may stand there; size 0 means no ghost.
var ghost := Rect2i()
var ghost_ok := false
## Ghost of a palisade line: its cells, and per cell whether it may stand there.
var ghost_line: Array[Vector2i] = []
var ghost_line_ok: Array[bool] = []


func attach(p_sim: Simulation, clock: SimClock) -> void:
	sim = p_sim
	clock.ticked.connect(func(_t: int) -> void: queue_redraw())


func _draw() -> void:
	if sim == null:
		return
	var eco := sim.economy
	for n in eco.nodes.alive_ids:
		var cell := eco.nodes.cells[n - 1]
		var c: Color = DEPOSIT_COLORS.get(eco.nodes.sources[n - 1], Color.GRAY)
		var at := Vector2(cell % sim.nav.width, cell / sim.nav.width)
		if eco.nodes.blocks[n - 1] == 1:
			_diamond(Rect2(at + Vector2(0.15, 0.15), Vector2(0.7, 0.7)), c, 6.0)
		else:
			draw_circle(Iso.cell_to_screen(at + Vector2(0.5, 0.5)), 4.0, c)
	var b := eco.buildings
	for id in b.alive_ids:
		_building(id)
	if ghost.size != Vector2i.ZERO:
		_diamond(Rect2(ghost.position, ghost.size), OK_COLOR if ghost_ok else BAD_COLOR, 0.0)
	for i in ghost_line.size():
		var col := OK_COLOR if ghost_line_ok[i] else BAD_COLOR
		_diamond(Rect2(ghost_line[i], Vector2.ONE), col, 0.0)


func _building(id: int) -> void:
	var b := sim.economy.buildings
	var s := id - 1
	var rect := Rect2(b.cell_x[s], b.cell_y[s], b.w[s], b.h[s])
	var base := UnitView.PLAYER_COLORS[b.owners[s] % UnitView.PLAYER_COLORS.size()]
	var height := HEIGHT_PER_CELL * mini(b.w[s], b.h[s])
	if b.blocks[s] == 0:
		height = 2.0
	var done := b.done[s] == 1
	var c := base.darkened(0.25)
	if not done:
		c.a = 0.35 + 0.5 * float(b.progress[s]) / maxf(b.work[s], 1.0)
		height *= float(b.progress[s]) / maxf(b.work[s], 1.0)
	if b.defs[s].base_id == &"farm":
		c = Color(0.78, 0.7, 0.35, c.a)
	_diamond(rect, c, height)
	if id == selected:
		_outline(rect, Color(0.4, 1.0, 0.4))
	var hp := float(b.hp[s]) / maxf(b.max_hp[s], 1.0)
	if hp < 1.0 or id == selected:
		var top := Iso.cell_to_screen(rect.get_center()) - Vector2(16.0, height + 10.0)
		draw_rect(Rect2(top, Vector2(32.0, 3.0)), Color(0.15, 0.05, 0.05))
		draw_rect(Rect2(top, Vector2(32.0 * hp, 3.0)), Color(0.3, 0.85, 0.3))


## A box over the cells: its top `height` pixels up, with darker sides.
func _diamond(cells: Rect2, c: Color, height: float) -> void:
	var p := _corners(cells)
	var up := Vector2(0.0, -height)
	if height > 0.0:
		draw_colored_polygon(
			PackedVector2Array([p[3], p[2], p[2] + up, p[3] + up]), c.darkened(0.3)
		)
		draw_colored_polygon(
			PackedVector2Array([p[2], p[1], p[1] + up, p[2] + up]), c.darkened(0.15)
		)
	draw_colored_polygon(PackedVector2Array([p[0] + up, p[1] + up, p[2] + up, p[3] + up]), c)


func _outline(cells: Rect2, c: Color) -> void:
	var p := _corners(cells)
	p.append(p[0])
	draw_polyline(p, c, 2.0)


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
