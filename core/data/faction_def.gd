class_name FactionDef
extends Resource
## What a faction has. tech_cost_permille scales the cost of listed common techs.
## Generated into data/factions/.

@export var id: StringName
@export var unit_ids: Array[StringName]
@export var building_ids: Array[StringName]
@export var tech_ids: Array[StringName]
@export var spell_ids: Array[StringName]
@export var tech_cost_permille: Dictionary[StringName, int]


## Faction copy of a common building: "barracks" -> "gdl_barracks".
func building_for(base_id: StringName) -> StringName:
	return StringName("%s_%s" % [id, base_id])
