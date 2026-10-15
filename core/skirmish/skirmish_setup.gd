class_name SkirmishSetup
extends RefCounted
## The start of a skirmish on the prototype map (M8): each side joins with its faction and
## starting stock, gets a finished town centre and START_PEASANTS peasants beside it. All of it
## goes in as tick-0 commands, so a recorded game replays from the same start.

const MAP_ID := "map_proto_samogitia"
## Player, faction and the top-left cell of its town centre: GDL north-west, the Order
## south-east (as the map is drawn).
const BASES := [[1, &"gdl", Vector2i(5, 5)], [2, &"to", Vector2i(108, 96)]]
const START_PEASANTS := 5


## The skirmish map's world with both sides set up (their commands queued for tick 0).
static func new_simulation(sim_seed: int, db: CatalogDB) -> Simulation:
	var sim := Simulation.new(sim_seed, db, 0, 0, MapText.load_map(MAP_ID, db))
	set_up(sim)
	return sim


static func set_up(sim: Simulation) -> void:
	for base: Array in BASES:
		var player: int = base[0]
		var faction: StringName = base[1]
		var at: Vector2i = base[2]
		sim.enqueue(SimCommand.join(0, player, faction))
		var center := StringName("%s_town_center" % faction)
		var x := Fixed.from_cells(at.x) + Fixed.HALF
		var y := Fixed.from_cells(at.y) + Fixed.HALF
		sim.enqueue(SimCommand.place(0, player, center, x, y))
		var peasant := StringName("%s_peasant" % faction)
		for i in START_PEASANTS:
			var px := Fixed.from_cells(at.x + i) + Fixed.HALF
			sim.enqueue(SimCommand.spawn(0, player, peasant, px, Fixed.from_cells(at.y + 5)))


static func faction_of(player: int) -> StringName:
	for base: Array in BASES:
		if base[0] == player:
			return base[1]
	return &""


## The AI profile for a faction and difficulty (ai/profiles/<faction>_<difficulty>.tres).
static func ai_profile(faction: StringName, difficulty: StringName) -> AiProfile:
	return load("res://ai/profiles/%s_%s.tres" % [faction, difficulty]) as AiProfile
