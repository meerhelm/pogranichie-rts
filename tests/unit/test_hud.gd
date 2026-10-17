extends GutTest
## M6 in the game scene: the fog hides the enemy, the HUD shows the stock and what is selected,
## its buttons give the same orders as the keys, the minimap moves the camera, the menu pauses,
## and the interface follows the chosen language.

var _main: Node2D
var _input: PlayerInput
var _hud: Hud
var _sim: Simulation


func before_each() -> void:
	TranslationServer.set_locale("en")
	var scene: PackedScene = load("res://game/main.tscn")
	_main = scene.instantiate()
	add_child_autofree(_main)
	_main.get_node("SimClock").paused = true
	_input = _main.get_node("UI/PlayerInput")
	_hud = _main.get_node("UI/Hud")
	_sim = _main.sim
	_sim.step()
	_hud.refresh()


func after_each() -> void:
	get_tree().paused = false
	TranslationServer.set_locale("en")


func _own(type: StringName) -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in _sim.entities.alive_ids:
		if _sim.entities.type_ids[id - 1] == type and _sim.entities.owners[id - 1] == 1:
			out.append(id)
	return out


## The skirmish starts without an army (M8): a few spearmen for the tests that need fighters.
func _spearmen() -> PackedInt32Array:
	for i in 4:
		var x := Fixed.from_cells(14 + i) + Fixed.HALF
		_sim.enqueue(SimCommand.spawn(_sim.tick, 1, &"gdl_spearman", x, Fixed.from_cells(14)))
	_sim.step()
	return _own(&"gdl_spearman")


func _select(ids: PackedInt32Array) -> void:
	var points := PackedVector2Array()
	points.resize(ids.size())
	_input.selection.box(Rect2(-1, -1, 2, 2), ids, points, false)


func _buttons(box: Container) -> Array[Button]:
	var out: Array[Button] = []
	for child in box.get_children():
		if child is Button and not child.is_queued_for_deletion():
			out.append(child as Button)
	return out


func test_enemy_is_hidden_by_the_fog_and_own_is_drawn() -> void:
	var units: UnitLayer = _main.get_node("World/Units")
	units._on_ticked(_sim.tick)
	var seen_enemy := 0
	var own := 0
	for id: int in units.views:
		var v := units.views[id]
		if v.player == 2 and v.visible:
			seen_enemy += 1
		elif v.player == 1 and v.visible:
			own += 1
	assert_eq(seen_enemy, 0, "the Order's peasants across the map are in the fog")
	assert_eq(own, SkirmishSetup.START_PEASANTS)
	var fog: FogLayer = _main.get_node("World/Fog")
	assert_true(fog.visible)
	var g: VisionGrid = _sim.vision.grids[1]
	var far_corner := _sim.nav.cell_at(_sim.nav.width - 1, _sim.nav.height - 1)
	assert_eq(g.shade[far_corner], 0, "unexplored")
	assert_eq(g.shade[_sim.nav.cell_at(7, 7)], VisionGrid.SHADE_VISIBLE, "around the court")


func test_top_bar_shows_stock_population_and_age() -> void:
	var state := _sim.economy.player(1)
	var food: Label = _hud._resources[0]
	assert_eq(food.text, str(state.stock[0]))
	assert_string_contains(food.tooltip_text, "Food", "the name is in the tooltip")
	assert_string_contains(_hud._population.text, "%d/" % state.pop_used())
	assert_eq(_hud._age.text, "Appanage")
	assert_eq(_hud._time.text, "0:00")


func test_unit_card_shows_hp_morale_and_stance() -> void:
	var spear := _spearmen()
	_select(PackedInt32Array([spear[0]]))
	_hud.refresh()
	assert_eq(_hud.card._title.text, "Boar-Spear Militia")
	assert_true(_hud.card._morale.visible, "morale bar")
	assert_string_contains(_hud.card._lines.text, "Stance: Aggressive")
	_select(spear)
	_hud.refresh()
	assert_eq(_hud.card._title.text, "%d units" % spear.size())


func test_order_buttons_give_the_same_commands_as_keys() -> void:
	var spear := _spearmen()
	_select(spear)
	_hud.refresh()
	var stand: IconButton = null
	for b in _buttons(_hud.commands._orders):
		if b.caption == "Stand ground":
			stand = b
	assert_not_null(stand)
	stand.pressed.emit()
	_sim.step()
	for id in spear:
		assert_eq(_sim.entities.stance[id - 1], EntityStore.Stance.STAND)


func test_peasants_get_build_buttons_with_prices() -> void:
	_select(_own(&"gdl_peasant"))
	_hud.refresh()
	var buttons := _buttons(_hud.commands._build)
	assert_gt(buttons.size(), 5)
	var house: IconButton = _hud.commands._build_buttons[&"gdl_house"]
	assert_eq(house.caption, "Hut")
	assert_string_contains(house.tooltip_text, "wood")
	house.pressed.emit()
	assert_eq(_input.placing, _sim.economy.db.building(&"gdl_house"))
	_hud.refresh()
	assert_string_contains(_hud._placing.text, "Hut")


func test_building_buttons_queue_and_cancel() -> void:
	var center := _sim.economy.buildings.alive_ids[0]
	_input.selected_building = center
	_input.selection.clear()
	_hud.refresh()
	var peasant: Button = _hud.commands._item_buttons[&"gdl_peasant"]
	assert_string_contains(peasant.tooltip_text, "food")
	assert_string_contains(peasant.tooltip_text, "Peasant (X)", "its key")
	assert_false(peasant.disabled)
	peasant.pressed.emit()
	_sim.step()
	assert_eq(_sim.economy.buildings.queues[center - 1].size(), 1)
	_hud.refresh()
	var queued := _buttons(_hud.commands._queue)
	assert_eq(queued.size(), 1)
	queued[0].pressed.emit()
	_sim.step()
	assert_eq(_sim.economy.buildings.queues[center - 1].size(), 0, "cancelled")


func test_minimap_click_moves_the_camera() -> void:
	var camera: RtsCamera = _main.get_node("Camera")
	# Containers lay out on the next frame; give the minimap its size now.
	_hud.minimap.size = Vector2(320, 180)
	var target := Vector2(60, 60)
	var local := _hud.minimap.local_of_cell(target)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = local
	_hud.minimap._gui_input(ev)
	assert_almost_eq(camera.position.x, Iso.cell_to_screen(target).x, 1.0)
	assert_almost_eq(camera.position.y, Iso.cell_to_screen(target).y, 1.0)


func test_escape_with_nothing_selected_opens_the_menu_and_pauses() -> void:
	_input.selection.clear()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_ESCAPE
	key.pressed = true
	_input._key(key)
	assert_true(_hud.menu.visible)
	assert_true(get_tree().paused)
	_hud.menu.close()
	assert_false(get_tree().paused)


func test_language_switch_translates_names_and_menu() -> void:
	assert_eq(tr("gdl_lit_lance"), "Lithuanian Lance")
	TranslationServer.set_locale("pl")
	assert_eq(tr("Resume"), "Wznów")
	assert_eq(tr("gdl_lit_lance"), "Kopia litewska", "names are translated too (M10)")
	TranslationServer.set_locale("be")
	assert_eq(tr("Settings"), "Налады")


func test_main_menu_opens_and_follows_the_language() -> void:
	var scene: PackedScene = load("res://ui/main_menu.tscn")
	var menu: Control = scene.instantiate()
	add_child_autofree(menu)
	assert_eq(menu._skirmish.text, "Skirmish")
	TranslationServer.set_locale("lt")
	menu.propagate_notification(NOTIFICATION_TRANSLATION_CHANGED)
	assert_eq(menu._skirmish.text, "Susirėmimas")


func test_buildings_show_damage_stages_and_ruins() -> void:
	var layer: BuildingLayer = _main.get_node("World/Buildings")
	var b := _sim.economy.buildings
	var court := 0
	for id in b.alive_ids:
		if b.owners[id - 1] == 1 and b.defs[id - 1].id == &"gdl_town_center":
			court = id
	assert_gt(court, 0, "the player has a court")
	layer._refresh()
	var box: BoxView = layer._boxes[StringName("b%d" % court)]
	assert_eq(box.sprite, SpriteDB.building(&"gdl_town_center", &"done"))
	b.hp[court - 1] = b.max_hp[court - 1] / 5
	layer._refresh()
	assert_eq(box.sprite, SpriteDB.building(&"gdl_town_center", &"damaged_2"))
	_sim.economy.destroy(court)
	layer._refresh()
	assert_true(is_instance_valid(box) and not box.is_queued_for_deletion(), "ruins stay")
	assert_eq(box.sprite, SpriteDB.building(&"gdl_town_center", &"rubble"))
	_sim.tick += BuildingLayer.RUBBLE_TICKS
	layer._refresh()
	assert_true(box.is_queued_for_deletion(), "and go after a while")


func test_palisade_cells_join_their_neighbours() -> void:
	var layer: BuildingLayer = _main.get_node("World/Buildings")
	var b := _sim.economy.buildings
	var def: BuildingDef = load("res://data/buildings/gdl_palisade.tres")
	var gate: BuildingDef = load("res://data/buildings/gdl_gate.tres")
	var x0 := 2
	var y0 := _sim.nav.height - 3
	# A line along x: post, gate, post; and one more post below the last one.
	var left := _sim.economy._found(1, def, x0, y0, false)
	var middle := _sim.economy._found(1, gate, x0 + 1, y0, false)
	var right := _sim.economy._found(1, def, x0 + 2, y0, false)
	_sim.economy._found(1, def, x0 + 2, y0 + 1, false)
	for id: int in [left, middle, right]:
		b.done[id - 1] = 1
		b.hp[id - 1] = b.max_hp[id - 1]
	layer._refresh()
	var box: BoxView = layer._boxes[StringName("b%d" % left)]
	assert_eq(box.sprite, SpriteDB.building(&"gdl_palisade"))
	assert_eq(box.front, [SpriteDB.building(&"gdl_palisade_e")] as Array[SpriteDB.Sprite])
	assert_true(box.back.is_empty(), "nothing west or north of the first post")
	var corner: BoxView = layer._boxes[StringName("b%d" % right)]
	assert_eq(corner.back, [SpriteDB.building(&"gdl_palisade_w")] as Array[SpriteDB.Sprite])
	assert_eq(corner.front, [SpriteDB.building(&"gdl_palisade_s")] as Array[SpriteDB.Sprite])
	assert_eq(layer._art_id(middle - 1), &"gdl_gate", "a gate in a line along x keeps its view")


func test_zaseka_along_y_uses_its_turned_view() -> void:
	var layer: BuildingLayer = _main.get_node("World/Buildings")
	var def: BuildingDef = load("res://data/buildings/gdl_zaseka.tres")
	var id := _sim.economy._found(1, def, 2, _sim.nav.height - 8, true)
	assert_eq(layer._art_id(id - 1), &"gdl_zaseka_v")


func test_speed_button_steps_through_1x_2x_4x_8x() -> void:
	var clock: SimClock = _main.get_node("SimClock")
	assert_eq(_hud._speed_button.text, "1x")
	var seen: Array[String] = []
	for i in 4:
		_hud.step_speed(1)
		seen.append(_hud._speed_button.text)
	assert_eq(seen, ["2x", "4x", "8x", "1x"] as Array[String])
	_hud.step_speed(-1)
	assert_eq(clock.speed_permille, 8000)
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_MINUS
	_hud._unhandled_input(key)
	assert_eq(_hud._speed_button.text, "4x")


func test_8x_runs_eight_times_the_ticks_and_the_same_ticks() -> void:
	var clock: SimClock = _main.get_node("SimClock")
	clock.speed_permille = 8000
	var start := _sim.tick
	# One 30 fps frame at 8x is 5.3 ticks: all of them run, the catch-up limit grows with speed.
	clock.add_time_usec(33_333 * 8)
	assert_eq(clock.advance_accumulated(), 5)
	assert_eq(_sim.tick, start + 5)
