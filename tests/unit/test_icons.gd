extends GutTest
## Every HUD button of the prototype has a picture (IconDB), and building tooltips say what the
## building is for (Tips).

const ORDERS: Array[String] = [
	"stop",
	"aggressive",
	"defensive",
	"stand_ground",
	"line",
	"column",
	"wedge",
	"retreat",
	"turn",
	"dismount",
	"take_apart"
]


func test_every_prototype_button_has_an_icon() -> void:
	var db := CatalogDB.load_prototype()
	var missing := PackedStringArray()
	for id: StringName in db.buildings:
		var b: BuildingDef = db.buildings[id]
		if b.campaign_only:
			continue
		if IconDB.of(id) == null:
			missing.append(id)
		for u in b.trains:
			var unit := db.unit(u)
			if unit != null and unit.faction == b.faction and not unit.campaign_only:
				if IconDB.of(u) == null:
					missing.append(u)
	for f: StringName in db.factions:
		for t in db.faction(f).tech_ids:
			if db.techs.has(t) and not db.techs[t].effects.is_empty() and IconDB.of(t) == null:
				missing.append(t)
	for id: StringName in db.spells:
		if not db.spells[id].tags.has(&"passive") and IconDB.of(id) == null:
			missing.append(id)
	if IconDB.of(&"age_khorugv") == null:
		missing.append("age_khorugv")
	for o in ORDERS:
		if IconDB.order(o) == null:
			missing.append(o)
	assert_eq(missing, PackedStringArray(), "buttons without an icon")


func test_building_tips_tell_what_it_is_for_and_what_it_gives() -> void:
	var db := CatalogDB.load_prototype()
	var house := db.building(&"gdl_house")
	assert_string_contains(Tips.purpose(house), "Homes for your people")
	assert_has(Tips.gives(house, db), "+5 population")
	var tip := Tips.order("stop", "Stop", "H", "Stop what they are doing and stand.")
	assert_string_contains(tip.bbcode(), IconDB.order("stop").resource_path)
	assert_eq(tip.plain_text(), "Stop (H)\nStop what they are doing and stand.")
	for id: StringName in db.buildings:
		var def: BuildingDef = db.buildings[id]
		if not def.campaign_only:
			assert_ne(Tips.purpose(def), "", "%s has no purpose text" % id)
