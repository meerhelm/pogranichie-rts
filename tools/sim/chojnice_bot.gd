class_name ChojniceBot
extends RefCounted
## A scripted player for «Корона 4. Хойнице, 1454»: plays the lost battle through with plain
## player commands, so the recorded game (tests/replays/crown04_playthrough.json) shows that
## the mission can be won and keeps every trigger on the way working:
##   godot --headless -s tools/sim/sim_cli.gd -- mission --mission crown_04 \
##     --out tests/replays/crown04_playthrough.json
## It sees the whole world and is not meant to play well, only to get through. The campaign it
## plays has used «The Pact» at Grunwald and knighted banners on the shore in 1433 (it answers
## those marks). Jaśko rides up to his arguing men so they go into the line, which then stands
## (C) and never chases; the priest sets up the three chapels; in the evening the banner strikes
## the Order's horse and comes back; at the sortie everyone rides to the tent round Jaśko and
## Stach, the foot servants hold their ground by the tent; then they close round the king and
## lead him to the causeway, and Stach takes the banner and the rest over the bog.

const THINK_EVERY := 20
const P := 1
const LINE := Vector2i(58, 37)
const STRIKE := Vector2i(66, 25)
const TENT := Vector2i(43, 69)
const EAST := Vector2i(147, 65)
## The places of power (top-left of the site) in the order the priest visits them.
const PLACES: Array[Vector2i] = [Vector2i(88, 48), Vector2i(80, 80), Vector2i(82, 30)]
## The marks of the campaign it plays: «The Pact» at Grunwald, the knights of 1433.
const MARKS: Array[String] = ["mark:crown_01:pact", "mark:crown_03:knights"]
const STAGES: Array[Array] = [
	["11", "over"],
	["9", "king"],
	["8", "sortie"],
	["6", "back"],
	["5", "strike"],
	["4", "line"],
]

var sim: Simulation
var _told := false
var _marked := false
var _stage := ""
var _seen := 0


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
		print("%d fired %s %s" % [sim.tick, m.fired, m.objective_state])
	if not _marked:
		_marked = true
		for q in MARKS:
			_cmd(SimCommand.choose(sim.tick, P, StringName(q), 0))
	if sim.tick % THINK_EVERY != 0:
		return
	_stage = _stage_now()
	match _stage:
		"deploy":
			_deploy()
		"line":
			_hold_line(LINE)
		"strike":
			_strike()
		"back":
			_hold_line(LINE + Vector2i(0, 4))
		"sortie":
			_to_tent()
		"king":
			_lead_king()
		"over":
			_over_the_bog()
	_priest()
	_foot()
	if sim.tick % 600 == 0 and OS.has_environment("BOT_LOG"):
		_log()


func _stage_now() -> String:
	var f := sim.mission.fired
	for step: Array in STAGES:
		if f.has(step[0]):
			return step[1]
	return "deploy"


func _log() -> void:
	var m := sim.mission
	var c := m.chojnice
	var last := ""
	var at := -1
	for tid: String in m.fired:
		if m.fired[tid] >= at:
			at = m.fired[tid]
			last = tid
	print(
		(
			"%02d:%02d %s %s last=%s units=%d arguing=%d front=%d drowned=%d escaped=%d king=%s"
			% [
				sim.tick / 1200,
				sim.tick / 20 % 60,
				c.clock_text(m, sim.tick),
				_stage,
				last,
				_mine().size(),
				c.arguing_now(m),
				c.front,
				c.drowned,
				c.escaped,
				m.alive_of("casimir"),
			]
		)
	)


# --- the day --------------------------------------------------------------------------------


## Jaśko rides among his arguing men; then the whole banner goes into the line.
func _deploy() -> void:
	var c := sim.mission.chojnice
	var horse := _of(&"pl_pospolite")
	var arguing := PackedInt32Array()
	for id in horse:
		if c.is_arguing(id):
			arguing.append(id)
	if not arguing.is_empty():
		_hero_to(&"hero_jasko", _centre(arguing))
		_hero_to(&"hero_stach", _centre(arguing) + Vector2i(1, 0))
		return
	_hold_line(LINE)


## The banner and both heroes stand in the line, told to stand.
func _hold_line(at: Vector2i) -> void:
	var horse := _horse()
	var away := PackedInt32Array()
	for id in horse:
		if _dist_cells(id, at) > 4 and sim.entities.orders[id - 1] == EntityStore.Order.IDLE:
			away.append(id)
	if not away.is_empty():
		_cmd(SimCommand.move(sim.tick, P, away, _fx(at.x), _fx(at.y)))
	_stand(horse)
	_hero_to(&"hero_jasko", at + Vector2i(0, 2))
	_hero_to(&"hero_stach", at + Vector2i(1, 2))


func _strike() -> void:
	var horse := _horse()
	var idle := PackedInt32Array()
	for id in horse:
		if _idle_one(id):
			idle.append(id)
	if not idle.is_empty():
		_set_stance(idle, EntityStore.Stance.AGGRESSIVE)
		_cmd(SimCommand.attack_move(sim.tick, P, idle, _fx(STRIKE.x), _fx(STRIKE.y)))
	for hero: StringName in [&"hero_jasko", &"hero_stach"]:
		var h := _of(hero)
		if not h.is_empty() and _idle_one(h[0]):
			var c := _centre(horse) if not horse.is_empty() else STRIKE
			_cmd(SimCommand.attack_move(sim.tick, P, h, _fx(c.x), _fx(c.y) + Fixed.ONE))


# --- the rear and the king ------------------------------------------------------------------


## Everyone rides to the tent round the heroes and fights there.
func _to_tent() -> void:
	var horse := _horse()
	_set_stance(horse, EntityStore.Stance.AGGRESSIVE)
	var heroes := _of(&"hero_jasko") + _of(&"hero_stach")
	var away := PackedInt32Array()
	for id in horse + heroes:
		if _dist_cells(id, TENT) > 5 and _idle_one(id):
			away.append(id)
	if not away.is_empty():
		_cmd(SimCommand.attack_move(sim.tick, P, away, _fx(TENT.x), _fx(TENT.y)))


## The heroes and the horse close round the king, then ride ahead of him along his road.
func _lead_king() -> void:
	var king := sim.mission.alive_of("casimir")
	if king.is_empty():
		return
	var kc := _centre(king)
	var to := kc
	if sim.mission.chojnice.led:
		to = kc + Vector2i(4, 0)
		if kc.x > 60:
			to = Vector2i(kc.x + 4, 65)
	var ids := _horse() + _of(&"hero_jasko") + _of(&"hero_stach")
	var away := PackedInt32Array()
	for id in ids:
		if _dist_cells(id, to) > 3 and not sim.combat.is_fleeing(id):
			if sim.entities.orders[id - 1] == EntityStore.Order.IDLE or sim.tick % 100 == 0:
				away.append(id)
	if not away.is_empty():
		_cmd(SimCommand.move(sim.tick, P, away, _fx(to.x), _fx(to.y)))


## Stach with the banner and whoever is left go over the causeway to the east bank.
func _over_the_bog() -> void:
	var ids := _mine()
	var away := PackedInt32Array()
	for id in ids:
		if sim.combat.is_fleeing(id) or _dist_cells(id, EAST) <= 1:
			continue
		if sim.entities.orders[id - 1] == EntityStore.Order.IDLE or sim.tick % 200 == 0:
			away.append(id)
	if not away.is_empty():
		_cmd(SimCommand.move(sim.tick, P, away, _fx(EAST.x), _fx(EAST.y)))


# --- the priest and the foot ----------------------------------------------------------------


func _priest() -> void:
	var pr := _of(&"pl_priest")
	if pr.is_empty() or sim.tick % 100 != 0:
		return
	var f := sim.mission.fired
	if not f.has("4") or f.has("5"):
		if f.has("5") and _idle_one(pr[0]) and _dist_cells(pr[0], TENT) > 4:
			_cmd(SimCommand.move(sim.tick, P, pr, _fx(TENT.x + 2), _fx(TENT.y)))
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


## The foot servants hold their ground by the tent; at the end they go with the rest.
func _foot() -> void:
	if sim.mission.fired.has("11"):
		return
	var foot := _of(&"pl_foot_servant")
	var at := TENT + Vector2i(3, -3)
	var away := PackedInt32Array()
	for id in foot:
		if _dist_cells(id, at) > 2 and sim.entities.orders[id - 1] == EntityStore.Order.IDLE:
			away.append(id)
	if not away.is_empty():
		_cmd(SimCommand.move(sim.tick, P, away, _fx(at.x), _fx(at.y)))
	_stand(foot)


# --- queries --------------------------------------------------------------------------------


func _horse() -> PackedInt32Array:
	return _of(&"pl_pospolite") + _of(&"pl_kopia")


func _stand(ids: PackedInt32Array) -> void:
	var loose := PackedInt32Array()
	for id in ids:
		if sim.entities.stance[id - 1] != EntityStore.Stance.STAND:
			loose.append(id)
	_set_stance(loose, EntityStore.Stance.STAND)


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


func _centre(ids: PackedInt32Array) -> Vector2i:
	var sx := 0
	var sy := 0
	for id in ids:
		sx += sim.entities.pos_x[id - 1]
		sy += sim.entities.pos_y[id - 1]
	return Vector2i(Fixed.to_cells(sx / ids.size()), Fixed.to_cells(sy / ids.size()))


func _dist_cells(id: int, at: Vector2i) -> int:
	var dx := sim.entities.pos_x[id - 1] - _fx(at.x)
	var dy := sim.entities.pos_y[id - 1] - _fx(at.y)
	return Fixed.to_cells(Fixed.isqrt(dx * dx + dy * dy))


static func _fx(cell: int) -> int:
	return Fixed.from_cells(cell) + Fixed.HALF


func _cmd(c: SimCommand) -> void:
	sim.enqueue(c)
