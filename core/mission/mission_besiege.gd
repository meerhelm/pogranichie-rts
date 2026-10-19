class_name MissionBesiege
extends RefCounted
## The rules of «Корона 2. Мальборк, 1410» (def.rules.besiege), run by MissionRuntime.step() on
## this object's state, which the runtime's save and hash carry: a siege from a field camp that
## cannot be won by storm. The castle is mended every dawn and its hunger rises too slowly; the
## castle's guns answer the batteries and bring down the burned walls; the Gdańsk shipmen come
## out at night to spike the bombards; the camp sickens; the Prussian towns send envoys to the
## king; at the end the bombards are taken away to Sztum.
##
## Rules (besiege):
##   player (the besieger), enemy (the garrison);
##   castle {rect, floor_permille}: the enemy's buildings inside rect [x0, y0, x1, y1] are the
##     castle: they never fall below floor_permille of their HP and are whole again at dawn;
##   nights {from, until, day_ticks, night_ticks}: from the trigger `from` night falls (at once)
##     and alternates with day until `until` fires (then it is day for good);
##   starve {from, every_ticks, base, per_town, hp_per_point, cap}: the hunger in the castle
##     (permille, the panel's «Siege»): every every_ticks after `from` it grows by base, per_town
##     for each town sworn to the king and a point per hp_per_point HP the castle lost; never
##     above cap (Plauen: fifteen more days and they would have starved);
##   guns {every_ticks, range, radius, damage, building_damage, cover: [[x, y, r], ...],
##     cover_permille}: the castle fires at the player's battery nearest its walls within range
##     cells, else at the nearest unit of the player: units within radius cells of where the ball
##     lands lose damage HP (guns behind the gabions half), a battery there building_damage;
##     under cover (St John's church: within r cells of x, y) only cover_permille of it;
##   ruins {kinds, radius, crush_radius, crush}: props of those kinds are burned walls; a ball
##     landing within radius cells of one brings it down on everyone within crush_radius (crush
##     HP);
##   sorties {unit, gates: [{at, from}], first, grow, max, delay_ticks, out_ticks, cut_cells,
##     permille, radius, spike_radius}: delay_ticks into every night first (+grow a night, up to
##     max) of `unit` come out of the next open gate (gates open from their trigger) and go for
##     the player's bombard nearest it; a spiker within spike_radius cells of a bombard for its
##     spike_ticks spikes it (it does not fire again until mended). After out_ticks they run back
##     and go in. One further than cut_cells from his gate cannot fall below permille of his HP
##     and there, with a unit of the player's side within radius cells, he is taken captive;
##   forge {radius, ticks}: a spiked bombard within radius cells of the player's finished smithy
##     for that long is mended;
##   plague {every_ticks, base, crowd, water, water_per, heat, heat_until, priest, lazaret, floor,
##     sick, sick_hp, max}: the camp's sickness (permille) grows every every_ticks by base, a
##     point per crowd units of the player, a point per water_per of them drinking below the town
##     (rect water), heat until the trigger heat_until; it falls by priest for each living priest
##     and lazaret for each finished lazaret, but never below floor once that high. From sick his
##     healers do not heal and his units (heroes and guns aside) lose sick_hp; at max the flag
##     plague_max;
##   lazaret {heal, radius}: a finished lazaret heals heal HP a second within radius while the
##     camp is not sick;
##   towns {groups: {group: [food, wood, iron, silver]}, hunters: {group: hunters' group}, to,
##     radius, every_ticks, catch_radius, guard_radius, catch_ticks}: the envoys' groups walk to
##     `to`; there they swear (they leave the map) and from then on bring their stock every
##     every_ticks. An envoy with an enemy within catch_radius and no fighting unit of the player's
##     side within guard_radius for catch_ticks is taken. The hunters follow their envoy;
##   sztum {from, at, radius, unit}: once `from` fires, the player's units of that type that reach
##     `at` are brought to Sztum (they leave the map);
##   setup.allowed {player: [building ids]}: campaign-only buildings the player may build;
##   setup.marks: [[mission, flag], ...]: campaign marks the game answers at the start with a
##     CHOOSE of the question "mark:<mission>:<flag>" (option 0) when the campaign has them.
## Conditions: spiked {at_least}; sworn {at_least}; envoys_lost {at_least}; plague {at_least};
##   hunger {at_least}; brought {at_least}; bombards_left {at_most}; shipmen_taken {at_least};
##   chapels {count}; alone {unit, radius, others} (that unit of the player by his own finished
##   battery with at most `others` units of his within radius cells); shot_after {trigger} (a
##   bombard of the player fired after it); nights {at_least}; ruins_fallen {at_least}; finished
##   {type_id, at_least} (the player's finished buildings of that type).
## Actions: burn_bridge {cells: [x0, y0, x1, y1]} (water, and whoever stands there drowns);
##   fall_back {rect, to} (the player's units in rect go to `to`); envoys_go (the envoys walk).

const CONDITIONS: Array[String] = [
	"spiked",
	"sworn",
	"envoys_lost",
	"plague",
	"hunger",
	"brought",
	"bombards_left",
	"shipmen_taken",
	"chapels",
	"alone",
	"shot_after",
	"nights",
	"ruins_fallen",
	"finished",
]
const ACTIONS: Array[String] = ["burn_bridge", "fall_back", "envoys_go"]
const FULL := 1000
## Where the castle's balls land round the aimed point, in turn (cells).
const SPREAD: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(1, 1),
	Vector2i(-1, -1),
	Vector2i(0, 1),
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, -1),
]
## Drowned on a burning bridge.
const DROWN := 1000
## The hunters are sent after their envoy this often (ticks).
const HUNT_EVERY := 40

var on := false
## The castle's buildings and the HP they had at the last look.
var castle := PackedInt32Array()
var castle_hp := 0
## Day and night: when the light next changes (-1: no cycle), how many nights have fallen.
var next_light := -1
var nights := 0
var hunger := 0
var hp_lost := 0
var next_shot := 0
var shots := 0
## Burned walls fallen (prop index -> tick).
var fallen: Dictionary[int, int] = {}
## The shipmen out now: id -> the gate (index) they came from; the tick they run back.
var out: Dictionary[int, int] = {}
var back_at := -1
var sorties := 0
var gate_turn := 0
## Spiking under way: bombard id -> ticks; spiked bombards (also in CrownTactics.spiked);
## mending at the forge: bombard id -> ticks.
var spiking: Dictionary[int, int] = {}
var spiked: Dictionary[int, bool] = {}
var mending: Dictionary[int, int] = {}
var spiked_total := 0
var taken := 0
var plague := 0
## Envoys: group -> 1 sworn, -1 lost; their catching counters by unit id; walking or not.
var towns: Dictionary[String, int] = {}
var catching: Dictionary[int, int] = {}
var envoys_walk := false
var next_supply := -1
var brought := 0
## The last tick a bombard of the player fired.
var last_shot := -1
## The last impact (cells), for the interface: x, y, tick.
var impact := PackedInt32Array([0, 0, -1])
var now := 0


func set_up(m: MissionRuntime) -> void:
	var r := _rules(m)
	if r.is_empty():
		return
	on = true
	m.stealth.night = false
	var c: Dictionary = r.get("castle", {})
	if not c.is_empty():
		var rect: Array = c["rect"]
		var store := m.economy.buildings
		for b in store.alive_ids:
			var s := b - 1
			if (
				store.owners[s] != int(r["enemy"])
				or not _in(rect, store.cell_x[s], store.cell_y[s])
			):
				continue
			castle.append(b)
			store.hp_floor[b] = maxi(store.max_hp[s] * int(c["floor_permille"]) / FULL, 1)
		castle_hp = _castle_hp(m)
	var allowed: Dictionary = m.def.setup.get("allowed", {})
	for key: String in allowed:
		var state := m.economy.player(key.to_int())
		for item: String in allowed[key]:
			if state != null:
				state.allowed[StringName(item)] = true
	var g: Dictionary = r.get("guns", {})
	next_shot = int(g.get("every_ticks", 0))


func step(m: MissionRuntime, tick: int) -> void:
	now = tick
	if not on:
		return
	var r := _rules(m)
	_light(m, r, tick)
	_castle(m, r, tick)
	_guns(m, r, tick)
	_sorties(m, r, tick)
	_spikes(m, r)
	_plague(m, r, tick)
	_towns(m, r, tick)
	_sztum(m, r)
	for id in m.entities.alive_ids:
		var s := id - 1
		if m.entities.owners[s] == int(r["player"]) and m.combat.crown.deployed.has(id):
			last_shot = maxi(last_shot, m.entities.last_attack[s])


func test(m: MissionRuntime, c: Dictionary) -> bool:
	var ok := false
	match c["type"]:
		"spiked":
			ok = spiked_total >= int(c["at_least"])
		"sworn":
			ok = count_towns(1) >= int(c["at_least"])
		"envoys_lost":
			ok = count_towns(-1) >= int(c["at_least"])
		"plague":
			ok = plague >= int(c["at_least"])
		"hunger":
			ok = hunger >= int(c["at_least"])
		"brought":
			ok = brought >= int(c["at_least"])
		"bombards_left":
			ok = _units_of(m, &"pl_bombard") <= int(c["at_most"])
		"shipmen_taken":
			ok = taken >= int(c["at_least"])
		"chapels":
			ok = chapels(m) >= int(c["count"])
		"alone":
			ok = _alone(m, c)
		"shot_after":
			ok = m.fired.has(c["trigger"]) and last_shot > m.fired[c["trigger"]]
		"nights":
			ok = nights >= int(c["at_least"])
		"ruins_fallen":
			ok = fallen.size() >= int(c["at_least"])
		"finished":
			ok = _finished(m, m.def.player, StringName(c["type_id"])) >= int(c["at_least"])
	return ok


func run(m: MissionRuntime, a: Dictionary, tick: int) -> void:
	match a["do"]:
		"burn_bridge":
			_burn_bridge(m, a["cells"], tick)
		"fall_back":
			var ids := PackedInt32Array()
			var rect: Array = a["rect"]
			var p := m.def.player
			for id in m.entities.alive_ids:
				var s := id - 1
				if m.entities.owners[s] != p:
					continue
				if _in(
					rect, Fixed.to_cells(m.entities.pos_x[s]), Fixed.to_cells(m.entities.pos_y[s])
				):
					ids.append(id)
			if not ids.is_empty():
				var to: Array = a["to"]
				var x := Fixed.from_cells(to[0]) + Fixed.HALF
				var y := Fixed.from_cells(to[1]) + Fixed.HALF
				m._apply.call(SimCommand.move(tick, p, ids, x, y))
		"envoys_go":
			envoys_walk = true
			var t: Dictionary = _rules(m).get("towns", {})
			for g: String in _sorted(t.get("groups", {})):
				towns[g] = 0
				m.run({"do": "move", "group": g, "to": t["to"]}, tick)


# --- the castle -----------------------------------------------------------------------------


func _light(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	var n: Dictionary = r.get("nights", {})
	if n.is_empty():
		return
	if m.fired.has(n["until"]):
		if next_light >= 0:
			next_light = -1
			m.stealth.night = false
		return
	if next_light < 0:
		if m.fired.has(n["from"]):
			_nightfall(m, n, tick)
		return
	if tick < next_light:
		return
	if m.stealth.night:
		m.stealth.night = false
		next_light = tick + int(n["day_ticks"])
		_dawn(m, tick)
	else:
		_nightfall(m, n, tick)


func _nightfall(m: MissionRuntime, n: Dictionary, tick: int) -> void:
	m.stealth.night = true
	nights += 1
	next_light = tick + int(n["night_ticks"])
	var s: Dictionary = _rules(m).get("sorties", {})
	if not s.is_empty():
		back_at = -1
		m.flags["night_%d" % nights] = tick


## At dawn the garrison has mended every wall.
func _dawn(m: MissionRuntime, tick: int) -> void:
	var store := m.economy.buildings
	for b in castle:
		if store.is_alive(b):
			store.hp[b - 1] = store.max_hp[b - 1]
	castle_hp = _castle_hp(m)
	m.flags["dawn"] = tick


func _castle(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	var hp := _castle_hp(m)
	if hp < castle_hp:
		hp_lost += castle_hp - hp
	castle_hp = hp
	var st: Dictionary = r.get("starve", {})
	if st.is_empty() or not m.fired.has(st["from"]) or tick % int(st["every_ticks"]) != 0:
		return
	var per := maxi(int(st["hp_per_point"]), 1)
	var add := int(st["base"]) + count_towns(1) * int(st["per_town"]) + hp_lost / per
	hp_lost %= per
	hunger = mini(hunger + add, int(st["cap"]))


func _castle_hp(m: MissionRuntime) -> int:
	var store := m.economy.buildings
	var sum := 0
	for b in castle:
		if store.is_alive(b):
			sum += store.hp[b - 1]
	return sum


# --- the castle's guns and the burned walls -------------------------------------------------


func _guns(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	var g: Dictionary = r.get("guns", {})
	if g.is_empty() or tick < next_shot:
		return
	next_shot = tick + int(g["every_ticks"])
	var rect: Array = r["castle"]["rect"]
	var reach := Fixed.from_cells(int(g["range"]))
	var p := int(r["player"])
	var best := reach * reach + 1
	var aim := Vector2i(-1, -1)
	var store := m.economy.buildings
	for b in store.alive_ids:
		var s := b - 1
		if store.owners[s] != p or store.type_ids[s] != &"pl_battery":
			continue
		var d := _to_rect_sq(rect, store.center_x(b), store.center_y(b))
		if d < best:
			best = d
			aim = Vector2i(Fixed.to_cells(store.center_x(b)), Fixed.to_cells(store.center_y(b)))
	if aim.x < 0:
		var e := m.entities
		for id in e.alive_ids:
			var s := id - 1
			if e.owners[s] != p or e.hp[s] <= 0:
				continue
			var d := _to_rect_sq(rect, e.pos_x[s], e.pos_y[s])
			if d < best:
				best = d
				aim = Vector2i(Fixed.to_cells(e.pos_x[s]), Fixed.to_cells(e.pos_y[s]))
	if aim.x < 0:
		return
	var at := aim + SPREAD[shots % SPREAD.size()]
	shots += 1
	_land(m, r, g, at, tick)


## A ball lands on cell `at`.
func _land(m: MissionRuntime, r: Dictionary, g: Dictionary, at: Vector2i, tick: int) -> void:
	impact = PackedInt32Array([at.x, at.y, tick])
	var permille := FULL
	for c: Array in g.get("cover", []):
		var dx := at.x - int(c[0])
		var dy := at.y - int(c[1])
		if dx * dx + dy * dy <= int(c[2]) * int(c[2]):
			permille = int(g["cover_permille"])
	var enemy := int(r["enemy"])
	var x := Fixed.from_cells(at.x) + Fixed.HALF
	var y := Fixed.from_cells(at.y) + Fixed.HALF
	var hit := _units_near(m, x, y, int(g["radius"]), enemy)
	for id in hit:
		var dmg := int(g["damage"]) * permille / FULL
		if m.combat.defs[id - 1].has_class(&"siege"):
			# The guns stand behind the gabions: half the harm.
			dmg /= 2
		m.combat.lightning(id, enemy, maxi(dmg, 1))
	var store := m.economy.buildings
	var reach := Fixed.from_cells(1)
	for b in store.alive_ids.duplicate():
		var s := b - 1
		if store.owners[s] == int(r["player"]) and store.distance_sq(b, x, y) <= reach * reach:
			m.economy.hit_building(b, maxi(int(g["building_damage"]) * permille / FULL, 1))
	_ruins(m, r, at, tick)


func _ruins(m: MissionRuntime, r: Dictionary, at: Vector2i, tick: int) -> void:
	var u: Dictionary = r.get("ruins", {})
	if u.is_empty():
		return
	var kinds: Array = u["kinds"]
	var props: Array = m.def.setup.get("props", [])
	var near := int(u["radius"])
	for i in props.size():
		var p: Dictionary = props[i]
		if fallen.has(i) or not kinds.has(p["kind"]):
			continue
		var pa: Array = p["at"]
		var dx := at.x - int(pa[0])
		var dy := at.y - int(pa[1])
		if dx * dx + dy * dy > near * near:
			continue
		fallen[i] = tick
		m.flags["ruin_fell"] = tick
		var x := Fixed.from_cells(pa[0]) + Fixed.HALF
		var y := Fixed.from_cells(pa[1]) + Fixed.HALF
		var crushed := _units_near(m, x, y, int(u["crush_radius"]), -1)
		for id in crushed:
			if m.combat.untouchable.has(id):
				continue
			m.combat.lightning(id, int(r["enemy"]), int(u["crush"]))
		if not crushed.is_empty():
			m.flags["ruin_crushed"] = tick
		m.run({"do": "ping", "at": [pa[0], pa[1]], "radius": 2}, tick)


# --- the night sorties ----------------------------------------------------------------------


func _sorties(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	var s: Dictionary = r.get("sorties", {})
	if s.is_empty() or nights == 0:
		return
	var n: Dictionary = r.get("nights", {})
	var night_start := next_light - int(n.get("night_ticks", 0))
	if (
		m.stealth.night
		and not m.flags.has("sortie_%d" % nights)
		and tick >= night_start + int(s["delay_ticks"])
	):
		_sortie(m, r, s, tick)
	if back_at >= 0 and tick >= back_at:
		back_at = -1
		_run_back(m, s, tick)
	_cut_off(m, r, s, tick)


func _open_gates(m: MissionRuntime, s: Dictionary) -> Array:
	var open := []
	var gates: Array = s["gates"]
	for i in gates.size():
		if m.fired.has(gates[i]["from"]):
			open.append(i)
	return open


func _sortie(m: MissionRuntime, r: Dictionary, s: Dictionary, tick: int) -> void:
	m.flags["sortie_%d" % nights] = tick
	var open := _open_gates(m, s)
	if open.is_empty():
		return
	var gi: int = open[gate_turn % open.size()]
	gate_turn += 1
	var gate: Array = s["gates"][gi]["at"]
	var size := mini(int(s["first"]) + int(s["grow"]) * sorties, int(s["max"]))
	var name := "shipmen_%d" % sorties
	sorties += 1
	m.flags["sortie"] = tick
	var spawn := {"group": name, "player": r["enemy"], "stance": "defensive", "at": gate}
	spawn["units"] = [[s["unit"], size]]
	m._spawn_group(tick, spawn)
	for id in m.alive_of(name):
		out[id] = gi
	var target := _bombard_near(m, int(r["player"]), gate)
	if target.x >= 0:
		# They steal up to the guns to spike them, and fight only those who fall on them.
		m.run({"do": "move", "group": name, "to": [target.x, target.y]}, tick)
		m.run({"do": "ping", "at": [target.x, target.y], "radius": 3}, tick)
	back_at = tick + int(s["out_ticks"])


func _bombard_near(m: MissionRuntime, p: int, at: Array) -> Vector2i:
	var e := m.entities
	var x := Fixed.from_cells(at[0])
	var y := Fixed.from_cells(at[1])
	var best := -1
	var found := Vector2i(-1, -1)
	for id in e.alive_ids:
		var s := id - 1
		if e.owners[s] != p or e.type_ids[s] != &"pl_bombard" or spiked.has(id):
			continue
		var d := (e.pos_x[s] - x) * (e.pos_x[s] - x) + (e.pos_y[s] - y) * (e.pos_y[s] - y)
		if best < 0 or d < best:
			best = d
			found = Vector2i(Fixed.to_cells(e.pos_x[s]), Fixed.to_cells(e.pos_y[s]))
	return found


## Back to the gate: the shipmen that get there go in (leave the map).
func _run_back(m: MissionRuntime, s: Dictionary, tick: int) -> void:
	var gates: Array = s["gates"]
	for i in sorties:
		var name := "shipmen_%d" % i
		var ids := m.alive_of(name)
		if ids.is_empty():
			continue
		var gate: Array = gates[out.get(ids[0], 0)]["at"]
		m.run({"do": "stance", "group": name, "stance": "passive"}, tick)
		m.run({"do": "move", "group": name, "to": gate}, tick)
		m.run({"do": "exit", "group": name, "at": gate, "radius": 2}, tick)


## Far from their gate the shipmen can be cut off and taken.
func _cut_off(m: MissionRuntime, r: Dictionary, s: Dictionary, tick: int) -> void:
	var e := m.entities
	var gates: Array = s["gates"]
	var far := Fixed.from_cells(int(s["cut_cells"]))
	var reach := Fixed.from_cells(int(s["radius"]))
	var ids: Array = out.keys()
	ids.sort()
	for id: int in ids:
		if not e.is_alive(id):
			out.erase(id)
			m.combat.hp_floor.erase(id)
			continue
		var sl := id - 1
		var gate: Array = gates[out[id]]["at"]
		var dx := e.pos_x[sl] - Fixed.from_cells(gate[0])
		var dy := e.pos_y[sl] - Fixed.from_cells(gate[1])
		if dx * dx + dy * dy <= far * far:
			m.combat.hp_floor.erase(id)
			continue
		var floor_hp := maxi(e.max_hp[sl] * int(s["permille"]) / FULL, 1)
		m.combat.hp_floor[id] = floor_hp
		if e.hp[sl] > floor_hp or not _side_near(m, int(r["player"]), sl, reach):
			continue
		taken += 1
		m.captives += 1
		m.flags["shipman_taken"] = tick
		out.erase(id)
		m.combat.hp_floor.erase(id)
		m.run(
			{
				"do": "ping",
				"at": [Fixed.to_cells(e.pos_x[sl]), Fixed.to_cells(e.pos_y[sl])],
				"radius": 2
			},
			tick
		)
		m._remove.call(id)


func _spikes(m: MissionRuntime, r: Dictionary) -> void:
	var e := m.entities
	var p := int(r["player"])
	var s: Dictionary = r.get("sorties", {})
	var near_cells := int(s.get("spike_radius", 2))
	var reach := Fixed.from_cells(near_cells)
	var ids: Array = spiking.keys()
	for id: int in ids:
		if not e.is_alive(id):
			spiking.erase(id)
	for id in e.alive_ids:
		var sl := id - 1
		if e.owners[sl] != p or e.type_ids[sl] != &"pl_bombard" or spiked.has(id):
			continue
		var need := 0
		for other in m.combat.buckets.near(e.pos_x[sl], e.pos_y[sl], reach):
			var o := other - 1
			if e.hp[o] <= 0 or not m.combat.defs[o].tags.has(&"spiker"):
				continue
			if not m.are_hostile(p, e.owners[o]):
				continue
			var dx := e.pos_x[o] - e.pos_x[sl]
			var dy := e.pos_y[o] - e.pos_y[sl]
			if dx * dx + dy * dy <= reach * reach:
				need = m.combat.defs[o].param(&"spike_ticks")
				break
		if need == 0:
			spiking.erase(id)
			continue
		spiking[id] = spiking.get(id, 0) + MissionRuntime.CHECK_EVERY
		if spiking[id] >= need:
			spiking.erase(id)
			spiked[id] = true
			m.combat.crown.spiked[id] = true
			m.combat.crown.deployed.erase(id)
			spiked_total += 1
			m.flags["spiked"] = now
			var at := [Fixed.to_cells(e.pos_x[sl]), Fixed.to_cells(e.pos_y[sl])]
			m.run({"do": "ping", "at": at, "radius": 2}, now)
	_forge(m, r)


## A smith drills out a spiked bombard standing by the forge.
func _forge(m: MissionRuntime, r: Dictionary) -> void:
	var f: Dictionary = r.get("forge", {})
	if f.is_empty():
		return
	var e := m.entities
	var store := m.economy.buildings
	var p := int(r["player"])
	var reach := Fixed.from_cells(int(f["radius"]))
	var ids: Array = spiked.keys()
	ids.sort()
	for id: int in ids:
		if not e.is_alive(id):
			spiked.erase(id)
			mending.erase(id)
			m.combat.crown.spiked.erase(id)
			continue
		var sl := id - 1
		var by := false
		for b in store.alive_ids:
			var s := b - 1
			if store.owners[s] != p or store.done[s] != 1 or store.defs[s].base_id != &"smithy":
				continue
			if store.distance_sq(b, e.pos_x[sl], e.pos_y[sl]) <= reach * reach:
				by = true
				break
		if not by:
			mending.erase(id)
			continue
		mending[id] = mending.get(id, 0) + MissionRuntime.CHECK_EVERY
		if mending[id] >= int(f["ticks"]):
			mending.erase(id)
			spiked.erase(id)
			m.combat.crown.spiked.erase(id)
			m.flags["mended"] = now


# --- the plague -----------------------------------------------------------------------------


func _plague(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	var pl: Dictionary = r.get("plague", {})
	if pl.is_empty():
		return
	var p := int(r["player"])
	var e := m.entities
	var lz: Dictionary = r.get("lazaret", {})
	var sick := plague >= int(pl["sick"])
	if not lz.is_empty() and not sick and tick % 20 == 0:
		_lazaret_heal(m, p, lz)
	if tick % int(pl["every_ticks"]) != 0 or tick == 0:
		return
	var units := 0
	var below := 0
	var priests := 0
	var water: Array = pl["water"]
	for id in e.alive_ids:
		var s := id - 1
		if e.owners[s] != p:
			continue
		units += 1
		if e.type_ids[s] == &"pl_priest":
			priests += 1
		if _in(water, Fixed.to_cells(e.pos_x[s]), Fixed.to_cells(e.pos_y[s])):
			below += 1
	var add := int(pl["base"]) + units / maxi(int(pl["crowd"]), 1)
	add += below / maxi(int(pl["water_per"]), 1)
	if not m.fired.has(pl["heat_until"]):
		add += int(pl["heat"])
	add -= priests * int(pl["priest"]) + _finished(m, p, &"pl_lazaret") * int(pl["lazaret"])
	var next := plague + add
	if add < 0:
		next = maxi(next, mini(plague, int(pl["floor"])))
	plague = clampi(next, 0, int(pl["max"]))
	if plague >= int(pl["max"]) and not m.flags.has("plague_max"):
		m.flags["plague_max"] = tick
	if plague >= int(pl["sick"]):
		m.magic.no_heal[p] = true
		for id in e.alive_ids:
			var s := id - 1
			if e.owners[s] != p or e.hp[s] <= 1:
				continue
			if m.combat.flags[s] & CombatSystem.F_HERO or m.combat.defs[s].has_class(&"siege"):
				continue
			e.hp[s] = maxi(e.hp[s] - int(pl["sick_hp"]), 1)
	else:
		m.magic.no_heal.erase(p)


func _lazaret_heal(m: MissionRuntime, p: int, lz: Dictionary) -> void:
	var store := m.economy.buildings
	var e := m.entities
	var reach := Fixed.from_cells(int(lz["radius"]))
	for b in store.alive_ids:
		var s := b - 1
		if store.owners[s] != p or store.done[s] != 1 or store.type_ids[s] != &"pl_lazaret":
			continue
		var near := m.combat.buckets.near(store.center_x(b), store.center_y(b), reach + Fixed.ONE)
		near.sort()
		for id in near:
			var o := id - 1
			if (
				e.owners[o] == p
				and e.hp[o] > 0
				and store.distance_sq(b, e.pos_x[o], e.pos_y[o]) <= reach * reach
			):
				e.hp[o] = mini(e.max_hp[o], e.hp[o] + int(lz["heal"]))


# --- the towns' envoys ----------------------------------------------------------------------


func _towns(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	var t: Dictionary = r.get("towns", {})
	if t.is_empty() or not envoys_walk:
		return
	var e := m.entities
	var to: Array = t["to"]
	var tx := Fixed.from_cells(to[0]) + Fixed.HALF
	var ty := Fixed.from_cells(to[1]) + Fixed.HALF
	var home := Fixed.from_cells(int(t["radius"]))
	var groups: Dictionary = t["groups"]
	var hunters: Dictionary = t.get("hunters", {})
	for g: String in _sorted(groups):
		if towns.get(g, 0) != 0:
			continue
		var ids := m.alive_of(g)
		if ids.is_empty():
			towns[g] = -1
			m.flags["envoy_lost"] = tick
			continue
		for id in ids:
			var s := id - 1
			var dx := e.pos_x[s] - tx
			var dy := e.pos_y[s] - ty
			if dx * dx + dy * dy <= home * home:
				towns[g] = 1
				m.flags["sworn_" + g] = tick
				for other in ids:
					catching.erase(other)
					m._remove.call(other)
				if next_supply < 0:
					next_supply = tick + int(t["every_ticks"])
				break
			if _caught(m, r, t, id):
				catching.erase(id)
				m._remove.call(id)
		if towns[g] == 0 and hunters.has(g) and tick % HUNT_EVERY == 0:
			var left := m.alive_of(g)
			if not left.is_empty():
				var at := [
					Fixed.to_cells(e.pos_x[left[0] - 1]), Fixed.to_cells(e.pos_y[left[0] - 1])
				]
				m.run({"do": "attack_move", "group": hunters[g], "to": at}, tick)
	if next_supply >= 0 and tick >= next_supply:
		next_supply = tick + int(t["every_ticks"])
		var state := m.economy.player(int(r["player"]))
		for g: String in _sorted(groups):
			if towns.get(g, 0) == 1 and state != null:
				var give: Array = groups[g]
				for k in give.size():
					state.stock[k] += int(give[k])


## Whether the envoy has been caught (an enemy at him and no guard of ours by him long enough).
func _caught(m: MissionRuntime, r: Dictionary, t: Dictionary, id: int) -> bool:
	var e := m.entities
	var s := id - 1
	var foe := false
	var catch_r := Fixed.from_cells(int(t["catch_radius"]))
	var guard_r := Fixed.from_cells(int(t["guard_radius"]))
	var guarded := false
	for other in m.combat.buckets.near(e.pos_x[s], e.pos_y[s], guard_r):
		var o := other - 1
		if e.hp[o] <= 0 or other == id:
			continue
		var dx := e.pos_x[o] - e.pos_x[s]
		var dy := e.pos_y[o] - e.pos_y[s]
		var d := dx * dx + dy * dy
		if m.are_hostile(int(r["player"]), e.owners[o]) and d <= catch_r * catch_r:
			foe = true
		elif m.are_friendly(int(r["player"]), e.owners[o]) and d <= guard_r * guard_r:
			if m.combat.defs[o].damage > 0:
				guarded = true
	if not foe or guarded:
		catching.erase(id)
		return false
	catching[id] = catching.get(id, 0) + MissionRuntime.CHECK_EVERY
	return catching[id] >= int(t["catch_ticks"])


func count_towns(state: int) -> int:
	var n := 0
	for g: String in towns:
		if towns[g] == state:
			n += 1
	return n


# --- the road to Sztum ----------------------------------------------------------------------


func _sztum(m: MissionRuntime, r: Dictionary) -> void:
	var z: Dictionary = r.get("sztum", {})
	if z.is_empty() or not m.fired.has(z["from"]):
		return
	var e := m.entities
	var at: Array = z["at"]
	var x := Fixed.from_cells(at[0]) + Fixed.HALF
	var y := Fixed.from_cells(at[1]) + Fixed.HALF
	var reach := Fixed.from_cells(int(z["radius"]))
	var kind := StringName(z["unit"])
	var p := int(r["player"])
	for id in e.alive_ids.duplicate():
		var s := id - 1
		if e.owners[s] != p or e.type_ids[s] != kind:
			continue
		var dx := e.pos_x[s] - x
		var dy := e.pos_y[s] - y
		if dx * dx + dy * dy <= reach * reach:
			brought += 1
			m.flags["brought"] = now
			spiked.erase(id)
			m.combat.crown.spiked.erase(id)
			m._remove.call(id)


# --- helpers --------------------------------------------------------------------------------


func _burn_bridge(m: MissionRuntime, rect: Array, tick: int) -> void:
	var nav := m.economy.nav
	var water := nav.terrain_index(&"t_water")
	var e := m.entities
	var on_it := PackedInt32Array()
	for id in e.alive_ids:
		var s := id - 1
		if e.hp[s] > 0 and _in(rect, Fixed.to_cells(e.pos_x[s]), Fixed.to_cells(e.pos_y[s])):
			on_it.append(id)
	for cy in range(int(rect[1]), int(rect[3]) + 1):
		for cx in range(int(rect[0]), int(rect[2]) + 1):
			if water >= 0:
				nav.set_terrain(nav.cell_at(cx, cy), water)
	for id in on_it:
		m.combat.untouchable.erase(id)
		m.combat.lightning(id, 0, DROWN)
	m.flags["bridge_burned"] = tick


## How many finished buildings of that type the player has.
func _finished(m: MissionRuntime, p: int, type: StringName) -> int:
	var store := m.economy.buildings
	var n := 0
	for b in store.alive_ids:
		var s := b - 1
		if store.owners[s] == p and store.done[s] == 1 and store.type_ids[s] == type:
			n += 1
	return n


## The player's chapels (wayside crosses made chapels).
func chapels(m: MissionRuntime) -> int:
	var store := m.economy.buildings
	var n := 0
	for b in store.alive_ids:
		var s := b - 1
		if store.owners[s] == m.def.player and store.upgraded[s] == 1:
			n += 1
	return n


func _alone(m: MissionRuntime, c: Dictionary) -> bool:
	var e := m.entities
	var p := m.def.player
	var kind := StringName(c["unit"])
	var store := m.economy.buildings
	var near_b := Fixed.from_cells(3)
	var reach := Fixed.from_cells(int(c["radius"]))
	for id in e.alive_ids:
		var s := id - 1
		if e.owners[s] != p or e.type_ids[s] != kind:
			continue
		var by := false
		for b in store.alive_ids:
			var bs := b - 1
			if store.owners[bs] != p or store.done[bs] != 1 or store.type_ids[bs] != &"pl_battery":
				continue
			if store.distance_sq(b, e.pos_x[s], e.pos_y[s]) <= near_b * near_b:
				by = true
				break
		if not by:
			return false
		var others := 0
		for other in m.combat.buckets.near(e.pos_x[s], e.pos_y[s], reach):
			var o := other - 1
			if other == id or e.owners[o] != p or e.hp[o] <= 0:
				continue
			if m.combat.defs[o].has_class(&"siege"):
				continue
			var dx := e.pos_x[o] - e.pos_x[s]
			var dy := e.pos_y[o] - e.pos_y[s]
			if dx * dx + dy * dy <= reach * reach:
				others += 1
		return others <= int(c["others"])
	return false


func _units_of(m: MissionRuntime, kind: StringName) -> int:
	var n := 0
	for id in m.entities.alive_ids:
		if m.entities.owners[id - 1] == m.def.player and m.entities.type_ids[id - 1] == kind:
			n += 1
	return n


## Units within radius cells of the point (fixed), ascending; `not_of`: leave that player's out
## and his friends' (-1: everyone).
func _units_near(m: MissionRuntime, x: int, y: int, radius: int, not_of: int) -> PackedInt32Array:
	var e := m.entities
	var reach := Fixed.from_cells(radius) + Fixed.HALF
	var out_ids := PackedInt32Array()
	for id in m.combat.buckets.near(x, y, reach):
		var s := id - 1
		if e.hp[s] <= 0:
			continue
		if not_of >= 0 and not m.are_hostile(not_of, e.owners[s]):
			continue
		var dx := e.pos_x[s] - x
		var dy := e.pos_y[s] - y
		if dx * dx + dy * dy <= reach * reach:
			out_ids.append(id)
	out_ids.sort()
	return out_ids


func _side_near(m: MissionRuntime, p: int, s: int, reach: int) -> bool:
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


static func _to_rect_sq(rect: Array, px: int, py: int) -> int:
	var x0 := Fixed.from_cells(rect[0])
	var y0 := Fixed.from_cells(rect[1])
	var x1 := Fixed.from_cells(int(rect[2]) + 1)
	var y1 := Fixed.from_cells(int(rect[3]) + 1)
	var dx := maxi(maxi(x0 - px, 0), px - x1)
	var dy := maxi(maxi(y0 - py, 0), py - y1)
	return dx * dx + dy * dy


static func _in(rect: Array, cx: int, cy: int) -> bool:
	return cx >= int(rect[0]) and cx <= int(rect[2]) and cy >= int(rect[1]) and cy <= int(rect[3])


static func _sorted(d: Dictionary) -> Array:
	var keys := d.keys()
	keys.sort()
	return keys


## The siege's panel numbers: the hunger in the castle, the plague, how many towns swore.
func hunger_permille() -> int:
	return hunger


func _rules(m: MissionRuntime) -> Dictionary:
	return m.def.rules.get("besiege", {})


func write_to(buf: StreamPeerBuffer) -> void:
	# Nothing outside this mission, so older replays keep their hashes.
	if not on:
		return
	for v: int in [castle_hp, next_light, nights, hunger, hp_lost, next_shot, shots, back_at]:
		buf.put_64(v)
	for v: int in [
		sorties, gate_turn, spiked_total, taken, plague, next_supply, brought, last_shot
	]:
		buf.put_64(v)
	buf.put_8(1 if envoys_walk else 0)
	for d: Dictionary in [fallen, out, spiking, spiked, mending, catching]:
		var keys := d.keys()
		keys.sort()
		buf.put_32(keys.size())
		for k: int in keys:
			buf.put_32(k)
			buf.put_64(int(d[k]))
	for g: String in _sorted(towns):
		buf.put_utf8_string(g)
		buf.put_8(towns[g] + 1)
