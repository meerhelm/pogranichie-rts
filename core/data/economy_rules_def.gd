class_name EconomyRulesDef
extends Resource
## Gathering, construction and production rules (M5) that the catalog states in prose:
## «Обзор и правила» → «Эпохи, население, сбор», ВКЛ → «Засеки», Орден → «Кирпич». Generated as
## data/rules/economy.tres from tools/catalog/manual.json (economy_rules). Values listed there
## under `_temporary` are not in the catalog yet and are guesses to confirm.
## Units: _milli thousandths (of a resource unit per second, or of a cell), _permille multipliers,
## plain numbers are resource units, cells or people.

@export var id: StringName

@export_group("Gathering")
## A peasant carries this much before walking to a drop-off.
@export var carry: int
## Hard population limit of a player.
@export var pop_cap: int
## Gathering speed per second, in thousandths: field, hunt, hive, wood, iron, silver.
@export var gather_farm_milli: int
@export var gather_hunt_milli: int
@export var gather_bort_milli: int
@export var gather_wood_milli: int
@export var gather_iron_milli: int
@export var gather_silver_milli: int
## What one forest cell, a bog ore deposit and a silver mine hold.
@export var tree_wood: int
@export var bog_ore_iron: int
@export var silver_mine_silver: int
## How many peasants may work one hive and one field at a time.
@export var bort_workers: int
@export var farm_workers: int

@export_group("Construction")
## A zaseka is felled from this many forest cells in a row.
@export var zaseka_cells: int
## With the Order's brickworks: walls, towers and castles cost this much less wood, brick walls
## this much less silver.
@export var brick_wood_discount_permille: int
@export var brick_wall_silver_discount_permille: int

@export_group("Start")
@export var start_food: int
@export var start_wood: int
@export var start_iron: int
@export var start_silver: int

@export_group("Temporary")
## How close (thousandths of a cell) a worker must stand to a resource or building to work it.
@export var work_reach_milli: int
## How far a gatherer looks for more of the same resource when its own runs out.
@export var resource_search_cells: int
## Every builder after the first adds this much of one builder's speed.
@export var builder_extra_permille: int
## Repairing all of a building's HP costs this share of its price and takes this share of its
## build time.
@export var repair_cost_permille: int
@export var repair_time_permille: int
## Longest production queue of a building.
@export var queue_max: int
## Share of the price given back when a queued unit or tech is cancelled.
@export var cancel_refund_permille: int
## A building marked near_forest_only (ВКЛ подсека) needs forest this many cells around it.
@export var near_forest_cells: int
@export_group("Dismantling")
## Taking an own building apart gives back this share of its price, as salvage the peasants
## carry to storage (Valentin, 2026-10-16).
@export var dismantle_refund_permille: int
## Temporary: taking a building apart takes this share of the time its construction took so far.
@export var dismantle_time_permille: int
## Temporary: picking up salvage, thousandths of a unit a second.
@export var gather_salvage_milli: int

@export_group("Salt")
## A salt spring's own silver, mined like a deposit until the Crown's salt works covers it.
@export var salt_spring_silver: int
