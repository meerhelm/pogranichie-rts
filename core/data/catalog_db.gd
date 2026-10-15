class_name CatalogDB
extends RefCounted
## Read access to the exported catalog in res://data/.
## CatalogDB.load_all() loads everything; CatalogDB.load_prototype() loads only what the
## prototype uses (factions, units, buildings, techs and spells listed in the index).

const DATA_DIR := "res://data"

var index: CatalogIndex
var units: Dictionary[StringName, UnitDef] = {}
var buildings: Dictionary[StringName, BuildingDef] = {}
var techs: Dictionary[StringName, TechDef] = {}
var spells: Dictionary[StringName, SpellDef] = {}
var factions: Dictionary[StringName, FactionDef] = {}
var ages: Dictionary[StringName, AgeDef] = {}
var power_places: Dictionary[StringName, PowerPlaceDef] = {}
var terrains: Dictionary[StringName, TerrainDef] = {}
## Combat and morale numbers (data/rules/combat.tres).
var rules: CombatRulesDef
## Gathering, construction and production numbers (data/rules/economy.tres).
var economy: EconomyRulesDef
## Fog of war numbers (data/rules/vision.tres).
var vision: VisionRulesDef


static func load_index() -> CatalogIndex:
	return load(DATA_DIR.path_join("catalog_index.tres")) as CatalogIndex


static func load_all() -> CatalogDB:
	var db := CatalogDB.new()
	db.index = load_index()
	db._load_ids(db.index.units, db.index.buildings, db.index.techs, db.index.spells)
	db._load_kind("factions", db.index.factions, db.factions)
	return db


static func load_prototype() -> CatalogDB:
	var db := CatalogDB.new()
	db.index = load_index()
	db._load_ids(
		db.index.prototype_units,
		db.index.prototype_buildings,
		db.index.prototype_techs,
		db.index.prototype_spells
	)
	db._load_kind("factions", db.index.prototype_factions, db.factions)
	return db


func unit(id: StringName) -> UnitDef:
	return units.get(id)


func building(id: StringName) -> BuildingDef:
	return buildings.get(id)


func tech(id: StringName) -> TechDef:
	return techs.get(id)


func spell(id: StringName) -> SpellDef:
	return spells.get(id)


func faction(id: StringName) -> FactionDef:
	return factions.get(id)


func terrain(id: StringName) -> TerrainDef:
	return terrains.get(id)


func age(id: StringName) -> AgeDef:
	return ages.get(id)


## The age with this index (1 Удел, 2 Хоругвь, 3 Держава), or null.
func age_by_index(index: int) -> AgeDef:
	for id: StringName in ages:
		if ages[id].index == index:
			return ages[id]
	return null


func _load_ids(
	unit_ids: Array[StringName],
	building_ids: Array[StringName],
	tech_ids: Array[StringName],
	spell_ids: Array[StringName]
) -> void:
	_load_kind("units", unit_ids, units)
	_load_kind("buildings", building_ids, buildings)
	_load_kind("techs", tech_ids, techs)
	_load_kind("spells", spell_ids, spells)
	_load_kind("ages", index.ages, ages)
	_load_kind("power_places", index.power_places, power_places)
	_load_kind("terrain", index.terrains, terrains)
	rules = load(DATA_DIR.path_join("rules/combat.tres")) as CombatRulesDef
	assert(rules != null, "catalog resource missing: rules/combat")
	economy = load(DATA_DIR.path_join("rules/economy.tres")) as EconomyRulesDef
	assert(economy != null, "catalog resource missing: rules/economy")
	vision = load(DATA_DIR.path_join("rules/vision.tres")) as VisionRulesDef
	assert(vision != null, "catalog resource missing: rules/vision")


func _load_kind(dir: String, ids: Array[StringName], into: Dictionary) -> void:
	for id in ids:
		var res: Resource = load(DATA_DIR.path_join(dir).path_join("%s.tres" % id))
		assert(res != null, "catalog resource missing: %s/%s" % [dir, id])
		into[id] = res


## Short hash of every loaded definition's stored fields. Replays keep it so playback can tell
## that the catalog numbers changed since recording (which changes the outcome).
func content_hash() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(index.exported_on.to_utf8_buffer())
	for kind: Dictionary in [
		units, buildings, techs, spells, factions, ages, power_places, terrains
	]:
		# Sort as String: StringName order follows interning, not text, and differs per run.
		var ids := PackedStringArray(kind.keys())
		ids.sort()
		for id in ids:
			ctx.update(_stored_fields(kind[StringName(id)]).to_utf8_buffer())
	if rules != null:
		ctx.update(_stored_fields(rules).to_utf8_buffer())
	if economy != null:
		ctx.update(_stored_fields(economy).to_utf8_buffer())
	if vision != null:
		ctx.update(_stored_fields(vision).to_utf8_buffer())
	return ctx.finish().hex_encode().left(16)


static func _stored_fields(res: Resource) -> String:
	var parts := PackedStringArray()
	for prop: Dictionary in res.get_property_list():
		var usage: int = prop["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_STORAGE:
			var prop_name: String = prop["name"]
			parts.append("%s=%s" % [prop_name, var_to_str(res.get(prop_name))])
	return "\n".join(parts)
