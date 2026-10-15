class_name UnitDef
extends Resource
## One unit from the catalog. Generated into data/units/ by tools/catalog/export.py.
## Times are in ticks (20 per second), speed in thousandths of a cell per second,
## multipliers in per-mille. params holds rule numbers from «Особое» (see tools/catalog/rules.py).

@export var id: StringName
@export var faction: StringName
@export var age: int
@export var campaign_only: bool
@export var trained_at: Array[StringName]
@export var spawned_by: StringName
@export var cost_food: int
@export var cost_wood: int
@export var cost_iron: int
@export var cost_silver: int
@export var cost_power: int
@export var cost_debt: int
@export var train_ticks: int
@export var pop: int
@export var hp: int
@export var damage: int
@export var damage_type: StringName
@export var shots: int
@export var reload_ticks: int
@export var attack_range: int
@export var min_range: int
@export var armor_melee: int
@export var armor_pierce: int
@export var speed_milli: int
@export var morale: int
@export var never_flees: bool
@export var classes: Array[StringName]
@export var bonuses: Dictionary[StringName, int]
@export var tags: Array[StringName]
@export var params: Dictionary[StringName, int]
@export var same_as: StringName
@export var food_yield: int
@export var lifetime_ticks: int


func has_class(cls: StringName) -> bool:
	return classes.has(cls)


## A rule number from «Особое», or default when the unit has no such rule.
func param(key: StringName, default: int = 0) -> int:
	return params.get(key, default)
