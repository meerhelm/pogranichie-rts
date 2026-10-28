extends SceneTree
## Lays out the building cards of tools/art/building_cards.py in the game's own frame, fonts and
## resource icons and saves one PNG per building (needs a display):
##   godot -s tools/art/building_cards.gd -- <dir with cards.json>
## Cards go to <dir>/cards/<NN>_<id>.png. Text is the catalog's (Russian), a review sheet, not UI.

const SIZE := Vector2i(1280, 720)
const THEME := "res://ui/theme.tres"
const RES_ICONS := ["food", "wood", "iron", "silver"]
const RES_NAMES := ["еда", "дерево", "железо", "серебро"]  # notr
const SERIF := "res://ui/fonts/PT_Serif-Web-Bold.ttf"

var _dir := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else "user://cards"
	root.size = SIZE
	_run.call_deferred()


func _run() -> void:
	var cards: Array = JSON.parse_string(
		FileAccess.get_file_as_string(_dir.path_join("cards.json"))
	)
	DirAccess.make_dir_recursive_absolute(_dir.path_join("cards"))
	var theme: Theme = load(THEME)
	var n := 0
	for card: Dictionary in cards:
		n += 1
		var ui := _card(card, theme)
		root.add_child(ui)
		for _i in 3:
			await process_frame
		var img := root.get_texture().get_image().get_region(Rect2i(Vector2i.ZERO, SIZE))
		img.save_png(_dir.path_join("cards/%02d_%s.png" % [n, card["id"]]))
		ui.queue_free()
		await process_frame
	print("cards saved: %d" % n)
	quit(0)


func _label(text: String, size: int, color := Color(0.92, 0.87, 0.77), serif := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	if serif:
		l.add_theme_font_override(&"font", load(SERIF))
	return l


func _row(title: String, value: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	var t := _label(title, 22, Color(0.75, 0.68, 0.55))
	t.custom_minimum_size.x = 150
	h.add_child(t)
	h.add_child(_label(value, 22))
	return h


func _card(card: Dictionary, theme: Theme) -> Control:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.04)
	bg.size = Vector2(SIZE)
	var panel := PanelContainer.new()
	panel.theme = theme
	panel.size = Vector2(SIZE)
	bg.add_child(panel)
	var m := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 26)
	panel.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 10)
	m.add_child(v)
	v.add_child(_label(str(card["name"]), 40, Color(1.0, 0.93, 0.78), true))
	var fmt := "%s  ·  эпоха «%s»  ·  %s клеток"  # notr
	var sub := fmt % [card["faction"], card["age"], card["cells"]]
	v.add_child(_label(sub, 22, Color(0.78, 0.7, 0.56)))
	var orn := PanelContainer.new()
	orn.theme_type_variation = &"Ornament"
	orn.custom_minimum_size.y = 22
	v.add_child(orn)
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 24)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"PortraitFrame"
	frame.custom_minimum_size = Vector2(700, 0)
	h.add_child(frame)
	var pic := TextureRect.new()
	pic.texture = ImageTexture.create_from_image(Image.load_from_file(str(card["img"])))
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var well := ColorRect.new()
	well.color = Color(0.16, 0.2, 0.12)
	well.add_child(pic)
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	frame.add_child(well)
	var info := VBoxContainer.new()
	info.add_theme_constant_override(&"separation", 12)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	info.add_child(_label("Стоимость", 24, Color(1.0, 0.93, 0.78), true))  # notr
	var cost: Array = card["cost"]
	if cost.is_empty() or str(card["cost_note"]) != "":
		var note := _label(str(card["cost_note"]), 22)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(note)
	if not cost.is_empty():
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override(&"h_separation", 10)
		for i in 4:
			if Num.of(cost[i]) == 0:
				continue
			var icon := TextureRect.new()
			icon.texture = load("res://ui/icons/%s.svg" % RES_ICONS[i])
			icon.custom_minimum_size = Vector2(30, 30)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			grid.add_child(icon)
			grid.add_child(_label("%d  %s" % [Num.of(cost[i]), RES_NAMES[i]], 24))
		if grid.get_child_count() == 0:
			info.add_child(_label("бесплатно", 22))  # notr
		info.add_child(grid)
	info.add_child(_row("Стройка", "%s с" % card["build_time"]))  # notr
	info.add_child(_row("Прочность", str(card["hp"])))  # notr
	info.add_child(_row("Броня", "%s (ближн. / стрелы)" % card["armor"]))  # notr
	info.add_child(_label("Что даёт", 24, Color(1.0, 0.93, 0.78), true))  # notr
	var eff := _label(str(card["effect"]), 22)
	eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	eff.custom_minimum_size.x = 460
	info.add_child(eff)
	return bg
