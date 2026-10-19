class_name MissionSilver
extends RefCounted
## The rules of «Корона 5. Серебро для Мальборка, 1457» (def.rules.silver), run by
## MissionRuntime.step() on this object's state, which the runtime's save and hash carry: a
## mission of money, not of battle. The Order's mercenaries in Malbork will sell the castle for
## silver; pani Barbara borrows it in Gdańsk, taxes the villages of the Żuławy and carries it to
## Malbork by wagon along the dikes or by boat down the Nogat, while the mercenaries' patience
## runs out, Gdańsk grumbles at the loans and the Order's riders come over the river for the
## wagons. Autumn mud, winter ice and the spring flood change the roads.
##
## Rules (silver {player, need, florins}: `need` silver delivered buys the castles; the panel
## shows silver × florins as Hungarian florins):
##   carry {units: {type: capacity}, load: [bases], load_radius}: a carrier of the player
##     standing still within load_radius of a finished building of the player of one of those
##     kinds takes as much silver from the stock as it holds; if it dies loaded the silver is
##     lost (lost condition);
##   deliver {points: [[x, y], ...], radius}: a loaded carrier there hands its silver over
##     (delivered) and the patience grows by as much × patience.per_silver_permille / 1000;
##   patience {start, max, every_ticks, from, per_silver_permille}: the mercenaries' patience
##     falls by one every every_ticks once the trigger `from` has fired;
##   discontent {start, max, every_ticks, crowd_at, calm_below, closed_at}: Gdańsk's discontent
##     falls by one every every_ticks; it grows with loans and taxes. From crowd_at a crowd stands
##     before the town hall and a question (asks.crowd) is put: a concession (discontent −
##     concession, no loans for concession_ticks), money (pay `money` silver, discontent −
##     money_calm) or the guard (discontent − guard_calm); the crowd comes again only after the
##     discontent fell below calm_below. At closed_at the town lends nothing;
##   crowd {player, at, units, concession, concession_ticks, money, money_calm, guard_calm};
##   loans {hero, hall, radius, from, sums: [[silver, discontent], ...], interest,
##     hero_permille, wait_ticks}: the hero within radius of the town hall is asked (asks.loan)
##     how much to borrow; a loan raises the discontent by its own + interest × loans taken
##     before, × hero_permille / 1000 (Barbara: «займы в Гданьске дешевле на 20%»); asked again
##     wait_ticks after an answer;
##   villages {at, radius, silver, food, stay_ticks, by, again_ticks, tax, tax_twice,
##     rumour_permille}: a unit of a `by` type standing stay_ticks within radius of a village
##     taxes it: silver and food, discontent + tax (tax_twice if the village paid already this
##     season); a village paying under a rumour gives rumour_permille of the silver; a village
##     the Order's riders plundered this season gives nothing;
##   rumours {from, every_ticks, priest, radius, clear_ticks, shrine_radius}: every every_ticks
##     a rumour of «devil's silver» starts in the next village with none, unless a finished
##     shrine of the player stands within shrine_radius of it; the priest standing clear_ticks
##     within radius of it ends it;
##   raids {player, from, until, spawn, units, normal_units, every: [autumn, winter, spring],
##     chase_cells, plunder_radius, per_raid, trophy, exit}: the Order's riders come over the
##     river from a spawn point in turn; they ride at a loaded wagon of the player within
##     chase_cells, else at the next village they have not plundered; per_raid villages and they
##     ride home to `exit`. Every rider killed gives the player `trophy` silver;
##   seasons {freeze, flood, mud_permille, mud_units}: winter turns the water of the freeze
##     rects to ice (and spring back), spring floods the grass and fields of the flood rects; in
##     autumn the mud_units go at mud_permille of their speed;
##   wages {every_ticks, units: {type: silver}}: the player's hired units are paid from the
##     stock; whoever cannot be paid leaves (deserted condition);
##   piles {rect, tower_radius, damage}: a boat of the player inside the rect strikes the piles
##     of the old bridge and loses `damage` HP a check, unless a finished tower of the player
##     stands within tower_radius of the rect's centre and shows the way;
##   brothers {group, exit}: if any of them is hurt or killed (not gone out by `exit`), the flag
##     brothers_hurt is set.
## Conditions: delivered {at_least}; patience {at_most | at_least}; discontent {at_least |
##   at_most}; season {at_least}; taxed {at_least}; rumours {at_least}; lost {at_least};
##   deserted; loans_taken {at_least}; units_near {at, radius, count} (the player's fighting
##   units there: not wagons, boats, workers or civilians).
## Actions: season {to}; patience {add}; cargo {group, silver} (each carrier of the group gets
##   that much silver, from outside the stock); unload {group} (their silver is handed over off
##   the books).

enum Season { AUTUMN, WINTER, SPRING }

const CONDITIONS: Array[String] = [
	"delivered",
	"patience",
	"discontent",
	"season",
	"taxed",
	"rumours",
	"lost",
	"deserted",
	"loans_taken",
	"units_near"
]
const ACTIONS: Array[String] = ["season", "patience", "cargo", "unload"]
## How often (ticks) the riders are sent again.
const RAID_EVERY := 40

var on := false
var player := 1
## Silver each carrier holds (id -> silver), what was delivered and what was lost with carriers.
var cargo: Dictionary[int, int] = {}
var delivered := 0
var lost := 0
var patience := 0
var discontent := 0
var season := Season.AUTUMN
## Loans: taken, the question open now ("": none), when the hero may be asked again, until
## when the town lends nothing after a concession.
var loans := 0
var loan_question := ""
var loan_wait := 0
var closed_until := -1
## The crowd before the town hall: the question open, its units, how many times it came.
var crowd_question := ""
var crowd := PackedInt32Array()
var crowds := 0
var crowd_armed := true
## Villages: the tick each one was last taxed (-1: never), the season of the last tax (-1),
## the season it was plundered in (-1), whether a rumour runs there, the ticks a taxer and the
## priest stood there.
var taxed_tick := PackedInt32Array()
var taxed_season := PackedInt32Array()
var plundered := PackedInt32Array()
var rumour := PackedByteArray()
var tax_stay := PackedInt32Array()
var priest_stay := PackedInt32Array()
var taxes := 0
var twice := 0
var rumours := 0
var next_rumour := -1
## Raids: the groups sent, their village targets (-1: going home) and villages done, the next
## raid's tick, riders counted (dead for a trophy, or gone home).
var raids: Array[String] = []
var raid_target := PackedInt32Array()
var raid_done := PackedInt32Array()
var next_raid := -1
var counted: Dictionary[int, bool] = {}
var trophies := 0
## Seasons: the frozen cells and the flooded cells with their old terrain.
var frozen := PackedInt32Array()
var flooded := PackedInt32Array()
var flood_old := PackedByteArray()
## Wages: the next payday and how many left unpaid.
var next_pay := -1
var deserted := 0
## The tick being checked (for conditions; not state of its own).
var now := 0


func set_up(m: MissionRuntime) -> void:
	var r := _rules(m)
	if r.is_empty():
		return
	on = true
	player = int(r["player"])
	patience = int(r.get("patience", {}).get("start", 500))
	discontent = int(r.get("discontent", {}).get("start", 0))
	var n := (r.get("villages", {}).get("at", []) as Array).size()
	taxed_tick.resize(n)
	taxed_season.resize(n)
	plundered.resize(n)
	tax_stay.resize(n)
	priest_stay.resize(n)
	taxed_tick.fill(-1)
	taxed_season.fill(-1)
	plundered.fill(-1)
	tax_stay.fill(0)
	priest_stay.fill(0)
	rumour.resize(n)
	rumour.fill(0)
	var w: Dictionary = r.get("wages", {})
	if not w.is_empty() and str(w.get("from", "")) == "":
		next_pay = int(w["every_ticks"])
	# Campaign-only buildings the player may build here (the pier), as in MissionBesiege.
	var allowed: Dictionary = m.def.setup.get("allowed", {})
	for key: String in allowed:
		var state := m.economy.player(key.to_int())
		for item: String in allowed[key]:
			if state != null:
				state.allowed[StringName(item)] = true


func step(m: MissionRuntime, tick: int) -> void:
	if not on:
		return
	now = tick
	var r := _rules(m)
	_carriers(m, r)
	_patience(m, r.get("patience", {}), tick)
	_discontent(m, r, tick)
	_loans(m, r, tick)
	_villages(m, r.get("villages", {}), tick)
	_rumours(m, r, tick)
	_raids(m, r.get("raids", {}), tick)
	_mud(m, r.get("seasons", {}))
	_wages(m, r.get("wages", {}), tick)
	_piles(m, r.get("piles", {}))
	_brothers(m, r.get("brothers", {}), tick)


func test(m: MissionRuntime, c: Dictionary) -> bool:
	var ok := false
	match c["type"]:
		"delivered":
			ok = delivered >= int(c["at_least"])
		"patience":
			ok = not c.has("at_least") or patience >= int(c["at_least"])
			ok = ok and (not c.has("at_most") or patience <= int(c["at_most"]))
		"discontent":
			ok = not c.has("at_least") or discontent >= int(c["at_least"])
			ok = ok and (not c.has("at_most") or discontent <= int(c["at_most"]))
		"season":
			ok = season >= int(c["at_least"])
		"taxed":
			ok = taxes >= int(c["at_least"])
		"rumours":
			ok = rumours >= int(c["at_least"])
		"lost":
			ok = lost >= int(c["at_least"])
		"deserted":
			ok = deserted > 0
		"loans_taken":
			ok = loans >= int(c["at_least"])
		"units_near":
			ok = units_near(m, c["at"], int(c["radius"])) >= int(c["count"])
	return ok


func run(m: MissionRuntime, a: Dictionary, tick: int) -> void:
	if not on:
		return
	match a["do"]:
		"season":
			_season(m, int(a["to"]), tick)
		"patience":
			var p: Dictionary = _rules(m).get("patience", {})
			patience = clampi(patience + int(a["add"]), 0, int(p.get("max", 1000)))
		"cargo":
			for id in m.alive_of(a["group"]):
				cargo[id] = int(a["silver"])
		"unload":
			for id in m.alive_of(a["group"]):
				cargo.erase(id)


# --- for the panel, the layer and the bot ---------------------------------------------------


## Silver the player's carriers hold now.
func on_the_road(m: MissionRuntime) -> int:
	var n := 0
	for id: int in cargo:
		if m.entities.is_alive(id):
			n += cargo[id]
	return n


func need(m: MissionRuntime) -> int:
	return int(_rules(m).get("need", 0))


func florins(m: MissionRuntime, silver: int) -> int:
	return silver * int(_rules(m).get("florins", 1))


## Silver the player pays in wages a payday.
func wages_due(m: MissionRuntime) -> int:
	var w: Dictionary = _rules(m).get("wages", {})
	if w.is_empty():
		return 0
	var pay: Dictionary = w["units"]
	var n := 0
	for id in m.entities.alive_ids:
		if m.entities.owners[id - 1] == player:
			n += int(pay.get(String(m.entities.type_ids[id - 1]), 0))
	return n


## The player's units within radius of `at`, carriers and workers not counted.
func units_near(m: MissionRuntime, at: Array, radius: int) -> int:
	var e := m.entities
	var reach := Fixed.from_cells(radius)
	var n := 0
	for id in e.alive_ids:
		var s := id - 1
		var def := m.combat.defs[s]
		if e.owners[s] != player or def == null or def.has_class(&"siege"):
			continue
		if def.has_class(&"boat") or def.has_class(&"peasant") or def.has_class(&"civilian"):
			continue
		if _dist(e, s, at) <= reach:
			n += 1
	return n


func loans_open(m: MissionRuntime) -> bool:
	var d: Dictionary = _rules(m).get("discontent", {})
	return (
		crowd.is_empty() and now >= closed_until and discontent < int(d.get("closed_at", 1 << 30))
	)


func village_count() -> int:
	return rumour.size()


func is_plundered(i: int) -> bool:
	return plundered[i] == season


## Whether the village can pay now (not plundered, not taxed this season).
func can_tax(i: int) -> bool:
	return plundered[i] != season and taxed_season[i] != season


# --- carrying the silver --------------------------------------------------------------------


func _carriers(m: MissionRuntime, r: Dictionary) -> void:
	var c: Dictionary = r.get("carry", {})
	var d: Dictionary = r.get("deliver", {})
	if c.is_empty():
		return
	var e := m.entities
	# Carriers that died loaded lose their silver.
	var ids := cargo.keys()
	ids.sort()
	for id: int in ids:
		if not e.is_alive(id) or e.hp[id - 1] <= 0:
			lost += cargo[id]
			cargo.erase(id)
			m.flags["silver_lost"] = now
	var units: Dictionary = c["units"]
	var state := m.economy.player(player)
	var load_r := Fixed.from_cells(int(c.get("load_radius", 4)))
	var points: Array = d.get("points", [])
	var deliver_r := Fixed.from_cells(int(d.get("radius", 4)))
	var p: Dictionary = r.get("patience", {})
	for id in e.alive_ids:
		var s := id - 1
		if e.owners[s] != player or not units.has(String(e.type_ids[s])):
			continue
		if cargo.has(id):
			for at: Array in points:
				if _dist(e, s, at) <= deliver_r:
					var silver: int = cargo[id]
					cargo.erase(id)
					delivered += silver
					var gain := silver * int(p.get("per_silver_permille", 1000)) / 1000
					patience = mini(patience + gain, int(p.get("max", 1000)))
					m.flags["delivered"] = now
					break
		elif state != null and e.orders[s] == EntityStore.Order.IDLE:
			var silver := mini(int(units[String(e.type_ids[s])]), state.stock[EconomySystem.SILVER])
			if silver > 0 and _near_building(m, s, c["load"], load_r):
				state.stock[EconomySystem.SILVER] -= silver
				cargo[id] = silver


func _near_building(m: MissionRuntime, s: int, bases: Array, reach: int) -> bool:
	var store := m.economy.buildings
	var e := m.entities
	for b in store.alive_ids:
		var bs := b - 1
		if store.owners[bs] != player or store.done[bs] != 1:
			continue
		if not bases.has(String(store.defs[bs].base_id)):
			continue
		# From the building's edge, not its centre: it is several cells wide.
		var half := Fixed.from_cells(maxi(store.defs[bs].param(&"size_w", 2), 2)) / 2
		var dist := Fixed.distance(store.center_x(b), store.center_y(b), e.pos_x[s], e.pos_y[s])
		if dist <= reach + half:
			return true
	return false


# --- patience and discontent ----------------------------------------------------------------


func _patience(m: MissionRuntime, p: Dictionary, tick: int) -> void:
	if p.is_empty() or not m.fired.has(str(p.get("from", ""))):
		return
	if tick % int(p["every_ticks"]) == 0:
		patience = maxi(patience - 1, 0)


func _discontent(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	var d: Dictionary = r.get("discontent", {})
	if d.is_empty():
		return
	if tick % int(d["every_ticks"]) == 0 and crowd.is_empty():
		discontent = maxi(discontent - 1, 0)
	var c: Dictionary = r.get("crowd", {})
	if c.is_empty():
		return
	if discontent < int(d["calm_below"]):
		crowd_armed = true
	if crowd_armed and crowd.is_empty() and discontent >= int(d["crowd_at"]):
		_raise_crowd(m, c, tick)
	if not crowd_question.is_empty():
		for option in 3:
			if m.flags.has(MissionRuntime.choice_flag(crowd_question, option)):
				_calm(m, c, option, tick)
				break


func _raise_crowd(m: MissionRuntime, c: Dictionary, tick: int) -> void:
	crowds += 1
	crowd_armed = false
	m.flags["crowd"] = tick
	var name := "crowd_%d" % crowds
	m.run(
		{
			"do": "spawn",
			"group": name,
			"player": c["player"],
			"at": c["at"],
			"units": c["units"],
			"stance": "passive"
		},
		tick
	)
	crowd = m.alive_of(name)
	crowd_question = name
	_ask(m, "crowd", name, tick)


func _calm(m: MissionRuntime, c: Dictionary, option: int, tick: int) -> void:
	var state := m.economy.player(player)
	match option:
		0:
			discontent = maxi(discontent - int(c["concession"]), 0)
			closed_until = tick + int(c["concession_ticks"])
		1:
			if state != null:
				var pay := mini(int(c["money"]), state.stock[EconomySystem.SILVER])
				state.stock[EconomySystem.SILVER] -= pay
			discontent = maxi(discontent - int(c["money_calm"]), 0)
		_:
			discontent = maxi(discontent - int(c["guard_calm"]), 0)
	m.flags["calmed"] = tick
	for id in crowd:
		if m.entities.is_alive(id):
			m._remove.call(id)
	crowd = PackedInt32Array()
	crowd_question = ""


## Puts the question asks[kind] to the player under the id `qid`.
func _ask(m: MissionRuntime, kind: String, qid: String, tick: int) -> void:
	var q: Dictionary = m.def.asks.get(kind, {})
	m.run(
		{"do": "ask", "id": qid, "text": q.get("text", ""), "options": q.get("options", [])}, tick
	)


# --- loans ----------------------------------------------------------------------------------


func _loans(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	var l: Dictionary = r.get("loans", {})
	if l.is_empty() or not m.fired.has(str(l.get("from", ""))):
		return
	if not loan_question.is_empty():
		var sums: Array = l["sums"]
		for option in sums.size() + 1:
			if not m.flags.has(MissionRuntime.choice_flag(loan_question, option)):
				continue
			if option < sums.size():
				_borrow(m, l, sums[option], tick)
			loan_question = ""
			loan_wait = tick + int(l["wait_ticks"])
			break
		return
	if tick < loan_wait or not loans_open(m):
		return
	var hero := m.alive_of(l["hero"])
	if hero.is_empty():
		return
	if _dist(m.entities, hero[0] - 1, l["hall"]) <= Fixed.from_cells(int(l["radius"])):
		loan_question = "loan_%d" % (loans + 1)
		_ask(m, "loan", loan_question, tick)


func _borrow(m: MissionRuntime, l: Dictionary, sum: Array, tick: int) -> void:
	var state := m.economy.player(player)
	if state != null:
		state.stock[EconomySystem.SILVER] += int(sum[0])
	var grow := (int(sum[1]) + int(l["interest"]) * loans) * int(l["hero_permille"]) / 1000
	var d: Dictionary = _rules(m).get("discontent", {})
	discontent = mini(discontent + grow, int(d.get("max", 1000)))
	loans += 1
	m.flags["loan"] = tick


# --- the villages ---------------------------------------------------------------------------


func _villages(m: MissionRuntime, v: Dictionary, tick: int) -> void:
	if v.is_empty():
		return
	var e := m.entities
	var at: Array = v["at"]
	var by: Array = v["by"]
	var reach := Fixed.from_cells(int(v["radius"]))
	var state := m.economy.player(player)
	for i in at.size():
		var here := false
		for id in e.alive_ids:
			var s := id - 1
			if e.owners[s] == player and by.has(String(e.type_ids[s])):
				# Only one standing still in the village collects, not one passing through.
				if e.orders[s] == EntityStore.Order.IDLE and _dist(e, s, at[i]) <= reach:
					here = true
					break
		tax_stay[i] = tax_stay[i] + MissionRuntime.CHECK_EVERY if here else 0
		if tax_stay[i] < int(v["stay_ticks"]) or state == null:
			continue
		if taxed_tick[i] >= 0 and tick < taxed_tick[i] + int(v["again_ticks"]):
			continue
		tax_stay[i] = 0
		if plundered[i] == season:
			m.flags["plundered_nothing"] = tick
			continue
		var silver := int(v["silver"])
		if rumour[i] == 1:
			silver = silver * int(v["rumour_permille"]) / 1000
		state.stock[EconomySystem.SILVER] += silver
		state.stock[EconomySystem.FOOD] += int(v["food"])
		var again := taxed_season[i] == season
		discontent += int(v["tax_twice"]) if again else int(v["tax"])
		discontent = mini(discontent, int(_rules(m).get("discontent", {}).get("max", 1000)))
		if again:
			twice += 1
			m.flags["taxed_twice"] = tick
		taxed_tick[i] = tick
		taxed_season[i] = season
		taxes += 1
		m.flags["taxed"] = tick


func _rumours(m: MissionRuntime, r: Dictionary, tick: int) -> void:
	var ru: Dictionary = r.get("rumours", {})
	var v: Dictionary = r.get("villages", {})
	if ru.is_empty() or v.is_empty() or not m.fired.has(str(ru.get("from", ""))):
		return
	var at: Array = v["at"]
	var e := m.entities
	# The priest ends rumours where he stands long enough.
	var reach := Fixed.from_cells(int(ru["radius"]))
	var priest := StringName(ru["priest"])
	for i in at.size():
		if rumour[i] == 0:
			priest_stay[i] = 0
			continue
		var here := false
		for id in e.alive_ids:
			var s := id - 1
			if e.owners[s] == player and e.type_ids[s] == priest and _dist(e, s, at[i]) <= reach:
				here = true
				break
		priest_stay[i] = priest_stay[i] + MissionRuntime.CHECK_EVERY if here else 0
		if priest_stay[i] >= int(ru["clear_ticks"]):
			rumour[i] = 0
			priest_stay[i] = 0
			m.flags["rumour_cleared"] = tick
	if next_rumour < 0:
		next_rumour = tick + int(ru["every_ticks"])
	if tick < next_rumour:
		return
	next_rumour = tick + int(ru["every_ticks"])
	var shrine_r := Fixed.from_cells(int(ru["shrine_radius"]))
	for k in at.size():
		var i := (rumours + k) % at.size()
		if rumour[i] == 1 or _shrine_near(m, at[i], shrine_r):
			continue
		rumour[i] = 1
		rumours += 1
		m.flags["rumour"] = tick
		m.run({"do": "ping", "at": at[i], "radius": 3}, tick)
		return


func _shrine_near(m: MissionRuntime, at: Array, reach: int) -> bool:
	var store := m.economy.buildings
	var x := Fixed.from_cells(int(at[0])) + Fixed.HALF
	var y := Fixed.from_cells(int(at[1])) + Fixed.HALF
	for b in store.alive_ids:
		var bs := b - 1
		if store.owners[bs] != player or store.done[bs] != 1 or store.defs[bs].base_id != &"shrine":
			continue
		if Fixed.distance(store.center_x(b), store.center_y(b), x, y) <= reach:
			return true
	return false


# --- the Order's riders ---------------------------------------------------------------------


func _raids(m: MissionRuntime, ra: Dictionary, tick: int) -> void:
	if ra.is_empty():
		return
	_trophies(m, ra)
	var going := m.fired.has(str(ra["from"])) and not m.fired.has(str(ra["until"]))
	if going and next_raid < 0:
		next_raid = tick + _raid_every(ra)
	if going and tick >= next_raid:
		next_raid = tick + _raid_every(ra)
		_send_raid(m, ra, tick)
	if tick % RAID_EVERY != 0:
		return
	for k in raids.size():
		if m.fired.has(str(ra["until"])) and raid_target[k] >= 0:
			raid_target[k] = -1
		_ride(m, ra, k, tick)


func _raid_every(ra: Dictionary) -> int:
	var every: Array = ra["every"]
	return int(every[mini(season, every.size() - 1)])


func _send_raid(m: MissionRuntime, ra: Dictionary, tick: int) -> void:
	var spawns: Array = ra["spawn"]
	var at: Array = spawns[raids.size() % spawns.size()]
	var units: Array = (ra["units"] as Array).duplicate(true)
	if m.difficulty != "easy":
		units.append_array(ra.get("normal_units", []))
	var name := "raid_%d" % raids.size()
	m.run(
		{
			"do": "spawn",
			"group": name,
			"player": ra["player"],
			"at": at,
			"units": units,
			"stance": "aggressive"
		},
		tick
	)
	raids.append(name)
	raid_target.append(_next_village(m, at, -1))
	raid_done.append(0)
	m.flags["raid"] = tick
	m.run({"do": "ping", "at": at, "radius": 4}, tick)


## The village nearest to `at` the riders have not plundered this season (not `skip`), or -1.
func _next_village(m: MissionRuntime, at: Array, skip: int) -> int:
	var v: Array = _rules(m).get("villages", {}).get("at", [])
	var best := -1
	var best_d := 1 << 30
	for i in v.size():
		if i == skip or plundered[i] == season:
			continue
		var dx := int(v[i][0]) - int(at[0])
		var dy := int(v[i][1]) - int(at[1])
		if dx * dx + dy * dy < best_d:
			best_d = dx * dx + dy * dy
			best = i
	return best


func _ride(m: MissionRuntime, ra: Dictionary, k: int, tick: int) -> void:
	var g := raids[k]
	var ids := m.alive_of(g)
	if ids.is_empty() or raid_target[k] == -2:
		return
	var e := m.entities
	var cx := 0
	var cy := 0
	for id in ids:
		cx += e.pos_x[id - 1]
		cy += e.pos_y[id - 1]
	cx /= ids.size()
	cy /= ids.size()
	var centre := [Fixed.to_cells(cx), Fixed.to_cells(cy)]
	if raid_target[k] == -1:
		_home(m, ra, g, tick)
		return
	# A loaded wagon near: at it.
	var prey := _loaded_near(m, cx, cy, Fixed.from_cells(int(ra["chase_cells"])))
	if prey != 0:
		m._apply.call(SimCommand.attack(tick, int(ra["player"]), ids, prey))
		return
	var v: Array = _rules(m)["villages"]["at"]
	var t: Array = v[raid_target[k]]
	var dx := int(t[0]) - int(centre[0])
	var dy := int(t[1]) - int(centre[1])
	var r := int(ra["plunder_radius"])
	if dx * dx + dy * dy <= r * r:
		plundered[raid_target[k]] = season
		m.flags["plundered"] = tick
		raid_done[k] += 1
		var nxt := _next_village(m, centre, raid_target[k])
		raid_target[k] = nxt if raid_done[k] < int(ra["per_raid"]) and nxt >= 0 else -1
		return
	m.run({"do": "attack_move", "group": g, "to": t}, tick)


func _home(m: MissionRuntime, ra: Dictionary, g: String, tick: int) -> void:
	raid_target[raids.find(g)] = -2
	m.run({"do": "exit", "group": g, "at": ra["exit"], "radius": 3}, tick)
	m.run({"do": "move", "group": g, "to": ra["exit"]}, tick)


func _loaded_near(m: MissionRuntime, x: int, y: int, reach: int) -> int:
	var e := m.entities
	var best := 0
	var best_d := reach + 1
	var ids := cargo.keys()
	ids.sort()
	for id: int in ids:
		if not e.is_alive(id) or e.move_class[id - 1] == NavGrid.MoveClass.BOAT:
			continue
		var d := Fixed.distance(e.pos_x[id - 1], e.pos_y[id - 1], x, y)
		if d < best_d:
			best_d = d
			best = id
	return best


## Riders that died (not those gone home) pay the player a trophy each.
func _trophies(m: MissionRuntime, ra: Dictionary) -> void:
	var e := m.entities
	var home := Fixed.from_cells(4)
	var state := m.economy.player(player)
	for g in raids:
		for id: int in m.groups.get(g, PackedInt32Array()):
			if counted.has(id) or e.is_alive(id):
				continue
			counted[id] = true
			if _dist(e, id - 1, ra["exit"]) > home and state != null:
				state.stock[EconomySystem.SILVER] += int(ra["trophy"])
				trophies += int(ra["trophy"])


# --- seasons --------------------------------------------------------------------------------


func _season(m: MissionRuntime, to: int, tick: int) -> void:
	if to == season:
		return
	season = to as Season
	var se: Dictionary = _rules(m).get("seasons", {})
	var nav := m.economy.nav
	var water := nav.terrain_index(&"t_water")
	var ice := nav.terrain_index(&"t_ice")
	if season == Season.WINTER:
		for rect: Array in se.get("freeze", []):
			for cy in range(int(rect[1]), int(rect[3]) + 1):
				for cx in range(int(rect[0]), int(rect[2]) + 1):
					var cell := nav.cell_at(cx, cy)
					if nav.terrain[cell] == water:
						frozen.append(cell)
						nav.set_terrain(cell, ice)
	elif season == Season.SPRING:
		for cell in frozen:
			nav.set_terrain(cell, water)
		frozen = PackedInt32Array()
		var grass := [nav.terrain_index(&"t_grass"), nav.terrain_index(&"t_field")]
		for rect: Array in se.get("flood", []):
			for cy in range(int(rect[1]), int(rect[3]) + 1):
				for cx in range(int(rect[0]), int(rect[2]) + 1):
					var cell := nav.cell_at(cx, cy)
					if grass.has(int(nav.terrain[cell])) and nav.blocked[cell] == 0:
						flooded.append(cell)
						flood_old.append(nav.terrain[cell])
						nav.set_terrain(cell, water)
		_ashore(m)
	m.flags["season_%d" % season] = tick


## Land units left on water by the thaw or the flood step ashore.
func _ashore(m: MissionRuntime) -> void:
	var nav := m.economy.nav
	var e := m.entities
	for id in e.alive_ids:
		var s := id - 1
		var cls: int = e.move_class[s]
		var cell := nav.cell_of(e.pos_x[s], e.pos_y[s])
		if nav.passable(cls, cell):
			continue
		var open := nav.nearest_passable(cls, cell, 12)
		if open != NavGrid.NO_CELL:
			e.pos_x[s] = nav.center_x(open)
			e.pos_y[s] = nav.center_y(open)
			m._apply.call(SimCommand.stop(now, e.owners[s], PackedInt32Array([id])))


func _mud(m: MissionRuntime, se: Dictionary) -> void:
	if se.is_empty():
		return
	var types: Array = se.get("mud_units", [])
	var permille := int(se.get("mud_permille", 1000)) if season == Season.AUTUMN else 1000
	var e := m.entities
	for id in e.alive_ids:
		var s := id - 1
		var def := m.combat.defs[s]
		if def == null or not types.has(String(e.type_ids[s])):
			continue
		var want := Fixed.speed_per_tick(def.speed_milli * permille / 1000)
		if e.speed[s] != want:
			e.speed[s] = want


# --- wages, the piles, the brothers ---------------------------------------------------------


func _wages(m: MissionRuntime, w: Dictionary, tick: int) -> void:
	if w.is_empty():
		return
	if next_pay < 0 and m.fired.has(str(w.get("from", ""))):
		next_pay = tick + int(w["every_ticks"])
	if next_pay < 0 or tick < next_pay:
		return
	next_pay = tick + int(w["every_ticks"])
	var state := m.economy.player(player)
	if state == null:
		return
	var pay: Dictionary = w["units"]
	var e := m.entities
	var due := wages_due(m)
	if state.stock[EconomySystem.SILVER] >= due:
		state.stock[EconomySystem.SILVER] -= due
		return
	# Who cannot be paid leaves, the dearest first (highest id among equals).
	var left := state.stock[EconomySystem.SILVER]
	state.stock[EconomySystem.SILVER] = 0
	var ids := PackedInt32Array()
	for id in e.alive_ids:
		if e.owners[id - 1] == player and pay.has(String(e.type_ids[id - 1])):
			ids.append(id)
	var owed := due - left
	var k := ids.size() - 1
	while owed > 0 and k >= 0:
		var wage := int(pay[String(e.type_ids[ids[k] - 1])])
		owed -= wage
		m._remove.call(ids[k])
		deserted += 1
		k -= 1
	m.flags["deserted"] = tick


func _piles(m: MissionRuntime, p: Dictionary) -> void:
	if p.is_empty():
		return
	var rect: Array = p["rect"]
	var centre := [(int(rect[0]) + int(rect[2])) / 2, (int(rect[1]) + int(rect[3])) / 2]
	var e := m.entities
	var boats := PackedInt32Array()
	for id in e.alive_ids:
		var s := id - 1
		if e.owners[s] != player or e.move_class[s] != NavGrid.MoveClass.BOAT:
			continue
		var cx := Fixed.to_cells(e.pos_x[s])
		var cy := Fixed.to_cells(e.pos_y[s])
		if cx >= int(rect[0]) and cx <= int(rect[2]) and cy >= int(rect[1]) and cy <= int(rect[3]):
			boats.append(id)
	if boats.is_empty() or _tower_near(m, centre, Fixed.from_cells(int(p["tower_radius"]))):
		return
	for id in boats:
		m.combat.lightning(id, 0, int(p["damage"]))
		m.flags["piles"] = now


func _tower_near(m: MissionRuntime, at: Array, reach: int) -> bool:
	var store := m.economy.buildings
	var x := Fixed.from_cells(int(at[0])) + Fixed.HALF
	var y := Fixed.from_cells(int(at[1])) + Fixed.HALF
	for b in store.alive_ids:
		var bs := b - 1
		if store.owners[bs] != player or store.done[bs] != 1 or store.defs[bs].base_id != &"tower":
			continue
		if Fixed.distance(store.center_x(b), store.center_y(b), x, y) <= reach:
			return true
	return false


func _brothers(m: MissionRuntime, b: Dictionary, tick: int) -> void:
	if b.is_empty() or m.flags.has("brothers_hurt"):
		return
	var e := m.entities
	var out := Fixed.from_cells(4)
	for id: int in m.groups.get(b["group"], PackedInt32Array()):
		var s := id - 1
		# Dead slots keep their last place: one that left the map stood by the way out.
		var hurt := e.hp[s] < e.max_hp[s] if e.is_alive(id) else _dist(e, s, b["exit"]) > out
		if hurt:
			m.flags["brothers_hurt"] = tick
			return


# --- helpers --------------------------------------------------------------------------------


static func _dist(e: EntityStore, s: int, at: Array) -> int:
	var x := Fixed.from_cells(int(at[0])) + Fixed.HALF
	var y := Fixed.from_cells(int(at[1])) + Fixed.HALF
	return Fixed.distance(e.pos_x[s], e.pos_y[s], x, y)


func _rules(m: MissionRuntime) -> Dictionary:
	return m.def.rules.get("silver", {})


func write_to(buf: StreamPeerBuffer) -> void:
	# Nothing outside this mission, so older replays keep their hashes.
	if not on:
		return
	var ids := cargo.keys()
	ids.sort()
	buf.put_32(ids.size())
	for id: int in ids:
		buf.put_32(id)
		buf.put_32(cargo[id])
	for v: int in [
		delivered,
		lost,
		patience,
		discontent,
		season,
		loans,
		loan_wait,
		closed_until,
		crowds,
		taxes,
		twice,
		rumours,
		next_rumour,
		next_raid,
		trophies,
		next_pay,
		deserted,
		1 if crowd_armed else 0
	]:
		buf.put_64(v)
	buf.put_utf8_string(loan_question)
	buf.put_utf8_string(crowd_question)
	for arr: PackedInt32Array in [
		crowd,
		taxed_tick,
		taxed_season,
		plundered,
		tax_stay,
		priest_stay,
		raid_target,
		raid_done,
		frozen,
		flooded
	]:
		buf.put_32(arr.size())
		for v in arr:
			buf.put_32(v)
	buf.put_data(rumour)
	buf.put_data(flood_old)
	for g in raids:
		buf.put_utf8_string(g)
	var done := counted.keys()
	done.sort()
	buf.put_32(done.size())
	for id: int in done:
		buf.put_32(id)
