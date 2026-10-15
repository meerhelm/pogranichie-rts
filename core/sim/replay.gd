class_name Replay
extends RefCounted
## A recorded game: seed, data and rules versions, map size, the command list and state
## hashes at checkpoints. Playing it back must reproduce every checkpoint hash exactly.
## Stored as JSON (see save()/load_file()).

const FORMAT := 1
const DEFAULT_CHECKPOINT_EVERY := 10

var sim_version := Simulation.SIM_VERSION
var data_version: String
var seed_value: int
var map_width_cells: int
var map_height_cells: int
var ticks: int
var checkpoint_every := DEFAULT_CHECKPOINT_EVERY
var commands: Array[SimCommand] = []
## checkpoints[i] is the state hash after (i + 1) * checkpoint_every ticks.
var checkpoints := PackedStringArray()
var final_hash: String


## Result of play(). first_mismatch_tick is -1 when every hash matched.
class Playback:
	extends RefCounted
	var ok := true
	var first_mismatch_tick := -1
	var expected_hash: String
	var actual_hash: String
	var final_hash: String
	var message: String


## Runs a fresh simulation for `ticks` ticks, feeding it commands from `orders`, and records
## the result. `orders` is called before each tick as orders.call(sim) and may enqueue commands.
static func record(
	p_seed: int,
	db: CatalogDB,
	p_ticks: int,
	orders: Callable,
	every: int = DEFAULT_CHECKPOINT_EVERY,
	width_cells: int = Simulation.DEFAULT_MAP_CELLS,
	height_cells: int = Simulation.DEFAULT_MAP_CELLS
) -> Replay:
	var sim := Simulation.new(p_seed, db, width_cells, height_cells)
	var r := Replay.new()
	r.data_version = sim.data_version
	r.seed_value = p_seed
	r.map_width_cells = width_cells
	r.map_height_cells = height_cells
	r.ticks = p_ticks
	r.checkpoint_every = every
	for i in p_ticks:
		orders.call(sim)
		sim.step()
		if sim.tick % every == 0:
			r.checkpoints.append(sim.state_hash())
	for cmd in sim.command_log:
		r.commands.append(cmd.duplicate_command())
	r.final_hash = sim.state_hash()
	return r


## Plays the replay back against the given catalog and compares every checkpoint.
func play(db: CatalogDB) -> Playback:
	var result := Playback.new()
	var sim := new_simulation(db)
	if sim_version != Simulation.SIM_VERSION:
		result.message = "replay sim_version %d, current %d" % [sim_version, Simulation.SIM_VERSION]
	elif sim.data_version != data_version:
		result.message = "replay data %s, current %s" % [data_version, sim.data_version]
	for cmd in commands:
		sim.enqueue(cmd.duplicate_command())
	for i in ticks:
		sim.step()
		if sim.tick % checkpoint_every == 0 and result.ok:
			var at := sim.tick / checkpoint_every - 1
			var actual := sim.state_hash()
			if at < checkpoints.size() and checkpoints[at] != actual:
				result.ok = false
				result.first_mismatch_tick = sim.tick
				result.expected_hash = checkpoints[at]
				result.actual_hash = actual
	result.final_hash = sim.state_hash()
	if result.ok and result.final_hash != final_hash:
		result.ok = false
		result.first_mismatch_tick = sim.tick
		result.expected_hash = final_hash
		result.actual_hash = result.final_hash
	return result


func new_simulation(db: CatalogDB) -> Simulation:
	return Simulation.new(seed_value, db, map_width_cells, map_height_cells)


func to_dict() -> Dictionary:
	var cmd_list: Array[Dictionary] = []
	for cmd in commands:
		cmd_list.append(cmd.to_dict())
	return {
		"format": FORMAT,
		"sim_version": sim_version,
		"data_version": data_version,
		"seed": seed_value,
		"map": [map_width_cells, map_height_cells],
		"ticks": ticks,
		"checkpoint_every": checkpoint_every,
		"final_hash": final_hash,
		"checkpoints": Array(checkpoints),
		"commands": cmd_list,
	}


static func from_dict(d: Dictionary) -> Replay:
	assert(int(d["format"]) == FORMAT, "unsupported replay format")
	var r := Replay.new()
	r.sim_version = int(d["sim_version"])
	r.data_version = d["data_version"]
	r.seed_value = int(d["seed"])
	var map_size: Array = d["map"]
	r.map_width_cells = int(map_size[0])
	r.map_height_cells = int(map_size[1])
	r.ticks = int(d["ticks"])
	r.checkpoint_every = int(d["checkpoint_every"])
	r.final_hash = d["final_hash"]
	var raw_checkpoints: Array = d["checkpoints"]
	r.checkpoints = PackedStringArray(raw_checkpoints)
	var raw_commands: Array = d["commands"]
	for raw: Dictionary in raw_commands:
		r.commands.append(SimCommand.from_dict(raw))
	return r


## One command per line, so diffs of recorded replays stay readable.
func to_json() -> String:
	var d := to_dict()
	var cmd_lines := PackedStringArray()
	for cmd: Dictionary in d["commands"]:
		cmd_lines.append("    " + JSON.stringify(cmd, "", false))
	d.erase("commands")
	var head := JSON.stringify(d, "  ", false)
	var body := ',\n  "commands": [\n%s\n  ]\n}\n' % ",\n".join(cmd_lines)
	return head.left(head.rfind("}")).rstrip("\n") + body


func save(path: String) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(to_json())
	return OK


static func load_file(path: String) -> Replay:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("cannot read replay %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("replay %s is not a JSON object" % path)
		return null
	return from_dict(parsed as Dictionary)
