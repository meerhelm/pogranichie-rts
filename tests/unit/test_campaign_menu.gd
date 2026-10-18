extends GutTest
## The main menu's pages and campaign progress: campaign, single player and network on the first
## page; a country choice; a campaign's missions open one after another as they are won and the
## progress is kept in a file; the Crown's planned missions are listed but cannot be played; a
## won mission (game scene) is recorded; back from a mission the menu opens on its campaign.

const MENU := preload("res://ui/main_menu.tscn")
const TEST_PATH := "user://test_campaign.cfg"


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	CampaignProgress.path = TEST_PATH
	CampaignProgress.reset()
	GameSettings.mission_id = ""


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	CampaignProgress.path = CampaignProgress.PATH
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


func test_every_gdl_mission_is_made_and_the_crown_is_planned() -> void:
	for id: String in CampaignProgress.MISSIONS["gdl"]:
		assert_true(CampaignProgress.is_made(id), id)
		assert_eq(CampaignProgress.campaign_of(id), "gdl")
	for id: String in CampaignProgress.MISSIONS["crown"]:
		assert_false(CampaignProgress.is_open(id), "%s cannot be played yet" % id)
		assert_string_starts_with(CampaignProgress.title_key(id), "Crown ")
	assert_eq(CampaignProgress.title_key("gdl_08"), "GDL 8. Orsha, 1514")


func test_first_page_has_campaign_single_player_and_network() -> void:
	var menu: Control = MENU.instantiate()
	add_child_autofree(menu)
	assert_true(menu._menu.visible)
	assert_eq(menu._campaign_button.text, "Campaign")
	assert_eq(menu._single_button.text, "Single player")
	assert_true(menu._network.disabled, "network play comes later")
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
	for b: Button in menu._campaign:
		assert_true(b.disabled)
	assert_eq(menu._mission_state[0].text, "not made yet")


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
