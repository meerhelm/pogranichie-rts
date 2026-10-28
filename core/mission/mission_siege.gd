class_name MissionSiege
extends RefCounted
## The rules of «ВКЛ 7. Слуцк, 1508» (def.rules.siege), run by MissionRuntime.step() on this
## object's state, which the runtime's save and hash carry: a wooden castle of two belts held
## against storming parties with ladders, fire and a hungry siege.
##
## Rules (siege):
##   player (the defender); belts {name: [x0, y0, x1, y1]} (the cells inside each belt of walls);
##     fall {enemies}: a belt is lost while at least that many enemy units stand in it and none
##     of the player's do, and won back once the player's stand there and no enemy does;
##   ladder {raise_ticks, climb_ticks, push_ticks, push_radius, fall_damage, tries}: a party set
##     to a ladder spot (the `ladders` action) walks to the foot of the wall and raises its
##     ladder there (raise_ticks with someone at the foot); then they climb one at a time
##     (climb_ticks each) and come down inside, where they storm on. The player's men within
##     push_radius cells of the ladder's top push it off (push_ticks, quicker for two or three);
##     whoever is on it falls (fall_damage) and the party raises it again while it has tries;
##     after the last one the party goes round to `else`;
##   wall {range, armor_m, armor_p}: the player's shooters standing inside a belt next to their
##     own wall, gate or tower shoot further and are harder to hit (a unit's own wall_range_bonus,
##     wall_armor_melee, wall_armor_pierce params come first);
##   militia {unit}: once `militia` is on, those units hit as hard as their militia_damage
##     (catalog: burghers «в осаде берёт оружие и бьёт на 5 Б»);
##   water {units, kinds, radius, unit_permille, water_permille}: a fire is put out quicker when
##     those units douse it (unit_permille more each) and when a prop of those kinds (a well,
##     barrels) is within radius cells of it (water_permille more for every douser);
##   lady {group, belt, home, floor_permille, douse_permille}: she only walks inside her belt
##     (sent back home when outside); the player's units within her aura radius do not lose
##     heart below floor_permille of their full morale, and fires there are put out quicker;
##   starve {morale}: while the player has no food, each of his units loses that much morale a
##     check (the hunger rule eats the food);
##   posad {buildings, every_ticks, food}: each of those buildings still standing brings food;
##   boats {pier, radius, every_ticks, food}: boats bring food to the pier unless an enemy unit
##     stands within radius cells of it;
##   tunnel {from, to, radius}: once on, the player's units that step on one mouth of the secret
##     passage come out of the other;
##   workshops {buildings, delay_ticks, ladders_less}: each one burned (set on fire or gone)
##     puts the next assault off by delay_ticks;
##   fire_arrows {group, every_ticks, belts}: while on and the group lives, every every_ticks a
##     flammable building of the player in those belts (not walls, gates or towers) catches fire;
##   lines_catch: false keeps the player's walls, gates and towers from catching a fire nearby.
## The player's storm («Гнев Перкуна») puts out every fire of his under it.
## Conditions: belt_lost {belt}; belt_fell {belt, at_least?}; burned {at_least}; assault_due;
##   ladders_spent {group}; manned {at_least} (shooters on the walls); in_belt {group}; hp_at_least
##   {group, permille}; standing {buildings, permille}; tunnel_used.
## Actions: ladders {group, spots: [[wall x, wall y, foot x, foot y], ...], goal, else};
##   assault_at {ticks} (the assault is due that long from now, plus the workshops' delay);
##   militia; fire_arrows {on}; tunnel {on}.

## Ladder states: carried to the wall or being raised, standing against it, done with.
enum Ladder { RAISING, UP, DONE }
const CONDITIONS: Array[String] = [
	"belt_lost",
	"belt_fell",
	"burned",
	"assault_due",
	"ladders_spent",
	"manned",
	"in_belt",
	"hp_at_least",
	"standing",
	"tunnel_used",
]
const ACTIONS: Array[String] = ["ladders", "assault_at", "militia", "fire_arrows", "tunnel"]
## Bases of the buildings a wall stands in (and the fire arrows leave alone).
const LINES: Array[StringName] = [&"wall", &"palisade", &"gate", &"tower"]
## How close (cells) a party member must be to the foot to raise or climb.
const AT_FOOT := 2
## At most this many pushers count.
const PUSHERS := 3

## Belts lost now, and how many times each fell.
var lost: Dictionary[String, bool] = {}
var falls: Dictionary[String, int] = {}
## Ladders, by index: the party's group, the wall, foot and top cells, the state, raising and
## pushing done (ticks), the climber (0: none) and his climbing done, raises left, and where the
## party storms once inside (goal) or once its ladder is done with (else), as cells.
var l_group: Array[String] = []
var l_wall := PackedInt32Array()
var l_foot := PackedInt32Array()
var l_top := PackedInt32Array()
var l_state := PackedInt32Array()
var l_raise := PackedInt32Array()
var l_push := PackedInt32Array()
var l_climber := PackedInt32Array()
var l_climb := PackedInt32Array()
var l_tries := PackedInt32Array()
var l_goal := PackedInt32Array()
var l_else := PackedInt32Array()
## Party members -> their ladder; how many came over the walls, how many ladders were pushed.
var assigned: Dictionary[int, int] = {}
var climbed := 0
var pushed := 0
## Shooters on the walls: unit id -> the range and armor bonuses given.
var wall_range: Dictionary[int, int] = {}
var wall_armor_m: Dictionary[int, int] = {}
var wall_armor_p: Dictionary[int, int] = {}
var militia := false
## When the assault is due (-1: not set) before the workshops' delay.
var assault_base := -1
var burned_set: Dictionary[String, bool] = {}
var arrows_on := false
var next_arrow := -1
var tunnel_on := false
var tunnel_used := false
var next_posad := -1
var next_boat := -1
## Food brought by the posad and the boats (for the panel and the tests).
var food_in := 0
## The tick of the last step (what the conditions compare with).
var now := 0


func set_up(m: MissionRuntime) -> void:
	var r := _rules(m)
	if r.is_empty():
		return
	# A siege starts by day (the night is the stealth module's, which starts dark).
	m.stealth.night = false
	for b: String in r.get("belts", {}):
		lost[b] = false
		falls[b] = 0
	if not r.get("lines_catch", true):
		var store := m.economy.buildings
		for b in store.alive_ids:
			if store.owners[b - 1] == Num.of(r["player"]) and LINES.has(store.defs[b - 1].base_id):
				m.fire.no_spread[b] = true
	var posad: Dictionary = r.get("posad", {})
	if not posad.is_empty():
		next_posad = Num.of(posad["every_ticks"])
	var boats: Dictionary = r.get("boats", {})
	if not boats.is_empty():
		next_boat = Num.of(boats["every_ticks"])


func step(m: MissionRuntime, tick: int) -> void:
	var r := _rules(m)
	now = tick
	if r.is_empty():
		return
	_belts(m, r)
	_ladders(m, r, tick)
	_walls(m, r)
	_lady(m, r, tick)
	_water(m, r)
	_rain(m, r)
	_arrows(m, r, tick)
	_burned(m, r)
	_food(m, r, tick)
	_tunnel(m, r, tick)


func test(m: MissionRuntime, c: Dictionary) -> bool:
	var ok := false
	match c["type"]:
		"belt_lost":
			ok = lost.get(c["belt"], false)
		"belt_fell":
			ok = falls.get(c["belt"], 0) >= Num.of(c.get("at_least", 1))
		"burned":
			ok = burned_set.size() >= Num.of(c["at_least"])
		"assault_due":
			ok = assault_base >= 0 and now >= assault_due(m)
		"ladders_spent":
			ok = ladders_spent(str(c["group"]))
		"manned":
			ok = wall_range.size() >= Num.of(c["at_least"])
		"in_belt":
			for id in m.alive_of(str(c["group"])):
				ok = ok or not belt_of(m, id).is_empty()
		"hp_at_least":
			ok = _hp_at_least(m, str(c["group"]), Num.of(c["permille"]))
		"standing":
			ok = standing_permille(m, c["buildings"]) >= Num.of(c["permille"])
		"tunnel_used":
			ok = tunnel_used
	return ok


## Whether the group has someone alive and all of it is at least at `permille` of full health.
func _hp_at_least(m: MissionRuntime, group: String, permille: int) -> bool:
	var ids := m.alive_of(group)
	for id in ids:
		var s := id - 1
		if m.entities.hp[s] * 1000 < m.entities.max_hp[s] * permille:
			return false
	return not ids.is_empty()


func run(m: MissionRuntime, a: Dictionary, tick: int) -> void:
	match a["do"]:
		"ladders":
			_set_ladders(m, a, tick)
		"assault_at":
			assault_base = tick + Num.of(a["ticks"])
		"militia":
			_arm(m)
		"fire_arrows":
			arrows_on = a.get("on", true)
			var fa: Dictionary = _rules(m).get("fire_arrows", {})
			next_arrow = tick + Num.of(fa.get("every_ticks", 0)) if arrows_on else -1
		"tunnel":
			tunnel_on = a.get("on", true)


## When the assault comes: the time set plus the delay of every workshop burned.
func assault_due(m: MissionRuntime) -> int:
	var w: Dictionary = _rules(m).get("workshops", {})
	return assault_base + burned_set.size() * Num.of(w.get("delay_ticks", 0))


func ladders_spent(group: String) -> bool:
	var any := false
	for i in l_group.size():
		if l_group[i] == group:
			any = true
			if l_state[i] != Ladder.DONE:
				return false
	return any


## Ladders standing against the walls now (for the panel).
func ladders_up() -> int:
	var n := 0
	for i in l_state.size():
		if l_state[i] == Ladder.UP:
			n += 1
	return n


## The belt the unit stands in, or "".
func belt_of(m: MissionRuntime, id: int) -> String:
	var cx := Fixed.to_cells(m.entities.pos_x[id - 1])
	var cy := Fixed.to_cells(m.entities.pos_y[id - 1])
	var belts: Dictionary = _rules(m).get("belts", {})
	var names := belts.keys()
	names.sort()
	for b: String in names:
		if _inside(belts[b], cx, cy):
			return b
	return ""


## Share (permille) of the named buildings still standing.
func standing_permille(m: MissionRuntime, names: Array) -> int:
	if names.is_empty():
		return 0
	var n := 0
	for name: String in names:
		if m.economy.buildings.is_alive(Num.of(m.named.get(name, 0))):
			n += 1
	return n * 1000 / names.size()


func _rules(m: MissionRuntime) -> Dictionary:
	return m.def.rules.get("siege", {})


static func _inside(rect: Array, cx: int, cy: int) -> bool:
	return (
		cx >= Num.of(rect[0])
		and cx <= Num.of(rect[2])
		and cy >= Num.of(rect[1])
		and cy <= Num.of(rect[3])
	)


static func _cell_x(m: MissionRuntime, cell: int) -> int:
	return m.economy.nav.center_x(cell)


static func _cell_y(m: MissionRuntime, cell: int) -> int:
	return m.economy.nav.center_y(cell)


func _fit(m: MissionRuntime, id: int) -> bool:
	return m.entities.is_alive(id) and m.entities.hp[id - 1] > 0 and not m.combat.is_fleeing(id)


func _near_cell(m: MissionRuntime, id: int, cell: int, cells: int) -> bool:
	var dx := m.entities.pos_x[id - 1] - _cell_x(m, cell)
	var dy := m.entities.pos_y[id - 1] - _cell_y(m, cell)
	var r := Fixed.from_cells(cells)
	return dx * dx + dy * dy <= r * r


# --- belts ----------------------------------------------------------------------------------


func _belts(m: MissionRuntime, r: Dictionary) -> void:
	var belts: Dictionary = r.get("belts", {})
	var need := Num.of(r.get("fall", {}).get("enemies", 1))
	var p := Num.of(r["player"])
	var e := m.entities
	var names := belts.keys()
	names.sort()
	for b: String in names:
		var rect: Array = belts[b]
		var own := 0
		var foes := 0
		for id in e.alive_ids:
			var s := id - 1
			if (
				e.hp[s] <= 0
				or not _inside(rect, Fixed.to_cells(e.pos_x[s]), Fixed.to_cells(e.pos_y[s]))
			):
				continue
			if e.owners[s] == p:
				own += 1
			elif m.are_hostile(p, e.owners[s]):
				foes += 1
		if not lost[b] and own == 0 and foes >= need:
			lost[b] = true
			falls[b] += 1
		elif lost[b] and own > 0 and foes == 0:
			lost[b] = false


# --- ladders --------------------------------------------------------------------------------


func _set_ladders(m: MissionRuntime, a: Dictionary, tick: int) -> void:
	var lr: Dictionary = _rules(m).get("ladder", {})
	var nav := m.economy.nav
	var spots: Array = a["spots"]
	var goal: Array = a["goal"]
	var away: Array = a.get("else", goal)
	var first := l_group.size()
	for spot: Array in spots:
		var wall := Vector2i(Num.of(spot[0]), Num.of(spot[1]))
		var foot := Vector2i(Num.of(spot[2]), Num.of(spot[3]))
		var top := wall * 2 - foot
		l_group.append(a["group"])
		l_wall.append(nav.cell_at(wall.x, wall.y))
		l_foot.append(nav.cell_at(foot.x, foot.y))
		l_top.append(nav.cell_at(top.x, top.y))
		l_state.append(Ladder.RAISING)
		l_raise.append(0)
		l_push.append(0)
		l_climber.append(0)
		l_climb.append(0)
		l_tries.append(Num.of(lr.get("tries", 1)))
		l_goal.append(nav.cell_at(Num.of(goal[0]), Num.of(goal[1])))
		l_else.append(nav.cell_at(Num.of(away[0]), Num.of(away[1])))
	# The party splits over its ladders in turn and carries them to the wall, not fighting
	# on the way.
	var ids := m.alive_of(str(a["group"]))
	var count := l_group.size() - first
	if count <= 0 or ids.is_empty():
		return
	var owner := m.entities.owners[ids[0] - 1]
	m._apply.call(SimCommand.set_stance(tick, owner, ids, EntityStore.Stance.PASSIVE))
	for k in ids.size():
		assigned[ids[k]] = first + k % count
	for i in range(first, first + count):
		_to_foot(m, i, tick)


## Sends the ladder's party members that are not at its foot there.
func _to_foot(m: MissionRuntime, i: int, tick: int) -> void:
	var cell := l_foot[i]
	var ids := PackedInt32Array()
	for id in _party(m, i):
		if (
			not _near_cell(m, id, cell, AT_FOOT)
			and m.entities.orders[id - 1] == EntityStore.Order.IDLE
		):
			ids.append(id)
	if ids.is_empty():
		return
	var owner := m.entities.owners[ids[0] - 1]
	m._apply.call(SimCommand.move(tick, owner, ids, _cell_x(m, cell), _cell_y(m, cell)))


## The ladder's party alive and able, ascending.
func _party(m: MissionRuntime, i: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var ids := assigned.keys()
	ids.sort()
	for id: int in ids:
		if assigned[id] == i and _fit(m, id):
			out.append(id)
	return out


func _ladders(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	var lr: Dictionary = r.get("ladder", {})
	for id: int in assigned.keys():
		if not m.entities.is_alive(id):
			assigned.erase(id)
	for i in l_group.size():
		if l_state[i] == Ladder.DONE:
			continue
		var party := _party(m, i)
		if party.is_empty():
			l_state[i] = Ladder.DONE
			l_climber[i] = 0
			continue
		var at_foot := PackedInt32Array()
		for id in party:
			if _near_cell(m, id, l_foot[i], AT_FOOT):
				at_foot.append(id)
		if l_state[i] == Ladder.RAISING:
			if at_foot.is_empty():
				if tick % 100 == 0:
					_to_foot(m, i, tick)
				continue
			l_raise[i] += MissionRuntime.CHECK_EVERY
			if l_raise[i] >= Num.of(lr.get("raise_ticks", 0)):
				l_state[i] = Ladder.UP
				l_push[i] = 0
				m.flags["ladder_up"] = tick
			continue
		_push(m, r, i, tick)
		if l_state[i] == Ladder.UP:
			_climb(m, lr, i, at_foot, tick)


## The player's men at the top push the ladder off.
func _push(m: MissionRuntime, r: Dictionary, i: int, tick: int) -> void:
	var lr: Dictionary = r.get("ladder", {})
	var p := Num.of(r["player"])
	var n := 0
	for id in m.entities.alive_ids:
		if m.entities.owners[id - 1] != p or not _fit(m, id):
			continue
		if _near_cell(m, id, l_top[i], Num.of(lr.get("push_radius", 2))):
			n += 1
			if n >= PUSHERS:
				break
	if n == 0:
		return
	l_push[i] += MissionRuntime.CHECK_EVERY * n
	if l_push[i] < Num.of(lr.get("push_ticks", 0)):
		return
	pushed += 1
	m.flags["ladder_pushed"] = tick
	var climber := l_climber[i]
	if climber != 0 and m.entities.is_alive(climber):
		m.combat.lightning(climber, p, Num.of(lr.get("fall_damage", 0)))
	l_climber[i] = 0
	l_climb[i] = 0
	l_raise[i] = 0
	l_push[i] = 0
	l_tries[i] -= 1
	if l_tries[i] > 0:
		l_state[i] = Ladder.RAISING
		return
	l_state[i] = Ladder.DONE
	var ids := _party(m, i)
	for id in ids:
		assigned.erase(id)
	if not ids.is_empty():
		var owner := m.entities.owners[ids[0] - 1]
		var to := l_else[i]
		m._apply.call(SimCommand.set_stance(tick, owner, ids, EntityStore.Stance.AGGRESSIVE))
		m._apply.call(SimCommand.attack_move(tick, owner, ids, _cell_x(m, to), _cell_y(m, to)))


## One man at a time goes up; at the top he comes down inside and storms on.
func _climb(
	m: MissionRuntime, lr: Dictionary, i: int, at_foot: PackedInt32Array, tick: int
) -> void:
	var climber := l_climber[i]
	if climber != 0 and (not _fit(m, climber) or not at_foot.has(climber)):
		climber = 0
		l_climb[i] = 0
	if climber == 0:
		if at_foot.is_empty():
			return
		climber = at_foot[0]
		l_climber[i] = climber
		l_climb[i] = 0
	l_climb[i] += MissionRuntime.CHECK_EVERY
	if l_climb[i] < Num.of(lr.get("climb_ticks", 0)):
		return
	var e := m.entities
	var owner := e.owners[climber - 1]
	var one := PackedInt32Array([climber])
	m._apply.call(SimCommand.stop(tick, owner, one))
	e.pos_x[climber - 1] = _cell_x(m, l_top[i])
	e.pos_y[climber - 1] = _cell_y(m, l_top[i])
	assigned.erase(climber)
	climbed += 1
	l_climber[i] = 0
	l_climb[i] = 0
	m.flags["climbed"] = tick
	var goal := l_goal[i]
	m._apply.call(SimCommand.set_stance(tick, owner, one, EntityStore.Stance.AGGRESSIVE))
	m._apply.call(SimCommand.attack_move(tick, owner, one, _cell_x(m, goal), _cell_y(m, goal)))


# --- shooters on the walls ------------------------------------------------------------------


func _walls(m: MissionRuntime, r: Dictionary) -> void:
	var w: Dictionary = r.get("wall", {})
	if w.is_empty():
		return
	var p := Num.of(r["player"])
	var e := m.entities
	for id: int in wall_range.keys():
		if not e.is_alive(id):
			wall_range.erase(id)
			wall_armor_m.erase(id)
			wall_armor_p.erase(id)
	for id in e.alive_ids:
		var s := id - 1
		var def := m.economy.unit_defs[s]
		if e.owners[s] != p or def == null or def.attack_range <= 0:
			continue
		var on := _on_wall(m, p, id)
		if on and not wall_range.has(id):
			wall_range[id] = def.param(&"wall_range_bonus", Num.of(w.get("range", 0)))
			wall_armor_m[id] = def.param(&"wall_armor_melee", Num.of(w.get("armor_m", 0)))
			wall_armor_p[id] = def.param(&"wall_armor_pierce", Num.of(w.get("armor_p", 0)))
			e.up_range[s] += wall_range[id]
			e.up_armor_m[s] += wall_armor_m[id]
			e.up_armor_p[s] += wall_armor_p[id]
		elif not on and wall_range.has(id):
			e.up_range[s] -= wall_range[id]
			e.up_armor_m[s] -= wall_armor_m[id]
			e.up_armor_p[s] -= wall_armor_p[id]
			wall_range.erase(id)
			wall_armor_m.erase(id)
			wall_armor_p.erase(id)


## Inside a belt and right by an own wall, gate or tower.
func _on_wall(m: MissionRuntime, p: int, id: int) -> bool:
	if belt_of(m, id).is_empty():
		return false
	var nav := m.economy.nav
	var store := m.economy.buildings
	var cx := Fixed.to_cells(m.entities.pos_x[id - 1])
	var cy := Fixed.to_cells(m.entities.pos_y[id - 1])
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if not nav.in_bounds(cx + dx, cy + dy):
				continue
			var b := store.occupant[nav.cell_at(cx + dx, cy + dy)]
			if b == BuildingStore.NO_ID or store.owners[b - 1] != p:
				continue
			if LINES.has(store.defs[b - 1].base_id) and store.done[b - 1] == 1:
				return true
	return false


# --- the princess, fire and water -----------------------------------------------------------


func _lady(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	var lady: Dictionary = r.get("lady", {})
	if lady.is_empty():
		return
	var ids := m.alive_of(str(lady["group"]))
	if ids.is_empty():
		return
	var her := ids[0]
	var e := m.entities
	var rect: Array = r["belts"][lady["belt"]]
	if not _inside(rect, Fixed.to_cells(e.pos_x[her - 1]), Fixed.to_cells(e.pos_y[her - 1])):
		if e.orders[her - 1] == EntityStore.Order.IDLE or tick % 100 == 0:
			var home: Array = lady["home"]
			var x := Fixed.from_cells(Num.of(home[0])) + Fixed.HALF
			var y := Fixed.from_cells(Num.of(home[1])) + Fixed.HALF
			m._apply.call(SimCommand.move(tick, e.owners[her - 1], PackedInt32Array([her]), x, y))
	var reach := Fixed.from_cells(m.combat.aura_radius(m.economy.unit_defs[her - 1]))
	var floor_permille := Num.of(lady.get("floor_permille", 0))
	for id in e.alive_ids:
		var s := id - 1
		var def := m.economy.unit_defs[s]
		if e.owners[s] != e.owners[her - 1] or id == her or def == null or def.morale <= 0:
			continue
		var dx := e.pos_x[s] - e.pos_x[her - 1]
		var dy := e.pos_y[s] - e.pos_y[her - 1]
		if dx * dx + dy * dy > reach * reach or m.combat.is_fleeing(id):
			continue
		var low := def.morale * CombatSystem.MORALE_SCALE * floor_permille / 1000
		e.morale[s] = maxi(e.morale[s], low)


## Extra dousing (thousandths of a tick of work per douser and check) at a burning building of
## the player: burghers douse quicker, so does anyone with water near or the princess by.
func _water(m: MissionRuntime, r: Dictionary) -> void:
	var fire := m.fire
	if fire.burning.is_empty():
		return
	var p := Num.of(r["player"])
	var w: Dictionary = r.get("water", {})
	var lady: Dictionary = r.get("lady", {})
	var her := 0
	if not lady.is_empty():
		var l := m.alive_of(str(lady["group"]))
		her = l[0] if not l.is_empty() else 0
	var store := m.economy.buildings
	var ids := fire.burning.keys()
	ids.sort()
	for b: int in ids:
		if not store.is_alive(b) or store.owners[b - 1] != p:
			continue
		var extra := 0
		var near_water := _water_near(m, w, b)
		var lady_near := her != 0 and _lady_near(m, her, b)
		var dousers := fire.dousers.keys()
		dousers.sort()
		for id: int in dousers:
			if fire.dousers[id] != b or not m.entities.is_alive(id):
				continue
			if (
				store.distance_sq(b, m.entities.pos_x[id - 1], m.entities.pos_y[id - 1])
				> Fixed.ONE * Fixed.ONE * 4
			):
				continue
			if (w.get("units", []) as Array).has(String(m.entities.type_ids[id - 1])):
				extra += Num.of(w.get("unit_permille", 0))
			if near_water:
				extra += Num.of(w.get("water_permille", 0))
			if lady_near:
				extra += Num.of(lady.get("douse_permille", 0))
		if extra <= 0:
			continue
		fire.doused[b] = fire.doused.get(b, 0) + MissionRuntime.CHECK_EVERY * extra / 1000
		if fire.doused[b] >= fire.rules.douse_ticks:
			fire.put_out(b)


func _water_near(m: MissionRuntime, w: Dictionary, b: int) -> bool:
	if w.is_empty():
		return false
	var kinds: Array = w.get("kinds", [])
	var reach := Fixed.from_cells(Num.of(w.get("radius", 0)))
	for prop: Dictionary in m.def.setup.get("props", []):
		if not kinds.has(prop["kind"]):
			continue
		var at: Array = prop["at"]
		var x := Fixed.from_cells(Num.of(at[0])) + Fixed.HALF
		var y := Fixed.from_cells(Num.of(at[1])) + Fixed.HALF
		if m.economy.buildings.distance_sq(b, x, y) <= reach * reach:
			return true
	return false


func _lady_near(m: MissionRuntime, her: int, b: int) -> bool:
	var reach := Fixed.from_cells(m.combat.aura_radius(m.economy.unit_defs[her - 1]))
	var x := m.entities.pos_x[her - 1]
	var y := m.entities.pos_y[her - 1]
	return m.economy.buildings.distance_sq(b, x, y) <= reach * reach


## The player's storm puts out his fires under it (the card: rain puts the fires out).
func _rain(m: MissionRuntime, r: Dictionary) -> void:
	var fire := m.fire
	if fire.burning.is_empty():
		return
	var p := Num.of(r["player"])
	var magic := m.magic
	var store := m.economy.buildings
	for i in magic.fx_ids.size():
		if magic.fx_owner[i] != p or not magic.spells[magic.fx_spell[i]].tags.has(&"storm"):
			continue
		var reach := Fixed.from_cells(magic.fx_radius[i])
		var ids := fire.burning.keys()
		ids.sort()
		for b: int in ids:
			if not store.is_alive(b) or store.owners[b - 1] != p:
				continue
			if store.distance_sq(b, magic.fx_x[i], magic.fx_y[i]) <= reach * reach:
				fire.put_out(b)
				m.flags["rain_put_out"] = now


func _arrows(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	var fa: Dictionary = r.get("fire_arrows", {})
	if fa.is_empty() or not arrows_on or next_arrow < 0 or tick < next_arrow:
		return
	next_arrow = tick + Num.of(fa["every_ticks"])
	if m.alive_of(str(fa["group"])).is_empty():
		return
	var p := Num.of(r["player"])
	var store := m.economy.buildings
	var nav := m.economy.nav
	var belts: Dictionary = r.get("belts", {})
	var can := PackedInt32Array()
	for b in store.alive_ids:
		var s := b - 1
		if store.owners[s] != p or LINES.has(store.defs[s].base_id) or not m.fire.flammable(b):
			continue
		var cx := Fixed.to_cells(store.center_x(b))
		var cy := Fixed.to_cells(store.center_y(b))
		for name: String in fa.get("belts", []):
			if _inside(belts[name], cx, cy):
				can.append(b)
				break
	if can.is_empty():
		return
	var b := can[m.fire.rng.next_below(can.size())]
	m.fire.ignite(b)
	m.flags["fire_arrow"] = tick
	var at := Vector2i(Fixed.to_cells(store.center_x(b)), Fixed.to_cells(store.center_y(b)))
	if nav.in_bounds(at.x, at.y):
		m.run({"do": "ping", "at": [at.x, at.y], "radius": 2}, tick)


## Workshops set on fire or gone count as burned, for good.
func _burned(m: MissionRuntime, r: Dictionary) -> void:
	var w: Dictionary = r.get("workshops", {})
	for name: String in w.get("buildings", []):
		if burned_set.has(name):
			continue
		var b: int = m.named.get(name, 0)
		if not m.economy.buildings.is_alive(b) or m.fire.is_burning(b):
			burned_set[name] = true


# --- food -----------------------------------------------------------------------------------


func _food(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	var p := Num.of(r["player"])
	var state := m.economy.player(p)
	if state == null:
		return
	var posad: Dictionary = r.get("posad", {})
	if not posad.is_empty() and next_posad >= 0 and tick >= next_posad:
		next_posad = tick + Num.of(posad["every_ticks"])
		var n := 0
		for name: String in posad["buildings"]:
			if m.economy.buildings.is_alive(Num.of(m.named.get(name, 0))):
				n += 1
		state.stock[EconomySystem.FOOD] += n * Num.of(posad["food"])
		food_in += n * Num.of(posad["food"])
	var boats: Dictionary = r.get("boats", {})
	if not boats.is_empty() and next_boat >= 0 and tick >= next_boat:
		next_boat = tick + Num.of(boats["every_ticks"])
		if not _enemy_near(m, p, boats["pier"], Num.of(boats["radius"])):
			state.stock[EconomySystem.FOOD] += Num.of(boats["food"])
			food_in += Num.of(boats["food"])
			m.flags["boat"] = tick
	var starve: Dictionary = r.get("starve", {})
	if starve.is_empty() or state.stock[EconomySystem.FOOD] > 0:
		return
	m.flags["starving"] = tick
	for id in m.entities.alive_ids:
		if m.entities.owners[id - 1] == p:
			m.combat.lose_morale(id - 1, Num.of(starve["morale"]))


func _enemy_near(m: MissionRuntime, p: int, at: Array, radius: int) -> bool:
	var x := Fixed.from_cells(Num.of(at[0])) + Fixed.HALF
	var y := Fixed.from_cells(Num.of(at[1])) + Fixed.HALF
	var reach := Fixed.from_cells(radius)
	var e := m.entities
	for id in e.alive_ids:
		var s := id - 1
		if e.hp[s] <= 0 or not m.are_hostile(p, e.owners[s]):
			continue
		var dx := e.pos_x[s] - x
		var dy := e.pos_y[s] - y
		if dx * dx + dy * dy <= reach * reach:
			return true
	return false


# --- the secret passage ---------------------------------------------------------------------


func _tunnel(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	var t: Dictionary = r.get("tunnel", {})
	if t.is_empty() or not tunnel_on:
		return
	var p := Num.of(r["player"])
	var mouths: Array = [t["from"], t["to"]]
	var radius := Num.of(t.get("radius", 1))
	var e := m.entities
	for id in e.alive_ids:
		var s := id - 1
		if e.owners[s] != p or not _fit(m, id):
			continue
		for k in 2:
			var at: Array = mouths[k]
			var x := Fixed.from_cells(Num.of(at[0])) + Fixed.HALF
			var y := Fixed.from_cells(Num.of(at[1])) + Fixed.HALF
			var dx := e.pos_x[s] - x
			var dy := e.pos_y[s] - y
			var reach := Fixed.from_cells(radius) - Fixed.HALF
			if dx * dx + dy * dy > reach * reach or e.orders[s] != EntityStore.Order.IDLE:
				continue
			# Out of the other mouth, a step clear of it, standing.
			var out: Array = mouths[1 - k]
			var side: Array = t.get("out_from" if k == 1 else "out_to", [0, 1])
			m._apply.call(SimCommand.stop(tick, p, PackedInt32Array([id])))
			e.pos_x[s] = Fixed.from_cells(Num.of(out[0]) + Num.of(side[0])) + Fixed.HALF
			e.pos_y[s] = Fixed.from_cells(Num.of(out[1]) + Num.of(side[1])) + Fixed.HALF
			if not tunnel_used:
				tunnel_used = true
				m.flags["tunnel_used"] = tick
			break


func _arm(m: MissionRuntime) -> void:
	var mi: Dictionary = _rules(m).get("militia", {})
	if mi.is_empty() or militia:
		return
	militia = true
	var p := Num.of(_rules(m)["player"])
	var e := m.entities
	for id in e.alive_ids:
		var def := m.economy.unit_defs[id - 1]
		if e.owners[id - 1] == p and def != null and String(def.id) == mi["unit"]:
			e.up_damage[id - 1] += maxi(def.param(&"militia_damage", def.damage) - def.damage, 0)


# --- state ----------------------------------------------------------------------------------


func write_to(buf: StreamPeerBuffer) -> void:
	var names := lost.keys()
	names.sort()
	for b: String in names:
		buf.put_utf8_string(b)
		buf.put_8(1 if lost[b] else 0)
		buf.put_32(falls[b])
	buf.put_32(l_group.size())
	for i in l_group.size():
		buf.put_utf8_string(l_group[i])
		for arr: PackedInt32Array in [
			l_wall,
			l_foot,
			l_top,
			l_state,
			l_raise,
			l_push,
			l_climber,
			l_climb,
			l_tries,
			l_goal,
			l_else
		]:
			buf.put_32(arr[i])
	for d: Dictionary in [assigned, wall_range, wall_armor_m, wall_armor_p]:
		var keys := d.keys()
		keys.sort()
		buf.put_32(keys.size())
		for k: int in keys:
			buf.put_32(k)
			buf.put_32(Num.of(d[k]))
	var burned := burned_set.keys()
	burned.sort()
	for name: String in burned:
		buf.put_utf8_string(name)
	buf.put_32(climbed)
	buf.put_32(pushed)
	buf.put_8(1 if militia else 0)
	buf.put_64(assault_base)
	buf.put_8(1 if arrows_on else 0)
	buf.put_64(next_arrow)
	buf.put_8(1 if tunnel_on else 0)
	buf.put_8(1 if tunnel_used else 0)
	buf.put_64(next_posad)
	buf.put_64(next_boat)
	buf.put_32(food_in)
