class_name VisionRulesDef
extends Resource
## Fog of war rules (M6). Generated as data/rules/vision.tres from tools/catalog/manual.json
## (vision_rules); values listed there under `_temporary` are not in the catalog yet.
## How far a unit sees is its «обзор» from «Особое» or CombatRulesDef.sight_default; a finished
## building sees BuildingDef.param("sight") (manual.json → building_layout.sight). All in cells.

@export var id: StringName
## Units in cover (forest) are seen only this close.
@export var cover_reveal_cells: int
## A unit standing on a hill sees this much farther (t_hill «+2 обзора»).
@export var hill_sight_bonus: int
## A building still under construction sees this far.
@export var foundation_sight: int
