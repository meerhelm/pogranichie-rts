class_name Construction
extends RefCounted
## Building, repairing and taking apart (part of EconomySystem, split out of it in 2026-10).
## Integers and ascending ids only.
##
## Builders put up foundations (each next builder adds builder_extra_permille of one builder's
## speed), go on to the next foundation of a wall line, and repair: all HP back in
## repair_time_permille of the build time for repair_cost_permille of the price, paid as it goes.
##
## Taking apart (Valentin, 2026-10-16): peasants ordered to DISMANTLE an own building walk to it
## and take it apart, several faster as in construction. It takes dismantle_time_permille of the
## work its construction has had so far, and its production queue is cancelled with the usual
## refund as soon as the order comes. When it is down the building leaves its owner salvage:
## dismantle_refund_permille of its price, a pile per resource on its cells, which only the
## owner's peasants pick up and carry, like any other resource, to a building that takes that
## resource in. Those who took it apart go on to the piles. A WORK order (build, repair) on a
## building being taken apart stops it. A side's last finished capital or castle cannot be
## taken apart (losing it loses the game, SkirmishVictory.CAPITALS).

## The economy, through a Callable: holding it would make a reference cycle (it holds this).
var _economy: Callable
## Builders and dismantlers working each building this tick, filled while units work.
var _builders: Dictionary[int, int] = {}
var _dismantlers: Dictionary[int, int] = {}


## `economy` returns the EconomySystem this works for.
func _init(economy: Callable) -> void:
	_economy = economy


func _e() -> EconomySystem:
	return _economy.call()


func begin_step() -> void:
	_builders.clear()
	_dismantlers.clear()


## After the units worked: buildings rise, are repaired or come apart, by ascending id.
func end_step() -> void:
	var built := _builders.keys()
	built.sort()
	for b: int in built:
		_construct(b, _builders[b])
	var taken := _dismantlers.keys()
	taken.sort()
	for b: int in taken:
		if _e().buildings.is_alive(b):
			_take_apart(b, _dismantlers[b])


## A builder speeds construction by a whole builder, every next one by builder_extra_permille.
func speed(workers: int) -> int:
	return 1000 + (workers - 1) * _e().rules.builder_extra_permille


# --- building and repairing ----------------------------------------------------------------


## One tick of a builder: on to its foundation (or the next of the line) and work on it.
func build(id: int) -> void:
	var e := _e()
	var slot := id - 1
	var b := e.job_ref[slot]
	var finished := not e.buildings.is_alive(b)
	if not finished:
		var s := b - 1
		finished = e.buildings.done[s] == 1 and e.buildings.hp[s] >= e.buildings.max_hp[s]
	if finished:
		# A field or hive it put up: the builder works it at once (if there is room on it).
		if _work_it(slot, b):
			return
		# Walls: go on to the next foundation of the line.
		var next := _nearest_foundation(id)
		if next == BuildingStore.NO_ID:
			e.end_job(slot)
			return
		e.job_ref[slot] = next
		e.tries[slot] = 0
		b = next
	if not e.to_building(id, b):
		return
	e.phase[slot] = EconomySystem.Phase.WORK
	_builders[b] = _builders.get(b, 0) + 1


## The builder of a finished field or hive starts working it, when there is room on it.
func _work_it(slot: int, b: int) -> bool:
	var e := _e()
	if not e.buildings.is_alive(b):
		return false
	var source := e.building_source(e.entities.owners[slot], b)
	if source < 0:
		return false
	var farm := source == ResourceNodes.Source.FARM
	var limit := e.rules.farm_workers if farm else e.rules.bort_workers
	if e.buildings.workers[b - 1] >= limit:
		return false
	return e.start_gather(slot, source, EconomySystem.Target.BUILDING, b)


func _nearest_foundation(id: int) -> int:
	var e := _e()
	var store := e.buildings
	var slot := id - 1
	var p := e.entities.owners[slot]
	var r := Fixed.from_cells(e.rules.resource_search_cells)
	var best := BuildingStore.NO_ID
	var best_d := 0
	for b in store.alive_ids:
		var s := b - 1
		if store.owners[s] != p or store.done[s] == 1:
			continue
		var d := store.distance_sq(b, e.entities.pos_x[slot], e.entities.pos_y[slot])
		if d > r * r:
			continue
		if best == BuildingStore.NO_ID or d < best_d:
			best = b
			best_d = d
	return best


func _construct(b: int, builders: int) -> void:
	var store := _e().buildings
	var s := b - 1
	var gain := speed(builders)
	if store.done[s] == 0:
		var before := store.progress[s]
		var after := mini(before + gain, store.work[s])
		store.progress[s] = after
		var max_hp := store.max_hp[s]
		var work := store.work[s]
		store.hp[s] += max_hp * after / work - max_hp * before / work
		store.hp[s] = clampi(store.hp[s], 1, max_hp)
		if after >= work:
			_e().complete(b)
			_e().players[store.owners[s]].built += 1
		return
	_repair(b, gain)


## Repair: all HP back in repair_time_permille of the build time, for repair_cost_permille of
## the price, paid as it goes; it stops while the owner cannot pay.
func _repair(b: int, gain_speed: int) -> void:
	var store := _e().buildings
	var rules := _e().rules
	var s := b - 1
	var def := store.defs[s]
	var state: PlayerState = _e().players.get(store.owners[s])
	if state == null or store.hp[s] >= store.max_hp[s]:
		return
	var ticks := maxi(def.build_ticks * rules.repair_time_permille / 1000, 1)
	var gain := store.repair_hp[s] + store.max_hp[s] * gain_speed / ticks
	var whole := mini(gain / 1000, store.max_hp[s] - store.hp[s])
	var price := PackedInt32Array([def.cost_food, def.cost_wood, def.cost_iron, def.cost_silver])
	var owed := store.repair_owed[s].duplicate()
	var due := PackedInt32Array([0, 0, 0, 0])
	for r in 4:
		owed[r] += whole * price[r] * rules.repair_cost_permille / store.max_hp[s]
		due[r] = owed[r] / 1000
	if not state.can_pay(due):
		return
	state.pay(due)
	for r in 4:
		owed[r] -= due[r] * 1000
	store.repair_owed[s] = owed
	store.repair_hp[s] = gain - whole * 1000
	store.hp[s] += whole


# --- taking apart --------------------------------------------------------------------------


## DISMANTLE: the obedient peasants among `units` take building cmd.target apart.
func order_dismantle(cmd: SimCommand, units: PackedInt32Array) -> void:
	var e := _e()
	var b := cmd.target
	if not can_dismantle(cmd.player, b):
		return
	start_dismantling(b)
	for id in units:
		var slot := id - 1
		var def := e.unit_defs[slot]
		if def == null or not def.has_class(&"peasant"):
			continue
		e.end_job(slot)
		e.job[slot] = EconomySystem.Job.DISMANTLE
		e.job_ref[slot] = b


## Whether player p may take building b apart: its own, and not its last capital or castle.
func can_dismantle(p: int, b: int) -> bool:
	var store := _e().buildings
	if not store.is_alive(b) or store.owners[b - 1] != p:
		return false
	if not is_last_capital(b):
		return true
	return store.dismantling[b - 1] == 1


## Whether b is its owner's only finished capital or castle.
func is_last_capital(b: int) -> bool:
	var store := _e().buildings
	var s := b - 1
	if store.done[s] == 0 or not SkirmishVictory.CAPITALS.has(store.defs[s].base_id):
		return false
	for other in store.alive_ids:
		var o := other - 1
		if other == b or store.owners[o] != store.owners[s] or store.done[o] == 0:
			continue
		if SkirmishVictory.CAPITALS.has(store.defs[o].base_id):
			return false
	return true


## Marks building b as being taken apart and cancels its queue (once).
func start_dismantling(b: int) -> void:
	var store := _e().buildings
	var s := b - 1
	if store.dismantling[s] == 1:
		return
	store.dismantling[s] = 1
	var total := store.progress[s] * _e().rules.dismantle_time_permille / 1000
	store.dismantle_total[s] = maxi(total, 1000)
	store.dismantle_left[s] = store.dismantle_total[s]
	var q: Array = store.queues[s]
	for i in range(q.size() - 1, -1, -1):
		_e().production.cancel(store.owners[s], b, i)


## A build or repair order: the building is no longer taken apart.
func stop_dismantling(b: int) -> void:
	var store := _e().buildings
	if store.is_alive(b):
		store.dismantling[b - 1] = 0
		store.dismantle_total[b - 1] = 0
		store.dismantle_left[b - 1] = 0


## One tick of a peasant with a DISMANTLE job: walk to the building, then take it apart.
func dismantle(id: int) -> void:
	var e := _e()
	var slot := id - 1
	var b := e.job_ref[slot]
	if not e.buildings.is_alive(b) or e.buildings.dismantling[b - 1] == 0:
		e.end_job(slot)
		return
	if not e.to_building(id, b):
		return
	e.phase[slot] = EconomySystem.Phase.WORK
	_dismantlers[b] = _dismantlers.get(b, 0) + 1


## What a building gives back when taken apart now: dismantle_refund_permille of its price.
func salvage(b: int) -> PackedInt32Array:
	var store := _e().buildings
	var s := b - 1
	var cost := _e().placement.building_cost(store.owners[s], store.defs[s])
	var out := PackedInt32Array([0, 0, 0, 0])
	for r in 4:
		out[r] = cost[r] * _e().rules.dismantle_refund_permille / 1000
	return out


func _take_apart(b: int, workers: int) -> void:
	var store := _e().buildings
	var s := b - 1
	store.dismantle_left[s] -= speed(workers)
	var left := maxi(store.dismantle_left[s], 0)
	var hp_left := store.max_hp[s] * left / store.dismantle_total[s]
	store.hp[s] = clampi(mini(store.hp[s], hp_left), 1, store.max_hp[s])
	if left == 0:
		_leave_salvage(b)


## The building is down: its salvage piles on its cells, its dismantlers on to them.
func _leave_salvage(b: int) -> void:
	var e := _e()
	var s := b - 1
	var owner := e.buildings.owners[s]
	var give := salvage(b)
	var cells := e.buildings.cells_of(b, e.nav.width)
	e.remove_building(b)
	var piles := PackedInt32Array()
	for r in 4:
		if give[r] <= 0:
			continue
		var cell := cells[piles.size() % cells.size()]
		var source := ResourceNodes.salvage_of(r)
		piles.append(e.nodes.add(source, cell, give[r], false, 0, owner))
	# Those who took it apart pick the piles up, in turn by id.
	var next := 0
	for id in e.entities.alive_ids:
		var slot := id - 1
		if e.job[slot] != EconomySystem.Job.DISMANTLE or e.job_ref[slot] != b:
			continue
		e.end_job(slot)
		if piles.is_empty():
			continue
		var pile := piles[next % piles.size()]
		next += 1
		e.start_gather(slot, e.nodes.sources[pile - 1], EconomySystem.Target.NODE, pile)
