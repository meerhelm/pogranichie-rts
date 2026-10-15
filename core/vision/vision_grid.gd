class_name VisionGrid
extends RefCounted
## What one player sees, per map cell (M6). Every unit and building of the player stamps the
## cells around it: `far` counts the stamps that reach a cell, `near` those close enough to
## see into cover (forest). A cell is explored once any stamp has reached it.
## Stamps are added and taken away as units move, so the counts are always the sum of what
## sees the cell now; nothing is recomputed from scratch.

const SHADE_EXPLORED := 128
const SHADE_VISIBLE := 255

var width: int
var height: int
var far := PackedInt32Array()
var near := PackedInt32Array()
var explored := PackedByteArray()
## For drawing (not simulation state): 0 unexplored, SHADE_EXPLORED, SHADE_VISIBLE per cell, so
## the fog texture is one copy of this array instead of a loop over the map.
var shade := PackedByteArray()
## Grows on every change, for drawing (fog texture, minimap) to redraw only when needed.
var version := 0


func _init(w: int, h: int) -> void:
	width = w
	height = h
	far.resize(w * h)
	near.resize(w * h)
	explored.resize(w * h)
	shade.resize(w * h)


## Adds `amount` (+1 or -1) to `far` in the cells at (cx, cy) + each offset of `offsets`
## (dx, dy pairs); cells off the map are skipped. Adding also explores.
func add_far(cx: int, cy: int, offsets: PackedInt32Array, amount: int) -> void:
	var n := offsets.size()
	var i := 0
	while i < n:
		var x := cx + offsets[i]
		var y := cy + offsets[i + 1]
		i += 2
		if x < 0 or y < 0 or x >= width or y >= height:
			continue
		var c := y * width + x
		far[c] += amount
		if amount > 0:
			explored[c] = 1
			shade[c] = SHADE_VISIBLE
		elif far[c] == 0:
			shade[c] = SHADE_EXPLORED
	version += 1


func add_near(cx: int, cy: int, offsets: PackedInt32Array, amount: int) -> void:
	var n := offsets.size()
	var i := 0
	while i < n:
		var x := cx + offsets[i]
		var y := cy + offsets[i + 1]
		i += 2
		if x < 0 or y < 0 or x >= width or y >= height:
			continue
		near[y * width + x] += amount
	version += 1
