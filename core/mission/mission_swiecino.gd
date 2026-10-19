class_name MissionSwiecino
extends RefCounted
## The rules of «Корона 6. Свецино, 1462» (def.rules.swiecino), run by MissionRuntime.step() on
## this object's state, which the runtime's save and hash carry: the last battle of the Crown
## campaign, two hired armies in two wagon forts by Lake Żarnowiec. Companies hired for Gdańsk
## silver and their wages, the ditch round the chained wagons, the horses tiring through three
## hours of fighting, the crossbows in the reeds, Dunin's command passing to Stach while he is
## bandaged, the death of Raweneck that breaks his men, prisoners taken for ransom.
##
## Rules (swiecino {player, enemy, ...}):
##   day {start_minutes, ticks_per_hour}: the clock on the panel (clock condition);
##   hire {at, max: {horse, foot}, offers: [[unit, cost, wage, kind], ...]}: while hiring is on
##     (action hire) the player is asked asks.hire again and again: option i hires one unit of
##     offers[i] for `cost` silver at `at` (if he has the silver, else flag no_silver, and the
##     kind is not full, else flag full_<kind>), the last option ends the hiring (flag
##     hiring_over); every hired unit wants `wage` each payday;
##   wages {company, company_every}: on each payday (action payday) the hired units are paid, and
##     the `company` group's members (Stach's own company: their wage is in offers by type) only
##     every company_every-th payday; whoever cannot be paid leaves the field, the hired last
##     first (deserted);
##   ditch {outer, inner, gaps, need, terrain, dig}: the band of cells between the rects (but the
##     gaps) is dug, ring by ring, as the work grows: each check every idle infantry unit of the
##     player inside `dig` adds CHECK_EVERY; at `need` the ditch is done (flag ditch_done). Dug
##     cells turn to `terrain`; enemy horse on them loses its run-up (no charge over the ditch);
##   camp {at, radius, wagons}: the tabor is ready when a ring of the player's wagons stands
##     within radius of `at` and the ditch is done; then the group `wagons` is chained (nobody
##     can strike it). The camp is lost while the enemy has `lost_units` units within radius and
##     the player none (camp_lost condition counts the ticks);
##   fatigue {players, camps: {player: [x, y]}, camp_radius, fight, ride, rest, camp_rest, floor,
##     tired, tired_damage, drain: {unit: permille}, rested, post}: the horses of those players
##     (cavalry, not heroes) have strength 0–1000: each check they lose `fight` in melee (calm
##     below 2 checks), `ride` on the move (× drain of their type), get back `rest` standing,
##     `camp_rest` near their own camp. Their morale cannot rise above full × (floor + (1000 −
##     floor) × strength / 1000) / 1000, and below `tired` they strike at tired_damage permille;
##     skirmish {damage, until} makes every such rider strike at `damage` permille more until
##     trigger `until` has fired. While rotation is on (action rotate), the enemy's tired riders
##     and those with less than `wounded` per mille of their hp break off (unless fleeing), go
##     back to their camp (the wounded stay there till rotation ends) and, once `rested`,
##     attack-move to `post`;
##   crossbows {zone, reeds, shooter, every_ticks, damage, morale, cap}: once on (action
##     crossbows), every every_ticks each enemy unit in the zone (the field before the reeds of
##     the little lake) takes damage × the player's `shooter` units in the reeds (at most cap)
##     and loses morale: volleys from the front and the flank;
##   command {group, stand_in, morale, radius, keep_ticks, floor_permille}: while the group's
##     commander serves the player, every unit of the player gets `morale`; from the flag
##     wounded on, keep_ticks long the same, then only units within radius of the stand_in's
##     hero; the commander cannot fall below floor_permille of his HP;
##   leader {group, followers, morale, floor_permille, mortal_from}: until the trigger
##     mortal_from the leader cannot fall below floor_permille of his HP; once he is dead (flag
##     leader_dead) every member of the followers' groups loses `morale` points;
##   surrender {radius, silver, from, tabor: {rect, groups, every_ticks}}: from the flag `from`
##     on an enemy unit that flees or has no morale left, with a fighting unit of the player
##     within radius, lays down its arms (it leaves the map as a prisoner, the player gets
##     `silver` ransom); while a unit of the player stands in the tabor rect, every every_ticks
##     one member of the groups there surrenders;
##   charge {leash}: charging groups (action charge) keep attack-moving at the player's nearest
##     fighting unit within leash cells, or anyone there when no fighter is (but not riders
##     resting by the rotation).
## Conditions: clock {at_least} (minutes since midnight); hired {kind?, at_least}; ditch
##   {at_least} (permille); tabor_ready; in_zone {at_least}; prisoners {at_least}; unpaid
##   {at_least} (units that left unpaid); fleeing
##   {permille} (the player's fighting units running now, per mille of those alive);
##   camp_lost {ticks}; hiring.
## Actions: hire {on}; payday; crossbows {on}; rotate {on}; charge {group, on}; fall_back_order
##   (the player's horse may «fall back, not run»: the retreat order of the GDL); rest {player,
##   to} (the player's horse not fleeing rides there); hurt {group, permille} (its members are
##   left with at most that share of their HP: Raweneck wounded).

const CONDITIONS: Array[String] = [
	"clock",
	"hired",
	"ditch",
	"tabor_ready",
	"in_zone",
	"prisoners",
	"unpaid",
	"fleeing",
	"camp_lost",
	"hiring",
]
const ACTIONS: Array[String] = [
	"hire", "payday", "crossbows", "rotate", "charge", "fall_back_order", "rest", "hurt"
]
const FULL := 1000
const CHECK := MissionRuntime.CHECK_EVERY
## A charging group is sent again at the nearest unit this often (ticks).
const CHARGE_EVERY := 40
## A unit is in melee while it struck or was struck within this many ticks.
const MELEE_TICKS := 2 * MissionRuntime.CHECK_EVERY

var on := false
var player := 0
var enemy := 0
## Hiring: open, the question asked now, hired units -> wage, how many of each kind.
var hiring := false
var question := ""
var asked := 0
var wage: Dictionary[int, int] = {}
var hired_horse := 0
var hired_foot := 0
## Paydays held, units that left unpaid.
var paydays := 0
var deserted := 0
## The ditch: its cells in digging order, the work done and the cells dug.
var ditch_cells := PackedInt32Array()
var work := 0
var dug := 0
var chained := false
## Ticks the camp has been in enemy hands.
var camp_threat := 0
## Horses' strength by id (of FULL).
var stamina: Dictionary[int, int] = {}
## Enemy riders resting in their camp.
var resting: Dictionary[int, bool] = {}
var rotate_on := false
var crossbows_on := false
## Charging groups.
var charging := PackedStringArray()
## Prisoners taken, the next surrender in the tabor, the leader's death seen.
var prisoners := 0
var next_yield := -1
var leader_down := false
## Units the player had, to count the fallen.
var mustered := 0
## The tick being checked (for conditions; not state of its own).
var now := 0


func set_up(m: MissionRuntime) -> void:
	var r := _rules(m)
	if r.is_empty():
		return
	on = true
	player = int(r["player"])
	enemy = int(r["enemy"])
	mustered = _fighting_alive(m)
	var d: Dictionary = r.get("ditch", {})
	if not d.is_empty():
		ditch_cells = _ditch_order(m, d)


func step(m: MissionRuntime, tick: int) -> void:
	if not on:
		return
	now = tick
	var r := _rules(m)
	_hire(m, r.get("hire", {}), tick)
	_ditch(m, r.get("ditch", {}), tick)
	_camp(m, r.get("camp", {}))
	_fatigue(m, r.get("fatigue", {}), tick)
	_crossbows(m, r.get("crossbows", {}), tick)
	_command(m, r.get("command", {}), tick)
	_leader(m, r.get("leader", {}), tick)
	_surrender(m, r.get("surrender", {}), tick)
	if tick % CHARGE_EVERY == 0:
		for g in charging:
			_charge(m, g, int(r.get("charge", {}).get("leash", 60)), tick)


func test(m: MissionRuntime, c: Dictionary) -> bool:
	var ok := false
	match c["type"]:
		"clock":
			ok = minutes(m, now) >= int(c["at_least"])
		"hired":
			var n := hired_horse + hired_foot
			if c.get("kind", "") == "horse":
				n = hired_horse
			elif c.get("kind", "") == "foot":
				n = hired_foot
			ok = n >= int(c["at_least"])
		"ditch":
			ok = ditch_permille(m) >= int(c["at_least"])
		"tabor_ready":
			ok = tabor_ready(m)
		"in_zone":
			ok = in_zone(m) >= int(c["at_least"])
		"prisoners":
			ok = prisoners >= int(c["at_least"])
		"unpaid":
			ok = deserted >= int(c["at_least"])
		"fleeing":
			ok = fleeing_permille(m) >= int(c["permille"])
		"camp_lost":
			ok = camp_threat >= int(c["ticks"])
		"hiring":
			ok = hiring
	return ok


func run(m: MissionRuntime, a: Dictionary, tick: int) -> void:
	if not on:
		return
	match a["do"]:
		"hire":
			hiring = a.get("on", true)
			if not hiring and not question.is_empty():
				m.choices.erase(question)
				question = ""
		"payday":
			_pay(m, tick)
		"crossbows":
			crossbows_on = a.get("on", true)
		"rotate":
			rotate_on = a.get("on", true)
			if not rotate_on:
				resting.clear()
		"charge":
			var g: String = a["group"]
			if a.get("on", true):
				if not charging.has(g):
					charging.append(g)
					_charge(m, g, int(_rules(m).get("charge", {}).get("leash", 60)), tick)
			elif charging.has(g):
				charging.remove_at(charging.find(g))
		"fall_back_order":
			var e := m.entities
			for id in e.alive_ids:
				if e.owners[id - 1] == player and _is_horse(m, id - 1, true):
					m.combat.flags[id - 1] |= CombatSystem.F_RETREAT
			m.flags["fall_back"] = tick
		"rest":
			_rest(m, int(a["player"]), a["to"], tick)
		"hurt":
			for id in m.alive_of(a["group"]):
				var s := id - 1
				var hp := maxi(m.entities.max_hp[s] * int(a["permille"]) / FULL, 1)
				m.entities.hp[s] = mini(m.entities.hp[s], hp)


# --- for the panel, the layer and the bot ---------------------------------------------------


## Minutes since midnight on the mission's clock.
func minutes(m: MissionRuntime, tick: int) -> int:
	var d: Dictionary = _rules(m).get("day", {})
	if d.is_empty():
		return 0
	return int(d["start_minutes"]) + tick * 60 / maxi(int(d["ticks_per_hour"]), 1)


## The clock as «HH:MM», for the panel.
func clock_text(m: MissionRuntime, tick: int) -> String:
	var t := minutes(m, tick) % (24 * 60)
	return "%02d:%02d" % [t / 60, t % 60]


func ditch_permille(m: MissionRuntime) -> int:
	var need := int(_rules(m).get("ditch", {}).get("need", 0))
	return FULL if need <= 0 else mini(work * FULL / need, FULL)


## Whether a ring of the player's wagons stands at the camp and the ditch is dug.
func tabor_ready(m: MissionRuntime) -> bool:
	return ditch_permille(m) >= FULL and ring_at_camp(m)


func ring_at_camp(m: MissionRuntime) -> bool:
	var c: Dictionary = _rules(m).get("camp", {})
	if c.is_empty():
		return false
	var cr := m.combat.crown
	var at: Array = c["at"]
	var x := Fixed.from_cells(at[0]) + Fixed.HALF
	var y := Fixed.from_cells(at[1]) + Fixed.HALF
	var reach := Fixed.from_cells(int(c["radius"]))
	for i in cr.ring_owner.size():
		if cr.ring_owner[i] == player and Fixed.distance(x, y, cr.ring_x[i], cr.ring_y[i]) <= reach:
			return true
	return false


## The silver the next payday will cost.
func wages_due(m: MissionRuntime) -> int:
	var due := 0
	for id in _paid_now(m):
		due += _wage_of(m, id)
	return due


## Enemy units in the crossbows' zone now.
func in_zone(m: MissionRuntime) -> int:
	var cb: Dictionary = _rules(m).get("crossbows", {})
	if cb.is_empty():
		return 0
	var n := 0
	var e := m.entities
	for id in e.alive_ids:
		var s := id - 1
		if e.owners[s] == enemy and e.hp[s] > 0 and _in_rect(cb["zone"], e.pos_x[s], e.pos_y[s]):
			n += 1
	return n


## The player's fighting units running now, per mille of those alive.
func fleeing_permille(m: MissionRuntime) -> int:
	var e := m.entities
	var alive := 0
	var running := 0
	for id in e.alive_ids:
		var s := id - 1
		if e.owners[s] != player or not _fights(m, s):
			continue
		alive += 1
		if e.intents[s] == EntityStore.Intent.FLEE:
			running += 1
	return 0 if alive == 0 else running * FULL / alive


## The mean strength of the player's horses, per mille (FULL with none).
func player_stamina(m: MissionRuntime) -> int:
	var total := 0
	var n := 0
	for id: int in stamina:
		if m.entities.is_alive(id) and m.entities.owners[id - 1] == player:
			total += stamina[id]
			n += 1
	return FULL if n == 0 else total / n


## The player's units that fell (not those that left unpaid).
func fallen(m: MissionRuntime) -> int:
	return maxi(mustered - _fighting_alive(m) - deserted, 0)


func cell_dug(k: int) -> bool:
	return k < dug


# --- hiring and wages -----------------------------------------------------------------------


func _hire(m: MissionRuntime, h: Dictionary, tick: int) -> void:
	if h.is_empty() or not hiring:
		return
	var offers: Array = h["offers"]
	if not question.is_empty():
		for option in offers.size() + 1:
			if not m.flags.has(MissionRuntime.choice_flag(question, option)):
				continue
			question = ""
			if option >= offers.size():
				hiring = false
				m.flags["hiring_over"] = tick
				return
			_hire_one(m, h, offers[option], tick)
			break
		if not question.is_empty():
			return
	asked += 1
	question = "hire_%d" % asked
	var q: Dictionary = m.def.asks.get("hire", {})
	m.run({"do": "ask", "id": question, "text": q["text"], "options": q["options"]}, tick)


func _hire_one(m: MissionRuntime, h: Dictionary, offer: Array, tick: int) -> void:
	var kind: String = offer[3]
	var cap: Dictionary = h.get("max", {})
	var have := hired_horse if kind == "horse" else hired_foot
	if have >= int(cap.get(kind, 0)):
		m.flags["full_" + kind] = tick
		return
	var state := m.economy.player(player)
	if state == null or state.stock[EconomySystem.SILVER] < int(offer[1]):
		m.flags["no_silver"] = tick
		return
	state.stock[EconomySystem.SILVER] -= int(offer[1])
	var at: Array = h["at"]
	var k := hired_horse + hired_foot
	var x := Fixed.from_cells(int(at[0]) + k % 4) + Fixed.HALF
	var y := Fixed.from_cells(int(at[1]) + k / 4) + Fixed.HALF
	var id: int = m._spawn.call(StringName(offer[0]), player, x, y)
	if id == EntityStore.NO_ID:
		return
	wage[id] = int(offer[2])
	mustered += 1
	if kind == "horse":
		hired_horse += 1
		if m.flags.has("fall_back"):
			m.combat.flags[id - 1] |= CombatSystem.F_RETREAT
	else:
		hired_foot += 1
	m.flags["hired"] = tick


## Who is paid on this payday, in the order they are paid: the company first, then the hired.
func _paid_now(m: MissionRuntime) -> PackedInt32Array:
	var w: Dictionary = _rules(m).get("wages", {})
	var out := PackedInt32Array()
	var every := maxi(int(w.get("company_every", 1)), 1)
	if (paydays + 1) % every == 0:
		out.append_array(m.alive_of(str(w.get("company", ""))))
	var ids := wage.keys()
	ids.sort()
	for id: int in ids:
		if m.entities.is_alive(id):
			out.append(id)
	return out


func _wage_of(m: MissionRuntime, id: int) -> int:
	if wage.has(id):
		return wage[id]
	var type := String(m.entities.type_ids[id - 1])
	for offer: Array in _rules(m).get("hire", {}).get("offers", []):
		if offer[0] == type:
			return int(offer[2])
	return 0


func _pay(m: MissionRuntime, tick: int) -> void:
	var state := m.economy.player(player)
	if state == null:
		return
	var ids := _paid_now(m)
	paydays += 1
	var left := state.stock[EconomySystem.SILVER]
	var gone := PackedInt32Array()
	for id in ids:
		var owed := _wage_of(m, id)
		if left >= owed:
			left -= owed
		else:
			gone.append(id)
	state.stock[EconomySystem.SILVER] = left
	for id in gone:
		wage.erase(id)
		stamina.erase(id)
		deserted += 1
		m._remove.call(id)
	m.flags["paid"] = tick
	if not gone.is_empty():
		m.flags["deserted"] = tick


# --- the tabor and the ditch ----------------------------------------------------------------


## The band's cells, ring by ring from the outside, each ring clockwise from its top-left.
func _ditch_order(m: MissionRuntime, d: Dictionary) -> PackedInt32Array:
	var nav := m.combat.nav
	var outer: Array = d["outer"]
	var inner: Array = d["inner"]
	var out := PackedInt32Array()
	var seen := {}
	var x0 := int(outer[0])
	var y0 := int(outer[1])
	var x1 := int(outer[2])
	var y1 := int(outer[3])
	while x0 < int(inner[0]) and y0 < int(inner[1]) and x1 > int(inner[2]) and y1 > int(inner[3]):
		var ring: Array[Vector2i] = []
		for x in range(x0, x1 + 1):
			ring.append(Vector2i(x, y0))
		for y in range(y0 + 1, y1 + 1):
			ring.append(Vector2i(x1, y))
		for x in range(x1 - 1, x0 - 1, -1):
			ring.append(Vector2i(x, y1))
		for y in range(y1 - 1, y0, -1):
			ring.append(Vector2i(x0, y))
		for c in ring:
			if not nav.in_bounds(c.x, c.y) or _in_gap(d, c):
				continue
			var cell := nav.cell_at(c.x, c.y)
			if seen.has(cell) or nav.terrain_at(cell) == &"t_water":
				continue
			seen[cell] = true
			out.append(cell)
		x0 += 1
		y0 += 1
		x1 -= 1
		y1 -= 1
	return out


static func _in_gap(d: Dictionary, c: Vector2i) -> bool:
	for g: Array in d.get("gaps", []):
		if c.x >= int(g[0]) and c.y >= int(g[1]) and c.x <= int(g[2]) and c.y <= int(g[3]):
			return true
	return false


func _ditch(m: MissionRuntime, d: Dictionary, tick: int) -> void:
	if d.is_empty() or ditch_cells.is_empty():
		return
	var e := m.entities
	var need := int(d["need"])
	if work < need:
		var diggers := 0
		for id in e.alive_ids:
			var s := id - 1
			if e.owners[s] != player or e.orders[s] != EntityStore.Order.IDLE:
				continue
			var unit := m.combat.defs[s]
			if unit == null or not unit.has_class(&"infantry") or unit.has_class(&"hero"):
				continue
			if _in_rect(d["dig"], e.pos_x[s], e.pos_y[s]):
				diggers += 1
		work = mini(work + diggers * CHECK, need)
		var should := ditch_cells.size() * work / need
		var nav := m.combat.nav
		var t := nav.terrain_ids.find(StringName(d.get("terrain", "t_bog")))
		while dug < should and t >= 0:
			nav.set_terrain(ditch_cells[dug], t)
			dug += 1
		if work >= need:
			m.flags["ditch_done"] = tick
	# Horse on the ditch loses its run-up: no charge over it.
	if dug == 0:
		return
	var dugged := {}
	for k in dug:
		dugged[ditch_cells[k]] = true
	var nav2 := m.combat.nav
	for id in e.alive_ids:
		var s := id - 1
		if e.owners[s] == player or not _is_horse(m, s, true):
			continue
		if dugged.has(nav2.cell_of(e.pos_x[s], e.pos_y[s])):
			e.run[s] = 0


func _camp(m: MissionRuntime, c: Dictionary) -> void:
	if c.is_empty():
		return
	if not chained and tabor_ready(m):
		chained = true
		m.flags["chained"] = now
	if chained:
		for id in m.alive_of(str(c.get("wagons", ""))):
			m.combat.untouchable[id] = true
	var at: Array = c["at"]
	var x := Fixed.from_cells(at[0]) + Fixed.HALF
	var y := Fixed.from_cells(at[1]) + Fixed.HALF
	var reach := Fixed.from_cells(int(c["radius"]))
	var e := m.entities
	var theirs := 0
	var ours := 0
	for id in m.combat.buckets.near(x, y, reach):
		var s := id - 1
		if e.hp[s] <= 0 or Fixed.distance(x, y, e.pos_x[s], e.pos_y[s]) > reach:
			continue
		if not _fights(m, s) or e.intents[s] == EntityStore.Intent.FLEE:
			continue
		if e.owners[s] == player:
			ours += 1
		elif e.owners[s] == enemy:
			theirs += 1
	if theirs >= int(c.get("lost_units", 3)) and ours == 0:
		camp_threat += CHECK
	else:
		camp_threat = 0


# --- the horses tire ------------------------------------------------------------------------


func _fatigue(m: MissionRuntime, f: Dictionary, tick: int) -> void:
	if f.is_empty():
		return
	var e := m.entities
	var players: Array = f["players"]
	var drain: Dictionary = f.get("drain", {})
	var camps: Dictionary = f.get("camps", {})
	var near_camp := Fixed.from_cells(int(f.get("camp_radius", 8)))
	var floor_permille := int(f.get("floor", 300))
	var tired := int(f.get("tired", 400))
	var crown := m.combat.crown
	# The long morning: the riders skirmish and wheel away, so blows land seldom until `until`.
	var skirmish: Dictionary = f.get("skirmish", {})
	var base := FULL
	if not skirmish.is_empty() and not m.fired.has(String(skirmish.get("until", ""))):
		base = int(skirmish.get("damage", FULL))
	for id in e.alive_ids:
		var s := id - 1
		if not players.has(e.owners[s]) or not _is_horse(m, s, false):
			continue
		var left: int = stamina.get(id, FULL)
		var k := int(drain.get(String(e.type_ids[s]), FULL))
		if e.calm[s] < MELEE_TICKS:
			left -= int(f["fight"]) * k / FULL
		elif e.moved[s] == 1:
			left -= int(f["ride"]) * k / FULL
		elif _at_camp(e, s, camps, near_camp):
			left += int(f["camp_rest"])
		else:
			left += int(f["rest"])
		left = clampi(left, 0, FULL)
		stamina[id] = left
		var full := m.combat.defs[s].morale * CombatSystem.MORALE_SCALE
		var cap := full * (floor_permille + (FULL - floor_permille) * left / FULL) / FULL
		if e.morale[s] > cap:
			e.morale[s] = cap
		var dmg := base
		if left < tired:
			dmg = dmg * int(f.get("tired_damage", FULL)) / FULL
		if dmg != FULL:
			crown.mission_damage[id] = dmg
		else:
			crown.mission_damage.erase(id)
	for id: int in stamina.keys():
		if not e.is_alive(id):
			stamina.erase(id)
			resting.erase(id)
			crown.mission_damage.erase(id)
	if rotate_on:
		_rotate(m, f, camps, near_camp, tick)


func _at_camp(e: EntityStore, s: int, camps: Dictionary, reach: int) -> bool:
	var at: Array = camps.get(str(e.owners[s]), [])
	if at.is_empty():
		return false
	var x := Fixed.from_cells(at[0]) + Fixed.HALF
	var y := Fixed.from_cells(at[1]) + Fixed.HALF
	return Fixed.distance(x, y, e.pos_x[s], e.pos_y[s]) <= reach


## The enemy's tired riders break off, go back to rest and come out again rested.
func _rotate(m: MissionRuntime, f: Dictionary, camps: Dictionary, reach: int, tick: int) -> void:
	var e := m.entities
	var at: Array = camps.get(str(enemy), [])
	if at.is_empty():
		return
	var home_x := Fixed.from_cells(at[0]) + Fixed.HALF
	var home_y := Fixed.from_cells(at[1]) + Fixed.HALF
	var post: Array = f.get("post", at)
	var post_x := Fixed.from_cells(post[0]) + Fixed.HALF
	var post_y := Fixed.from_cells(post[1]) + Fixed.HALF
	var ids := stamina.keys()
	ids.sort()
	var home := PackedInt32Array()
	var out := PackedInt32Array()
	for id: int in ids:
		var s := id - 1
		if e.owners[s] != enemy or e.intents[s] == EntityStore.Intent.FLEE:
			continue
		var hurt := e.hp[s] * FULL < int(f.get("wounded", 0)) * e.max_hp[s]
		if resting.has(id):
			var idle := e.intents[s] == EntityStore.Intent.NONE
			if idle and stamina[id] >= int(f.get("rested", 800)) and _at_camp(e, s, camps, reach):
				if not hurt:
					resting.erase(id)
					out.append(id)
		elif stamina[id] < int(f.get("tired", 400)) or hurt:
			resting[id] = true
			home.append(id)
	if not home.is_empty():
		m._apply.call(SimCommand.move(tick, enemy, home, home_x, home_y))
	if not out.is_empty():
		m._apply.call(SimCommand.attack_move(tick, enemy, out, post_x, post_y))


# --- the crossbows, the command, the leader -------------------------------------------------


func _crossbows(m: MissionRuntime, cb: Dictionary, tick: int) -> void:
	if cb.is_empty() or not crossbows_on or tick % int(cb["every_ticks"]) != 0:
		return
	var e := m.entities
	var shooter := StringName(cb["shooter"])
	var shooters := 0
	for id in e.alive_ids:
		var s := id - 1
		if e.owners[s] == player and e.type_ids[s] == shooter and e.hp[s] > 0:
			if (
				e.intents[s] != EntityStore.Intent.FLEE
				and _in_rect(cb["reeds"], e.pos_x[s], e.pos_y[s])
			):
				shooters += 1
	shooters = mini(shooters, int(cb.get("cap", 4)))
	if shooters == 0:
		return
	var hit := PackedInt32Array()
	for id in e.alive_ids:
		var s := id - 1
		if e.owners[s] == enemy and e.hp[s] > 0 and _in_rect(cb["zone"], e.pos_x[s], e.pos_y[s]):
			if not m.combat.untouchable.has(id) and _fights(m, s):
				hit.append(id)
	for id in hit:
		m.combat.lightning(id, player, int(cb["damage"]) * shooters)
		if e.is_alive(id):
			m.combat.lose_morale(id - 1, int(cb.get("morale", 0)))
	if not hit.is_empty():
		m.flags["volley"] = tick


func _command(m: MissionRuntime, c: Dictionary, tick: int) -> void:
	if c.is_empty():
		return
	var crown := m.combat.crown
	crown.army_morale.erase(player)
	crown.mission_morale.clear()
	var head := m.alive_of(c["group"])
	# The commander cannot fall; he only drops out wounded, when the story says so.
	for id in head:
		var floor_hp := m.entities.max_hp[id - 1] * int(c.get("floor_permille", 0)) / FULL
		if floor_hp > 0:
			m.combat.hp_floor[id] = floor_hp
	var serving := not head.is_empty() and m.entities.owners[head[0] - 1] == player
	var wounded := int(m.flags.get("wounded", -1))
	if wounded >= 0 and tick - wounded < int(c.get("keep_ticks", 0)):
		serving = true
	if serving:
		crown.army_morale[player] = int(c["morale"])
		return
	var stand := m.alive_of(c["stand_in"])
	if stand.is_empty():
		return
	var e := m.entities
	var s := stand[0] - 1
	var reach := Fixed.from_cells(int(c["radius"]))
	for id in m.combat.buckets.near(e.pos_x[s], e.pos_y[s], reach):
		var o := id - 1
		if e.owners[o] != player:
			continue
		if Fixed.distance(e.pos_x[s], e.pos_y[s], e.pos_x[o], e.pos_y[o]) <= reach:
			crown.mission_morale[id] = int(c["morale"])


## Whether the player's command is in Stach's hands now (Dunin bandaged in the tabor).
func stand_in_commands(m: MissionRuntime) -> bool:
	var c: Dictionary = _rules(m).get("command", {})
	if c.is_empty():
		return false
	var head := m.alive_of(c["group"])
	return head.is_empty() or m.entities.owners[head[0] - 1] != player


func _leader(m: MissionRuntime, l: Dictionary, tick: int) -> void:
	if l.is_empty() or leader_down:
		return
	var ids := m.alive_of(l["group"])
	var e := m.entities
	if not ids.is_empty():
		var s := ids[0] - 1
		if m.fired.has(str(l.get("mortal_from", ""))):
			m.combat.hp_floor.erase(ids[0])
		else:
			m.combat.hp_floor[ids[0]] = maxi(e.max_hp[s] * int(l["floor_permille"]) / FULL, 1)
		if e.hp[s] > 0:
			return
	if not m.groups.has(l["group"]):
		return
	leader_down = true
	m.flags["leader_dead"] = tick
	for g: String in l.get("followers", []):
		for id in m.alive_of(g):
			m.combat.lose_morale(id - 1, int(l["morale"]))


func _surrender(m: MissionRuntime, sr: Dictionary, tick: int) -> void:
	if sr.is_empty() or not m.flags.has(str(sr.get("from", ""))):
		return
	var e := m.entities
	var reach := Fixed.from_cells(int(sr["radius"]))
	var taken := PackedInt32Array()
	for id in e.alive_ids:
		var s := id - 1
		if e.owners[s] != enemy or e.hp[s] <= 0 or m.combat.untouchable.has(id):
			continue
		if not _fights(m, s) or m.combat.flags[s] & CombatSystem.F_HERO:
			continue
		if e.intents[s] != EntityStore.Intent.FLEE and e.morale[s] > 0:
			continue
		if _player_near(m, s, reach):
			taken.append(id)
	var t: Dictionary = sr.get("tabor", {})
	if not t.is_empty() and tick >= next_yield and _player_in(m, t["rect"]):
		next_yield = tick + int(t["every_ticks"])
		for g: String in t["groups"]:
			var ids := m.alive_of(g)
			if not ids.is_empty() and not taken.has(ids[0]):
				taken.append(ids[0])
				break
	for id in taken:
		_take(m, id, int(sr.get("silver", 0)), tick)


func _take(m: MissionRuntime, id: int, silver: int, tick: int) -> void:
	prisoners += 1
	m.flags["prisoner"] = tick
	m.combat.hp_floor.erase(id)
	stamina.erase(id)
	resting.erase(id)
	m.combat.crown.mission_damage.erase(id)
	m._remove.call(id)
	var state := m.economy.player(player)
	if state != null:
		state.stock[EconomySystem.SILVER] += silver


func _player_near(m: MissionRuntime, s: int, reach: int) -> bool:
	var e := m.entities
	for other in m.combat.buckets.near(e.pos_x[s], e.pos_y[s], reach):
		var o := other - 1
		if e.owners[o] != player or e.hp[o] <= 0 or not _fights(m, o):
			continue
		if e.intents[o] == EntityStore.Intent.FLEE:
			continue
		if Fixed.distance(e.pos_x[s], e.pos_y[s], e.pos_x[o], e.pos_y[o]) <= reach:
			return true
	return false


func _player_in(m: MissionRuntime, rect: Array) -> bool:
	var e := m.entities
	for id in e.alive_ids:
		var s := id - 1
		if e.owners[s] == player and e.hp[s] > 0 and _fights(m, s):
			if _in_rect(rect, e.pos_x[s], e.pos_y[s]):
				return true
	return false


# --- orders ---------------------------------------------------------------------------------


func _charge(m: MissionRuntime, g: String, leash_cells: int, tick: int) -> void:
	var ids := m.alive_of(g)
	if ids.is_empty():
		return
	var e := m.entities
	var lead := ids[0] - 1
	var leash := Fixed.from_cells(leash_cells)
	# The nearest fighting unit of the player; anyone else only when no fighter is in reach.
	var best := 0
	var best_d := 0
	var best_fights := false
	for id in e.alive_ids:
		var s := id - 1
		if e.owners[s] != player or e.hp[s] <= 0 or m.combat.untouchable.has(id):
			continue
		var d := Fixed.distance(e.pos_x[lead], e.pos_y[lead], e.pos_x[s], e.pos_y[s])
		if d > leash:
			continue
		var fights := _fights(m, s)
		if best == 0 or (fights and not best_fights) or (fights == best_fights and d < best_d):
			best = id
			best_d = d
			best_fights = fights
	var free := PackedInt32Array()
	for id in ids:
		var s := id - 1
		if e.target[s] == EntityStore.NO_ID and e.intents[s] == EntityStore.Intent.NONE:
			if not resting.has(id):
				free.append(id)
	if best != 0 and not free.is_empty():
		var x := e.pos_x[best - 1]
		var y := e.pos_y[best - 1]
		m._apply.call(SimCommand.attack_move(tick, e.owners[lead], free, x, y))


func _rest(m: MissionRuntime, p: int, to: Array, tick: int) -> void:
	var e := m.entities
	var ids := PackedInt32Array()
	for id in e.alive_ids:
		var s := id - 1
		if e.owners[s] == p and _is_horse(m, s, true) and e.intents[s] == EntityStore.Intent.NONE:
			ids.append(id)
	if ids.is_empty():
		return
	var x := Fixed.from_cells(to[0]) + Fixed.HALF
	var y := Fixed.from_cells(to[1]) + Fixed.HALF
	m._apply.call(SimCommand.move(tick, p, ids, x, y))


# --- the rest -------------------------------------------------------------------------------


## Cavalry (heroes too when `heroes`).
func _is_horse(m: MissionRuntime, s: int, heroes: bool) -> bool:
	var unit := m.combat.defs[s]
	if unit == null or not unit.has_class(&"cavalry"):
		return false
	return heroes or not unit.has_class(&"hero")


## A unit that fights: not a wagon, a priest, a hero or anyone who never fights.
func _fights(m: MissionRuntime, s: int) -> bool:
	var unit := m.combat.defs[s]
	if unit == null or unit.damage <= 0 or unit.has_class(&"hero"):
		return false
	for cls: StringName in CombatSystem.PASSIVE_CLASSES:
		if unit.has_class(cls):
			return false
	return not unit.has_class(&"siege")


func _fighting_alive(m: MissionRuntime) -> int:
	var n := 0
	for id in m.entities.alive_ids:
		if m.entities.owners[id - 1] == player and _fights(m, id - 1):
			n += 1
	return n


static func _in_rect(rect: Array, x: int, y: int) -> bool:
	var cx := Fixed.to_cells(x)
	var cy := Fixed.to_cells(y)
	return cx >= int(rect[0]) and cy >= int(rect[1]) and cx <= int(rect[2]) and cy <= int(rect[3])


func _rules(m: MissionRuntime) -> Dictionary:
	return m.def.rules.get("swiecino", {})


func write_to(buf: StreamPeerBuffer) -> void:
	# Nothing outside this mission, so older replays keep their hashes.
	if not on:
		return
	buf.put_8(1 if hiring else 0)
	buf.put_utf8_string(question)
	buf.put_32(asked)
	for d: Dictionary in [wage, stamina]:
		var ids := d.keys()
		ids.sort()
		buf.put_32(ids.size())
		for id: int in ids:
			buf.put_32(id)
			buf.put_32(int(d[id]))
	var rest := resting.keys()
	rest.sort()
	buf.put_32(rest.size())
	for id: int in rest:
		buf.put_32(id)
	for v: int in [hired_horse, hired_foot, paydays, deserted, work, dug, camp_threat, prisoners]:
		buf.put_32(v)
	for b: bool in [chained, rotate_on, crossbows_on, leader_down]:
		buf.put_8(1 if b else 0)
	buf.put_64(next_yield)
	buf.put_32(mustered)
	buf.put_32(charging.size())
	for g in charging:
		buf.put_utf8_string(g)
