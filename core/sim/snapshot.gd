class_name Snapshot
extends RefCounted
## A copy of the whole simulation state (M9 saves): every script variable of every object
## reachable from the root, as plain values that var_to_bytes() can store.
##
## capture() walks the object graph from the root and writes each object once (shared objects
## stay shared). Containers become tagged dictionaries, objects become references to the object
## table, loaded resources (catalog defs) their path, and objects named in `externals` (the
## CatalogDB) their name. Callables must be methods of objects in the graph.
##
## restore() needs a fresh world built the same way the saved one was (the same constructors, so
## the same objects point at each other) and overwrites it: an object of the save is matched
## with the object the fresh world holds at the same place, and containers are refilled in
## place, so containers that several objects share stay shared. Objects the fresh world does not
## have yet (a flow field, a player, a queued command) come from `factories` (script path ->
## Callable returning a blank object) or, for scripts whose _init takes no arguments, from new().
## Simulation.state_hash() of the restored world equals the saved one.

const FORMAT := 1
## Tags of encoded values (dictionaries are always tags; a saved Dictionary is K/V).
const ARRAY := "a"
const KEYS := "k"
const VALUES := "v"
const OBJECT := "o"
const RESOURCE := "r"
const EXTERNAL := "x"
const CALLABLE := "c"


## The graph from `root` as plain data. `externals`: name -> object kept out of the copy.
static func capture(root: Object, externals: Dictionary = {}) -> Dictionary:
	var w := _Writer.new()
	w.externals = externals
	var root_ref := w.ref(root)
	while w.pending < w.objects.size():
		w.write_object(w.pending)
		w.pending += 1
	return {"format": FORMAT, "root": root_ref, "objects": w.table}


## Overwrites `fresh_root` (built like the saved root) with the saved state. Returns an empty
## string, or what went wrong.
static func restore(
	data: Dictionary, fresh_root: Object, externals: Dictionary = {}, factories: Dictionary = {}
) -> String:
	if Num.of(data.get("format", 0)) != FORMAT:
		return "unsupported snapshot format"
	var r := _Reader.new()
	r.table = data["objects"]
	r.externals = externals
	r.factories = factories
	var root_id: int = data["root"][OBJECT]
	r.claim(root_id, fresh_root)
	while not r.todo.is_empty():
		var id: int = r.todo.pop_front()
		r.fill(id)
		if not r.error.is_empty():
			return r.error
	return r.error


## The names of an object's script variables, in declaration order.
static func script_vars(obj: Object) -> PackedStringArray:
	var names := PackedStringArray()
	for prop: Dictionary in obj.get_property_list():
		var usage: int = prop["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			names.append(str(prop["name"]))
	return names


## A packed array copied, other values as they are. Packed arrays are copy-on-write: one the
## world shares with the snapshot is copied on its next write, and code that writes through a
## local alias of a member (the pathfinder, the heap) would then write to the copy. So the
## world and the snapshot never share one.
static func own(value: Variant) -> Variant:
	if typeof(value) >= TYPE_PACKED_BYTE_ARRAY and typeof(value) <= TYPE_PACKED_VECTOR4_ARRAY:
		return value.duplicate()
	return value


class _Writer:
	extends RefCounted
	var externals: Dictionary = {}
	var objects: Array[Object] = []
	var ids: Dictionary[int, int] = {}
	var table: Array = []
	var pending := 0

	## The object's index in the table, adding it if it is new.
	func ref(obj: Object) -> Dictionary:
		var key := obj.get_instance_id()
		if not ids.has(key):
			ids[key] = objects.size()
			objects.append(obj)
			table.append({})
		return {OBJECT: ids[key]}

	func write_object(index: int) -> void:
		var obj := objects[index]
		var script: Script = obj.get_script()
		assert(script != null and not script.resource_path.is_empty(), "snapshot: no script file")
		var props := {}
		for prop_name in Snapshot.script_vars(obj):
			props[prop_name] = encode(obj.get(prop_name))
		table[index] = {"script": script.resource_path, "props": props}

	func encode(value: Variant) -> Variant:
		match typeof(value):
			TYPE_ARRAY:
				var out := []
				for item: Variant in value:
					out.append(encode(item))
				return {ARRAY: out}
			TYPE_DICTIONARY:
				var d: Dictionary = value
				var keys := []
				var values := []
				for k: Variant in d:
					keys.append(encode(k))
					values.append(encode(d[k]))
				return {KEYS: keys, VALUES: values}
			TYPE_OBJECT:
				return encode_object(value)
			TYPE_CALLABLE:
				var c: Callable = value
				if c.is_null():
					return {CALLABLE: null}
				assert(c.is_standard(), "snapshot: lambdas cannot be saved")
				return {CALLABLE: [encode_object(c.get_object()), String(c.get_method())]}
		return Snapshot.own(value)

	func encode_object(obj: Object) -> Variant:
		if obj == null:
			return null
		for name: String in externals:
			if externals[name] == obj:
				return {EXTERNAL: name}
		if obj is Resource and not (obj as Resource).resource_path.is_empty():
			return {RESOURCE: (obj as Resource).resource_path}
		return ref(obj)


class _Reader:
	extends RefCounted
	var table: Array = []
	var externals: Dictionary = {}
	var factories: Dictionary = {}
	## Saved object index -> the live object standing for it.
	var live: Dictionary[int, Object] = {}
	## Instance ids of the live objects already matched.
	var taken: Dictionary[int, bool] = {}
	var todo: Array[int] = []
	var error := ""

	func claim(id: int, obj: Object) -> void:
		live[id] = obj
		taken[obj.get_instance_id()] = true
		todo.append(id)

	func fill(id: int) -> void:
		var obj := live[id]
		var saved: Dictionary = table[id]
		var script: Script = obj.get_script()
		if script == null or script.resource_path != saved["script"]:
			error = "snapshot: object %d is %s, the world has %s" % [id, saved["script"], obj]
			return
		var props: Dictionary = saved["props"]
		for prop_name: String in props:
			var current: Variant = obj.get(prop_name)
			var value: Variant = decode(props[prop_name], current)
			if not error.is_empty():
				return
			if typeof(current) == TYPE_ARRAY and typeof(value) == TYPE_ARRAY:
				(current as Array).assign(value)
			elif typeof(current) == TYPE_DICTIONARY and typeof(value) == TYPE_DICTIONARY:
				var into: Dictionary = current
				into.clear()
				var from: Dictionary = value
				for k: Variant in from:
					into[k] = from[k]
			else:
				obj.set(prop_name, value)

	## `current` is what the fresh world holds there now: objects in it are reused.
	func decode(value: Variant, current: Variant) -> Variant:
		if typeof(value) != TYPE_DICTIONARY:
			return Snapshot.own(value)
		var tag: Dictionary = value
		var out: Variant = null
		if tag.has(ARRAY):
			out = decode_array(tag[ARRAY], current)
		elif tag.has(KEYS):
			out = decode_dictionary(tag[KEYS], tag[VALUES], current)
		elif tag.has(OBJECT):
			out = object_for(Num.of(tag[OBJECT]), current)
		elif tag.has(RESOURCE):
			out = load(str(tag[RESOURCE]))
		elif tag.has(EXTERNAL):
			out = externals.get(tag[EXTERNAL])
		elif tag.has(CALLABLE):
			out = decode_callable(tag[CALLABLE], current)
		else:
			error = "snapshot: unknown tag %s" % tag.keys()
		return out

	func decode_array(items: Array, current: Variant) -> Array:
		var old: Array = current if typeof(current) == TYPE_ARRAY else []
		var out := []
		for i in items.size():
			out.append(decode(items[i], old[i] if i < old.size() else null))
		return out

	func decode_dictionary(keys: Array, values: Array, current: Variant) -> Dictionary:
		var old: Dictionary = current if typeof(current) == TYPE_DICTIONARY else {}
		var out := {}
		for i in keys.size():
			var k: Variant = decode(keys[i], null)
			out[k] = decode(values[i], old.get(k))
		return out

	func decode_callable(parts: Variant, current: Variant) -> Callable:
		if parts == null:
			return Callable()
		# The fresh world's own callable points at the matching object.
		var fresh: Object = null
		if typeof(current) == TYPE_CALLABLE and (current as Callable).is_standard():
			fresh = (current as Callable).get_object()
		var target: Variant = decode(parts[0], fresh)
		return Callable(target as Object, StringName(str(parts[1])))

	func object_for(id: int, current: Variant) -> Object:
		if live.has(id):
			return live[id]
		var path: String = table[id]["script"]
		var obj: Object = null
		var fits := current is Object and _script_path(current) == path
		if fits and not taken.has((current as Object).get_instance_id()):
			obj = current
		elif factories.has(path):
			obj = (factories[path] as Callable).call()
		else:
			obj = (load(path) as GDScript).new()
		claim(id, obj)
		return obj

	static func _script_path(obj: Object) -> String:
		var script: Script = obj.get_script()
		return script.resource_path if script != null else ""
