class_name MagicSystem
extends RefCounted
## Сила and magic (M7), run by Simulation every tick after the economy, before movement.
## Integers and ascending ids only, so it plays out the same everywhere.
##
## Places of power and the Сила they give live in PowerPlaces. Spells are cast with the CAST
## command by a unit the SpellDef names as a caster, in the spell's age, off cooldown, paying
## its Сила (power_cost). How a spell is aimed and what it does come from its tags
## (manual.json → spell_effects):
##   target_point: lands on a point within MagicRulesDef.cast_range of the caster, who walks
##     there first; target_self: around the caster and moving with it;
##   mist («Болотный туман»): the caster's units and buildings in it are hidden from others
##     beyond VisionRulesDef.cover_reveal_cells, a unit until it attacks (MistField);
##   relic («Реликвия в строю»): the caster's units near it do not fall below relic_morale_floor
##     morale while above it; others' units coming near lose relic_enemy_morale once;
##   icon («Икона перед войском»): like a relic carried by the caster, the caster's units near it
##     do not fall below icon_morale_floor percent of their full morale (nobody else is shaken);
##   dispel («Экзорцизм»): others' spell effects touching its circle end; others' creatures in
##     it lose exorcism_creature_damage HP and are driven off;
##   storm («Гнев Перкуна»): storm_strikes lightning bolts of storm_damage HP hit the heaviest
##     (most max HP) enemy units under it at once; while it lasts, the rain keeps every bow,
##     crossbow and gun under it from shooting;
##   wolf_path («Волчья тропа»): an effect where the caster stands, for the spell's duration; the
##     mission opens the trail of the place of power there (MissionStealth);
##   hymn («Богородица»): carried by the caster, own units near it get hymn_morale and those
##     fleeing turn back to fight;
##   blessing («Благословение хоругви», single_target): the own unit nearest the point gets
##     blessing_armor to both armors and blessing_morale while it lasts;
##   pact («Договор»): carried by the caster, own units near it lose no morale and strike for
##     pact_damage_permille.
## A tech may make a spell cheaper («sp_bogurodzica.cost_permille»).
## A spell tagged hero_at_power_place («герой у места силы») may also be cast by a hero of the
## spell's faction standing within capture_radius of a place of power nobody hides.
## Cooldowns run per caster and spell; casters near their own building tagged spell_recharge
## (the alka) recharge alka_recharge_permille faster. Healers («лечит N HP/с в радиусе R»)
## heal their side's units around them once a second.

## Why a spell cannot be cast now.
enum Cast {
	OK, NO_PLAYER, UNKNOWN, NOT_CASTER, AGE, PASSIVE, NOT_READY, COOLDOWN, POWER, NOT_AT_PLACE
}

## PlayerState.power per point of Сила: thousandths of a point times ticks per second, so a
## shrine adds its rate in thousandths a second every tick without rounding.
const POWER_UNIT := 1000 * Fixed.TICKS_PER_SECOND
## Cooldowns count down in thousandths of a tick (the alka speeds them up by a share).
const COOLDOWN_SCALE := 1000
const HEAL_EVERY := Fixed.TICKS_PER_SECOND
## Key of per-caster maps: unit id * SPELL_SLOTS + spell index.
const SPELL_SLOTS := 64
## Key of a unit touched by a relic: effect id * RELIC_KEY + unit id.
const RELIC_KEY := 1 << 24

var entities: EntityStore
var nav: NavGrid
var db: CatalogDB
var rules: MagicRulesDef
var players: Dictionary[int, PlayerState]
var buildings: BuildingStore
var combat: CombatSystem
var places: PowerPlaces
## Where mists lie, for the fog of war (VisionSystem.mist).
var mist := MistField.new()
var tick := 0

## Spells by index (ids sorted as text) and the index of each id.
var spells: Array[SpellDef] = []
var spell_index: Dictionary[StringName, int] = {}

## Spell effects in the world, by effect id ascending: spell index, owner, caster (0 when the
## effect stays where it landed), centre (fixed), radius (cells), first and end tick.
var fx_ids := PackedInt32Array()
var fx_spell := PackedInt32Array()
var fx_owner := PackedInt32Array()
var fx_caster := PackedInt32Array()
var fx_x := PackedInt64Array()
var fx_y := PackedInt64Array()
var fx_radius := PackedInt32Array()
var fx_from := PackedInt32Array()
var fx_until := PackedInt32Array()
var _next_fx := 1

## Cooldown left (thousandths of a tick) per caster and spell (key id * SPELL_SLOTS + spell).
var _cooldown: Dictionary[int, int] = {}
## A cast waiting for its caster to walk into range: caster id -> (spell index, x, y).
var _pending: Dictionary[int, Vector3i] = {}
## Units a relic has already shaken (key effect id * RELIC_KEY + unit id).
var _relic_hit: Dictionary[int, bool] = {}
## Per unit slot: HP a second it heals around it, and how far (cells); 0 for non-healers.
var _heal := PackedInt32Array()
var _heal_radius := PackedInt32Array()

var _walk: Callable
var _stop: Callable
var _remove: Callable


## `walk(id, x, y)`, `stop(id)` and `remove(id)` are the simulation's unit calls.
func _init(
	p_entities: EntityStore,
	p_nav: NavGrid,
	p_db: CatalogDB,
	economy: EconomySystem,
	p_combat: CombatSystem,
	walk: Callable,
	stop: Callable,
	remove: Callable
) -> void:
	entities = p_entities
	nav = p_nav
	db = p_db
	rules = db.magic if db != null else null
	players = economy.players
	buildings = economy.buildings
	combat = p_combat
	_walk = walk
	_stop = stop
	_remove = remove
	places = PowerPlaces.new(entities, nav, economy, rules, db, combat.buckets)
	if rules != null:
		economy.placement.places = places
	if db == null:
		return
	var ids := PackedStringArray(db.spells.keys())
	ids.sort()
	for id in ids:
		spell_index[StringName(id)] = spells.size()
		spells.append(db.spell(StringName(id)))


func enabled() -> bool:
	return rules != null


func on_spawn(id: int, def: UnitDef) -> void:
	var slot := id - 1
	while _heal.size() <= slot:
		_heal.append(0)
		_heal_radius.append(0)
	if def != null:
		_heal[slot] = def.param(&"heal_hp_per_s")
		_heal_radius[slot] = def.param(&"heal_radius")
		if _heal[slot] > 0 and _heal_radius[slot] <= 0 and rules != null:
			_heal_radius[slot] = rules.heal_radius_default


## Plain orders (move, stop, attack, work) call off casts waiting for the caster to walk up.
func drop_casts(ids: PackedInt32Array) -> void:
	for id in ids:
		_pending.erase(id)


# --- casting -------------------------------------------------------------------------------


## CAST: of the command's units that may cast the spell now, the one nearest the point casts
## (ties to the lower id); for a point out of its range it walks there first.
func order(cmd: SimCommand, ids: PackedInt32Array) -> void:
	if not enabled() or not spell_index.has(cmd.type_id):
		return
	var spell := spells[spell_index[cmd.type_id]]
	var x := clampi(cmd.x, 0, Fixed.from_cells(nav.width) - 1)
	var y := clampi(cmd.y, 0, Fixed.from_cells(nav.height) - 1)
	var best := EntityStore.NO_ID
	var best_d := 0
	for id in ids:
		if can_cast(cmd.player, id, spell.id) != Cast.OK:
			continue
		var d := Fixed.distance(entities.pos_x[id - 1], entities.pos_y[id - 1], x, y)
		if spell.tags.has(&"target_self"):
			d = 0
		if best == EntityStore.NO_ID or d < best_d:
			best = id
			best_d = d
	if best == EntityStore.NO_ID:
		return
	if spell.tags.has(&"target_self") or best_d <= Fixed.from_cells(rules.cast_range):
		_cast(best, spell, x, y)
		return
	_pending[best] = Vector3i(spell_index[spell.id], x, y)
	_walk.call(best, x, y)


## Whether the unit may cast the spell now (Cast.OK), or why not.
func can_cast(p: int, id: int, spell_id: StringName) -> Cast:
	var state: PlayerState = players.get(p)
	if state == null:
		return Cast.NO_PLAYER
	var fail := _caster_fail(p, id, spell_id)
	if fail != Cast.OK:
		return fail
	var spell := spells[spell_index[spell_id]]
	if state.age < spell.age:
		return Cast.AGE
	if cooldown_ticks(id, spell_id) > 0:
		return Cast.COOLDOWN
	if state.power < power_cost(p, spell) * POWER_UNIT:
		return Cast.POWER
	return Cast.OK


## Whether the unit is the player's own caster of a spell that can be cast at all.
func _caster_fail(p: int, id: int, spell_id: StringName) -> Cast:
	if not spell_index.has(spell_id) or not entities.is_alive(id):
		return Cast.UNKNOWN
	var spell := spells[spell_index[spell_id]]
	var fail := Cast.OK
	if entities.owners[id - 1] != p:
		fail = Cast.NOT_CASTER
	elif not spell.casters.has(entities.type_ids[id - 1]):
		if not _hero_of(id, spell):
			fail = Cast.NOT_CASTER
		elif not at_place(id):
			fail = Cast.NOT_AT_PLACE
	if fail != Cast.OK:
		return fail
	if spell.tags.has(&"passive"):
		return Cast.PASSIVE
	if not (spell.tags.has(&"target_point") or spell.tags.has(&"target_self")):
		return Cast.NOT_READY
	return Cast.OK


## Spells the unit's type casts, by index order (passive ones left out); a hero has those
## tagged hero_at_power_place while he stands at a place of power.
func spells_of(id: int) -> Array[SpellDef]:
	var out: Array[SpellDef] = []
	var type_id := entities.type_ids[id - 1]
	for spell in spells:
		if spell.tags.has(&"passive"):
			continue
		if spell.casters.has(type_id) or (_hero_of(id, spell) and at_place(id)):
			out.append(spell)
	return out


## Whether the unit is a hero of the spell's faction and the spell is cast by heroes at a place.
func _hero_of(id: int, spell: SpellDef) -> bool:
	var def := combat.defs[id - 1] if id - 1 < combat.defs.size() else null
	if def == null or not spell.tags.has(&"hero_at_power_place"):
		return false
	return def.has_class(&"hero") and def.faction == spell.faction


## Whether the unit stands within capture_radius of a place of power nobody hides.
func at_place(id: int) -> bool:
	var cx := Fixed.to_cells(entities.pos_x[id - 1])
	var cy := Fixed.to_cells(entities.pos_y[id - 1])
	return places.site_near(cx, cy, rules.capture_radius) >= 0


## Whole ticks left before the unit may cast the spell again.
func cooldown_ticks(id: int, spell_id: StringName) -> int:
	var left: int = _cooldown.get(id * SPELL_SLOTS + spell_index.get(spell_id, 0), 0)
	return (left + COOLDOWN_SCALE - 1) / COOLDOWN_SCALE


## The spell's Сила cost for the side, with techs («sp_bogurodzica.cost_permille»).
func power_cost(p: int, spell: SpellDef) -> int:
	var state: PlayerState = players.get(p)
	if state == null:
		return spell.power_cost
	var off: int = state.unit_mods.get(StringName("%s.cost_permille" % spell.id), 0)
	return spell.power_cost * maxi(1000 + off, 0) / 1000


## The spell's radius for its caster's side, with techs («sp_exorcism.radius»).
func radius_of(p: int, spell: SpellDef) -> int:
	var state: PlayerState = players.get(p)
	var bonus := 0
	if state != null:
		bonus = state.unit_mods.get(StringName("%s.radius" % spell.id), 0)
	return spell.radius + bonus


func _cast(id: int, spell: SpellDef, x: int, y: int) -> void:
	var slot := id - 1
	var p := entities.owners[slot]
	players[p].power -= power_cost(p, spell) * POWER_UNIT
	_cooldown[id * SPELL_SLOTS + spell_index[spell.id]] = spell.cooldown_ticks * COOLDOWN_SCALE
	_pending.erase(id)
	var r := radius_of(p, spell)
	if spell.tags.has(&"dispel"):
		_dispel(p, x, y, r)
	elif spell.tags.has(&"mist"):
		_add_effect(spell, p, 0, x, y, r)
	elif spell.tags.has(&"blessing"):
		var blessed := _own_unit_at(p, x, y)
		if blessed != EntityStore.NO_ID:
			_add_effect(spell, p, blessed, x, y, 0)
	elif spell.tags.has(&"relic") or spell.tags.has(&"icon") or spell.tags.has(&"hymn"):
		_add_effect(spell, p, id, entities.pos_x[slot], entities.pos_y[slot], r)
	elif spell.tags.has(&"pact"):
		_add_effect(spell, p, id, entities.pos_x[slot], entities.pos_y[slot], r)
	elif spell.tags.has(&"storm"):
		_add_effect(spell, p, 0, x, y, r)
		_lightning(p, x, y, r)
	elif spell.tags.has(&"wolf_path"):
		_add_effect(spell, p, 0, entities.pos_x[slot], entities.pos_y[slot], r)


## The player's own living unit nearest the point within a cell (lowest id on a tie), or none.
func _own_unit_at(p: int, x: int, y: int) -> int:
	var best := EntityStore.NO_ID
	var best_d := Fixed.ONE + 1
	var near := combat.buckets.near(x, y, Fixed.ONE)
	near.sort()
	for id in near:
		var slot := id - 1
		if entities.owners[slot] != p or entities.hp[slot] <= 0 or combat.defs[slot] == null:
			continue
		var d := Fixed.distance(x, y, entities.pos_x[slot], entities.pos_y[slot])
		if d < best_d:
			best = id
			best_d = d
	return best


## Fills CombatSystem.crown's spell boosts for this tick (called at the start of the combat
## step), and turns back own units fleeing inside a hymn.
func boost() -> void:
	var crown := combat.crown
	crown.spell_morale.clear()
	crown.spell_armor.clear()
	crown.spell_damage.clear()
	crown.pact.clear()
	for i in fx_ids.size():
		var tags := spells[fx_spell[i]].tags
		if tags.has(&"blessing"):
			var b := fx_caster[i]
			if entities.is_alive(b):
				crown.spell_armor[b] = crown.spell_armor.get(b, 0) + rules.blessing_armor
				crown.spell_morale[b] = crown.spell_morale.get(b, 0) + rules.blessing_morale
			continue
		if not (tags.has(&"hymn") or tags.has(&"pact")):
			continue
		var near := combat.buckets.near(fx_x[i], fx_y[i], Fixed.from_cells(fx_radius[i]))
		near.sort()
		for id in near:
			var slot := id - 1
			if entities.owners[slot] != fx_owner[i] or entities.hp[slot] <= 0:
				continue
			if tags.has(&"hymn"):
				crown.spell_morale[id] = crown.spell_morale.get(id, 0) + rules.hymn_morale
				Maneuvers.rally(combat, id)
			else:
				crown.pact[id] = true
				crown.spell_damage[id] = rules.pact_damage_permille


## «Гнев Перкуна»: bolts on the enemy units with the most max HP under the storm (ties: lower id).
func _lightning(p: int, x: int, y: int, r: int) -> void:
	var reach := Fixed.from_cells(r)
	var near := combat.buckets.near(x, y, reach)
	near.sort()
	var picked := PackedInt32Array()
	for k in rules.storm_strikes:
		var best := 0
		for id in near:
			var slot := id - 1
			if not combat.sides.hostile(p, entities.owners[slot]) or entities.hp[slot] <= 0:
				continue
			if id in picked:
				continue
			if Fixed.distance(x, y, entities.pos_x[slot], entities.pos_y[slot]) > reach:
				continue
			if best == 0 or entities.max_hp[slot] > entities.max_hp[best - 1]:
				best = id
		if best == 0:
			break
		picked.append(best)
	for id in picked:
		combat.lightning(id, p, rules.storm_damage)


## True while the unit stands in the rain of a storm: its bow, crossbow or gun is silent.
func silenced(slot: int) -> bool:
	for i in fx_ids.size():
		if not spells[fx_spell[i]].tags.has(&"storm"):
			continue
		var reach := Fixed.from_cells(fx_radius[i])
		if Fixed.distance(entities.pos_x[slot], entities.pos_y[slot], fx_x[i], fx_y[i]) <= reach:
			return true
	return false


func _add_effect(spell: SpellDef, p: int, caster: int, x: int, y: int, r: int) -> void:
	fx_ids.append(_next_fx)
	_next_fx += 1
	fx_spell.append(spell_index[spell.id])
	fx_owner.append(p)
	fx_caster.append(caster)
	fx_x.append(x)
	fx_y.append(y)
	fx_radius.append(r)
	fx_from.append(tick)
	fx_until.append(tick + maxi(spell.duration_ticks, 1))
	_sync_mist()


## «Экзорцизм»: others' effects touching the circle end; others' creatures in it are hurt and
## driven off.
func _dispel(p: int, x: int, y: int, r: int) -> void:
	var i := 0
	while i < fx_ids.size():
		var reach := Fixed.from_cells(r + fx_radius[i])
		if fx_owner[i] != p and Fixed.distance(x, y, fx_x[i], fx_y[i]) <= reach:
			_end_effect(i)
		else:
			i += 1
	_sync_mist()
	var hurt := combat.buckets.near(x, y, Fixed.from_cells(r))
	hurt.sort()
	for id in hurt:
		var slot := id - 1
		var def := combat.defs[slot]
		var owner := entities.owners[slot]
		if def == null or not def.has_class(&"creature") or owner == p:
			continue
		entities.hp[slot] -= rules.exorcism_creature_damage
		if entities.hp[slot] <= 0:
			_remove.call(id)
		else:
			combat.drive_off(id)


# --- the magic step ------------------------------------------------------------------------


func step(at_tick: int) -> void:
	tick = at_tick
	if not enabled():
		return
	places.step(tick)
	_serve_pending()
	_count_down()
	_effects()
	_heal_units()


## Casters who walked into range cast; those that died, stopped short or can no longer cast
## give up.
func _serve_pending() -> void:
	if _pending.is_empty():
		return
	var ids := _pending.keys()
	ids.sort()
	for id: int in ids:
		var want: Vector3i = _pending[id]
		var spell := spells[want.x]
		var slot := id - 1
		if can_cast(entities.owners[slot] if entities.is_alive(id) else 0, id, spell.id) != Cast.OK:
			_pending.erase(id)
			continue
		var d := Fixed.distance(entities.pos_x[slot], entities.pos_y[slot], want.y, want.z)
		if d <= Fixed.from_cells(rules.cast_range):
			_stop.call(id)
			_cast(id, spell, want.y, want.z)
		elif entities.orders[slot] == EntityStore.Order.IDLE:
			_pending.erase(id)


func _count_down() -> void:
	if _cooldown.is_empty():
		return
	var keys := _cooldown.keys()
	keys.sort()
	for key: int in keys:
		var id := key / SPELL_SLOTS
		if not entities.is_alive(id):
			_cooldown.erase(key)
			continue
		var left: int = _cooldown[key] - COOLDOWN_SCALE * (1000 + _recharge_bonus(id)) / 1000
		if left <= 0:
			_cooldown.erase(key)
		else:
			_cooldown[key] = left


## alka_recharge_permille near a finished building of the unit's side tagged spell_recharge.
func _recharge_bonus(id: int) -> int:
	var slot := id - 1
	var owner := entities.owners[slot]
	var r := Fixed.from_cells(rules.alka_recharge_radius)
	for b in buildings.alive_ids:
		var s := b - 1
		if buildings.owners[s] != owner or buildings.done[s] == 0:
			continue
		if not buildings.defs[s].tags.has(&"spell_recharge"):
			continue
		if buildings.distance_sq(b, entities.pos_x[slot], entities.pos_y[slot]) <= r * r:
			return rules.alka_recharge_permille
	return 0


## Ends what ran out (or lost its caster), moves relics with their bearers, shakes enemies who
## come near a relic.
func _effects() -> void:
	var i := 0
	var changed := false
	while i < fx_ids.size():
		var caster := fx_caster[i]
		if tick >= fx_until[i] or (caster != 0 and not entities.is_alive(caster)):
			changed = changed or spells[fx_spell[i]].tags.has(&"mist")
			_end_effect(i)
			continue
		if caster != 0:
			fx_x[i] = entities.pos_x[caster - 1]
			fx_y[i] = entities.pos_y[caster - 1]
		if spells[fx_spell[i]].tags.has(&"relic"):
			_shake(i)
		i += 1
	if changed:
		_sync_mist()


func _shake(i: int) -> void:
	var near := combat.buckets.near(fx_x[i], fx_y[i], Fixed.from_cells(fx_radius[i]))
	near.sort()
	for id in near:
		var slot := id - 1
		var owner := entities.owners[slot]
		var key := fx_ids[i] * RELIC_KEY + id
		if owner <= 0 or owner == fx_owner[i] or _relic_hit.has(key) or entities.hp[slot] <= 0:
			continue
		_relic_hit[key] = true
		combat.lose_morale(slot, rules.relic_enemy_morale)


func _end_effect(i: int) -> void:
	var fx := fx_ids[i]
	if spells[fx_spell[i]].tags.has(&"relic"):
		for key: int in _relic_hit.keys():
			if key / RELIC_KEY == fx:
				_relic_hit.erase(key)
	fx_ids.remove_at(i)
	fx_spell.remove_at(i)
	fx_owner.remove_at(i)
	fx_caster.remove_at(i)
	fx_radius.remove_at(i)
	fx_from.remove_at(i)
	fx_until.remove_at(i)
	fx_x.remove_at(i)
	fx_y.remove_at(i)


func _sync_mist() -> void:
	mist.clear()
	for i in fx_ids.size():
		if spells[fx_spell[i]].tags.has(&"mist"):
			mist.add(
				fx_owner[i],
				Fixed.to_cells(fx_x[i]),
				Fixed.to_cells(fx_y[i]),
				fx_radius[i],
				fx_from[i]
			)


## For CombatSystem.morale_floor: inside a relic (or an icon) of its own side a unit keeps at
## least relic_morale_floor morale (icon_morale_floor percent of its full) while it has more;
## the highest counts.
func morale_floor(slot: int) -> int:
	var owner := entities.owners[slot]
	var best := 0
	for i in fx_ids.size():
		if fx_owner[i] != owner:
			continue
		var tags := spells[fx_spell[i]].tags
		var floor_points := 0
		if tags.has(&"relic"):
			floor_points = rules.relic_morale_floor
		elif tags.has(&"icon") and combat.defs[slot] != null:
			floor_points = combat.defs[slot].morale * rules.icon_morale_floor / 100
		if floor_points <= best:
			continue
		var r := Fixed.from_cells(fx_radius[i])
		var dx := entities.pos_x[slot] - fx_x[i]
		var dy := entities.pos_y[slot] - fx_y[i]
		if dx * dx + dy * dy <= r * r:
			best = floor_points
	return best


## Once a second each healer gives its HP a second to every hurt unit of its side in reach.
func _heal_units() -> void:
	for id in entities.alive_ids:
		var slot := id - 1
		if slot >= _heal.size() or _heal[slot] <= 0 or (tick + id) % HEAL_EVERY != 0:
			continue
		var owner := entities.owners[slot]
		var amount := _heal[slot] + _mod(owner, slot, &"heal")
		var near := combat.buckets.near(
			entities.pos_x[slot], entities.pos_y[slot], Fixed.from_cells(_heal_radius[slot])
		)
		near.sort()
		for other in near:
			var o := other - 1
			if entities.owners[o] == owner and entities.hp[o] > 0:
				entities.hp[o] = mini(entities.max_hp[o], entities.hp[o] + amount)


## Sum of the owner's tech changes to a unit stat by its classes and id.
func _mod(owner: int, slot: int, stat: StringName) -> int:
	var state: PlayerState = players.get(owner)
	var def := combat.defs[slot]
	if state == null or def == null or state.unit_mods.is_empty():
		return 0
	var sum: int = state.unit_mods.get(StringName("%s.%s" % [def.id, stat]), 0)
	for cls in def.classes:
		sum += state.unit_mods.get(StringName("%s.%s" % [cls, stat]), 0)
	return sum


# --- state ---------------------------------------------------------------------------------


func write_to(buf: StreamPeerBuffer) -> void:
	places.write_to(buf)
	buf.put_32(_next_fx)
	buf.put_32(fx_ids.size())
	for i in fx_ids.size():
		for v: int in [fx_ids[i], fx_spell[i], fx_owner[i], fx_caster[i], fx_radius[i]]:
			buf.put_32(v)
		buf.put_64(fx_x[i])
		buf.put_64(fx_y[i])
		buf.put_32(fx_from[i])
		buf.put_32(fx_until[i])
	for d: Dictionary in [_cooldown, _relic_hit]:
		var keys := d.keys()
		keys.sort()
		buf.put_32(keys.size())
		for k: int in keys:
			buf.put_64(k)
			buf.put_32(int(d[k]))
	var waiting := _pending.keys()
	waiting.sort()
	buf.put_32(waiting.size())
	for id: int in waiting:
		var want: Vector3i = _pending[id]
		buf.put_32(id)
		buf.put_32(want.x)
		buf.put_64(want.y)
		buf.put_64(want.z)
