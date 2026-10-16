class_name MissionSetup
extends RefCounted
## The start of a campaign mission (M9): its map, the simulation with the mission's script in it
## and the mission's own setup applied at tick 0. The skirmish victory rules are off: the
## mission decides who wins.


static func new_simulation(
	mission_id: String, sim_seed: int, db: CatalogDB, difficulty: String = "normal"
) -> Simulation:
	var def := MissionDef.load_id(mission_id)
	if def == null:
		return null
	var grid := MapText.load_map(def.map_id, db)
	if grid == null:
		return null
	var sim := Simulation.new(sim_seed, db, 0, 0, grid)
	sim.victory.rules = null
	sim.mission = MissionRuntime.new(def, sim, difficulty)
	sim.mission.set_up(sim.tick)
	return sim
