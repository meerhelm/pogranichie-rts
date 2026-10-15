class_name TechDef
extends Resource
## One technology. Common techs have an empty faction and a common building id
## ("smithy"); resolve it per faction with FactionDef. Generated into data/techs/.
## effects: what the tech changes (manual.json → tech_effects): gather_<kind>, farm_food,
## zaseka_speed and zaseka_hp are per-mille increases; wall_sight adds cells of sight to towers
## and walls; "<class or unit id>.<stat>" adds to a unit stat (damage_melee, damage_pierce,
## armor_melee, armor_pierce, range, hp_permille).

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
@export var effects: Dictionary[StringName, int]
