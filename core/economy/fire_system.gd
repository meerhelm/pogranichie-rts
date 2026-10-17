class_name FireSystem
extends RefCounted
## Arson and fire (M9, mission card ВКЛ 1 «Поджог»), run by Simulation every tick after the
## economy. Integers only, buildings and units in ascending id order, chance only from the sim's
## rng, so a fire burns the same everywhere. Every number comes from FireRulesDef.
##
## A unit ordered to set a building on fire (SimCommand.ignite) walks up to it (or into its
## shooting range: fire arrows) and works at it for FireRulesDef.ignite_ticks (a hero with an
## ignite_ticks param is quicker); then the building burns. A fire takes the building's HP over
## burn_ticks (half as fast for burns_slowly, a zaseka in zaseka_burn_ticks), may jump to every
## flammable building within spread_cells, and goes out once the owner's units have worked
## douse_ticks at it: the owner's free units within douse_radius_cells come by themselves.
## Buildings tagged fireproof (stone and brick) do not burn unless a mission marks them wooden.

## Free units around a fire are looked for every this many ticks, not every tick.
const DOUSE_SCAN_EVERY := 10
## An arsonist or douser that cannot get to its building after this many walks gives up.
const MAX_TRIES := 4

var entities: EntityStore
var economy: EconomySystem
var rng: SimRng
var rules: FireRulesDef
## Allies (set by Simulation): nobody sets fire to an ally's building.
var sides := Sides.new()
## Burning buildings -> damage in thousandths of HP not yet dealt.
var burning: Dictionary[int, int] = {}
## Burning buildings -> unit-ticks of dousing done.
var doused: Dictionary[int, int] = {}
## Buildings a mission made wooden (they burn even if their kind is fireproof).
var wooden: Dictionary[int, bool] = {}
## Units setting a building on fire -> the building, and the ticks they have worked at it.
var arson: Dictionary[int, int] = {}
var arson_ticks: Dictionary[int, int] = {}
## Units putting a fire out -> the building.
var dousers: Dictionary[int, int] = {}
## Walks that did not get the unit there yet (arsonists and dousers).
var tries: Dictionary[int, int] = {}

var _stop: Callable


func _init(p_economy: EconomySystem, p_rng: SimRng, p_rules: FireRulesDef, stop: Callable) -> void:
	economy = p_economy
	entities = p_economy.entities
	rng = p_rng
	rules = p_rules
	_stop = stop


func enabled() -> bool:
	return rules != null and economy.enabled()


## Whether the building can catch fire now.
func flammable(b: int) -> bool:
	var store := economy.buildings
	if not store.is_alive(b) or burning.has(b):
		return false
	return wooden.has(b) or not store.defs[b - 1].tags.has(&"fireproof")


func is_burning(b: int) -> bool:
	return burning.has(b)


## Sets the building on fire (arson done, a spreading fire, or a mission).
func ignite(b: int) -> void:
	if enabled() and flammable(b):
		burning[b] = 0
		doused[b] = 0


## Whether a unit of this kind may carry a torch: anyone who fights, except animals.
func can_ignite(id: int) -> bool:
	var def := economy.unit_defs[id - 1]
	return def != null and def.damage > 0 and not def.has_class(&"animal")


## IGNITE: `ids` are the command's alive units that obey; the target is someone else's building.
func order(cmd: SimCommand, ids: PackedInt32Array) -> void:
	if not enabled():
		return
	var b := cmd.target
	var store := economy.buildings
	if not store.is_alive(b) or sides.friendly(store.owners[b - 1], cmd.player):
		return
	if not flammable(b):
		return
	for id in ids:
		if can_ignite(id):
			drop([id])
			arson[id] = b
			arson_ticks[id] = 0


## Units given another order stop setting fires and putting them out.
func drop(ids: PackedInt32Array) -> void:
	for id in ids:
		arson.erase(id)
		arson_ticks.erase(id)
		dousers.erase(id)
		tries.erase(id)


## Ticks a unit works at a building before it burns.
func ignite_ticks_of(id: int) -> int:
	var def := economy.unit_defs[id - 1]
	return def.param(&"ignite_ticks", rules.ignite_ticks) if def != null else rules.ignite_ticks


func step(tick: int) -> void:
	if not enabled():
		return
	_arsonists(tick)
	_burn()
	if tick % rules.spread_every_ticks == 0:
		_spread()
	if tick % DOUSE_SCAN_EVERY == 0:
		_call_dousers()
	_douse()


func _arsonists(tick: int) -> void:
	var ids := arson.keys()
	ids.sort()
	for id: int in ids:
		var b := arson[id]
		if not entities.is_alive(id) or economy.combat.is_fleeing(id) or not flammable(b):
			drop([id])
			continue
		if not _at(id, b, _reach_of(id)):
			continue
		arson_ticks[id] += 1
		entities.last_attack[id - 1] = tick
		if arson_ticks[id] >= ignite_ticks_of(id):
			ignite(b)
			drop([id])


## Melee units work at the wall; archers shoot fire arrows from their range.
func _reach_of(id: int) -> int:
	var def := economy.unit_defs[id - 1]
	if def.attack_range > 0:
		return Fixed.from_cells(def.attack_range + entities.up_range[id - 1])
	return -1


## Walks the unit to the building (EconomySystem.to_building); true once it is there. A unit
## that does not get there after MAX_TRIES walks gives up.
func _at(id: int, b: int, reach: int) -> bool:
	var was_moving := entities.orders[id - 1] == EntityStore.Order.MOVE
	if economy.to_building(id, b, reach):
		tries.erase(id)
		return true
	if not was_moving and entities.orders[id - 1] == EntityStore.Order.MOVE:
		tries[id] = tries.get(id, 0) + 1
		if tries[id] > MAX_TRIES:
			_stop.call(id)
			drop([id])
	return false


func _burn() -> void:
	var store := economy.buildings
	var ids := burning.keys()
	ids.sort()
	for b: int in ids:
		if not store.is_alive(b):
			_put_out(b)
			continue
		var s := b - 1
		var def := store.defs[s]
		var ticks := (
			rules.zaseka_burn_ticks if BuildingPlacement.is_zaseka(def) else rules.burn_ticks
		)
		var per_tick := store.max_hp[s] * 1000 / maxi(ticks, 1)
		if def.tags.has(&"burns_slowly"):
			per_tick = per_tick * rules.slow_burn_permille / 1000
		var acc := burning[b] + per_tick
		burning[b] = acc % 1000
		if acc >= 1000:
			economy.hit_building(b, acc / 1000)
		if not store.is_alive(b):
			_put_out(b)


func _spread() -> void:
	var store := economy.buildings
	var reach := Fixed.from_cells(rules.spread_cells)
	var ids := burning.keys()
	ids.sort()
	var caught := PackedInt32Array()
	for b: int in ids:
		for o in store.alive_ids:
			if o == b or not flammable(o) or caught.has(o):
				continue
			if _gap_sq(b, o) > reach * reach:
				continue
			if rng.chance_permille(rules.spread_permille):
				caught.append(o)
	for o in caught:
		ignite(o)


## Squared gap between two footprints (fixed units); 0 when they touch.
func _gap_sq(a: int, b: int) -> int:
	var store := economy.buildings
	var sa := a - 1
	var sb := b - 1
	var gx := maxi(store.cell_x[sb] - store.cell_x[sa] - store.w[sa], 0)
	gx = maxi(gx, store.cell_x[sa] - store.cell_x[sb] - store.w[sb])
	var gy := maxi(store.cell_y[sb] - store.cell_y[sa] - store.h[sa], 0)
	gy = maxi(gy, store.cell_y[sa] - store.cell_y[sb] - store.h[sb])
	return Fixed.from_cells(gx) * Fixed.from_cells(gx) + Fixed.from_cells(gy) * Fixed.from_cells(gy)


## The owner's free units near each fire come to put it out.
func _call_dousers() -> void:
	var store := economy.buildings
	var e := entities
	var r := Fixed.from_cells(rules.douse_radius_cells)
	var ids := burning.keys()
	ids.sort()
	for b: int in ids:
		var owner := store.owners[b - 1]
		for id in e.alive_ids:
			if e.owners[id - 1] != owner or not _free(id):
				continue
			if store.distance_sq(b, e.pos_x[id - 1], e.pos_y[id - 1]) <= r * r:
				dousers[id] = b


## Free to help: standing about, not fighting, not working, not fleeing, not busy with fire.
func _free(id: int) -> bool:
	var e := entities
	var slot := id - 1
	if dousers.has(id) or arson.has(id) or e.orders[slot] != EntityStore.Order.IDLE:
		return false
	if e.target[slot] != EntityStore.NO_ID or economy.job[slot] != EconomySystem.Job.NONE:
		return false
	var def := economy.unit_defs[slot]
	if def == null or def.has_class(&"animal") or e.intents[slot] != EntityStore.Intent.NONE:
		return false
	return true


func _douse() -> void:
	var ids := dousers.keys()
	ids.sort()
	for id: int in ids:
		if not dousers.has(id):
			# Let go when the fire they were at went out earlier in this loop.
			continue
		var b := dousers[id]
		var e := entities
		var busy := e.target[id - 1] != EntityStore.NO_ID or economy.combat.is_fleeing(id)
		if not e.is_alive(id) or not burning.has(b) or busy:
			drop([id])
			continue
		if not _at(id, b, -1):
			continue
		doused[b] += 1
		if doused[b] >= rules.douse_ticks:
			_put_out(b)


func _put_out(b: int) -> void:
	burning.erase(b)
	doused.erase(b)
	var ids := dousers.keys()
	ids.sort()
	for id: int in ids:
		if dousers[id] == b:
			drop([id])
			if entities.is_alive(id):
				_stop.call(id)


func on_remove(id: int) -> void:
	drop([id])


func write_to(buf: StreamPeerBuffer) -> void:
	if not enabled():
		return
	for d: Dictionary in [burning, doused, wooden, arson, arson_ticks, dousers, tries]:
		var keys := d.keys()
		keys.sort()
		buf.put_32(keys.size())
		for k: int in keys:
			buf.put_32(k)
			buf.put_64(int(d[k]))
