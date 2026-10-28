class_name MissionRetreat
extends RefCounted
## The rules of «ВКЛ 5. Ведроша, 1500» (def.rules bridge, ford, rescue and waves), run by
## MissionRuntime.step() on this object's state, which the runtime's save and hash carry: the
## one bridge on the Trosna that the ambush's axemen bring down, the narrow ford below it where
## men drown if they crowd, the count of men brought back over the river, Muscovite reserves
## coming in waves. Setup `power` {player: points} gives a side Сила (the Muscovite icon).
##
## Rules:
##   bridge {cells: [x0, y0, x1, y1] (the bridge's cells, a rectangle), at, radius, hp,
##     group (who wrecks it), per_unit (hp a check each wrecker within radius takes off),
##     fall_ticks (it falls this long after the wrecking begins, whatever happens)}: when it
##     falls its cells turn to water and whoever stands on them drowns;
##   ford {cells: [x0, y0, x1, y1], capacity, drown_permille}: once on (the `ford` action),
##     with more than capacity units in the cells the ones that came in last lose drown_permille
##     of their full HP every check;
##   rescue {player, east_of, west_of}: a unit of the player that has been east of column
##     east_of and now stands alive west of column west_of is brought back (counted by `saved`);
##   waves {player, units, at, to, every_ticks}: while on (the `waves` action), every
##     every_ticks a fresh party comes in at `at` and attack-moves to `to` (groups wave_<n>).
## Conditions: bridge_down; bridge_below {permille} (the wrecking has begun and the bridge has
##   less than that share of its hp left); saved {at_least, group?} (units brought back; with
##   group, its members west of west_of, crossed or not); drowned {at_least}.
## Actions: bridge {on} (the wreckers start, or the bridge falls at once with on false);
##   ford {on}; waves {on}; unprotect {group} (its members may be attacked again); transfer
##   {group, player} (its living members go over to that player, as the same group); cast
##   {group, spell} (the group's caster casts the spell where it stands).

const CONDITIONS: Array[String] = ["bridge_down", "bridge_below", "saved", "drowned"]
const ACTIONS: Array[String] = ["bridge", "ford", "waves", "unprotect", "transfer", "cast"]
## Damage enough to finish anyone who stands on the bridge as it goes down.
const DROWN := 100000

## The bridge's hp left, the tick its wrecking began (-1: not yet) and whether it is down.
var bridge_hp := 0
var bridge_from := -1
var bridge_fell := false
## The ford: on or off, and the tick each unit now in it came in.
var ford_on := false
var ford_in: Dictionary[int, int] = {}
## Units drowned (on the falling bridge or in the ford).
var drowned := 0
## The player's units that have been east of rescue.east_of.
var crossed: Dictionary[int, bool] = {}
## The next wave (-1: none) and how many came.
var next_wave := -1
var waves := 0


func set_up(m: MissionRuntime) -> void:
	bridge_hp = Num.of(m.def.rules.get("bridge", {}).get("hp", 0))
	var power: Dictionary = m.def.setup.get("power", {})
	for key: String in power:
		var state := m.economy.player(key.to_int())
		if state != null:
			state.power = Num.of(power[key]) * MagicSystem.POWER_UNIT


func step(m: MissionRuntime, tick: int) -> void:
	_cross(m)
	_bridge(m, tick)
	_ford(m, tick)
	_waves(m, tick)


func test(m: MissionRuntime, c: Dictionary) -> bool:
	match c["type"]:
		"bridge_down":
			return bridge_fell
		"bridge_below":
			var full := Num.of(m.def.rules["bridge"]["hp"])
			return bridge_from >= 0 and bridge_hp * 1000 < full * Num.of(c["permille"])
		"saved":
			return saved(m, str(c.get("group", ""))) >= Num.of(c["at_least"])
		"drowned":
			return drowned >= Num.of(c["at_least"])
	return false


func run(m: MissionRuntime, a: Dictionary, tick: int) -> void:
	match a["do"]:
		"bridge":
			if a.get("on", true):
				bridge_from = tick if bridge_from < 0 else bridge_from
			else:
				_fall(m, tick)
		"ford":
			ford_on = a.get("on", true)
		"waves":
			var w: Dictionary = m.def.rules.get("waves", {})
			next_wave = tick + Num.of(w.get("every_ticks", 0)) if a.get("on", true) else -1
		"unprotect":
			for id in m.alive_of(str(a["group"])):
				m.combat.untouchable.erase(id)
		"transfer":
			_transfer(m, str(a["group"]), Num.of(a["player"]))
		"cast":
			var ids := m.alive_of(str(a["group"]))
			for id in ids:
				var spell := StringName(str(a["spell"]))
				var owner := m.entities.owners[id - 1]
				if m.magic.can_cast(owner, id, spell) == MagicSystem.Cast.OK:
					var x := m.entities.pos_x[id - 1]
					var y := m.entities.pos_y[id - 1]
					var one := PackedInt32Array([id])
					m._apply.call(SimCommand.cast(tick, owner, one, spell, x, y))
					break


## Units brought back over the river: the player's that crossed east and stand west now; with a
## group, the group's members west now.
func saved(m: MissionRuntime, group: String = "") -> int:
	var r: Dictionary = m.def.rules.get("rescue", {})
	if r.is_empty():
		return 0
	var west := Fixed.from_cells(Num.of(r["west_of"]) + 1)
	var e := m.entities
	var n := 0
	if not group.is_empty():
		for id in m.alive_of(group):
			if e.pos_x[id - 1] < west:
				n += 1
		return n
	var ids := crossed.keys()
	for id: int in ids:
		if e.is_alive(id) and e.hp[id - 1] > 0 and e.pos_x[id - 1] < west:
			n += 1
	return n


## The bridge's state as a share of its hp (permille), for the panel.
func bridge_permille(m: MissionRuntime) -> int:
	var full := Num.of(m.def.rules.get("bridge", {}).get("hp", 0))
	return 0 if bridge_fell or full <= 0 else bridge_hp * 1000 / full


func _cross(m: MissionRuntime) -> void:
	var r: Dictionary = m.def.rules.get("rescue", {})
	if r.is_empty():
		return
	var p := Num.of(r["player"])
	var east := Fixed.from_cells(Num.of(r["east_of"]))
	var e := m.entities
	for id in e.alive_ids:
		if e.owners[id - 1] == p and e.pos_x[id - 1] >= east:
			crossed[id] = true


func _bridge(m: MissionRuntime, tick: int) -> void:
	var b: Dictionary = m.def.rules.get("bridge", {})
	if b.is_empty() or bridge_fell or bridge_from < 0:
		return
	var at: Array = b["at"]
	var x := Fixed.from_cells(Num.of(at[0])) + Fixed.HALF
	var y := Fixed.from_cells(Num.of(at[1])) + Fixed.HALF
	var r := Fixed.from_cells(Num.of(b["radius"]))
	var e := m.entities
	var working := 0
	for id in m.alive_of(str(b["group"])):
		var s := id - 1
		if e.hp[s] <= 0 or m.combat.is_fleeing(id):
			continue
		var dx := e.pos_x[s] - x
		var dy := e.pos_y[s] - y
		if dx * dx + dy * dy <= r * r:
			working += 1
	bridge_hp = maxi(bridge_hp - working * Num.of(b["per_unit"]), 0)
	if bridge_hp == 0 or tick >= bridge_from + Num.of(b["fall_ticks"]):
		_fall(m, tick)


## The bridge goes down: its cells become water and everyone on them drowns.
func _fall(m: MissionRuntime, tick: int) -> void:
	var b: Dictionary = m.def.rules.get("bridge", {})
	if b.is_empty() or bridge_fell:
		return
	bridge_fell = true
	bridge_hp = 0
	var nav := m.economy.nav
	var water := nav.terrain_index(&"t_water")
	var rect: Array = b["cells"]
	var on := PackedInt32Array()
	var e := m.entities
	for id in e.alive_ids:
		var cx := Fixed.to_cells(e.pos_x[id - 1])
		var cy := Fixed.to_cells(e.pos_y[id - 1])
		if _inside(rect, cx, cy) and e.hp[id - 1] > 0:
			on.append(id)
	for cy in range(Num.of(rect[1]), Num.of(rect[3]) + 1):
		for cx in range(Num.of(rect[0]), Num.of(rect[2]) + 1):
			if water >= 0:
				nav.set_terrain(nav.cell_at(cx, cy), water)
	for id in on:
		drowned += 1
		m.combat.untouchable.erase(id)
		m.combat.lightning(id, 0, DROWN)
	m.flags["bridge_down"] = tick


## The ford: more than capacity in it and the last ones in go under.
func _ford(m: MissionRuntime, tick: int) -> void:
	var f: Dictionary = m.def.rules.get("ford", {})
	if f.is_empty() or not ford_on:
		ford_in.clear()
		return
	var rect: Array = f["cells"]
	var e := m.entities
	var now: Dictionary[int, int] = {}
	for id in e.alive_ids:
		var s := id - 1
		if e.hp[s] <= 0 or m.combat.untouchable.has(id):
			continue
		if _inside(rect, Fixed.to_cells(e.pos_x[s]), Fixed.to_cells(e.pos_y[s])):
			now[id] = ford_in.get(id, tick)
	ford_in = now
	var cap := Num.of(f["capacity"])
	if now.size() <= cap:
		return
	# Who came in last goes under first (ties: the higher id).
	var order: Array = []
	for id: int in now:
		order.append([now[id], id])
	order.sort()
	for k in range(cap, order.size()):
		var id: int = order[k][1]
		var dmg := maxi(e.max_hp[id - 1] * Num.of(f["drown_permille"]) / 1000, 1)
		if e.hp[id - 1] <= dmg:
			drowned += 1
		m.combat.lightning(id, 0, dmg)
	m.flags["crowding"] = tick


func _waves(m: MissionRuntime, tick: int) -> void:
	var w: Dictionary = m.def.rules.get("waves", {})
	if w.is_empty() or next_wave < 0 or tick < next_wave:
		return
	next_wave = tick + Num.of(w["every_ticks"])
	var name := "wave_%d" % waves
	waves += 1
	var g := {"group": name, "player": w["player"], "at": w["at"], "units": w["units"]}
	m.run({"do": "spawn", "stance": "aggressive"}.merged(g), tick)
	m.run({"do": "attack_move", "group": name, "to": w["to"]}, tick)
	m.flags["wave"] = tick


## The group's living members go over to `p`: each is taken off and the same unit comes in for
## the new side where it stood, with the HP it had.
func _transfer(m: MissionRuntime, group: String, p: int) -> void:
	var e := m.entities
	var ids := PackedInt32Array()
	for id in m.alive_of(group):
		var s := id - 1
		if e.hp[s] <= 0:
			continue
		var type := e.type_ids[s]
		var x := e.pos_x[s]
		var y := e.pos_y[s]
		var hp := e.hp[s]
		m._remove.call(id)
		var fresh: int = m._spawn.call(type, p, x, y)
		if fresh != EntityStore.NO_ID:
			e.hp[fresh - 1] = mini(hp, e.max_hp[fresh - 1])
			ids.append(fresh)
	m.groups[group] = ids


static func _inside(rect: Array, cx: int, cy: int) -> bool:
	return (
		cx >= Num.of(rect[0])
		and cx <= Num.of(rect[2])
		and cy >= Num.of(rect[1])
		and cy <= Num.of(rect[3])
	)


func write_to(buf: StreamPeerBuffer) -> void:
	buf.put_32(bridge_hp)
	buf.put_64(bridge_from)
	buf.put_8(1 if bridge_fell else 0)
	buf.put_8(1 if ford_on else 0)
	var inside := ford_in.keys()
	inside.sort()
	buf.put_32(inside.size())
	for id: int in inside:
		buf.put_32(id)
		buf.put_64(ford_in[id])
	buf.put_32(drowned)
	var ids := crossed.keys()
	ids.sort()
	buf.put_32(ids.size())
	for id: int in ids:
		buf.put_32(id)
	buf.put_64(next_wave)
	buf.put_32(waves)
