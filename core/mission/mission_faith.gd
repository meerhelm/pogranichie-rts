class_name MissionFaith
extends RefCounted
## The rules of «ВКЛ 3. Крещение» (def.rules baptism, spies and evidence), run by
## MissionRuntime.step() on its own state: who is baptized, the spies of the Order and the
## evidence they gather. Static functions on the runtime, so its save and hash keep it all.


## Baptism (card ВКЛ 3: «Костёл крестит крестьян»): every baptism_every ticks each finished
## church (`base`) of `player` baptizes one of the player's `unit`s within `radius` cells, the
## lowest id first. The baptized work as before.
static func baptism(m: MissionRuntime, tick: int) -> void:
	var b: Dictionary = m.def.rules.get("baptism", {})
	if b.is_empty() or m.baptism_every <= 0 or tick == 0 or tick % m.baptism_every != 0:
		return
	var p: int = b["player"]
	var base := StringName(b["base"])
	var unit := StringName(b["unit"])
	var r := Fixed.from_cells(b["radius"])
	var entities := m.entities
	var store := m.economy.buildings
	for c in store.alive_ids:
		var s := c - 1
		if store.owners[s] != p or store.done[s] != 1 or store.defs[s].base_id != base:
			continue
		for id in entities.alive_ids:
			var u := id - 1
			if entities.owners[u] != p or entities.type_ids[u] != unit or m.baptized.has(id):
				continue
			var dx := entities.pos_x[u] - store.center_x(c)
			var dy := entities.pos_y[u] - store.center_y(c)
			if dx * dx + dy * dy <= r * r:
				m.baptized[id] = true
				break


## Living baptized units.
static func baptized_alive(m: MissionRuntime) -> int:
	var n := 0
	for id: int in m.baptized:
		if m.entities.is_alive(id):
			n += 1
	return n


## Spies (rules.spies): up to spies_wanted of `unit` walk the map for `player`, coming in at `at`
## and going round `route` (each starts at its own waypoint). A killed one is replaced after
## respawn_ticks («донос пишет следующий»). `spawn` and `apply` are the runtime's hands.
static func spies(m: MissionRuntime, tick: int, spawn: Callable, apply: Callable) -> void:
	var r: Dictionary = m.def.rules.get("spies", {})
	if r.is_empty():
		return
	var entities := m.entities
	var alive := PackedInt32Array()
	for id in m.spies:
		if entities.is_alive(id) and entities.hp[id - 1] > 0:
			alive.append(id)
		else:
			m.spies_killed += 1
			m.spy_waypoint.erase(id)
			m.spy_next = tick + int(r["respawn_ticks"])
			add_evidence(m, int(m.def.rules.get("evidence", {}).get("kill", 0)) * 1000)
	m.spies = alive
	var route: Array = r["route"]
	if m.spies.size() < m.spies_wanted and tick >= m.spy_next:
		var at: Array = r["at"]
		var x := Fixed.from_cells(at[0]) + Fixed.HALF
		var y := Fixed.from_cells(at[1]) + Fixed.HALF
		var id: int = spawn.call(StringName(r["unit"]), r["player"], x, y)
		if id != EntityStore.NO_ID:
			apply.call(
				SimCommand.set_stance(
					tick, r["player"], PackedInt32Array([id]), EntityStore.Stance.PASSIVE
				)
			)
			m.spies.append(id)
			m.spy_waypoint[id] = (m.spies_killed + m.spies.size() - 1) % route.size()
			if m.spies.size() < m.spies_wanted:
				m.spy_next = tick + MissionRuntime.CHECK_EVERY * 20
	for id in m.spies:
		if entities.orders[id - 1] != EntityStore.Order.IDLE:
			continue
		var k: int = m.spy_waypoint[id]
		var to: Array = route[k]
		m.spy_waypoint[id] = (k + 1) % route.size()
		var tx := Fixed.from_cells(to[0]) + Fixed.HALF
		var ty := Fixed.from_cells(to[1]) + Fixed.HALF
		apply.call(SimCommand.move(tick, r["player"], PackedInt32Array([id]), tx, ty))


## Evidence (card ВКЛ 3, «Шкала Свидетельства»): it grows when a spy sees a rite at an alka
## (each of `player`'s finished shrines a spy sees adds alka_milli a check; under the player's
## mist a spy sees it only from mist_sight cells), sees Сила used (a new spell effect of the
## player within `sight` cells of a spy, plus the effect's radius, adds `cast` points), or a spy
## is killed (`kill` points). The more baptized (and faith), the slower it grows: each takes
## faith_step_permille off the gain, down to faith_floor_permille of it. The first spell of
## the player sets the flag power_spent, seen or not.
static func evidence(m: MissionRuntime, tick: int) -> void:
	var r: Dictionary = m.def.rules.get("evidence", {})
	if r.is_empty():
		return
	var p: int = r["player"]
	var spy := StringName(r["spy"])
	var sight := Fixed.from_cells(r["sight"])
	var near_sight := Fixed.from_cells(r["mist_sight"])
	var entities := m.entities
	var magic := m.magic
	var eyes := PackedInt32Array()
	for id in entities.alive_ids:
		if entities.type_ids[id - 1] == spy and entities.hp[id - 1] > 0:
			eyes.append(id)
	var gain := 0
	for i in magic.fx_ids.size():
		if magic.fx_ids[i] <= m.fx_seen:
			continue
		m.fx_seen = magic.fx_ids[i]
		if magic.fx_owner[i] != p:
			continue
		if not m.flags.has("power_spent"):
			m.flags["power_spent"] = tick
		var reach := sight + Fixed.from_cells(magic.fx_radius[i])
		if _seen_by(entities, eyes, magic.fx_x[i], magic.fx_y[i], reach):
			gain += int(r["cast"]) * 1000
			m.flags["rite_seen"] = tick
	var store := m.economy.buildings
	for b in store.alive_ids:
		var s := b - 1
		if store.owners[s] != p or store.done[s] != 1 or store.defs[s].base_id != &"shrine":
			continue
		var bx := store.center_x(b)
		var by := store.center_y(b)
		var hidden := magic.mist.hides(p, Fixed.to_cells(bx), Fixed.to_cells(by), -1)
		if _seen_by(entities, eyes, bx, by, near_sight if hidden else sight):
			gain += int(r["alka_milli"])
			m.flags["rite_seen"] = tick
	add_evidence(m, gain)


## Adds to the evidence what is left of `milli` after the faith (gains only).
static func add_evidence(m: MissionRuntime, milli: int) -> void:
	var r: Dictionary = m.def.rules.get("evidence", {})
	if milli <= 0 or r.is_empty():
		return
	var faith := baptized_alive(m) + m.faith_bonus
	var keep := maxi(int(r["faith_floor_permille"]), 1000 - faith * int(r["faith_step_permille"]))
	m.evidence = mini(m.evidence + milli * keep / 1000, evidence_max(m))


## The evidence that loses the mission, in milli-points.
static func evidence_max(m: MissionRuntime) -> int:
	return int(m.def.rules.get("evidence", {}).get("max", 100)) * 1000


static func _seen_by(
	entities: EntityStore, eyes: PackedInt32Array, x: int, y: int, reach: int
) -> bool:
	for id in eyes:
		var dx := entities.pos_x[id - 1] - x
		var dy := entities.pos_y[id - 1] - y
		if dx * dx + dy * dy <= reach * reach:
			return true
	return false
