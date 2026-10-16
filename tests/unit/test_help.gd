extends GutTest
## Help for a new player: the skirmish advisor moves on as the player does each step, F1 opens
## «How to play» and pauses, build buttons say what a building is for, and the text size
## setting changes the theme's font size.

var _main: Node2D
var _input: PlayerInput
var _hud: Hud
var _sim: Simulation
var _hints := true
var _text_size := 1


func before_each() -> void:
	TranslationServer.set_locale("en")
	GameSettings.ensure_loaded()
	_hints = GameSettings.hints
	_text_size = GameSettings.text_size
	GameSettings.hints = true
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
	GameSettings.hints = _hints
	GameSettings.text_size = _text_size
	GameSettings.apply()


func _peasants() -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in _sim.entities.alive_ids:
		if _sim.entities.type_ids[id - 1] == &"gdl_peasant" and _sim.entities.owners[id - 1] == 1:
			out.append(id)
	return out


func _select(ids: PackedInt32Array) -> void:
	var points := PackedVector2Array()
	points.resize(ids.size())
	_input.selection.box(Rect2(-1, -1, 2, 2), ids, points, false)


## The forest cell nearest the GDL court.
func _forest_near_base() -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for y in 40:
		for x in 40:
			if _sim.economy.nodes.wood[_sim.nav.cell_at(x, y)] > 0:
				var d := (x - 7) * (x - 7) + (y - 7) * (y - 7)
				if d < best_d:
					best = Vector2i(x, y)
					best_d = d
	return best


func test_advisor_follows_the_player() -> void:
	var advisor := _hud.advisor
	assert_true(advisor.visible, "a skirmish starts with hints")
	assert_eq(Advisor.STEPS[advisor.step], &"select")
	var peasants := _peasants()
	_select(peasants)
	_hud.refresh()
	assert_eq(Advisor.STEPS[advisor.step], &"wood")
	var cell := _forest_near_base()
	assert_true(cell.x >= 0, "forest near the base")
	var x := Fixed.from_cells(cell.x) + Fixed.HALF
	var y := Fixed.from_cells(cell.y) + Fixed.HALF
	_sim.enqueue(SimCommand.gather_at(_sim.tick, 1, peasants, x, y))
	_sim.step()
	_hud.refresh()
	assert_eq(Advisor.STEPS[advisor.step], &"house", "population is full at the start")
	assert_string_contains(advisor.hint(&"house"), "«Hut»")


func test_advisor_is_off_when_hints_are_off() -> void:
	GameSettings.hints = false
	_hud.refresh()
	assert_false(_hud.advisor.visible)


func test_f1_opens_how_to_play_and_pauses() -> void:
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_F1
	_hud._unhandled_input(key)
	assert_true(_hud.help.visible)
	assert_true(get_tree().paused)
	assert_string_contains(_hud.help.page(), "«Slash-and-Burn Field»")
	_hud.help.close()
	assert_false(_hud.help.visible)
	assert_false(get_tree().paused)


func test_build_buttons_say_what_a_building_is_for() -> void:
	_select(_peasants())
	_hud.refresh()
	var house: Button = _hud.commands._build_buttons[&"gdl_house"]
	assert_string_contains(house.tooltip_text, "+5 population")
	var yard: Button = _hud.commands._build_buttons[&"gdl_lumber_yard"]
	assert_string_contains(yard.tooltip_text, "Peasants bring here: wood")


func test_text_size_changes_the_theme_font() -> void:
	GameSettings.text_size = GameSettings.TEXT_SIZES.size() - 1
	GameSettings.apply()
	assert_eq(ThemeDB.get_project_theme().default_font_size, GameSettings.TEXT_SIZES[-1])
