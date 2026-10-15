@tool
class_name AiStep
extends BTAction
## One step of the skirmish AI's behaviour tree: calls `method` on the agent (SkirmishAi),
## which returns true for SUCCESS and false for FAILURE.

@export var method: StringName


func _generate_name() -> String:
	return "Do %s" % method


func _tick(_delta: float) -> Status:
	var ai := agent as SkirmishAi
	var t0 := Time.get_ticks_usec() if ai.timing else 0
	var ok: bool = agent.call(method)
	if ai.timing:
		ai.step_usec[method] = ai.step_usec.get(method, 0) + Time.get_ticks_usec() - t0
	return SUCCESS if ok else FAILURE
