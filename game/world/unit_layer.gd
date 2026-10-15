class_name UnitLayer
extends Node2D
## Keeps one UnitView per simulation entity and moves it between the last two tick positions,
## so units glide at any frame rate while the simulation ticks 20 times a second.
## Children are y-sorted: a unit lower on screen is drawn in front.

var sim: Simulation
var clock: SimClock
var views: Dictionary[int, UnitView] = {}
## The player at this screen: enemy forest archers hidden in the forest are not drawn for them.
var local_player := 1

## Fixed positions at the previous and the latest tick, by id.
var _prev: Dictionary[int, Vector2i] = {}
var _cur: Dictionary[int, Vector2i] = {}


func _ready() -> void:
	y_sort_enabled = true


func attach(p_sim: Simulation, p_clock: SimClock) -> void:
	sim = p_sim
	clock = p_clock
	clock.ticked.connect(_on_ticked)
	_on_ticked(sim.tick)


func _on_ticked(_tick: int) -> void:
	var e := sim.entities
	for id in e.alive_ids:
		var p := Vector2i(e.pos_x[id - 1], e.pos_y[id - 1])
		var view: UnitView = views.get(id)
		if view == null:
			view = _make_view(id)
			_prev[id] = p
		else:
			_prev[id] = _cur[id]
			view.face(p.x - _cur[id].x, p.y - _cur[id].y)
		_cur[id] = p
		_show_state(id, view)
	for id: int in views.keys():
		if not e.is_alive(id):
			views[id].queue_free()
			views.erase(id)
			_prev.erase(id)
			_cur.erase(id)


func _process(_delta: float) -> void:
	if sim == null:
		return
	var t := clock.alpha_permille() / 1000.0 if not clock.paused else 1.0
	for id: int in views:
		var a := Iso.fixed_to_screen(_prev[id].x, _prev[id].y)
		var b := Iso.fixed_to_screen(_cur[id].x, _cur[id].y)
		views[id].position = a.lerp(b, t)


func _show_state(id: int, v: UnitView) -> void:
	var e := sim.entities
	var slot := id - 1
	var mood := UnitView.Mood.STEADY
	if e.intents[slot] == EntityStore.Intent.FLEE:
		mood = UnitView.Mood.FLEEING
	elif sim.combat.enabled() and sim.combat.wavering(slot):
		mood = UnitView.Mood.WAVERING
	var hidden := sim.combat.enabled() and sim.combat.is_hidden(id)
	v.visible = not hidden or e.owners[slot] == local_player
	var hp := clampi(e.hp[slot] * 1000 / maxi(e.max_hp[slot], 1), 0, 1000)
	v.show_state(hp, mood, hidden, e.move_class[slot])


func view(id: int) -> UnitView:
	return views.get(id)


func _make_view(id: int) -> UnitView:
	var e := sim.entities
	var v := UnitView.new()
	v.unit_id = id
	v.player = e.owners[id - 1]
	v.move_class = e.move_class[id - 1]
	v.type_id = e.type_ids[id - 1]
	v.name = "Unit%d" % id
	views[id] = v
	add_child(v)
	return v
