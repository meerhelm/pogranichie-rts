class_name GrunwaldBot
extends RefCounted
## A scripted player for «ВКЛ 2. Грюнвальд, 1410»: plays the field battle through to victory
## with plain player commands, so the recorded game (tests/replays/gdl02_playthrough.json)
## shows that the mission can be won and keeps every trigger on the way working:
##   godot --headless -s tools/sim/sim_cli.gd -- mission --mission gdl_02 \
##     --out tests/replays/gdl02_playthrough.json
## It sees the whole world and is not meant to play well, only to get through: wait out the
## cannonade, charge Wallenrode's wing, fall back to the forest with «Lithuanian retreat» when
## the khan leaves, ride out on the Grand Master's reserve and storm the wagenburg. Gintaut and
## the banner stay behind the army, and a rider is sent to the banner whenever it falls.

const THINK_EVERY := 20
const P := 1
const FOREST := Vector2i(138, 142)
## The Order's foot and bombards on the left wing: the knights beside them stand until they
## are touched, and the bot goes for the foot first.
const WING_FOOT := Vector2i(106, 62)
## The Smolensk banners at the joint of the wings.
const SMOLENSK := Vector2i(91, 114)
## Where Gintaut and the banner wait until the reserve comes out.
const LEADERS_AT := Vector2i(124, 122)
const WAGONS := Vector2i(65, 30)
## Where the army gathers before it storms the wagenburg all together.
const BEFORE_WAGONS := Vector2i(65, 46)
## Where the army waits for the reserve, on its way to the Poles.
const AMBUSH := Vector2i(60, 84)
## How far behind the army Gintaut and the banner keep.
const BEHIND := 8
const CASTERS: Array[StringName] = [&"gdl_znakharka"]

var sim: Simulation
var stage := "wait"
var _last_order := -100000
var _sent_retreat := false
var _formed := false


func _init(p_sim: Simulation) -> void:
	sim = p_sim


## Orders for the coming tick; call before each step.
func think() -> void:
	if sim.tick % THINK_EVERY != 0 or sim.mission.is_over():
		return
	var m := sim.mission
	if m.fired.has("11"):
		stage = "wagons"
	elif m.fired.has("9"):
		stage = "reserve"
	elif m.fired.has("4"):
		stage = "retreat"
	elif m.fired.has("3"):
		stage = "attack"
	_banner()
	match stage:
		"wait":
			_wait()
		"attack":
			_charge(WING_FOOT, 2)
		"retreat":
			_retreat()
		"reserve":
			_reserve()
		"wagons":
			if _formed_up():
				_storm()
	_leaders()
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
			"%02d:%02d %s last=%s army=%d foes=%d reserve=%d smolensk=%d/%d/%d bearer=%d"
			% [
				sim.tick / 1200,
				sim.tick / 20 % 60,
				stage,
				last,
				_soldiers().size(),
				foes,
				m.alive_of("reserve").size(),
				m.alive_of("smolensk_1").size(),
				m.alive_of("smolensk_2").size(),
				m.alive_of("smolensk_3").size(),
				m.bearer,
			]
		)
	)


# --- stages ---------------------------------------------------------------------------------


## Before the cannonade: stand where the mission put us (crossing the line only brings the
## volley sooner).
func _wait() -> void:
	pass


## Everyone fit to fight goes at the nearest enemy around `at`, again every few seconds for
## units that stand idle.
func _charge(at: Vector2i, every_s: int) -> void:
	if sim.tick - _last_order < every_s * 20:
		return
	_last_order = sim.tick
	var army := _soldiers()
	var idle := _idle(army)
	if idle.is_empty():
		return
	var target := _nearest_enemy(_centre(army), at, 16)
	if target != EntityStore.NO_ID:
		var tx := sim.entities.pos_x[target - 1]
		var ty := sim.entities.pos_y[target - 1]
		_cmd(SimCommand.attack_move(sim.tick, P, idle, tx, ty))
	else:
		_cmd(SimCommand.attack_move(sim.tick, P, idle, _fx(at.x), _fx(at.y)))


## The wagenburg: everyone goes for the men behind the wagons by name, the nearest one, and
## whoever is hacking at a wagon is sent on to them too (a wagon has 150 HP and the crossbows
## shoot meanwhile; the wagons need not fall for the mission).
func _storm() -> void:
	if sim.tick - _last_order < 2 * 20:
		return
	_last_order = sim.tick
	var army := _soldiers()
	var free := PackedInt32Array()
	for id in army:
		var t := sim.entities.target[id - 1]
		if t == EntityStore.NO_ID or sim.entities.type_ids[t - 1] == &"to_wagon":
			free.append(id)
	if free.is_empty():
		return
	var target := _nearest_enemy(_centre(free), WAGONS, 16)
	if target == EntityStore.NO_ID:
		_cmd(SimCommand.attack_move(sim.tick, P, free, _fx(WAGONS.x), _fx(WAGONS.y)))
	else:
		_cmd(SimCommand.attack(sim.tick, P, free, target))


## Before the wagenburg: the army gathers short of it, so it does not run onto the wagons one
## by one, then storms. True once it has gathered (or after a minute and a half).
func _formed_up() -> bool:
	if _formed:
		return true
	var army := _soldiers()
	var near := 0
	for id in army:
		if _dist_cells(id, BEFORE_WAGONS) <= 6:
			near += 1
	var waited: int = sim.tick - sim.mission.fired["11"]
	if near * 5 >= army.size() * 4 or waited > 90 * 20:
		_formed = true
		_last_order = -100000
		return true
	if sim.tick % 200 == 0:
		var away := PackedInt32Array()
		for id in army:
			if (
				_dist_cells(id, BEFORE_WAGONS) > 6
				and sim.entities.target[id - 1] == EntityStore.NO_ID
			):
				away.append(id)
		if not away.is_empty():
			_cmd(SimCommand.move(sim.tick, P, away, _fx(BEFORE_WAGONS.x), _fx(BEFORE_WAGONS.y)))
	return false


## The khan has gone: the light horse take «Lithuanian retreat», the rest ride for the forest.
## Once there, the army waits, turning on pursuers that come close.
func _retreat() -> void:
	if not _sent_retreat:
		_sent_retreat = true
		var riders := _of_type(&"gdl_light_horse")
		if not riders.is_empty():
			_cmd(SimCommand.order(sim.tick, P, SimCommand.Kind.RETREAT, riders))
		var rest := PackedInt32Array()
		for id in _soldiers():
			if sim.entities.type_ids[id - 1] != &"gdl_light_horse":
				rest.append(id)
		rest.append_array(_leaders_ids())
		_cmd(SimCommand.move(sim.tick, P, rest, _fx(FOREST.x), _fx(FOREST.y)))
		_last_order = sim.tick
		return
	if sim.tick - _last_order < 200:
		return
	_last_order = sim.tick
	# Once the khorugv is back at the forest and the pursuers are dealt with, help Smolensk.
	if sim.mission.fired.has("8") or (sim.mission.fired.has("7") and _pursuers_near() == 0):
		var help := _idle(_soldiers())
		var foe := _nearest_enemy(_centre(_soldiers()), SMOLENSK, 14)
		if not help.is_empty() and foe != EntityStore.NO_ID:
			var fx := sim.entities.pos_x[foe - 1]
			var fy := sim.entities.pos_y[foe - 1]
			_cmd(SimCommand.attack_move(sim.tick, P, help, fx, fy))
			return
	var away := PackedInt32Array()
	for id in _soldiers():
		if _dist_cells(id, FOREST) > 8 and sim.entities.orders[id - 1] == EntityStore.Order.IDLE:
			if sim.entities.target[id - 1] == EntityStore.NO_ID:
				away.append(id)
	if not away.is_empty():
		_cmd(SimCommand.move(sim.tick, P, away, _fx(FOREST.x), _fx(FOREST.y)))


## The reserve is out: strike it in the flank, units by units as they come.
func _reserve() -> void:
	if sim.tick - _last_order < 200:
		return
	_last_order = sim.tick
	var army := _soldiers()
	# The reserve moves on: everyone not already in a fight is sent at it again.
	var idle := PackedInt32Array()
	for id in army:
		if sim.entities.target[id - 1] == EntityStore.NO_ID:
			idle.append(id)
	if idle.is_empty():
		return
	var foes := sim.mission.alive_of("reserve")
	foes.append_array(sim.mission.alive_of("jungingen"))
	var best := EntityStore.NO_ID
	var best_d := 0
	var c := _centre(army)
	for id in foes:
		var d := _dist_sq(sim.entities.pos_x[id - 1] - c.x, sim.entities.pos_y[id - 1] - c.y)
		if best == EntityStore.NO_ID or d < best_d:
			best = id
			best_d = d
	if best == EntityStore.NO_ID:
		_cmd(SimCommand.attack_move(sim.tick, P, idle, _fx(AMBUSH.x), _fx(AMBUSH.y)))
		return
	var tx := sim.entities.pos_x[best - 1]
	var ty := sim.entities.pos_y[best - 1]
	_cmd(SimCommand.attack_move(sim.tick, P, idle, tx, ty))


## Order units within 16 cells of the forest.
func _pursuers_near() -> int:
	var n := 0
	var r := Fixed.from_cells(16)
	for id in sim.entities.alive_ids:
		var s := id - 1
		if sim.entities.owners[s] != 2:
			continue
		var dx := sim.entities.pos_x[s] - _fx(FOREST.x)
		var dy := sim.entities.pos_y[s] - _fx(FOREST.y)
		if dx * dx + dy * dy <= r * r:
			n += 1
	return n


# --- Gintaut and the banner -----------------------------------------------------------------


## Gintaut, the bearer and the znakharka keep BEHIND cells behind the army's centre, on the side
## away from the enemy; in the retreat they ride with it.
func _leaders() -> void:
	if stage == "retreat" or sim.tick % 100 != 0:
		return
	if stage != "wagons":
		var home := LEADERS_AT if stage == "attack" else FOREST
		var wait := _leaders_ids()
		if not wait.is_empty() and stage != "wait":
			_cmd(SimCommand.move(sim.tick, P, wait, _fx(home.x), _fx(home.y)))
		return
	var army := _soldiers()
	if army.is_empty():
		return
	var c := _centre(army)
	var back := Vector2i(FOREST.x, FOREST.y)
	var bx := Fixed.from_cells(back.x) - c.x
	var by := Fixed.from_cells(back.y) - c.y
	var len := maxi(Fixed.isqrt(bx * bx + by * by), 1)
	var px := c.x + bx * Fixed.from_cells(BEHIND) / len
	var py := c.y + by * Fixed.from_cells(BEHIND) / len
	var ids := _leaders_ids()
	if not ids.is_empty():
		_cmd(SimCommand.move(sim.tick, P, ids, px, py))


## A fallen banner: the nearest fit unit of ours rides to it.
func _banner() -> void:
	var m := sim.mission
	if m.banner_down < 0:
		return
	var best := EntityStore.NO_ID
	var best_d := 0
	for id in sim.entities.alive_ids:
		if sim.entities.owners[id - 1] != P or sim.combat.is_fleeing(id):
			continue
		var dx := sim.entities.pos_x[id - 1] - m.banner_x
		var d := _dist_sq(dx, sim.entities.pos_y[id - 1] - m.banner_y)
		if best == EntityStore.NO_ID or d < best_d:
			best = id
			best_d = d
	if best != EntityStore.NO_ID:
		_cmd(SimCommand.move(sim.tick, P, PackedInt32Array([best]), m.banner_x, m.banner_y))


func _leaders_ids() -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in sim.entities.alive_ids:
		if sim.entities.owners[id - 1] != P:
			continue
		var t := sim.entities.type_ids[id - 1]
		if t == &"hero_gintaut" or id == sim.mission.bearer or t in CASTERS:
			out.append(id)
	return out


# --- queries --------------------------------------------------------------------------------


## Fighting units: everyone of ours but Gintaut, the bearer and the casters, and not fleeing.
func _soldiers() -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in sim.entities.alive_ids:
		var s := id - 1
		if sim.entities.owners[s] != P or sim.combat.is_fleeing(id):
			continue
		var t := sim.entities.type_ids[s]
		if t == &"hero_gintaut" or id == sim.mission.bearer or t in CASTERS:
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


func _of_type(t: StringName) -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in _soldiers():
		if sim.entities.type_ids[id - 1] == t:
			out.append(id)
	return out


func _centre(ids: PackedInt32Array) -> Vector2i:
	if ids.is_empty():
		return Vector2i(_fx(FOREST.x), _fx(FOREST.y))
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
		if stage == "wagons" and sim.entities.type_ids[s] == &"to_wagon":
			continue  # the men behind the wagons, not the chained wagons
		if _dist_sq(sim.entities.pos_x[s] - ax, sim.entities.pos_y[s] - ay) > r * r:
			continue
		var d := _dist_sq(sim.entities.pos_x[s] - from.x, sim.entities.pos_y[s] - from.y)
		if best == EntityStore.NO_ID or d < best_d:
			best = id
			best_d = d
	return best


func _dist_cells(id: int, at: Vector2i) -> int:
	var dx := sim.entities.pos_x[id - 1] - _fx(at.x)
	var dy := sim.entities.pos_y[id - 1] - _fx(at.y)
	return Fixed.to_cells(Fixed.isqrt(dx * dx + dy * dy))


static func _dist_sq(dx: int, dy: int) -> int:
	return dx * dx + dy * dy


static func _fx(cell: int) -> int:
	return Fixed.from_cells(cell) + Fixed.HALF


func _cmd(c: SimCommand) -> void:
	sim.enqueue(c)
