class_name SpellDef
extends Resource
## One spell. casters are unit, building or hero ids. Generated into data/spells/.

@export var id: StringName
@export var faction: StringName
@export var casters: Array[StringName]
@export var age: int
@export var power_cost: int
@export var debt_cost: int
@export var cooldown_ticks: int
@export var radius: int
@export var duration_ticks: int
@export var tags: Array[StringName]
@export var params: Dictionary[StringName, int]
