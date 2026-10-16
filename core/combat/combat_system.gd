class_name CombatSystem
extends RefCounted
## Fights and morale (M4), run by Simulation every tick before movement. Integers only, units in
## ascending id order, randomness only from rng, so a fight plays out the same everywhere.
##
## A unit with a target walks up to it (melee reach or shooting range) and strikes every
## reload_ticks; arrows, bolts and javelins fly as projectiles and land a few ticks later.
## Damage follows Damage.compute(); every number comes from CombatRulesDef and UnitDef.
## Morale falls with lost HP, hits in the flank or rear, firearms and dying neighbours, and comes
## back out of combat. At 25 a unit wavers, at 0 it flees to the rally point (see Intent.FLEE).

## An idle unit looks for enemies every this many ticks (staggered by id), not every tick.
const SCAN_EVERY := 5
## A chasing unit re-plans its path to a moving target at most this often.
const REPATH_EVERY := 10
## A unit at zero morale checks every this many ticks whether it still has a reason to stand.
const MORALE_CHECK_EVERY := 10
const MORALE_SCALE := 1000
## Classes of a dismounted Prussian rider.
const DISMOUNTED_CLASSES: Array[StringName] = [&"infantry"]
const FOREST := &"t_forest"
const HILL := &"t_hill"

# Per-unit flags derived from the catalog (not state: rebuilt from type and dismount).
const F_INFANTRY := 1
const F_HERO := 2
const F_NEVER_FLEES := 4
const F_RANGED := 8
const F_JAVELIN := 16
const F_STEALTH := 32
const F_CHARGE := 64
const F_NO_PURSUIT := 128
const F_RETREAT := 256
const F_DISMOUNT := 512
const F_PASSIVE := 1024
const TAG_FLAGS: Dictionary[StringName, int] = {
	&"javelin": F_JAVELIN,
	&"forest_stealth": F_STEALTH,
	&"charge": F_CHARGE,
	&"no_pursuit": F_NO_PURSUIT,
	&"lithuanian_retreat": F_RETREAT,
	&"can_dismount": F_DISMOUNT,
}
## Units of these classes never start a fight on their own.
const PASSIVE_CLASSES: Array[StringName] = [&"peasant", &"civilian", &"spiritual", &"animal"]

var entities: EntityStore
var nav: NavGrid
var rng: SimRng
var rules: CombatRulesDef
## The tick being simulated (Simulation.tick at step()).
var tick := 0
## UnitDef and flags by entity slot (null def: a unit from a test without the catalog).
var defs: Array[UnitDef] = []
var flags := PackedInt32Array()
## Rally point of each player, fixed units; units without one flee to where they were created.
var rally: Dictionary[int, Vector2i] = {}

## Fog of war (set by Simulation): units only pick fights with enemies their side can see.
var vision: VisionSystem
## «Реликвия в строю» (M7, set by Simulation): `floor(slot) -> int`, the morale in points a unit
## cannot be brought below while it is above it (0 for none).
var morale_floor: Callable
## Called as on_kill.call(killer_player, victim_player) when a hit finishes a unit (M8 stats).
var on_kill: Callable
## Arrows, bolts and javelins in flight.
var shots := Projectiles.new()
## Who is near whom, refilled at the start of every step.
var buckets: UnitBuckets
## Units nobody may attack (M9: a mission's tithe collector and his escort).
var untouchable: Dictionary[int, bool] = {}

# Simulation callbacks (Callables do not keep the simulation alive, so no reference cycle).
var _walk: Callable
var _stop: Callable
var _remove: Callable
var _forest := -1
var _hill := -1
var _heroes := 0
## The widest hero aura so far, in cells.
var _aura_cells := 0
## Units killed this tick, buried after every hit has landed.
var _dying := PackedInt32Array()


## `walk(id, x, y)`, `stop(id)` and `remove(id)` are the simulation's unit movement calls.
func _init(
	p_entities: EntityStore,
	p_nav: NavGrid,
	p_rng: SimRng,
	p_rules: CombatRulesDef,
	walk: Callable,
	stop: Callable,
	remove: Callable
) -> void:
	entities = p_entities
	nav = p_nav
	rng = p_rng
	rules = p_rules
	_walk = walk
	_stop = stop
	_remove = remove
	_forest = nav.terrain_index(FOREST)
	_hill = nav.terrain_index(HILL)
	buckets = UnitBuckets.new(nav.width, nav.height)


func enabled() -> bool:
	return rules != null


## Called by Simulation right after a unit is created.
func on_spawn(id: int, def: UnitDef) -> void:
	defs.append(def)
	flags.append(_flags_for(def, false))
	if def == null or rules == null:
		return
	var e := entities
	var slot := id - 1
	if flags[slot] & F_HERO:
		_heroes += 1
		_aura_cells = maxi(_aura_cells, aura_radius(def))
	e.morale[slot] = 0 if flags[slot] & F_NEVER_FLEES else def.morale * MORALE_SCALE
	e.stance[slot] = (
		EntityStore.Stance.PASSIVE if flags[slot] & F_PASSIVE else EntityStore.Stance.AGGRESSIVE
	)


static func _flags_for(def: UnitDef, is_dismounted: bool) -> int:
	if def == null:
		return F_NEVER_FLEES | F_PASSIVE
	var f := 0
	var classes := DISMOUNTED_CLASSES if is_dismounted else def.classes
	if classes.has(&"infantry"):
		f |= F_INFANTRY
	if def.has_class(&"hero"):
		f |= F_HERO
	if (
		def.never_flees
		or def.has_class(&"spiritual")
		or def.has_class(&"creature")
		or def.has_class(&"hero")
	):
		f |= F_NEVER_FLEES
	if def.attack_range > 0:
		f |= F_RANGED
	for tag: StringName in TAG_FLAGS:
		if def.tags.has(tag):
			f |= TAG_FLAGS[tag]
	for cls in PASSIVE_CLASSES:
		if def.has_class(cls):
			f |= F_PASSIVE
	if def.damage <= 0:
		f |= F_PASSIVE
	return f


# --- orders --------------------------------------------------------------------------------


## Orders that are about fighting. `ids` are alive units of the command's player that obey.
func order(cmd: SimCommand, ids: PackedInt32Array) -> void:
	match cmd.kind:
		SimCommand.Kind.ATTACK:
			_order_attack(cmd.player, ids, cmd.target)
		SimCommand.Kind.STANCE:
			for id in ids:
				_set_stance(id, clampi(cmd.value, 0, EntityStore.Stance.PASSIVE))
		SimCommand.Kind.RETREAT:
			_order_retreat(cmd.player, ids)
		SimCommand.Kind.TURN:
			for id in ids:
				_order_turn(id, cmd.target)
		SimCommand.Kind.DISMOUNT:
			for id in ids:
				_toggle_dismount(id)
		SimCommand.Kind.RALLY:
			rally[cmd.player] = Vector2i(_clamp_x(cmd.x), _clamp_y(cmd.y))


## A plain move or stop drops the fight; an attack-move keeps fighting on the way.
func on_move_order(id: int, attack: bool) -> void:
	var e := entities
	var slot := id - 1
	_clear_target(slot)
	e.attack_move[slot] = 1 if attack else 0
	e.am_x[slot] = e.target_x[slot]
	e.am_y[slot] = e.target_y[slot]
	if e.intents[slot] == EntityStore.Intent.RETREAT:
		e.intents[slot] = EntityStore.Intent.NONE
		e.intent_ticks[slot] = 0


func on_stop_order(id: int) -> void:
	var slot := id - 1
	_clear_target(slot)
	entities.attack_move[slot] = 0


## True if the unit is fleeing and deaf to orders.
func is_fleeing(id: int) -> bool:
	return entities.intents[id - 1] == EntityStore.Intent.FLEE


## An attack order from outside combat (hunting: the economy sends peasants at animals).
func order_attack(player: int, ids: PackedInt32Array, enemy: int) -> void:
	_order_attack(player, ids, enemy)


## Units that took up other work (building, gathering, assaulting a building) drop their target.
func drop_targets(ids: PackedInt32Array) -> void:
	for id in ids:
		_clear_target(id - 1)
		entities.attack_move[id - 1] = 0


func _order_attack(player: int, ids: PackedInt32Array, enemy: int) -> void:
	var e := entities
	if not e.is_alive(enemy) or e.owners[enemy - 1] == player or _hidden_from(enemy - 1, player):
		return
	if untouchable.has(enemy):
		return
	for id in ids:
		var slot := id - 1
		if defs[slot] == null or defs[slot].damage <= 0:
			continue
		_end_retreat(slot)
		e.attack_move[slot] = 0
		e.target[slot] = enemy
		e.target_kind[slot] = EntityStore.TargetKind.ORDERED
		e.chase_x[slot] = e.pos_x[slot]
		e.chase_y[slot] = e.pos_y[slot]
		_stop.call(id)


func _set_stance(id: int, value: int) -> void:
	var e := entities
	var slot := id - 1
	e.stance[slot] = value
	e.post_x[slot] = e.pos_x[slot]
	e.post_y[slot] = e.pos_y[slot]
	if value == EntityStore.Stance.STAND and e.target_kind[slot] == EntityStore.TargetKind.AUTO:
		_clear_target(slot)
		if e.orders[slot] == EntityStore.Order.MOVE and e.attack_move[slot] == 0:
			_stop.call(id)


## «Литовский отход»: the group turns and rides retreat_cells toward its rally point, faster and
## without losing morale for a while; «Разворот» may follow within turn_window_ticks.
func _order_retreat(player: int, ids: PackedInt32Array) -> void:
	var e := entities
	var ready := PackedInt32Array()
	var sum_x := 0
	var sum_y := 0
	for id in ids:
		var slot := id - 1
		if flags[slot] & F_RETREAT and e.retreat_cd[slot] == 0:
			ready.append(id)
			sum_x += e.pos_x[slot]
			sum_y += e.pos_y[slot]
	if ready.is_empty():
		return
	var cx := Fixed.floor_div(sum_x, ready.size())
	var cy := Fixed.floor_div(sum_y, ready.size())
	var goal := _rally_of(player, ready[0] - 1)
	var dx := goal.x - cx
	var dy := goal.y - cy
	var d := Fixed.isqrt(dx * dx + dy * dy)
	if d < Fixed.ONE:
		# Already at the rally point: ride away from where the first unit faces.
		dx = -e.facing_x[ready[0] - 1]
		dy = -e.facing_y[ready[0] - 1]
		d = Fixed.ONE
	var off_x := dx * Fixed.from_cells(rules.retreat_cells) / d
	var off_y := dy * Fixed.from_cells(rules.retreat_cells) / d
	for id in ready:
		var slot := id - 1
		_clear_target(slot)
		e.attack_move[slot] = 0
		e.intents[slot] = EntityStore.Intent.RETREAT
		e.intent_ticks[slot] = rules.retreat_fearless_ticks
		e.retreat_cd[slot] = rules.retreat_cooldown_ticks
		e.turn_ticks[slot] = rules.turn_window_ticks
		e.turn_bonus[slot] = 0
		_walk.call(id, _clamp_x(e.pos_x[slot] + off_x), _clamp_y(e.pos_y[slot] + off_y))


## «Разворот»: within the window after a retreat, turn on the enemy (the given one or the
## nearest) with +turn_damage_bonus and a ×turn_charge_permille charge on the next hit. The
## bonus waits up to turn_window_ticks for that hit; one turn per retreat.
func _order_turn(id: int, enemy: int) -> void:
	var e := entities
	var slot := id - 1
	if e.turn_ticks[slot] == 0 or e.turn_bonus[slot] == 1:
		return
	_end_retreat(slot)
	e.turn_bonus[slot] = 1
	e.turn_ticks[slot] = rules.turn_window_ticks
	e.attack_move[slot] = 0
	var owner := e.owners[slot]
	if e.is_alive(enemy) and e.owners[enemy - 1] != owner and not _hidden_from(enemy - 1, owner):
		e.target[slot] = enemy
		e.target_kind[slot] = EntityStore.TargetKind.ORDERED
	else:
		_acquire(slot, _sight(slot))
	e.chase_x[slot] = e.pos_x[slot]
	e.chase_y[slot] = e.pos_y[slot]


func _toggle_dismount(id: int) -> void:
	var e := entities
	var slot := id - 1
	var def := defs[slot]
	if not flags[slot] & F_DISMOUNT:
		return
	var down := e.dismounted[slot] == 0
	e.dismounted[slot] = 1 if down else 0
	flags[slot] = _flags_for(def, down)
	var speed_milli := rules.dismount_speed_milli if down else def.speed_milli
	e.speed[slot] = Fixed.speed_per_tick(speed_milli)
	e.move_class[slot] = NavGrid.MoveClass.FOOT if down else NavGrid.move_class_for(def)
	_stop.call(id)


func _end_retreat(slot: int) -> void:
	var e := entities
	if e.intents[slot] == EntityStore.Intent.RETREAT:
		e.intents[slot] = EntityStore.Intent.NONE
		e.intent_ticks[slot] = 0


func _clear_target(slot: int) -> void:
	entities.target[slot] = EntityStore.NO_ID
	entities.target_kind[slot] = EntityStore.TargetKind.NONE


func _clamp_x(x: int) -> int:
	return clampi(x, 0, Fixed.from_cells(nav.width) - 1)


func _clamp_y(y: int) -> int:
	return clampi(y, 0, Fixed.from_cells(nav.height) - 1)


func _rally_of(player: int, slot: int) -> Vector2i:
	if rally.has(player):
		return rally[player]
	return Vector2i(entities.home_x[slot], entities.home_y[slot])


# --- the combat step -----------------------------------------------------------------------


## Timers, targets and strikes, landing projectiles, burying the dead, morale. Before movement.
func step(at_tick: int) -> void:
	tick = at_tick
	if rules == null:
		return
	buckets.fill(entities)
	var e := entities
	for id in e.alive_ids:
		_count_down(id - 1)
	for id in e.alive_ids:
		_think(id)
	_land_shots()
	_bury_dead()
	for id in e.alive_ids:
		_morale_tick(id)


## After movement: a unit that stood still this tick has lost its run-up.
func after_move() -> void:
	if rules == null:
		return
	var e := entities
	for id in e.alive_ids:
		var slot := id - 1
		if e.moved[slot] == 0:
			e.run[slot] = 0
		e.moved[slot] = 0


func _count_down(slot: int) -> void:
	var e := entities
	if e.cooldown[slot] > 0:
		e.cooldown[slot] -= 1
	if e.javelin_cd[slot] > 0:
		e.javelin_cd[slot] -= 1
	if e.retreat_cd[slot] > 0:
		e.retreat_cd[slot] -= 1
	if e.disorder[slot] > 0:
		e.disorder[slot] -= 1
	if e.reveal[slot] > 0:
		e.reveal[slot] -= 1
	if e.turn_ticks[slot] > 0:
		e.turn_ticks[slot] -= 1
		if e.turn_ticks[slot] == 0:
			e.turn_bonus[slot] = 0


func _think(id: int) -> void:
	var e := entities
	var slot := id - 1
	if defs[slot] == null:
		return
	match e.intents[slot]:
		EntityStore.Intent.FLEE:
			e.intent_ticks[slot] -= 1
			if e.intent_ticks[slot] <= 0:
				e.intents[slot] = EntityStore.Intent.NONE
				_stop.call(id)
			return
		EntityStore.Intent.RETREAT:
			e.intent_ticks[slot] -= 1
			if e.intent_ticks[slot] <= 0:
				e.intents[slot] = EntityStore.Intent.NONE
			return
	if e.target[slot] != EntityStore.NO_ID and not _target_valid(slot):
		_drop_target(id)
	if e.target[slot] == EntityStore.NO_ID:
		if _may_look(slot) and (tick + id) % SCAN_EVERY == 0:
			_acquire(slot, _sight(slot))
			if e.target[slot] != EntityStore.NO_ID and e.attack_move[slot] == 0:
				e.post_x[slot] = e.pos_x[slot]
				e.post_y[slot] = e.pos_y[slot]
		if e.target[slot] == EntityStore.NO_ID:
			if e.attack_move[slot] == 1 and e.orders[slot] == EntityStore.Order.IDLE:
				e.attack_move[slot] = 0
			return
	_engage(id)


## Whether the unit looks for a fight by itself now: not passive, not on a plain move.
func _may_look(slot: int) -> bool:
	var e := entities
	if e.stance[slot] == EntityStore.Stance.PASSIVE or e.intents[slot] != EntityStore.Intent.NONE:
		return false
	return e.orders[slot] == EntityStore.Order.IDLE or e.attack_move[slot] == 1


func _target_valid(slot: int) -> bool:
	var e := entities
	var t := e.target[slot] - 1
	if not e.is_alive(t + 1) or e.hp[t] <= 0 or _hidden_from(t, e.owners[slot]):
		return false
	if untouchable.has(t + 1):
		return false
	if e.target_kind[slot] == EntityStore.TargetKind.ORDERED:
		return true
	var px := e.pos_x[slot]
	var py := e.pos_y[slot]
	var ok := true
	if e.intents[t] == EntityStore.Intent.FLEE:
		var chased := Fixed.distance(e.chase_x[slot], e.chase_y[slot], px, py)
		var pursues := flags[slot] & F_NO_PURSUIT == 0
		ok = pursues and chased <= Fixed.from_cells(rules.pursuit_cells)
	match e.stance[slot]:
		EntityStore.Stance.DEFENSIVE:
			var away := Fixed.distance(e.post_x[slot], e.post_y[slot], px, py)
			ok = ok and away <= Fixed.from_cells(rules.defensive_leash_cells)
		EntityStore.Stance.STAND:
			ok = ok and Fixed.distance(px, py, e.pos_x[t], e.pos_y[t]) <= _reach(slot)
	return ok


## Gives up the target: an attack-move walks on, a defender goes back to its post, others stop.
func _drop_target(id: int) -> void:
	var e := entities
	var slot := id - 1
	var was_auto := e.target_kind[slot] == EntityStore.TargetKind.AUTO
	_clear_target(slot)
	if e.attack_move[slot] == 1:
		_walk.call(id, e.am_x[slot], e.am_y[slot])
	elif was_auto and e.stance[slot] == EntityStore.Stance.DEFENSIVE:
		_walk.call(id, e.post_x[slot], e.post_y[slot])
	elif e.orders[slot] == EntityStore.Order.MOVE:
		_stop.call(id)


## Picks the nearest enemy it can see within `radius` (fixed units). Fleeing enemies are left
## alone unless they are within reach.
func _acquire(slot: int, radius: int) -> void:
	var e := entities
	var found := _nearest_enemy(slot, radius)
	if found == EntityStore.NO_ID:
		return
	e.target[slot] = found
	e.target_kind[slot] = EntityStore.TargetKind.AUTO
	e.chase_x[slot] = e.pos_x[slot]
	e.chase_y[slot] = e.pos_y[slot]


## Walks into reach of the target, then strikes when the weapon is ready.
func _engage(id: int) -> void:
	var e := entities
	var slot := id - 1
	var t := e.target[slot] - 1
	var def := defs[slot]
	var dx := e.pos_x[t] - e.pos_x[slot]
	var dy := e.pos_y[t] - e.pos_y[slot]
	var dist := Fixed.isqrt(dx * dx + dy * dy)
	if e.intents[t] == EntityStore.Intent.RETREAT and e.disorder[slot] == 0:
		e.disorder[slot] = rules.retreat_disorder_ticks
	if flags[slot] & F_JAVELIN and e.javelin_cd[slot] == 0:
		if dist <= Fixed.from_cells(def.param(&"javelin_range")):
			_throw_javelin(slot, t, dist)
	if dist <= _reach(slot) and dist >= Fixed.from_cells(def.min_range):
		if e.orders[slot] == EntityStore.Order.MOVE:
			_stop.call(id)
		_face(slot, dx, dy, dist)
		if e.cooldown[slot] == 0:
			if flags[slot] & F_RANGED:
				_shoot(slot, t, dist)
			else:
				_strike(slot, t)
			e.cooldown[slot] = maxi(def.reload_ticks, 1)
		return
	if e.stance[slot] == EntityStore.Stance.STAND:
		if e.target_kind[slot] != EntityStore.TargetKind.ORDERED:
			return
	var drift := Fixed.distance(e.target_x[slot], e.target_y[slot], e.pos_x[t], e.pos_y[t])
	if e.orders[slot] == EntityStore.Order.IDLE:
		_walk.call(id, e.pos_x[t], e.pos_y[t])
	elif (tick + id) % REPATH_EVERY == 0 and drift > Fixed.ONE:
		_walk.call(id, e.pos_x[t], e.pos_y[t])


func _face(slot: int, dx: int, dy: int, dist: int) -> void:
	if dist == 0:
		return
	entities.facing_x[slot] = dx * Fixed.ONE / dist
	entities.facing_y[slot] = dy * Fixed.ONE / dist


# --- hits ----------------------------------------------------------------------------------


func _strike(slot: int, t: int) -> void:
	var e := entities
	var def := defs[slot]
	var hit := _hit_from(slot, t, def.damage, def.damage_type)
	if flags[slot] & F_CHARGE:
		var run_up := def.param(&"charge_distance", rules.charge_distance_default)
		if e.run[slot] >= Fixed.from_cells(run_up):
			hit.multipliers.append(def.param(&"charge_permille", 1000))
	if e.turn_bonus[slot] == 1:
		hit.multipliers.append(rules.turn_charge_permille)
	e.run[slot] = 0
	_use_turn_bonus(slot)
	var dmg := Damage.compute(hit, rules)
	e.last_attack[slot] = tick
	_apply_hit(slot + 1, e.owners[slot], t, dmg, hit.side, def.damage_type, false)


## A Hit against target slot t with the attacker's bonuses, wavering and «Разворот» damage.
## Armor is the target's now; the side is seen from where the attacker stands.
func _hit_from(slot: int, t: int, damage: int, damage_type: StringName) -> Damage.Hit:
	var e := entities
	var hit := Damage.Hit.new()
	hit.damage = damage + (rules.turn_damage_bonus if e.turn_bonus[slot] == 1 else 0)
	if damage_type == defs[slot].damage_type:
		hit.damage += e.up_damage[slot]
	hit.damage_type = damage_type
	hit.bonus = Damage.bonus_against(defs[slot].bonuses, _classes(t))
	hit.armor_melee = _armor_melee(t)
	hit.armor_pierce = _armor_pierce(t)
	hit.side = _side(t, e.pos_x[slot], e.pos_y[slot])
	if wavering(slot):
		hit.multipliers.append(rules.waver_damage_permille)
	return hit


## The «Разворот» bonus goes with the first hit, and with it the chance to turn again.
func _use_turn_bonus(slot: int) -> void:
	if entities.turn_bonus[slot] == 1:
		entities.turn_bonus[slot] = 0
		entities.turn_ticks[slot] = 0


func _side(t: int, from_x: int, from_y: int) -> int:
	var e := entities
	var dx := from_x - e.pos_x[t]
	var dy := from_y - e.pos_y[t]
	return Damage.side_of(dx, dy, e.facing_x[t], e.facing_y[t])


func _shoot(slot: int, t: int, dist: int) -> void:
	var def := defs[slot]
	var hit := _hit_from(slot, t, def.damage, def.damage_type)
	if flags[slot] & F_STEALTH:
		entities.reveal[slot] = rules.stealth_reveal_ticks
	entities.last_attack[slot] = tick
	_use_turn_bonus(slot)
	var cannon := def.has_class(&"siege") and def.damage_type == Damage.FIREARM
	_launch(slot, t, dist, hit, cannon)


## Сулица: a javelin thrown at the target on its own cooldown, besides the melee strikes.
## It is not the lance: no class bonuses and no «Разворот» damage.
func _throw_javelin(slot: int, t: int, dist: int) -> void:
	var def := defs[slot]
	var hit := _hit_from(slot, t, def.param(&"javelin_damage"), Damage.PIERCE)
	hit.damage = def.param(&"javelin_damage")
	hit.bonus = 0
	_launch(slot, t, dist, hit, false)
	entities.javelin_cd[slot] = maxi(def.param(&"javelin_cooldown_ticks"), 1)
	entities.last_attack[slot] = tick


## Sends the shot off. A target standing in the forest is missed forest_miss_permille of the time
## (decided now, from the simulation's generator).
func _launch(slot: int, t: int, dist: int, hit: Damage.Hit, cannon: bool) -> void:
	var mult := 1000
	for m in hit.multipliers:
		mult = mult * m / 1000
	var shot_flags := Projectiles.CANNON if cannon else 0
	if _lost_in_forest(t):
		shot_flags |= Projectiles.MISS
	var e := entities
	_send_shot(
		slot + 1, e.owners[slot], e.pos_x[slot], e.pos_y[slot], t, dist, hit, mult, shot_flags
	)


## A tower's arrow (TowerFire): from (sx, sy) at unit slot t, no class bonus; the shooter is
## minus the building id `b`.
func tower_shot(
	b: int, owner: int, sx: int, sy: int, t: int, damage: int, kind: StringName
) -> void:
	var hit := Damage.Hit.new()
	hit.damage = damage
	hit.damage_type = kind
	hit.side = _side(t, sx, sy)
	var shot_flags := Projectiles.MISS if _lost_in_forest(t) else 0
	var dist := Fixed.distance(sx, sy, entities.pos_x[t], entities.pos_y[t])
	_send_shot(-b, owner, sx, sy, t, dist, hit, 1000, shot_flags)


## Puts a shot in the air from (sx, sy) at unit slot t, `dist` away; flight time in whole
## ticks, rounded up.
func _send_shot(
	shooter: int,
	owner: int,
	sx: int,
	sy: int,
	t: int,
	dist: int,
	hit: Damage.Hit,
	mult: int,
	shot_flags: int
) -> void:
	var per_second := rules.projectile_speed_milli * Fixed.ONE
	var flight := maxi(1, (dist * 1000 * Fixed.TICKS_PER_SECOND + per_second - 1) / per_second)
	shots.launch(shooter, owner, t + 1, sx, sy, tick, flight, hit, mult, shot_flags)


func _lost_in_forest(t: int) -> bool:
	return _in_terrain(t, _forest) and rng.chance_permille(rules.forest_miss_permille)


func _land_shots() -> void:
	var e := entities
	for i in shots.landing(tick):
		var t := shots.target[i] - 1
		if shots.flags[i] & Projectiles.MISS or not e.is_alive(t + 1) or e.hp[t] <= 0:
			continue
		var hit := shots.hit_of(i)
		hit.armor_melee = _armor_melee(t)
		hit.armor_pierce = _armor_pierce(t)
		var dmg := Damage.compute(hit, rules)
		var cannon := shots.flags[i] & Projectiles.CANNON != 0
		_apply_hit(shots.from[i], shots.owner[i], t, dmg, hit.side, hit.damage_type, cannon)
	shots.drop_landed(tick)


## Damage, morale and retaliation for one landed hit on target slot t.
func _apply_hit(
	attacker: int, attacker_owner: int, t: int, dmg: int, side: int, kind: StringName, cannon: bool
) -> void:
	var e := entities
	var was_alive := e.hp[t] > 0
	e.hp[t] -= dmg
	e.calm[t] = 0
	if e.is_alive(attacker):
		e.calm[attacker - 1] = 0
	if e.hp[t] <= 0:
		_dying.append(t + 1)
		if was_alive and on_kill.is_valid():
			on_kill.call(attacker_owner, e.owners[t])
	var loss := 0
	var tenths := (e.max_hp[t] - maxi(e.hp[t], 0)) * 10 / maxi(e.max_hp[t], 1)
	if tenths > e.lost_tenths[t]:
		loss += (tenths - e.lost_tenths[t]) * rules.morale_per_tenth_hp
		e.lost_tenths[t] = mini(tenths, 10)
	if side == Damage.Side.FLANK:
		loss += rules.flank_hit_morale
	elif side == Damage.Side.REAR:
		loss += rules.rear_hit_morale
	if kind == Damage.FIREARM and not cannon:
		loss += rules.firearm_hit_morale
	lose_morale(t, loss)
	if cannon:
		_cannon_volley(t)
	if (
		e.hp[t] > 0
		and e.target[t] == EntityStore.NO_ID
		and _may_look(t)
		and e.is_alive(attacker)
		and e.owners[attacker - 1] == attacker_owner
		and not _hidden_from(attacker - 1, e.owners[t])
	):
		e.target[t] = attacker
		e.target_kind[t] = EntityStore.TargetKind.AUTO
		e.chase_x[t] = e.pos_x[t]
		e.chase_y[t] = e.pos_y[t]
		if e.attack_move[t] == 0:
			e.post_x[t] = e.pos_x[t]
			e.post_y[t] = e.pos_y[t]


## Units of the hit unit's side within cannon_volley_radius of it lose cannon_volley_morale.
func _cannon_volley(t: int) -> void:
	var e := entities
	var r := Fixed.from_cells(rules.cannon_volley_radius)
	for other in buckets.near(e.pos_x[t], e.pos_y[t], r):
		if e.owners[other - 1] == e.owners[t] and e.hp[other - 1] > 0:
			lose_morale(other - 1, rules.cannon_volley_morale)


func _bury_dead() -> void:
	if _dying.is_empty():
		return
	var e := entities
	_dying.sort()
	var r := Fixed.from_milli(rules.neighbour_radius_milli)
	for id in _dying:
		if not e.is_alive(id):
			continue
		var slot := id - 1
		if flags[slot] & F_HERO:
			_heroes -= 1
		for other in buckets.near(e.pos_x[slot], e.pos_y[slot], r):
			var o := other - 1
			if other != id and e.owners[o] == e.owners[slot] and e.hp[o] > 0:
				lose_morale(o, rules.neighbour_death_morale)
		_remove.call(id)
	_dying.clear()


# --- morale --------------------------------------------------------------------------------


## Takes `points` of morale (catalog points) unless the unit never flees or is in the fearless
## part of a «Литовский отход»; a unit with nothing left to hold it flees.
func lose_morale(slot: int, points: int) -> void:
	var e := entities
	if points <= 0 or flags[slot] & F_NEVER_FLEES or defs[slot] == null:
		return
	if e.intents[slot] == EntityStore.Intent.RETREAT:
		return
	var lowest := 0
	if morale_floor.is_valid():
		var floor_points: int = morale_floor.call(slot)
		if e.morale[slot] > floor_points * MORALE_SCALE:
			lowest = floor_points * MORALE_SCALE
	e.morale[slot] = maxi(lowest, e.morale[slot] - points * MORALE_SCALE)
	if e.morale[slot] == 0 and e.intents[slot] == EntityStore.Intent.NONE:
		if morale_bonus(slot) <= 0:
			_flee(slot)


## Morale in catalog points with every bonus around the unit (hero aura, close order).
func effective_morale(slot: int) -> int:
	return entities.morale[slot] / MORALE_SCALE + morale_bonus(slot)


func morale_bonus(slot: int) -> int:
	var e := entities
	var bonus := 0
	var owner := e.owners[slot]
	var px := e.pos_x[slot]
	var py := e.pos_y[slot]
	if _heroes > 0:
		bonus += _aura_at(slot, owner, px, py)
	if flags[slot] & F_INFANTRY:
		var r := Fixed.from_milli(rules.formation_radius_milli)
		var n := 0
		for other in buckets.near(px, py, r):
			var o := other - 1
			if o != slot and flags[o] & F_INFANTRY and e.owners[o] == owner:
				n += 1
		if n >= rules.formation_neighbours:
			bonus += rules.formation_morale
	return bonus


## The strongest aura of an own hero around the unit (its own aura_radius and aura_morale from
## the hero template, M9; the general hero rule otherwise).
func _aura_at(slot: int, owner: int, px: int, py: int) -> int:
	var e := entities
	var best := 0
	for other in buckets.near(px, py, Fixed.from_cells(_aura_cells)):
		var o := other - 1
		if o == slot or not flags[o] & F_HERO or e.owners[o] != owner:
			continue
		var r := Fixed.from_cells(aura_radius(defs[o]))
		var dx := e.pos_x[o] - px
		var dy := e.pos_y[o] - py
		if dx * dx + dy * dy <= r * r:
			best = maxi(best, defs[o].param(&"aura_morale", rules.hero_aura_morale))
	return best


func aura_radius(def: UnitDef) -> int:
	return def.param(&"aura_radius", rules.hero_aura_radius)


## At or below waver_morale (with bonuses) a unit hits 20% weaker. Units that never flee do not.
func wavering(slot: int) -> bool:
	if flags[slot] & F_NEVER_FLEES or defs[slot] == null:
		return false
	var e := entities
	if e.morale[slot] > rules.waver_morale * MORALE_SCALE:
		return false
	return effective_morale(slot) <= rules.waver_morale


## Sends a unit running to its rally point even if it never flees (a creature hit by
## «Экзорцизм»).
func drive_off(id: int) -> void:
	if entities.is_alive(id) and defs[id - 1] != null and rules != null:
		_flee(id - 1)


func _flee(slot: int) -> void:
	var e := entities
	var id := slot + 1
	_clear_target(slot)
	e.attack_move[slot] = 0
	e.intents[slot] = EntityStore.Intent.FLEE
	e.intent_ticks[slot] = rules.flee_ticks
	var goal := _rally_of(e.owners[slot], slot)
	_walk.call(id, goal.x, goal.y)
	# Whoever was fighting it starts a chase from where it stands (pursuit_cells at most).
	for other in e.alive_ids:
		var o := other - 1
		if e.target[o] == id:
			e.chase_x[o] = e.pos_x[o]
			e.chase_y[o] = e.pos_y[o]


func _morale_tick(id: int) -> void:
	var e := entities
	var slot := id - 1
	if flags[slot] & F_NEVER_FLEES:
		return
	if e.calm[slot] < rules.out_of_combat_ticks:
		e.calm[slot] += 1
	else:
		var full := defs[slot].morale * MORALE_SCALE
		var per_tick := rules.morale_recovery_per_second * MORALE_SCALE / Fixed.TICKS_PER_SECOND
		e.morale[slot] = mini(full, e.morale[slot] + per_tick)
	if (
		e.morale[slot] == 0
		and e.intents[slot] == EntityStore.Intent.NONE
		and (tick + id) % MORALE_CHECK_EVERY == 0
		and morale_bonus(slot) <= 0
	):
		_flee(slot)


# --- what a unit is now ---------------------------------------------------------------------


func _classes(t: int) -> Array[StringName]:
	if entities.dismounted[t] == 1:
		return DISMOUNTED_CLASSES
	return defs[t].classes if defs[t] != null else DISMOUNTED_CLASSES


func _armor_melee(t: int) -> int:
	var def := defs[t]
	if def == null:
		return 0
	var e := entities
	var a := def.armor_melee + e.up_armor_m[t]
	if _in_terrain(t, _forest):
		a += def.param(&"forest_armor_melee")
	if e.dismounted[t] == 1:
		a += def.param(&"dismount_armor_melee")
	if e.disorder[t] > 0:
		a -= rules.retreat_disorder_armor
	return a


func _armor_pierce(t: int) -> int:
	var def := defs[t]
	if def == null:
		return 0
	var a := def.armor_pierce + entities.up_armor_p[t]
	if _in_terrain(t, _forest):
		a += def.param(&"forest_armor_pierce")
	if entities.dismounted[t] == 1:
		a += def.param(&"dismount_armor_pierce")
	return a


## Striking distance in fixed units: melee reach, or range with the hill and forest bonuses.
func _reach(slot: int) -> int:
	var def := defs[slot]
	if not flags[slot] & F_RANGED:
		return Fixed.from_milli(rules.melee_reach_milli)
	var cells := def.attack_range + entities.up_range[slot]
	if _in_terrain(slot, _hill):
		cells += rules.hill_range_bonus
	if _in_terrain(slot, _forest):
		cells += def.param(&"forest_range_bonus")
	return Fixed.from_cells(cells)


## How far the unit notices enemies: its «обзор» (or sight_default), at least its reach; a unit
## standing its ground only looks as far as it can strike.
func _sight(slot: int) -> int:
	var reach := _reach(slot)
	if entities.stance[slot] == EntityStore.Stance.STAND:
		return reach
	var cells := defs[slot].param(&"sight", rules.sight_default)
	return maxi(Fixed.from_cells(cells), reach)


func _in_terrain(slot: int, terrain_index: int) -> bool:
	if terrain_index < 0:
		return false
	var e := entities
	return nav.terrain[nav.cell_of(e.pos_x[slot], e.pos_y[slot])] == terrain_index


## A forest archer in the forest is invisible to the other side until it shoots.
func _hidden_from(slot: int, viewer: int) -> bool:
	var e := entities
	if not flags[slot] & F_STEALTH or e.owners[slot] == viewer or e.reveal[slot] > 0:
		return false
	return _in_terrain(slot, _forest)


## True while the unit is a hidden forest archer (for drawing it see-through to its owner).
func is_hidden(id: int) -> bool:
	return _hidden_from(id - 1, -1)


# --- who is near ----------------------------------------------------------------------------


func _nearest_enemy(slot: int, radius: int) -> int:
	var e := entities
	var owner := e.owners[slot]
	var px := e.pos_x[slot]
	var py := e.pos_y[slot]
	var reach := _reach(slot)
	var best := EntityStore.NO_ID
	var best_d := 0
	for other in buckets.near(px, py, radius):
		var o := other - 1
		if e.owners[o] == owner or e.owners[o] == 0 or e.hp[o] <= 0 or defs[o] == null:
			continue
		if untouchable.has(other) or defs[o].tags.has(&"not_targeted"):
			continue
		if _hidden_from(o, owner) or (vision != null and not vision.sees_unit(owner, other)):
			continue
		var d := Fixed.distance(px, py, e.pos_x[o], e.pos_y[o])
		if e.intents[o] == EntityStore.Intent.FLEE and (d > reach or flags[slot] & F_NO_PURSUIT):
			continue
		if best == EntityStore.NO_ID or d < best_d or (d == best_d and other < best):
			best = other
			best_d = d
	return best


# --- state ----------------------------------------------------------------------------------


func write_to(buf: StreamPeerBuffer) -> void:
	var players := rally.keys()
	players.sort()
	buf.put_32(players.size())
	for p: int in players:
		buf.put_32(p)
		buf.put_64(rally[p].x)
		buf.put_64(rally[p].y)
	shots.write_to(buf)
	var guarded := untouchable.keys()
	guarded.sort()
	buf.put_32(guarded.size())
	for id: int in guarded:
		buf.put_32(id)
