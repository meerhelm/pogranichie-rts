extends GutTest
## The main menu's pages and campaign progress: campaign, single player and network on the first
## page; a country choice; a campaign's missions open one after another as they are won and the
## progress is kept in a file; the Crown's planned missions are listed but cannot be played; a
## won mission (game scene) is recorded; back from a mission the menu opens on its campaign.

const MENU := preload("res://ui/main_menu.tscn")
const TEST_PATH := "user://test_campaign.cfg"

var _path_before := ""


func before_each() -> void:
	_path_before = CampaignProgress.path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	CampaignProgress.path = TEST_PATH
	CampaignProgress.reset()
	GameSettings.mission_id = ""


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	CampaignProgress.path = _path_before
	CampaignProgress.reset()
	GameSettings.mission_id = ""
	TranslationServer.set_locale("en")


func test_missions_open_one_after_another_and_are_kept() -> void:
	assert_true(CampaignProgress.is_open("gdl_01"))
	assert_false(CampaignProgress.is_open("gdl_02"))
	CampaignProgress.mark_won("gdl_01")
	assert_true(CampaignProgress.is_open("gdl_02"))
	assert_false(CampaignProgress.is_open("gdl_03"))
	assert_eq(CampaignProgress.won_count("gdl"), 1)
	CampaignProgress.reset()
	assert_true(CampaignProgress.is_won("gdl_01"), "read back from the file")
	assert_true(CampaignProgress.is_open("gdl_02"))


func test_every_gdl_mission_is_made_and_the_crown_is_begun() -> void:
	for id: String in CampaignProgress.MISSIONS["gdl"]:
		assert_true(CampaignProgress.is_made(id), id)
		assert_eq(CampaignProgress.campaign_of(id), "gdl")
	assert_true(CampaignProgress.is_open("crown_01"), "Корона 1 is made and opens first")
	for id: String in CampaignProgress.MISSIONS["crown"]:
		if id != "crown_01":
			assert_false(CampaignProgress.is_open(id), "%s cannot be played yet" % id)
		assert_string_starts_with(CampaignProgress.title_key(id), "Crown ")
	assert_eq(CampaignProgress.title_key("crown_01"), "Crown 1. Grunwald, 1410")
	assert_true(CampaignProgress.is_made("crown_02"), "Корона 2 is made")
	assert_eq(CampaignProgress.title_key("crown_02"), "Crown 2. Malbork, 1410")
	assert_true(CampaignProgress.is_made("crown_03"), "Корона 3 is made")
	assert_eq(CampaignProgress.title_key("crown_03"), "Crown 3. Baltic Water, 1433")
	assert_true(CampaignProgress.is_made("crown_04"), "Корона 4 is made")
	assert_eq(CampaignProgress.title_key("crown_04"), "Crown 4. Chojnice, 1454")
	assert_true(CampaignProgress.is_made("crown_05"), "Корона 5 is made")
	assert_eq(CampaignProgress.title_key("crown_05"), "Crown 5. Silver for Malbork, 1457")
	assert_true(CampaignProgress.is_made("crown_06"), "Корона 6 is made")
	assert_eq(CampaignProgress.title_key("crown_06"), "Crown 6. Świecino, 1462")
	assert_eq(CampaignProgress.title_key("gdl_08"), "GDL 8. Orsha, 1514")


func test_first_page_has_campaign_single_player_and_network() -> void:
	var menu: Control = MENU.instantiate()
	add_child_autofree(menu)
	assert_true(menu._menu.visible)
	assert_eq(menu._campaign_button.text, "Campaign")
	assert_eq(menu._single_button.text, "Single player")
	assert_false(menu._network.disabled, "network play is on")
	menu._network.pressed.emit()
	assert_true(menu._net.visible)
	assert_eq(menu._net.create.text, "Create a game")
	menu._net.back_button.pressed.emit()
	assert_true(menu._menu.visible)
	menu._single_button.pressed.emit()
	assert_true(menu._single.visible)
	assert_false(menu._menu.visible)
	assert_eq(menu._skirmish.text, "Skirmish")
	menu._back[2].pressed.emit()
	assert_true(menu._menu.visible)


func test_campaign_leads_to_countries_and_missions() -> void:
	var menu: Control = MENU.instantiate()
	add_child_autofree(menu)
	menu._campaign_button.pressed.emit()
	assert_true(menu._countries.visible)
	assert_eq(menu._country.size(), 2)
	assert_eq(menu._country[0].text, "Grand Duchy of Lithuania")
	assert_eq(menu._country[1].text, "Crown of Poland")
	assert_string_contains(menu._country_note[0].text, "missions won: 0 of 8")
	menu._country[0].pressed.emit()
	assert_true(menu._missions.visible)
	assert_eq(menu._campaign.size(), 8)
	assert_eq(menu._campaign[0].text, "GDL 1. Samogitian Fire")
	assert_false(menu._campaign[0].disabled)
	assert_true(menu._campaign[1].disabled, "the second opens after the first is won")
	assert_eq(menu._mission_state[0].text, "open")
	menu._back[1].pressed.emit()
	menu._country[1].pressed.emit()
	assert_eq(menu._campaign.size(), 6)
	assert_false(menu._campaign[0].disabled, "Корона 1 is open")
	assert_eq(menu._mission_state[0].text, "open")
	for i in range(1, 6):
		assert_true(menu._campaign[i].disabled)
	assert_eq(menu._mission_state[1].text, "win the previous mission to open")
	assert_eq(menu._mission_state[2].text, "win the previous mission to open")
	assert_eq(menu._mission_state[3].text, "win the previous mission to open")
	assert_eq(menu._mission_state[4].text, "win the previous mission to open")
	assert_eq(menu._mission_state[5].text, "win the previous mission to open")


func test_won_missions_show_and_open_the_next() -> void:
	CampaignProgress.mark_won("gdl_01")
	CampaignProgress.mark_won("gdl_02")
	var menu: Control = MENU.instantiate()
	add_child_autofree(menu)
	menu._open_campaign("gdl")
	assert_eq(menu._mission_state[0].text, "won")
	assert_eq(menu._mission_state[1].text, "won")
	assert_eq(menu._mission_state[2].text, "open")
	assert_false(menu._campaign[2].disabled)
	assert_true(menu._campaign[3].disabled)


func test_cheat_code_opens_every_mission_and_closes_them_back() -> void:
	CampaignProgress.mark_won("gdl_01")
	var menu: Control = MENU.instantiate()
	add_child_autofree(menu)
	menu._open_campaign("gdl")
	assert_true(menu._campaign[3].disabled)
	_type(menu, "XVITAUT")
	assert_true(CampaignProgress.all_open())
	assert_eq(menu._mission_state[0].text, "won", "a won mission stays won")
	assert_eq(menu._mission_state[7].text, "open")
	assert_false(menu._campaign[7].disabled)
	assert_eq(menu._cheat_note.text, "All campaign missions are open")
	for id: String in CampaignProgress.MISSIONS["crown"]:
		assert_true(CampaignProgress.is_open(id), id)
	assert_false(CampaignProgress.is_won("gdl_02"), "opened, not counted as won")
	CampaignProgress.reset()
	assert_true(CampaignProgress.is_open("crown_06"), "read back from the file")
	_type(menu, "VITAUT")
	assert_false(CampaignProgress.all_open())
	assert_true(CampaignProgress.is_open("gdl_02"))
	assert_false(CampaignProgress.is_open("gdl_03"))
	assert_true(menu._campaign[3].disabled)


func _type(menu: Control, word: String) -> void:
	for ch in word:
		var key := InputEventKey.new()
		key.pressed = true
		key.physical_keycode = ch.unicode_at(0) as Key
		menu._unhandled_input(key)


func test_a_won_mission_keeps_its_carried_flags() -> void:
	CampaignProgress.mark_won("crown_01", PackedStringArray(["captive"]))
	assert_true(CampaignProgress.is_won("crown_01"))
	assert_true(CampaignProgress.has_mark("crown_01", "captive"))
	assert_false(CampaignProgress.has_mark("crown_01", "pact"))
	CampaignProgress.reset()
	assert_true(CampaignProgress.has_mark("crown_01", "captive"), "read back from the file")
	CampaignProgress.mark_won("crown_01", PackedStringArray(["pact"]))
	assert_false(CampaignProgress.has_mark("crown_01", "captive"), "the new victory replaces it")
	assert_true(CampaignProgress.has_mark("crown_01", "pact"))


func test_back_from_a_mission_opens_its_campaign() -> void:
	GameSettings.mission_id = "gdl_03"
	var menu: Control = MENU.instantiate()
	add_child_autofree(menu)
	assert_true(menu._missions.visible)
	assert_eq(menu._shown, "gdl")


func test_pages_follow_the_language() -> void:
	var menu: Control = MENU.instantiate()
	add_child_autofree(menu)
	menu._open_campaign("crown")
	TranslationServer.set_locale("be")
	menu.propagate_notification(NOTIFICATION_TRANSLATION_CHANGED)
	assert_eq(menu._campaign_button.text, "Кампанія")
	assert_eq(menu._campaign[5].text, "Карона 6. Свеціна, 1462")
	assert_eq(menu._missions_head.text, "Карона Польская")


func test_single_player_picks_a_map_with_its_history_note() -> void:
	var was := GameSettings.skirmish_map
	var menu: Control = MENU.instantiate()
	add_child_autofree(menu)
	menu._single_button.pressed.emit()
	assert_eq(menu._map.item_count, SkirmishMaps.ids().size())
	var i := SkirmishMaps.ids().find("map_sk_orsha")
	menu._map.select(i)
	menu._map.item_selected.emit(i)
	assert_eq(GameSettings.skirmish_map, "map_sk_orsha")
	assert_eq(menu._map.get_item_text(i), "Map: Orsha, 1514")
	assert_string_starts_with(menu._map_note.text, "8 September 1514.")
	TranslationServer.set_locale("be")
	assert_eq(menu._map.get_item_text(i), "Карта: Орша, 1514")
	GameSettings.skirmish_map = was
	GameSettings.save()
