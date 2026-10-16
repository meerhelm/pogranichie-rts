class_name BuildingPlacement
extends RefCounted
## Where buildings may stand and what they cost (M5): footprints, the placement rules (map,
## terrain, forest, other buildings, faction, age), palisade lines and the Order's brick
## discount. Part of EconomySystem; reads its players, buildings and resources.
## Places of power (M7): a shrine (tag power_place_only) goes only on the top-left cell of a site
## its player holds; nothing else may cover a site's cells.

## What may be put into a line (replacing its pieces), and what a line is made of.
const REPLACING: Array[StringName] = [&"tower", &"gate"]
const REPLACED: Array[StringName] = [&"palisade", &"wall"]

var nav: NavGrid
var rules: EconomyRulesDef
## Shared with EconomySystem.
var players: Dictionary[int, PlayerState]
var buildings: BuildingStore
var nodes: ResourceNodes
## Places of power (set by MagicSystem; null without the catalog).
var places: PowerPlaces

var _forest := -1


func _init(economy: EconomySystem) -> void:
	nav = economy.nav
	rules = economy.rules
	players = economy.players
	buildings = economy.buildings
	nodes = economy.nodes
	_forest = nav.terrain_index(EconomySystem.FOREST)


static func is_wall(def: BuildingDef) -> bool:
	return def.cost_per_tile


## Cells of a wall line from (x0, y0) to (x1, y1): straight steps, never diagonal ones.
static func wall_cells(x0: int, y0: int, x1: int, y1: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = [Vector2i(x0, y0)]
	var x := x0
	var y := y0
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x1 > x0 else -1
	var sy := 1 if y1 > y0 else -1
	var err := dx - dy
	while x != x1 or y != y1:
		# Step along the axis that keeps closest to the line; one axis at a time.
		if 2 * err > -dy and x != x1:
			err -= dy
			x += sx
		else:
			err += dx
			y += sy
		out.append(Vector2i(x, y))
	return out


func footprint(def: BuildingDef, vertical: bool) -> Vector2i:
	var size := Vector2i(def.param(&"size_w", 1), def.param(&"size_h", 1))
	return Vector2i(size.y, size.x) if vertical else size


## Whether the player may put this building with its top-left cell at (cx, cy):
## EconomySystem.Fail.OK if so.
## Map setup (`setup`) skips the faction's age and the place-of-power rule.
func can_place(
	p: int, def: BuildingDef, cx: int, cy: int, vertical: bool, setup: bool = false
) -> int:
	var state: PlayerState = players.get(p)
	var fail := _rule_fail(state, def, setup)
	if fail == EconomySystem.Fail.OK and not setup and def.tags.has(&"power_place_only"):
		if places == null or not places.site_free_for(p, cx, cy):
			fail = EconomySystem.Fail.POWER_PLACE
	if fail == EconomySystem.Fail.OK:
		var size := footprint(def, vertical)
		fail = _cells_fail(p, def, cx, cy, size)
		if fail == EconomySystem.Fail.OK and not def.tags.has(&"power_place_only"):
			if _covers_site(cx, cy, size):
				fail = EconomySystem.Fail.OCCUPIED
		if fail == EconomySystem.Fail.OK and def.tags.has(&"near_forest_only"):
			if not _forest_near(cx, cy, size):
				fail = EconomySystem.Fail.NO_FOREST_NEAR
	return fail


## Who may build it: the player's faction and age (map setup skips the age).
func _rule_fail(state: PlayerState, def: BuildingDef, setup: bool) -> int:
	if state == null:
		return EconomySystem.Fail.NO_PLAYER
	if def.faction != state.faction:
		return EconomySystem.Fail.FACTION
	if setup:
		return EconomySystem.Fail.OK
	if def.campaign_only or def.age > state.age:
		return EconomySystem.Fail.AGE
	if state.locked.has(def.id):
		return EconomySystem.Fail.LOCKED
	return EconomySystem.Fail.OK


## Where it may stand: on the map, on free cells, on open land (in the forest for in_forest).
## A tower or gate may also go on cells of the player's own palisade or wall (replaceable()).
func _cells_fail(p: int, def: BuildingDef, cx: int, cy: int, size: Vector2i) -> int:
	var in_forest := def.tags.has(&"in_forest")
	for y in range(cy, cy + size.y):
		for x in range(cx, cx + size.x):
			if not nav.in_bounds(x, y):
				return EconomySystem.Fail.OUT_OF_MAP
			var cell := nav.cell_at(x, y)
			var on := buildings.occupant[cell]
			if on != 0 and replaceable(p, def, on) and nav.blocked[cell] == 1:
				continue
			if on != 0 or nav.blocked[cell] != 0:
				return EconomySystem.Fail.OCCUPIED
			if in_forest:
				if nodes.wood[cell] <= 0:
					return EconomySystem.Fail.NOT_FOREST
			elif nav.terrain[cell] == _forest or not nav.passable(NavGrid.MoveClass.SIEGE, cell):
				return EconomySystem.Fail.TERRAIN
	return EconomySystem.Fail.OK


func _covers_site(cx: int, cy: int, size: Vector2i) -> bool:
	if places == null:
		return false
	var s := PowerPlaces.SITE
	for i in places.count():
		var x := places.cells[i] % nav.width
		var y := places.cells[i] / nav.width
		if cx < x + s and x < cx + size.x and cy < y + s and y < cy + size.y:
			return true
	return false


func _forest_near(cx: int, cy: int, size: Vector2i) -> bool:
	var r := rules.near_forest_cells
	for y in range(cy - r, cy + size.y + r):
		for x in range(cx - r, cx + size.x + r):
			if nav.in_bounds(x, y) and nodes.wood[nav.cell_at(x, y)] > 0:
				return true
	return false


func building_cost(p: int, def: BuildingDef) -> PackedInt32Array:
	var cost := PackedInt32Array([def.cost_food, def.cost_wood, def.cost_iron, def.cost_silver])
	if def.tags.has(&"brick_discount") and _has_done_tag(p, &"brickworks"):
		cost[EconomySystem.WOOD] = (
			cost[EconomySystem.WOOD] * (1000 - rules.brick_wood_discount_permille) / 1000
		)
		if def.base_id == &"wall":
			cost[EconomySystem.SILVER] = (
				cost[EconomySystem.SILVER]
				* (1000 - rules.brick_wall_silver_discount_permille)
				/ 1000
			)
	return cost


func _has_done_tag(p: int, tag: StringName) -> bool:
	for b in buildings.alive_ids:
		var s := b - 1
		if buildings.owners[s] == p and buildings.done[s] == 1 and buildings.defs[s].tags.has(tag):
			return true
	return false


## Whether a new `def` of player p takes the place of building b: a tower or gate put into
## the player's own palisade or wall line replaces the pieces under it.
func replaceable(p: int, def: BuildingDef, b: int) -> bool:
	if not REPLACING.has(def.base_id) or not buildings.is_alive(b):
		return false
	var s := b - 1
	return buildings.owners[s] == p and REPLACED.has(buildings.defs[s].base_id)


static func is_zaseka(def: BuildingDef) -> bool:
	return def.cost_source == &"forest"
