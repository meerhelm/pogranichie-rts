class_name UiText
extends RefCounted
## Translated texts the HUD and menus share: resource names, costs, damage types, stances and
## why something cannot be built or queued. Every literal here goes through t(), so
## tools/i18n/extract.py finds it; game names are catalog ids, translated in i18n/*.po.


## The text in the current language (TranslationServer, for code outside the scene tree).
static func t(text: String) -> String:
	return TranslationServer.translate(text)


## Name of a unit, building, tech, age or faction from its catalog id.
static func name_of(id: StringName) -> String:
	return TranslationServer.translate(String(id))


static func resource(r: int) -> String:
	match r:
		EconomySystem.FOOD:
			return t("Food")
		EconomySystem.WOOD:
			return t("Wood")
		EconomySystem.IRON:
			return t("Iron")
		EconomySystem.SILVER:
			return t("Silver")
	return t("Power")


## "50 food, 20 wood", or "free".
static func cost(c: PackedInt32Array) -> String:
	var parts := PackedStringArray()
	for r in 4:
		if c[r] > 0:
			parts.append(t("%d %s") % [c[r], resource(r).to_lower()])
	return ", ".join(parts) if not parts.is_empty() else t("free")


static func damage_type(kind: StringName) -> String:
	match kind:
		Damage.MELEE:
			return t("melee")
		Damage.PIERCE:
			return t("pierce")
		Damage.FIREARM:
			return t("firearm")
		Damage.SIEGE:
			return t("siege")
	return ""


static func stance(s: int) -> String:
	match s:
		EntityStore.Stance.AGGRESSIVE:
			return t("Aggressive")
		EntityStore.Stance.DEFENSIVE:
			return t("Defensive")
		EntityStore.Stance.STAND:
			return t("Stand ground")
	return t("Passive")


static func formation(kind: int) -> String:
	match kind:
		Formation.Kind.COLUMN:
			return t("Column")
		Formation.Kind.WEDGE:
			return t("Wedge")
	return t("Line")


## Why a building cannot stand there or an item cannot be queued (EconomySystem.Fail).
static func fail(reason: int) -> String:
	match reason:
		EconomySystem.Fail.OK:
			return ""
		EconomySystem.Fail.FACTION:
			return t("Not for this faction")
		EconomySystem.Fail.AGE:
			return t("Needs a later age")
		EconomySystem.Fail.OUT_OF_MAP:
			return t("Off the map")
		EconomySystem.Fail.TERRAIN:
			return t("Cannot be built on this ground")
		EconomySystem.Fail.OCCUPIED:
			return t("The place is taken")
		EconomySystem.Fail.NOT_FOREST:
			return t("Must stand in the forest")
		EconomySystem.Fail.NO_FOREST_NEAR:
			return t("Needs forest nearby")
		EconomySystem.Fail.POWER_PLACE:
			return t("Only on a place of power")
		EconomySystem.Fail.COST:
			return t("Not enough resources")
		EconomySystem.Fail.QUEUE_FULL:
			return t("The queue is full")
		EconomySystem.Fail.LIMIT:
			return t("Population limit reached")
		EconomySystem.Fail.CONDITION:
			return t("Conditions not met")
		EconomySystem.Fail.LOCKED:
			return t("Not available yet in this mission")
	return t("Not available")


## Why a spell cannot be cast now (MagicSystem.Cast).
static func cast_fail(reason: int) -> String:
	match reason:
		MagicSystem.Cast.OK:
			return ""
		MagicSystem.Cast.AGE:
			return t("Needs a later age")
		MagicSystem.Cast.COOLDOWN:
			return t("Not ready yet")
		MagicSystem.Cast.POWER:
			return t("Not enough Power")
		MagicSystem.Cast.PASSIVE:
			return t("Always on")
	return t("Not available")


## "1:05" for game time in ticks.
static func clock(ticks: int) -> String:
	var seconds := ticks / Fixed.TICKS_PER_SECOND
	return "%d:%02d" % [seconds / 60, seconds % 60]
