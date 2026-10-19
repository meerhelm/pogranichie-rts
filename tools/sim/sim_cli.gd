extends SceneTree
## Headless runner for the simulation, no window and no scenes:
##   godot --headless -s tools/sim/sim_cli.gd -- play tests/replays/m2_fuzz_1000.json
##   godot --headless -s tools/sim/sim_cli.gd -- record --seed 7 --ticks 1000 --out x.json
##   godot --headless -s tools/sim/sim_cli.gd -- determinism --runs 10 --ticks 1000
##   godot --headless -s tools/sim/sim_cli.gd -- bench --units 200 --ticks 600
##   godot --headless -s tools/sim/sim_cli.gd -- arena --seeds 50 --out arena.csv [--pairs a,b]
##     [--parity 1]
##   godot --headless -s tools/sim/sim_cli.gd -- aivsai --games 20 --difficulty normal --out g.csv
##     [--factions gdl,to] (player 1's faction, then player 2's) [--map <skirmish map id>]
##   godot --headless -s tools/sim/sim_cli.gd -- mission --out m9.json
##     [--mission gdl_01|...|gdl_08] [--difficulty normal] [--ticks 90000]
##     [--every 200]
##     (MissionBot plays the campaign mission until it is over; fails unless it is won)
## record, determinism and bench take --map <map id> (see MapText); without it, open grass;
## and --economy 1 to have the fuzzer play the economy too (players, buildings, gathering);
## with it, --magic 1 adds shrines on places of power and spells.
## bench also takes --battle 1 (two armies meet instead of random orders) and --profile 1
## (milliseconds per system, on average and in the slowest tick).
## Exit code 0 on success, 1 on a hash mismatch or bad arguments.

## Armies of bench --battle 1.
const BATTLE_ARMIES: Array = [
	[&"gdl_spearman", &"gdl_forest_archer", &"gdl_light_horse", &"gdl_lit_lance"],
	[&"to_knecht", &"to_crossbow", &"to_halfbrother", &"to_knight_brother"],
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var code := 1
	if args.is_empty():
		printerr(
			"usage: sim_cli.gd -- play|record|determinism|bench|arena|aivsai|mission [options]"
		)
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
			"aivsai":
				code = _ai_vs_ai(opts)
			"mission":
				code = _mission(opts)
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
		if not replay.mission_id.is_empty():
			var outcome: String = MissionRuntime.Outcome.keys()[result.mission_outcome]
			print("  mission %s: %s" % [replay.mission_id, outcome])
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


## Records MissionBot playing a campaign mission through; the replay is written only if won.
func _mission(opts: Dictionary) -> int:
	var out: String = opts.get("out", "")
	if out.is_empty():
		printerr("mission needs --out <path>")
		return 1
	var db := CatalogDB.load_prototype()
	var mission_id: String = opts.get("mission", "gdl_01")
	# The bot is made on the first tick, once the recording has built the world.
	var bots: Array[RefCounted] = []
	var orders := func(sim: Simulation) -> void:
		if bots.is_empty():
			match mission_id:
				"gdl_02":
					bots.append(GrunwaldBot.new(sim))
				"gdl_03":
					bots.append(BaptismBot.new(sim))
				"gdl_04":
					bots.append(VilkomirBot.new(sim))
				"gdl_05":
					bots.append(VedroshaBot.new(sim))
				"gdl_06":
					bots.append(WolfTrailBot.new(sim))
				"gdl_07":
					bots.append(SlutskBot.new(sim))
				"gdl_08":
					bots.append(OrshaBot.new(sim))
				"crown_01":
					bots.append(CrownGrunwaldBot.new(sim))
				"crown_02":
					bots.append(MalborkBot.new(sim))
				"crown_03":
					bots.append(BalticBot.new(sim))
				"crown_04":
					bots.append(ChojniceBot.new(sim))
				"crown_05":
					bots.append(SilverBot.new(sim))
				"crown_06":
					bots.append(SwiecinoBot.new(sim))
				_:
					bots.append(MissionBot.new(sim))
		bots[0].call(&"think")
	var over := func(sim: Simulation) -> bool:
		if sim.mission.is_over() and OS.has_environment("BOT_LOG"):
			print("over at %d: %s" % [sim.tick, sim.mission.outcome_text])
		return sim.mission.is_over()
	var replay := Replay.record(
		int(opts.get("seed", "1")),
		db,
		int(opts.get("ticks", "90000")),
		orders,
		int(opts.get("every", "200")),
		0,
		0,
		"",
		mission_id,
		opts.get("difficulty", "normal"),
		over
	)
	var played := replay.play(db)
	if played.mission_outcome != MissionRuntime.Outcome.VICTORY:
		printerr("the bot did not win %s (stopped at tick %d)" % [mission_id, replay.ticks])
		return 1
	var err := replay.save(out)
	if err != OK:
		printerr("cannot write %s: %s" % [out, error_string(err)])
		return 1
	print(
		(
			"recorded %s: won at tick %d (%s), %d commands, %s"
			% [
				out,
				replay.ticks,
				UiText.clock(replay.ticks),
				replay.commands.size(),
				replay.final_hash.left(16)
			]
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
	var battle: bool = opts.get("battle", "0") == "1"
	if battle:
		_spawn_battle(sim, units)
	else:
		CommandFuzzer.populate(sim, types, units, 99)
	var fuzz := CommandFuzzer.new(5, types)
	fuzz.command_permille = 0 if battle else 1000
	fuzz.economy = opts.get("economy", "0") == "1"
	fuzz.magic = opts.get("magic", "0") == "1"
	if fuzz.economy:
		fuzz.issue(sim)
	sim.step()
	if battle:
		_charge_battle(sim)
	var worst := 0
	var hash_usec := 0
	var start := Time.get_ticks_usec()
	var times := {}
	var worst_parts := {}
	var profile: bool = opts.get("profile", "0") == "1"
	for i in ticks:
		if not battle:
			fuzz.issue(sim)
		var t0 := Time.get_ticks_usec()
		if profile:
			var one := {}
			sim.step_profiled(one)
			for key: String in one:
				times[key] = int(times.get(key, 0)) + int(one[key])
			if Time.get_ticks_usec() - t0 > worst:
				worst_parts = one
		else:
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
	for key: String in times:
		print(
			(
				"  %-18s %.3f ms/tick, %.3f ms in the worst tick"
				% [key, int(times[key]) / 1000.0 / ticks, int(worst_parts.get(key, 0)) / 1000.0]
			)
		)
	return 0


## bench --battle 1: two armies of units/2 each (GDL west, Order east) in the middle of the
## map, which then attack-move into each other in groups of 25.
static func _spawn_battle(sim: Simulation, units: int) -> void:
	var cx := Fixed.to_cells(sim.map_width) / 2
	var cy := Fixed.to_cells(sim.map_height) / 2
	for side in 2:
		var kinds: Array = BATTLE_ARMIES[side]
		var x0 := cx - 22 if side == 0 else cx + 12
		for i in units / 2:
			var unit: StringName = kinds[i % kinds.size()]
			var x := Fixed.from_cells(x0 + i % 10) + Fixed.HALF
			var y := Fixed.from_cells(cy - 10 + i / 10) + Fixed.HALF
			sim.enqueue(SimCommand.spawn(sim.tick, side + 1, unit, x, y))


static func _charge_battle(sim: Simulation) -> void:
	var sides: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
	for id in sim.entities.alive_ids:
		sides[sim.entities.owners[id - 1] - 1].append(id)
	for side in 2:
		var ids := sides[side]
		var target_x := (
			sim.map_width / 2 + (Fixed.from_cells(8) if side == 0 else -Fixed.from_cells(8))
		)
		for start in range(0, ids.size(), 25):
			var group := ids.slice(start, start + 25)
			sim.enqueue(
				SimCommand.attack_move(sim.tick, side + 1, group, target_x, sim.map_height / 2)
			)


## Balance arena (BalanceArena): one CSV row per pair, printed and written to --out; with
## --parity 1 the row is the count of B that holds A's budget army to an even fight.
func _arena(opts: Dictionary) -> int:
	var seeds := int(opts.get("seeds", "50"))
	var only := PackedStringArray()
	if opts.has("pairs"):
		only = str(opts["pairs"]).split(",")
	var parity: bool = opts.get("parity", "0") == "1"
	var arena := BalanceArena.new(CatalogDB.load_all())
	var header := BalanceArena.PARITY_HEADER if parity else BalanceArena.CSV_HEADER
	var lines := PackedStringArray([header])
	print(header)
	for pair: Array in BalanceArena.DEFAULT_PAIRS:
		if not only.is_empty() and not only.has(str(pair[0])):
			continue
		var row := arena.parity_row(pair, seeds) if parity else arena.run_pair(pair, seeds)
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


## «ИИ против ИИ» (AiMatch): --games games from --seed on, one CSV row each; fails if a game
## times out. Split a long run across processes with different --seed and --games.
func _ai_vs_ai(opts: Dictionary) -> int:
	var games := int(opts.get("games", "20"))
	var first := int(opts.get("seed", "1"))
	var difficulty := StringName(opts.get("difficulty", "normal"))
	var match_runner := AiMatch.new(CatalogDB.load_prototype())
	var sides: PackedStringArray = String(opts.get("factions", "gdl,to")).split(",")
	if sides.size() != 2:
		printerr("--factions takes two factions, such as pl,to")
		return 1
	match_runner.factions = [StringName(sides[0]), StringName(sides[1])]
	match_runner.map_id = opts.get("map", SkirmishSetup.MAP_ID)
	if not SkirmishMaps.has(match_runner.map_id):
		printerr("--map takes a skirmish map: ", ", ".join(SkirmishMaps.ids()))
		return 1
	var lines := PackedStringArray([AiMatch.CSV_HEADER])
	print(AiMatch.CSV_HEADER)
	var code := 0
	for i in games:
		var game := match_runner.play(first + i, difficulty, int(opts.get("ticks", "72000")))
		var line := match_runner.row(i + 1, first + i, difficulty, game)
		print(line)
		lines.append(line)
		if game.winner == 0:
			code = 1
	var out: String = opts.get("out", "")
	if not out.is_empty():
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f == null:
			printerr("cannot write %s" % out)
			return 1
		f.store_string("\n".join(lines) + "\n")
	return code


func _fuzz_replay(opts: Dictionary) -> Replay:
	var db := CatalogDB.load_prototype()
	var fuzz := CommandFuzzer.new(int(opts.get("fuzz-seed", "2")), _unit_types(db))
	fuzz.economy = opts.get("economy", "0") == "1"
	fuzz.magic = opts.get("magic", "0") == "1"
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
