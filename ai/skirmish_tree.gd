class_name SkirmishTree
extends RefCounted
## The skirmish AI's behaviour tree (LimboAI), built in code so it lives next to the methods it
## calls. Each think runs it once from the top:
##
##   Sequence
##     Sequence "economy": train peasants, put idle peasants to work, send one out to look for
##       resources not found yet, finish foundations, houses
##       when the population is near its limit, the next build-order step, a mine by each
##       worked deposit, more barracks and the like while money piles up, fields for the food
##       workers, places of power and shrines, army units
##     Selector "military", the first that applies:
##       base threatened? -> defend the base
##       wave too weak?   -> pull the wave back home
##       wave ready?      -> send a wave
##       wave out?        -> press the attack
##       otherwise        -> gather the army at the rally point
##     cast spells
##
## Every economy step succeeds, so the military part always runs after it.

const ECONOMY: Array[StringName] = [
	&"train_peasants",
	&"assign_workers",
	&"explore",
	&"finish_foundations",
	&"build_houses",
	&"follow_build_order",
	&"build_mines",
	&"build_producers",
	&"build_fields",
	&"take_places",
	&"train_army",
]
## (question, action) pairs of the military selector, in priority order.
const MILITARY: Array[StringName] = [
	&"base_threatened",
	&"defend_base",
	&"wave_weak",
	&"retreat_wave",
	&"wave_ready",
	&"launch_wave",
	&"wave_out",
	&"press_attack",
]


static func build() -> BehaviorTree:
	var root := BTSequence.new()
	root.custom_name = "think"
	var economy := BTSequence.new()
	economy.custom_name = "economy"
	for m in ECONOMY:
		economy.add_child(_step(m))
	root.add_child(economy)
	var military := BTSelector.new()
	military.custom_name = "military"
	for i in range(0, MILITARY.size(), 2):
		var branch := BTSequence.new()
		branch.add_child(_check(MILITARY[i]))
		branch.add_child(_step(MILITARY[i + 1]))
		military.add_child(branch)
	military.add_child(_step(&"gather_army"))
	root.add_child(military)
	root.add_child(_step(&"cast_spells"))
	var bt := BehaviorTree.new()
	bt.description = "Skirmish AI (M8)"
	bt.root_task = root
	return bt


static func _step(method: StringName) -> AiStep:
	var task := AiStep.new()
	task.method = method
	return task


static func _check(method: StringName) -> AiCheck:
	var task := AiCheck.new()
	task.method = method
	return task
