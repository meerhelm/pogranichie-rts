class_name AgeDef
extends Resource
## One age (Удел, Хоругвь, Держава) with its cost and research time. Generated into data/ages/.

@export var id: StringName
@export var index: int
@export var cost_food: int
@export var cost_wood: int
@export var cost_iron: int
@export var cost_silver: int
@export var research_ticks: int
@export var params: Dictionary[StringName, int]
