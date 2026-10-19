class_name SwiecinoBot
extends RefCounted
## A scripted player for «Корона 6. Свецино, 1462»: plays the battle through with plain player
## commands, so the recorded game (tests/replays/crown06_playthrough.json) shows that the
## mission can be won and keeps every trigger on the way working:
##   godot --headless -s tools/sim/sim_cli.gd -- mission --mission crown_06 \
##     --out tests/replays/crown06_playthrough.json
## It sees the whole world and is not meant to play well, only to get through. At dawn it hires
## three companies of horse and two of drabants, draws the wagons up in a ring and lets the foot
## dig the ditch while the crossbowmen go into the reeds and the priest sets up the chapels. In
## the morning the horse holds a line before the camp and sends tired riders back to rest by
## the wagons; at noon it waits in the field before the reeds, so the Order's charge comes under
## the crossbows, and meets Raweneck's second charge there. Then everybody goes for the Order's
## wagon fort and, last, rides at the Pomeranian peasants.

const THINK_EVERY := 20
const P := 1
const CAMP := Vector2i(46, 74)
const LINE := Vector2i(56, 50)
const REEDS := Vector2i(32, 60)
const LURE := Vector2i(40, 57)
const ORDER_CAMP := Vector2i(74, 20)
const WEST := Vector2i(30, 23)
## The places of power (top-left of the site) in the order the priest visits them.
const PLACES: Array[Vector2i] = [Vector2i(88, 58), Vector2i(104, 34), Vector2i(82, 88)]
## What it hires, by option of the hire question: three hired horse, two drabants, then enough.
const HIRES: Array[int] = [0, 0, 0, 3, 3, 4]
const STAGES: Array[Array] = [
	["11", "peasants"],
	["10", "tabor"],
	["7", "lure"],
	["6", "noon"],
	["4", "fight"],
]
const TIRED := 380
const RESTED := 850
## Riders below this per mille of their hp go back to the wagons and stay there.
const WOUNDED := 400

var sim: Simulation
var _told := false
var _hired := 0
var _ringed := -100000
var _stage := ""
var _seen := 0
## Riders sent back to rest.
var _resting: Dictionary[int, bool] = {}


func _init(p_sim: Simulation) -> void:
	sim = p_sim


## Orders for the coming tick; call before each step.
func think() -> void:
	var m := sim.mission
	if m.is_over():
		if not _told and OS.has_environment("BOT_LOG"):
			_told = true
			print("over at %d: %s" % [sim.tick, m.outcome_text])
		return
	if OS.has_environment("BOT_LOG") and m.fired.size() != _seen:
		_seen = m.fired.size()
		print("%d fired %s %s" % [sim.tick, m.fired.keys(), m.objective_state])
	_answer()
	if sim.tick % THINK_EVERY != 0:
		return
	_stage = _stage_now()
	_wagons()
	_crossbows()
	_priest()
	match _stage:
		"dawn":
			_dig()
			_hold(CAMP + Vector2i(0, -8), false)
		"fight":
			_dig()
			_hold(LINE, true)
		"noon":
			_dig()
			_hold(LURE, false)
		"lure":
			_hold(LURE, true)
		"tabor":
			_storm()
		"peasants":
			_peasants()
	if sim.tick % 600 == 0 and OS.has_environment("BOT_LOG"):
		_log()


func _stage_now() -> String:
	var f := sim.mission.fired
	for step: Array in STAGES:
		if f.has(step[0]):
			return step[1]
	return "dawn"


func _log() -> void:
	var m := sim.mission
	var s := m.swiecino
	print(
		(
			"%02d:%02d %s %s units=%d foe=%d ditch=%d stamina=%d zone=%d prisoners=%d silver=%d "
			% [
				sim.tick / 1200,
				sim.tick / 20 % 60,
				s.clock_text(m, sim.tick),
				_stage,
				_mine().size(),
				_foes().size(),
				s.ditch_permille(m),
				s.player_stamina(m),
				s.in_zone(m),
				s.prisoners,
				sim.economy.player(P).stock[EconomySystem.SILVER],
			]
		)
	)


# --- hiring, wagons, foot, crossbows, the priest ---------------------------------------------


func _answer() -> void:
	var s := sim.mission.swiecino
	if s.question.is_empty() or not sim.mission.choices.has(s.question):
		return
	var option := HIRES[mini(_hired, HIRES.size() - 1)]
	_hired += 1
	_cmd(SimCommand.choose(sim.tick, P, StringName(s.question), option))


func _wagons() -> void:
	var s := sim.mission.swiecino
	if s.ring_at_camp(sim.mission) or sim.tick - _ringed < 600:
		return
	var wagons := sim.mission.alive_of("wagons")
	for id in wagons:
		if sim.entities.orders[id - 1] != EntityStore.Order.IDLE:
			return
	_ringed = sim.tick
	_cmd(SimCommand.order(sim.tick, P, SimCommand.Kind.TABOR, wagons))


## The foot stands idle inside the camp, so it digs; once the ditch is dug it holds the gap.
func _dig() -> void:
	var foot := _of(&"pl_drab") + _of(&"nt_gdansk_militia")
	var at := CAMP + Vector2i(0, -4)
	var away := PackedInt32Array()
	for id in foot:
		if _dist_cells(id, at) > 5 and _idle_one(id):
			away.append(id)
	if not away.is_empty():
		_cmd(SimCommand.move(sim.tick, P, away, _fx(at.x), _fx(at.y)))


func _crossbows() -> void:
	var xb := _of(&"nt_gdansk_crossbow")
	var away := PackedInt32Array()
	for id in xb:
		if _dist_cells(id, REEDS) > 3 and _idle_one(id) and not sim.combat.is_fleeing(id):
			away.append(id)
	if not away.is_empty():
		_cmd(SimCommand.move(sim.tick, P, away, _fx(REEDS.x), _fx(REEDS.y)))
	_set_stance(xb, EntityStore.Stance.STAND)


func _priest() -> void:
	var pr := _of(&"pl_priest")
	if pr.is_empty() or sim.tick % 100 != 0 or not sim.mission.fired.has("2"):
		return
	var store := sim.economy.buildings
	for at in PLACES:
		var shrine := 0
		for b in store.alive_ids:
			var s := b - 1
			if store.owners[s] == P and store.type_ids[s] == &"pl_shrine":
				if store.cell_x[s] == at.x and store.cell_y[s] == at.y:
					shrine = b
		if shrine != 0 and store.done[shrine - 1] == 1:
			continue
		if not _idle_one(pr[0]) and sim.economy.job[pr[0] - 1] != EconomySystem.Job.NONE:
			return
		var places := sim.magic.places
		var site := places.site_at(at.x, at.y)
		if shrine == 0 and site >= 0 and places.holders[site] != P:
			if _dist_cells(pr[0], at + Vector2i(1, 1)) > 1:
				_cmd(SimCommand.move(sim.tick, P, pr, _fx(at.x + 1), _fx(at.y + 1)))
		elif shrine == 0:
			_cmd(SimCommand.build(sim.tick, P, pr, &"pl_shrine", _fx(at.x), _fx(at.y)))
		else:
			_cmd(SimCommand.on_building(sim.tick, P, SimCommand.Kind.WORK, pr, shrine))
		return


# --- the horse ------------------------------------------------------------------------------


## The horse holds round `at` (fighting what comes when `fight`); tired riders go back to the
## wagons and come out again rested. Stach and Dunin stay a little behind the line.
func _hold(at: Vector2i, fight: bool) -> void:
	var s := sim.mission.swiecino
	var horse := _horse()
	var out := PackedInt32Array()
	var home := PackedInt32Array()
	for id in horse:
		if sim.combat.is_fleeing(id):
			continue
		var left: int = s.stamina.get(id, 1000)
		var hurt := sim.entities.hp[id - 1] * 1000 < WOUNDED * sim.entities.max_hp[id - 1]
		if _resting.has(id):
			if left >= RESTED and not hurt:
				_resting.erase(id)
			continue
		if fight and (left < TIRED or hurt):
			_resting[id] = true
			home.append(id)
			continue
		if _dist_cells(id, at) > 4 and _idle_one(id):
			out.append(id)
	if not home.is_empty():
		_cmd(SimCommand.move(sim.tick, P, home, _fx(CAMP.x), _fx(CAMP.y)))
	if not out.is_empty():
		_set_stance(out, EntityStore.Stance.DEFENSIVE)
		_cmd(SimCommand.attack_move(sim.tick, P, out, _fx(at.x), _fx(at.y)))
	_hero_to(&"hero_stach", at + Vector2i(0, 5))
	_hero_to(&"hero_dunin", at + Vector2i(-2, 6))
	_hero_to(&"hero_jasienski", at + Vector2i(2, 4))


## Everybody who can fight goes into the Order's wagon fort.
func _storm() -> void:
	var ids := _horse() + _of(&"pl_drab") + _of(&"nt_gdansk_militia")
	var away := PackedInt32Array()
	for id in ids:
		if _dist_cells(id, ORDER_CAMP) > 3 and _idle_one(id) and not sim.combat.is_fleeing(id):
			away.append(id)
	if not away.is_empty():
		_set_stance(away, EntityStore.Stance.AGGRESSIVE)
		_cmd(SimCommand.attack_move(sim.tick, P, away, _fx(ORDER_CAMP.x), _fx(ORDER_CAMP.y)))
	_hero_to(&"hero_stach", ORDER_CAMP + Vector2i(0, 8))


func _peasants() -> void:
	var horse := _horse()
	var away := PackedInt32Array()
	for id in horse:
		if _dist_cells(id, WEST) > 3 and _idle_one(id) and not sim.combat.is_fleeing(id):
			away.append(id)
	if not away.is_empty():
		_cmd(SimCommand.attack_move(sim.tick, P, away, _fx(WEST.x), _fx(WEST.y)))
	_hero_to(&"hero_stach", ORDER_CAMP + Vector2i(-6, 6))


# --- queries --------------------------------------------------------------------------------


func _horse() -> PackedInt32Array:
	return _of(&"pl_merc_horse") + _of(&"pl_kopia") + _of(&"pl_light_horse")


func _foes() -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in sim.entities.alive_ids:
		if sim.entities.owners[id - 1] == 2 and sim.entities.hp[id - 1] > 0:
			out.append(id)
	return out


func _set_stance(ids: PackedInt32Array, stance: int) -> void:
	var change := PackedInt32Array()
	for id in ids:
		if sim.entities.stance[id - 1] != stance:
			change.append(id)
	if not change.is_empty():
		_cmd(SimCommand.set_stance(sim.tick, P, change, stance))


func _hero_to(hero: StringName, at: Vector2i) -> void:
	var h := _of(hero)
	if h.is_empty() or _dist_cells(h[0], at) <= 1:
		return
	if sim.entities.orders[h[0] - 1] == EntityStore.Order.IDLE or sim.tick % 100 == 0:
		_cmd(SimCommand.move(sim.tick, P, h, _fx(at.x), _fx(at.y)))


func _mine() -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in sim.entities.alive_ids:
		if sim.entities.owners[id - 1] == P and sim.entities.hp[id - 1] > 0:
			out.append(id)
	return out


func _of(type: StringName) -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in _mine():
		if sim.entities.type_ids[id - 1] == type:
			out.append(id)
	return out


func _idle_one(id: int) -> bool:
	var s := id - 1
	return sim.entities.orders[s] == EntityStore.Order.IDLE and sim.entities.target[s] == 0


func _dist_cells(id: int, at: Vector2i) -> int:
	var dx := sim.entities.pos_x[id - 1] - _fx(at.x)
	var dy := sim.entities.pos_y[id - 1] - _fx(at.y)
	return Fixed.to_cells(Fixed.isqrt(dx * dx + dy * dy))


static func _fx(cell: int) -> int:
	return Fixed.from_cells(cell) + Fixed.HALF


func _cmd(c: SimCommand) -> void:
	sim.enqueue(c)
