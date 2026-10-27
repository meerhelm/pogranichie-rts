extends GutTest
## The idle worker button and the . key (2026-10): the top bar counts the peasants with nothing
## to do; a click selects the next one and centres the camera on it, going round them all;
## Shift selects them all; a peasant at work or walking is not idle.

var _main: Node2D
var _input: PlayerInput
var _hud: Hud
var _sim: Simulation
var _camera: RtsCamera


func before_each() -> void:
	TranslationServer.set_locale("en")
	var scene: PackedScene = load("res://game/main.tscn")
	_main = scene.instantiate()
	add_child_autofree(_main)
	_main.get_node("SimClock").paused = true
	_input = _main.get_node("UI/PlayerInput")
	_hud = _main.get_node("UI/Hud")
	_camera = _input.camera
	_sim = _main.sim
	_sim.step()
	_hud.refresh()


func after_each() -> void:
	TranslationServer.set_locale("en")


func _peasants() -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in _sim.entities.alive_ids:
		var def := _sim.economy.unit_defs[id - 1]
		if _sim.entities.owners[id - 1] == 1 and def != null and def.has_class(&"peasant"):
			out.append(id)
	return out


func _period(shift := false) -> void:
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_PERIOD
	key.shift_pressed = shift
	_input._unhandled_input(key)


func test_start_peasants_are_idle_and_counted() -> void:
	var peasants := _peasants()
	assert_eq(peasants.size(), SkirmishSetup.START_PEASANTS)
	assert_eq(IdleWorkers.of(_sim, 1), peasants)
	assert_true(_hud._idle_button.visible)
	assert_eq(_hud._idle_button.text, str(peasants.size()))
	assert_string_contains(_hud._idle_button.tooltip_text, "Idle workers: %d" % peasants.size())


func test_button_goes_round_the_idle_peasants_and_centres_the_camera() -> void:
	var peasants := _peasants()
	var seen := PackedInt32Array()
	for i in peasants.size():
		_hud._idle_button.pressed.emit()
		assert_eq(_input.selection.ids.size(), 1, "one peasant at a time")
		var id := _input.selection.ids[0]
		assert_false(seen.has(id), "each press goes on to another one")
		seen.append(id)
		var at := RtsCamera.clamp_to_bounds(
			Iso.fixed_to_screen(_sim.entities.pos_x[id - 1], _sim.entities.pos_y[id - 1]),
			_camera.bounds
		)
		assert_almost_eq(_camera.position.x, at.x, 1.0, "the camera is on it")
		assert_almost_eq(_camera.position.y, at.y, 1.0)
	_hud._idle_button.pressed.emit()
	assert_eq(_input.selection.ids[0], seen[0], "and comes back to the first")


func test_working_or_walking_peasants_are_not_idle() -> void:
	var peasants := _peasants()
	var walker := PackedInt32Array([peasants[0]])
	var e := _sim.entities
	var x := e.pos_x[peasants[0] - 1] + Fixed.from_cells(3)
	_sim.enqueue(SimCommand.move(_sim.tick, 1, walker, x, e.pos_y[peasants[0] - 1]))
	_sim.step()
	_hud.refresh()
	assert_false(IdleWorkers.of(_sim, 1).has(peasants[0]))
	assert_eq(_hud._idle_button.text, str(peasants.size() - 1))
	for i in peasants.size():
		_period()
		assert_ne(_input.selection.ids[0], peasants[0], "the . key skips the walking one")


func test_shift_selects_all_idle_peasants() -> void:
	_period(true)
	assert_eq(_input.selection.ids, _peasants())


func test_no_peasants_hides_the_button() -> void:
	for id in _peasants():
		_sim.entities.owners[id - 1] = 2
	_hud.refresh()
	assert_false(_hud._idle_button.visible)
	assert_false(_input.select_idle_worker())
