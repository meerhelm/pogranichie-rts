class_name SkirmishSetup
extends RefCounted
## The start of a skirmish (M8): each side joins with its faction and
## starting stock, gets a finished town centre and START_PEASANTS peasants beside it. All of it
## goes in as tick-0 commands, so a recorded game replays from the same start.
## Any of FACTIONS may play either side (the Crown joined on 2026-10-18); without a choice GDL
## plays the first side of the map and the Order the second. The map is one of SkirmishMaps
## (2026-10-19), the prototype's «Жемайтское порубежье» unless another is picked.

const MAP_ID := "map_proto_samogitia"
## Player and default faction of each side, in the order of the map's bases (SkirmishMaps).
const BASES := [[1, &"gdl"], [2, &"to"]]
## Factions a skirmish offers, in menu order.
const FACTIONS: Array[StringName] = [&"gdl", &"pl", &"to"]
const DEFAULT_FACTIONS: Array[StringName] = [&"gdl", &"to"]
const START_PEASANTS := 5


## The skirmish map's world with both sides set up (their commands queued for tick 0).
## `factions`: the faction of player 1 and of player 2.
## `map_id`: one of SkirmishMaps.
static func new_simulation(
	sim_seed: int,
	db: CatalogDB,
	factions: Array[StringName] = DEFAULT_FACTIONS,
	map_id: String = MAP_ID
) -> Simulation:
	var sim := Simulation.new(sim_seed, db, 0, 0, MapText.load_map(map_id, db))
	set_up(sim, factions, map_id)
	return sim


static func set_up(
	sim: Simulation, factions: Array[StringName] = DEFAULT_FACTIONS, map_id: String = MAP_ID
) -> void:
	for i in BASES.size():
		var player: int = BASES[i][0]
		var faction: StringName = factions[i]
		var at := SkirmishMaps.base(map_id, i)
		sim.enqueue(SimCommand.join(0, player, faction))
		var center := StringName("%s_town_center" % faction)
		var x := Fixed.from_cells(at.x) + Fixed.HALF
		var y := Fixed.from_cells(at.y) + Fixed.HALF
		sim.enqueue(SimCommand.place(0, player, center, x, y))
		var peasant := peasant_of(sim.economy.db, faction)
		for k in START_PEASANTS:
			var px := Fixed.from_cells(at.x + k) + Fixed.HALF
			sim.enqueue(SimCommand.spawn(0, player, peasant, px, Fixed.from_cells(at.y + 5)))


static func faction_of(player: int, factions: Array[StringName] = DEFAULT_FACTIONS) -> StringName:
	for i in BASES.size():
		if BASES[i][0] == player:
			return factions[i]
	return &""


## The faction's peasant: its unit of class peasant that gathers, trained at its town centre
## (gdl_peasant, the Crown's pl_kmet), or <faction>_peasant without the catalog.
static func peasant_of(db: CatalogDB, faction: StringName) -> StringName:
	var fallback := StringName("%s_peasant" % faction)
	if db == null or db.unit(fallback) != null:
		return fallback
	var center := StringName("%s_town_center" % faction)
	var ids := PackedStringArray(db.units.keys())
	ids.sort()
	for id in ids:
		var def := db.unit(StringName(id))
		if def.faction == faction and def.has_class(&"peasant") and not def.campaign_only:
			if def.trained_at.has(center) and not def.tags.has(&"no_gather"):
				return def.id
	return fallback


## The AI profile for a faction and difficulty (ai/profiles/<faction>_<difficulty>.tres).
static func ai_profile(faction: StringName, difficulty: StringName) -> AiProfile:
	return load("res://ai/profiles/%s_%s.tres" % [faction, difficulty]) as AiProfile
