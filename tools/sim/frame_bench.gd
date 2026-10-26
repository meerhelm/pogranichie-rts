extends SceneTree
## Frame-time benchmark of the real skirmish scene (plan M10: 200 units at 60 fps): two armies
## of units/2 each meet near the player's base in view of the camera, and the script measures
## every frame for --seconds of game time. Headless it shows what the scripts and the
## simulation cost per frame; in a window (no --headless) it is the real frame rate.
##
##   godot -s tools/sim/frame_bench.gd -- --units 200 --seconds 30
##   godot --headless -s tools/sim/frame_bench.gd -- --units 200 --seconds 30

const ARMIES: Array = [
	[&"gdl_spearman", &"gdl_forest_archer", &"gdl_light_horse", &"gdl_lit_lance"],
	[&"to_knecht", &"to_crossbow", &"to_halfbrother", &"to_knight_brother"],
]

var _main: Node
var _units := 200
var _seconds := 30
var _frames := PackedInt64Array()

var _last := 0
var _started := false
var _start_usec := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		if args[i] == "--units":
			_units = int(args[i + 1])
		elif args[i] == "--seconds":
			_seconds = int(args[i + 1])
	# Headless Godot sleeps about 7 ms a frame (low-processor mode): measure the work instead.
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 0
	Engine.max_fps = 0
	GameSettings.ensure_loaded()
	GameSettings.load_path = ""
	GameSettings.mission_id = ""
	_main = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	var sim: Simulation = _main.get(&"sim")
	if sim == null:
		return false
	if not _started:
		_started = true
		_spawn(sim)
		_start_usec = now
	elif _last > 0:
		_frames.append(now - _last)
		if now - _last > 16_667:
			print("  slow frame at tick %d: %.1f ms" % [sim.tick, (now - _last) / 1000.0])
	_last = now
	if now - _start_usec >= _seconds * 1_000_000:
		_report(sim)
		return true
	return false


func _spawn(sim: Simulation) -> void:
	var home := SkirmishMaps.base(SkirmishSetup.MAP_ID, 0) + Vector2i(2, 4)
	for side in 2:
		var kinds: Array = ARMIES[side]
		var x0 := home.x - 14 if side == 0 else home.x + 6
		for i in _units / 2:
			var x := Fixed.from_cells(clampi(x0 + i % 8, 1, sim.nav.width - 2)) + Fixed.HALF
			var y := (
				Fixed.from_cells(clampi(home.y - 6 + i / 8, 1, sim.nav.height - 2)) + Fixed.HALF
			)
			sim.apply_now(SimCommand.spawn(sim.tick, side + 1, kinds[i % kinds.size()], x, y))
	var sides: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
	var kinds_all: Array = ARMIES[0] + ARMIES[1]
	for id in sim.entities.alive_ids:
		if kinds_all.has(sim.entities.type_ids[id - 1]):
			sides[sim.entities.owners[id - 1] - 1].append(id)
	for side in 2:
		var to := Fixed.from_cells(home.x - 4 if side == 1 else home.x)
		sim.apply_now(
			SimCommand.attack_move(sim.tick, side + 1, sides[side], to, Fixed.from_cells(home.y))
		)


func _report(sim: Simulation) -> void:
	print(
		(
			"frame bench: %d frames, %d units at the end, %s"
			% [_frames.size(), sim.entities.count(), _stats(_frames)]
		)
	)


static func _stats(values: PackedInt64Array) -> String:
	if values.is_empty():
		return "no frames"
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0
	var over := 0
	for v in values:
		total += v
		if v > 16_667:
			over += 1
	var n := values.size()
	return (
		"avg %.2f ms (%.0f fps), p99 %.2f ms, worst %.2f ms, %d over 16.7 ms"
		% [
			total / 1000.0 / n,
			1_000_000.0 * n / maxi(total, 1),
			sorted[mini(n * 99 / 100, n - 1)] / 1000.0,
			sorted[-1] / 1000.0,
			over,
		]
	)
