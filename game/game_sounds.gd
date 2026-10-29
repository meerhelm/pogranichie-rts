class_name GameSounds
extends Node
## The game's event sounds (Sfx), heard by the local player only: alerts (an attack, a building
## finished, a unit trained, a technology or an age reached, a mission objective), the answer of
## units to selection and orders (a short noise of their kind, no voices), a click on a building
## and the interface sounds of orders (queue, cancel, rally, a building placed). Reads the
## simulation and the input, the simulation knows nothing of it. Combat, work and ambience come
## later.

## Seconds between two polls of the player's counters.
const POLL := 0.25
## Least gap between unit answers, ms (only one answers at a time).
const ACK_GAP_MS := 350
## Cells around an attacked spot looked at for own buildings: then it is the town under attack.
const TOWN_RADIUS := 10

var sim: Simulation
var player := 1
var input: PlayerInput

var _faction: StringName = &"gdl"
var _trained := 0
var _techs := 0
var _age := 1
var _events_read := 0
var _poll_left := POLL
var _last_ack := -100000
var _selected := PackedInt32Array()


func attach(p_sim: Simulation, p_player: int, p_input: PlayerInput, minimap: Minimap) -> void:
	sim = p_sim
	player = p_player
	input = p_input
	Sfx.ensure()
	var state := sim.economy.player(player)
	if state != null:
		_faction = state.faction
		_trained = state.trained
		_techs = state.techs.size()
		_age = state.age
	if sim.mission != null:
		_events_read = sim.mission.events.size()
	input.ordered.connect(_on_order)
	input.building_selected.connect(_on_building)
	input.selection.changed.connect(_on_selection)
	if minimap != null:
		minimap.alerted.connect(_on_alert)


func _process(delta: float) -> void:
	if sim == null:
		return
	_poll_left -= delta
	if _poll_left > 0.0:
		return
	_poll_left = POLL
	_poll_player()
	_poll_mission()


func _poll_player() -> void:
	var state := sim.economy.player(player)
	if state == null:
		return
	if state.age > _age:
		Sfx.play(StringName("alert_age_up_%s" % _faction), 2000)
	elif state.techs.size() > _techs:
		Sfx.play(&"alert_research_done", 1000)
	if state.trained > _trained:
		Sfx.play(StringName("alert_unit_ready_%s" % _faction), 1500)
	_age = state.age
	_techs = state.techs.size()
	_trained = state.trained


func _poll_mission() -> void:
	if sim.mission == null:
		return
	var events := sim.mission.events
	while _events_read < events.size():
		var e: Dictionary = events[_events_read]
		_events_read += 1
		match e["kind"]:
			"objective":
				match int(e["state"]):
					MissionRuntime.Objective.DONE:
						Sfx.play(&"alert_objective_done", 1000)
					MissionRuntime.Objective.FAILED:
						Sfx.play(&"alert_objective_failed", 1000)
					_:
						Sfx.play(&"alert_objective_new", 1000)


func _on_alert(kind: int, cell: Vector2) -> void:
	match kind:
		MinimapAlerts.Kind.ATTACK:
			Sfx.play(&"alert_attack_town" if _town_near(cell) else &"alert_attack_army", 3000)
		MinimapAlerts.Kind.BUILT:
			Sfx.play(&"alert_building_done", 1000)
		MinimapAlerts.Kind.SIGNAL:
			Sfx.play(&"alert_message", 1000)


func _town_near(cell: Vector2) -> bool:
	var b := sim.economy.buildings
	for id in b.alive_ids:
		var s := id - 1
		if b.owners[s] != player:
			continue
		var at := Vector2(b.cell_x[s] + b.w[s] / 2.0, b.cell_y[s] + b.h[s] / 2.0)
		if at.distance_squared_to(cell) <= TOWN_RADIUS * TOWN_RADIUS:
			return true
	return false


func _on_building(b: int) -> void:
	var def := sim.economy.buildings.defs[b - 1]
	if def == null:
		return
	var own := StringName("bld_%s" % def.id)
	if Sfx.has(own):
		Sfx.play(own, 300)
	else:
		Sfx.play(StringName("bld_%s" % def.base_id), 300)


func _on_selection() -> void:
	var now := input.selection.ids
	var before := _selected
	_selected = now.duplicate()
	if now.is_empty():
		return
	# Units only dropping out (dead) or the same group again: no answer.
	var grew := false
	for id in now:
		if not before.has(id):
			grew = true
			break
	if not grew:
		return
	_ack(now[0], &"select")


func _on_order(cmd: SimCommand) -> void:
	match cmd.kind:
		SimCommand.Kind.MOVE, SimCommand.Kind.ATTACK_MOVE, SimCommand.Kind.RETREAT:
			_ack_first(cmd, &"move")
		SimCommand.Kind.ATTACK, SimCommand.Kind.ASSAULT, SimCommand.Kind.IGNITE:
			_ack_first(cmd, &"attack")
		SimCommand.Kind.GATHER, SimCommand.Kind.WORK:
			_ack_first(cmd, &"work")
		SimCommand.Kind.BUILD, SimCommand.Kind.WALL:
			Sfx.play(&"ui_place_ok", 150)
		SimCommand.Kind.QUEUE:
			if cmd.ids.is_empty():
				return
			var fail := sim.economy.production.can_queue(player, cmd.ids[0], cmd.type_id)
			if fail == EconomySystem.Fail.COST:
				Sfx.play(&"alert_no_resources", 600)
			elif fail == EconomySystem.Fail.OK:
				Sfx.play(&"ui_queue", 100)
		SimCommand.Kind.CANCEL:
			Sfx.play(&"ui_cancel", 100)
		SimCommand.Kind.RALLY, SimCommand.Kind.BUILDING_RALLY:
			Sfx.play(&"ui_rally", 200)


func _ack_first(cmd: SimCommand, what: StringName) -> void:
	if cmd.ids.is_empty():
		return
	_ack(cmd.ids[0], what)


## The answer of unit `id` (select, move, attack or work), one at a time.
func _ack(id: int, what: StringName) -> void:
	var e := sim.entities
	if not e.is_alive(id) or e.owners[id - 1] != player:
		return
	var now := Time.get_ticks_msec()
	if now - _last_ack < ACK_GAP_MS:
		return
	var def := sim.economy.unit_defs[id - 1]
	if def == null:
		return
	for sound in ack_sounds(def, what):
		if Sfx.has(sound):
			_last_ack = now
			Sfx.play(sound, 0, 0.04)
			return


## The sounds that can answer for a unit, best first: its own kind, then a general one.
static func ack_sounds(def: UnitDef, what: StringName) -> Array[StringName]:
	var kind := ack_kind(def)
	var out: Array[StringName] = []
	if what == &"work":
		return [&"ack_peasant_work"] if kind == &"peasant" else out
	if what == &"attack" and def.classes.has(&"spearman"):
		out.append(&"ack_spear_attack")
	out.append(StringName("ack_%s_%s" % [kind, what]))
	if what == &"move" and kind in [&"pagan", &"priest", &"inok", &"yurodivy", &"spy", &"master"]:
		out.append(&"ack_robe_move")
	out.append(StringName("ack_inf_%s" % what))
	if def.classes.has(&"hero") and what == &"select":
		out.insert(0, &"ack_hero_select")
	return out


## The answer kind of a unit: the part between ack_ and _select in the sound ids.
static func ack_kind(def: UnitDef) -> StringName:
	match def.id:
		&"gdl_vilkolak":
			return &"vilkolak"
		&"pl_stranger":
			return &"stranger"
		&"mo_moroz":
			return &"moroz"
		&"to_grand_master":
			return &"master"
		&"to_spy":
			return &"spy"
		&"mo_yurodivy":
			return &"yurodivy"
		&"mo_inok":
			return &"inok"
		&"gdl_znakharka", &"nt_pagan_priest":
			return &"pagan"
	var c := def.classes
	if c.has(&"boat"):
		return &"boat"
	if c.has(&"spiritual"):
		return &"priest"
	if c.has(&"peasant") or c.has(&"civilian"):
		return &"peasant"
	if c.has(&"siege"):
		return &"siege"
	if c.has(&"firearm"):
		return &"gun"
	if c.has(&"horse_archer") or c.has(&"light_cavalry"):
		return &"lcav"
	if c.has(&"heavy_cavalry"):
		return &"hcav"
	if c.has(&"cavalry"):
		return &"lcav"
	if c.has(&"archer"):
		return &"crossbow" if String(def.id).contains("crossbow") else &"archer"
	return &"inf"
