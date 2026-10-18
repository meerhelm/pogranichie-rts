class_name MissionStealth
extends RefCounted
## The rules of «ВКЛ 6. Волчья тропа, 1507» (def.rules.stealth), run by MissionRuntime.step() on
## this object's state, which the runtime's save and hash carry: a small band slips past the
## border watch. Watchers see in a cone the way they face (half as far at night, further in a
## campfire's light, only close up into a forest), hear horses at a trot and their dogs smell
## whoever is near; each of these fills one detection meter, and a full meter raises the alarm.
## Night and day, tired horses, horses led on foot, fresh horses from a village stable, hidden
## places of power and the trails «Волчья тропа» opens from them are here too (an open trail
## is under the trees: the eye sees onto it as into a forest, and dogs find no scent on it).
##
## Rules (stealth):
##   known_map (the player starts with the whole map explored);
##   groups (the fugitives: whom the watch looks for), finder (who finds hidden places), watchers
##     (players whose units and buildings in `towers` watch), towers (building ids that see all
##     round);
##   hidden (place indices kept off the map), reveal_radius (cells from the finder), charge
##     (Сила a found place gives), paths {place: [[x, y], ...]} (the trail «Волчья тропа» opens
##     from that place: a line of cells, two wide, whose closed cells turn to t_road while open);
##   cone_permille (cosine of half the cone, ×1000), night_permille (sight at night), torches
##     (groups that carry torches: torch_permille at night), lit_permille (sight onto someone in
##     a campfire's light; light_radius cells round each prop_campfire of the setup's props),
##     day_open_permille (by day, onto someone moving in the open), cover (cells: how close one
##     must be to see into a forest; a hero tagged forest_stealth is not seen there at all);
##   see, noise, dogs (meter points, of 1000, a check for each watcher who sees, hears or smells
##     a fugitive; seeing from within half the sight counts double), noise_cells and
##     road_noise_cells (how far a trot is heard), decay (points lost a check with nobody
##     noticed), alarm_radius (watchers this near rise and ride to the spot), alarm_reset (the
##     meter after an alarm; it does not rise for alarm_calm_ticks after), alarm_cut_ticks
##     (each alarm brings the chase this much nearer);
##   guide {group, radius} (near this group the fugitives raise no suspicion: the Keeper's gať);
##   stamina {drain, rest, rest_still, tired_until, walk_permille}: a horse at a trot loses
##     drain a check, led or resting it gets rest (rest_still standing); at 0 it is tired and
##     only walks until it has tired_until again; walking goes at walk_permille of the speed;
##   stable {building, radius, share}: the first fugitive at the stable takes fresh horses for
##     everyone within share cells, and the alarm goes up there;
##   posts [{group, look: [[dx, dy], ...], every_ticks}]: watchers that stand and turn through
##     the looks; patrols [{group, route: [[x, y], ...]}]: watchers that ride the route round.
## Conditions: alarm {at_least} (alarms raised); detection {at_least} (the meter, of 1000); found
##   {place}; found_count {at_least}; night {is}; pursuit_due (the chase's time has come);
##   west_of {group, x} (a living member stands in a column west of x).
## Actions: daylight {night}; stealth {on} (the watch looks or not); reveal {place}; open_path
##   {place, ticks} (-1: for good); pursuit {ticks} (the chase sets out in that many ticks, or
##   sooner if it was due sooner).

const CONDITIONS: Array[String] = [
	"alarm", "detection", "found", "found_count", "night", "pursuit_due", "west_of"
]
const ACTIONS: Array[String] = ["daylight", "stealth", "reveal", "open_path", "pursuit"]
const FULL := 1000

## The watch looks (rules present and not switched off) and whether it is night.
var on := false
var night := true
## The detection meter (of FULL), alarms raised, and where the watch last noticed someone.
var meter := 0
var alarms := 0
var last_x := 0
var last_y := 0
## Per fugitive: the horse's strength (of FULL), led on foot, and tired.
var stamina: Dictionary[int, int] = {}
var walking: Dictionary[int, bool] = {}
var tired: Dictionary[int, bool] = {}
## Places found, and open trails: place -> the tick it closes (-1: never).
var found: Dictionary[int, bool] = {}
var path_until: Dictionary[int, int] = {}
## Cells of open trails -> the terrain index they had.
var path_old: Dictionary[int, int] = {}
## The last «Волчья тропа» effect looked at (MagicSystem effect id).
var wolf_seen := 0
## When the chase sets out (-1: not yet known).
var pursuit_at := -1
## Patrols: group -> index of the waypoint it rides to. Watchers roused by an alarm.
var patrol_leg: Dictionary[String, int] = {}
var roused: Dictionary[int, bool] = {}
var stable_used := false
## Until this tick, after an alarm, the meter does not rise (the watch is already roused).
var calm_until := 0
## The tick of the last step (what the conditions compare with).
var now := 0


func set_up(m: MissionRuntime) -> void:
	# Props (setup.props [{kind, at, block?}]) are drawn by the game; a blocking one closes its cell.
	for p: Dictionary in m.def.setup.get("props", []):
		var at: Array = p["at"]
		if p.get("block", false) and m.economy.nav.in_bounds(at[0], at[1]):
			m.economy.nav.set_blocked(m.economy.nav.cell_at(at[0], at[1]), true)
	var r := _rules(m)
	if r.is_empty():
		return
	on = true
	if r.get("known_map", false) and m.combat.vision != null and m.combat.vision.enabled():
		m.combat.vision.explore_all(m.def.player)
	for i: int in r.get("hidden", []):
		if i < m.magic.places.count():
			m.magic.places.hidden[i] = true
	for id in fugitives(m):
		stamina[id] = FULL


func step(m: MissionRuntime, tick: int) -> void:
	var r := _rules(m)
	now = tick
	if r.is_empty():
		return
	_posts(m, r, tick)
	_patrols(m, r, tick)
	_find(m, r, tick)
	_wolf(m, r)
	_close_paths(m, r, tick)
	_horses(m, r)
	_stable(m, r, tick)
	if on:
		_watch(m, r, tick)


func test(m: MissionRuntime, c: Dictionary) -> bool:
	var ok := false
	match c["type"]:
		"alarm":
			ok = alarms >= int(c.get("at_least", 1))
		"detection":
			ok = meter >= int(c["at_least"])
		"found":
			ok = found.has(int(c["place"]))
		"found_count":
			ok = found.size() >= int(c["at_least"])
		"night":
			ok = night == bool(c.get("is", true))
		"pursuit_due":
			ok = pursuit_at >= 0 and now >= pursuit_at
		"west_of":
			var edge := Fixed.from_cells(int(c["x"]))
			for id in m.alive_of(c["group"]):
				ok = ok or m.entities.pos_x[id - 1] < edge
	return ok


func run(m: MissionRuntime, a: Dictionary, tick: int) -> void:
	match a["do"]:
		"daylight":
			night = bool(a.get("night", false))
		"stealth":
			on = bool(a.get("on", true)) and not _rules(m).is_empty()
		"reveal":
			_reveal(m, int(a["place"]), tick)
		"open_path":
			var ticks := int(a.get("ticks", -1))
			_open_path(m, int(a["place"]), -1 if ticks < 0 else tick + ticks, tick)
		"pursuit":
			var at := tick + int(a["ticks"])
			pursuit_at = at if pursuit_at < 0 else mini(pursuit_at, at)


## The fugitives alive, ascending.
func fugitives(m: MissionRuntime) -> PackedInt32Array:
	var out := PackedInt32Array()
	for g: String in _rules(m).get("groups", []):
		out.append_array(m.alive_of(g))
	out.sort()
	return out


## The command's units that are fugitives switch between riding and leading their horses on foot
## (the DISMOUNT order); the others are returned for the usual dismount.
func pace(_m: MissionRuntime, ids: PackedInt32Array) -> PackedInt32Array:
	var rest := PackedInt32Array()
	for id in ids:
		if not stamina.has(id):
			rest.append(id)
		elif walking.has(id):
			walking.erase(id)
		else:
			walking[id] = true
	return rest


## A fugitive's step this tick: led on foot or on a tired horse it walks.
func speed(id: int, budget: int, m: MissionRuntime) -> int:
	if walking.has(id) or tired.has(id):
		return budget * int(_rules(m)["stamina"]["walk_permille"]) / 1000
	return budget


## Whether the unit goes at a walk now (for the interface).
func at_walk(id: int) -> bool:
	return walking.has(id) or tired.has(id)


## How far the watcher sees now, in fixed units, before cover and light (for its cone).
func sight_of(m: MissionRuntime, id: int) -> int:
	var r := _rules(m)
	var def := m.combat.defs[id - 1]
	var cells: int = def.param(&"sight", m.combat.rules.sight_default) if def != null else 6
	var permille := FULL
	if night:
		permille = int(r.get("night_permille", FULL))
		if _torch(m, r, id):
			permille = int(r.get("torch_permille", permille))
	return Fixed.from_cells(cells) * permille / FULL


## The trail's cells of a place: a two-wide line through its points, without diagonal steps.
func trail(m: MissionRuntime, i: int) -> PackedInt32Array:
	var pts: Array = _rules(m).get("paths", {}).get(str(i), [])
	var nav := m.economy.nav
	var out := PackedInt32Array()
	for k in range(1, pts.size()):
		var a: Array = pts[k - 1]
		var b: Array = pts[k]
		var ax := int(a[0])
		var ay := int(a[1])
		var dx := int(b[0]) - ax
		var dy := int(b[1]) - ay
		var n := maxi(maxi(absi(dx), absi(dy)), 1)
		var wide := Vector2i(1, 0) if absi(dy) > absi(dx) else Vector2i(0, 1)
		var prev := Vector2i(ax, ay)
		for step in n + 1:
			var c := Vector2i(
				ax + Fixed.floor_div(dx * step * 2 + n, n * 2),
				ay + Fixed.floor_div(dy * step * 2 + n, n * 2)
			)
			if c.x != prev.x and c.y != prev.y:
				_add_cells(nav, out, Vector2i(c.x, prev.y), wide)
			_add_cells(nav, out, c, wide)
			prev = c
	return out


static func _add_cells(nav: NavGrid, out: PackedInt32Array, c: Vector2i, wide: Vector2i) -> void:
	for p: Vector2i in [c, c + wide]:
		if nav.in_bounds(p.x, p.y) and not out.has(nav.cell_at(p.x, p.y)):
			out.append(nav.cell_at(p.x, p.y))


func _rules(m: MissionRuntime) -> Dictionary:
	return m.def.rules.get("stealth", {})


# --- the watch ------------------------------------------------------------------------------


func _watch(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	var e := m.entities
	var runners := fugitives(m)
	var watchers := _watchers(m, r)
	var towers := _towers(m, r)
	var guide := _guide(m, r)
	var gain := 0
	for f in runners:
		var s := f - 1
		if e.hp[s] <= 0 or _guided(m, r, guide, f):
			continue
		var fx := e.pos_x[s]
		var fy := e.pos_y[s]
		var cell := m.economy.nav.cell_of(fx, fy)
		var forest := _is_forest(m, cell) or path_old.has(cell)
		var lit := _lit(m, r, fx, fy)
		var moving := e.orders[s] == EntityStore.Order.MOVE
		var trot := moving and not at_walk(f)
		var hidden := forest and not lit and m.combat.flags[s] & CombatSystem.F_STEALTH != 0
		var got := 0
		for w in watchers:
			var ws := w - 1
			var dx := fx - e.pos_x[ws]
			var dy := fy - e.pos_y[ws]
			var d2 := dx * dx + dy * dy
			var heard := 0
			var dogs := Fixed.from_cells(m.combat.defs[ws].param(&"dogs_radius", 0))
			if dogs > 0 and not path_old.has(cell) and d2 <= dogs * dogs:
				heard += int(r["dogs"])
			if trot:
				var road := m.economy.nav.terrain_at(cell) == &"t_road" and not path_old.has(cell)
				var n := Fixed.from_cells(int(r["road_noise_cells" if road else "noise_cells"]))
				if d2 <= n * n:
					heard += int(r["noise"])
			if heard > 0:
				got += heard
				_turn(m, w, dx, dy)
			if hidden:
				continue
			var reach := _reach(m, r, sight_of(m, w), forest, lit, moving)
			if d2 <= reach * reach and _in_cone(m, r, w, dx, dy, d2):
				got += int(r["see"]) * (2 if d2 * 4 <= reach * reach else 1)
		for b in towers:
			var bs := m.economy.buildings
			var dx := fx - bs.center_x(b)
			var dy := fy - bs.center_y(b)
			var base := Fixed.from_cells(bs.defs[b - 1].param(&"sight", 0))
			if night:
				base = base * int(r.get("night_permille", FULL)) / FULL
			var reach := _reach(m, r, base, forest, lit, moving)
			if not hidden and dx * dx + dy * dy <= reach * reach:
				got += int(r["see"])
		if got > 0:
			gain += got
			last_x = fx
			last_y = fy
	if gain > 0:
		if tick >= calm_until:
			meter = mini(meter + gain, FULL)
	else:
		meter = maxi(meter - int(r["decay"]), 0)
	if meter >= FULL:
		_alarm(m, r, tick)


## How far a watcher whose sight is `base` sees the fugitive: further onto someone in a fire's
## light, onto someone moving in the open by day; only close up into a forest.
func _reach(
	m: MissionRuntime, r: Dictionary, base: int, forest: bool, lit: bool, moving: bool
) -> int:
	var reach := base
	if lit:
		reach = reach * int(r.get("lit_permille", FULL)) / FULL
	elif not night and moving and not forest:
		reach = reach * int(r.get("day_open_permille", FULL)) / FULL
	if forest and not lit:
		reach = mini(reach, Fixed.from_cells(int(r.get("cover", m.combat.rules.sight_default))))
	return reach


func _in_cone(m: MissionRuntime, r: Dictionary, w: int, dx: int, dy: int, d2: int) -> bool:
	var e := m.entities
	var d := Fixed.isqrt(d2)
	if d == 0:
		return true
	var dot := e.facing_x[w - 1] * dx + e.facing_y[w - 1] * dy
	return dot * FULL >= int(r.get("cone_permille", 500)) * Fixed.ONE * d


## A standing watcher who hears or smells someone turns that way.
func _turn(m: MissionRuntime, w: int, dx: int, dy: int) -> void:
	var e := m.entities
	var d := Fixed.isqrt(dx * dx + dy * dy)
	if d == 0 or e.orders[w - 1] != EntityStore.Order.IDLE:
		return
	e.facing_x[w - 1] = dx * Fixed.ONE / d
	e.facing_y[w - 1] = dy * Fixed.ONE / d


func _watchers(m: MissionRuntime, r: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	var players: Array = r.get("watchers", [])
	var e := m.entities
	for id in e.alive_ids:
		var s := id - 1
		if not players.has(e.owners[s]) or e.hp[s] <= 0 or m.combat.is_fleeing(id):
			continue
		if m.combat.defs[s] == null or m.combat.defs[s].has_class(&"civilian"):
			continue
		out.append(id)
	return out


func _towers(m: MissionRuntime, r: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	var players: Array = r.get("watchers", [])
	var kinds: Array = r.get("towers", [])
	var bs := m.economy.buildings
	for b in bs.alive_ids:
		var s := b - 1
		if players.has(bs.owners[s]) and bs.done[s] == 1 and kinds.has(String(bs.type_ids[s])):
			out.append(b)
	return out


func _guide(m: MissionRuntime, r: Dictionary) -> PackedInt32Array:
	var g: Dictionary = r.get("guide", {})
	return PackedInt32Array() if g.is_empty() else m.alive_of(g["group"])


func _guided(m: MissionRuntime, r: Dictionary, guide: PackedInt32Array, f: int) -> bool:
	if guide.is_empty():
		return false
	var e := m.entities
	var reach := Fixed.from_cells(int(r["guide"]["radius"]))
	for g in guide:
		var dx := e.pos_x[f - 1] - e.pos_x[g - 1]
		var dy := e.pos_y[f - 1] - e.pos_y[g - 1]
		if dx * dx + dy * dy <= reach * reach:
			return true
	return false


func _torch(m: MissionRuntime, r: Dictionary, id: int) -> bool:
	for g: String in r.get("torches", []):
		if m.groups.get(g, PackedInt32Array()).has(id):
			return true
	return false


func _is_forest(m: MissionRuntime, cell: int) -> bool:
	var t := m.economy.nav.terrain_at(cell)
	return t == NavGrid.FOREST or t == &"t_old_forest"


## Whether the point is in the light of one of the setup's campfires.
func _lit(m: MissionRuntime, r: Dictionary, x: int, y: int) -> bool:
	var reach := Fixed.from_cells(int(r.get("light_radius", 0)))
	for p: Dictionary in m.def.setup.get("props", []):
		if p["kind"] != "prop_campfire":
			continue
		var at: Array = p["at"]
		var dx := x - Fixed.from_cells(at[0]) - Fixed.HALF
		var dy := y - Fixed.from_cells(at[1]) - Fixed.HALF
		if dx * dx + dy * dy <= reach * reach:
			return true
	return false


## The alarm: the meter falls back, the chase comes nearer, the watch near the spot rides there.
func _alarm(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	alarms += 1
	meter = int(r.get("alarm_reset", 0))
	calm_until = tick + int(r.get("alarm_calm_ticks", 0))
	m.flags["alarm"] = tick
	if pursuit_at >= 0:
		pursuit_at = maxi(pursuit_at - int(r.get("alarm_cut_ticks", 0)), tick)
	var reach := Fixed.from_cells(int(r.get("alarm_radius", 0)))
	var e := m.entities
	var by: Dictionary[int, PackedInt32Array] = {}
	for w in _watchers(m, r):
		var dx := e.pos_x[w - 1] - last_x
		var dy := e.pos_y[w - 1] - last_y
		if dx * dx + dy * dy > reach * reach:
			continue
		roused[w] = true
		var p := e.owners[w - 1]
		if not by.has(p):
			by[p] = PackedInt32Array()
		by[p].append(w)
	var owners := by.keys()
	owners.sort()
	for p: int in owners:
		m._apply.call(SimCommand.set_stance(tick, p, by[p], EntityStore.Stance.AGGRESSIVE))
		m._apply.call(SimCommand.attack_move(tick, p, by[p], last_x, last_y))
	var at := [Fixed.to_cells(last_x), Fixed.to_cells(last_y)]
	m.run({"do": "ping", "at": at, "radius": 4}, tick)


# --- posts and patrols ----------------------------------------------------------------------


func _posts(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	var e := m.entities
	for p: Dictionary in r.get("posts", []):
		var looks: Array = p["look"]
		var every := maxi(int(p.get("every_ticks", 1)), 1)
		var look: Array = looks[(tick / every) % looks.size()]
		var lx := int(look[0])
		var ly := int(look[1])
		var d := Fixed.isqrt(lx * lx + ly * ly)
		if d == 0 or tick % every >= MissionRuntime.CHECK_EVERY:
			continue
		for id in m.alive_of(p["group"]):
			if roused.has(id) or e.orders[id - 1] != EntityStore.Order.IDLE:
				continue
			e.facing_x[id - 1] = lx * Fixed.ONE / d
			e.facing_y[id - 1] = ly * Fixed.ONE / d


func _patrols(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	var e := m.entities
	for p: Dictionary in r.get("patrols", []):
		var g: String = p["group"]
		var ids := PackedInt32Array()
		for id in m.alive_of(g):
			if not roused.has(id):
				ids.append(id)
		if ids.is_empty():
			continue
		var idle := true
		for id in ids:
			idle = idle and e.orders[id - 1] == EntityStore.Order.IDLE
		if not idle:
			continue
		var route: Array = p["route"]
		var leg: int = (patrol_leg.get(g, -1) + 1) % route.size()
		patrol_leg[g] = leg
		var to: Array = route[leg]
		var x := Fixed.from_cells(to[0]) + Fixed.HALF
		var y := Fixed.from_cells(to[1]) + Fixed.HALF
		m._apply.call(SimCommand.move(tick, e.owners[ids[0] - 1], ids, x, y))


# --- places, trails, horses -----------------------------------------------------------------


## The finder comes within reveal_radius of a hidden place: it is found.
func _find(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	var places := m.magic.places
	if places.hidden.is_empty():
		return
	var reach := Fixed.from_cells(int(r.get("reveal_radius", 0)))
	var e := m.entities
	for id in m.alive_of(r.get("finder", "")):
		for i in places.count():
			if not places.hidden.has(i):
				continue
			var dx := e.pos_x[id - 1] - places.center_x(i)
			var dy := e.pos_y[id - 1] - places.center_y(i)
			if dx * dx + dy * dy <= reach * reach:
				_reveal(m, i, tick)


func _reveal(m: MissionRuntime, i: int, tick: int) -> void:
	var places := m.magic.places
	if i < 0 or i >= places.count() or found.has(i):
		return
	places.hidden.erase(i)
	found[i] = true
	var state := m.economy.player(m.def.player)
	if state != null:
		var cap := m.magic.rules.power_cap * MagicSystem.POWER_UNIT
		var charge := int(_rules(m).get("charge", 0)) * MagicSystem.POWER_UNIT
		state.power = mini(state.power + charge, cap)
	m.flags["found_%d" % i] = tick
	var at := [Fixed.to_cells(places.center_x(i)), Fixed.to_cells(places.center_y(i))]
	m.run({"do": "ping", "at": at, "radius": 3}, tick)


## A «Волчья тропа» cast at a found place opens that place's trail while the spell lasts.
func _wolf(m: MissionRuntime, r: Dictionary) -> void:
	var magic := m.magic
	for k in magic.fx_ids.size():
		var fx := magic.fx_ids[k]
		if fx <= wolf_seen or not magic.spells[magic.fx_spell[k]].tags.has(&"wolf_path"):
			continue
		wolf_seen = fx
		var cx := Fixed.to_cells(magic.fx_x[k])
		var cy := Fixed.to_cells(magic.fx_y[k])
		var i := magic.places.site_near(cx, cy, magic.rules.capture_radius)
		if i >= 0 and r.get("paths", {}).has(str(i)):
			_open_path(m, i, magic.fx_until[k], now)


func _open_path(m: MissionRuntime, i: int, until: int, tick: int) -> void:
	var nav := m.economy.nav
	var road := nav.terrain_index(&"t_road")
	if path_until.has(i) and (path_until[i] < 0 or (until >= 0 and until <= path_until[i])):
		return
	path_until[i] = until
	for cell in trail(m, i):
		if path_old.has(cell) or nav.passable(NavGrid.MoveClass.FOOT, cell):
			continue
		path_old[cell] = nav.terrain[cell]
		nav.set_terrain(cell, road)
	m.flags["trail_%d" % i] = tick


## A trail whose time is up closes once nobody stands on it.
func _close_paths(m: MissionRuntime, _r: Dictionary, tick: int) -> void:
	if path_until.is_empty():
		return
	var nav := m.economy.nav
	var keys := path_until.keys()
	keys.sort()
	for i: int in keys:
		if path_until[i] < 0 or tick < path_until[i]:
			continue
		var cells := PackedInt32Array()
		for cell in trail(m, i):
			if path_old.has(cell):
				cells.append(cell)
		var busy := false
		for id in m.entities.alive_ids:
			var c := nav.cell_of(m.entities.pos_x[id - 1], m.entities.pos_y[id - 1])
			busy = busy or cells.has(c)
		if busy:
			continue
		for cell in cells:
			nav.set_terrain(cell, path_old[cell])
			path_old.erase(cell)
		path_until.erase(i)


func _horses(m: MissionRuntime, r: Dictionary) -> void:
	var s: Dictionary = r.get("stamina", {})
	if s.is_empty():
		return
	var e := m.entities
	for id in fugitives(m):
		var moving := e.orders[id - 1] == EntityStore.Order.MOVE
		var left: int = stamina.get(id, FULL)
		if moving and not at_walk(id):
			left -= int(s["drain"])
			if left <= 0:
				left = 0
				tired[id] = true
		else:
			left += int(s["rest"] if moving else s["rest_still"])
		left = mini(left, FULL)
		if tired.has(id) and left >= int(s["tired_until"]):
			tired.erase(id)
		stamina[id] = left
	for id: int in stamina.keys():
		if not e.is_alive(id):
			stamina.erase(id)
			walking.erase(id)
			tired.erase(id)


## Fresh horses from the village stable, at the price of the alarm.
func _stable(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	var st: Dictionary = r.get("stable", {})
	if st.is_empty() or stable_used:
		return
	var b: int = m.named.get(st["building"], 0)
	var bs := m.economy.buildings
	if not bs.is_alive(b):
		return
	var e := m.entities
	var reach := Fixed.from_cells(int(st["radius"]))
	var taker := 0
	for id in fugitives(m):
		if bs.distance_sq(b, e.pos_x[id - 1], e.pos_y[id - 1]) <= reach * reach:
			taker = id
			break
	if taker == 0:
		return
	stable_used = true
	var share := Fixed.from_cells(int(st["share"]))
	for id in fugitives(m):
		var dx := e.pos_x[id - 1] - e.pos_x[taker - 1]
		var dy := e.pos_y[id - 1] - e.pos_y[taker - 1]
		if dx * dx + dy * dy <= share * share:
			stamina[id] = FULL
			tired.erase(id)
	m.flags["fresh_horses"] = tick
	last_x = bs.center_x(b)
	last_y = bs.center_y(b)
	_alarm(m, r, tick)


# --- state ----------------------------------------------------------------------------------


func write_to(buf: StreamPeerBuffer) -> void:
	buf.put_8((1 if on else 0) | (2 if night else 0) | (4 if stable_used else 0))
	buf.put_32(meter)
	buf.put_32(alarms)
	buf.put_64(last_x)
	buf.put_64(last_y)
	buf.put_32(wolf_seen)
	buf.put_64(pursuit_at)
	buf.put_64(now)
	buf.put_64(calm_until)
	for d: Dictionary in [stamina, walking, tired, found, path_until, path_old, roused]:
		var keys := d.keys()
		keys.sort()
		buf.put_32(keys.size())
		for k: int in keys:
			buf.put_32(k)
			buf.put_64(int(d[k]))
	var names := patrol_leg.keys()
	names.sort()
	for g: String in names:
		buf.put_utf8_string(g)
		buf.put_32(patrol_leg[g])
