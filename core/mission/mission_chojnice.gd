class_name MissionChojnice
extends RefCounted
## The rules of «Корона 4. Хойнице, 1454» (def.rules.chojnice), run by MissionRuntime.step() on
## this object's state, which the runtime's save and hash carry: a battle the Crown loses. The
## long day of setting out the levy of the nobility, whose lords argue over places in the line;
## the levy itself, brave and wilful, that rides after anyone who runs and loses heart early;
## the panic that runs through the army from a blow in the rear; the king who will not leave the
## field until his own men take him; the bog where whoever runs off the causeway drowns; the
## debt Jaśko pays on the causeway; the Łęczyca banner going from hand to hand.
##
## Rules (chojnice {player, crown: [players], ...}):
##   day {start_minutes, ticks_per_hour}: the clock on the panel (hour condition);
##   pospolite {players, chase_cells, banner_radius, banner_recovery}: units of those players
##     tagged auto_pursuit and not told to STAND ride (attack) at a fleeing enemy within
##     chase_cells by themselves and keep after him, however far; they flee once their morale
##     with every bonus falls to their flee_morale; near a banner bearer of their own they get
##     banner_recovery more morale back a check;
##   walls [x0, y0, x1, y1]: the player's units that get there after the trigger `walls_from`
##     have chased to the walls (chased condition);
##   dispute {groups: [[group, every, ticks], ...], hero_radius, from}: every `every`-th member
##     of the group (all at 1) argues over its place: it does not move until start + ticks × (1 +
##     its index in the group mod 3); the player's argue until one of his heroes comes within
##     hero_radius of them;
##   deploy {group: [x, y]}: once deploying (action deploy), the group's members that do not
##     argue go to their place: the point plus where they stood in the group at the start;
##   panic {players, speed, max, shield_radius, foot}: from the point of the panic action a wave
##     runs out speed cells a check (up to max): every unit of those players it reaches flees,
##     unless it stands within shield_radius of a banner bearer or a hero of its own side or a
##     unit of type `foot` holding its ground (STAND); heroes and units that never flee are let
##     be;
##   drown {rects, safe}: a unit of the crown side fleeing on a bog cell inside the rects and not
##     on the causeway (safe rects) drowns;
##   king {group, escorts, radius, follow_cells, route: [[x, y], ...], floor_permille, from}: from
##     the trigger `from` the king lets himself be led when `escorts` units of the player stand
##     within radius cells of him; led, he rides the route while a unit of the player is within
##     follow_cells of him, and at its end he is out (flag king_out). He cannot fall below
##     floor_permille of his HP; there, with an enemy and nobody of his side near, he is taken
##     (flag king_taken);
##   banner {groups, raise_radius, raise_ticks}: the Łęczyca banner, carried by the first living
##     member of the group the action banner_to names (groups lists who may have it); if its
##     bearer falls, a unit of the player within raise_radius raises it, else after raise_ticks
##     the enemy has it (flag banner_taken);
##   debt {marks, group, base_ticks, per_debt_ticks, with}: the debt from the campaign is the
##     number of `marks` (questions "mark:…") answered. From the action last_stand the group's
##     hero holds: «Договор» works round him without being cast for base_ticks + debt ×
##     per_debt_ticks; then he falls, and the groups `with` with him (flag debt_paid);
##   floors {group: permille}: those groups' members cannot fall below that share of their HP
##     until released (action release);
##   escape {rect, keep}: the player's units that reach the rect leave the map over the bog
##     (escaped), but for the groups in keep.
## Conditions: hour {at_least} (minutes since midnight); chased {at_least}; panic_reached
##   {cells}; king_led; escaped {at_least}; drowned {at_least, player?}; arguing {at_most}.
## Actions: deploy {on}; panic {at}; pursue {group, on} (the group's members that are not
##   fighting keep attack-moving at the nearest unit of the player or the king); banner_to
##   {group}; last_stand; release {group}.

const CONDITIONS: Array[String] = [
	"hour", "chased", "panic_reached", "king_led", "escaped", "drowned", "arguing"
]
const ACTIONS: Array[String] = ["deploy", "panic", "pursue", "banner_to", "last_stand", "release"]
## How often (ticks) a pursuing group is sent again at the nearest unit.
const PURSUE_EVERY := 40
## The king rides on to the next waypoint once this near the last one (cells).
const AT_WAYPOINT := 2
const FULL := 1000

var on := false
## Arguing units -> the tick their argument ends (-1: until a hero comes).
var arguing: Dictionary[int, int] = {}
## Deploying, and each deploying unit's place (fixed units) and whether it was sent there.
var deploying := false
var place_x: Dictionary[int, int] = {}
var place_y: Dictionary[int, int] = {}
var sent: Dictionary[int, bool] = {}
## The player's units that chased to the walls.
var chased: Dictionary[int, bool] = {}
## The panic: its centre (fixed units), the front (cells, -1: none) and who it reached.
var panic_x := 0
var panic_y := 0
var front := -1
var struck: Dictionary[int, bool] = {}
## Units drowned, in all and the player's.
var drowned := 0
var drowned_player := 0
## The king: led, the next waypoint, out.
var led := false
var leg := 0
var king_out := false
## The banner's bearer (0: on the ground), where it lies, since when (-1: carried).
var bearer := 0
var banner_x := 0
var banner_y := 0
var banner_down := -1
## The last stand: the tick it ends (-1: not begun), the debt, whether it is over.
var stand_until := -1
var debt := 0
var paid := false
## Groups whose HP floor was released; groups pursuing.
var released := PackedStringArray()
var pursuing := PackedStringArray()
var escaped := 0
## The tick being checked (for conditions; not state of its own).
var now := 0


func set_up(m: MissionRuntime) -> void:
	var r := _rules(m)
	if r.is_empty():
		return
	on = true
	var d: Dictionary = r.get("dispute", {})
	for entry: Array in d.get("groups", []):
		var members := m.alive_of(str(entry[0]))
		var every := maxi(Num.of(entry[1]), 1)
		var ticks := Num.of(entry[2])
		for k in members.size():
			if k % every != 0:
				continue
			var owner := m.entities.owners[members[k] - 1]
			arguing[members[k]] = -1 if owner == Num.of(r["player"]) else ticks * (1 + k % 3)
	var places: Dictionary = r.get("deploy", {})
	for g: String in places:
		var members := m.alive_of(g)
		if members.is_empty():
			continue
		var to: Array = places[g]
		var cx := 0
		var cy := 0
		for id in members:
			cx += m.entities.pos_x[id - 1]
			cy += m.entities.pos_y[id - 1]
		cx /= members.size()
		cy /= members.size()
		for id in members:
			place_x[id] = (
				Fixed.from_cells(Num.of(to[0])) + Fixed.HALF + m.entities.pos_x[id - 1] - cx
			)
			place_y[id] = (
				Fixed.from_cells(Num.of(to[1])) + Fixed.HALF + m.entities.pos_y[id - 1] - cy
			)
	var b: Dictionary = r.get("banner", {})
	if not b.is_empty():
		_banner_to(m, str((b["groups"] as Array)[0]))


func step(m: MissionRuntime, tick: int) -> void:
	if not on:
		return
	now = tick
	var r := _rules(m)
	_floors(m, r.get("floors", {}))
	_dispute(m, r.get("dispute", {}), tick)
	_deploy(m, tick)
	_pospolite(m, r.get("pospolite", {}), tick)
	_walls(m, r, tick)
	_panic(m, r.get("panic", {}), tick)
	_drown(m, r.get("drown", {}), r, tick)
	_king(m, r.get("king", {}), tick)
	_banner(m, r.get("banner", {}), tick)
	_stand(m, r.get("debt", {}), tick)
	_escape(m, r.get("escape", {}), tick)
	if tick % PURSUE_EVERY == 0:
		for g in pursuing:
			_pursue(m, g, tick)


func test(m: MissionRuntime, c: Dictionary) -> bool:
	var ok := false
	match c["type"]:
		"hour":
			ok = minutes(m, now) >= Num.of(c["at_least"])
		"chased":
			ok = chased.size() >= Num.of(c["at_least"])
		"panic_reached":
			ok = front >= Num.of(c["cells"])
		"king_led":
			ok = led
		"escaped":
			ok = escaped >= Num.of(c["at_least"])
		"drowned":
			var n := drowned_player if c.has("player") else drowned
			ok = n >= Num.of(c["at_least"])
		"arguing":
			ok = arguing_now(m) <= Num.of(c["at_most"])
	return ok


func run(m: MissionRuntime, a: Dictionary, tick: int) -> void:
	if not on:
		return
	match a["do"]:
		"deploy":
			deploying = a.get("on", true)
		"panic":
			var at: Array = a["at"]
			panic_x = Fixed.from_cells(Num.of(at[0])) + Fixed.HALF
			panic_y = Fixed.from_cells(Num.of(at[1])) + Fixed.HALF
			front = 0
			m.flags["panic"] = tick
		"pursue":
			var g: String = a["group"]
			if a.get("on", true):
				if not pursuing.has(g):
					pursuing.append(g)
					_pursue(m, g, tick)
			elif pursuing.has(g):
				pursuing.remove_at(pursuing.find(g))
		"banner_to":
			_banner_to(m, str(a["group"]))
		"last_stand":
			_last_stand(m, tick)
		"release":
			var g: String = a["group"]
			if not released.has(g):
				released.append(g)
			for id in m.alive_of(g):
				m.combat.hp_floor.erase(id)


## Minutes since midnight on the mission's clock.
func minutes(m: MissionRuntime, tick: int) -> int:
	var d: Dictionary = _rules(m).get("day", {})
	if d.is_empty():
		return 0
	return Num.of(d["start_minutes"]) + tick * 60 / maxi(Num.of(d["ticks_per_hour"]), 1)


## The clock as «HH:MM», for the panel.
func clock_text(m: MissionRuntime, tick: int) -> String:
	var t := minutes(m, tick) % (24 * 60)
	return "%02d:%02d" % [t / 60, t % 60]


func arguing_now(m: MissionRuntime) -> int:
	var n := 0
	for id: int in arguing:
		if m.entities.is_alive(id):
			n += 1
	return n


func is_arguing(id: int) -> bool:
	return arguing.has(id)


# --- the long day ---------------------------------------------------------------------------


func _dispute(m: MissionRuntime, d: Dictionary, tick: int) -> void:
	if arguing.is_empty():
		return
	var e := m.entities
	var p := Num.of(_rules(m)["player"])
	var reach := Fixed.from_cells(Num.of(d.get("hero_radius", 4)))
	var heroes := PackedInt32Array()
	for id in e.alive_ids:
		if e.owners[id - 1] == p and m.combat.defs[id - 1] != null:
			if m.combat.defs[id - 1].has_class(&"hero"):
				heroes.append(id)
	var start := Num.of(m.fired.get(str(d.get("from", "")), 0))
	var done := PackedInt32Array()
	var held := PackedInt32Array()
	var ids := arguing.keys()
	ids.sort()
	for id: int in ids:
		if not e.is_alive(id):
			done.append(id)
			continue
		var s := id - 1
		var until: int = arguing[id]
		var over := until >= 0 and tick >= start + until
		if until < 0:
			for h in heroes:
				if Fixed.distance(e.pos_x[h - 1], e.pos_y[h - 1], e.pos_x[s], e.pos_y[s]) <= reach:
					over = true
					break
		if over:
			done.append(id)
		elif e.orders[s] != EntityStore.Order.IDLE:
			held.append(id)
	for id in done:
		arguing.erase(id)
	for id in held:
		m._apply.call(SimCommand.stop(tick, e.owners[id - 1], PackedInt32Array([id])))


func _deploy(m: MissionRuntime, tick: int) -> void:
	if not deploying:
		return
	var e := m.entities
	var ids := place_x.keys()
	ids.sort()
	for id: int in ids:
		if sent.has(id) or arguing.has(id) or not e.is_alive(id):
			continue
		sent[id] = true
		var one := PackedInt32Array([id])
		m._apply.call(SimCommand.move(tick, e.owners[id - 1], one, place_x[id], place_y[id]))


# --- the levy -------------------------------------------------------------------------------


func _pospolite(m: MissionRuntime, ps: Dictionary, tick: int) -> void:
	# Morale with its bonuses is known from the first combat step on.
	if ps.is_empty() or m.combat.crown.defs.size() != m.combat.defs.size():
		return
	var e := m.entities
	var players: Array = ps["players"]
	var reach := Fixed.from_cells(Num.of(ps["chase_cells"]))
	var near_banner := Fixed.from_cells(Num.of(ps.get("banner_radius", 8)))
	var recovery := Num.of(ps.get("banner_recovery", 0)) * CombatSystem.MORALE_SCALE
	for id in e.alive_ids:
		var s := id - 1
		var unit := m.combat.defs[s]
		if unit == null or not unit.tags.has(&"auto_pursuit") or not players.has(e.owners[s]):
			continue
		if e.intents[s] != EntityStore.Intent.NONE or e.hp[s] <= 0:
			continue
		var full := unit.morale * CombatSystem.MORALE_SCALE
		if recovery > 0 and e.morale[s] < full:
			if m.combat.banners.near(e, e.owners[s], e.pos_x[s], e.pos_y[s], near_banner):
				e.morale[s] = mini(full, e.morale[s] + recovery)
		if m.combat.crown.pact.has(id):
			continue
		if m.combat.effective_morale(s) <= unit.param(&"flee_morale", 0):
			m.combat.drive_off(id)
			continue
		if e.stance[s] == EntityStore.Stance.STAND or e.stance[s] == EntityStore.Stance.PASSIVE:
			continue
		if arguing.has(id) or e.target_kind[s] == EntityStore.TargetKind.ORDERED:
			continue
		var prey := _fleeing_enemy(m, s, reach)
		if prey != 0:
			m._apply.call(SimCommand.attack(tick, e.owners[s], PackedInt32Array([id]), prey))


## The nearest fleeing enemy within reach of the unit (lowest id on a tie), or 0.
func _fleeing_enemy(m: MissionRuntime, s: int, reach: int) -> int:
	var e := m.entities
	var best := 0
	var best_d := 0
	var near := m.combat.buckets.near(e.pos_x[s], e.pos_y[s], reach)
	near.sort()
	for other in near:
		var o := other - 1
		if e.intents[o] != EntityStore.Intent.FLEE or e.hp[o] <= 0:
			continue
		if not m.are_hostile(e.owners[s], e.owners[o]) or m.combat.untouchable.has(other):
			continue
		var d := Fixed.distance(e.pos_x[s], e.pos_y[s], e.pos_x[o], e.pos_y[o])
		if d <= reach and (best == 0 or d < best_d):
			best = other
			best_d = d
	return best


func _walls(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	if not r.has("walls") or not m.fired.has(str(r.get("walls_from", ""))):
		return
	var rect: Array = r["walls"]
	var e := m.entities
	var p := Num.of(r["player"])
	for id in e.alive_ids:
		var s := id - 1
		if e.owners[s] == p and not chased.has(id) and _in_rect(rect, e.pos_x[s], e.pos_y[s]):
			chased[id] = true
			m.flags["chased"] = tick


# --- the panic and the bog ------------------------------------------------------------------


func _panic(m: MissionRuntime, pn: Dictionary, tick: int) -> void:
	if pn.is_empty() or front < 0 or front >= Num.of(pn["max"]):
		return
	front = mini(front + Num.of(pn["speed"]), Num.of(pn["max"]))
	var e := m.entities
	var players: Array = pn["players"]
	var reach := Fixed.from_cells(front)
	var shield := Fixed.from_cells(Num.of(pn["shield_radius"]))
	var foot := StringName(str(pn.get("foot", "")))
	var hit := PackedInt32Array()
	for id in m.combat.buckets.near(panic_x, panic_y, reach):
		var s := id - 1
		if struck.has(id) or not players.has(e.owners[s]) or e.hp[s] <= 0:
			continue
		if Fixed.distance(panic_x, panic_y, e.pos_x[s], e.pos_y[s]) > reach:
			continue
		hit.append(id)
	hit.sort()
	for id in hit:
		struck[id] = true
		var s := id - 1
		var unit := m.combat.defs[s]
		if unit == null or unit.never_flees or unit.has_class(&"hero"):
			continue
		if m.combat.crown.pact.has(id) or _shielded(m, s, shield, foot):
			continue
		m.flags["panicked"] = tick
		m.combat.drive_off(id)


## Whether a banner, a hero of the unit's side or a foot servant holding his ground is near.
func _shielded(m: MissionRuntime, s: int, reach: int, foot: StringName) -> bool:
	var e := m.entities
	var px := e.pos_x[s]
	var py := e.pos_y[s]
	for other in m.combat.buckets.near(px, py, reach):
		var o := other - 1
		if other == s + 1 or e.hp[o] <= 0 or not m.are_friendly(e.owners[s], e.owners[o]):
			continue
		if Fixed.distance(px, py, e.pos_x[o], e.pos_y[o]) > reach:
			continue
		var unit := m.combat.defs[o]
		if other == bearer or (unit != null and unit.has_class(&"hero")):
			return true
		if e.type_ids[o] == foot and e.stance[o] == EntityStore.Stance.STAND:
			return true
	return false


func _drown(m: MissionRuntime, dr: Dictionary, r: Dictionary, tick: int) -> void:
	if dr.is_empty():
		return
	var e := m.entities
	var crown: Array = r.get("crown", [r["player"]])
	var p := Num.of(r["player"])
	var bog := &"t_bog"
	var lost := PackedInt32Array()
	for id in e.alive_ids:
		var s := id - 1
		if e.intents[s] != EntityStore.Intent.FLEE or not crown.has(e.owners[s]):
			continue
		if m.combat.nav.terrain_at(m.combat.nav.cell_of(e.pos_x[s], e.pos_y[s])) != bog:
			continue
		var inside := false
		for rect: Array in dr["rects"]:
			inside = inside or _in_rect(rect, e.pos_x[s], e.pos_y[s])
		for rect: Array in dr.get("safe", []):
			inside = inside and not _in_rect(rect, e.pos_x[s], e.pos_y[s])
		if inside:
			lost.append(id)
	for id in lost:
		drowned += 1
		if e.owners[id - 1] == p:
			drowned_player += 1
		m.flags["drowned"] = tick
		m.combat.hp_floor.erase(id)
		m.combat.lightning(id, 0, e.hp[id - 1])


# --- the king -------------------------------------------------------------------------------


func _king(m: MissionRuntime, k: Dictionary, tick: int) -> void:
	if k.is_empty() or king_out:
		return
	var ids := m.alive_of(str(k["group"]))
	if ids.is_empty():
		return
	var e := m.entities
	var king := ids[0]
	var s := king - 1
	m.combat.hp_floor[king] = maxi(e.max_hp[s] * Num.of(k["floor_permille"]) / FULL, 1)
	if e.hp[s] <= m.combat.hp_floor[king] and _taken(m, s):
		m.flags["king_taken"] = tick
		return
	if not m.fired.has(str(k["from"])):
		return
	var p := Num.of(_rules(m)["player"])
	if not led:
		if _count_near(m, s, p, Fixed.from_cells(Num.of(k["radius"]))) >= Num.of(k["escorts"]):
			led = true
			m.flags["king_led"] = tick
			m._apply.call(SimCommand.set_stance(tick, e.owners[s], ids, EntityStore.Stance.PASSIVE))
		else:
			return
	var route: Array = k["route"]
	var at: Array = route[mini(leg, route.size() - 1)]
	var wx := Fixed.from_cells(Num.of(at[0])) + Fixed.HALF
	var wy := Fixed.from_cells(Num.of(at[1])) + Fixed.HALF
	if Fixed.distance(wx, wy, e.pos_x[s], e.pos_y[s]) <= Fixed.from_cells(AT_WAYPOINT):
		leg += 1
		if leg >= route.size():
			king_out = true
			m.flags["king_out"] = tick
			m.combat.hp_floor.erase(king)
			m._remove.call(king)
			return
		at = route[leg]
		wx = Fixed.from_cells(Num.of(at[0])) + Fixed.HALF
		wy = Fixed.from_cells(Num.of(at[1])) + Fixed.HALF
	var with_us := _count_near(m, s, p, Fixed.from_cells(Num.of(k["follow_cells"]))) > 0
	if with_us and (e.orders[s] == EntityStore.Order.IDLE or tick % 100 == 0):
		m._apply.call(SimCommand.move(tick, e.owners[s], PackedInt32Array([king]), wx, wy))
	elif not with_us and e.orders[s] != EntityStore.Order.IDLE:
		m._apply.call(SimCommand.stop(tick, e.owners[s], PackedInt32Array([king])))


## Whether an enemy stands next to him and nobody of his side does.
func _taken(m: MissionRuntime, s: int) -> bool:
	var e := m.entities
	var reach := Fixed.from_cells(3)
	var enemy := false
	for other in m.combat.buckets.near(e.pos_x[s], e.pos_y[s], reach):
		var o := other - 1
		if o == s or e.hp[o] <= 0:
			continue
		if Fixed.distance(e.pos_x[s], e.pos_y[s], e.pos_x[o], e.pos_y[o]) > reach:
			continue
		if m.are_friendly(e.owners[s], e.owners[o]):
			return false
		enemy = enemy or m.are_hostile(e.owners[s], e.owners[o])
	return enemy


func _count_near(m: MissionRuntime, s: int, p: int, reach: int) -> int:
	var e := m.entities
	var n := 0
	for other in m.combat.buckets.near(e.pos_x[s], e.pos_y[s], reach):
		var o := other - 1
		if e.owners[o] != p or e.hp[o] <= 0:
			continue
		if Fixed.distance(e.pos_x[s], e.pos_y[s], e.pos_x[o], e.pos_y[o]) <= reach:
			n += 1
	return n


# --- the banner and the debt ----------------------------------------------------------------


func _banner_to(m: MissionRuntime, group: String) -> void:
	var ids := m.alive_of(group)
	if ids.is_empty():
		return
	if bearer != 0:
		m.combat.banners.bearers.erase(bearer)
	bearer = ids[0]
	banner_down = -1
	m.combat.banners.bearers[bearer] = true


func _banner(m: MissionRuntime, b: Dictionary, tick: int) -> void:
	if b.is_empty() or m.flags.has("banner_taken"):
		return
	var e := m.entities
	if bearer != 0:
		if e.is_alive(bearer) and e.hp[bearer - 1] > 0:
			banner_x = e.pos_x[bearer - 1]
			banner_y = e.pos_y[bearer - 1]
			return
		m.combat.banners.bearers.erase(bearer)
		bearer = 0
		banner_down = tick
		m.flags["banner_down"] = tick
		var at := [Fixed.to_cells(banner_x), Fixed.to_cells(banner_y)]
		m.run({"do": "ping", "at": at, "radius": 2}, tick)
	var p := Num.of(_rules(m)["player"])
	var reach := Fixed.from_cells(Num.of(b["raise_radius"]))
	var near := m.combat.buckets.near(banner_x, banner_y, reach)
	near.sort()
	for id in near:
		var s := id - 1
		if e.owners[s] != p or e.hp[s] <= 0 or m.combat.is_fleeing(id):
			continue
		if Fixed.distance(banner_x, banner_y, e.pos_x[s], e.pos_y[s]) <= reach:
			bearer = id
			banner_down = -1
			m.combat.banners.bearers[id] = true
			m.flags["banner_raised"] = tick
			return
	if tick - banner_down >= Num.of(b["raise_ticks"]):
		m.flags["banner_taken"] = tick


func _last_stand(m: MissionRuntime, tick: int) -> void:
	var d: Dictionary = _rules(m).get("debt", {})
	if d.is_empty() or stand_until >= 0:
		return
	debt = 0
	for q: String in d.get("marks", []):
		if m.flags.has(MissionRuntime.choice_flag(q, 0)):
			debt += 1
	stand_until = tick + Num.of(d["base_ticks"]) + debt * Num.of(d["per_debt_ticks"])
	m.flags["last_stand"] = tick


func _stand(m: MissionRuntime, d: Dictionary, tick: int) -> void:
	if d.is_empty() or stand_until < 0 or paid:
		return
	var ids := m.alive_of(str(d["group"]))
	if tick >= stand_until or ids.is_empty():
		paid = true
		m.flags["debt_paid"] = tick
		for g: String in [d["group"]] + (d.get("with", []) as Array):
			for id in m.alive_of(g):
				m.combat.hp_floor.erase(id)
				m.combat.lightning(id, 0, m.entities.hp[id - 1])
		return
	var hero := ids[0]
	if _pact_on(m, hero):
		return
	var spell: SpellDef = m.magic.db.spell(&"sp_pact") if m.magic.db != null else null
	if spell != null and m.magic.spell_index.has(spell.id):
		var e := m.entities
		var r := maxi(m.magic.radius_of(e.owners[hero - 1], spell), 1)
		m.magic._add_effect(
			spell, e.owners[hero - 1], hero, e.pos_x[hero - 1], e.pos_y[hero - 1], r
		)


func _pact_on(m: MissionRuntime, hero: int) -> bool:
	var mg := m.magic
	for i in mg.fx_ids.size():
		if mg.fx_caster[i] == hero and mg.spells[mg.fx_spell[i]].tags.has(&"pact"):
			return true
	return false


# --- the rest -------------------------------------------------------------------------------


func _floors(m: MissionRuntime, floors: Dictionary) -> void:
	var names := floors.keys()
	names.sort()
	for g: String in names:
		if released.has(g):
			continue
		for id in m.alive_of(g):
			var hp := m.entities.max_hp[id - 1] * Num.of(floors[g]) / FULL
			m.combat.hp_floor[id] = maxi(hp, 1)


func _pursue(m: MissionRuntime, g: String, tick: int) -> void:
	var ids := m.alive_of(g)
	if ids.is_empty():
		return
	var e := m.entities
	var r := _rules(m)
	var p := Num.of(r["player"])
	var king := m.alive_of(str(r.get("king", {}).get("group", "")))
	var lead := ids[0] - 1
	var best := 0
	var best_d := 0
	for id in e.alive_ids:
		var s := id - 1
		if e.hp[s] <= 0 or (e.owners[s] != p and not king.has(id)):
			continue
		var d := Fixed.distance(e.pos_x[lead], e.pos_y[lead], e.pos_x[s], e.pos_y[s])
		if best == 0 or d < best_d:
			best = id
			best_d = d
	var free := PackedInt32Array()
	for id in ids:
		if e.target[id - 1] == EntityStore.NO_ID and e.intents[id - 1] == EntityStore.Intent.NONE:
			free.append(id)
	if best != 0 and not free.is_empty():
		var x := e.pos_x[best - 1]
		var y := e.pos_y[best - 1]
		m._apply.call(SimCommand.attack_move(tick, e.owners[lead], free, x, y))


func _escape(m: MissionRuntime, es: Dictionary, tick: int) -> void:
	if es.is_empty():
		return
	var e := m.entities
	var p := Num.of(_rules(m)["player"])
	var keep := {}
	for g: String in es.get("keep", []):
		for id in m.alive_of(g):
			keep[id] = true
	var out := PackedInt32Array()
	for id in e.alive_ids:
		var s := id - 1
		if e.owners[s] == p and not keep.has(id) and e.hp[s] > 0 and id != bearer:
			if _in_rect(es["rect"], e.pos_x[s], e.pos_y[s]):
				out.append(id)
	for id in out:
		escaped += 1
		m.flags["escaped"] = tick
		m.combat.hp_floor.erase(id)
		m._remove.call(id)


static func _in_rect(rect: Array, x: int, y: int) -> bool:
	var cx := Fixed.to_cells(x)
	var cy := Fixed.to_cells(y)
	return (
		cx >= Num.of(rect[0])
		and cy >= Num.of(rect[1])
		and cx <= Num.of(rect[2])
		and cy <= Num.of(rect[3])
	)


func _rules(m: MissionRuntime) -> Dictionary:
	return m.def.rules.get("chojnice", {})


func write_to(buf: StreamPeerBuffer) -> void:
	# Nothing outside this mission, so older replays keep their hashes.
	if not on:
		return
	for d: Dictionary in [arguing, place_x, place_y]:
		var ids := d.keys()
		ids.sort()
		buf.put_32(ids.size())
		for id: int in ids:
			buf.put_32(id)
			buf.put_64(Num.of(d[id]))
	for d: Dictionary in [sent, chased, struck]:
		var ids := d.keys()
		ids.sort()
		buf.put_32(ids.size())
		for id: int in ids:
			buf.put_32(id)
	buf.put_8(1 if deploying else 0)
	buf.put_64(panic_x)
	buf.put_64(panic_y)
	buf.put_32(front)
	buf.put_32(drowned)
	buf.put_32(drowned_player)
	buf.put_8(1 if led else 0)
	buf.put_32(leg)
	buf.put_8(1 if king_out else 0)
	buf.put_32(bearer)
	buf.put_64(banner_x)
	buf.put_64(banner_y)
	buf.put_64(banner_down)
	buf.put_64(stand_until)
	buf.put_32(debt)
	buf.put_8(1 if paid else 0)
	for g in released:
		buf.put_utf8_string(g)
	buf.put_32(pursuing.size())
	for g in pursuing:
		buf.put_utf8_string(g)
	buf.put_32(escaped)
