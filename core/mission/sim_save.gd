class_name SimSave
extends RefCounted
## Saving and loading a mission in progress (M9): a header (mission, seed, difficulty, versions,
## tick, state hash) and a Snapshot of the whole simulation, the mission's triggers included.
## Loading builds the mission's start afresh (MissionSetup) and overwrites it with the snapshot,
## so the loaded world has the same state_hash() as the saved one and plays on the same.

const FORMAT := 1
const DIR := "user://saves"


## The header and snapshot of a mission's world, as plain data.
static func capture(sim: Simulation) -> Dictionary:
	var m := sim.mission
	return {
		"format": FORMAT,
		"mission_id": m.def.id,
		"title": m.def.title,
		"seed": sim.seed_value,
		"difficulty": m.difficulty,
		"sim_version": Simulation.SIM_VERSION,
		"data_version": sim.data_version,
		"tick": sim.tick,
		"hash": sim.state_hash(),
		"snapshot": Snapshot.capture(sim, _externals(sim)),
	}


## The world from capture()'s data, or null (with an error) if it cannot be loaded.
static func restore(data: Dictionary, db: CatalogDB) -> Simulation:
	if Num.of(data.get("format", 0)) != FORMAT:
		push_error("save: unsupported format")
		return null
	if Num.of(data["sim_version"]) != Simulation.SIM_VERSION:
		push_error("save: made by another game version (rules %s)" % data["sim_version"])
		return null
	var sim := MissionSetup.new_simulation(
		str(data["mission_id"]), Num.of(data["seed"]), db, str(data["difficulty"])
	)
	if sim == null:
		return null
	if sim.data_version != data["data_version"]:
		push_error("save: made with other game data")
		return null
	var error := Snapshot.restore(data["snapshot"], sim, _externals(sim), _factories(sim))
	if not error.is_empty():
		push_error("save: " + error)
		return null
	return sim


static func save(sim: Simulation, path: String) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_var(capture(sim))
	return OK


static func load_file(path: String, db: CatalogDB) -> Simulation:
	var data := read_header(path, true)
	return restore(data, db) if not data.is_empty() else null


## The saved data (without the snapshot unless `full`), or {} if the file is not a save.
static func read_header(path: String, full: bool = false) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data: Variant = f.get_var()
	if not data is Dictionary:
		return {}
	var d: Dictionary = data
	if not full:
		d.erase("snapshot")
	return d


## Saves in the save folder, newest first.
static func list() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	var files: Array = []
	for name in dir.get_files():
		if name.ends_with(".save"):
			var path := DIR.path_join(name)
			files.append([FileAccess.get_modified_time(path), path])
	files.sort()
	files.reverse()
	for entry: Array in files:
		out.append(str(entry[1]))
	return out


static func _externals(sim: Simulation) -> Dictionary:
	return {"db": sim.catalog(), "mission": sim.mission.def}


## Objects whose constructors take arguments, for those the fresh world does not have yet.
static func _factories(sim: Simulation) -> Dictionary:
	var nav := sim.nav
	return {
		"res://core/nav/flow_field.gd":
		func() -> FlowField: return FlowField.new(nav, 0, 0, PackedInt32Array()),
		"res://core/economy/player_state.gd": func() -> PlayerState: return PlayerState.new(0, &""),
		"res://core/vision/vision_grid.gd": func() -> VisionGrid: return VisionGrid.new(1, 1),
	}
