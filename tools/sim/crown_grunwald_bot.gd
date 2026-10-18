class_name CrownGrunwaldBot
extends RefCounted
## A scripted player for «Корона 1. Грюнвальд, 1410»: plays the field battle through to victory
## with plain player commands, so the recorded game (tests/replays/crown01_playthrough.json)
## shows that the mission can be won and keeps every trigger on the way working:
##   godot --headless -s tools/sim/sim_cli.gd -- mission --mission crown_01 \
##     --out tests/replays/crown01_playthrough.json
## It sees the whole world and is not meant to play well, only to get through: wait in the
## grove until the order, meet the Order's right wing, ride Jaśko to the fallen banner, use «The
## Pact» against the Grand Master's reserve by the king's hill and storm the wagenburg. Jaśko
## and the priest stay behind the army.

const THINK_EVERY := 20
const P := 1
const GROVE := Vector2i(30, 119)
## Where Jaśko and the priest wait while the wing fights: south of the grove.
const BACK := Vector2i(40, 131)
const WING := Vector2i(30, 80)
const HILL := Vector2i(72, 134)
const WAGONS := Vector2i(65, 30)
## How far behind the army Jaśko keeps.
const BEHIND := 10
## Where Jaśko keeps from while the reserve is fought: behind the king's hill.
const BEHIND_HILL := Vector2i(82, 148)

var sim: Simulation
var stage := "wait"
var _last_order := -100000
var _pact_cast := false


func _init(p_sim: Simulation) -> void:
	sim = p_sim


## Orders for the coming tick; call before each step.
func think() -> void:
	if sim.tick % THINK_EVERY != 0 or sim.mission.is_over():
		return
	var m := sim.mission
	if m.fired.has("10"):
		stage = "wagons"
	elif m.fired.has("7"):
		stage = "reserve"
	elif m.fired.has("5") and not m.fired.has("6"):
		stage = "banner"
	elif m.fired.has("3"):
		stage = "wing"
	match stage:
		"wait":
			pass
		"wing":
			_charge(WING, 24, 3)
			_wait_back()
		"banner":
			_to_banner()
		"reserve":
			_reserve()
		"wagons":
			_charge(WAGONS, 20, 2)
			_jasko_behind(BEHIND_HILL)
	if sim.tick % 1200 == 0 and OS.has_environment("BOT_LOG"):
		_log()


func _log() -> void:
	var m := sim.mission
	var last := ""
	var at := -1
	for tid: String in m.fired:
		if m.fired[tid] >= at:
			at = m.fired[tid]
			last = tid
	var foes := 0
	for id in sim.entities.alive_ids:
		if sim.entities.owners[id - 1] == 2:
			foes += 1
	print(
		(
			"%02d:%02d %s last=%s army=%d foes=%d reserve=%d heat=%d king=%d captives=%d"
			% [
				sim.tick / 1200,
				sim.tick / 20 % 60,
				stage,
				last,
				_soldiers().size(),
				foes,
				m.alive_of("reserve").size(),
				m.field.player_heat(m),
				m.alive_of("jagiello").size(),
				m.field.captured,
			]
		)
	)


# --- stages ---------------------------------------------------------------------------------


## Idle fighters go at the Order's unit nearest the army within `radius` cells of `at`, or to
## `at` when there is none.
func _charge(at: Vector2i, radius: int, every_s: int) -> void:
	if sim.tick - _last_order < every_s * 20:
		return
	_last_order = sim.tick
	var army := _soldiers()
	var idle := _idle(army)
	if idle.is_empty():
		return
	var target := _nearest_enemy(_centre(army), at, radius)
	if target != EntityStore.NO_ID:
		var tx := sim.entities.pos_x[target - 1]
		var ty := sim.entities.pos_y[target - 1]
		_cmd(SimCommand.attack_move(sim.tick, P, idle, tx, ty))
	else:
		_cmd(SimCommand.attack_move(sim.tick, P, idle, _fx(at.x), _fx(at.y)))


## The banner is down: Jaśko rides to it with the nearest lances.
func _to_banner() -> void:
	if sim.tick - _last_order < 40:
		return
	_last_order = sim.tick
	var f := sim.mission.field
	var jasko := _of_type(&"hero_jasko", true)
	if not jasko.is_empty():
		_cmd(SimCommand.move(sim.tick, P, jasko, f.banner_x, f.banner_y))
	var escort := _of_type(&"pl_kopia", false)
	if not escort.is_empty():
		_cmd(SimCommand.attack_move(sim.tick, P, escort, f.banner_x, f.banner_y))


## The reserve is out: the army goes to the king's hill and strikes the reserve there; Jaśko
## calls «The Pact» once the reserve is in the fight.
func _reserve() -> void:
	_jasko_behind(BEHIND_HILL)
	if sim.tick - _last_order < 100:
		return
	_last_order = sim.tick
	var army := _soldiers()
	var idle := PackedInt32Array()
	for id in army:
		if sim.entities.target[id - 1] == EntityStore.NO_ID:
			idle.append(id)
	var foes := sim.mission.alive_of("reserve")
	var best := EntityStore.NO_ID
	var best_d := 0
	var hill := Vector2i(_fx(HILL.x), _fx(HILL.y))
	for id in foes:
		var d := _dist_sq(sim.entities.pos_x[id - 1] - hill.x, sim.entities.pos_y[id - 1] - hill.y)
		if best == EntityStore.NO_ID or d < best_d:
			best = id
			best_d = d
	if not _pact_cast and best != EntityStore.NO_ID and best_d < Fixed.from_cells(14) ** 2:
		var jasko := _of_type(&"hero_jasko", true)
		if not jasko.is_empty():
			var jx := sim.entities.pos_x[jasko[0] - 1]
			var jy := sim.entities.pos_y[jasko[0] - 1]
			_cmd(SimCommand.cast(sim.tick, P, jasko, &"sp_pact", jx, jy))
			_pact_cast = true
	if idle.is_empty():
		return
	if best == EntityStore.NO_ID or best_d > Fixed.from_cells(40) ** 2:
		_cmd(SimCommand.attack_move(sim.tick, P, idle, hill.x, hill.y))
		return
	var tx := sim.entities.pos_x[best - 1]
	var ty := sim.entities.pos_y[best - 1]
	_cmd(SimCommand.attack_move(sim.tick, P, idle, tx, ty))


func _wait_back() -> void:
	if sim.tick % 100 != 0:
		return
	var ids := _of_type(&"hero_jasko", true)
	ids.append_array(_of_type(&"pl_priest", true))
	if not ids.is_empty():
		_cmd(SimCommand.move(sim.tick, P, ids, _fx(BACK.x), _fx(BACK.y)))


## Jaśko and the priest keep BEHIND cells behind the army, towards `home`.
func _jasko_behind(home: Vector2i) -> void:
	if sim.tick % 100 != 0:
		return
	var ids := _of_type(&"hero_jasko", true)
	ids.append_array(_of_type(&"pl_priest", true))
	if ids.is_empty():
		return
	var army := _soldiers()
	var c := _centre(army)
	var bx := _fx(home.x) - c.x
	var by := _fx(home.y) - c.y
	var len := maxi(Fixed.isqrt(bx * bx + by * by), 1)
	var px := c.x + bx * Fixed.from_cells(BEHIND) / len
	var py := c.y + by * Fixed.from_cells(BEHIND) / len
	if len < Fixed.from_cells(BEHIND):
		px = _fx(home.x)
		py = _fx(home.y)
	_cmd(SimCommand.move(sim.tick, P, ids, px, py))


# --- queries --------------------------------------------------------------------------------


## Fighting units: everyone of ours but Jaśko and the priest, and not fleeing.
func _soldiers() -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in sim.entities.alive_ids:
		var s := id - 1
		if sim.entities.owners[s] != P or sim.combat.is_fleeing(id):
			continue
		var t := sim.entities.type_ids[s]
		if t == &"hero_jasko" or t == &"pl_priest":
			continue
		out.append(id)
	return out


func _idle(ids: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in ids:
		var s := id - 1
		if sim.entities.orders[s] == EntityStore.Order.IDLE and sim.entities.target[s] == 0:
			out.append(id)
	return out


## The player's units of that type (fleeing ones too if `all`).
func _of_type(t: StringName, all: bool) -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in sim.entities.alive_ids:
		var s := id - 1
		if sim.entities.owners[s] != P or sim.entities.type_ids[s] != t:
			continue
		if all or not sim.combat.is_fleeing(id):
			out.append(id)
	return out


func _centre(ids: PackedInt32Array) -> Vector2i:
	if ids.is_empty():
		return Vector2i(_fx(GROVE.x), _fx(GROVE.y))
	var x := 0
	var y := 0
	for id in ids:
		x += sim.entities.pos_x[id - 1]
		y += sim.entities.pos_y[id - 1]
	return Vector2i(x / ids.size(), y / ids.size())


## The Order's unit nearest to `from` (fixed point) within `radius` cells of `at`.
func _nearest_enemy(from: Vector2i, at: Vector2i, radius: int) -> int:
	var best := EntityStore.NO_ID
	var best_d := 0
	var r := Fixed.from_cells(radius)
	var ax := _fx(at.x)
	var ay := _fx(at.y)
	for id in sim.entities.alive_ids:
		var s := id - 1
		if sim.entities.owners[s] != 2 or sim.combat.untouchable.has(id):
			continue
		if _dist_sq(sim.entities.pos_x[s] - ax, sim.entities.pos_y[s] - ay) > r * r:
			continue
		var d := _dist_sq(sim.entities.pos_x[s] - from.x, sim.entities.pos_y[s] - from.y)
		if best == EntityStore.NO_ID or d < best_d:
			best = id
			best_d = d
	return best


static func _dist_sq(dx: int, dy: int) -> int:
	return dx * dx + dy * dy


static func _fx(cell: int) -> int:
	return Fixed.from_cells(cell) + Fixed.HALF


func _cmd(c: SimCommand) -> void:
	sim.enqueue(c)
