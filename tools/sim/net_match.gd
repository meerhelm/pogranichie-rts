class_name NetMatch
extends RefCounted
## A network game without a window, for tests and `sim_cli.gd -- net`: a NetSession whose own
## player is a SkirmishAi, its orders going through Lockstep like a person's clicks. Two of them
## (two processes over ENet, or two LoopbackTransport ends in a test) play a whole game against
## each other, and their state hashes must agree all the way.

var session: NetSession
var sim: Simulation
var ai: SkirmishAi


func _init(p_session: NetSession) -> void:
	session = p_session


## Once the session has started: makes the world, the lockstep and the AI for the local player.
func begin(db: CatalogDB, difficulty: StringName = &"normal") -> void:
	sim = session.new_simulation(db)
	var lockstep := session.attach(sim)
	var faction := SkirmishSetup.faction_of(session.local_player, session.factions())
	var profile := SkirmishSetup.ai_profile(faction, difficulty)
	if profile != null:
		ai = SkirmishAi.new()
		ai.setup(sim, session.local_player, profile, int(session.setup["seed"]))
		ai.sink = lockstep.submit


## Delivers what came over the network and steps as many ticks as the other side allows, at most
## max_steps; returns the ticks stepped.
func pump(max_steps: int = 100) -> int:
	session.transport.poll()
	if session.lockstep == null:
		return 0
	var n := 0
	while n < max_steps and session.lockstep.can_step():
		if ai != null:
			ai.issue()
		session.lockstep.try_step()
		n += 1
	return n


func over() -> bool:
	return sim != null and sim.victory.is_over()


func free_ai() -> void:
	if ai != null:
		ai.free()
		ai = null
