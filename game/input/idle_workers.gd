class_name IdleWorkers
extends RefCounted
## The player's idle workers, for the «Idle worker» button and the . key (2026-10): peasants with
## no job (gathering, hunting, building, taking apart), no order to walk, no one to fight, not
## fleeing and not putting out or setting fires. Reads the sim, never changes it.


## Ids of the player's idle workers, in ascending order.
static func of(sim: Simulation, player: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if sim == null:
		return out
	var e := sim.entities
	var eco := sim.economy
	var fire := sim.fire
	for id in e.alive_ids:
		var slot := id - 1
		if e.owners[slot] != player or slot >= eco.unit_defs.size():
			continue
		var def := eco.unit_defs[slot]
		if def == null or not def.has_class(&"peasant"):
			continue
		if slot < eco.job.size() and eco.job[slot] != EconomySystem.Job.NONE:
			continue
		if e.orders[slot] != EntityStore.Order.IDLE:
			continue
		if e.target_kind[slot] != EntityStore.TargetKind.NONE:
			continue
		if e.intents[slot] != EntityStore.Intent.NONE:
			continue
		if fire != null and (fire.dousers.has(id) or fire.arson.has(id)):
			continue
		out.append(id)
	out.sort()
	return out


## True if the player has any worker at all, idle or not (a field battle has none).
static func any(sim: Simulation, player: int) -> bool:
	if sim == null:
		return false
	var e := sim.entities
	var defs := sim.economy.unit_defs
	for id in e.alive_ids:
		var slot := id - 1
		if e.owners[slot] == player and slot < defs.size():
			if defs[slot] != null and defs[slot].has_class(&"peasant"):
				return true
	return false


## The idle worker after `last` (by id, wrapping around), or the first; 0 if there is none.
static func next_after(idle: PackedInt32Array, last: int) -> int:
	if idle.is_empty():
		return 0
	for id in idle:
		if id > last:
			return id
	return idle[0]
