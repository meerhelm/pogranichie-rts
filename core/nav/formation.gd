class_name Formation
extends RefCounted
## Slots of a group order: line, column or wedge, one cell apart, centred on the target and
## facing the way the group moves. Units are matched to slots without crossing: the front
## units take the front rank, and inside a rank they keep their left-to-right order.

enum Kind { LINE, COLUMN, WEDGE }

## Distance between neighbouring slots.
const SPACING := Fixed.ONE
const COLUMN_WIDTH := 3


## Slot offsets for n units as [lateral, back] pairs in fixed units, rank by rank, front first,
## each rank left to right. lateral grows to the right of the facing, back grows rearward.
static func offsets(kind: Kind, n: int) -> Array[Vector2i]:
	var ranks: Array[int] = []
	match kind:
		Kind.LINE:
			_fill_ranks(ranks, n, line_width(n))
		Kind.COLUMN:
			_fill_ranks(ranks, n, mini(n, COLUMN_WIDTH))
		Kind.WEDGE:
			var left := n
			var row := 1
			while left > 0:
				ranks.append(mini(row, left))
				left -= row
				row += 2
	var out: Array[Vector2i] = []
	var depth := (ranks.size() - 1) * SPACING
	for r in ranks.size():
		var count := ranks[r]
		for i in count:
			# Centre each rank: lateral = (i - (count - 1) / 2) * spacing, kept integral.
			var lateral := (2 * i - (count - 1)) * SPACING / 2
			out.append(Vector2i(lateral, r * SPACING - depth / 2))
	return out


## Units abreast in a line: about four ranks for big groups, one rank for small ones.
static func line_width(n: int) -> int:
	if n <= 4:
		return n
	var w := Fixed.isqrt(4 * n)
	if w * w < 4 * n:
		w += 1
	return mini(w, n)


## World positions of the slots. (fx, fy) is the facing direction (any length, not zero).
static func slot_positions(
	kind: Kind, n: int, cx: int, cy: int, fx: int, fy: int
) -> Array[Vector2i]:
	var length := Fixed.isqrt(fx * fx + fy * fy)
	if length == 0:
		fx = 0
		fy = -Fixed.ONE
		length = Fixed.ONE
	# Unit facing u and its right-hand side r = (-u.y, u.x), both scaled to Fixed.ONE.
	var ux := fx * Fixed.ONE / length
	var uy := fy * Fixed.ONE / length
	var out: Array[Vector2i] = []
	for o in offsets(kind, n):
		var x := cx + Fixed.floor_div(-uy * o.x - ux * o.y, Fixed.ONE)
		var y := cy + Fixed.floor_div(ux * o.x - uy * o.y, Fixed.ONE)
		out.append(Vector2i(x, y))
	return out


## Which slot each unit takes: result[i] is the slot index for units[i]. Front units (by
## projection on the facing) fill the front ranks; within a rank, left to right. Ties by id.
static func assign(
	kind: Kind, ids: PackedInt32Array, xs: PackedInt64Array, ys: PackedInt64Array, fx: int, fy: int
) -> PackedInt32Array:
	var n := ids.size()
	var rank_sizes := _rank_sizes(offsets(kind, n))
	var order := range(n)
	# forward = projection on the facing, larger is further ahead.
	order.sort_custom(
		func(a: int, b: int) -> bool:
			var pa: int = xs[a] * fx + ys[a] * fy
			var pb: int = xs[b] * fx + ys[b] * fy
			return pa > pb or (pa == pb and ids[a] < ids[b])
	)
	var result := PackedInt32Array()
	result.resize(n)
	var start := 0
	for count in rank_sizes:
		var rank: Array = order.slice(start, start + count)
		# lateral = projection on the right-hand side (-fy, fx), smaller is further left.
		rank.sort_custom(
			func(a: int, b: int) -> bool:
				var la: int = -xs[a] * fy + ys[a] * fx
				var lb: int = -xs[b] * fy + ys[b] * fx
				return la < lb or (la == lb and ids[a] < ids[b])
		)
		for i in count:
			result[rank[i]] = start + i
		start += count
	return result


static func _fill_ranks(ranks: Array[int], n: int, w: int) -> void:
	var left := n
	while left > 0:
		ranks.append(mini(w, left))
		left -= w


static func _rank_sizes(slots: Array[Vector2i]) -> Array[int]:
	var sizes: Array[int] = []
	var last_back := -(1 << 40)
	for s in slots:
		if s.y != last_back:
			sizes.append(0)
			last_back = s.y
		sizes[-1] += 1
	return sizes
