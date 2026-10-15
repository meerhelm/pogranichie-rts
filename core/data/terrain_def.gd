class_name TerrainDef
extends Resource
## One terrain tile from the catalog («Локации» → «Тайлы и рельеф»). Generated into
## data/terrain/. Speed multipliers are in per-mille; 0 where the tile is impassable.

@export var id: StringName
## Ground units can enter (false for old forest, quagmire, water).
@export var passable: bool
## Only boats move here (water).
@export var boats_only: bool
## Speed multiplier for foot units, carts and animals.
@export var infantry_permille: int
@export var cavalry_permille: int
## Extra multiplier when entering this tile from a lower one (hill ×0,9 «вверх»); 1000 = none.
@export var uphill_permille: int
## Siege units cannot cross (ford).
@export var siege_blocked: bool
