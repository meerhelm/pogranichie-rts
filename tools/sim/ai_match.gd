class_name AiMatch
extends RefCounted
## «ИИ против ИИ» (plan M8 and section 5): two skirmish AIs play the prototype map headless,
## as fast as the machine allows, until one wins or the time runs out. One CSV row a game.
## Used by `sim_cli.gd -- aivsai`.

## A game still going after this long (60 game minutes) is a timeout.
const MAX_TICKS := 72000
const CSV_HEADER := (
	"game,seed,difficulty,winner,winner_faction,reason,minutes,"
	+ "p1_trained,p1_lost,p1_killed,p1_built,p1_buildings_lost,"
	+ "p2_trained,p2_lost,p2_killed,p2_built,p2_buildings_lost,step_avg_ms"
)

var db: CatalogDB


## Outcome of one game.
class Game:
	extends RefCounted
	var sim: Simulation
	var ticks := 0
	var step_usec := 0
	var winner := 0
	var reason := 0


func _init(p_db: CatalogDB) -> void:
	db = p_db


## Plays one game; `on_tick` (if valid) is called with the simulation after every step.
func play(game_seed: int, difficulty: StringName, max_ticks: int = MAX_TICKS) -> Game:
	var g := Game.new()
	var sim := SkirmishSetup.new_simulation(SkirmishAi.mix_seed(game_seed, 0), db)
	g.sim = sim
	var ais: Array[SkirmishAi] = []
	for base: Array in SkirmishSetup.BASES:
		var ai := SkirmishAi.new()
		var faction: StringName = base[1]
		ai.setup(sim, base[0], SkirmishSetup.ai_profile(faction, difficulty), game_seed)
		ais.append(ai)
	var start := Time.get_ticks_usec()
	while sim.tick < max_ticks and not sim.victory.is_over():
		for ai in ais:
			ai.issue()
		sim.step()
	g.step_usec = Time.get_ticks_usec() - start
	g.ticks = sim.tick
	g.winner = sim.victory.winner
	g.reason = sim.victory.reason
	for ai in ais:
		ai.free()
	return g


func row(index: int, game_seed: int, difficulty: StringName, g: Game) -> String:
	var cells := [
		index,
		game_seed,
		difficulty,
		g.winner,
		SkirmishSetup.faction_of(g.winner) if g.winner != 0 else "",
		SkirmishVictory.Reason.keys()[g.reason].to_lower() if g.winner != 0 else "timeout",
		"%.1f" % (g.ticks / 1200.0),
	]
	for p: int in [1, 2]:
		var st: PlayerState = g.sim.economy.players.get(p)
		cells.append_array([st.trained, st.lost, st.killed, st.built, st.buildings_lost])
	cells.append("%.2f" % (g.step_usec / 1000.0 / maxi(g.ticks, 1)))
	return ",".join(cells.map(func(c: Variant) -> String: return str(c)))
