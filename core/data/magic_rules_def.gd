class_name MagicRulesDef
extends Resource
## Places of power and spells (M7). Generated as data/rules/magic.tres from
## tools/catalog/manual.json (magic_rules); values listed there under `_temporary` are not in
## the catalog yet. Distances in cells, times in ticks, Сила in whole points.

@export var id: StringName
## A side holds a free place of power this long with nobody else in capture_radius to take it.
@export var capture_ticks: int
@export var capture_radius: int
## Сила a player can hold.
@export var power_cap: int
## A shrine within reach of another side's consecration gives this share of its Сила.
@export var consecration_permille: int
## Znakharki this close to their own alka recharge their spells this much faster.
@export var alka_recharge_permille: int
@export var alka_recharge_radius: int
## How far from the caster a spell aimed at a point may land.
@export var cast_range: int
## «Реликвия в строю»: own units' morale does not fall below this while above it; enemies who
## come near lose relic_enemy_morale once.
@export var relic_morale_floor: int
@export var relic_enemy_morale: int
## «Экзорцизм»: HP a creature loses before it is driven off.
@export var exorcism_creature_damage: int
## «Гнев Перкуна»: lightning strikes on the heaviest enemies under the storm, and HP each takes.
@export var storm_strikes: int
@export var storm_damage: int
## «Икона перед войском»: own units near the icon do not fall below this percent of their full
## morale while above it.
@export var icon_morale_floor: int

## «Богородица»: own units in the hymn get this much morale, and the fleeing ones come back.
@export var hymn_morale: int
## «Благословение хоругви»: the blessed unit's armor (both) and morale bonus.
@export var blessing_armor: int
@export var blessing_morale: int
## «Договор»: units under it lose no morale and strike this much harder (per mille).
@export var pact_damage_permille: int
## Healers whose rule names no radius heal their side this many cells around them.
@export var heal_radius_default: int
