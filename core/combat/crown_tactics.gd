class_name CrownTactics
extends RefCounted
## The Crown's own ways of fighting (Корона tab of the catalog), part of CombatSystem. Integers
## and ascending ids only; every number from CombatRulesDef and the units' «Особое».
##
## Tabor: wagons (UnitDef param tabor_wagons) that stand still tabor_link_ticks within
## tabor_link_cells of one another form a ring once there are tabor_wagons of them (fewer with
## «Таборная наука»). Own infantry and shooters inside the ring get +tabor_armor to both armors
## (more with the tech) and lose no morale to blows in the flank.
## Pavise: a pavisier (tag pavise) that stands still pavise_ticks has set up his pavise; own
## shooters up to pavise_cover_cells behind him (not ahead of the way he faces) get
## +pavise_armor pierce armor.
## The knight's lance tires: after melee_fatigue_ticks of melee without a new charge its strikes
## lose melee_fatigue_damage, until a charge starts it over (or it rests out of combat).
## The foot servant (tag lance_escort) gets escort_morale with an own charging heavy horseman
## within escort_radius_milli; one in close order (tag steadies_neighbours, formation_neighbours
## own infantry around) halves the morale own units around him lose.
## The bombard (tag battery_only) fires only deployed at an own finished battery: standing still
## next to it deploy_ticks, at most the battery's `guns` at a time; every shot costs shot_iron
## iron. It never walks after a target.
## Spells (MagicSystem fills these at the start of every tick): «Богородица» and «Благословение
## хоругви» add morale, the blessing armor, «Договор» stops morale falling and adds damage.

## A battery is reached from this far (thousandths of a cell from its walls).
const BATTERY_REACH_MILLI := 1500

var entities: EntityStore
var rules: CombatRulesDef
var buckets: UnitBuckets
## UnitDef by slot, shared with CombatSystem.
var defs: Array[UnitDef] = []
## Buildings and players (set by Simulation; null in tests without the economy).
var buildings: BuildingStore
var players: Dictionary[int, PlayerState] = {}
var tick := 0

## Ticks a wagon, pavisier or bombard has stood still (up to what it needs), by id.
var still: Dictionary[int, int] = {}
## Tick the lance's melee began (since its last charge), by id.
var fight_from: Dictionary[int, int] = {}
## Deployed bombards: id -> the battery they fire from.
var deployed: Dictionary[int, int] = {}
## Spiked bombards (Корона 2: the Gdańsk shipmen), by id: they do not fire until mended.
var spiked: Dictionary[int, bool] = {}
## Tabor rings standing now, refilled every tick: owner, centre (fixed) and radius (fixed).
var ring_owner := PackedInt32Array()
var ring_x := PackedInt64Array()
var ring_y := PackedInt64Array()
var ring_r := PackedInt64Array()
## Spell boosts this tick (MagicSystem.boost): morale points, armor and damage per mille, by id;
## pact: units whose morale does not fall.
var spell_morale: Dictionary[int, int] = {}
var spell_armor: Dictionary[int, int] = {}
var spell_damage: Dictionary[int, int] = {}
var pact: Dictionary[int, bool] = {}
## Morale every unit of a player gets (catalog points), by player: the great banner of the
## kingdom while it stands (Корона 1, MissionField; the mission's state carries it).
var army_morale: Dictionary[int, int] = {}

## Units that need watching, by id (wagons, pavisiers, bombards, escorts and steadiers).
var _watched: Dictionary[int, bool] = {}
var _steadiers: Dictionary[int, bool] = {}
## Whether any pavisier was ever made (skips looking for cover otherwise).
var _pavises := false


func _init(p_entities: EntityStore, p_rules: CombatRulesDef, p_buckets: UnitBuckets) -> void:
	entities = p_entities
	rules = p_rules
	buckets = p_buckets


func on_spawn(id: int, def: UnitDef) -> void:
	if def == null:
		return
	if def.param(&"tabor_wagons") > 0 or def.tags.has(&"pavise") or def.tags.has(&"battery_only"):
		_watched[id] = true
	if def.tags.has(&"pavise"):
		_pavises = true
	if def.tags.has(&"steadies_neighbours"):
		_steadiers[id] = true


# --- the step ------------------------------------------------------------------------------


## At the start of the combat step: forget the dead, find the tabor rings, deploy bombards.
func refresh(at_tick: int) -> void:
	tick = at_tick
	for d: Dictionary in [_watched, _steadiers, still, fight_from, deployed]:
		for id: int in d.keys():
			if not entities.is_alive(id):
				d.erase(id)
	_find_rings()
	_deploy()


## After movement: a unit that moved starts standing still from nothing.
func after_move() -> void:
	var e := entities
	for id: int in _watched:
		var slot := id - 1
		if e.moved[slot] == 1:
			still.erase(id)
			deployed.erase(id)
		else:
			var need := maxi(_need_still(slot), 1)
			still[id] = mini(still.get(id, 0) + 1, need)


func _need_still(slot: int) -> int:
	var def := defs[slot]
	if def.param(&"tabor_wagons") > 0:
		return rules.tabor_link_ticks
	if def.tags.has(&"pavise"):
		return def.param(&"pavise_ticks")
	return def.param(&"deploy_ticks")


func _ready_still(id: int) -> bool:
	return still.get(id, 0) >= _need_still(id - 1)


# --- tabor -------------------------------------------------------------------------------


func _find_rings() -> void:
	ring_owner.clear()
	ring_x.clear()
	ring_y.clear()
	ring_r.clear()
	var e := entities
	var wagons := PackedInt32Array()
	for id: int in _watched:
		if defs[id - 1].param(&"tabor_wagons") > 0 and _ready_still(id) and e.hp[id - 1] > 0:
			wagons.append(id)
	if wagons.size() < 2:
		return
	wagons.sort()
	var link := Fixed.from_cells(rules.tabor_link_cells)
	var group := PackedInt32Array()
	group.resize(wagons.size())
	group.fill(-1)
	for i in wagons.size():
		if group[i] >= 0:
			continue
		# Wagons of one owner linked a step at a time make one group.
		group[i] = i
		var todo := [i]
		while not todo.is_empty():
			var a: int = todo.pop_back()
			for j in wagons.size():
				if group[j] >= 0 or e.owners[wagons[j] - 1] != e.owners[wagons[a] - 1]:
					continue
				var sa := wagons[a] - 1
				var sb := wagons[j] - 1
				if Fixed.distance(e.pos_x[sa], e.pos_y[sa], e.pos_x[sb], e.pos_y[sb]) <= link:
					group[j] = i
					todo.append(j)
	for i in wagons.size():
		if group[i] == i:
			_ring_of(wagons, group, i)


## A group of wagons is a ring when it has enough wagons and they stand round a middle (none
## closer than a cell to it).
func _ring_of(wagons: PackedInt32Array, group: PackedInt32Array, head: int) -> void:
	var e := entities
	var members := PackedInt32Array()
	var sx := 0
	var sy := 0
	for j in wagons.size():
		if group[j] == head:
			members.append(wagons[j])
			sx += e.pos_x[wagons[j] - 1]
			sy += e.pos_y[wagons[j] - 1]
	var owner := e.owners[members[0] - 1]
	var need := defs[members[0] - 1].param(&"tabor_wagons")
	var state: PlayerState = players.get(owner)
	if state != null:
		need += state.tabor_wagons_bonus
	if members.size() < maxi(need, 2):
		return
	var cx := Fixed.floor_div(sx, members.size())
	var cy := Fixed.floor_div(sy, members.size())
	var r := 0
	for id in members:
		var d := Fixed.distance(cx, cy, e.pos_x[id - 1], e.pos_y[id - 1])
		if d < Fixed.ONE:
			return
		r = maxi(r, d)
	ring_owner.append(owner)
	ring_x.append(cx)
	ring_y.append(cy)
	ring_r.append(r)


## The ring the unit stands in (infantry and shooters of the ring's owner only), or -1.
func ring_at(slot: int) -> int:
	if ring_owner.is_empty() or defs[slot] == null:
		return -1
	var def := defs[slot]
	if not (def.has_class(&"infantry") or def.has_class(&"archer") or def.has_class(&"firearm")):
		return -1
	var e := entities
	for i in ring_owner.size():
		if ring_owner[i] != e.owners[slot]:
			continue
		if Fixed.distance(ring_x[i], ring_y[i], e.pos_x[slot], e.pos_y[slot]) <= ring_r[i]:
			return i
	return -1


func _tabor_armor(slot: int) -> int:
	var i := ring_at(slot)
	if i < 0:
		return 0
	var state: PlayerState = players.get(ring_owner[i])
	return rules.tabor_armor + (state.tabor_armor_bonus if state != null else 0)


## Inside a tabor a blow in the flank costs no morale.
func ignores_flank(slot: int) -> bool:
	return ring_at(slot) >= 0


# --- armor, morale, damage -----------------------------------------------------------------


func armor_melee(slot: int) -> int:
	return _tabor_armor(slot) + spell_armor.get(slot + 1, 0)


func armor_pierce(slot: int) -> int:
	return _tabor_armor(slot) + spell_armor.get(slot + 1, 0) + _pavise_cover(slot)


## +pavise_armor for a shooter behind an own pavise that is set up.
func _pavise_cover(slot: int) -> int:
	var def := defs[slot]
	if not _pavises or def == null:
		return 0
	if not (def.has_class(&"archer") or def.has_class(&"firearm")):
		return 0
	var e := entities
	var r := Fixed.from_cells(rules.pavise_cover_cells)
	var best := 0
	for other in buckets.near(e.pos_x[slot], e.pos_y[slot], r):
		var o := other - 1
		if o == slot or e.owners[o] != e.owners[slot] or not _watched.has(other):
			continue
		if not defs[o].tags.has(&"pavise") or not _ready_still(other) or e.hp[o] <= 0:
			continue
		# Behind or beside the pavisier: not ahead of the way he faces.
		var dx := e.pos_x[slot] - e.pos_x[o]
		var dy := e.pos_y[slot] - e.pos_y[o]
		if dx * e.facing_x[o] + dy * e.facing_y[o] <= 0:
			best = maxi(best, defs[o].param(&"pavise_armor"))
	return best


## Whether a pavisier has his pavise set up (for drawing him crouched behind it).
func pavise_set(id: int) -> bool:
	return _watched.has(id) and defs[id - 1].tags.has(&"pavise") and _ready_still(id)


## Morale from the Crown's rules: the servant beside his knight's lance, and spells.
func morale_bonus(slot: int) -> int:
	var bonus: int = spell_morale.get(slot + 1, 0)
	if not army_morale.is_empty():
		bonus += army_morale.get(entities.owners[slot], 0)
	var def := defs[slot]
	if def == null or not def.tags.has(&"lance_escort"):
		return bonus
	var e := entities
	var r := Fixed.from_milli(rules.escort_radius_milli)
	for other in buckets.near(e.pos_x[slot], e.pos_y[slot], r):
		var o := other - 1
		if o == slot or e.owners[o] != e.owners[slot] or defs[o] == null or e.hp[o] <= 0:
			continue
		if defs[o].tags.has(&"charge") and defs[o].has_class(&"heavy_cavalry"):
			return bonus + def.param(&"escort_morale")
	return bonus


## The morale a unit really loses of `points`: none under «Договор», half beside a steadying
## servant in close order.
func morale_loss(slot: int, points: int) -> int:
	if pact.has(slot + 1):
		return 0
	if _steadiers.is_empty():
		return points
	var e := entities
	var r := Fixed.from_milli(rules.formation_radius_milli)
	for other in buckets.near(e.pos_x[slot], e.pos_y[slot], r):
		var o := other - 1
		if o == slot or not _steadiers.has(other) or e.owners[o] != e.owners[slot]:
			continue
		if e.hp[o] > 0 and _in_close_order(o):
			return (points + 1) / 2
	return points


func _in_close_order(slot: int) -> bool:
	var e := entities
	var n := 0
	var r := Fixed.from_milli(rules.formation_radius_milli)
	for other in buckets.near(e.pos_x[slot], e.pos_y[slot], r):
		var o := other - 1
		if o != slot and e.owners[o] == e.owners[slot] and defs[o] != null:
			if defs[o].has_class(&"infantry"):
				n += 1
	return n >= rules.formation_neighbours


## Per-mille damage multiplier of the unit's strikes (1000: none).
func damage_permille(slot: int) -> int:
	return spell_damage.get(slot + 1, 1000)


## The lance's strike: a charge starts its melee over; long melee costs it damage.
func strike_penalty(slot: int, charged: bool) -> int:
	var def := defs[slot]
	var ticks := def.param(&"melee_fatigue_ticks")
	if ticks <= 0:
		return 0
	var id := slot + 1
	var e := entities
	if charged or not fight_from.has(id) or e.calm[slot] >= rules.out_of_combat_ticks:
		fight_from[id] = tick
		return 0
	return def.param(&"melee_fatigue_damage") if tick - fight_from[id] >= ticks else 0


# --- the bombard --------------------------------------------------------------------------


## Bombards standing still next to an own finished battery deploy, up to its guns.
func _deploy() -> void:
	if buildings == null:
		return
	var e := entities
	var at_battery: Dictionary[int, int] = {}
	for id: int in deployed:
		at_battery[deployed[id]] = at_battery.get(deployed[id], 0) + 1
	var ids := _watched.keys()
	ids.sort()
	for id: int in ids:
		var slot := id - 1
		if deployed.has(id) or not defs[slot].tags.has(&"battery_only") or not _ready_still(id):
			continue
		var b := _battery_near(slot)
		if b == BuildingStore.NO_ID:
			continue
		var guns := maxi(buildings.defs[b - 1].param(&"guns", 1), 1)
		if at_battery.get(b, 0) < guns:
			deployed[id] = b
			at_battery[b] = at_battery.get(b, 0) + 1
	for id: int in deployed.keys():
		if not buildings.is_done(deployed[id]) or e.hp[id - 1] <= 0:
			deployed.erase(id)


func _battery_near(slot: int) -> int:
	var e := entities
	var reach := Fixed.from_milli(BATTERY_REACH_MILLI)
	for b in buildings.alive_ids:
		var s := b - 1
		if buildings.owners[s] != e.owners[slot] or buildings.done[s] == 0:
			continue
		if buildings.defs[s].param(&"guns") <= 0:
			continue
		if buildings.distance_sq(b, e.pos_x[slot], e.pos_y[slot]) <= reach * reach:
			return b
	return BuildingStore.NO_ID


## Units that never walk after a target (the bombard keeps to its battery).
func anchored(slot: int) -> bool:
	return defs[slot] != null and defs[slot].tags.has(&"battery_only")


## Whether the unit may fire now: a bombard only deployed and with the iron for a shot.
func may_fire(slot: int) -> bool:
	var def := defs[slot]
	if def == null or not def.tags.has(&"battery_only"):
		return true
	if not deployed.has(slot + 1) or spiked.has(slot + 1):
		return false
	var state: PlayerState = players.get(entities.owners[slot])
	return state == null or state.stock[EconomySystem.IRON] >= def.param(&"shot_iron")


## Takes the shot's iron (call when the unit fires).
func fired(slot: int) -> void:
	var def := defs[slot]
	if def == null or def.param(&"shot_iron") <= 0:
		return
	var state: PlayerState = players.get(entities.owners[slot])
	if state != null:
		state.stock[EconomySystem.IRON] -= def.param(&"shot_iron")


# --- state ----------------------------------------------------------------------------------


func write_to(buf: StreamPeerBuffer) -> void:
	# Nothing while no Crown unit has done anything, so older replays keep their hashes.
	if still.is_empty() and fight_from.is_empty() and deployed.is_empty():
		return
	for d: Dictionary in [still, fight_from, deployed]:
		var keys := d.keys()
		keys.sort()
		buf.put_32(keys.size())
		for k: int in keys:
			buf.put_32(k)
			buf.put_32(int(d[k]))
