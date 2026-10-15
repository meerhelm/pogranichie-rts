class_name UnitBuckets
extends RefCounted
## Units sorted into square blocks of BLOCK cells, refilled once a tick, to answer "who is within
## r of this point" without looking at every unit.

## Side of a block in cells.
const BLOCK := 4

var _bw := 1
var _bh := 1
# _head[block] is the last id put there, _next[id - 1] the one before it (0 ends a chain).
var _head := PackedInt32Array()
var _next := PackedInt32Array()
var _entities: EntityStore


func _init(width_cells: int, height_cells: int) -> void:
	_bw = (width_cells + BLOCK - 1) / BLOCK
	_bh = (height_cells + BLOCK - 1) / BLOCK
	_head.resize(_bw * _bh)


func fill(e: EntityStore) -> void:
	_entities = e
	_head.fill(0)
	_next.resize(e.next_id - 1)
	for id in e.alive_ids:
		var b := _block(e.pos_x[id - 1], e.pos_y[id - 1])
		_next[id - 1] = _head[b]
		_head[b] = id


## Alive ids within r (fixed units) of the point, as positioned at the last fill(). The order is
## the buckets' own: callers that pick one must break ties by id.
func near(x: int, y: int, r: int) -> PackedInt32Array:
	var e := _entities
	var result := PackedInt32Array()
	if e == null:
		return result
	var bx0 := _col(x - r)
	var bx1 := _col(x + r)
	var by0 := _row(y - r)
	var by1 := _row(y + r)
	var r2 := r * r
	for by in range(by0, by1 + 1):
		for bx in range(bx0, bx1 + 1):
			var id := _head[by * _bw + bx]
			while id != 0:
				if e.is_alive(id):
					var dx := e.pos_x[id - 1] - x
					var dy := e.pos_y[id - 1] - y
					if dx * dx + dy * dy <= r2:
						result.append(id)
				id = _next[id - 1]
	return result


func _col(x: int) -> int:
	return clampi(Fixed.to_cells(x) / BLOCK, 0, _bw - 1)


func _row(y: int) -> int:
	return clampi(Fixed.to_cells(y) / BLOCK, 0, _bh - 1)


func _block(x: int, y: int) -> int:
	return _row(y) * _bw + _col(x)
