class_name CombatFlags
extends RefCounted
## Behaviour flags of a unit type, cached by CombatSystem per unit.


static func of(def: UnitDef, is_dismounted: bool) -> int:
	if def == null:
		return CombatSystem.F_NEVER_FLEES | CombatSystem.F_PASSIVE
	var f := 0
	var classes := CombatSystem.DISMOUNTED_CLASSES if is_dismounted else def.classes
	if classes.has(&"infantry"):
		f |= CombatSystem.F_INFANTRY
	if def.has_class(&"hero"):
		f |= CombatSystem.F_HERO
	if (
		def.never_flees
		or def.has_class(&"spiritual")
		or def.has_class(&"creature")
		or def.has_class(&"hero")
	):
		f |= CombatSystem.F_NEVER_FLEES
	if def.attack_range > 0:
		f |= CombatSystem.F_RANGED
	for tag: StringName in CombatSystem.TAG_FLAGS:
		if def.tags.has(tag):
			f |= CombatSystem.TAG_FLAGS[tag]
	for cls in CombatSystem.PASSIVE_CLASSES:
		if def.has_class(cls):
			f |= CombatSystem.F_PASSIVE
	if def.damage <= 0:
		f |= CombatSystem.F_PASSIVE
	return f
