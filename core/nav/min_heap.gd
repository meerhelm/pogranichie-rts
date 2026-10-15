class_name MinHeap
extends RefCounted
## Binary min-heap of (key, cell) pairs, ordered by key and then by cell, so equal keys pop in
## the same order on every machine. Used by A* and the flow field. Each pair is packed into one
## int (key above CELL_BITS, cell below) and sifting is written out inline: in GDScript a
## function call per comparison would cost more than the whole comparison. The array is used
## in place (copying a packed array to a local would copy it on every write).

const CELL_BITS := 16
const CELL_MASK := (1 << CELL_BITS) - 1
## Keys must stay below this so packed values do not overflow.
const MAX_KEY := 1 << (62 - CELL_BITS)

var _items := PackedInt64Array()


func is_empty() -> bool:
	return _items.is_empty()


func size() -> int:
	return _items.size()


func clear() -> void:
	_items.clear()


func push(key: int, cell: int) -> void:
	var v := (key << CELL_BITS) | cell
	_items.append(v)
	var i := _items.size() - 1
	while i > 0:
		var parent := (i - 1) >> 1
		var p := _items[parent]
		if p <= v:
			break
		_items[i] = p
		i = parent
	_items[i] = v


func top_key() -> int:
	return _items[0] >> CELL_BITS


## Removes the smallest pair and returns its cell.
func pop() -> int:
	var top := _items[0]
	var last := _items.size() - 1
	var v := _items[last]
	_items.resize(last)
	if last > 0:
		var i := 0
		while true:
			var c := 2 * i + 1
			if c >= last:
				break
			var cv := _items[c]
			if c + 1 < last and _items[c + 1] < cv:
				c += 1
				cv = _items[c]
			if v <= cv:
				break
			_items[i] = cv
			i = c
		_items[i] = v
	return top & CELL_MASK
