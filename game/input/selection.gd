class_name Selection
extends RefCounted
## Which of the player's units are selected, and the Ctrl+1…9 groups. Pure logic: it is given
## the units on screen (ids, screen points, types) and never touches the scene or the sim.

signal changed

## Clicks this close to a unit (in screen pixels) pick it.
const PICK_RADIUS := 14.0

var ids := PackedInt32Array()
var groups: Dictionary[int, PackedInt32Array] = {}


func clear() -> void:
	_replace(PackedInt32Array())


func has(id: int) -> bool:
	return ids.has(id)


## The unit whose figure is under the point (`hit`, if it is a candidate), else the nearest
## to the point within PICK_RADIUS, or 0.
static func pick(
	at: Vector2, cand_ids: PackedInt32Array, points: PackedVector2Array, hit := 0
) -> int:
	if hit != 0 and cand_ids.has(hit):
		return hit
	var best := 0
	var best_d := PICK_RADIUS * PICK_RADIUS
	for i in cand_ids.size():
		var d := points[i].distance_squared_to(at)
		if d <= best_d:
			best_d = d
			best = cand_ids[i]
	return best


## Click: select the unit under the cursor (`hit`: the one whose figure is there, see pick);
## with Shift, add it or take it out.
func click(
	at: Vector2, cand_ids: PackedInt32Array, points: PackedVector2Array, shift: bool, hit := 0
) -> void:
	var id := pick(at, cand_ids, points, hit)
	if not shift:
		_replace(PackedInt32Array([id]) if id != 0 else PackedInt32Array())
	elif id != 0:
		var next := ids.duplicate()
		if next.has(id):
			next.remove_at(next.find(id))
		else:
			next.append(id)
		_replace(next)


## Drag box: select every unit inside; with Shift, add them to the selection.
func box(rect: Rect2, cand_ids: PackedInt32Array, points: PackedVector2Array, shift: bool) -> void:
	var r := rect.abs()
	var inside := PackedInt32Array()
	for i in cand_ids.size():
		if r.has_point(points[i]):
			inside.append(cand_ids[i])
	if shift:
		inside.append_array(ids)
	_replace(inside)


## Double click: every unit of the clicked unit's type among the candidates (those on screen).
func same_type(
	at: Vector2,
	cand_ids: PackedInt32Array,
	points: PackedVector2Array,
	types: Array[StringName],
	shift: bool,
	hit := 0
) -> void:
	var id := pick(at, cand_ids, points, hit)
	if id == 0:
		return
	var type := types[cand_ids.find(id)]
	var same := PackedInt32Array()
	for i in cand_ids.size():
		if types[i] == type:
			same.append(cand_ids[i])
	if shift:
		same.append_array(ids)
	_replace(same)


## Selects exactly these units (the idle worker button).
func set_ids(new_ids: PackedInt32Array) -> void:
	_replace(new_ids)


func assign_group(n: int) -> void:
	groups[n] = ids.duplicate()


## Selects group n, leaving out units for which is_alive returns false. True if not empty.
func recall_group(n: int, is_alive: Callable) -> bool:
	var alive := PackedInt32Array()
	var group: PackedInt32Array = groups.get(n, PackedInt32Array())
	for id in group:
		if is_alive.call(id):
			alive.append(id)
	groups[n] = alive
	_replace(alive)
	return not alive.is_empty()


## Drops dead units from the selection and every group.
func forget_dead(is_alive: Callable) -> void:
	var kept := PackedInt32Array()
	for id in ids:
		if is_alive.call(id):
			kept.append(id)
	if kept.size() != ids.size():
		_replace(kept)


func _replace(new_ids: PackedInt32Array) -> void:
	var sorted := PackedInt32Array()
	for id in new_ids:
		if id != 0 and not sorted.has(id):
			sorted.append(id)
	sorted.sort()
	if sorted != ids:
		ids = sorted
		changed.emit()
