class_name FireRulesDef
extends Resource
## Arson and fire (M9). Generated as data/rules/fire.tres from tools/catalog/manual.json
## (fire_rules). Any unit that fights can set a wooden building on fire; the fire eats its HP,
## jumps to wooden buildings around it, and the owner's free units nearby put it out.

@export var id: StringName
## Ticks a unit works at a building before it catches fire (a hero may have its own,
## UnitDef param ignite_ticks).
@export var ignite_ticks: int
## Ticks a fire takes to burn a building's full HP.
@export var burn_ticks: int
## Damage of a fire per-mille for buildings tagged burns_slowly.
@export var slow_burn_permille: int
## Ticks a fire takes to burn a zaseka (catalog: «огонь сжигает за 20 с»).
@export var zaseka_burn_ticks: int
## Every this many ticks a fire may jump to each flammable building within spread_cells,
## with chance spread_permille.
@export var spread_every_ticks: int
@export var spread_cells: int
@export var spread_permille: int
## The owner's free units within this many cells come to put the fire out...
@export var douse_radius_cells: int
## ...and need this many unit-ticks of work at the building.
@export var douse_ticks: int
