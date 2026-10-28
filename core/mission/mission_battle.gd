class_name MissionBattle
extends RefCounted
## The rules of «ВКЛ 8. Орша, 1514» (def.rules.battle), run by MissionRuntime.step() on this
## object's state, which the runtime's save and hash carry: the night crossing of the Dnieper on
## bridges of boats, barrels and logs that camp servants lay section by section while a Muscovite
## patrol rides the far bank; the infantry and guns waiting hidden in the ravine and by the
## forest, out of the player's hands until the signal; the false retreat that leads the chase to
## a chosen point; the chase itself; the left hand pressed into the boggy Kropivna; the captive
## commander and the last place of power, the old oak.
##
## Rules (battle):
##   player (whose servants build and whose units the patrol looks for); known_map;
##   worker (the unit type that builds), deck (the terrain a finished section becomes);
##   bridges [{cells: [x0, y0, x1, y1], sections, work, cost: [food, wood, iron, silver],
##     radius}]: a bridge over the rows y0..y1, built from the south bank (y1) north in
##     `sections` equal parts; workers within radius cells of the head (the cell south of the
##     next section, in the middle of the bridge) add CHECK_EVERY each a check, a section takes
##     `work` and costs `cost` when it is begun (no stock: no work, flag no_wood);
##   patrol {group, route: [[x, y], ...], radius, ticks}: the patrol rides the route round while
##     it is night; a member that sees a unit of the player within radius for `ticks` in a row
##     raises the alarm (flag alarm): the patrol rides there;
##   cover [[x0, y0, x1, y1], ...] (the ravine, the forest's edge), ambush (the group): while held,
##     a member inside a cover rectangle or under the player's «Болотный туман» is hidden: the
##     enemy cannot see it to strike it;
##   oak {place, unit, radius, charge}: the place starts hidden; the first unit of that type of the
##     player within radius of it finds it: the player gets `charge` Сила, flag oak;
##   press {group, cells: [x0, y0, x1, y1]}: once on, members of the group that get into the
##     cells (the Kropivna's bog) count as pressed into it;
##   take {group, permille, radius, to}: the group's hero cannot fall below permille of his HP;
##     there, with a unit of the player's side within radius he is taken captive (flag
##     taken:<group>, he leaves the map), else he rides off to `to` and leaves the map;
##   chase_leash (cells: how far a chasing group looks for the player's units).
## Conditions: bridges_built {at_least}; north_of {group, y, at_least} (living members north of
##   row y); pressed {at_least}; hidden_count {at_least} (ambush members hidden now).
## Actions: hold {on} (the ambush is held: passive, deaf to the player, hidden where it may be;
##   off: it answers to the player again and is seen); ambush_fire {radius, damage, morale} (the
##   volley from the ambush: enemies within radius of a member take the damage and lose morale,
##   twice as much if the member that has them in reach was hidden; the hold ends); chase
##   {group, on} (the group keeps attack-moving at the player's nearest unit); feint {on} (a
##   «Литовский отход» of the player rides on to the rally point, not just a few cells); press
##   {on}; place {player, type, at, name} (a building put down, named).

const CONDITIONS: Array[String] = ["bridges_built", "north_of", "pressed", "hidden_count"]
const ACTIONS: Array[String] = ["hold", "ambush_fire", "chase", "feint", "press", "place"]
## How often (ticks) a chasing group is sent again at the nearest unit.
const CHASE_EVERY := 40
## A patrol is at its waypoint this near (cells).
const AT_WAYPOINT := 3

## Per bridge: sections finished, the work done on the next one, whether it is paid for.
var built := PackedInt32Array()
var work := PackedInt32Array()
var paid := PackedInt32Array()
## The patrol's next waypoint, how long it has seen someone, and the alarm.
var leg := 0
var seen := 0
var alarm := false
## The ambush: held members, and those hidden now.
var held: Dictionary[int, bool] = {}
var hidden: Dictionary[int, bool] = {}
## Chasing groups, the feint, the press and who was pressed, the oak found.
var chasing: Dictionary[String, bool] = {}
var feint_on := false
var press_on := false
var pressed: Dictionary[int, bool] = {}
var oak_found := false


func set_up(m: MissionRuntime) -> void:
	var r := _rules(m)
	if r.is_empty():
		return
	var bridges: Array = r.get("bridges", [])
	built.resize(bridges.size())
	work.resize(bridges.size())
	paid.resize(bridges.size())
	if r.get("known_map", false) and m.combat.vision != null and m.combat.vision.enabled():
		m.combat.vision.explore_all(m.def.player)
	var oak: Dictionary = r.get("oak", {})
	if not oak.is_empty() and Num.of(oak["place"]) < m.magic.places.count():
		m.magic.places.hidden[Num.of(oak["place"])] = true
	var take: Dictionary = r.get("take", {})
	if not take.is_empty():
		for id in m.alive_of(str(take["group"])):
			if m.combat.flags[id - 1] & CombatSystem.F_HERO:
				var floor_hp := maxi(m.entities.max_hp[id - 1] * Num.of(take["permille"]) / 1000, 1)
				m.combat.hp_floor[id] = floor_hp


func step(m: MissionRuntime, tick: int) -> void:
	var r := _rules(m)
	if r.is_empty():
		return
	_bridges(m, r, tick)
	_patrol(m, r, tick)
	_hide(m, r)
	_oak(m, r, tick)
	_press(m, r)
	_take(m, r, tick)
	if tick % CHASE_EVERY == 0:
		_chase(m, r, tick)


func test(m: MissionRuntime, c: Dictionary) -> bool:
	match c["type"]:
		"bridges_built":
			return bridges_done(m) >= Num.of(c["at_least"])
		"north_of":
			var n := 0
			var row := Fixed.from_cells(Num.of(c["y"]))
			for id in m.alive_of(str(c["group"])):
				if m.entities.pos_y[id - 1] < row:
					n += 1
			return n >= Num.of(c["at_least"])
		"pressed":
			return pressed.size() >= Num.of(c["at_least"])
		"hidden_count":
			return hidden.size() >= Num.of(c["at_least"])
	return false


func run(m: MissionRuntime, a: Dictionary, tick: int) -> void:
	match a["do"]:
		"hold":
			_hold(m, a.get("on", true), tick)
		"ambush_fire":
			_fire(m, a, tick)
		"chase":
			chasing[a["group"]] = a.get("on", true)
			if not chasing[a["group"]]:
				chasing.erase(a["group"])
		"feint":
			feint_on = a.get("on", true)
		"press":
			press_on = a.get("on", true)
		"place":
			var at: Array = a["at"]
			var b := m._place(
				tick, Num.of(a["player"]), str(a["type"]), Num.of(at[0]), Num.of(at[1])
			)
			if b != 0 and a.has("name"):
				m.named[a["name"]] = b


# --- the bridges ----------------------------------------------------------------------------


## Bridges with every section laid.
func bridges_done(m: MissionRuntime) -> int:
	var n := 0
	var bridges: Array = _rules(m).get("bridges", [])
	for i in bridges.size():
		if built[i] >= Num.of(bridges[i]["sections"]):
			n += 1
	return n


## Rows a section of bridge `b` spans (the last one may be shorter).
static func section_rows(b: Dictionary) -> int:
	var rect: Array = b["cells"]
	var rows := Num.of(rect[3]) - Num.of(rect[1]) + 1
	return ceili(float(rows) / float(maxi(Num.of(b["sections"]), 1)))


## The cell the builders of bridge `b` stand at: just south of its next section, mid-bridge.
static func head(b: Dictionary, done: int) -> Vector2i:
	var rect: Array = b["cells"]
	var x := (Num.of(rect[0]) + Num.of(rect[2])) / 2
	return Vector2i(x, Num.of(rect[3]) + 1 - done * section_rows(b))


## The cells of bridge i that are laid (for the map).
func deck_cells(m: MissionRuntime, i: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var bridges: Array = _rules(m).get("bridges", [])
	if i >= bridges.size():
		return out
	var b: Dictionary = bridges[i]
	var rect: Array = b["cells"]
	var low := maxi(Num.of(rect[3]) + 1 - built[i] * section_rows(b), Num.of(rect[1]))
	for y in range(low, Num.of(rect[3]) + 1):
		for x in range(Num.of(rect[0]), Num.of(rect[2]) + 1):
			out.append(Vector2i(x, y))
	return out


func _bridges(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	var bridges: Array = r.get("bridges", [])
	if bridges.is_empty():
		return
	var p := Num.of(r["player"])
	var worker := StringName(str(r.get("worker", "gdl_camp_servant")))
	var e := m.entities
	for i in bridges.size():
		var b: Dictionary = bridges[i]
		if built[i] >= Num.of(b["sections"]):
			continue
		var at := head(b, built[i])
		var x := Fixed.from_cells(at.x) + Fixed.HALF
		var y := Fixed.from_cells(at.y) + Fixed.HALF
		var reach := Fixed.from_cells(Num.of(b["radius"]))
		var workers := 0
		for id in e.alive_ids:
			var s := id - 1
			if e.owners[s] != p or e.type_ids[s] != worker or e.hp[s] <= 0:
				continue
			var dx := e.pos_x[s] - x
			var dy := e.pos_y[s] - y
			if dx * dx + dy * dy <= reach * reach:
				workers += 1
		if workers == 0:
			continue
		if paid[i] == 0:
			if not _pay(m, p, b.get("cost", [])):
				m.flags["no_wood"] = tick
				continue
			paid[i] = 1
		work[i] += workers * MissionRuntime.CHECK_EVERY
		if work[i] >= Num.of(b["work"]):
			_lay(m, r, i, tick)


func _pay(m: MissionRuntime, p: int, cost: Array) -> bool:
	var state := m.economy.player(p)
	if state == null:
		return false
	for k in cost.size():
		if state.stock[k] < Num.of(cost[k]):
			return false
	for k in cost.size():
		state.stock[k] -= Num.of(cost[k])
	return true


## The next section of bridge i is laid: its cells become the deck.
func _lay(m: MissionRuntime, r: Dictionary, i: int, tick: int) -> void:
	var b: Dictionary = r["bridges"][i]
	var rect: Array = b["cells"]
	var rows := section_rows(b)
	var bottom := Num.of(rect[3]) - built[i] * rows
	var top := maxi(bottom - rows + 1, Num.of(rect[1]))
	var nav := m.economy.nav
	var deck := nav.terrain_index(StringName(str(r.get("deck", "t_bog"))))
	for cy in range(top, bottom + 1):
		for cx in range(Num.of(rect[0]), Num.of(rect[2]) + 1):
			if deck >= 0:
				nav.set_terrain(nav.cell_at(cx, cy), deck)
	built[i] += 1
	work[i] = 0
	paid[i] = 0
	m.flags["section_%d_%d" % [i, built[i]]] = tick
	if built[i] >= Num.of(b["sections"]):
		m.flags["bridge_%d" % i] = tick


## How far the next section of bridge i is (permille), for the panel.
func section_permille(m: MissionRuntime, i: int) -> int:
	var bridges: Array = _rules(m).get("bridges", [])
	if i >= bridges.size() or built[i] >= Num.of(bridges[i]["sections"]):
		return 1000
	return work[i] * 1000 / maxi(Num.of(bridges[i]["work"]), 1)


# --- the patrol -----------------------------------------------------------------------------


func _patrol(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	var pr: Dictionary = r.get("patrol", {})
	if pr.is_empty() or alarm or not m.stealth.night:
		return
	var ids := m.alive_of(str(pr["group"]))
	if ids.is_empty():
		return
	var e := m.entities
	var route: Array = pr["route"]
	var lead := ids[0] - 1
	var to: Array = route[leg % route.size()]
	var wx := Fixed.from_cells(Num.of(to[0])) + Fixed.HALF
	var wy := Fixed.from_cells(Num.of(to[1])) + Fixed.HALF
	var near := Fixed.from_cells(AT_WAYPOINT)
	var dx := e.pos_x[lead] - wx
	var dy := e.pos_y[lead] - wy
	if dx * dx + dy * dy <= near * near:
		leg = (leg + 1) % route.size()
		to = route[leg]
		m.run({"do": "move", "group": pr["group"], "to": to}, tick)
	elif e.orders[lead] != EntityStore.Order.MOVE:
		m.run({"do": "move", "group": pr["group"], "to": to}, tick)
	var spot := _spotted(m, Num.of(r["player"]), ids, Fixed.from_cells(Num.of(pr["radius"])))
	if spot.x < 0:
		seen = 0
		return
	seen += MissionRuntime.CHECK_EVERY
	if seen < Num.of(pr["ticks"]):
		return
	alarm = true
	m.flags["alarm"] = tick
	m.run({"do": "stance", "group": pr["group"], "stance": "aggressive"}, tick)
	m.run({"do": "attack_move", "group": pr["group"], "to": [spot.x, spot.y]}, tick)
	m.run({"do": "ping", "at": [spot.x, spot.y], "radius": 4}, tick)


## The cell of the first unit of player p a watcher sees within reach, or (-1, -1).
func _spotted(m: MissionRuntime, p: int, watchers: PackedInt32Array, reach: int) -> Vector2i:
	var e := m.entities
	for w in watchers:
		for other in m.combat.buckets.near(e.pos_x[w - 1], e.pos_y[w - 1], reach):
			var o := other - 1
			if e.owners[o] != p or e.hp[o] <= 0:
				continue
			var dx := e.pos_x[o] - e.pos_x[w - 1]
			var dy := e.pos_y[o] - e.pos_y[w - 1]
			if dx * dx + dy * dy <= reach * reach:
				return Vector2i(Fixed.to_cells(e.pos_x[o]), Fixed.to_cells(e.pos_y[o]))
	return Vector2i(-1, -1)


# --- the ambush -----------------------------------------------------------------------------


func _hold(m: MissionRuntime, on: bool, tick: int) -> void:
	var group: String = _rules(m).get("ambush", "")
	if on:
		# The stance first: held units do not take orders, the mission's own included.
		m.run({"do": "stance", "group": group, "stance": "passive"}, tick)
		for id in m.alive_of(group):
			held[id] = true
		_hide(m, _rules(m))
		return
	held.clear()
	for id: int in hidden:
		m.combat.untouchable.erase(id)
	hidden.clear()
	m.run({"do": "stance", "group": group, "stance": "aggressive"}, tick)


## While held, ambush members in cover or under the player's mist cannot be seen to be struck.
func _hide(m: MissionRuntime, r: Dictionary) -> void:
	if held.is_empty():
		return
	var e := m.entities
	var p := Num.of(r["player"])
	for id in m.alive_of(str(r.get("ambush", ""))):
		if not held.has(id):
			continue
		var cx := Fixed.to_cells(e.pos_x[id - 1])
		var cy := Fixed.to_cells(e.pos_y[id - 1])
		if in_cover(r, cx, cy) or m.magic.mist.hides(p, cx, cy, -1):
			hidden[id] = true
			m.combat.untouchable[id] = true
		elif hidden.has(id):
			hidden.erase(id)
			m.combat.untouchable.erase(id)
	for id: int in hidden.keys():
		if not e.is_alive(id):
			hidden.erase(id)
			m.combat.untouchable.erase(id)


static func in_cover(r: Dictionary, cx: int, cy: int) -> bool:
	for rect: Array in r.get("cover", []):
		if (
			cx >= Num.of(rect[0])
			and cx <= Num.of(rect[2])
			and cy >= Num.of(rect[1])
			and cy <= Num.of(rect[3])
		):
			return true
	return false


## The ambush fires: every enemy in reach of a member is struck once, and loses morale, twice
## as much if a hidden member had it in reach.
func _fire(m: MissionRuntime, a: Dictionary, tick: int) -> void:
	var r := _rules(m)
	var p := Num.of(r["player"])
	var e := m.entities
	var reach := Fixed.from_cells(Num.of(a["radius"]))
	var hit: Dictionary[int, bool] = {}
	for id in m.alive_of(str(r.get("ambush", ""))):
		var s := id - 1
		for other in m.combat.buckets.near(e.pos_x[s], e.pos_y[s], reach):
			var o := other - 1
			if e.hp[o] <= 0 or not m.are_hostile(p, e.owners[o]):
				continue
			var dx := e.pos_x[o] - e.pos_x[s]
			var dy := e.pos_y[o] - e.pos_y[s]
			if dx * dx + dy * dy > reach * reach:
				continue
			hit[other] = hit.get(other, false) or hidden.has(id)
	var ids := hit.keys()
	ids.sort()
	for id: int in ids:
		var unit := m.combat.defs[id - 1]
		m.combat.lightning(id, p, Num.of(a["damage"]))
		if unit != null and e.is_alive(id):
			var points := Num.of(a["morale"]) * (2 if hit[id] else 1)
			m.combat.lose_morale(id - 1, points)
	m.flags["volley"] = tick
	if not hidden.is_empty():
		m.flags["volley_hidden"] = tick
	_hold(m, false, tick)


## A «Литовский отход» of the player while the feint is on: the riders go on to the rally point.
## Called by the simulation right after the retreat order.
func feint(sim: Simulation, p: int, ids: PackedInt32Array) -> void:
	if not feint_on or sim.mission == null or p != sim.mission.def.player:
		return
	if not sim.combat.rally.has(p):
		return
	var goal: Vector2i = sim.combat.rally[p]
	for id in ids:
		if sim.entities.intents[id - 1] == EntityStore.Intent.RETREAT:
			sim.walk_unit(id, goal.x, goal.y)


## Chasing groups go at the player's nearest unit within the leash.
func _chase(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	if chasing.is_empty():
		return
	var e := m.entities
	var p := Num.of(r["player"])
	var leash := Fixed.from_cells(Num.of(r.get("chase_leash", 40)))
	var names := chasing.keys()
	names.sort()
	for g: String in names:
		var ids := m.alive_of(g)
		if ids.is_empty():
			continue
		var s := ids[0] - 1
		var best := -1
		var best_d := leash * leash
		for id in e.alive_ids:
			var o := id - 1
			if e.owners[o] != p or e.hp[o] <= 0 or m.combat.untouchable.has(id):
				continue
			var dx := e.pos_x[o] - e.pos_x[s]
			var dy := e.pos_y[o] - e.pos_y[s]
			if dx * dx + dy * dy < best_d:
				best_d = dx * dx + dy * dy
				best = o
		if best >= 0:
			var to := [Fixed.to_cells(e.pos_x[best]), Fixed.to_cells(e.pos_y[best])]
			m.run({"do": "attack_move", "group": g, "to": to}, tick)


# --- the oak, the Kropivna, the captive -------------------------------------------------------


func _oak(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	var oak: Dictionary = r.get("oak", {})
	if oak.is_empty() or oak_found:
		return
	var i := Num.of(oak["place"])
	var places := m.magic.places
	if i >= places.count():
		return
	var e := m.entities
	var p := Num.of(r["player"])
	var reach := Fixed.from_cells(Num.of(oak["radius"]))
	var unit := StringName(str(oak["unit"]))
	for id in e.alive_ids:
		var s := id - 1
		if e.owners[s] != p or e.type_ids[s] != unit:
			continue
		var dx := e.pos_x[s] - places.center_x(i)
		var dy := e.pos_y[s] - places.center_y(i)
		if dx * dx + dy * dy > reach * reach:
			continue
		oak_found = true
		places.hidden.erase(i)
		var state := m.economy.player(p)
		if state != null:
			var cap := m.magic.rules.power_cap * MagicSystem.POWER_UNIT
			state.power = mini(state.power + Num.of(oak["charge"]) * MagicSystem.POWER_UNIT, cap)
		m.flags["oak"] = tick
		var at := [Fixed.to_cells(places.center_x(i)), Fixed.to_cells(places.center_y(i))]
		m.run({"do": "ping", "at": at, "radius": 3}, tick)
		return


func _press(m: MissionRuntime, r: Dictionary) -> void:
	var pr: Dictionary = r.get("press", {})
	if pr.is_empty() or not press_on:
		return
	var rect: Array = pr["cells"]
	var e := m.entities
	for id in m.alive_of(str(pr["group"])):
		var cx := Fixed.to_cells(e.pos_x[id - 1])
		var cy := Fixed.to_cells(e.pos_y[id - 1])
		if (
			cx >= Num.of(rect[0])
			and cx <= Num.of(rect[2])
			and cy >= Num.of(rect[1])
			and cy <= Num.of(rect[3])
		):
			pressed[id] = true


func _take(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	var t: Dictionary = r.get("take", {})
	if t.is_empty():
		return
	var g: String = t["group"]
	if m.flags.has("taken:" + g) or m.flags.has("escaped:" + g):
		return
	for id in m.alive_of(g):
		if not m.combat.hp_floor.has(id) or m.entities.hp[id - 1] > m.combat.hp_floor[id]:
			continue
		var s := id - 1
		if _friend_near(m, Num.of(r["player"]), s, Fixed.from_cells(Num.of(t["radius"]))):
			m.flags["taken:" + g] = tick
			m.captives += 1
			var at := [Fixed.to_cells(m.entities.pos_x[s]), Fixed.to_cells(m.entities.pos_y[s])]
			m.run({"do": "ping", "at": at, "radius": 2}, tick)
			m._remove.call(id)
			return
		m.flags["escaped:" + g] = tick
		m.combat.untouchable[id] = true
		var name := "%s_escaped" % g
		m.groups[name] = PackedInt32Array([id])
		m.run({"do": "stance", "group": name, "stance": "passive"}, tick)
		m.run({"do": "move", "group": name, "to": t["to"]}, tick)
		m.run({"do": "exit", "group": name, "at": t["to"], "radius": 3}, tick)
		return


func _friend_near(m: MissionRuntime, p: int, s: int, reach: int) -> bool:
	var e := m.entities
	for other in m.combat.buckets.near(e.pos_x[s], e.pos_y[s], reach):
		var o := other - 1
		if e.hp[o] <= 0 or not m.are_friendly(p, e.owners[o]):
			continue
		var dx := e.pos_x[o] - e.pos_x[s]
		var dy := e.pos_y[o] - e.pos_y[s]
		if dx * dx + dy * dy <= reach * reach:
			return true
	return false


func _rules(m: MissionRuntime) -> Dictionary:
	return m.def.rules.get("battle", {})


func write_to(buf: StreamPeerBuffer) -> void:
	buf.put_32(built.size())
	for i in built.size():
		buf.put_32(built[i])
		buf.put_32(work[i])
		buf.put_8(paid[i])
	buf.put_32(leg)
	buf.put_32(seen)
	buf.put_8(
		(
			(1 if alarm else 0)
			| (2 if feint_on else 0)
			| (4 if press_on else 0)
			| (8 if oak_found else 0)
		)
	)
	for d: Dictionary in [held, hidden, pressed]:
		var ids := d.keys()
		ids.sort()
		buf.put_32(ids.size())
		for id: int in ids:
			buf.put_32(id)
	var names := chasing.keys()
	names.sort()
	buf.put_32(names.size())
	for g: String in names:
		buf.put_utf8_string(g)
