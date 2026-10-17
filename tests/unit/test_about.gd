extends GutTest
## The version and «About the game»: ui/changelog.json starts with the version in project.godot,
## every build has items with English text, the main menu shows the version and opens the
## page, and a language change before the menu is ready does not break it.

const LOCALES: Array[String] = ["en", "be", "pl", "uk", "lt"]
const MENU := preload("res://ui/main_menu.tscn")


func after_each() -> void:
	TranslationServer.set_locale("en")


func test_changelog_starts_with_the_project_version() -> void:
	var builds := AboutPanel.versions()
	assert_gt(builds.size(), 0)
	var top: Dictionary = builds[0]
	assert_eq(str(top.get("version")), AboutPanel.version())
	assert_ne(AboutPanel.version(), "")


func test_every_build_has_dated_items_in_every_language() -> void:
	var seen := {}
	for entry: Variant in AboutPanel.versions():
		var build: Dictionary = entry
		var version := str(build.get("version", ""))
		assert_false(seen.has(version), "version %s twice" % version)
		seen[version] = true
		assert_eq(str(build.get("date", "")).length(), 10, version)
		var items: Array = build.get("items", [])
		assert_gt(items.size(), 0, version)
		for raw: Variant in items:
			var item: Dictionary = raw
			for lang in LOCALES:
				assert_false(
					str(item.get(lang, "")).is_empty(), "%s %s: %s" % [version, lang, item]
				)


func test_item_falls_back_to_english() -> void:
	TranslationServer.set_locale("lt")
	assert_eq(AboutPanel.item_text({"en": "Towers", "lt": "Bokštai"}), "Bokštai")
	assert_eq(AboutPanel.item_text({"en": "Towers"}), "Towers")


func test_main_menu_shows_the_version_and_opens_about() -> void:
	var menu: Control = MENU.instantiate()
	add_child_autofree(menu)
	assert_eq(menu._version.text, "Version %s" % AboutPanel.version())
	assert_eq(menu._about_button.text, "About the game")
	menu._about_button.pressed.emit()
	assert_true(menu._about.visible)
	var page: String = menu._about.page()
	assert_string_contains(page, "Version 0.0.1")
	assert_string_contains(page, "Version %s" % AboutPanel.version())
	TranslationServer.set_locale("be")
	menu.propagate_notification(NOTIFICATION_TRANSLATION_CHANGED)
	assert_eq(menu._version.text, "Версія %s" % AboutPanel.version())
	assert_string_contains(menu._about.page(), "Версія 0.0.1")


func test_language_change_before_ready_does_not_break_the_menu() -> void:
	var menu: Control = MENU.instantiate()
	menu._retranslate()
	add_child_autofree(menu)
	assert_eq(menu._campaign.size(), menu.MISSIONS.size())
	assert_false(menu._campaign[0].text.is_empty())
