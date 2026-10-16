extends GutTest
## M2 acceptance: the same seed and commands give the same state hash every time, and
## recorded replays play back to the same hashes (on every OS CI runs on). A campaign mission's
## replay (M9) must also end in victory.

const REPLAY_DIR := "res://tests/replays"
const RUNS := 10
const TICKS := 1000

var _db: CatalogDB
var _types: Array[StringName] = []


func before_all() -> void:
	_db = CatalogDB.load_prototype()
	_types.assign(_db.units.keys())
	_types.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))


func _fuzzed(seed_value: int, fuzz_seed: int) -> Replay:
	var fuzz := CommandFuzzer.new(fuzz_seed, _types)
	return Replay.record(seed_value, _db, TICKS, fuzz.issue)


func test_ten_runs_of_1000_random_ticks_match() -> void:
	var first := _fuzzed(11, 23)
	assert_gt(first.commands.size(), 200, "the fuzzer should give the sim real work")
	for i in RUNS - 1:
		var again := _fuzzed(11, 23)
		assert_eq(again.checkpoints, first.checkpoints, "run %d checkpoints" % (i + 2))
		assert_eq(again.final_hash, first.final_hash, "run %d final hash" % (i + 2))


func test_replay_survives_save_and_load() -> void:
	var recorded := _fuzzed(5, 6)
	var path := "user://test_replay_round_trip.json"
	assert_eq(recorded.save(path), OK)
	var loaded := Replay.load_file(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_eq(loaded.to_dict(), recorded.to_dict())
	var result := loaded.play(_db)
	assert_true(result.ok, "first mismatch at tick %d" % result.first_mismatch_tick)
	assert_eq(result.final_hash, recorded.final_hash)


func test_playback_reports_the_first_diverging_checkpoint() -> void:
	var replay := _fuzzed(5, 6)
	# Move one spawn a few cells: a spawn always takes effect, unlike orders to dead units.
	var spawns := replay.commands.filter(
		func(c: SimCommand) -> bool: return c.kind == SimCommand.Kind.SPAWN and c.tick > 300
	)
	var changed: SimCommand = spawns[0]
	var shift := Fixed.from_cells(5)
	changed.x = changed.x - shift if changed.x > Fixed.from_cells(60) else changed.x + shift
	var result := replay.play(_db)
	assert_false(result.ok)
	var every := replay.checkpoint_every
	assert_eq(result.first_mismatch_tick, (changed.tick / every + 1) * every)


func test_different_seeds_diverge() -> void:
	assert_ne(_fuzzed(1, 2).final_hash, _fuzzed(1, 3).final_hash)


## Recorded once and committed; a mismatch here on any OS means the sim is not deterministic
## or its rules changed. Re-record only in a separate commit that says why the result changed.
func test_recorded_replays_play_back() -> void:
	var files := DirAccess.get_files_at(REPLAY_DIR)
	var played := 0
	for file in files:
		if not file.ends_with(".json"):
			continue
		var replay := Replay.load_file(REPLAY_DIR.path_join(file))
		assert_not_null(replay, file)
		if replay == null:
			continue
		assert_eq(replay.data_version, _db.content_hash(), "%s: catalog data changed" % file)
		var result := replay.play(_db)
		assert_true(
			result.ok,
			(
				"%s: first mismatch at tick %d, expected %s, got %s"
				% [file, result.first_mismatch_tick, result.expected_hash, result.actual_hash]
			)
		)
		if not replay.mission_id.is_empty():
			var won := MissionRuntime.Outcome.VICTORY
			assert_eq(result.mission_outcome, won, "%s: the mission is won" % file)
		played += 1
	assert_gt(played, 0, "no replays in %s" % REPLAY_DIR)
