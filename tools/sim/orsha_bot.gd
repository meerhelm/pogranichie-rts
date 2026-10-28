class_name OrshaBot
extends RefCounted
## A scripted player for «ВКЛ 8. Орша, 1514»: plays the mission through to its end with plain
## player commands, so the recorded game (tests/replays/gdl08_playthrough.json) shows that the
## battle can be won and keeps every trigger on the way working:
##   godot --headless -s tools/sim/sim_cli.gd -- mission --mission gdl_08 \
##     --out tests/replays/gdl08_playthrough.json
## It sees the whole world and is not meant to play well, only to get through. At night four
## servants stand at the head of each bridge; the horse fords the river upstream, the light
## horse cuts down the patrol before it can raise the alarm, Andrei rides to the old oak. At
## dawn the foot and the guns go into the ravine, the znakharka lays the mist over it, the light
## horse waits north of the ravine as bait and the lances by the hetman. The lances help the
## court banners against the Right Hand; when the Left Hand rides at the light horse it sets the
## rally point behind the ravine and orders the «Литовский отход», and the chase comes onto the
## guns. Then everyone goes for the Muscovite camp.

const THINK_EVERY := 20
const P := 1
const FORD_N := Vector2i(118, 82)
const OAK := Vector2i(131, 83)
const RAVINE := Vector2i(100, 65)
const BAIT := Vector2i(106, 56)
const RALLY := Vector2i(104, 76)
const LANCES_AT := Vector2i(90, 74)
const COURT_HELP := Vector2i(44, 72)
const CAMP := Vector2i(79, 12)

var sim: Simulation
var _sent: Dictionary[String, int] = {}
var _crews: Array[PackedInt32Array] = []
var _logged: Dictionary[String, bool] = {}


func _init(p_sim: Simulation) -> void:
	sim = p_sim


## Orders for the coming tick; call before each step.
func think() -> void:
	if sim.mission.is_over() and OS.get_environment("BOT_LOG") == "2" and not _logged.has("end"):
		_logged["end"] = true
		print("  end: %s" % sim.mission.outcome_text)
	if sim.tick % THINK_EVERY != 0 or sim.mission.is_over():
		return
	var m := sim.mission
	if not m.fired.has("4"):
		_night(m)
	elif not m.fired.has("6"):
		_deploy(m)
	elif not m.fired.has("10"):
		_battle(m)
	else:
		_attack()
	if sim.tick % 1200 == 0 and OS.has_environment("BOT_LOG"):
		_log()
	if OS.get_environment("BOT_LOG") == "2":
		for tid: String in m.fired:
			if not _logged.has(tid):
				_logged[tid] = true
				print("  %s at %02d:%02d" % [tid, m.fired[tid] / 1200, m.fired[tid] / 20 % 60])


func _log() -> void:
	var m := sim.mission
	var last := ""
	var at := -1
	for tid: String in m.fired:
		if m.fired[tid] >= at:
			at = m.fired[tid]
			last = tid
	var count := {}
	for id in sim.entities.alive_ids:
		var o := sim.entities.owners[id - 1]
		count[o] = count.get(o, 0) + 1
	print(
		(
			"%02d:%02d last=%s units=%s bridges=%s alarm=%s hidden=%d captives=%d"
			% [
				sim.tick / 1200,
				sim.tick / 20 % 60,
				last,
				count,
				m.battle.built,
				m.battle.alarm,
				m.battle.hidden.size(),
				m.captives,
			]
		)
	)


# --- the night ------------------------------------------------------------------------------


func _night(m: MissionRuntime) -> void:
	_bridges(m)
	if not _sent.has("ford"):
		_sent["ford"] = sim.tick
		_go(_group("riders") + _group("lances") + _group("znakharka"), FORD_N, 0)
		_go(_group("andrei"), OAK, 0)
	_patrol(m)
	if m.fired.has("oak") and not _sent.has("andrei_back"):
		_sent["andrei_back"] = sim.tick
		_go(_group("andrei"), FORD_N, 0)


## Four servants at the head of each bridge.
func _bridges(m: MissionRuntime) -> void:
	if _crews.is_empty():
		var servants := _group("servants")
		_crews.append(servants.slice(0, 4))
		_crews.append(servants.slice(4, 8))
	var bridges: Array = m.def.rules["battle"]["bridges"]
	for i in bridges.size():
		var b: Dictionary = bridges[i]
		var crew := _alive(_crews[i])
		if m.battle.built[i] >= Num.of(b["sections"]):
			_go(_idle(crew), Vector2i(77, 98), 3)
			continue
		var head := MissionBattle.head(b, m.battle.built[i])
		_go(crew, head, 1)


## The light horse rides at the patrol once it is near and cuts it down.
func _patrol(m: MissionRuntime) -> void:
	var patrol := _group("patrol")
	var riders := _group("riders")
	if patrol.is_empty() or riders.is_empty() or m.battle.alarm:
		return
	if _dist_cells(riders[0], FORD_N) > 6:
		return
	if _dist_cells(patrol[0], FORD_N) <= 16:
		_cmd(SimCommand.attack(sim.tick, P, riders, patrol[0]))


# --- the dawn -------------------------------------------------------------------------------


func _deploy(m: MissionRuntime) -> void:
	if not _sent.has("deploy"):
		_sent["deploy"] = sim.tick
		var foot := _group("foot")
		var guns := _group("guns")
		for k in foot.size():
			var at := RAVINE + Vector2i(-3 + k % 4 * 2, 1 + k / 4 * 2)
			_cmd(SimCommand.move(sim.tick, P, PackedInt32Array([foot[k]]), _fx(at.x), _fx(at.y)))
		for k in guns.size():
			var at := RAVINE + Vector2i(-3 + k * 2, -2)
			_cmd(SimCommand.move(sim.tick, P, PackedInt32Array([guns[k]]), _fx(at.x), _fx(at.y)))
		_go(_group("riders"), BAIT, 0)
		_go(_group("lances") + _group("andrei"), LANCES_AT, 0)
		_go(_group("znakharka"), RAVINE + Vector2i(0, 4), 0)
		_go(_group("servants"), Vector2i(77, 98), 0)
	var witch := _group("znakharka")
	if not witch.is_empty() and not _sent.has("mist") and _dist_cells(witch[0], RAVINE) <= 6:
		_sent["mist"] = sim.tick
		_cmd(SimCommand.cast(sim.tick, P, witch, &"sp_bog_mist", _fx(RAVINE.x), _fx(RAVINE.y)))
	var ready := true
	for id in _group("guns") + _group("foot"):
		if not MissionBattle.in_cover(m.def.rules["battle"], _cell(id).x, _cell(id).y):
			ready = false
	if (ready and sim.tick > _sent["deploy"] + 600) or sim.tick > _sent["deploy"] + 3600:
		if not _sent.has("begin"):
			_sent["begin"] = sim.tick
			_cmd(SimCommand.choose(sim.tick, P, &"deploy", 0))


# --- the battle -----------------------------------------------------------------------------


func _battle(m: MissionRuntime) -> void:
	if m.fired.has("7") and not m.fired.has("8"):
		if not _sent.has("court"):
			_sent["court"] = sim.tick
			var lances := _group("lances") + _group("andrei")
			_cmd(SimCommand.attack_move(sim.tick, P, lances, _fx(COURT_HELP.x), _fx(COURT_HELP.y)))
	if not m.fired.has("8"):
		return
	if not _sent.has("back"):
		_sent["back"] = sim.tick
		_go(_group("lances") + _group("andrei"), LANCES_AT, 0)
		_cmd(SimCommand.rally(sim.tick, P, _fx(RALLY.x), _fx(RALLY.y)))
	var riders := _group("riders")
	var left := _group("left")
	if riders.is_empty() or left.is_empty():
		return
	var near := false
	for id in left:
		if _dist_cells(id, _cell_v(riders[0])) <= 7:
			near = true
	if near and (not _sent.has("feint") or sim.tick > _sent["feint"] + 1000):
		_sent["feint"] = sim.tick
		_cmd(SimCommand.order(sim.tick, P, SimCommand.Kind.RETREAT, riders))


func _attack() -> void:
	if sim.tick % 200 != 0:
		return
	var all := (
		_group("riders")
		+ _group("lances")
		+ _group("andrei")
		+ _group("reserve")
		+ _group("foot")
		+ _group("guns")
	)
	var idle := _idle(all)
	if not idle.is_empty():
		_cmd(SimCommand.attack_move(sim.tick, P, idle, _fx(CAMP.x), _fx(CAMP.y)))


# --- queries --------------------------------------------------------------------------------


func _group(g: String) -> PackedInt32Array:
	return sim.mission.alive_of(g)


func _alive(ids: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in ids:
		if sim.entities.is_alive(id):
			out.append(id)
	return out


func _idle(ids: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in ids:
		var s := id - 1
		if sim.entities.orders[s] == EntityStore.Order.IDLE and sim.entities.target[s] == 0:
			out.append(id)
	return out


## Sends the members farther than `within` cells from `at` there.
func _go(ids: PackedInt32Array, at: Vector2i, within: int) -> void:
	var away := PackedInt32Array()
	for id in ids:
		if within <= 0 or _dist_cells(id, at) > within:
			away.append(id)
	if not away.is_empty():
		_cmd(SimCommand.move(sim.tick, P, away, _fx(at.x), _fx(at.y)))


func _cell(id: int) -> Vector2i:
	return Vector2i(
		Fixed.to_cells(sim.entities.pos_x[id - 1]), Fixed.to_cells(sim.entities.pos_y[id - 1])
	)


func _cell_v(id: int) -> Vector2i:
	return _cell(id)


func _dist_cells(id: int, at: Vector2i) -> int:
	var dx := sim.entities.pos_x[id - 1] - _fx(at.x)
	var dy := sim.entities.pos_y[id - 1] - _fx(at.y)
	return Fixed.to_cells(Fixed.isqrt(dx * dx + dy * dy))


static func _fx(cell: int) -> int:
	return Fixed.from_cells(cell) + Fixed.HALF


func _cmd(c: SimCommand) -> void:
	sim.enqueue(c)
