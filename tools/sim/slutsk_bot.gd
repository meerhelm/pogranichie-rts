class_name SlutskBot
extends RefCounted
## A scripted player for «ВКЛ 7. Слуцк, 1508»: plays the mission through to its end with plain
## player commands, so the recorded game (tests/replays/gdl07_playthrough.json) shows that the
## siege can be held and keeps every trigger on the way working:
##   godot --headless -s tools/sim/sim_cli.gd -- mission --mission gdl_07 \
##     --out tests/replays/gdl07_playthrough.json
## It sees the whole world and is not meant to play well, only to get through. Archers and the
## hook guns stand by the Lower castle's walls, the townsmen come in from the posad, spearmen
## wait behind the wall where the ladders will go up and push them off. After the first assault
## Andrei, Yuri and the light horse go out through the secret passage; Yuri waits by the river
## while the others set the ladder workshops on fire, and all come back the same way. For the
## night assault the spearmen move to the Upper castle's walls and the heroes stay by the court.

const THINK_EVERY := 20
const P := 1
## Where the shooters stand: inside the Lower castle right by its north and east walls.
const SHOOTERS: Array[Vector2i] = [
	Vector2i(44, 33),
	Vector2i(48, 33),
	Vector2i(52, 33),
	Vector2i(56, 33),
	Vector2i(61, 37),
	Vector2i(61, 41),
	Vector2i(61, 44),
	Vector2i(61, 53),
	Vector2i(61, 56),
	Vector2i(61, 60),
]
const GUNS: Array[Vector2i] = [Vector2i(61, 47), Vector2i(61, 50)]
## Behind the wall at the tops of the ladders of each assault.
const TOPS_1: Array[Vector2i] = [
	Vector2i(46, 33), Vector2i(54, 33), Vector2i(61, 40), Vector2i(61, 56)
]
const TOPS_2: Array[Vector2i] = [
	Vector2i(26, 39),
	Vector2i(32, 39),
	Vector2i(30, 57),
	Vector2i(28, 39),
	Vector2i(61, 44),
	Vector2i(50, 63),
]
const TOWNSMEN := Vector2i(48, 50)
const TOWNSMEN_NIGHT := Vector2i(31, 48)
const HOME := Vector2i(50, 47)
const COURT := Vector2i(32, 47)
const MOUTH := Vector2i(24, 41)
const EXIT := Vector2i(18, 27)
const OUTSIDE := Vector2i(21, 27)
const WORKSHOP_NAMES: Array[String] = ["workshop_3", "workshop_1", "workshop_2"]

var sim: Simulation
var _sortie := PackedInt32Array()
## Sortie state: 0 not yet, 1 going to the passage, 2 outside, 3 coming back, 4 back home.
var _phase := 0


func _init(p_sim: Simulation) -> void:
	sim = p_sim


## Orders for the coming tick; call before each step.
func think() -> void:
	if sim.tick % THINK_EVERY != 0 or sim.mission.is_over():
		return
	var m := sim.mission
	if sim.tick == 0:
		_cmd(SimCommand.move(sim.tick, P, _group("burghers"), _fx(TOWNSMEN.x), _fx(TOWNSMEN.y)))
	if sim.tick % 200 == 0:
		_posts(m)
	if m.fired.has("4") and not m.fired.has("7"):
		_sortie_step(m)
	elif m.fired.has("7"):
		_night(m)
	if sim.tick % 1200 == 0 and OS.has_environment("BOT_LOG"):
		_log()


func _log() -> void:
	var m := sim.mission
	var count := {}
	for id in sim.entities.alive_ids:
		var o := sim.entities.owners[id - 1]
		count[o] = count.get(o, 0) + 1
	print(
		(
			"%02d:%02d fired=%d units=%s food=%d ladders=%d pushed=%d climbed=%d burned=%d sortie=%d"
			% [
				sim.tick / 1200,
				sim.tick / 20 % 60,
				m.fired.size(),
				count,
				sim.economy.player(P).stock[EconomySystem.FOOD],
				m.siege.ladders_up(),
				m.siege.pushed,
				m.siege.climbed,
				m.siege.burned_set.size(),
				_phase,
			]
		)
	)


# --- posts ----------------------------------------------------------------------------------


## Shooters and guns back at their places by the walls, spearmen at the ladder tops.
func _posts(m: MissionRuntime) -> void:
	_spread(_group("archers"), SHOOTERS)
	_spread(_group("hakownica"), GUNS)
	_spread(_group("spears"), TOPS_2 if m.fired.has("7") else TOPS_1)


## Each idle unit goes to its own place (unit k to place k mod n).
func _spread(ids: PackedInt32Array, at: Array[Vector2i]) -> void:
	for k in ids.size():
		var c: Vector2i = at[k % at.size()]
		var one := PackedInt32Array([ids[k]])
		if _idle(one).is_empty() or _dist_cells(ids[k], c) <= 0:
			continue
		_cmd(SimCommand.move(sim.tick, P, one, _fx(c.x), _fx(c.y)))


# --- the sortie -----------------------------------------------------------------------------


func _sortie_step(m: MissionRuntime) -> void:
	if _phase == 0:
		_sortie = _group("andrei")
		_sortie.append_array(_group("yuri"))
		_sortie.append_array(_group("yuri_guard"))
		var horse := PackedInt32Array()
		for id in _group("veterans"):
			if sim.entities.type_ids[id - 1] == &"gdl_light_horse":
				horse.append(id)
		_sortie.append_array(horse)
		_phase = 1
	_sortie = _alive(_sortie)
	match _phase:
		1:
			# One by one onto the mouth of the passage; who is through waits outside.
			_through(MOUTH, false)
			if _all_out():
				_phase = 2
		2:
			# The young prince waits by the river; the others burn the workshops.
			var yuri := _group("yuri")
			if not yuri.is_empty() and _dist_cells(yuri[0], OUTSIDE) > 1:
				_cmd(SimCommand.move(sim.tick, P, yuri, _fx(OUTSIDE.x), _fx(OUTSIDE.y)))
			_burn(m)
			if m.fired.has("6") and _workshops_left(m) == 0 or sim.tick > m.fired["4"] + 4 * 1200:
				_phase = 3
		3:
			_through(EXIT, true)
			if _none_out():
				_phase = 4
				_cmd(SimCommand.move(sim.tick, P, _sortie, _fx(COURT.x), _fx(COURT.y)))


## Sends the idle sortie riders on the wrong side to the mouth `at`, the nearest first.
func _through(at: Vector2i, coming_back: bool) -> void:
	var waiting := PackedInt32Array()
	for id in _idle(_sortie):
		if _inside(id) == coming_back:
			continue
		waiting.append(id)
	if waiting.is_empty():
		return
	var best := waiting[0]
	for id in waiting:
		if _dist_cells(id, at) < _dist_cells(best, at):
			best = id
	_cmd(SimCommand.move(sim.tick, P, PackedInt32Array([best]), _fx(at.x), _fx(at.y)))
	if not coming_back:
		var out := PackedInt32Array()
		for id in _idle(_sortie):
			if not _inside(id) and _dist_cells(id, EXIT) <= 2:
				out.append(id)
		if not out.is_empty():
			_cmd(SimCommand.move(sim.tick, P, out, _fx(OUTSIDE.x), _fx(OUTSIDE.y)))


func _burn(m: MissionRuntime) -> void:
	var idle := PackedInt32Array()
	for id in _idle(_sortie):
		if not _group("yuri").has(id):
			idle.append(id)
	if idle.is_empty():
		return
	for name in WORKSHOP_NAMES:
		var b: int = m.named.get(name, 0)
		if sim.economy.buildings.is_alive(b) and not sim.fire.is_burning(b):
			_cmd(SimCommand.ignite(sim.tick, P, idle, b))
			return


func _workshops_left(m: MissionRuntime) -> int:
	var n := 0
	for name in WORKSHOP_NAMES:
		var b: int = m.named.get(name, 0)
		if sim.economy.buildings.is_alive(b) and not sim.fire.is_burning(b):
			n += 1
	return n


func _inside(id: int) -> bool:
	return not sim.mission.siege.belt_of(sim.mission, id).is_empty()


func _all_out() -> bool:
	for id in _sortie:
		if _inside(id):
			return false
	return true


func _none_out() -> bool:
	for id in _sortie:
		if not _inside(id):
			return false
	return true


# --- the night ------------------------------------------------------------------------------


## The townsmen by the princess, the heroes by the court; the rest of the sortie comes back.
func _night(m: MissionRuntime) -> void:
	if _phase in [1, 2, 3]:
		_phase = 3
		_sortie = _alive(_sortie)
		_through(EXIT, true)
		if _none_out():
			_phase = 4
	if sim.tick % 200 != 0:
		return
	var townsmen := _idle(_group("burghers"))
	if not townsmen.is_empty() and not m.fired.has("9"):
		_go(townsmen, TOWNSMEN_NIGHT, 4)
	if _phase == 4 or _phase == 0:
		_go(_idle(_group("andrei")), COURT, 3)
		_go(_idle(_group("yuri")), COURT, 3)


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


func _go(ids: PackedInt32Array, at: Vector2i, within: int) -> void:
	var away := PackedInt32Array()
	for id in ids:
		if _dist_cells(id, at) > within:
			away.append(id)
	if not away.is_empty():
		_cmd(SimCommand.move(sim.tick, P, away, _fx(at.x), _fx(at.y)))


func _dist_cells(id: int, at: Vector2i) -> int:
	var dx := sim.entities.pos_x[id - 1] - _fx(at.x)
	var dy := sim.entities.pos_y[id - 1] - _fx(at.y)
	return Fixed.to_cells(Fixed.isqrt(dx * dx + dy * dy))


static func _fx(cell: int) -> int:
	return Fixed.from_cells(cell) + Fixed.HALF


func _cmd(c: SimCommand) -> void:
	sim.enqueue(c)
