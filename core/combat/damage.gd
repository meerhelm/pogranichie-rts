class_name Damage
extends RefCounted
## The damage formula from the catalog («Обзор и правила» → «Урон»), integers only:
##   max(1, damage − armor) + class bonus, then every multiplier (flank or rear, charge,
##   wavering, siege against units), rounded down once at the very end.
## Melee (Б) and siege (Ос) hit melee armor, arrows and bolts (С) pierce armor; firearms (О) count
## half the pierce armor, rounded down. The bonus is added after armor and armor never cuts it.

enum Side { FRONT, FLANK, REAR }

const MELEE := &"melee"
const PIERCE := &"pierce"
const FIREARM := &"firearm"
const SIEGE := &"siege"


## Everything one hit depends on. Fill it and call compute().
class Hit:
	extends RefCounted
	var damage := 0
	var damage_type := MELEE
	## Sum of the attacker's bonuses against the target's classes.
	var bonus := 0
	var armor_melee := 0
	var armor_pierce := 0
	var side: int = Side.FRONT
	## Other multipliers in per-mille (charge, wavering, «Разворот»), 1000 = none.
	var multipliers := PackedInt32Array()


## Damage of one hit, at least 1 before multipliers.
static func compute(hit: Hit, rules: CombatRulesDef) -> int:
	var armor := hit.armor_melee
	if hit.damage_type == PIERCE:
		armor = hit.armor_pierce
	elif hit.damage_type == FIREARM:
		armor = hit.armor_pierce * rules.firearm_pierce_armor_permille / 1000
	var total := maxi(1, hit.damage - maxi(armor, 0)) + hit.bonus
	var num := 1
	var den := 1
	if hit.side == Side.FLANK:
		num *= rules.flank_permille
		den *= 1000
	elif hit.side == Side.REAR:
		num *= rules.rear_permille
		den *= 1000
	if hit.damage_type == SIEGE:
		num *= rules.siege_vs_unit_permille
		den *= 1000
	for m in hit.multipliers:
		num *= m
		den *= 1000
	return total * num / den


## Sum of an attacker's «+N к …» bonuses that match the target's classes.
## One strike of a unit on a building: the formula against the building's armor; siege damage
## counts in full against buildings («Ос по постройкам берётся целиком»).
static func against_building(
	def: UnitDef, up_damage: int, bdef: BuildingDef, rules: CombatRulesDef
) -> int:
	var hit := Hit.new()
	hit.damage = def.damage + up_damage
	hit.damage_type = MELEE if def.damage_type == SIEGE else def.damage_type
	hit.bonus = bonus_against(def.bonuses, [&"building"])
	hit.armor_melee = bdef.armor_melee
	hit.armor_pierce = bdef.armor_pierce
	return compute(hit, rules)


static func bonus_against(bonuses: Dictionary[StringName, int], classes: Array[StringName]) -> int:
	var sum := 0
	for cls in classes:
		sum += bonuses.get(cls, 0)
	return sum


## Where a hit comes from, seen by the target: the attacker's direction against the way the target
## faces. Front and rear are the 90° cones ahead and behind, flanks are the rest.
## (dx, dy) points from the target to the attacker; (fx, fy) is the target's facing.
static func side_of(dx: int, dy: int, fx: int, fy: int) -> int:
	var along := dx * fx + dy * fy
	var across := absi(dx * fy - dy * fx)
	if along >= across:
		return Side.FRONT
	if -along > across:
		return Side.REAR
	return Side.FLANK
