class_name MissionRuntime
extends RefCounted
## A mission being played (M9): its setup, its triggers and its own rules, inside the
## simulation (Simulation.mission), so a saved game and a replay carry them. Simulation.step()
## runs it after the players' commands of the tick; it orders units with the same commands a
## player gives (applied at once, not logged: a replay keeps only the players' commands and
## rebuilds the mission from its file). Integers only, triggers in file order.
##
## Conditions (`when`, a dictionary with `type`):
##   start; fired {trigger}; after {trigger, ticks}; flag {flag}; difficulty {at_least};
##   stock {player, res, at_least | at_most}; built {player, base} (a finished building of
##   that kind laid after the setup); destroyed {building}; building_hp_below {building,
##   permille}; near {player, at, radius, unit?}; group_near {group, at, radius};
##   has_unit {player, unit}; age {player, at_least}; cast {player, spell} (its effect is on the
##   map); group_dead / group_lost / group_exited {group}; places_held {player, count};
##   blockade_held (every blockade post is held now); garrison_at_most {permille};
##   group_near_count {group, at, radius, count}; group_alive_at_most {group, count};
##   units_at_most {player, count} (all the player's units, heroes included);
##   retreating {player} (some unit of the player is in a «Литовский отход»); place_held
##   {player, place} (by index in the map's list);
##   baptized {count} (living baptized units, rules.baptism); evidence {at_least | at_most}
##   (whole points, rules.evidence); built_near {player, base, at, radius} (a finished building
##   of that kind, any time); mist_over {player, at} (the player's «Болотный туман» lies there);
##   chose {question, option} (see `ask`); group_exited also takes count; ВКЛ 4–8: see
##   MissionMarch, MissionRetreat, MissionStealth, MissionSiege, MissionBattle; any / all {of:
##   [...]}; not {of}; for_ticks {ticks, of} (true for that long in a row; one per trigger).
## Actions (`do`): objective {id, text?, state? (active, done, failed), optional?}; hint {text};
##   dialogue {lines}; cutscene {id, at, lines}; ping {at, radius} (these four only reach the
##   interface through `events`); spawn {group?, player, at, units, stance?, untouchable?};
##   move / attack_move {group, to}; stance {group, stance}; exit {group, at, radius} (members
##   that get there leave the map); take_stock {player, res, permille}; give_stock {player, res,
##   amount}; lock / unlock {player, items}; flag {flag}; boats {on}; blockade {on};
##   ignite {building}; rally {player, at}; volley {player, at, radius, damage} (a cannon ball
##   lands: the player's enemies there lose HP and morale); kill {group, by} (scripted deaths);
##   victory / defeat {text};
##   ВКЛ 3: evidence {add} (points, may be negative); faith {add} (counts as that many more
##   baptized against evidence); baptism_rate {every_ticks}; spies {count} (how many spies walk
##   the map now); quench {place, permille} (what is left of a place of power, 0: gone, its
##   shrine falls); ask {id, text, options: [text, ...]} (a question the player answers with a
##   CHOOSE command; the interface shows it); pay {player, cost: [food, wood, iron, silver]};
##   destroy {building}; name_built {player, base, name} (names the player's newest finished
##   building of that kind); assault {group, building, else?} (storm a named building, or
##   attack-move to `else` when it is gone).
##   ВКЛ 4–8, Корона 1–5: MissionMarch, Retreat, Stealth, Siege, Battle, Field, Besiege,
##   Baltic, Chojnice, Silver. Setup may also give sides {player: lead player}, neutral
## [players], age, pop {player: places}, power, props, buildings turned:true. Rules: hunger,
## boats, blockade, banner and those of the mission modules.

enum Outcome { NONE, VICTORY, DEFEAT }
enum Objective { ACTIVE, DONE, FAILED }

## Triggers and rules are checked every this many ticks (half a second), not every tick.
const CHECK_EVERY := 10
const STANCES := {
	"aggressive": EntityStore.Stance.AGGRESSIVE,
	"defensive": EntityStore.Stance.DEFENSIVE,
	"stand": EntityStore.Stance.STAND,
	"passive": EntityStore.Stance.PASSIVE,
}
const DIFFICULTIES: Array[String] = ["easy", "normal", "hard"]

var def: MissionDef
var difficulty := "normal"
var entities: EntityStore
var economy: EconomySystem
var combat: CombatSystem
var magic: MagicSystem
var fire: FireSystem
var victory: SkirmishVictory

## Trigger id -> the tick it fired.
var fired: Dictionary[String, int] = {}
## Objectives in the order they were given, with their state, text and whether optional.
var objectives: Array[String] = []
var objective_state: Dictionary[String, int] = {}
var objective_text: Dictionary[String, String] = {}
var objective_optional: Dictionary[String, bool] = {}
var flags: Dictionary[String, int] = {}
## Named groups of units (ids as spawned; the dead stay in the list) and how many were spawned.
var groups: Dictionary[String, PackedInt32Array] = {}
## Groups ordered off the map: [x, y, radius] in fixed units; and how many left that way.
var exits: Dictionary[String, PackedInt64Array] = {}
var exited: Dictionary[String, int] = {}
## Named buildings -> building id.
var named: Dictionary[String, int] = {}
## for_ticks counters, by trigger id.
var counters: Dictionary[String, int] = {}
## The last building id of the setup: later ones are the players'.
var setup_buildings := 0
var next_boat := -1
## The blockade (rules.blockade, phase 4 of ВКЛ 1): on or off, the garrison's strength in
## permille, which posts are held (a bit per post), the tick of the next sortie (-1: none yet)
## and how many sorties went out.
var blockade_on := false
var garrison := 1000
var posts_held := 0
var next_sortie := -1
var sorties := 0
## The khorugv's banner (rules.banner): who carries it (0: it lies on the ground), where it
## fell (fixed units) and when (-1: it stands).
var bearer := 0
var banner_x := 0
var banner_y := 0
var banner_down := -1
## ВКЛ 3. Baptism (rules.baptism): the baptized units by id, extra faith from scripted mass
## baptisms, and how often each church baptizes (ticks).
var baptized: Dictionary[int, bool] = {}
var faith_bonus := 0
var baptism_every := 0
## The evidence the Order gathers for the council (rules.evidence), thousandths of a point; the
## spies on the map and the next waypoint of each; how many spies should walk now, when the next
## one comes (-1: at once) and how many were killed; the last spell effect looked at.
var evidence := 0
var spies := PackedInt32Array()
var spy_waypoint: Dictionary[int, int] = {}
var spies_wanted := 0
var spy_next := -1
var spies_killed := 0
var fx_seen := 0
## Questions put to the player (`ask`) and not answered yet: id -> number of options.
var choices: Dictionary[String, int] = {}
## ВКЛ 4. The marching column (rules.march): unit id -> -1 while in column, or the tick it has
## formed up after being struck. Captives (rules.capture) per group and in all. The next camp
## supply and the next raid (-1: none), and how many raids came.
var marching: Dictionary[int, int] = {}
var captured: Dictionary[String, int] = {}
var captives := 0
var next_supply := -1
var next_raid := -1
var raids := 0
## The panel's countdown (`countdown`): its text and the tick it ends (-1: none).
var countdown_text := ""
var countdown_end := -1
## The mission modules of ВКЛ 5–8 and Корона 1–5 (see the header).
var retreat := MissionRetreat.new()
var stealth := MissionStealth.new()
var siege := MissionSiege.new()
var battle := MissionBattle.new()
var field := MissionField.new()
var besiege := MissionBesiege.new()
var baltic := MissionBaltic.new()
var chojnice := MissionChojnice.new()
var silver := MissionSilver.new()
var outcome := Outcome.NONE
var outcome_text := ""
## What the interface shows, in order: {kind, tick, ...} (kind: objective, hint, dialogue,
## cutscene, ping, end). The interface keeps its own read position.
var events: Array[Dictionary] = []

var _apply: Callable
var _spawn: Callable
var _remove: Callable
var _sides: Sides


func _init(p_def: MissionDef, sim: Simulation, p_difficulty: String) -> void:
	def = p_def
	difficulty = p_difficulty
	entities = sim.entities
	economy = sim.economy
	combat = sim.combat
	magic = sim.magic
	fire = sim.fire
	victory = sim.victory
	_apply = sim.apply_now
	_spawn = sim.spawn_unit
	_remove = sim.remove_unit
	_sides = sim.sides


func is_over() -> bool:
	return outcome != Outcome.NONE


## The mission modules with state, in the order they set up, step and hash.
func _modules() -> Array[RefCounted]:
	return [retreat, stealth, siege, battle, field, besiege, baltic, chojnice, silver]


# --- setup ----------------------------------------------------------------------------------


## The mission's start: players, stock, locks, buildings, walls, units. Called once, at tick 0.
func set_up(tick: int) -> void:
	var s := def.setup
	var sides: Dictionary = s.get("sides", {})
	for key: String in sides:
		_sides.team[key.to_int()] = int(sides[key])
	for p: int in s.get("neutral", []):
		_sides.neutral[p] = true
	for entry: Array in def.players:
		_apply.call(SimCommand.join(tick, entry[0], StringName(entry[1])))
	var stock: Dictionary = s.get("stock", {})
	for key: String in stock:
		var state := economy.player(key.to_int())
		if state != null:
			var values: Array = stock[key]
			state.stock = PackedInt64Array(values)
	var locked: Dictionary = s.get("locked", {})
	for key: String in locked:
		_lock(key.to_int(), locked[key], true)
	for b: Dictionary in s.get("buildings", []):
		var id := _place(tick, b["player"], b["type"], b["at"][0], b["at"][1], b.has("turned"))
		if id == 0:
			push_warning("mission %s: cannot place %s at %s" % [def.id, b["type"], b["at"]])
			continue
		if b.has("name"):
			named[b["name"]] = id
		if b.get("wooden", false):
			fire.wooden[id] = true
	for w: Dictionary in s.get("walls", []):
		var from: Array = w["from"]
		var to: Array = w["to"]
		for cell in BuildingPlacement.wall_cells(from[0], from[1], to[0], to[1]):
			_place(tick, w["player"], w["type"], cell.x, cell.y)
	for g: Dictionary in s.get("groups", []):
		_spawn_group(tick, g)
	for c: Array in s.get("consecrated", []):
		magic.places.consecrated_by[c[0]] = named.get(c[1], 0)
	var ages: Dictionary = s.get("age", {})
	for key: String in ages:
		var state := economy.player(key.to_int())
		if state != null:
			state.age = int(ages[key])
	var b: Dictionary = def.rules.get("banner", {})
	if not b.is_empty():
		var carriers := alive_of(b["group"])
		if not carriers.is_empty():
			_raise_banner(carriers[0])
	var pop: Dictionary = s.get("pop", {})
	for key: String in pop:
		var state := economy.player(key.to_int())
		if state != null:
			state.pop_provided += int(pop[key])
	setup_buildings = economy.buildings.next_id - 1
	for mark: Array in s.get("marks", []):
		choices["mark:%s:%s" % [mark[0], mark[1]]] = 1
	baptism_every = int(def.rules.get("baptism", {}).get("every_ticks", 0))
	MissionMarch.set_up(self)
	for mod in _modules():
		mod.call(&"set_up", self)


func _place(tick: int, p: int, type: String, cx: int, cy: int, turned := false) -> int:
	var before := economy.buildings.next_id
	var x := Fixed.from_cells(cx) + Fixed.HALF
	var y := Fixed.from_cells(cy) + Fixed.HALF
	_apply.call(SimCommand.place(tick, p, StringName(type), x, y, turned))
	return before if economy.buildings.next_id > before else 0


## Units of a group stand in a square around `at`, row by row.
func _spawn_group(tick: int, g: Dictionary) -> void:
	var p: int = g["player"]
	var at: Array = g["at"]
	var units: Array = g["units"]
	var total := 0
	for u: Array in units:
		total += int(u[1])
	var cols := ceili(sqrt(float(total)))
	var ids := PackedInt32Array()
	var i := 0
	for u: Array in units:
		for k in int(u[1]):
			var x := Fixed.from_cells(at[0] + i % cols) + Fixed.HALF
			var y := Fixed.from_cells(at[1] + i / cols) + Fixed.HALF
			var id: int = _spawn.call(StringName(u[0]), p, x, y)
			if id != EntityStore.NO_ID:
				ids.append(id)
			i += 1
	if g.has("stance"):
		_apply.call(SimCommand.set_stance(tick, p, ids, STANCES[g["stance"]]))
	if g.get("untouchable", false):
		for id in ids:
			combat.untouchable[id] = true
	if g.has("group"):
		groups[g["group"]] = ids
	elif g.has("name"):
		groups[g["name"]] = ids


func _lock(p: int, items: Array, on: bool) -> void:
	var state := economy.player(p)
	if state == null:
		return
	for item: String in items:
		if on:
			state.locked[StringName(item)] = true
		else:
			state.locked.erase(StringName(item))


# --- the mission step -----------------------------------------------------------------------


func step(tick: int) -> void:
	if is_over() or tick % CHECK_EVERY != 0:
		return
	_exits()
	_hunger(tick)
	_boats(tick)
	_blockade(tick)
	_banner(tick)
	MissionFaith.baptism(self, tick)
	MissionFaith.spies(self, tick, _spawn, _apply)
	MissionFaith.evidence(self, tick)
	MissionMarch.supply(self, tick)
	MissionMarch.raids(self, tick)
	MissionMarch.march(self, tick)
	MissionMarch.capture(self, tick, _remove)
	MissionMarch.spare(self, tick)
	for mod in _modules():
		mod.call(&"step", self, tick)
	for t: Dictionary in def.triggers:
		var tid: String = t["id"]
		if fired.has(tid):
			continue
		if test(t["when"], tid, tick):
			fired[tid] = tick
			for action: Dictionary in t["do"]:
				run(action, tick)
			if is_over():
				return


## Whether the condition holds now. `tid`: the trigger it belongs to (for for_ticks).
func test(c: Dictionary, tid: String, tick: int) -> bool:
	var ok := false
	match c["type"]:
		"start":
			ok = true
		"fired":
			ok = fired.has(c["trigger"])
		"after":
			ok = fired.has(c["trigger"]) and tick >= fired[c["trigger"]] + int(c["ticks"])
		"flag":
			ok = flags.has(c["flag"])
		"difficulty":
			ok = DIFFICULTIES.find(difficulty) >= DIFFICULTIES.find(c["at_least"])
		"stock":
			ok = _stock(c)
		"built":
			ok = _built(c["player"], StringName(c["base"]))
		"destroyed":
			ok = not economy.buildings.is_alive(named.get(c["building"], 0))
		"building_hp_below":
			var b: int = named.get(c["building"], 0)
			var bs := economy.buildings
			ok = bs.is_alive(b) and bs.hp[b - 1] * 1000 < bs.max_hp[b - 1] * int(c["permille"])
		"near":
			ok = _near(c["player"], StringName(c.get("unit", "")), c["at"], c["radius"])
		"group_near":
			ok = _group_near(c["group"], c["at"], c["radius"])
		"has_unit":
			ok = _units_of(c["player"], StringName(c["unit"])) > 0
		"age":
			var state := economy.player(c["player"])
			ok = state != null and state.age >= int(c["at_least"])
		"cast":
			ok = _cast(c["player"], StringName(c["spell"]))
		"group_dead":
			ok = groups.has(c["group"]) and alive_of(c["group"]).is_empty()
		"group_lost":
			var g: String = c["group"]
			ok = groups.has(g) and alive_of(g).size() + exited.get(g, 0) < groups[g].size()
		"group_exited":
			ok = exited.get(c["group"], 0) >= int(c.get("count", 1))
		"places_held":
			ok = _places_held(c["player"]) >= int(c["count"])
		"blockade_held":
			ok = blockade_on and posts_held == _all_posts()
		"garrison_at_most":
			ok = blockade_on and garrison <= int(c["permille"])
		"group_near_count":
			ok = _group_near_count(c["group"], c["at"], c["radius"]) >= int(c["count"])
		"group_alive_at_most":
			ok = groups.has(c["group"]) and alive_of(c["group"]).size() <= int(c["count"])
		"units_at_most":
			ok = _units_of(c["player"]) <= int(c["count"])
		"retreating":
			ok = _retreating(c["player"])
		"place_held":
			var i := int(c["place"])
			ok = i < magic.places.count() and magic.places.holders[i] == int(c["player"])
		"baptized":
			ok = baptized_alive() >= int(c["count"])
		"evidence":
			var points := evidence / 1000
			ok = not c.has("at_least") or points >= int(c["at_least"])
			ok = ok and (not c.has("at_most") or points <= int(c["at_most"]))
		"built_near":
			ok = _built_near(c["player"], StringName(c["base"]), c["at"], c["radius"])
		"mist_over":
			var at: Array = c["at"]
			ok = magic.mist.hides(c["player"], at[0], at[1], -1)
		"chose":
			ok = flags.has(choice_flag(c["question"], int(c["option"])))
		"any":
			for sub: Dictionary in c["of"]:
				ok = ok or test(sub, tid, tick)
		"all":
			ok = true
			for sub: Dictionary in c["of"]:
				ok = ok and test(sub, tid, tick)
		"not":
			ok = not test(c["of"], tid, tick)
		"for_ticks":
			if test(c["of"], tid, tick):
				counters[tid] = counters.get(tid, 0) + CHECK_EVERY
			else:
				counters[tid] = 0
			ok = counters[tid] >= int(c["ticks"])
		_ when MissionMarch.CONDITIONS.has(c["type"]):
			ok = MissionMarch.test(self, c)
		_:
			var mod := _module_for(c["type"], &"CONDITIONS")
			if mod != null:
				ok = mod.call(&"test", self, c)
			else:
				push_warning("mission %s: unknown condition %s" % [def.id, c["type"]])
	return ok


## The mission module whose CONDITIONS or ACTIONS (`list`) name `what`, or null.
func _module_for(what: String, list: StringName) -> RefCounted:
	for mod in _modules():
		var script: Script = mod.get_script()
		var names: Array = script.get_script_constant_map()[list]
		if names.has(what):
			return mod
	return null


func run(a: Dictionary, tick: int) -> void:
	match a["do"]:
		"objective":
			_objective(a, tick)
		"hint", "dialogue", "cutscene", "ping":
			var e := a.duplicate(true)
			e["kind"] = a["do"]
			e.erase("do")
			e["tick"] = tick
			events.append(e)
		"spawn":
			_spawn_group(tick, a)
		"move", "attack_move":
			var ids := alive_of(a["group"])
			if not ids.is_empty():
				var to: Array = a["to"]
				var x := Fixed.from_cells(to[0]) + Fixed.HALF
				var y := Fixed.from_cells(to[1]) + Fixed.HALF
				var owner := entities.owners[ids[0] - 1]
				var cmd := SimCommand.move(tick, owner, ids, x, y)
				if a["do"] == "attack_move":
					cmd = SimCommand.attack_move(tick, owner, ids, x, y)
				_apply.call(cmd)
		"stance":
			var ids := alive_of(a["group"])
			if not ids.is_empty():
				var owner := entities.owners[ids[0] - 1]
				_apply.call(SimCommand.set_stance(tick, owner, ids, STANCES[a["stance"]]))
		"exit":
			var at: Array = a["at"]
			exits[a["group"]] = PackedInt64Array(
				[
					Fixed.from_cells(at[0]) + Fixed.HALF,
					Fixed.from_cells(at[1]) + Fixed.HALF,
					Fixed.from_cells(a["radius"])
				]
			)
		"take_stock":
			var state := economy.player(a["player"])
			if state != null:
				var r := EconomySystem.RESOURCE_NAMES.find(StringName(a["res"]))
				state.stock[r] -= state.stock[r] * int(a["permille"]) / 1000
		"give_stock":
			var state := economy.player(a["player"])
			if state != null:
				var r := EconomySystem.RESOURCE_NAMES.find(StringName(a["res"]))
				state.stock[r] += int(a["amount"])
		"lock", "unlock":
			_lock(a["player"], a["items"], a["do"] == "lock")
		"flag":
			flags[a["flag"]] = tick
		"boats":
			next_boat = tick + int(def.rules["boats"]["every_ticks"]) if a["on"] else -1
		"blockade":
			blockade_on = a["on"]
		"ignite":
			fire.ignite(named.get(a["building"], 0))
		"rally":
			var at: Array = a["at"]
			var x := Fixed.from_cells(at[0]) + Fixed.HALF
			var y := Fixed.from_cells(at[1]) + Fixed.HALF
			_apply.call(SimCommand.rally(tick, a["player"], x, y))
		"volley":
			_volley(a)
		"kill":
			for id in alive_of(a["group"]):
				combat.lightning(id, int(a.get("by", 0)), entities.hp[id - 1])
		"victory", "defeat":
			_end(a["do"] == "victory", a.get("text", ""), tick)
		"evidence":
			evidence = clampi(evidence + int(a["add"]) * 1000, 0, MissionFaith.evidence_max(self))
		"faith":
			faith_bonus += int(a["add"])
		"baptism_rate":
			baptism_every = int(a["every_ticks"])
		"spies":
			spies_wanted = int(a["count"])
		"quench":
			MissionFaith.quench(self, int(a["place"]), int(a["permille"]))
		"ask":
			choices[a["id"]] = (a["options"] as Array).size()
			var e := a.duplicate(true)
			e["kind"] = "choice"
			e.erase("do")
			e["tick"] = tick
			events.append(e)
		"pay":
			var state := economy.player(a["player"])
			if state != null:
				var cost: Array = a["cost"]
				for r in cost.size():
					state.stock[r] = maxi(state.stock[r] - int(cost[r]), 0)
		"destroy":
			economy.destroy(named.get(a["building"], 0))
		"name_built":
			var b := _last_built(a["player"], StringName(a["base"]))
			if b != 0:
				named[a["name"]] = b
		"assault":
			var ids := alive_of(a["group"])
			var b: int = named.get(a["building"], 0)
			if not ids.is_empty() and economy.buildings.is_alive(b):
				var owner := entities.owners[ids[0] - 1]
				_apply.call(SimCommand.on_building(tick, owner, SimCommand.Kind.ASSAULT, ids, b))
			elif not ids.is_empty() and a.has("else"):
				run({"do": "attack_move", "group": a["group"], "to": a["else"]}, tick)
		_ when MissionMarch.ACTIONS.has(a["do"]):
			MissionMarch.run(self, a, tick)
		_:
			var mod := _module_for(a["do"], &"ACTIONS")
			if mod != null:
				mod.call(&"run", self, a, tick)
			else:
				push_warning("mission %s: unknown action %s" % [def.id, a["do"]])


func _objective(a: Dictionary, tick: int) -> void:
	var oid: String = a["id"]
	var state: int = Objective.ACTIVE
	match a.get("state", "active"):
		"done":
			state = Objective.DONE
		"failed":
			state = Objective.FAILED
	if not objective_state.has(oid):
		if state != Objective.ACTIVE:
			return
		objectives.append(oid)
		objective_text[oid] = a.get("text", "")
		objective_optional[oid] = a.get("optional", false)
	elif objective_state[oid] != Objective.ACTIVE:
		# Done or failed stays so (an optional one cannot be both).
		return
	objective_state[oid] = state
	events.append({"kind": "objective", "tick": tick, "id": oid, "state": state})


func _end(won: bool, text: String, tick: int) -> void:
	outcome = Outcome.VICTORY if won else Outcome.DEFEAT
	outcome_text = text
	var other := 0
	for entry: Array in def.players:
		if entry[0] != def.player:
			other = entry[0]
			break
	victory.winner = def.player if won else other
	victory.reason = SkirmishVictory.Reason.MISSION
	victory.message = text
	victory.end_tick = tick
	events.append({"kind": "end", "tick": tick, "won": won, "text": text})


# --- conditions -----------------------------------------------------------------------------


## The group's members still alive, ascending.
func alive_of(group: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	var members: PackedInt32Array = groups.get(group, PackedInt32Array())
	for id in members:
		if entities.is_alive(id):
			out.append(id)
	out.sort()
	return out


func _stock(c: Dictionary) -> bool:
	var state := economy.player(c["player"])
	if state == null:
		return false
	var amount := state.stock[EconomySystem.RESOURCE_NAMES.find(StringName(c["res"]))]
	if c.has("at_least") and amount < int(c["at_least"]):
		return false
	if c.has("at_most") and amount > int(c["at_most"]):
		return false
	return true


func _built(p: int, base: StringName) -> bool:
	var store := economy.buildings
	for b in store.alive_ids:
		if b > setup_buildings and store.owners[b - 1] == p and store.done[b - 1] == 1:
			if store.defs[b - 1].base_id == base:
				return true
	return false


func _near(p: int, unit: StringName, at: Array, radius: int) -> bool:
	var x := Fixed.from_cells(at[0]) + Fixed.HALF
	var y := Fixed.from_cells(at[1]) + Fixed.HALF
	var r := Fixed.from_cells(radius)
	var e := entities
	for id in e.alive_ids:
		var s := id - 1
		if e.owners[s] != p or (unit != &"" and e.type_ids[s] != unit):
			continue
		if _dist_sq(e.pos_x[s] - x, e.pos_y[s] - y) <= r * r:
			return true
	return false


func _group_near(group: String, at: Array, radius: int) -> bool:
	return _group_near_count(group, at, radius) > 0


## Whether the two players are enemies (ВКЛ 4: who takes whom captive).
func are_hostile(a: int, b: int) -> bool:
	return _sides.hostile(a, b)


func are_friendly(a: int, b: int) -> bool:
	return _sides.friendly(a, b)


func _group_near_count(group: String, at: Array, radius: int) -> int:
	var x := Fixed.from_cells(at[0]) + Fixed.HALF
	var y := Fixed.from_cells(at[1]) + Fixed.HALF
	var r := Fixed.from_cells(radius)
	var n := 0
	for id in alive_of(group):
		if _dist_sq(entities.pos_x[id - 1] - x, entities.pos_y[id - 1] - y) <= r * r:
			n += 1
	return n


## The player's living units (of that type, if given).
func _units_of(p: int, unit: StringName = &"") -> int:
	var n := 0
	for id in entities.alive_ids:
		if entities.owners[id - 1] == p and (unit == &"" or entities.type_ids[id - 1] == unit):
			n += 1
	return n


func _retreating(p: int) -> bool:
	for id in entities.alive_ids:
		if entities.owners[id - 1] == p and entities.intents[id - 1] == EntityStore.Intent.RETREAT:
			return true
	return false


## A cannon ball lands at `at`: every enemy of `player` within `radius` loses `damage` HP and
## morale as from a volley.
func _volley(a: Dictionary) -> void:
	var at: Array = a["at"]
	var x := Fixed.from_cells(at[0]) + Fixed.HALF
	var y := Fixed.from_cells(at[1]) + Fixed.HALF
	var r := Fixed.from_cells(a["radius"])
	var by: int = a["player"]
	var hit := PackedInt32Array()
	for id in entities.alive_ids:
		var s := id - 1
		if not _sides.hostile(by, entities.owners[s]):
			continue
		if _dist_sq(entities.pos_x[s] - x, entities.pos_y[s] - y) <= r * r:
			hit.append(id)
	for id in hit:
		combat.lightning(id, by, int(a["damage"]))


func _cast(p: int, spell: StringName) -> bool:
	for i in magic.fx_ids.size():
		if magic.fx_owner[i] == p and magic.spells[magic.fx_spell[i]].id == spell:
			return true
	return false


func _places_held(p: int) -> int:
	var n := 0
	for i in magic.places.count():
		if magic.places.holders[i] == p:
			n += 1
	return n


## The newest finished building of that kind of the player, or 0.
func _last_built(p: int, base: StringName) -> int:
	var store := economy.buildings
	var found := 0
	for b in store.alive_ids:
		var s := b - 1
		if store.owners[s] == p and store.done[s] == 1 and store.defs[s].base_id == base:
			found = b
	return found


func _built_near(p: int, base: StringName, at: Array, radius: int) -> bool:
	var store := economy.buildings
	var x := Fixed.from_cells(at[0]) + Fixed.HALF
	var y := Fixed.from_cells(at[1]) + Fixed.HALF
	var r := Fixed.from_cells(radius)
	for b in store.alive_ids:
		var s := b - 1
		if store.owners[s] != p or store.done[s] != 1 or store.defs[s].base_id != base:
			continue
		if _dist_sq(store.center_x(b) - x, store.center_y(b) - y) <= r * r:
			return true
	return false


static func _dist_sq(dx: int, dy: int) -> int:
	return dx * dx + dy * dy


## The flag a picked option sets.
static func choice_flag(question: String, option: int) -> String:
	return "choice:%s:%d" % [question, option]


## The player answers an open question (a CHOOSE command): the option's flag is set and the
## question closes. Answers to questions that are not open, or from others, are ignored.
func choose(p: int, question: String, option: int, tick: int) -> void:
	if p != def.player or not choices.has(question):
		return
	if option < 0 or option >= choices[question]:
		return
	choices.erase(question)
	flags[choice_flag(question, option)] = tick
	events.append({"kind": "chosen", "tick": tick, "id": question, "option": option})


# --- the mission's own rules ----------------------------------------------------------------


## Members of a group with an exit that got there leave the map.
func _exits() -> void:
	var names := exits.keys()
	names.sort()
	for g: String in names:
		var at := exits[g]
		for id in alive_of(g):
			var dx := entities.pos_x[id - 1] - at[0]
			var dy := entities.pos_y[id - 1] - at[1]
			if _dist_sq(dx, dy) <= at[2] * at[2]:
				exited[g] = exited.get(g, 0) + 1
				_remove.call(id)


## Hunger (card: «стартовый запас еды мал и падает быстрее обычного»): every every_ticks the
## player loses a food per units_per_food of their units, until the `until` trigger fires.
func _hunger(tick: int) -> void:
	var h: Dictionary = def.rules.get("hunger", {})
	if h.is_empty() or fired.has(h["until"]) or tick == 0 or tick % int(h["every_ticks"]) != 0:
		return
	var p: int = h["player"]
	var state := economy.player(p)
	if state == null:
		return
	var n := 0
	for id in entities.alive_ids:
		if entities.owners[id - 1] == p:
			n += 1
	var eat := n / maxi(int(h["units_per_food"]), 1)
	state.stock[EconomySystem.FOOD] = maxi(state.stock[EconomySystem.FOOD] - eat, 0)


## Boats: once switched on, every every_ticks a boat lands `units` at the pier and they go to
## `to`; the boats stop for good once `holder` stands at the pier with no one of the Order near.
func _boats(tick: int) -> void:
	var b: Dictionary = def.rules.get("boats", {})
	if b.is_empty() or next_boat < 0 or flags.has("pier_closed"):
		return
	var pier: Array = b["pier"]
	var holder := _near(b["holder"], &"", pier, b["radius"])
	if holder and not _near(b["player"], &"", pier, b["radius"]):
		flags["pier_closed"] = tick
		next_boat = -1
		return
	if tick < next_boat:
		return
	next_boat = tick + int(b["every_ticks"])
	var g := {"group": "boat_%d" % tick, "player": b["player"], "at": b["at"], "units": b["units"]}
	_spawn_group(tick, g)
	run({"do": "attack_move", "group": g["group"], "to": b["to"]}, tick)


## Blockade (card, phase 4: «если перерезать пристань и дороги к замку, его гарнизон теряет
## здоровье от болезней и голода, по 1% в 10 секунд»; «каждые 2 минуты вылазка на одну из
## точек»). A post is held when `player` has a unit within `radius` of it and `enemy` has none.
## While every post is held, each every_ticks the garrison's strength falls by step_permille and
## each of its units loses that share of its HP, down to sick_floor_permille of it (sickness
## weakens, it does not kill). From the first time all posts are held, every sortie_every ticks
## up to sortie_size garrison units (not the `keep` ones) come out against the next post in turn.
func _blockade(tick: int) -> void:
	var b: Dictionary = def.rules.get("blockade", {})
	if b.is_empty() or not blockade_on:
		return
	var posts: Array = b["posts"]
	posts_held = 0
	for i in posts.size():
		var at: Array = posts[i]
		if _near(b["player"], &"", at, b["radius"]) and not _near(b["enemy"], &"", at, b["radius"]):
			posts_held |= 1 << i
	var full := posts_held == _all_posts()
	if full and next_sortie < 0:
		next_sortie = tick + int(b["sortie_every"])
	if full and garrison > 0 and tick % int(b["every_ticks"]) == 0:
		var step := int(b["step_permille"])
		garrison = maxi(garrison - step, 0)
		_sicken(b, step)
	if next_sortie >= 0 and tick >= next_sortie and garrison > 0:
		next_sortie = tick + int(b["sortie_every"])
		_sortie(b, tick)


func _all_posts() -> int:
	var b: Dictionary = def.rules.get("blockade", {})
	return (1 << (b.get("posts", []) as Array).size()) - 1


func _garrison_ids(b: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	for g: String in b["groups"]:
		out.append_array(alive_of(g))
	return out


func _sicken(b: Dictionary, step: int) -> void:
	var floor_permille := int(b["sick_floor_permille"])
	for id in _garrison_ids(b):
		var s := id - 1
		var low := entities.max_hp[s] * floor_permille / 1000
		if entities.hp[s] > low:
			entities.hp[s] = maxi(entities.hp[s] - maxi(entities.max_hp[s] * step / 1000, 1), low)


func _sortie(b: Dictionary, tick: int) -> void:
	var out_already := {}
	for i in sorties:
		var members: PackedInt32Array = groups.get("sortie_%d" % i, PackedInt32Array())
		for id in members:
			out_already[id] = true
	var keep: Array = b.get("keep", [])
	var ids := PackedInt32Array()
	for id in _garrison_ids(b):
		if ids.size() >= int(b["sortie_size"]):
			break
		if out_already.has(id) or String(entities.type_ids[id - 1]) in keep:
			continue
		ids.append(id)
	if ids.is_empty():
		return
	var posts: Array = b["posts"]
	var at: Array = posts[sorties % posts.size()]
	var name := "sortie_%d" % sorties
	sorties += 1
	groups[name] = ids
	flags["sortie"] = tick
	run({"do": "stance", "group": name, "stance": "aggressive"}, tick)
	run({"do": "attack_move", "group": name, "to": at}, tick)
	run({"do": "ping", "at": at, "radius": int(b["radius"])}, tick)


## The khorugv's banner (card ВКЛ 2: «Если знаменосец пал, у отряда есть 20 секунд, чтобы
## поднять знамя, иначе хоругвь бежит»). The bearer gives the banner's morale around him
## (CombatSystem.banners). When he falls the banner lies where he fell: the first unit of
## `player` within raise_radius of it (lowest id) picks it up. If nobody does in raise_ticks,
## the flag banner_lost is set and every unit of the player loses all its morale.
func _banner(tick: int) -> void:
	var b: Dictionary = def.rules.get("banner", {})
	if b.is_empty():
		return
	if bearer != 0:
		if entities.is_alive(bearer) and entities.hp[bearer - 1] > 0:
			banner_x = entities.pos_x[bearer - 1]
			banner_y = entities.pos_y[bearer - 1]
			return
		combat.banners.bearers.erase(bearer)
		bearer = 0
		banner_down = tick
		flags["banner_down"] = tick
		run({"do": "ping", "at": [banner_x / Fixed.ONE, banner_y / Fixed.ONE], "radius": 2}, tick)
	if banner_down < 0 or flags.has("banner_lost"):
		return
	var r := Fixed.from_cells(b["raise_radius"])
	var p: int = b["player"]
	for id in entities.alive_ids:
		var s := id - 1
		if entities.owners[s] != p or entities.hp[s] <= 0 or combat.is_fleeing(id):
			continue
		if _dist_sq(entities.pos_x[s] - banner_x, entities.pos_y[s] - banner_y) <= r * r:
			_raise_banner(id)
			flags["banner_raised"] = tick
			return
	if tick - banner_down >= int(b["raise_ticks"]):
		flags["banner_lost"] = tick
		for id in entities.alive_ids:
			if entities.owners[id - 1] == p:
				combat.lose_morale(id - 1, 1000)


func _raise_banner(id: int) -> void:
	bearer = id
	banner_down = -1
	banner_x = entities.pos_x[id - 1]
	banner_y = entities.pos_y[id - 1]
	combat.banners.bearers[id] = true


## Living baptized units (ВКЛ 3).
func baptized_alive() -> int:
	return MissionFaith.baptized_alive(self)


# --- state ----------------------------------------------------------------------------------


func write_to(buf: StreamPeerBuffer) -> void:
	buf.put_8(outcome)
	buf.put_32(setup_buildings)
	buf.put_64(next_boat)
	buf.put_8(1 if blockade_on else 0)
	buf.put_32(garrison)
	buf.put_32(posts_held)
	buf.put_64(next_sortie)
	buf.put_32(sorties)
	buf.put_32(bearer)
	buf.put_64(banner_x)
	buf.put_64(banner_y)
	buf.put_64(banner_down)
	buf.put_32(events.size())
	for d: Dictionary in [fired, objective_state, flags, exited, named, counters]:
		var keys := d.keys()
		keys.sort()
		buf.put_32(keys.size())
		for k: String in keys:
			buf.put_utf8_string(k)
			buf.put_64(int(d[k]))
	var names := groups.keys()
	names.sort()
	for g: String in names:
		buf.put_utf8_string(g)
		for id in groups[g]:
			buf.put_32(id)
	for oid in objectives:
		buf.put_utf8_string(oid)
	# ВКЛ 3.
	var ids := baptized.keys()
	ids.sort()
	buf.put_32(ids.size())
	for id: int in ids:
		buf.put_32(id)
	buf.put_32(faith_bonus)
	buf.put_32(baptism_every)
	buf.put_64(evidence)
	buf.put_32(spies.size())
	for id in spies:
		buf.put_32(id)
		buf.put_32(spy_waypoint.get(id, 0))
	buf.put_32(spies_wanted)
	buf.put_64(spy_next)
	buf.put_32(spies_killed)
	buf.put_32(fx_seen)
	var open := choices.keys()
	open.sort()
	for q: String in open:
		buf.put_utf8_string(q)
		buf.put_32(choices[q])
	var places := magic.places.quenched.keys()
	places.sort()
	for i: int in places:
		buf.put_32(i)
		buf.put_32(magic.places.quenched[i])
	MissionMarch.write_to(self, buf)
	for mod in _modules():
		mod.call(&"write_to", buf)
