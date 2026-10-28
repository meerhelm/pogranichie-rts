class_name PowerPlaces
extends RefCounted
## Places of power (M7): sites the map marks (MapText `@place`), who holds each, capture, the
## shrines standing on them and the Сила they give. Part of MagicSystem; integers and ascending
## ids only.
##
## A free site (no shrine on it) goes to a side that keeps units within capture_radius of it for
## capture_ticks with nobody else's units there; anyone else coming near starts it over. The
## holder may lay its shrine on the site (BuildingPlacement asks site_free_for()). A finished
## shrine gives its owner BuildingDef.power_rate_milli Сила a second times the place's
## PowerPlaceDef.power_permille; a shrine within reach of another side's consecration
## (sp_consecration: the Order's chapel or a brother-priest) gives consecration_permille of it.
## While a shrine stands the site is its owner's; destroyed, the site can be taken again.

## A site is SITE × SITE cells, the shrine's footprint.
const SITE := 2
## Consecration is looked up every this many ticks (it changes only as buildings and priests do).
const CONSECRATION_EVERY := 10

var entities: EntityStore
var nav: NavGrid
var buildings: BuildingStore
var players: Dictionary[int, PlayerState]
var rules: MagicRulesDef
var buckets: UnitBuckets

## Per site, by index in map order.
var defs: Array[PowerPlaceDef] = []
## Top-left cell of the site.
var cells := PackedInt32Array()
## Player holding the site (0: nobody), and who is taking it and for how many ticks so far.
var holders := PackedInt32Array()
var takers := PackedInt32Array()
var progress := PackedInt32Array()
## The shrine standing on the site (BuildingStore id, 0 for none).
var shrines := PackedInt32Array()
## 1 while the shrine is within reach of another side's consecration.
var consecrated := PackedByteArray()
## Sites a mission says another side has consecrated from afar (M9: «освящены орденом»): site ->
## the building that does it; the site stays consecrated for others while it stands.
var consecrated_by: Dictionary[int, int] = {}
## Sites a mission has put out (ВКЛ 3: «место силы гаснет», «огонь уходит под землю»): site ->
## what is left of its Сила, permille. At 0 the site is gone: nobody holds or takes it, no
## shrine may stand there. MissionRuntime writes it into the state hash.
var quenched: Dictionary[int, int] = {}
## Sites a mission keeps off the map until someone finds them (ВКЛ 6: «скрытые места силы»):
## nobody sees, takes or picks them while they are here.
var hidden: Dictionary[int, bool] = {}

## Unit and building ids that consecrate, and how far (sp_consecration).
var _consecrators: Dictionary[StringName, bool] = {}
var _consecration_radius := 0
var _consecration_spell: StringName


func _init(
	p_entities: EntityStore,
	p_nav: NavGrid,
	economy: EconomySystem,
	p_rules: MagicRulesDef,
	db: CatalogDB,
	p_buckets: UnitBuckets
) -> void:
	entities = p_entities
	nav = p_nav
	buildings = economy.buildings
	players = economy.players
	rules = p_rules
	buckets = p_buckets
	if db == null:
		return
	var ids := PackedStringArray(db.spells.keys())
	ids.sort()
	for id in ids:
		var spell := db.spell(StringName(id))
		if spell.tags.has(&"consecration"):
			_consecration_spell = spell.id
			_consecration_radius = spell.radius
			for c in spell.casters:
				_consecrators[c] = true
	for i in nav.place_kinds.size():
		var def: PowerPlaceDef = db.power_places.get(nav.place_kinds[i])
		if def == null:
			push_error("map place of unknown kind %s" % nav.place_kinds[i])
			continue
		add(def, nav.place_cells[i])


func add(def: PowerPlaceDef, cell: int) -> int:
	defs.append(def)
	cells.append(cell)
	holders.append(0)
	takers.append(0)
	progress.append(0)
	shrines.append(BuildingStore.NO_ID)
	consecrated.append(0)
	return defs.size() - 1


func count() -> int:
	return defs.size()


## The site whose top-left cell is (cx, cy), or -1.
func site_at(cx: int, cy: int) -> int:
	if not nav.in_bounds(cx, cy):
		return -1
	var i := cells.find(nav.cell_at(cx, cy))
	return -1 if hidden.has(i) else i


## The site with any of its cells within `radius` cells of (cx, cy), the nearest first; -1.
func site_near(cx: int, cy: int, radius: int) -> int:
	var best := -1
	var best_d := 0
	for i in count():
		if hidden.has(i):
			continue
		var dx := cx - (cells[i] % nav.width) - SITE / 2
		var dy := cy - (cells[i] / nav.width) - SITE / 2
		var d := maxi(absi(dx), absi(dy))
		if d <= radius and (best < 0 or d < best_d):
			best = i
			best_d = d
	return best


## Whether the player may lay a shrine with its top-left cell at (cx, cy): the site is there,
## the player holds it and nothing stands on it.
func site_free_for(p: int, cx: int, cy: int) -> bool:
	var i := site_at(cx, cy)
	return i >= 0 and holders[i] == p and shrines[i] == BuildingStore.NO_ID and not is_gone(i)


## Whether a mission has put the site out for good.
func is_gone(i: int) -> bool:
	return quenched.get(i, 1000) == 0


## Centre of the site, fixed units.
func center_x(i: int) -> int:
	return Fixed.from_cells(cells[i] % nav.width + SITE / 2)


func center_y(i: int) -> int:
	return Fixed.from_cells(cells[i] / nav.width + SITE / 2)


## Сила the site's shrine gives now, thousandths of a point a second (0 without a finished one).
func rate_milli(i: int) -> int:
	var b := shrines[i]
	if not buildings.is_done(b):
		return 0
	var rate := BuildingStore.power_rate(buildings, b) * defs[i].power_permille / 1000
	if consecrated[i] == 1:
		rate = rate * rules.consecration_permille / 1000
	if quenched.has(i):
		rate = rate * quenched[i] / 1000
	return rate


func step(tick: int) -> void:
	for i in count():
		_track_shrine(i)
		if shrines[i] == BuildingStore.NO_ID and not is_gone(i) and not hidden.has(i):
			_capture(i)
	if tick % CONSECRATION_EVERY == 0:
		for i in count():
			consecrated[i] = 1 if _is_consecrated(i) else 0
	var cap := rules.power_cap * MagicSystem.POWER_UNIT
	for i in count():
		var rate := rate_milli(i)
		var state: PlayerState = players.get(holders[i])
		if rate > 0 and state != null:
			var before := state.power
			state.power = mini(cap, state.power + rate)
			state.power_gained += state.power - before


## Notices a shrine laid on the site or one that is gone; the site is its owner's.
func _track_shrine(i: int) -> void:
	if shrines[i] != BuildingStore.NO_ID and not buildings.is_alive(shrines[i]):
		shrines[i] = BuildingStore.NO_ID
		consecrated[i] = 0
	if shrines[i] == BuildingStore.NO_ID:
		var b := buildings.occupant[cells[i]]
		if b != BuildingStore.NO_ID and buildings.defs[b - 1].tags.has(&"power_place_only"):
			shrines[i] = b
			holders[i] = buildings.owners[b - 1]
			takers[i] = 0
			progress[i] = 0


## One tick of capture: a single other side near the site counts on, anyone else resets it.
func _capture(i: int) -> void:
	var r := Fixed.from_cells(rules.capture_radius)
	var side := 0
	var contested := false
	for id in buckets.near(center_x(i), center_y(i), r):
		var owner := entities.owners[id - 1]
		if owner <= 0 or entities.hp[id - 1] <= 0:
			continue
		if side == 0:
			side = owner
		elif owner != side:
			contested = true
			break
	if contested or side == 0 or side == holders[i]:
		takers[i] = 0
		progress[i] = 0
		return
	if takers[i] != side:
		takers[i] = side
		progress[i] = 0
	progress[i] += 1
	if progress[i] >= rules.capture_ticks:
		holders[i] = side
		takers[i] = 0
		progress[i] = 0


## Another side's chapel (finished) or brother-priest within the consecration radius.
func _is_consecrated(i: int) -> bool:
	var b := shrines[i]
	if _consecrators.is_empty() or not buildings.is_done(b):
		return false
	var owner := buildings.owners[b - 1]
	var far := consecrated_by.get(i, BuildingStore.NO_ID) as int
	if buildings.is_alive(far) and buildings.owners[far - 1] != owner:
		return true
	var x := center_x(i)
	var y := center_y(i)
	for o in buildings.alive_ids:
		var s := o - 1
		if buildings.owners[s] == owner or buildings.done[s] == 0:
			continue
		if not _consecrators.has(buildings.type_ids[s]):
			continue
		var r := Fixed.from_cells(_radius_for(buildings.owners[s]))
		if _dist_sq(x, y, buildings.center_x(o), buildings.center_y(o)) <= r * r:
			return true
	var reach := Fixed.from_cells(_consecration_radius + _max_bonus())
	for id in buckets.near(x, y, reach):
		var s := id - 1
		var unit_owner := entities.owners[s]
		if unit_owner == owner or unit_owner <= 0 or not _consecrators.has(entities.type_ids[s]):
			continue
		var r := Fixed.from_cells(_radius_for(unit_owner))
		if _dist_sq(x, y, entities.pos_x[s], entities.pos_y[s]) <= r * r:
			return true
	return false


## The consecration radius of a player, with its techs («<spell>.radius»).
func _radius_for(p: int) -> int:
	var state: PlayerState = players.get(p)
	var bonus := 0
	if state != null:
		bonus = state.unit_mods.get(StringName("%s.radius" % _consecration_spell), 0)
	return _consecration_radius + bonus


func _max_bonus() -> int:
	var most := 0
	for p: int in players:
		most = maxi(most, _radius_for(p) - _consecration_radius)
	return most


static func _dist_sq(ax: int, ay: int, bx: int, by: int) -> int:
	return (ax - bx) * (ax - bx) + (ay - by) * (ay - by)


func write_to(buf: StreamPeerBuffer) -> void:
	buf.put_32(count())
	for i in count():
		buf.put_32(cells[i])
		buf.put_32(holders[i])
		buf.put_32(takers[i])
		buf.put_32(progress[i])
		buf.put_32(shrines[i])
		buf.put_8(consecrated[i])
		buf.put_32(Num.of(consecrated_by.get(i, 0)))
		buf.put_8(1 if hidden.has(i) else 0)
