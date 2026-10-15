class_name SkirmishRulesDef
extends Resource
## How a skirmish is won (M8). Generated as data/rules/skirmish.tres from
## tools/catalog/manual.json (skirmish_rules). A side whose capital and castles are all destroyed
## is out; a side that holds every place of power on the map this long wins outright.

@export var id: StringName
## Ticks one side must hold all places of power in a row to win (concept doc: 5 minutes).
@export var hold_all_places_ticks: int
