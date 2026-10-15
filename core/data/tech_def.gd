class_name TechDef
extends Resource
## One technology. Common techs have an empty faction and a common building id
## ("smithy"); resolve it per faction with FactionDef. Generated into data/techs/.

@export var id: StringName
@export var faction: StringName
@export var building: StringName
@export var age: int
@export var cost_food: int
@export var cost_wood: int
@export var cost_iron: int
@export var cost_silver: int
@export var research_ticks: int
@export var faith: bool
