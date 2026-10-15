class_name AiProfile
extends Resource
## How one skirmish AI plays (M8): its build order, army and the knobs that make it easy or
## normal. These are the AI's habits, not game rules: every price, speed and limit still comes
## from the catalog. Profiles live in ai/profiles/<faction>_<difficulty>.tres.

@export var faction: StringName
## easy or normal; the name shown in the menu is the profile's difficulty.
@export var difficulty: StringName
## The AI thinks once every this many ticks.
@export var think_ticks := 10
## Peasants to keep (the town centre trains them while there are fewer).
@export var peasant_target := 30
## How peasants are shared out, in parts: food, wood, iron, silver.
@export var worker_split := PackedInt32Array([45, 35, 12, 8])
## What to build in order, beyond houses and fields (those follow need): building base ids
## (lumber_yard, barracks...) with the faction prefix left out, or `age` for the next age.
@export var build_order: Array[StringName] = []
## Units to train, taken in turn; a unit the AI cannot train yet is skipped.
@export var army: Array[StringName] = []
## Units in the first attack wave, how many more each next wave takes, and the most.
@export var first_wave := 8
@export var wave_growth := 4
@export var max_wave := 40
## No wave leaves before this tick.
@export var first_attack_tick := 9600
## A wave whose strength falls below this share (per-mille) of the enemy it sees retreats home;
## 0 never retreats.
@export var retreat_permille := 600
## Enemies this close (cells) to own buildings are a threat to the base.
@export var defend_cells := 14
## Places of power to take and lay a shrine on, nearest first.
@export var shrines := 1
## Spiritual units cast their spells when they can.
@export var casts_spells := true
