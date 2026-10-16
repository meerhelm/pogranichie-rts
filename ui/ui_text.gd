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


## Name of a resource node of this ResourceNodes source (a deposit, a carcass, salvage).
static func node_name(source: int) -> String:
	match source:
		ResourceNodes.Source.IRON:
			return t("Bog ore")
		ResourceNodes.Source.SILVER:
			return t("Silver mine")
		ResourceNodes.Source.HUNT:
			return t("Carcass")
	return t("Salvage")


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
		EconomySystem.Fail.DISMANTLING:
			return t("Being taken apart")
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


## Where a resource comes from, for the top bar's tooltips.
static func resource_help(r: int) -> String:
	match r:
		EconomySystem.FOOD:
			return t("Food: peasants work a farm by the forest or a bort (hive) in it.")
		EconomySystem.WOOD:
			return t("Wood: right-click the forest with peasants.")
		EconomySystem.IRON:
			return t("Iron: right-click bog ore (brown blocks in the bog) with peasants.")
		EconomySystem.SILVER:
			return t("Silver: right-click a silver mine (grey blocks on a hill) with peasants.")
	return t("Power: build a shrine on a place of power; spells spend it.")


## What a building is for, in a line or two, for its button's tooltip.
static func building_help(def: BuildingDef, db: CatalogDB) -> String:
	var lines := PackedStringArray()
	var what := _building_purpose(def.base_id)
	if not what.is_empty():
		lines.append(what)
	if def.pop_provided > 0:
		lines.append(t("+%d population") % def.pop_provided)
	if not def.accepts.is_empty() and def.base_id != EconomySystem.TOWN_CENTER:
		var names := PackedStringArray()
		for res: StringName in def.accepts:
			names.append(resource(EconomySystem.RESOURCE_NAMES.find(res)).to_lower())
		lines.append(t("Peasants bring here: %s") % ", ".join(names))
	var trains := PackedStringArray()
	for id: StringName in def.trains:
		var unit := db.unit(id)
		if unit != null and not unit.campaign_only:
			trains.append(name_of(id))
	if not trains.is_empty():
		lines.append(t("Trains: %s") % ", ".join(trains))
	return "\n".join(lines)


static func _building_purpose(base_id: StringName) -> String:
	match base_id:
		&"town_center":
			return t("Trains peasants, takes every resource, leads to the next age.")
		&"house":
			return t("Room for more people: build one before training more.")
		&"farm":
			return t("A field by the forest: right-click it with a peasant for food.")
		&"bort":
			return t("A hive in the forest: two peasants gather honey (food).")
		&"granary":
			return t("A store near the fields, so peasants walk less.")
		&"lumber_yard":
			return t("A store at the forest edge, so woodcutters walk less.")
		&"mine":
			return t("A store by the ore or silver, so miners walk less.")
		&"barracks", &"range", &"stable", &"siege_workshop":
			return t("Trains troops: select it and press a button below.")
		&"shrine":
			return t("Stands only on a place of power; gives Power and trains casters.")
		&"palisade", &"wall":
			return t("A wall: drag to lay a line.")
		&"gate":
			return t("A gate in your wall that lets your own people through.")
		&"zaseka":
			return t("A felled-tree barrier, laid in the forest for free.")
		&"tower":
			return t("A watch tower that shoots at enemies.")
	return ""


## What a unit does, for the train button's tooltip ("" if nothing to add).
static func unit_help(def: UnitDef) -> String:
	if def != null and def.has_class(&"peasant"):
		return t("Gathers resources and builds.")
	return ""
