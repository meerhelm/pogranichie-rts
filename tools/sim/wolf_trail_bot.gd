class_name WolfTrailBot
extends RefCounted
## A scripted player for «ВКЛ 6. Волчья тропа, 1507»: plays the mission through to its end with
## plain player commands, so the recorded game (tests/replays/gdl06_playthrough.json) shows the
## escape can be made and keeps every trigger on the way working:
##   godot --headless -s tools/sim/sim_cli.gd -- mission --mission gdl_06 \
##     --out tests/replays/gdl06_playthrough.json
## It sees the whole world and is not meant to play well, only to get through. The band leads
## its horses at a walk all the way: out of the camp past the chapel to the old pine, over the
## zaseka by the pine's trail, into the northern forest to sit out the day; at sunset south
## through the forest to the boulder in the stream, along its trail to the gať, behind the old
## woman over the bog and on to the ford, where Andrei's men clear the post and meet the chase.

const THINK_EVERY := 20
const P := 1
## The band's way, leg by leg: where it walks and what it waits for before the next leg.
## Wait kinds: "" (arrive), "found_N" / "trail_N" (flags), "sunset" / "6" / "7" (triggers),
## "clear" (arrive, then wait until no patrol is near the road ahead), "clear_road" (arrive on
## the second trail, then wait until the road patrol is away from its end), "ford" (wait until
## Andrei's men have cut down the post at the ford).
const LEGS: Array = [
	[Vector2i(124, 57), ""],
	[Vector2i(128, 41), ""],
	[Vector2i(119, 33), "found_0"],
	[Vector2i(117, 31), "cast"],
	[Vector2i(113, 26), "trail_0"],
	[Vector2i(99, 26), ""],
	[Vector2i(93, 11), "sunset"],
	[Vector2i(75, 17), ""],
	[Vector2i(70, 40), "clear"],
	[Vector2i(70, 50), ""],
	[Vector2i(76, 51), ""],
	[Vector2i(77, 57), "found_1"],
	[Vector2i(77, 61), "cast"],
	[Vector2i(67, 60), "trail_1"],
	[Vector2i(67, 60), "clear_road"],
	[Vector2i(62, 61), ""],
	[Vector2i(59, 60), "6"],
	[Vector2i(46, 47), ""],
	[Vector2i(29, 47), "7"],
	[Vector2i(27, 47), "ford"],
	[Vector2i(8, 45), ""],
]
const ANDREI_TO := Vector2i(21, 44)

var sim: Simulation
var _leg := 0
var _led := false
var _cast_at := -1
var _alarms := 0
var _armed := false


func _init(p_sim: Simulation) -> void:
	sim = p_sim


## Orders for the coming tick; call before each step.
func think() -> void:
	if sim.tick % THINK_EVERY != 0 or sim.mission.is_over():
		return
	var band := sim.mission.stealth.fugitives(sim.mission)
	if band.is_empty():
		return
	if not _led:
		_led = true
		_cmd(SimCommand.order(sim.tick, P, SimCommand.Kind.DISMOUNT, band))
	_walk(band)
	_andrei()
	var alarms := sim.mission.stealth.alarms
	if OS.has_environment("BOT_LOG") and (sim.tick % 1200 == 0 or alarms != _alarms):
		_log(band)
	_alarms = alarms


func _log(band: PackedInt32Array) -> void:
	var m := sim.mission
	var last := ""
	var at := -1
	for tid: String in m.fired:
		if m.fired[tid] >= at:
			at = m.fired[tid]
			last = tid
	var prince := m.alive_of("prince")
	var where := Vector2i(-1, -1)
	if not prince.is_empty():
		where = _cell(prince[0])
	print(
		(
			"%02d:%02d leg=%d last=%s prince=%s band=%d meter=%d alarms=%d at=%s night=%s chase=%d"
			% [
				sim.tick / 1200,
				sim.tick / 20 % 60,
				_leg,
				last,
				where,
				band.size(),
				m.stealth.meter,
				m.stealth.alarms,
				Vector2i(Fixed.to_cells(m.stealth.last_x), Fixed.to_cells(m.stealth.last_y)),
				m.stealth.night,
				m.stealth.pursuit_at,
			]
		)
	)


func _walk(band: PackedInt32Array) -> void:
	if _leg >= LEGS.size():
		return
	var to: Vector2i = LEGS[_leg][0]
	var wait: String = LEGS[_leg][1]
	var prince := sim.mission.alive_of("prince")
	if prince.is_empty():
		return
	if wait == "cast":
		_cast(prince[0], band, to)
		return
	var arrive := wait == "" or wait.begins_with("clear")
	if _ready(wait) and (not arrive or _dist_cells(prince[0], to) <= 2):
		_leg += 1
		return
	var away := PackedInt32Array()
	for id in band:
		if _dist_cells(id, to) > 2 and not _going_to(id, to):
			away.append(id)
	if not away.is_empty():
		_cmd(SimCommand.move(sim.tick, P, away, _fx(to.x), _fx(to.y)))


## The prince walks onto the place and casts «Волчья тропа» there; the others wait by him.
func _cast(prince: int, band: PackedInt32Array, at: Vector2i) -> void:
	if _dist_cells(prince, at) > 1:
		if not _going_to(prince, at):
			_cmd(SimCommand.move(sim.tick, P, PackedInt32Array([prince]), _fx(at.x), _fx(at.y)))
		return
	if _cast_at < 0 or sim.tick - _cast_at > 200:
		_cast_at = sim.tick
		var x := sim.entities.pos_x[prince - 1]
		var y := sim.entities.pos_y[prince - 1]
		var ids := PackedInt32Array([prince])
		_cmd(SimCommand.cast(sim.tick, P, ids, &"sp_wolf_path", x, y))
	var next: String = LEGS[_leg + 1][1]
	if sim.mission.flags.has(next):
		_cast_at = -1
		_leg += 1
	var rest := PackedInt32Array()
	for id in band:
		if id != prince and _dist_cells(id, at) > 3 and not _going_to(id, at):
			rest.append(id)
	if not rest.is_empty():
		_cmd(SimCommand.move(sim.tick, P, rest, _fx(at.x), _fx(at.y)))


func _ready(wait: String) -> bool:
	var m := sim.mission
	if wait == "":
		return true
	if wait == "ford":
		return m.alive_of("post_ford").is_empty()
	if wait == "clear":
		return _clear(Vector2i(70, 46), 14)
	if wait == "clear_road":
		return _clear(Vector2i(60, 60), 12)
	if wait.begins_with("found_") or wait.begins_with("trail_"):
		return m.flags.has(wait)
	return m.fired.has(wait)


## Once Andrei's men are on the bank, they cross and clear the ford for the prince.
func _andrei() -> void:
	var m := sim.mission
	if not m.fired.has("7"):
		return
	if not _armed:
		# The hiding is over: the band defends itself from now on.
		_armed = true
		var band := m.stealth.fugitives(m)
		_cmd(SimCommand.set_stance(sim.tick, P, band, EntityStore.Stance.DEFENSIVE))
	var ids := PackedInt32Array()
	for g: String in ["andrei", "lances", "riders", "archers"]:
		for id in m.alive_of(g):
			if sim.entities.orders[id - 1] == EntityStore.Order.IDLE:
				ids.append(id)
	if ids.is_empty() or sim.tick % 200 != 0:
		return
	_cmd(SimCommand.attack_move(sim.tick, P, ids, _fx(ANDREI_TO.x), _fx(ANDREI_TO.y)))


## Whether no watcher of the patrols stands within `radius` cells of `at`.
func _clear(at: Vector2i, radius: int) -> bool:
	for g: String in ["patrol_zaseka", "patrol_road"]:
		for id in sim.mission.alive_of(g):
			if _dist_cells(id, at) <= radius:
				return false
	return true


# --- queries --------------------------------------------------------------------------------


func _going_to(id: int, at: Vector2i) -> bool:
	var s := id - 1
	if sim.entities.orders[s] == EntityStore.Order.IDLE:
		return false
	return (
		Fixed.to_cells(sim.entities.target_x[s]) == at.x
		and Fixed.to_cells(sim.entities.target_y[s]) == at.y
	)


func _cell(id: int) -> Vector2i:
	return Vector2i(
		Fixed.to_cells(sim.entities.pos_x[id - 1]), Fixed.to_cells(sim.entities.pos_y[id - 1])
	)


func _dist_cells(id: int, at: Vector2i) -> int:
	var dx := sim.entities.pos_x[id - 1] - _fx(at.x)
	var dy := sim.entities.pos_y[id - 1] - _fx(at.y)
	return Fixed.to_cells(Fixed.isqrt(dx * dx + dy * dy))


static func _fx(cell: int) -> int:
	return Fixed.from_cells(cell) + Fixed.HALF


func _cmd(c: SimCommand) -> void:
	sim.enqueue(c)
