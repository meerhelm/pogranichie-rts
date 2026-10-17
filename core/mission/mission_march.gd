class_name MissionMarch
extends RefCounted
## The rules of «ВКЛ 4. Вилькомир, 1435» (def.rules supply, raids, march, capture and spare), run
## by MissionRuntime.step() on its own state: the field camp's supply from the wagons, the
## Tatar raids of the first night, the enemy column on the march, captives and the spared
## brother. Static functions on the runtime, so its save and hash keep it all.
##
## Trigger conditions: groups_near {group, other, radius} (a member of one within radius of a
## member of the other); captured {group?, at_least} (captives taken from the group, or in all);
## groups_taken {groups, count} (at least count of the groups lost half their men or more as
## captives); spared {group} (the group's hero is spared).
## Actions: merge {group, of: [groups]} (a group of all their members, for orders to many at
## once); protect {group} (nobody may attack its members any more); march {groups, on} (into or
## out of the marching column); morale {group, permille} (each member loses that share of its
## full morale); countdown {text, ticks} (the panel counts down to tick + ticks under the
## objectives; ticks 0 hides it).

const CONDITIONS: Array[String] = ["groups_near", "captured", "groups_taken", "spared"]
const ACTIONS: Array[String] = ["merge", "protect", "march", "morale", "countdown"]


## At the mission's start: the spared hero gets his HP floor, the first supply and raid are due.
static func set_up(m: MissionRuntime) -> void:
	var s: Dictionary = m.def.rules.get("supply", {})
	if not s.is_empty():
		m.next_supply = int(s["every_ticks"])
	var r: Dictionary = m.def.rules.get("raids", {})
	if not r.is_empty():
		m.next_raid = int(r["first_ticks"])
	var sp: Dictionary = m.def.rules.get("spare", {})
	if sp.is_empty():
		return
	for id in m.alive_of(sp["group"]):
		if m.combat.flags[id - 1] & CombatSystem.F_HERO:
			var floor_hp := maxi(m.entities.max_hp[id - 1] * int(sp["permille"]) / 1000, 1)
			m.combat.hp_floor[id] = floor_hp


## Camp supply (card: «еда и серебро приходят из обоза по таймеру»): every every_ticks the
## player gets `amount` [food, wood, iron, silver] while the named camp stands.
static func supply(m: MissionRuntime, tick: int) -> void:
	var s: Dictionary = m.def.rules.get("supply", {})
	if s.is_empty() or m.next_supply < 0 or tick < m.next_supply:
		return
	if not m.economy.buildings.is_alive(m.named.get(s["building"], 0)):
		m.next_supply = -1
		m.flags["supply_lost"] = tick
		return
	m.next_supply = tick + int(s["every_ticks"])
	var state := m.economy.player(s["player"])
	if state == null:
		return
	var amount: Array = s["amount"]
	for r in amount.size():
		state.stock[r] += int(amount[r])


## Raids (card 1.3: «каждые 2 минуты набег татар (3–4 юнита) через северную полосу суши на
## обоз игрока»): from first_ticks on, every every_ticks a party of `units` comes in at `at` and
## attack-moves to `to`, until the `until` trigger fires. Each party is the group raid_<n>.
static func raids(m: MissionRuntime, tick: int) -> void:
	var r: Dictionary = m.def.rules.get("raids", {})
	if r.is_empty() or m.next_raid < 0 or tick < m.next_raid:
		return
	if m.fired.has(r["until"]):
		m.next_raid = -1
		return
	m.next_raid = tick + int(r["every_ticks"])
	var name := "raid_%d" % m.raids
	m.raids += 1
	var g := {
		"group": name,
		"player": r["player"],
		"at": r["at"],
		"units": r["units"],
		"stance": "aggressive"
	}
	m.run({"do": "spawn"}.merged(g), tick)
	m.run({"do": "attack_move", "group": name, "to": r["to"]}, tick)
	m.flags["raid"] = tick


## Puts the groups' living members into the marching column (on) or takes them out of it.
static func set_marching(m: MissionRuntime, groups: Array, on: bool) -> void:
	for g: String in groups:
		for id in m.alive_of(g):
			if on:
				m.marching[id] = -1
			else:
				m.marching.erase(id)


## The column on the march (card: «Вражеские отряды в походной колонне имеют штраф к защите и
## боевому духу, пока не перестроятся (перестроение занимает 20–30 секунд)»). A unit in the
## column has the «lost order» armour malus (EntityStore.disorder, as after a «Литовский
## отход») and its morale held at most morale_permille of the full. Once struck it starts to
## form up: reform_ticks later it is out of the column and fights as usual.
static func march(m: MissionRuntime, tick: int) -> void:
	var r: Dictionary = m.def.rules.get("march", {})
	if r.is_empty() or m.marching.is_empty():
		return
	var e := m.entities
	var reform := int(r["reform_ticks"])
	var cap_permille := int(r["morale_permille"])
	var ids := m.marching.keys()
	ids.sort()
	for id: int in ids:
		if not e.is_alive(id) or e.hp[id - 1] <= 0:
			m.marching.erase(id)
			continue
		var s := id - 1
		var until: int = m.marching[id]
		if until >= 0 and tick >= until:
			m.marching.erase(id)
			continue
		e.disorder[s] = maxi(e.disorder[s], MissionRuntime.CHECK_EVERY + 1)
		if until < 0:
			var def := m.combat.defs[s]
			if def != null:
				var cap := def.morale * CombatSystem.MORALE_SCALE * cap_permille / 1000
				e.morale[s] = mini(e.morale[s], cap)
			if e.calm[s] < MissionRuntime.CHECK_EVERY:
				m.marching[id] = tick + reform


## Captives (card: «Отряд с боевым духом ниже 20%, окружённый с двух сторон, сдаётся вместо
## того, чтобы погибнуть»). An enemy of `player` whose morale is below morale_permille of its
## full, with units of the player's side within `radius` cells on two opposite sides of it,
## lays down its arms: it is led away (leaves the map) and counted for every group it was in.
## Heroes, units that never flee and untouchable ones do not surrender; with `players`, only
## units of those players do (ВКЛ 4: Švitrigaila's own men, not the Livonian brothers).
## `banners`: the groups the panel counts as banners taken (see groups_taken).
static func capture(m: MissionRuntime, tick: int, remove: Callable) -> void:
	var c: Dictionary = m.def.rules.get("capture", {})
	if c.is_empty():
		return
	var captor: int = c["player"]
	var permille := int(c["morale_permille"])
	var r := Fixed.from_cells(c["radius"])
	var e := m.entities
	var combat := m.combat
	var only: Array = c.get("players", [])
	var taken := PackedInt32Array()
	for id in e.alive_ids:
		var s := id - 1
		if e.hp[s] <= 0 or not m.are_hostile(captor, e.owners[s]):
			continue
		if not only.is_empty() and not only.has(e.owners[s]):
			continue
		var def := combat.defs[s]
		if def == null or combat.untouchable.has(id):
			continue
		if combat.flags[s] & CombatSystem.F_NEVER_FLEES:
			continue
		if e.morale[s] * 1000 >= def.morale * CombatSystem.MORALE_SCALE * permille:
			continue
		if surrounded(m, s, captor, r):
			taken.append(id)
	if taken.is_empty():
		return
	var names := m.groups.keys()
	names.sort()
	for id in taken:
		for g: String in names:
			if m.groups[g].has(id):
				m.captured[g] = m.captured.get(g, 0) + 1
		m.captives += 1
		var at := [Fixed.to_cells(e.pos_x[id - 1]), Fixed.to_cells(e.pos_y[id - 1])]
		m.run({"do": "ping", "at": at, "radius": 1}, tick)
		remove.call(id)
	m.flags["captured"] = tick


## Whether units friendly to `captor` stand within r of the unit in slot s on two opposite
## sides of it (two of them whose directions from it make an obtuse angle).
static func surrounded(m: MissionRuntime, s: int, captor: int, r: int) -> bool:
	var e := m.entities
	var px := e.pos_x[s]
	var py := e.pos_y[s]
	var dirs: Array[Vector2i] = []
	for other in m.combat.buckets.near(px, py, r):
		var o := other - 1
		if e.hp[o] <= 0 or not m.are_friendly(captor, e.owners[o]):
			continue
		var dx := e.pos_x[o] - px
		var dy := e.pos_y[o] - py
		if dx * dx + dy * dy > r * r or (dx == 0 and dy == 0):
			continue
		for d in dirs:
			if d.x * dx + d.y * dy < 0:
				return true
		dirs.append(Vector2i(dx, dy))
	return false


## How many of the groups have had at least half of their men taken captive.
static func groups_taken(m: MissionRuntime, names: Array) -> int:
	var n := 0
	for g: String in names:
		var size: int = m.groups.get(g, PackedInt32Array()).size()
		if size > 0 and m.captured.get(g, 0) * 2 >= size:
			n += 1
	return n


## The spared brother (card: «при 20% здоровья он становится неуязвимым и отступает»): the hero
## of `group` cannot fall below permille of his HP (CombatSystem.hp_floor); once he is there he
## becomes untouchable, stops fighting and rides to `to`, and the flag spared:<group> is set.
static func spare(m: MissionRuntime, tick: int) -> void:
	var sp: Dictionary = m.def.rules.get("spare", {})
	if sp.is_empty():
		return
	var flag := "spared:%s" % sp["group"]
	if m.flags.has(flag):
		return
	for id in m.alive_of(sp["group"]):
		if not m.combat.hp_floor.has(id) or m.entities.hp[id - 1] > m.combat.hp_floor[id]:
			continue
		m.flags[flag] = tick
		m.combat.untouchable[id] = true
		var name := "%s_spared" % sp["group"]
		m.groups[name] = PackedInt32Array([id])
		m.run({"do": "stance", "group": name, "stance": "passive"}, tick)
		m.run({"do": "move", "group": name, "to": sp["to"]}, tick)
		return


static func test(m: MissionRuntime, c: Dictionary) -> bool:
	match c["type"]:
		"groups_near":
			return groups_near(m, c["group"], c["other"], int(c["radius"]))
		"captured":
			var n: int = m.captured.get(c["group"], 0) if c.has("group") else m.captives
			return n >= int(c["at_least"])
		"groups_taken":
			return groups_taken(m, c["groups"]) >= int(c["count"])
		"spared":
			return m.flags.has("spared:%s" % c["group"])
	return false


static func run(m: MissionRuntime, a: Dictionary, tick: int) -> void:
	match a["do"]:
		"merge":
			var ids := PackedInt32Array()
			for g: String in a["of"]:
				ids.append_array(m.groups.get(g, PackedInt32Array()))
			ids.sort()
			m.groups[a["group"]] = ids
		"protect":
			for id in m.alive_of(a["group"]):
				m.combat.untouchable[id] = true
		"march":
			set_marching(m, a["groups"], a.get("on", true))
		"morale":
			for id in m.alive_of(a["group"]):
				var unit := m.combat.defs[id - 1]
				if unit != null:
					m.combat.lose_morale(id - 1, unit.morale * int(a["permille"]) / 1000)
		"countdown":
			m.countdown_text = a.get("text", "")
			m.countdown_end = tick + int(a["ticks"]) if int(a["ticks"]) > 0 else -1


static func groups_near(m: MissionRuntime, group: String, other: String, radius: int) -> bool:
	var e := m.entities
	var r := Fixed.from_cells(radius)
	var them := m.alive_of(other)
	for id in m.alive_of(group):
		for o in them:
			var dx := e.pos_x[id - 1] - e.pos_x[o - 1]
			var dy := e.pos_y[id - 1] - e.pos_y[o - 1]
			if dx * dx + dy * dy <= r * r:
				return true
	return false


## This mission's part of the state hash (MissionRuntime.write_to), with the HP floors.
static func write_to(m: MissionRuntime, buf: StreamPeerBuffer) -> void:
	var walking := m.marching.keys()
	walking.sort()
	buf.put_32(walking.size())
	for id: int in walking:
		buf.put_32(id)
		buf.put_64(m.marching[id])
	var taken := m.captured.keys()
	taken.sort()
	buf.put_32(taken.size())
	for g: String in taken:
		buf.put_utf8_string(g)
		buf.put_32(m.captured[g])
	buf.put_32(m.captives)
	buf.put_64(m.next_supply)
	buf.put_64(m.next_raid)
	buf.put_32(m.raids)
	buf.put_utf8_string(m.countdown_text)
	buf.put_64(m.countdown_end)
	var floors := m.combat.hp_floor.keys()
	floors.sort()
	buf.put_32(floors.size())
	for id: int in floors:
		buf.put_32(id)
		buf.put_32(m.combat.hp_floor[id])
