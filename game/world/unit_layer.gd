class_name UnitLayer
extends Node2D
## Keeps one UnitView per simulation entity and moves it between the last two tick positions,
## so units glide at any frame rate while the simulation ticks 20 times a second.
## Children are y-sorted: a unit lower on screen is drawn in front.

## One unit on the map: placeholder body or the type's animated sheet (UnitView).
const VIEW_SCENE := preload("res://game/world/unit_view.tscn")
## No place to turn to (_work_point).
const NO_POINT := Vector2i(-1, -1)
## Ticks between looks into the training queues for art to load ahead (_prefetch_queued).
const PREFETCH_TICKS := 20

var sim: Simulation
var clock: SimClock
var views: Dictionary[int, UnitView] = {}
## The player at this screen: others' units are drawn only when this player sees them (fog of
## war, forest archers hidden in the forest).
var local_player := 1
## Draw everyone regardless of the fog (the debug arena).
var reveal_all := false

## Tick of each unit's last blow already shown, by id.
var _struck: Dictionary[int, int] = {}
## Fixed positions at the previous and the latest tick, by id.
var _prev: Dictionary[int, Vector2i] = {}
var _cur: Dictionary[int, Vector2i] = {}


func _ready() -> void:
	y_sort_enabled = true


func attach(p_sim: Simulation, p_clock: SimClock) -> void:
	sim = p_sim
	clock = p_clock
	clock.advanced.connect(_on_advanced)
	_on_advanced(sim.tick, 1)


## Once a frame after its ticks. After one tick a unit glides from where it stood a tick ago;
## after several (high game speed) it is shown where it is, a frame is short enough for that.
func _on_advanced(tick: int, steps: int) -> void:
	if tick / PREFETCH_TICKS != (tick - steps) / PREFETCH_TICKS:
		_prefetch_queued()
	var e := sim.entities
	for id in e.alive_ids:
		var p := Vector2i(e.pos_x[id - 1], e.pos_y[id - 1])
		var uv: UnitView = views.get(id)
		if uv == null:
			uv = _make_view(id)
			_prev[id] = p
		else:
			_prev[id] = _cur[id] if steps == 1 else p
			uv.face(p.x - _cur[id].x, p.y - _cur[id].y)
			uv.set_moving(p != _cur[id])
			_show_action(id, uv, p != _cur[id])
		_cur[id] = p
		_show_state(id, uv)
	for id: int in views.keys():
		if not e.is_alive(id):
			views[id].queue_free()
			views.erase(id)
			_prev.erase(id)
			_cur.erase(id)
			_struck.erase(id)


## Unit sheets are big: the art of what any building is training is loaded on a worker thread
## before the first such unit comes out, instead of stalling the frame it appears in.
func _prefetch_queued() -> void:
	if not sim.economy.enabled():
		return
	var b := sim.economy.buildings
	for id in b.alive_ids:
		for item: StringName in b.queues[id - 1]:
			SpriteDB.prefetch_unit(item)


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
	var is_hidden := sim.combat.enabled() and sim.combat.is_hidden(id)
	var own := e.owners[slot] == local_player
	var seen := reveal_all or sim.vision.sees_unit(local_player, id)
	v.visible = own or (not is_hidden and seen)
	var hp := clampi(e.hp[slot] * 1000 / maxi(e.max_hp[slot], 1), 0, 1000)
	v.show_state(hp, mood, is_hidden, e.move_class[slot])


## Work and attack animations, turned toward what the unit works on or hits.
func _show_action(id: int, v: UnitView, moved: bool) -> void:
	if v.sprite == null:
		return
	var e := sim.entities
	var slot := id - 1
	var eco := sim.economy
	var job := eco.job[slot] if eco.enabled() else EconomySystem.Job.NONE
	var work := (
		job in [EconomySystem.Job.GATHER, EconomySystem.Job.BUILD, EconomySystem.Job.DISMANTLE]
		and eco.phase[slot] == EconomySystem.Phase.WORK
	)
	# The Crown's pavisier crouches behind his set pavise (its work animation).
	if sim.combat.enabled() and sim.combat.crown.pavise_set(id):
		work = true
	v.set_working(work)
	var at := _work_point(slot, job) if work or job == EconomySystem.Job.ASSAULT else NO_POINT
	var blow := e.last_attack[slot]
	if blow != _struck.get(id, -1):
		_struck[id] = blow
		if blow >= 0:
			v.strike()
			if at == NO_POINT:
				v.face(e.facing_x[slot], e.facing_y[slot])
	if not moved and at != NO_POINT:
		v.face(at.x - e.pos_x[slot], at.y - e.pos_y[slot])


## Where a unit's job is, in fixed units: the building, resource cell or node it works on.
func _work_point(slot: int, job: int) -> Vector2i:
	var eco := sim.economy
	var ref := eco.job_ref[slot]
	var nav := sim.nav
	var cell := -1
	if job != EconomySystem.Job.GATHER or eco.job_target[slot] == EconomySystem.Target.BUILDING:
		if not eco.buildings.is_alive(ref):
			return NO_POINT
		return Vector2i(eco.buildings.center_x(ref), eco.buildings.center_y(ref))
	if eco.job_target[slot] == EconomySystem.Target.CELL:
		cell = ref
	elif ref > 0 and ref <= eco.nodes.alive.size() and eco.nodes.alive[ref - 1] == 1:
		cell = eco.nodes.cells[ref - 1]
	if cell < 0:
		return NO_POINT
	return Vector2i(nav.center_x(cell), nav.center_y(cell))


func view(id: int) -> UnitView:
	return views.get(id)


func _make_view(id: int) -> UnitView:
	var e := sim.entities
	var v: UnitView = VIEW_SCENE.instantiate()
	v.unit_id = id
	v.player = e.owners[id - 1]
	v.move_class = e.move_class[id - 1]
	v.type_id = e.type_ids[id - 1]
	v.name = "Unit%d" % id
	views[id] = v
	add_child(v)
	return v
