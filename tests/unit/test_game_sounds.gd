extends GutTest
## Every unit answers with a sound that exists, and the sound ids the game asks for have files.

const ALERTS: Array[StringName] = [
	&"alert_attack_town",
	&"alert_attack_army",
	&"alert_building_done",
	&"alert_research_done",
	&"alert_no_resources",
	&"alert_message",
	&"alert_objective_new",
	&"alert_objective_done",
	&"alert_objective_failed",
	&"stinger_victory",
	&"stinger_defeat",
	&"ui_click",
	&"ui_tab",
	&"ui_queue",
	&"ui_cancel",
	&"ui_rally",
	&"ui_place_ok",
]


func _has_file(id: StringName) -> bool:
	return ResourceLoader.exists("%s%s_1.ogg" % [Sfx.DIR, id])


func test_every_unit_has_an_answer_for_select_move_and_attack() -> void:
	var db := CatalogDB.load_all()
	for def: UnitDef in db.units.values():
		for what: StringName in [&"select", &"move", &"attack"]:
			var found := false
			for sound in GameSounds.ack_sounds(def, what):
				if _has_file(sound):
					found = true
					break
			assert_true(found, "%s has no %s sound" % [def.id, what])


func test_alert_and_interface_sounds_have_files() -> void:
	for id in ALERTS:
		assert_true(_has_file(id), "no file for %s" % id)
	for f: String in ["gdl", "pl", "to", "mo"]:
		assert_true(_has_file(StringName("alert_unit_ready_%s" % f)))
		assert_true(_has_file(StringName("alert_age_up_%s" % f)))


func test_kinds_follow_the_unit_classes() -> void:
	var db := CatalogDB.load_all()
	assert_eq(GameSounds.ack_kind(db.unit(&"gdl_peasant")), &"peasant")
	assert_eq(GameSounds.ack_kind(db.unit(&"to_knight_brother")), &"hcav")
	assert_eq(GameSounds.ack_kind(db.unit(&"pl_crossbow")), &"crossbow")
	assert_eq(GameSounds.ack_kind(db.unit(&"gdl_forest_archer")), &"archer")
	assert_eq(GameSounds.ack_kind(db.unit(&"mo_moroz")), &"moroz")
	assert_eq(GameSounds.ack_kind(db.unit(&"pl_bombard")), &"siege")


func test_world_sounds_name_files_that_exist() -> void:
	for source: int in ResourceNodes.Source.values():
		assert_true(_has_file(WorldSounds._work_sound(source)), "work %d" % source)
	for id: String in ["pl_bombard", "mo_tyufyak", "gdl_porok", "pl_field_gun"]:
		assert_true(_has_file(WorldSounds._gun_sound(id)), id)
	for land: StringName in WorldSounds.LAND.values():
		assert_true(_has_file(land), String(land))
	for id in WorldSounds.MELEE:
		assert_true(_has_file(id), String(id))
	for f: String in ["gdl", "pl", "to", "mo"]:
		assert_true(ResourceLoader.exists("res://audio/music/%s_calm_1.ogg" % f), f)
