extends SceneTree
## Late-game frame bench of the real skirmish scene at a high game speed: the AI plays both
## sides and the script feeds the SimClock as a 60 fps game loop would at --speed (the button's
## 1, 2, 4 or 8). Every game minute it prints the frame time, the speed the game really kept
## and where the time went: the ticks (sim, AIs, `ticked`), the once-a-frame view refresh
## (`advanced`) and the rest of the frame (_process and drawing).
##
##   godot --headless -s tools/sim/late_bench.gd -- --minutes 40 --speed 8

const FRAME_USEC := 16_667

var _main: Node
var _minutes := 40
var _speed := 8
var _clock: SimClock
var _started := false

var _last_frame := 0
var _frames := 0
var _frame_usec := 0
var _worst := 0
var _tick_usec := 0
var _view_usec := 0
var _ticks := 0
var _real_usec := 0
var _view_start := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		if args[i] == "--minutes":
			_minutes = int(args[i + 1])
		elif args[i] == "--speed":
			_speed = int(args[i + 1])
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 0
	Engine.max_fps = 0
	GameSettings.ensure_loaded()
	GameSettings.load_path = ""
	GameSettings.mission_id = ""
	_main = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	var sim: Simulation = _main.get(&"sim")
	if sim == null:
		return false
	if not _started:
		_start(sim)
		return false
	var now := Time.get_ticks_usec()
	if _last_frame > 0:
		# A frame done sooner waits for the 60 Hz display, as with vsync.
		var frame := maxi(now - _last_frame, FRAME_USEC)
		_frame_usec += frame
		_worst = maxi(_worst, frame)
		_frames += 1
		# The clock gets the real time of the last frame, as SimClock._process would.
		_clock.add_time_usec(frame * _speed * Hud.BASE_SPEED)
		_real_usec += frame
	_last_frame = now
	var before := sim.tick
	var t := Time.get_ticks_usec()
	_clock.advance_accumulated()
	var took := Time.get_ticks_usec() - t
	_tick_usec += took
	if took > 300_000:
		print(
			(
				"  slow frame: ticks %.0f ms (%d ticks) at tick %d"
				% [took / 1000.0, sim.tick - before, sim.tick]
			)
		)
	_ticks += sim.tick - before
	if sim.tick / 1200 != before / 1200:
		_report(sim)
	if sim.tick >= _minutes * 1200 or sim.victory.is_over():
		_report(sim)
		return true
	return false


func _start(sim: Simulation) -> void:
	_started = true
	_clock = _main.get_node("SimClock")
	_clock.set_process(false)
	var faction := SkirmishSetup.faction_of(
		1, [GameSettings.player_faction, GameSettings.enemy_faction]
	)
	var mine := SkirmishAi.new()
	mine.setup(sim, 1, SkirmishSetup.ai_profile(faction, &"normal"), 7)
	_main.add_child(mine)
	_clock.ticked.connect(func(_t: int) -> void: mine.issue())
	if not _clock.has_signal(&"advanced"):
		return
	# The views' refresh is timed apart from the ticks: first and last of the handlers.
	_clock.connect(&"advanced", _view_begin)
	var conns := _clock.get_signal_connection_list(&"advanced")
	for c: Dictionary in conns:
		var cb: Callable = c["callable"]
		if cb != Callable(self, &"_view_begin"):
			_clock.disconnect(&"advanced", cb)
			var label := "%s.%s" % [_owner_name(cb), cb.get_method()]
			_clock.connect(&"advanced", func(t: int, st: int) -> void: _timed(label, cb, t, st))
	_clock.connect(&"advanced", _view_end)


## Calls one view handler and notes a call slower than 100 ms.
func _timed(label: String, cb: Callable, t: int, st: int) -> void:
	var t0 := Time.get_ticks_usec()
	cb.call(t, st)
	var took := Time.get_ticks_usec() - t0
	if took > 100_000:
		print("  slow view %s: %.0f ms at tick %d" % [label, took / 1000.0, t])


static func _owner_name(cb: Callable) -> String:
	var o := cb.get_object()
	if o == null:
		return "?"
	var s: Script = o.get_script()
	return s.resource_path.get_file().get_basename() if s != null else o.get_class()


func _view_begin(_t: int, _s: int) -> void:
	_view_start = Time.get_ticks_usec()


func _view_end(_t: int, _s: int) -> void:
	_view_usec += Time.get_ticks_usec() - _view_start


func _report(sim: Simulation) -> void:
	var frames := maxi(_frames, 1)
	print(
		(
			(
				"min %2d units %3d bld %3d | fps %4.1f worst %5.1f ms | speed kept %.1fx of %dx"
				+ " | ticks %.1f ms/frame (views %.1f), rest %.1f ms/frame"
			)
			% [
				sim.tick / 1200,
				sim.entities.count(),
				sim.economy.buildings.count(),
				1_000_000.0 * frames / maxi(_frame_usec, 1),
				_worst / 1000.0,
				_ticks * float(Fixed.TICK_USEC) / maxi(_real_usec, 1) / Hud.BASE_SPEED,
				_speed,
				(_tick_usec - _view_usec) / 1000.0 / frames,
				_view_usec / 1000.0 / frames,
				(_frame_usec - _tick_usec) / 1000.0 / frames,
			]
		)
	)
	_frames = 0
	_frame_usec = 0
	_worst = 0
	_tick_usec = 0
	_view_usec = 0
	_ticks = 0
	_real_usec = 0
