class_name WorldSounds
extends Node2D
## Sounds of the world around the camera, placed where they happen (AudioStreamPlayer2D, so they
## pan and fade with distance from the screen centre): shots by weapon, hits and deaths, blows on
## buildings and their fall, fire, building sites, peasants at work, spells. Only what the local
## player sees, and only near the screen. Plus the ambience of the land in view (two players
## crossfading) and the faction's music in a loop of its tracks.
##
## Reads the simulation after each frame's ticks (SimClock.advanced) and compares with what it saw
## the last time, like MinimapAlerts; the simulation knows nothing about sound.

## Players for one-shots placed in the world.
const VOICES := 16
## Loops at once (building sites, fires).
const LOOPS := 4
## Pixels from the screen centre where sounds fade out.
const HEAR := 1400.0
## Most one-shots started in one look (a big battle stays a din, not a roar).
const PER_LOOK := 3
## Seconds between looks at the world, the land and the loops.
const LOOK := 0.1
const LAND_LOOK := 1.0
const AMBIENCE_DB := -6.0
const FADE := 2.0
## A peasant at work makes a sound every this many seconds (random within).
const WORK_EVERY := Vector2(1.0, 1.8)
## Building bases of stone (their blows and fall sound of stone).
const STONE: Array[StringName] = [&"castle", &"wall", &"tower", &"foundry"]
const MELEE: Array[StringName] = [
	&"melee_sword_mail", &"melee_sword_shield", &"melee_spear", &"melee_axe", &"melee_club"
]
## Terrain -> ambience.
const LAND: Dictionary[StringName, StringName] = {
	&"t_forest": &"amb_forest",
	&"t_old_forest": &"amb_old_forest",
	&"t_bog": &"amb_bog",
	&"t_quagmire": &"amb_bog",
	&"t_water": &"amb_river",
	&"t_ford": &"amb_ford",
	&"t_ice": &"amb_ice",
	&"t_hill": &"amb_hill",
	&"t_ash": &"amb_ash",
}

var sim: Simulation
var units: UnitLayer
var player := 1
## Sounds played in the world so far, by id (for tests).
var played: Dictionary[StringName, int] = {}

var _pool: Array[AudioStreamPlayer2D] = []
var _next := 0
## "build:<id>" or "fire:<id>" -> a looping player.
var _loops: Dictionary[String, AudioStreamPlayer2D] = {}
var _look_left := 0.0
var _land_left := 0.0
## Units seen near the screen last time: id -> [hp, position].
var _seen_units: Dictionary[int, Array] = {}
## Buildings seen near the screen last time: id -> [hp, position].
var _seen_buildings: Dictionary[int, Array] = {}
## Targets of shots in flight last time -> the shot's damage type index.
var _in_flight: Dictionary[int, int] = {}
## Targets whose shot landed since the last look -> its damage type index.
var _landed: Dictionary[int, int] = {}
var _shots_tick := -1
var _fx_seen: Dictionary[int, bool] = {}
var _burning: Dictionary[int, bool] = {}
var _work_next: Dictionary[int, float] = {}
var _time := 0.0
var _started := 0
var _ambience: Array[AudioStreamPlayer] = []
var _ambience_id: StringName = &""
var _ambience_on := 0
var _music: AudioStreamPlayer
var _tracks: Array[StringName] = []
var _track := 0


func attach(p_sim: Simulation, p_units: UnitLayer, p_player: int) -> void:
	sim = p_sim
	units = p_units
	player = p_player
	Sfx.ensure()
	for i in VOICES:
		var p := AudioStreamPlayer2D.new()
		p.bus = &"Sfx"
		p.max_distance = HEAR
		p.attenuation = 1.5
		add_child(p)
		_pool.append(p)
	for i in 2:
		var a := AudioStreamPlayer.new()
		a.bus = &"Sfx"
		a.volume_db = -60.0
		add_child(a)
		_ambience.append(a)
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	add_child(_music)
	_music.finished.connect(_next_track)
	var state := sim.economy.player(player)
	var faction := state.faction if state != null else &"gdl"
	for k: int in [1, 2]:
		var id := StringName("%s_calm_%d" % [faction, k])
		if ResourceLoader.exists(_music_path(id)):
			_tracks.append(id)
	_track = randi() % maxi(_tracks.size(), 1)
	_next_track()
	_shots_tick = sim.tick
	if sim.magic != null:
		for id in sim.magic.fx_ids:
			_fx_seen[id] = true


static func _music_path(id: StringName) -> String:
	return "res://audio/music/%s.ogg" % id


func _next_track() -> void:
	if _tracks.is_empty():
		return
	_track = (_track + 1) % _tracks.size()
	var stream := load(_music_path(_tracks[_track])) as AudioStream
	if stream == null:
		return
	_music.stream = stream
	_music.volume_db = -30.0
	_music.play()
	create_tween().tween_property(_music, "volume_db", 0.0, FADE * 2.0)


func _process(delta: float) -> void:
	if sim == null or get_tree().paused:
		return
	_time += delta
	_look_left -= delta
	if _look_left <= 0.0:
		_look_left = LOOK
		_started = 0
		var view := _view_rect()
		_look_shots(view)
		_look_units(view)
		_look_buildings(view)
		_look_work(view)
		_look_spells(view)
	_land_left -= delta
	if _land_left <= 0.0:
		_land_left = LAND_LOOK
		_look_land()


## The world rect on screen, grown by a margin (sounds just off screen still count).
func _view_rect() -> Rect2:
	var vp := get_viewport()
	var rect := vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	return rect.grow(200.0)


## Plays sound `id` at world point `at`.
func play_at(id: StringName, at: Vector2, gap_ms: int = 60, pitch: float = 0.05) -> void:
	if _started >= PER_LOOK:
		return
	var streams := Sfx.streams(id)
	if streams.is_empty() or not Sfx.ensure().take_gap(id, gap_ms):
		return
	_started += 1
	played[id] = played.get(id, 0) + 1
	var p := _pool[_next]
	_next = (_next + 1) % VOICES
	p.stream = streams[randi() % streams.size()]
	p.position = at
	p.pitch_scale = 1.0 + randf_range(-pitch, pitch)
	p.play()


func _look_shots(view: Rect2) -> void:
	var c := sim.combat
	if c == null:
		return
	var shots := c.shots
	var flying: Dictionary[int, int] = {}
	for i in shots.size():
		flying[shots.target[i]] = shots.type[i]
		if shots.launched[i] <= _shots_tick:
			continue
		var at := Iso.fixed_to_screen(shots.x[i], shots.y[i])
		if not view.has_point(at) or not _sees(shots.x[i], shots.y[i]):
			continue
		play_at(_shot_sound(shots.from[i], shots.type[i]), at, 50)
	_shots_tick = sim.tick
	# Hits of shots that were flying last time and are gone now are heard in _look_units.
	var landed: Dictionary[int, int] = {}
	for t: int in _in_flight:
		if not flying.has(t):
			landed[t] = _in_flight[t]
	_in_flight = flying
	_landed = landed


func _shot_sound(from: int, type: int) -> StringName:
	var def := sim.economy.unit_defs[from - 1] if from > 0 else null
	if def == null:
		return &"bow_shot"  # a tower
	var id := String(def.id)
	var damage := Projectiles.DAMAGE_TYPES[type]
	var sound := &"bow_shot"
	if damage == Damage.SIEGE or (damage == Damage.FIREARM and def.classes.has(&"siege")):
		sound = _gun_sound(id)
	elif damage == Damage.FIREARM:
		sound = &"gun_hook_shot" if id.contains("hakownica") else &"gun_hand_shot"
	elif id.contains("crossbow") or id.contains("pavise"):
		sound = &"crossbow_shot"
	return sound


static func _gun_sound(id: String) -> StringName:
	if id.contains("bombard"):
		return &"cannon_bombard"
	if id.contains("tyufyak"):
		return &"cannon_tyufyak"
	if id.contains("porok"):
		return &"porok_release"
	return &"cannon_field"


func _look_units(view: Rect2) -> void:
	var e := sim.entities
	var now: Dictionary[int, Array] = {}
	for id in e.alive_ids:
		var v := units.view(id)
		if v == null or not v.visible or not view.has_point(v.position):
			continue
		var s := id - 1
		now[id] = [e.hp[s], v.position]
		if not _seen_units.has(id):
			continue
		var before: int = _seen_units[id][0]
		if e.hp[s] < before:
			_hit_sound(id, v.position)
	for id: int in _seen_units:
		if not now.has(id) and not e.is_alive(id):
			_death_sound(id, _seen_units[id][1])
	_seen_units = now
	_landed.clear()


func _hit_sound(id: int, at: Vector2) -> void:
	var def := sim.economy.unit_defs[id - 1]
	if _landed.has(id):
		var type := Projectiles.DAMAGE_TYPES[_landed[id]]
		if type == Damage.SIEGE:
			play_at(&"impact_ground", at, 150)
		elif type == Damage.PIERCE:
			var armored := def != null and def.classes.has(&"heavy_cavalry")
			play_at(&"arrow_hit_metal" if armored else &"arrow_hit_body", at, 60)
		return
	if def != null and def.classes.has(&"animal"):
		play_at(&"melee_spear", at, 80)
		return
	play_at(MELEE[randi() % MELEE.size()], at, 70)


func _death_sound(id: int, at: Vector2) -> void:
	var def := sim.economy.unit_defs[id - 1]
	if def == null:
		return
	if def.classes.has(&"animal"):
		var animal := StringName("an_%s" % String(def.id).trim_prefix("nt_"))
		play_at(animal if Sfx.has(animal) else &"death_inf", at, 200, 0.0)
	elif def.classes.has(&"cavalry"):
		play_at(&"death_cav", at, 150)
		play_at(&"horse_pain", at, 300)
	else:
		play_at(&"death_inf", at, 90)
	if def.classes.has(&"hero") and sim.entities.owners[id - 1] == player:
		Sfx.play(&"alert_hero_down", 3000)


func _look_buildings(view: Rect2) -> void:
	var b := sim.economy.buildings
	var now: Dictionary[int, Array] = {}
	var sites: Dictionary[int, bool] = {}
	for id in b.alive_ids:
		var s := id - 1
		var at := Iso.cell_to_screen(
			Vector2(b.cell_x[s] + b.w[s] / 2.0, b.cell_y[s] + b.h[s] / 2.0)
		)
		if (
			not view.has_point(at)
			or not sim.vision.sees_cell(player, sim.nav.cell_at(b.cell_x[s], b.cell_y[s]))
		):
			continue
		now[id] = [b.hp[s], at]
		var stone := _stone(b.defs[s])
		var dismantled := b.dismantling[s] == 1 if s < b.dismantling.size() else false
		if dismantled and _being_built(id, EconomySystem.Job.DISMANTLE):
			sites[id] = true
		elif _seen_buildings.has(id) and b.hp[s] < int(_seen_buildings[id][0]) and b.is_done(id):
			play_at(&"hit_stone_building" if stone else &"hit_wood_building", at, 90)
		if not b.is_done(id) and _being_built(id, EconomySystem.Job.BUILD):
			sites[id] = true
	for id: int in _seen_buildings:
		if not now.has(id) and b.hp[id - 1] <= 0:
			play_at(
				&"collapse_stone" if _stone(b.defs[id - 1]) else &"collapse_wood",
				_seen_buildings[id][1],
				300,
				0.0
			)
	_seen_buildings = now
	var fires: Dictionary[int, bool] = {}
	if sim.fire != null:
		for id: int in sim.fire.burning:
			if now.has(id):
				fires[id] = true
				if not _burning.has(id):
					play_at(&"fire_ignite", now[id][1], 200)
	_burning = fires
	_keep_loops(now, sites, fires)


static func _stone(def: BuildingDef) -> bool:
	return def != null and (STONE.has(def.base_id) or def.id == &"to_brickworks")


## Whether a unit works at building `b` with job `job` (BUILD or DISMANTLE).
func _being_built(b: int, job: int) -> bool:
	var eco := sim.economy
	for id in sim.entities.alive_ids:
		var s := id - 1
		var working := (
			job == EconomySystem.Job.DISMANTLE or eco.phase[s] == EconomySystem.Phase.WORK
		)
		if eco.job[s] == job and eco.job_ref[s] == b and working:
			return true
	return false


## Starts and stops the looping sounds of building sites and fires in view (the nearest first).
func _keep_loops(
	seen: Dictionary[int, Array], sites: Dictionary[int, bool], fires: Dictionary[int, bool]
) -> void:
	var want: Dictionary[String, Array] = {}
	for id: int in fires:
		want["fire:%d" % id] = [&"fire_loop", seen[id][1]]
	for id: int in sites:
		if want.size() >= LOOPS:
			break
		var stone := _stone(sim.economy.buildings.defs[id - 1])
		want["build:%d" % id] = [&"build_stone_loop" if stone else &"build_wood_loop", seen[id][1]]
	for key: String in _loops.keys():
		if not want.has(key):
			_loops[key].queue_free()
			_loops.erase(key)
	for key: String in want:
		if _loops.has(key) or _loops.size() >= LOOPS:
			continue
		var streams := Sfx.streams(want[key][0])
		if streams.is_empty():
			continue
		var p := AudioStreamPlayer2D.new()
		p.bus = &"Sfx"
		p.max_distance = HEAR
		p.attenuation = 1.5
		p.volume_db = -4.0
		var stream := (streams[randi() % streams.size()] as AudioStream).duplicate() as AudioStream
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		p.stream = stream
		p.position = want[key][1]
		add_child(p)
		p.play()
		_loops[key] = p


func _look_work(view: Rect2) -> void:
	var eco := sim.economy
	var e := sim.entities
	for id in e.alive_ids:
		var s := id - 1
		if eco.job[s] != EconomySystem.Job.GATHER or eco.phase[s] != EconomySystem.Phase.WORK:
			_work_next.erase(id)
			continue
		var v := units.view(id)
		if v == null or not v.visible or not view.has_point(v.position):
			continue
		var due: float = _work_next.get(id, _time + randf_range(0.0, WORK_EVERY.y))
		if _time >= due:
			play_at(_work_sound(eco.job_source[s]), v.position, 60)
			due = _time + randf_range(WORK_EVERY.x, WORK_EVERY.y)
		_work_next[id] = due


static func _work_sound(source: int) -> StringName:
	match source:
		ResourceNodes.Source.WOOD, ResourceNodes.Source.SALVAGE_WOOD:
			return &"eco_chop"
		ResourceNodes.Source.IRON, ResourceNodes.Source.SILVER:
			return &"eco_mine"
		ResourceNodes.Source.HUNT:
			return &"eco_hunt"
		ResourceNodes.Source.BORT:
			return &"eco_honey"
	return &"eco_farm"


func _look_spells(view: Rect2) -> void:
	var m := sim.magic
	if m == null:
		return
	for i in m.fx_ids.size():
		var id := m.fx_ids[i]
		if _fx_seen.has(id):
			continue
		_fx_seen[id] = true
		var at := Iso.fixed_to_screen(m.fx_x[i], m.fx_y[i])
		if not view.has_point(at) and m.fx_owner[i] != player:
			continue
		var spell := m.spells[m.fx_spell[i]].id
		play_at(spell, at, 500, 0.0)
		if spell == &"sp_perkunas":
			play_at(&"rain_loop", at, 500, 0.0)


## Picks the ambience of the land most seen on screen and crossfades to it.
func _look_land() -> void:
	var vp := get_viewport()
	var rect := vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	var count: Dictionary[StringName, int] = {}
	for i in 7:
		for j in 5:
			var at := rect.position + rect.size * Vector2((i + 0.5) / 7.0, (j + 0.5) / 5.0)
			var c := Iso.screen_to_cell_index(at)
			if not sim.nav.in_bounds(c.x, c.y):
				continue
			var land: StringName = LAND.get(
				sim.nav.terrain_at(sim.nav.cell_at(c.x, c.y)), &"amb_field"
			)
			count[land] = count.get(land, 0) + 1
	var best: StringName = &"amb_field"
	var most := 0
	for land: StringName in count:
		if count[land] > most:
			most = count[land]
			best = land
	if best == _ambience_id:
		return
	var streams := Sfx.streams(best)
	if streams.is_empty():
		return
	_ambience_id = best
	var old := _ambience[_ambience_on]
	_ambience_on = 1 - _ambience_on
	var fresh := _ambience[_ambience_on]
	var stream := (streams[randi() % streams.size()] as AudioStream).duplicate() as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	fresh.stream = stream
	fresh.volume_db = -60.0
	fresh.play()
	var t := create_tween().set_parallel()
	t.tween_property(fresh, "volume_db", AMBIENCE_DB, FADE)
	t.tween_property(old, "volume_db", -60.0, FADE)


func _sees(x: int, y: int) -> bool:
	return units.reveal_all or sim.vision.sees_cell(player, sim.nav.cell_of(x, y))
