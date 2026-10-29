extends GutTest
## The minimap blinks red when the player's units are hit with an enemy near, once per fight
## area for a while, and green once when a building of the player's is finished.

var _main: Node2D
var _sim: Simulation


func before_each() -> void:
	var scene: PackedScene = load("res://game/main.tscn")
	_main = scene.instantiate()
	add_child_autofree(_main)
	_main.get_node("SimClock").paused = true
	_sim = _main.sim
	_sim.step()


func _spawn(type: StringName, player: int, x: int, y: int) -> int:
	return _sim.spawn_unit(type, player, Fixed.from_cells(x) + Fixed.HALF, Fixed.from_cells(y))


func _kinds(alerts: Array[Dictionary]) -> Array[int]:
	var out: Array[int] = []
	for a in alerts:
		out.append(a["kind"])
	return out


func test_hit_with_an_enemy_near_is_an_attack_once_per_area() -> void:
	var own := _spawn(&"gdl_spearman", 1, 20, 20)
	var alerts := MinimapAlerts.new(_sim, 1)
	_sim.entities.hp[own - 1] -= 5
	assert_eq(alerts.poll(_sim.tick).size(), 0, "no enemy near: sickness, not an attack")
	_spawn(&"to_knecht", 2, 22, 20)
	_sim.entities.hp[own - 1] -= 5
	var got := alerts.poll(_sim.tick)
	assert_eq(_kinds(got), [MinimapAlerts.Kind.ATTACK])
	_sim.entities.hp[own - 1] -= 5
	assert_eq(alerts.poll(_sim.tick + 20).size(), 0, "the same fight stays quiet")
	_sim.entities.hp[own - 1] -= 5
	var later := alerts.poll(_sim.tick + MinimapAlerts.COOLDOWN_TICKS)
	assert_eq(_kinds(later), [MinimapAlerts.Kind.ATTACK], "and blinks again after a while")


func test_enemy_hurt_is_no_alert() -> void:
	_spawn(&"gdl_spearman", 1, 20, 20)
	var enemy := _spawn(&"to_knecht", 2, 22, 20)
	var alerts := MinimapAlerts.new(_sim, 1)
	_sim.entities.hp[enemy - 1] -= 5
	assert_eq(alerts.poll(_sim.tick).size(), 0)


func test_finished_building_blinks_once() -> void:
	var eco := _sim.economy
	var house := eco._found(1, _sim.catalog().building(&"gdl_house"), 20, 20, false)
	var alerts := MinimapAlerts.new(_sim, 1)
	assert_eq(alerts.poll(_sim.tick).size(), 0, "a foundation is no news")
	eco.complete(house)
	var got := alerts.poll(_sim.tick)
	assert_eq(_kinds(got), [MinimapAlerts.Kind.BUILT])
	assert_eq(alerts.poll(_sim.tick).size(), 0, "only once")


func test_minimap_blinks_and_glows_then_stops() -> void:
	var hud: Hud = _main.get_node("UI/Hud")
	var minimap := hud.minimap
	minimap.ping(MinimapAlerts.Kind.ATTACK, Vector2(10, 10))
	minimap._age_pings(Minimap.BLINK / 2.0)
	assert_true(minimap._halo.visible, "red glow while under attack")
	minimap._age_pings(Minimap.BLINK * Minimap.ATTACK_BLINKS)
	assert_eq(minimap._pings.size(), 0)
	assert_false(minimap._halo.visible)


func test_mission_signal_blinks_once_and_not_after_a_load() -> void:
	var mission := MissionRuntime.new(MissionDef.load_id("gdl_01"), _sim, "normal")
	_sim.mission = mission
	mission.events.clear()
	mission.events.append({"kind": "ping", "tick": 0, "at": [3, 4], "radius": 2})
	var alerts := MinimapAlerts.new(_sim, 1)
	assert_eq(alerts.poll(_sim.tick).size(), 0, "a signal given before the load stays quiet")
	mission.events.append({"kind": "hint", "tick": 1})
	mission.events.append({"kind": "ping", "tick": 1, "at": [10, 12], "radius": 2})
	var got := alerts.poll(_sim.tick)
	assert_eq(_kinds(got), [MinimapAlerts.Kind.SIGNAL])
	assert_eq(got[0]["cell"], Vector2(10.5, 12.5))
	assert_eq(alerts.poll(_sim.tick).size(), 0)
	_sim.mission = null
