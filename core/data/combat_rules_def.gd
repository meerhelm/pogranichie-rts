class_name CombatRulesDef
extends Resource
## Combat and morale rules (M4) that the catalog states in prose: «Обзор и правила» → «Урон» and
## «Боевой дух», ВКЛ → «Литовский отход», «Сверка статов» for the arena. Generated as
## data/rules/combat.tres from tools/catalog/manual.json (combat_rules). Values listed there
## under `_temporary` are not in the catalog yet and are guesses to confirm.
## Units: _ticks at 20 per second, _permille multipliers, _milli thousandths of a cell; plain
## numbers are cells or morale points.

@export var id: StringName

@export_group("Damage")
## Hit from the side ×1,25, from behind ×1,5.
@export var flank_permille: int
@export var rear_permille: int
## Firearms (О) count only half of the target's pierce armor, rounded down.
@export var firearm_pierce_armor_permille: int
## Siege damage (Ос) against units: divided by 4.
@export var siege_vs_unit_permille: int
## Shots at a target standing in the forest miss this often.
@export var forest_miss_permille: int
## Shooting from a hill: +1 range.
@export var hill_range_bonus: int
## Run-up for a charge when the unit's «Особое» names none.
@export var charge_distance_default: int

@export_group("Morale")
## −1 for every 10% of HP the unit has lost.
@export var morale_per_tenth_hp: int
## −10 when a unit of the same side dies this close.
@export var neighbour_death_morale: int
@export var neighbour_radius_milli: int
## −10 for a hit in the flank, −20 in the rear.
@export var flank_hit_morale: int
@export var rear_hit_morale: int
## −5 for a firearm hit, −15 for a cannon hit within 2 cells.
@export var firearm_hit_morale: int
@export var cannon_volley_morale: int
@export var cannon_volley_radius: int
## A commanding hero gives +15 within 8 cells.
@export var hero_aura_morale: int
@export var hero_aura_radius: int
## Infantry in close order: +5 with at least formation_neighbours own infantry this close.
@export var formation_morale: int
@export var formation_neighbours: int
@export var formation_radius_milli: int
## At or below 25 a unit wavers and deals 20% less damage.
@export var waver_morale: int
@export var waver_damage_permille: int
## At 0 a unit flees to its rally point and ignores orders for 20 seconds.
@export var flee_ticks: int
## Out of combat (no hits given or taken for out_of_combat_ticks) morale comes back 2 a second.
@export var morale_recovery_per_second: int
@export var out_of_combat_ticks: int

@export_group("Behaviour")
## How far a unit notices enemies when its «Особое» gives no «обзор».
@export var sight_default: int
## Centre-to-centre distance at which melee units strike.
@export var melee_reach_milli: int
## A unit chases a target that turned to flee at most this far.
@export var pursuit_cells: int
## Defensive stance: how far from its post a unit follows an enemy before going back.
@export var defensive_leash_cells: int
## Flight speed of arrows, bolts and javelins, thousandths of a cell per second.
@export var projectile_speed_milli: int
## A forest archer that shot stays visible this long.
@export var stealth_reveal_ticks: int
## A dismounted Prussian rider walks at infantry speed.
@export var dismount_speed_milli: int

@export_group("Lithuanian retreat")
## The unit turns and rides 8 cells toward its rally point, 6 s without morale loss, 30% faster.
@export var retreat_cells: int
@export var retreat_fearless_ticks: int
@export var retreat_speed_permille: int
## Its pursuers lose order for 10 s: −2 melee armor.
@export var retreat_disorder_ticks: int
@export var retreat_disorder_armor: int
## «Разворот» within 10 s: +3 damage and a ×1,25 charge on the next hit.
@export var turn_window_ticks: int
@export var turn_damage_bonus: int
@export var turn_charge_permille: int
@export var retreat_cooldown_ticks: int

@export_group("Banner")
## A khorugv's banner (ВКЛ 2): own units this close to a bearer get this much morale.
@export var banner_morale: int
@export var banner_radius: int

@export_group("Balance arena")
## Armies for equal money: 1200 resources, iron counts ×1,5 and silver ×2.
@export var arena_budget: int
@export var arena_iron_permille: int
@export var arena_silver_permille: int
