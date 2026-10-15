class_name BuildingDef
extends Resource
## One building. Common buildings are expanded per faction (gdl_barracks, to_barracks);
## base_id is the common id they come from. Generated into data/buildings/.

@export var id: StringName
@export var faction: StringName
@export var base_id: StringName
@export var age: int
@export var campaign_only: bool
@export var cost_food: int
@export var cost_wood: int
@export var cost_iron: int
@export var cost_silver: int
@export var cost_per_tile: bool
@export var cost_source: StringName
@export var build_ticks: int
@export var hp: int
@export var armor_melee: int
@export var armor_pierce: int
@export var pop_provided: int
@export var garrison: int
@export var accepts: Array[StringName]
@export var damage: int
@export var damage_type: StringName
@export var attack_range: int
@export var power_rate_milli: int
@export var trains: Array[StringName]
@export var tags: Array[StringName]
@export var params: Dictionary[StringName, int]


func param(key: StringName, default: int = 0) -> int:
	return params.get(key, default)
