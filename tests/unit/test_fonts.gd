extends GutTest
## The interface font has every letter the five languages need (plan M10).

const LETTERS := "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчшщъыьэюя"
const EXTRA := "ІіЎўЇїЄєҐґĄąĘęŁłŻżŹźĆćŃńÓóŚśĖėĮįŲųŪūČčŠšŽž’«»—–…"


func test_theme_fonts_cover_all_languages() -> void:
	var theme := load("res://ui/theme.tres") as Theme
	assert_not_null(theme)
	var fonts: Array[Font] = [theme.default_font, theme.get_font(&"font", &"Title")]
	for font in fonts:
		assert_not_null(font)
		var missing := ""
		for c in LETTERS + EXTRA:
			if not font.has_char(c.unicode_at(0)):
				missing += c
		assert_eq(missing, "", "%s lacks letters" % font.resource_path)


func test_project_uses_the_theme() -> void:
	assert_eq(ProjectSettings.get_setting("gui/theme/custom"), "res://ui/theme.tres")
