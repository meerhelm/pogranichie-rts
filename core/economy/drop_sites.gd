class_name DropSites
extends RefCounted
## Which finished buildings of a player take a resource, for EconomySystem.drop_site: every
## carrying peasant asks every tick, so the lists, by id, are kept until a building is added,
## finished or removed (BuildingStore.version, next_id).

var _lists: Dictionary[int, PackedInt32Array] = {}
var _version := -1
var _next := -1


func of(buildings: BuildingStore, p: int, res: int) -> PackedInt32Array:
	if _version != buildings.version or _next != buildings.next_id:
		_version = buildings.version
		_next = buildings.next_id
		_lists.clear()
	var names := EconomySystem.RESOURCE_NAMES
	var key := p * names.size() + res
	if _lists.has(key):
		return _lists[key]
	var want: StringName = names[res]
	var list := PackedInt32Array()
	for b in buildings.alive_ids:
		var s := b - 1
		if buildings.owners[s] == p and buildings.done[s] == 1:
			if buildings.defs[s].accepts.has(want):
				list.append(b)
	_lists[key] = list
	return list
