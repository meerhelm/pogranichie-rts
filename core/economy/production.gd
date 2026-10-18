class_name EconomyProduction
extends RefCounted
## The economy's production (M5): prices of units, techs and ages, building queues within the
## population limit, trained units coming out, research and what techs do to units. Part of
## EconomySystem, which owns the state it works on and calls it each tick.
## The Crown's wayside cross becomes a chapel by the queue item CHAPEL at it (upgrade_wood,
## upgrade_silver, its build time), queued while an own priest stands by.

## Queue item that makes a shrine a chapel (BuildingStore.upgraded).
const CHAPEL := &"chapel"
## A priest this near a shrine (cells from its walls) lets its chapel be queued.
const CHAPEL_PRIEST_CELLS := 3

var entities: EntityStore
var nav: NavGrid
var db: CatalogDB
var rules: EconomyRulesDef
## Shared with EconomySystem: players by number, buildings, unit defs by slot.
var players: Dictionary[int, PlayerState]
var buildings: BuildingStore
var unit_defs: Array[UnitDef]

var _walk: Callable
var _spawn: Callable


func _init(economy: EconomySystem, walk: Callable, spawn: Callable) -> void:
	entities = economy.entities
	nav = economy.nav
	db = economy.db
	rules = economy.rules
	players = economy.players
	buildings = economy.buildings
	unit_defs = economy.unit_defs
	_walk = walk
	_spawn = spawn


func _pop_cap(state: PlayerState) -> int:
	return mini(state.pop_provided, rules.pop_cap)


func unit_cost(u: UnitDef, at: BuildingDef) -> PackedInt32Array:
	var cost := PackedInt32Array([u.cost_food, u.cost_wood, u.cost_iron, u.cost_silver])
	var discount := at.param(&"cavalry_discount_permille") if at != null else 0
	if discount > 0 and u.has_class(&"cavalry"):
		for r in 4:
			cost[r] = cost[r] * (1000 - discount) / 1000
	return cost


func tech_cost(p: int, t: TechDef) -> PackedInt32Array:
	var cost := PackedInt32Array([t.cost_food, t.cost_wood, t.cost_iron, t.cost_silver])
	var fac := db.faction(players[p].faction)
	var permille: int = fac.tech_cost_permille.get(t.id, 1000) if fac != null else 1000
	for r in 4:
		cost[r] = cost[r] * permille / 1000
	return cost


static func age_cost(a: AgeDef) -> PackedInt32Array:
	return PackedInt32Array([a.cost_food, a.cost_wood, a.cost_iron, a.cost_silver])


## Puts a unit, tech or age in the building's queue and takes its price; EconomySystem.Fail.OK
## if accepted.
func enqueue(p: int, b: int, item: StringName) -> int:
	var check := can_queue(p, b, item)
	if check != EconomySystem.Fail.OK:
		return check
	var state := players[p]
	state.pay(item_cost(p, b, item))
	buildings.queues[b - 1].append(item)
	if db.unit(item) == null and item != CHAPEL:
		state.researching[item] = true
	return EconomySystem.Fail.OK


func can_queue(p: int, b: int, item: StringName) -> int:
	var state: PlayerState = players.get(p)
	if state == null or not buildings.is_done(b) or buildings.owners[b - 1] != p:
		return EconomySystem.Fail.NO_PLAYER
	var bdef := buildings.defs[b - 1]
	var fail := EconomySystem.Fail.UNKNOWN
	if db.unit(item) != null:
		fail = _unit_fail(state, bdef, db.unit(item))
	elif db.tech(item) != null:
		fail = _tech_fail(state, bdef, db.tech(item))
	elif db.age(item) != null:
		fail = _age_fail(state, bdef, db.age(item))
	elif item == CHAPEL:
		fail = _chapel_fail(state, b)
	if fail == EconomySystem.Fail.OK and buildings.dismantling[b - 1] == 1:
		fail = EconomySystem.Fail.DISMANTLING
	if fail != EconomySystem.Fail.OK:
		return fail
	if state.locked.has(item):
		return EconomySystem.Fail.LOCKED
	if buildings.queues[b - 1].size() >= rules.queue_max:
		return EconomySystem.Fail.QUEUE_FULL
	if not state.can_pay(item_cost(p, b, item)):
		return EconomySystem.Fail.COST
	return EconomySystem.Fail.OK


func _unit_fail(state: PlayerState, bdef: BuildingDef, u: UnitDef) -> int:
	if not bdef.trains.has(u.id) or u.campaign_only or u.faction != state.faction:
		return EconomySystem.Fail.UNKNOWN
	if u.age > state.age:
		return EconomySystem.Fail.AGE
	if not _under_limit(state.player, u):
		return EconomySystem.Fail.LIMIT
	return EconomySystem.Fail.OK


func _tech_fail(state: PlayerState, bdef: BuildingDef, t: TechDef) -> int:
	# A tech without effects is not in the game yet (manual.json tech_effects._deferred).
	if (t.building != bdef.id and t.building != bdef.base_id) or t.effects.is_empty():
		return EconomySystem.Fail.UNKNOWN
	var fac := db.faction(state.faction)
	if fac == null or not fac.tech_ids.has(t.id):
		return EconomySystem.Fail.FACTION
	if t.age > state.age:
		return EconomySystem.Fail.AGE
	if state.techs.has(t.id) or state.researching.has(t.id):
		return EconomySystem.Fail.CONDITION
	return EconomySystem.Fail.OK


## The chapel: a shrine that has one (upgrade_power_rate_milli), not yet upgraded nor being
## upgraded, with an own priest (tag builds_shrine) within CHAPEL_PRIEST_CELLS of it.
func _chapel_fail(state: PlayerState, b: int) -> int:
	var s := b - 1
	if buildings.defs[s].param(&"upgrade_power_rate_milli") <= 0:
		return EconomySystem.Fail.UNKNOWN
	if buildings.upgraded[s] == 1 or buildings.queues[s].has(CHAPEL):
		return EconomySystem.Fail.CONDITION
	return EconomySystem.Fail.OK if priest_near(state.player, b) else EconomySystem.Fail.CONDITION


## Whether an own unit tagged builds_shrine stands within CHAPEL_PRIEST_CELLS of building b.
func priest_near(p: int, b: int) -> bool:
	var r := Fixed.from_cells(CHAPEL_PRIEST_CELLS)
	for id in entities.alive_ids:
		var slot := id - 1
		var def := unit_defs[slot]
		if entities.owners[slot] != p or def == null or not def.tags.has(&"builds_shrine"):
			continue
		if buildings.distance_sq(b, entities.pos_x[slot], entities.pos_y[slot]) <= r * r:
			return true
	return false


func _age_fail(state: PlayerState, bdef: BuildingDef, a: AgeDef) -> int:
	if bdef.base_id != EconomySystem.TOWN_CENTER or a.index != state.age + 1:
		return EconomySystem.Fail.UNKNOWN
	if state.researching.has(a.id) or not age_condition(state.player, a):
		return EconomySystem.Fail.CONDITION
	return EconomySystem.Fail.OK


func item_cost(p: int, b: int, item: StringName) -> PackedInt32Array:
	var u := db.unit(item)
	if u != null:
		return unit_cost(u, buildings.defs[b - 1] if buildings.is_alive(b) else null)
	var t := db.tech(item)
	if t != null:
		return tech_cost(p, t)
	var a := db.age(item)
	if a != null:
		return age_cost(a)
	if item == CHAPEL and buildings.is_alive(b):
		var def := buildings.defs[b - 1]
		return PackedInt32Array([0, def.param(&"upgrade_wood"), 0, def.param(&"upgrade_silver")])
	return PackedInt32Array([0, 0, 0, 0])


## «2 постройки Удела»: that many finished buildings of different kinds from the age (or
## earlier), not counting those tagged no_age_count; «Замок или …» also takes a castle.
func age_condition(p: int, a: AgeDef) -> bool:
	var need := a.params.get(&"required_buildings", 0) as int
	var of_age := a.params.get(&"required_buildings_age", 0) as int
	var kinds := {}
	for b in buildings.alive_ids:
		var s := b - 1
		if buildings.owners[s] != p or buildings.done[s] == 0:
			continue
		var def := buildings.defs[s]
		if a.params.get(&"castle_instead", 0) == 1 and def.base_id == &"castle":
			return true
		if def.age <= of_age and not def.tags.has(&"no_age_count"):
			kinds[String(def.id)] = true
	return kinds.size() >= need


## Units with a «не больше N» limit: alive and queued together stay within it.
func _under_limit(p: int, u: UnitDef) -> bool:
	var limit := u.param(&"limit")
	var per_castle := u.param(&"limit_per_castle")
	if per_castle > 0:
		limit = per_castle * _count_done(p, &"castle")
	elif limit == 0:
		return true
	var have := 0
	for id in entities.alive_ids:
		if entities.owners[id - 1] == p and entities.type_ids[id - 1] == u.id:
			have += 1
	for b in buildings.alive_ids:
		if buildings.owners[b - 1] == p:
			for item: StringName in buildings.queues[b - 1]:
				if item == u.id:
					have += 1
	return have < limit


func _count_done(p: int, base: StringName) -> int:
	var n := 0
	for b in buildings.alive_ids:
		var s := b - 1
		if (
			buildings.owners[s] == p
			and buildings.done[s] == 1
			and buildings.defs[s].base_id == base
		):
			n += 1
	return n


## Takes item `index` out of the queue and gives back cancel_refund_permille of its price.
func cancel(p: int, b: int, index: int) -> void:
	if not buildings.is_alive(b) or buildings.owners[b - 1] != p:
		return
	var s := b - 1
	var q: Array = buildings.queues[s]
	if index < 0 or index >= q.size():
		return
	var item: StringName = q[index]
	var state := players[p]
	state.refund(item_cost(p, b, item), rules.cancel_refund_permille)
	state.researching.erase(item)
	if index == 0:
		if buildings.queue_started[s] == 1 and db.unit(item) != null:
			state.pop_training -= db.unit(item).pop
		buildings.queue_started[s] = 0
		buildings.queue_ticks[s] = 0
	q.remove_at(index)


## Ticks an item (unit, tech, age, the chapel at building b) takes in a queue.
func item_ticks(item: StringName, b: int = BuildingStore.NO_ID) -> int:
	if item == CHAPEL:
		return buildings.defs[b - 1].build_ticks if buildings.is_alive(b) else 0
	var u := db.unit(item)
	if u != null:
		return u.train_ticks
	var t := db.tech(item)
	if t != null:
		return t.research_ticks
	var a := db.age(item)
	return a.research_ticks if a != null else 0


func produce(b: int) -> void:
	var s := b - 1
	var q: Array = buildings.queues[s]
	var state: PlayerState = players.get(buildings.owners[s])
	if buildings.done[s] == 0 or q.is_empty() or state == null:
		return
	var item: StringName = q[0]
	var u := db.unit(item)
	if buildings.queue_started[s] == 0:
		# A unit starts only when there is room for it, and holds its place while trained.
		if u != null and state.pop_used() + u.pop > _pop_cap(state):
			return
		if u != null:
			state.pop_training += u.pop
		buildings.queue_started[s] = 1
	buildings.queue_ticks[s] += 1
	if buildings.queue_ticks[s] < item_ticks(item, b):
		return
	q.remove_at(0)
	buildings.queue_ticks[s] = 0
	buildings.queue_started[s] = 0
	if u != null:
		state.pop_training -= u.pop
		state.trained += 1
		_release_unit(b, u)
	elif item == CHAPEL:
		buildings.upgraded[s] = 1
	else:
		_finish_research(state, item)


func _finish_research(state: PlayerState, item: StringName) -> void:
	state.researching.erase(item)
	var a := db.age(item)
	if a != null:
		state.age = a.index
	else:
		_research_done(state, db.tech(item))


## A trained unit comes out next to the building (on the side toward its rally point) and walks
## to the rally point if there is one.
func _release_unit(b: int, u: UnitDef) -> void:
	var s := b - 1
	var p := buildings.owners[s]
	var tx := buildings.center_x(b)
	var ty := Fixed.from_cells(buildings.cell_y[s] + buildings.h[s] + 1)
	if buildings.has_rally[s] == 1:
		tx = buildings.rally_x[s]
		ty = buildings.rally_y[s]
	var spot := _exit_cell(b, tx, ty, NavGrid.move_class_for(u))
	var id: int = _spawn.call(u.id, p, nav.center_x(spot), nav.center_y(spot))
	if id > 0 and buildings.has_rally[s] == 1:
		_walk.call(id, tx, ty)


func _exit_cell(b: int, tx: int, ty: int, cls: int) -> int:
	var s := b - 1
	var x0 := buildings.cell_x[s]
	var y0 := buildings.cell_y[s]
	for r in range(1, EconomySystem.STAND_RINGS + 3):
		var best := NavGrid.NO_CELL
		var best_d := 0
		for y in range(y0 - r, y0 + buildings.h[s] + r):
			for x in range(x0 - r, x0 + buildings.w[s] + r):
				var on_ring := (
					x == x0 - r
					or y == y0 - r
					or x == x0 + buildings.w[s] + r - 1
					or y == y0 + buildings.h[s] + r - 1
				)
				if not on_ring or not nav.in_bounds(x, y):
					continue
				var c := nav.cell_at(x, y)
				if not nav.passable(cls, c):
					continue
				var d := Fixed.distance(tx, ty, nav.center_x(c), nav.center_y(c))
				if best == NavGrid.NO_CELL or d < best_d:
					best = c
					best_d = d
		if best != NavGrid.NO_CELL:
			return best
	return nav.cell_at(x0, y0)


# --- techs ---------------------------------------------------------------------------------


func _research_done(state: PlayerState, t: TechDef) -> void:
	if t == null:
		return
	state.techs[t.id] = true
	var keys := PackedStringArray()
	for k: StringName in t.effects:
		keys.append(String(k))
	keys.sort()
	var stats_changed := false
	for k in keys:
		var key := StringName(k)
		var v: int = t.effects[key]
		if k.contains("."):
			state.unit_mods[key] = state.unit_mods.get(key, 0) + v
			stats_changed = true
			continue
		match k:
			"farm_food":
				state.farm_food_bonus += v
			"zaseka_speed":
				state.zaseka_speed_bonus += v
			"zaseka_hp":
				state.zaseka_hp_bonus += v
			"wall_sight":
				state.wall_sight_bonus += v
			"tabor_wagons":
				state.tabor_wagons_bonus += v
			"tabor_armor":
				state.tabor_armor_bonus += v
			"salt_rate":
				state.salt_rate_bonus += v
			_:
				var src := (
					["gather_farm", "gather_hunt", "gather_bort", "gather_wood", "gather_iron"]
					. find(k)
				)
				state.gather_bonus[src if src >= 0 else ResourceNodes.Source.SILVER] += v
	if stats_changed:
		for id in entities.alive_ids:
			if entities.owners[id - 1] == state.player:
				apply_mods(id)


## Puts the owner's tech bonuses on one unit: damage of its own kind, armor, range, HP.
func apply_mods(id: int) -> void:
	var slot := id - 1
	var def := unit_defs[slot]
	var state: PlayerState = players.get(entities.owners[slot])
	if def == null or state == null or state.unit_mods.is_empty():
		return
	var sums := {}
	var keys: Array[StringName] = def.classes.duplicate()
	keys.append(def.id)
	for k: StringName in keys:
		for stat: String in [
			"damage_melee", "damage_pierce", "armor_melee", "armor_pierce", "range", "hp_permille"
		]:
			var v: int = state.unit_mods.get(StringName("%s.%s" % [k, stat]), 0)
			sums[stat] = (sums.get(stat, 0) as int) + v
	var e := entities
	if def.damage_type == EconomySystem.MELEE:
		e.up_damage[slot] = sums["damage_melee"]
	elif def.damage_type == EconomySystem.PIERCE:
		e.up_damage[slot] = sums["damage_pierce"]
	e.up_armor_m[slot] = sums["armor_melee"]
	e.up_armor_p[slot] = sums["armor_pierce"]
	e.up_range[slot] = sums["range"] if def.attack_range > 0 else 0
	var new_max: int = def.hp * (1000 + (sums["hp_permille"] as int)) / 1000
	if new_max != e.max_hp[slot] and e.hp[slot] > 0:
		e.hp[slot] += new_max - e.max_hp[slot]
		e.max_hp[slot] = new_max
