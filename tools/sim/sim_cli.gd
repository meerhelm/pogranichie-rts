extends SceneTree
## Headless runner for the simulation, no window and no scenes:
##   godot --headless -s tools/sim/sim_cli.gd -- play tests/replays/m2_fuzz_1000.json
##   godot --headless -s tools/sim/sim_cli.gd -- record --seed 7 --ticks 1000 --out x.json
##   godot --headless -s tools/sim/sim_cli.gd -- determinism --runs 10 --ticks 1000
##   godot --headless -s tools/sim/sim_cli.gd -- bench --units 200 --ticks 600
##   godot --headless -s tools/sim/sim_cli.gd -- arena --seeds 50 --out arena.csv [--pairs a,b]
## record, determinism and bench take --map <map id> (see MapText); without it, open grass;
## and --economy 1 to have the fuzzer play the economy too (players, buildings, gathering).
## Exit code 0 on success, 1 on a hash mismatch or bad arguments.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var code := 1
	if args.is_empty():
		printerr("usage: sim_cli.gd -- play|record|determinism|bench|arena [options]")
	else:
		var opts := _options(args.slice(1))
		match args[0]:
			"play":
				code = _play(args.slice(1))
			"record":
				code = _record(opts)
			"determinism":
				code = _determinism(opts)
			"bench":
				code = _bench(opts)
			"arena":
				code = _arena(opts)
			_:
				printerr("unknown command: ", args[0])
	quit(code)


func _play(paths: PackedStringArray) -> int:
	var db := CatalogDB.load_prototype()
	var code := 0
	for path in paths:
		if path.begins_with("--"):
			continue
		var replay := Replay.load_file(path)
		if replay == null:
			code = 1
			continue
		var result := replay.play(db)
		if not result.message.is_empty():
			print("  note: ", result.message)
		if result.ok:
			print("OK   %s  %d ticks  %s" % [path, replay.ticks, result.final_hash.left(16)])
		else:
			code = 1
			print(
				(
					"FAIL %s  first mismatch at tick %d: expected %s, got %s"
					% [
						path,
						result.first_mismatch_tick,
						result.expected_hash.left(16),
						result.actual_hash.left(16)
					]
				)
			)
	return code


func _record(opts: Dictionary) -> int:
	var out: String = opts.get("out", "")
	if out.is_empty():
		printerr("record needs --out <path>")
		return 1
	var replay := _fuzz_replay(opts)
	var err := replay.save(out)
	if err != OK:
		printerr("cannot write %s: %s" % [out, error_string(err)])
		return 1
	print(
		(
			"recorded %s: %d ticks, %d commands, %s"
			% [out, replay.ticks, replay.commands.size(), replay.final_hash.left(16)]
		)
	)
	return 0


func _determinism(opts: Dictionary) -> int:
	var runs := int(opts.get("runs", "10"))
	var first := _fuzz_replay(opts)
	var db := CatalogDB.load_prototype()
	print("run 1: %s (%d commands)" % [first.final_hash.left(16), first.commands.size()])
	for i in range(1, runs):
		var again := _fuzz_replay(opts)
		var played := first.play(db)
		var same := again.checkpoints == first.checkpoints and played.ok
		print("run %d: %s %s" % [i + 1, again.final_hash.left(16), "same" if same else "DIFFERENT"])
		if not same:
			return 1
	return 0


func _bench(opts: Dictionary) -> int:
	var units := int(opts.get("units", "200"))
	var ticks := int(opts.get("ticks", "600"))
	var db := CatalogDB.load_prototype()
	var map_id: String = opts.get("map", "")
	var grid := MapText.load_map(map_id, db) if not map_id.is_empty() else null
	var sim := Simulation.new(int(opts.get("seed", "1")), db, 120, 120, grid)
	var types := _unit_types(db)
	CommandFuzzer.populate(sim, types, units, 99)
	var fuzz := CommandFuzzer.new(5, types)
	fuzz.command_permille = 1000
	fuzz.economy = opts.get("economy", "0") == "1"
	if fuzz.economy:
		fuzz.issue(sim)
	sim.step()
	var worst := 0
	var hash_usec := 0
	var start := Time.get_ticks_usec()
	for i in ticks:
		fuzz.issue(sim)
		var t0 := Time.get_ticks_usec()
		sim.step()
		worst = maxi(worst, Time.get_ticks_usec() - t0)
		var h0 := Time.get_ticks_usec()
		sim.state_hash()
		hash_usec += Time.get_ticks_usec() - h0
	var total := Time.get_ticks_usec() - start - hash_usec
	print(
		(
			(
				"bench: %d units, %d ticks: step avg %.3f ms, worst %.3f ms; "
				+ "state hash avg %.3f ms; %d path searches, %d cells expanded"
			)
			% [
				sim.entities.count(),
				ticks,
				total / 1000.0 / ticks,
				worst / 1000.0,
				hash_usec / 1000.0 / ticks,
				sim.pathfinder.searches,
				sim.pathfinder.total_expanded
			]
		)
	)
	return 0


## Balance arena (BalanceArena): one CSV row per pair, printed and written to --out.
func _arena(opts: Dictionary) -> int:
	var seeds := int(opts.get("seeds", "50"))
	var only := PackedStringArray()
	if opts.has("pairs"):
		only = str(opts["pairs"]).split(",")
	var arena := BalanceArena.new(CatalogDB.load_all())
	var lines := PackedStringArray([BalanceArena.CSV_HEADER])
	print(BalanceArena.CSV_HEADER)
	for pair: Array in BalanceArena.DEFAULT_PAIRS:
		if not only.is_empty() and not only.has(str(pair[0])):
			continue
		var row := arena.run_pair(pair, seeds)
		print(row)
		lines.append(row)
	var out: String = opts.get("out", "")
	if not out.is_empty():
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f == null:
			printerr("cannot write %s" % out)
			return 1
		f.store_string("\n".join(lines) + "\n")
	return 0


func _fuzz_replay(opts: Dictionary) -> Replay:
	var db := CatalogDB.load_prototype()
	var fuzz := CommandFuzzer.new(int(opts.get("fuzz-seed", "2")), _unit_types(db))
	fuzz.economy = opts.get("economy", "0") == "1"
	return Replay.record(
		int(opts.get("seed", "1")),
		db,
		int(opts.get("ticks", "1000")),
		fuzz.issue,
		int(opts.get("every", str(Replay.DEFAULT_CHECKPOINT_EVERY))),
		Simulation.DEFAULT_MAP_CELLS,
		Simulation.DEFAULT_MAP_CELLS,
		opts.get("map", "")
	)


static func _unit_types(db: CatalogDB) -> Array[StringName]:
	var types: Array[StringName] = []
	types.assign(db.units.keys())
	types.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return types


static func _options(args: PackedStringArray) -> Dictionary:
	var opts := {}
	var i := 0
	while i < args.size():
		if args[i].begins_with("--") and i + 1 < args.size():
			opts[args[i].substr(2)] = args[i + 1]
			i += 2
		else:
			i += 1
	return opts
