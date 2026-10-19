class_name SilverLayer
extends Node2D
## What «Корона 5» (MissionSilver) shows on the map: a silver coin over every wagon or boat that
## carries the ransom, and a ring on the ground round each village of the Żuławy that says what
## the village pays now: green when it may be taxed, grey when it was taxed this season, violet
## while a rumour goes round it (half the tax), red once the Order's riders plundered it this
## season (nothing). Only what the local player sees is drawn; everything is read from the
## simulation.

const COIN := Color(0.86, 0.88, 0.9)
const COIN_EDGE := Color(0.35, 0.36, 0.4)
const FREE := Color(0.45, 0.8, 0.4, 0.7)
const TAXED := Color(0.7, 0.7, 0.7, 0.6)
const RUMOUR := Color(0.7, 0.45, 0.9, 0.8)
const PLUNDERED := Color(0.9, 0.25, 0.2, 0.85)
## Screen pixels from a carrier's foot up to the coin.
const RISE := 40.0
## Ring radius round a village in screen pixels: about the 4 cells where the tax is taken.
const RING := 130.0

var sim: Simulation
var local_player := 1

var _state := PackedInt32Array()


## Whether the mission has the silver rules.
static func wanted(p_sim: Simulation) -> bool:
	var m := p_sim.mission
	return m != null and m.def.rules.has("silver")


func attach(p_sim: Simulation, clock: SimClock) -> void:
	sim = p_sim
	clock.advanced.connect(func(t: int, _s: int) -> void: _on_ticked(t))
	queue_redraw()


func _on_ticked(_tick: int) -> void:
	# Carriers move, so redraw while any carries silver; else only when a village changes.
	var now := _villages()
	if now != _state or not sim.mission.silver.cargo.is_empty():
		_state = now
		queue_redraw()


## Each village's ring: 0 free, 1 taxed this season, 2 rumour, 3 plundered, -1 not seen yet.
func _villages() -> PackedInt32Array:
	var s := sim.mission.silver
	var at: Array = sim.mission.def.rules["silver"].get("villages", {}).get("at", [])
	var out := PackedInt32Array()
	for i in at.size():
		var cell := sim.nav.cell_at(int(at[i][0]), int(at[i][1]))
		if sim.vision.state(local_player, cell) == VisionSystem.State.UNEXPLORED:
			out.append(-1)
		elif s.plundered[i] == s.season:
			out.append(3)
		elif s.rumour[i] == 1:
			out.append(2)
		elif s.taxed_season[i] == s.season:
			out.append(1)
		else:
			out.append(0)
	return out


func _draw() -> void:
	if sim == null:
		return
	var at: Array = sim.mission.def.rules["silver"].get("villages", {}).get("at", [])
	var colours := [FREE, TAXED, RUMOUR, PLUNDERED]
	for i in mini(_state.size(), at.size()):
		if _state[i] < 0:
			continue
		var c := Iso.cell_to_screen(Vector2(int(at[i][0]) + 0.5, int(at[i][1]) + 0.5))
		draw_set_transform(c, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, RING, 0.0, TAU, 48, colours[_state[i]], 2.0)
		draw_set_transform(Vector2.ZERO)
	var e := sim.entities
	for id: int in sim.mission.silver.cargo:
		if not e.is_alive(id) or not _seen(id):
			continue
		var top := Iso.fixed_to_screen(e.pos_x[id - 1], e.pos_y[id - 1]) - Vector2(0.0, RISE)
		draw_circle(top, 5.0, COIN)
		draw_arc(top, 5.0, 0.0, TAU, 16, COIN_EDGE, 1.0)


func _seen(id: int) -> bool:
	var e := sim.entities
	var cell := sim.nav.cell_of(e.pos_x[id - 1], e.pos_y[id - 1])
	return sim.vision.state(local_player, cell) == VisionSystem.State.VISIBLE
