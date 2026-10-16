class_name Breach
extends RefCounted
## Breaking in: a unit sent to attack a building it cannot walk up to (behind a palisade, a
## wall or a gate closed to it) attacks the piece of the enclosure in its way instead: the
## enemy wall, gate or tower near it that is closest to the building it was sent at.

## How far from the unit (cells, Chebyshev) a piece of the enclosure may be.
const CELLS := 3
## What an enclosure is made of.
const BASES: Array[StringName] = [&"palisade", &"gate", &"wall", &"tower"]


## True when the unit's side cannot walk from `from_cell` up to building `b`: no open cell
## around it lies in the unit's area or in one its own gates join to that area.
static func cut_off(
	nav: NavGrid, buildings: BuildingStore, cls: int, player: int, from_cell: int, b: int
) -> bool:
	var home := nav.area(cls, from_cell)
	if home < 0:
		return false
	var s := b - 1
	var x0 := buildings.cell_x[s] - 1
	var y0 := buildings.cell_y[s] - 1
	var x1 := buildings.cell_x[s] + buildings.w[s]
	var y1 := buildings.cell_y[s] + buildings.h[s]
	var seen := false
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if (x != x0 and x != x1 and y != y0 and y != y1) or not nav.in_bounds(x, y):
				continue
			var a := nav.area(cls, y * nav.width + x)
			if a < 0:
				continue
			seen = true
			if a == home or nav.gate_linked(player, cls, home, a):
				return false
	return seen


## The piece of an enclosure for `player`'s unit at `cell` to break on the way to building
## `goal`, or BuildingStore.NO_ID when there is none within CELLS. Any other side's piece;
## the one nearest to the goal wins, ties to the lower id.
static func target(
	nav: NavGrid, buildings: BuildingStore, player: int, cell: int, goal: int
) -> int:
	var cx := cell % nav.width
	var cy := cell / nav.width
	var gx := buildings.center_x(goal)
	var gy := buildings.center_y(goal)
	var best := BuildingStore.NO_ID
	var best_d := 0
	for y in range(maxi(cy - CELLS, 0), mini(cy + CELLS + 1, nav.height)):
		for x in range(maxi(cx - CELLS, 0), mini(cx + CELLS + 1, nav.width)):
			var b := buildings.occupant[y * nav.width + x]
			if b == BuildingStore.NO_ID or b == best:
				continue
			var s := b - 1
			var owner := buildings.owners[s]
			if owner == player or owner == 0 or not BASES.has(buildings.defs[s].base_id):
				continue
			var d := buildings.distance_sq(b, gx, gy)
			if best == BuildingStore.NO_ID or d < best_d or (d == best_d and b < best):
				best = b
				best_d = d
	return best
