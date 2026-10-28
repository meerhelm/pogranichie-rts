class_name MissionBaltic
extends RefCounted
## The rules of «Корона 3. Балтийская вода, 1433» (def.rules.baltic), run by MissionRuntime.step()
## on this object's state, which the runtime's save and hash carry: the march with the Czech
## «orphans» of Jan Čapek, an ally with a will of its own, from Chojnice to the sea. The
## wagenburg at every camp, the wind that carries the fire of Tczew's suburb to its wall, the
## «Согласие» (concord) between the Crown's commander and Čapek, the orphans following their
## leaders, plundering villages first and breaking chapels nobody of the Crown guards, the
## prisoners of Tczew and the knighting on the shore.
##
## Rules (baltic {player, hussites, crown: [players], ...}):
##   concord {start, mutiny_ticks, reset}: permille. At 0 the orphans stop listening for
##     mutiny_ticks (they stand where they are and follow nobody; flag mutiny, counted by
##     mutinies), then it starts again from `reset` (flag mutiny_over);
##   follow [[group, leader group, far cells], ...]: every FOLLOW_EVERY ticks (from the trigger
##     follow_from on, if given) the group's members farther than `far` from the leader's first
##     living member walk (attack-move) to him;
##   camps [{at, radius}, ...]: a camp is held while a tabor ring of the player stands within
##     radius of `at` (CrownTactics rings); every camp once held counts (flag camp_<i>);
##   wind {rect, dx, dy, reach, heat_cells, heat_damage, gate, burnt}: buildings in the rect (the
##     suburb) burn as wood and catch fire only from the wind: every WIND_EVERY ticks a burning
##     one sets alight those downwind (ahead along (dx, dy), at most `reach` cells off its line
##     and away) and scorches every unit within heat_cells downwind of it; once `burnt` of them
##     are gone the fire takes the named wooden `gate` (flag suburb_burnt);
##   surrender {rect, groups, from, every_ticks, count}: after the trigger `from`, while a unit of
##     the player stands in the rect, every every_ticks `count` members of the groups lay down
##     their arms (leave the map, counted by surrendered);
##   prisoners {group, killers, to, radius, kill_radius, silver}: once hunting (action prisoners)
##     the killers walk at the nearest prisoner and kill those within kill_radius; a prisoner
##     brought within radius of the `to` group's first member is ransomed (leaves the map, the
##     player gets `silver`);
##   forage {villages: [named buildings], radius, amount: [food, wood, iron, silver]}: the first
##     side to come within radius of a village takes it: the player gets `amount`, the orphans
##     burn it; a village gives once;
##   chapels {radius, ticks}: a shrine of the crown players on a place of power with orphans
##     within radius and nobody of the crown for `ticks` is broken (flag chapel_broken);
##   hungry {every_ticks, permille}: while the player has no food, every every_ticks each of
##     his units loses that share of its full morale;
##   knighting {questions, groups}: the answers to the questions (option i: groups[i], past the
##     end: nobody) knight those groups of the player (counted by knighted, flag knights).
## Conditions: concord {at_least | at_most}; mutinies {at_least}; camp_held {camp}; camps_held
##   {at_least}; surrendered {at_least}; ransomed {at_least}; prisoners_killed {at_least};
##   prisoners_left {at_most}; foraged {by: player | orphans, at_least}; knighted {at_least}.
## Actions: concord {add}; prisoners {on}; tabor {group} (the group's wagons draw up a ring).

const CONDITIONS: Array[String] = [
	"concord",
	"mutinies",
	"camp_held",
	"camps_held",
	"surrendered",
	"ransomed",
	"prisoners_killed",
	"prisoners_left",
	"foraged",
	"knighted",
]
const ACTIONS: Array[String] = ["concord", "prisoners", "tabor"]
const FOLLOW_EVERY := 100
const WIND_EVERY := 100
## Concord is kept in permille.
const CONCORD_MAX := 1000

## Whether the mission has these rules (the state hash carries nothing otherwise).
var on := false
var concord := 0
var mutinies := 0
## The tick the orphans' mutiny ends (-1: none now).
var mutiny_until := -1
## Camps held now and ever (a bit per camp).
var camps_now := 0
var camps_ever := 0
## The suburb's buildings and the wind's fire (only those it set alight count as burning by it).
var suburb := PackedInt32Array()
var gate_lit := false
var surrendered := 0
var hunting := false
var ransomed := 0
var killed := 0
## Villages taken: name -> 1 by the player, 2 by the orphans.
var villages: Dictionary[String, int] = {}
## Ticks the orphans have stood unguarded at a shrine, by place index; and shrines broken.
var unguarded: Dictionary[int, int] = {}
var broken := 0
## Groups knighted, in order, and the questions already answered.
var knights := PackedStringArray()
var answered := PackedStringArray()


func set_up(m: MissionRuntime) -> void:
	var r := _rules(m)
	if r.is_empty():
		return
	on = true
	concord = Num.of(r.get("concord", {}).get("start", CONCORD_MAX))
	var w: Dictionary = r.get("wind", {})
	if not w.is_empty():
		var store := m.economy.buildings
		var rect: Array = w["rect"]
		for b in store.alive_ids:
			if _in_rect(rect, store.center_x(b), store.center_y(b)):
				suburb.append(b)
				m.fire.wooden[b] = true
				m.fire.no_spread[b] = true
		var g: int = m.named.get(w.get("gate", ""), 0)
		if g != 0:
			m.fire.wooden[g] = true
			m.fire.no_spread[g] = true


func step(m: MissionRuntime, tick: int) -> void:
	if not on:
		return
	var r := _rules(m)
	_mutiny(m, r, tick)
	var marching := not r.has("follow_from") or m.fired.has(r["follow_from"])
	if tick % FOLLOW_EVERY == 0 and mutiny_until < 0 and marching:
		_follow(m, r, tick)
	_camps(m, r, tick)
	if tick % WIND_EVERY == 0:
		_wind(m, r.get("wind", {}), tick)
	_fan_gate(m, r.get("wind", {}))
	_surrender(m, r.get("surrender", {}), tick)
	_prisoners(m, r.get("prisoners", {}), tick)
	_forage(m, r.get("forage", {}), tick)
	_chapels(m, r.get("chapels", {}), tick)
	_hungry(m, r.get("hungry", {}), tick)
	_knighting(m, r.get("knighting", {}), tick)


func test(m: MissionRuntime, c: Dictionary) -> bool:
	var ok := false
	match c["type"]:
		"concord":
			ok = not c.has("at_least") or concord >= Num.of(c["at_least"])
			ok = ok and (not c.has("at_most") or concord <= Num.of(c["at_most"]))
		"mutinies":
			ok = mutinies >= Num.of(c["at_least"])
		"camp_held":
			ok = camps_now & (1 << Num.of(c["camp"])) != 0
		"camps_held":
			ok = _bits(camps_ever) >= Num.of(c["at_least"])
		"surrendered":
			ok = surrendered >= Num.of(c["at_least"])
		"ransomed":
			ok = ransomed >= Num.of(c["at_least"])
		"prisoners_killed":
			ok = killed >= Num.of(c["at_least"])
		"prisoners_left":
			var group: String = _rules(m).get("prisoners", {}).get("group", "")
			ok = m.alive_of(group).size() <= Num.of(c["at_most"])
		"foraged":
			ok = foraged(1 if c["by"] == "player" else 2) >= Num.of(c["at_least"])
		"knighted":
			ok = knights.size() >= Num.of(c["at_least"])
	return ok


func run(m: MissionRuntime, a: Dictionary, tick: int) -> void:
	if not on:
		return
	match a["do"]:
		"concord":
			add_concord(m, Num.of(a["add"]), tick)
		"prisoners":
			hunting = a.get("on", true)
		"tabor":
			var ids := m.alive_of(str(a["group"]))
			if not ids.is_empty():
				var owner := m.entities.owners[ids[0] - 1]
				m._apply.call(SimCommand.order(tick, owner, SimCommand.Kind.TABOR, ids))


## Concord moves by `add` permille (within 0..1000); at 0 the orphans mutiny.
func add_concord(m: MissionRuntime, add: int, tick: int) -> void:
	if mutiny_until >= 0:
		return
	concord = clampi(concord + add, 0, CONCORD_MAX)
	if concord > 0:
		return
	var c: Dictionary = _rules(m).get("concord", {})
	mutinies += 1
	mutiny_until = tick + Num.of(c.get("mutiny_ticks", 2400))
	m.flags["mutiny"] = tick
	var ids := _orphans(m)
	if not ids.is_empty():
		var p := Num.of(_rules(m)["hussites"])
		m._apply.call(SimCommand.stop(tick, p, ids))
		m._apply.call(SimCommand.set_stance(tick, p, ids, EntityStore.Stance.STAND))


## How many villages that side (1: the player, 2: the orphans) has taken.
func foraged(by: int) -> int:
	var n := 0
	for v: String in villages:
		if villages[v] == by:
			n += 1
	return n


func camps_count() -> int:
	return _bits(camps_ever)


func camps_total(m: MissionRuntime) -> int:
	return (_rules(m).get("camps", []) as Array).size()


# --- the orphans ---------------------------------------------------------------------------


func _orphans(m: MissionRuntime) -> PackedInt32Array:
	var p := Num.of(_rules(m)["hussites"])
	var out := PackedInt32Array()
	for id in m.entities.alive_ids:
		if m.entities.owners[id - 1] == p:
			out.append(id)
	return out


func _mutiny(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	if mutiny_until < 0 or tick < mutiny_until:
		return
	mutiny_until = -1
	concord = Num.of(r.get("concord", {}).get("reset", 400))
	m.flags["mutiny_over"] = tick
	var ids := _orphans(m)
	if not ids.is_empty():
		var p := Num.of(r["hussites"])
		m._apply.call(SimCommand.set_stance(tick, p, ids, EntityStore.Stance.AGGRESSIVE))


func _follow(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	var e := m.entities
	for f: Array in r.get("follow", []):
		var leaders := m.alive_of(str(f[1]))
		if leaders.is_empty():
			continue
		var lead := leaders[0] - 1
		var far := Fixed.from_cells(Num.of(f[2]))
		var lx := e.pos_x[lead]
		var ly := e.pos_y[lead]
		var away := PackedInt32Array()
		for id in m.alive_of(str(f[0])):
			var s := id - 1
			if e.target[s] != EntityStore.NO_ID:
				continue
			if Fixed.distance(lx, ly, e.pos_x[s], e.pos_y[s]) > far:
				away.append(id)
		if not away.is_empty():
			m._apply.call(SimCommand.attack_move(tick, e.owners[away[0] - 1], away, lx, ly))


# --- camps --------------------------------------------------------------------------------


func _camps(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	var camps: Array = r.get("camps", [])
	var crown: CrownTactics = m.combat.crown
	var p := Num.of(r["player"])
	camps_now = 0
	for i in camps.size():
		var c: Dictionary = camps[i]
		var at: Array = c["at"]
		var x := Fixed.from_cells(Num.of(at[0])) + Fixed.HALF
		var y := Fixed.from_cells(Num.of(at[1])) + Fixed.HALF
		var reach := Fixed.from_cells(Num.of(c["radius"]))
		for k in crown.ring_owner.size():
			if crown.ring_owner[k] != p:
				continue
			if Fixed.distance(x, y, crown.ring_x[k], crown.ring_y[k]) <= reach:
				camps_now |= 1 << i
				break
		if camps_now & (1 << i) and not camps_ever & (1 << i):
			camps_ever |= 1 << i
			m.flags["camp_%d" % i] = tick


# --- the wind -----------------------------------------------------------------------------


func _wind(m: MissionRuntime, w: Dictionary, tick: int) -> void:
	if w.is_empty():
		return
	var store := m.economy.buildings
	var fire := m.fire
	var dx := Num.of(w["dx"])
	var dy := Num.of(w["dy"])
	var reach := Num.of(w["reach"])
	var lit := PackedInt32Array()
	var gone := 0
	for b in suburb:
		if not store.is_alive(b):
			gone += 1
			continue
		if not fire.is_burning(b):
			continue
		var bx := store.center_x(b)
		var by := store.center_y(b)
		for o in suburb:
			if o == b or not store.is_alive(o) or not fire.flammable(o) or lit.has(o):
				continue
			if _downwind(bx, by, store.center_x(o), store.center_y(o), dx, dy, reach):
				lit.append(o)
		_scorch(m, w, bx, by, dx, dy)
	for o in lit:
		fire.ignite(o)
	if not gate_lit and gone >= Num.of(w["burnt"]):
		gate_lit = true
		m.flags["suburb_burnt"] = tick
		var g: int = m.named.get(w.get("gate", ""), 0)
		if store.is_alive(g):
			# The gate's oak leaves burn even in a brick gatehouse.
			fire.wooden[g] = true
			fire.ignite(g)
			var at := [Fixed.to_cells(store.center_x(g)), Fixed.to_cells(store.center_y(g))]
			m.run({"do": "ping", "at": at, "radius": 3}, tick)


## Once lit, the wind keeps fanning the gate: the garrison cannot put it out.
func _fan_gate(m: MissionRuntime, w: Dictionary) -> void:
	if not gate_lit:
		return
	var g: int = m.named.get(w.get("gate", ""), 0)
	if not m.economy.buildings.is_alive(g):
		return
	if m.fire.is_burning(g):
		m.fire.doused[g] = 0
	else:
		m.fire.ignite(g)


## Whether (ox, oy) lies ahead of (bx, by) along the wind, within `reach` cells of it both ways.
static func _downwind(bx: int, by: int, ox: int, oy: int, dx: int, dy: int, reach: int) -> bool:
	var rx := ox - bx
	var ry := oy - by
	var along := rx * dx + ry * dy
	if along <= 0:
		return false
	var side := absi(rx * dy - ry * dx)
	var r := Fixed.from_cells(reach)
	return along <= r and side <= r


## Units within heat_cells downwind of a burning building lose heat_damage HP.
func _scorch(m: MissionRuntime, w: Dictionary, bx: int, by: int, dx: int, dy: int) -> void:
	var e := m.entities
	var cells := Num.of(w["heat_cells"])
	var hurt := PackedInt32Array()
	for id in m.combat.buckets.near(bx, by, Fixed.from_cells(cells)):
		var s := id - 1
		if e.hp[s] > 0 and _downwind(bx, by, e.pos_x[s], e.pos_y[s], dx, dy, cells):
			hurt.append(id)
	hurt.sort()
	for id in hurt:
		if m.entities.is_alive(id):
			m.combat.lightning(id, 0, Num.of(w["heat_damage"]))


# --- the town and its prisoners -----------------------------------------------------------


func _surrender(m: MissionRuntime, s: Dictionary, tick: int) -> void:
	if s.is_empty() or not m.fired.has(s["from"]) or tick % Num.of(s["every_ticks"]) != 0:
		return
	var rect: Array = s["rect"]
	var e := m.entities
	var p := Num.of(_rules(m)["player"])
	var inside := false
	for id in e.alive_ids:
		if e.owners[id - 1] == p and _in_rect(rect, e.pos_x[id - 1], e.pos_y[id - 1]):
			inside = true
			break
	if not inside:
		return
	var left := Num.of(s["count"])
	for g: String in s["groups"]:
		for id in m.alive_of(g):
			if left == 0:
				return
			left -= 1
			surrendered += 1
			m.flags["surrender"] = tick
			var at := [Fixed.to_cells(e.pos_x[id - 1]), Fixed.to_cells(e.pos_y[id - 1])]
			m.run({"do": "ping", "at": at, "radius": 1}, tick)
			m._remove.call(id)


func _prisoners(m: MissionRuntime, pr: Dictionary, tick: int) -> void:
	if pr.is_empty():
		return
	var e := m.entities
	var held := m.alive_of(str(pr["group"]))
	if held.is_empty():
		return
	var to := m.alive_of(str(pr["to"]))
	if not to.is_empty():
		var tx := e.pos_x[to[0] - 1]
		var ty := e.pos_y[to[0] - 1]
		var reach := Fixed.from_cells(Num.of(pr["radius"]))
		for id in held:
			if Fixed.distance(tx, ty, e.pos_x[id - 1], e.pos_y[id - 1]) <= reach:
				ransomed += 1
				m.flags["ransomed"] = tick
				var state := m.economy.player(m.def.player)
				if state != null:
					state.stock[EconomySystem.SILVER] += Num.of(pr.get("silver", 0))
				m._remove.call(id)
		held = m.alive_of(str(pr["group"]))
	if not hunting or held.is_empty():
		return
	var kill := Fixed.from_cells(Num.of(pr["kill_radius"]))
	for k in m.alive_of(str(pr["killers"])):
		var kx := e.pos_x[k - 1]
		var ky := e.pos_y[k - 1]
		var best := 0
		var best_d := 0
		for id in held:
			if not e.is_alive(id) or e.hp[id - 1] <= 0:
				continue
			var d := Fixed.distance(kx, ky, e.pos_x[id - 1], e.pos_y[id - 1])
			if d <= kill:
				killed += 1
				m.flags["prisoner_killed"] = tick
				m.combat.lightning(id, e.owners[k - 1], e.hp[id - 1])
				continue
			if best == 0 or d < best_d:
				best = id
				best_d = d
		if best != 0:
			var one := PackedInt32Array([k])
			var bx := e.pos_x[best - 1]
			var by := e.pos_y[best - 1]
			m._apply.call(SimCommand.move(tick, e.owners[k - 1], one, bx, by))


# --- villages, chapels, hunger ------------------------------------------------------------


func _forage(m: MissionRuntime, f: Dictionary, tick: int) -> void:
	if f.is_empty():
		return
	var store := m.economy.buildings
	var reach := Fixed.from_cells(Num.of(f["radius"]))
	var r := _rules(m)
	var p := Num.of(r["player"])
	var orphans := Num.of(r["hussites"])
	for v: String in f["villages"]:
		if villages.has(v):
			continue
		var b: int = m.named.get(v, 0)
		if not store.is_alive(b):
			continue
		var bx := store.center_x(b)
		var by := store.center_y(b)
		var by_player := false
		var by_orphans := false
		for id in m.combat.buckets.near(bx, by, reach):
			var s := id - 1
			if m.entities.hp[s] <= 0:
				continue
			if Fixed.distance(bx, by, m.entities.pos_x[s], m.entities.pos_y[s]) > reach:
				continue
			by_player = by_player or m.entities.owners[s] == p
			by_orphans = by_orphans or m.entities.owners[s] == orphans
		if by_player:
			villages[v] = 1
			m.flags["foraged"] = tick
			var state := m.economy.player(p)
			var amount: Array = f["amount"]
			for k in amount.size():
				state.stock[k] += Num.of(amount[k])
			m.run({"do": "ping", "at": [Fixed.to_cells(bx), Fixed.to_cells(by)], "radius": 2}, tick)
		elif by_orphans:
			villages[v] = 2
			m.flags["plundered"] = tick
			m.fire.wooden[b] = true
			m.fire.ignite(b)


func _chapels(m: MissionRuntime, c: Dictionary, tick: int) -> void:
	if c.is_empty():
		return
	var places := m.magic.places
	var r := _rules(m)
	var crown: Array = r.get("crown", [r["player"]])
	var orphans := Num.of(r["hussites"])
	var reach := Fixed.from_cells(Num.of(c["radius"]))
	var e := m.entities
	for i in places.count():
		var b := places.shrines[i]
		if b == 0 or not crown.has(places.holders[i]):
			unguarded.erase(i)
			continue
		var cell := places.cells[i]
		var x := m.magic.nav.center_x(cell) + Fixed.HALF
		var y := m.magic.nav.center_y(cell) + Fixed.HALF
		var near_orphans := false
		var guarded := false
		for id in m.combat.buckets.near(x, y, reach):
			var s := id - 1
			if e.hp[s] <= 0 or Fixed.distance(x, y, e.pos_x[s], e.pos_y[s]) > reach:
				continue
			near_orphans = near_orphans or e.owners[s] == orphans
			guarded = guarded or crown.has(e.owners[s])
		if not near_orphans or guarded:
			unguarded.erase(i)
			continue
		unguarded[i] = unguarded.get(i, 0) + MissionRuntime.CHECK_EVERY
		if unguarded[i] >= Num.of(c["ticks"]):
			unguarded.erase(i)
			broken += 1
			m.flags["chapel_broken"] = tick
			m.run({"do": "ping", "at": [Fixed.to_cells(x), Fixed.to_cells(y)], "radius": 3}, tick)
			m.economy.destroy(b)


func _hungry(m: MissionRuntime, h: Dictionary, tick: int) -> void:
	if h.is_empty() or tick % Num.of(h["every_ticks"]) != 0:
		return
	var p := Num.of(_rules(m)["player"])
	var state := m.economy.player(p)
	if state == null or state.stock[EconomySystem.FOOD] > 0:
		return
	m.flags["starving"] = tick
	for id in m.entities.alive_ids:
		var unit := m.combat.defs[id - 1]
		if m.entities.owners[id - 1] == p and unit != null and unit.morale > 0:
			m.combat.lose_morale(id - 1, unit.morale * Num.of(h["permille"]) / 1000)


func _knighting(m: MissionRuntime, k: Dictionary, tick: int) -> void:
	if k.is_empty():
		return
	var groups: Array = k["groups"]
	for q: String in k["questions"]:
		if answered.has(q):
			continue
		for option in groups.size() + 1:
			if not m.flags.has(MissionRuntime.choice_flag(q, option)):
				continue
			answered.append(q)
			if option < groups.size() and not knights.has(str(groups[option])):
				knights.append(str(groups[option]))
				m.flags["knights"] = tick
			break


# --- helpers ------------------------------------------------------------------------------


static func _in_rect(rect: Array, x: int, y: int) -> bool:
	var cx := Fixed.to_cells(x)
	var cy := Fixed.to_cells(y)
	return (
		cx >= Num.of(rect[0])
		and cy >= Num.of(rect[1])
		and cx <= Num.of(rect[2])
		and cy <= Num.of(rect[3])
	)


static func _bits(v: int) -> int:
	var n := 0
	while v != 0:
		n += v & 1
		v >>= 1
	return n


func _rules(m: MissionRuntime) -> Dictionary:
	return m.def.rules.get("baltic", {})


func write_to(buf: StreamPeerBuffer) -> void:
	# Nothing outside this mission, so older replays keep their hashes.
	if not on:
		return
	buf.put_32(concord)
	buf.put_32(mutinies)
	buf.put_64(mutiny_until)
	buf.put_32(camps_now)
	buf.put_32(camps_ever)
	buf.put_32(suburb.size())
	for b in suburb:
		buf.put_32(b)
	buf.put_8(1 if gate_lit else 0)
	buf.put_32(surrendered)
	buf.put_8(1 if hunting else 0)
	buf.put_32(ransomed)
	buf.put_32(killed)
	var names := villages.keys()
	names.sort()
	buf.put_32(names.size())
	for v: String in names:
		buf.put_utf8_string(v)
		buf.put_8(villages[v])
	var ids := unguarded.keys()
	ids.sort()
	buf.put_32(ids.size())
	for i: int in ids:
		buf.put_32(i)
		buf.put_32(unguarded[i])
	buf.put_32(broken)
	for g in knights:
		buf.put_utf8_string(g)
	for q in answered:
		buf.put_utf8_string(q)
