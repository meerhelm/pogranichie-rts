class_name MistField
extends RefCounted
## Where «Болотный туман» lies now (M7), for the fog of war. MagicSystem keeps it in step with
## its mist effects; VisionSystem only asks. It holds no other object, so the vision can keep it
## without a reference cycle.

## Per mist: whose it is, centre cell, radius in cells, and the tick it came down.
var owners := PackedInt32Array()
var cell_x := PackedInt32Array()
var cell_y := PackedInt32Array()
var radius := PackedInt32Array()
var since := PackedInt32Array()


func clear() -> void:
	owners.clear()
	cell_x.clear()
	cell_y.clear()
	radius.clear()
	since.clear()


func add(owner: int, cx: int, cy: int, r: int, from_tick: int) -> void:
	owners.append(owner)
	cell_x.append(cx)
	cell_y.append(cy)
	radius.append(r)
	since.append(from_tick)


func is_empty() -> bool:
	return owners.is_empty()


## Whether a mist of `owner` covers the cell and hides what stands there: a unit only until its
## first attack after the mist came down (`last_attack`, -1 for buildings and units that never
## attacked).
func hides(owner: int, cx: int, cy: int, last_attack: int) -> bool:
	for i in owners.size():
		if owners[i] != owner or last_attack >= since[i]:
			continue
		var dx := cx - cell_x[i]
		var dy := cy - cell_y[i]
		if dx * dx + dy * dy <= radius[i] * radius[i]:
			return true
	return false


## Whether any mist covers the cell (for drawing it).
func covers(cx: int, cy: int) -> bool:
	for i in owners.size():
		var dx := cx - cell_x[i]
		var dy := cy - cell_y[i]
		if dx * dx + dy * dy <= radius[i] * radius[i]:
			return true
	return false
