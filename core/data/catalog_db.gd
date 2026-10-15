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


func _load_kind(dir: String, ids: Array[StringName], into: Dictionary) -> void:
	for id in ids:
		var res: Resource = load(DATA_DIR.path_join(dir).path_join("%s.tres" % id))
		assert(res != null, "catalog resource missing: %s/%s" % [dir, id])
		into[id] = res
