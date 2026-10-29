extends SceneTree
## Opens the skirmish, lets it run a few seconds and saves a screenshot, to see the art in the
## game. Needs a display (on a server: xvfb-run with the opengl3 driver):
##   godot --rendering-driver opengl3 -s tools/art/screenshot.gd -- out.png [seconds] [zoom]
##   [scene] [action], action: select (the player's units), menu (game menu), help (F1 page),
##   look:X:Y (no fog, camera on cell X, Y), showcase:FACTION:X:Y (every prototype building
##   and unit of a faction, gdl or to, laid out from cell X, Y, finished, the camera on them),
##   click:WHAT (no fog, the camera on the first deposit, forest cell, enemy building or wild
##   animal, WHAT = node, forest, building or animal, and a left click on it), dismantle (the
##   player's peasants take a house by the town centre apart, nearly done, so its salvage shows),
##   work (the same, caught while they work), fight (no fog, spearmen against knechts and a
##   crossbowman by the town centre), panel:WHAT[:HOVER] (the bottom panel with WHAT selected:
##   peasants, army (spearmen, a light horseman, a wise woman) or a building base id such as
##   town_center or granary, finished by the town centre; plenty of resources; the mouse over the
##   button HOVER, a building, unit, tech or spell id, or order<N> for the Nth order button),
##   towers:X:Y (no fog: from cell X, Y a palisade ring of the player's with a tower in each
##   corner and a gate, a house inside; knechts outside storm the house, spearmen inside),
##   about (on res://ui/main_menu.tscn: the «About the game» page),
##   single (on res://ui/main_menu.tscn: the single player page with the map list),
##   resource:R (the top bar's tooltip of resource R, 0 food ... 3 silver, after the player's
##   peasants gathered a minute and a half: three on wood, two on food (a field by the town
##   centre), a peasant queued at the town centre and the saw researched),
##   speed:N (the game speed button stepped N times up, e.g. 2 for 4x),
##   forest:X:Y (no fog: a forest patch from cell X, Y with the player's units in it and behind
##   it, two selected, one on open ground beside it and one behind a house, to see the trees and
##   the house in front of them turn see-through, and the tree tints),
##   idle:N (the idle worker button pressed N times: the Nth idle peasant selected, camera on it),
##   units:X:Y:ID,ID,... (no fog: the listed units, heroes too, in a row from cell X, Y, two
##   cells apart, the camera on them)
##   alerts (the fight by the town centre and a house of the player's finished during it, shot
##   while the minimap blinks: red at the fight with the red glow, green at the house, white at
##   a mission's signal put by hand south of the town centre),
##   rally (the player's town centre selected, its rally point set a few cells away),
##   play (in a mission: the briefing closed, the mission starts),
##   talk (in a mission: the briefing closed and the opening cutscene skipped, so the first
##   dialogue line and hints show),
##   effects (no fog: the player's town centre and a house on fire, «Болотный туман» beside them
##   and a spearman carrying «Реликвия в строю», to see the particle effects),
##   briefing (in a mission: the briefing closed, the mission run a little, then F2's briefing),
##   net (on res://ui/main_menu.tscn: the «Network play» page, a game created and waiting),
##   netlobby:ADDRESS (on the main menu: joins the game at ADDRESS, picks the Crown and is ready;
##   run with a `net` shot of the host for both sides of the lobby),
##   nethost / netjoin:ADDRESS (a network game over ENet: run one of each, the host first; the
##   game scene opens once both are ready in the lobby, then the player's units are selected,
##   the guest sends a chat line, the host answers one and pauses the game).
## SHOT_MISSION=gdl_01 (or another mission id) opens that mission instead of the skirmish; a new
## mission starts with its briefing open. SHOT_MAP=map_sk_orsha (or another SkirmishMaps id) plays
## the skirmish on that map.
## SHOT_LOCALE=be (or pl, uk, lt) in the environment shoots in that language; SHOT_AFTER=N
## waits N seconds after the action instead of 1 (2.5 for actions with arguments).

var _out := "user://screenshot.png"
var _seconds := 6.0
var _zoom := 1.0
var _scene := "res://game/main.tscn"
var _action := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_seconds = float(args[1])
	if args.size() > 2:
		_zoom = float(args[2])
	if args.size() > 3:
		_scene = args[3]
	if args.size() > 4:
		_action = args[4]
	root.size = Vector2i(1600, 900)
	if not OS.get_environment("SHOT_LOCALE").is_empty():
		TranslationServer.set_locale(OS.get_environment("SHOT_LOCALE"))
	if not OS.get_environment("SHOT_MISSION").is_empty():
		GameSettings.mission_id = OS.get_environment("SHOT_MISSION")
	if not OS.get_environment("SHOT_MAP").is_empty():
		GameSettings.ensure_loaded()
		GameSettings.skirmish_map = OS.get_environment("SHOT_MAP")
	if _action == "nethost" or _action.begins_with("netjoin:"):
		_start_net()
		return
	change_scene_to_file(_scene)
	_shoot.call_deferred()


## Shakes hands with the other screenshot process, then opens the game scene.
func _start_net() -> void:
	GameSettings.ensure_loaded()
	var t := EnetTransport.new()
	var s := NetSession.open(self, t)
	if _action == "nethost":
		t.host()
		var factions: Array[StringName] = [&"gdl", &"to"]
		s.host_game(GameSettings.skirmish_map, factions, Lockstep.DEFAULT_DELAY)
	else:
		t.join(_action.split(":")[1])
		s.join_game()
	s.lobby_changed.connect(
		func() -> void:
			if s.state == NetSession.State.LOBBY and not s.ready_flags[s.local_player - 1]:
				s.set_ready(true)
			if s.is_host and s.both_ready():
				s.start_game()
	)
	s.started.connect(
		func() -> void:
			change_scene_to_file(_scene)
			_shoot.call_deferred()
	)
	s.failed.connect(
		func(why: String) -> void:
			printerr("network game did not start: ", why)
			quit(1)
	)


func _shoot() -> void:
	await create_timer(0.5).timeout
	if not OS.get_environment("SHOT_LOCALE").is_empty():
		TranslationServer.set_locale(OS.get_environment("SHOT_LOCALE"))
	var cam := current_scene.get_node_or_null("Camera") as Camera2D
	if cam != null:
		cam.zoom = Vector2.ONE * _zoom
	await create_timer(_seconds).timeout
	_act()
	var after := 2.5 if _action.count(":") > 1 else 1.0
	if not OS.get_environment("SHOT_AFTER").is_empty():
		after = float(OS.get_environment("SHOT_AFTER"))
	await create_timer(after).timeout
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(_out)
	print("saved ", _out)
	quit()


func _act() -> void:
	var main := current_scene
	if _action == "select" and main.get("sim") != null:
		var input: PlayerInput = main.get_node("UI/PlayerInput")
		var sim: Simulation = main.get("sim")
		var ids := PackedInt32Array()
		for id in sim.entities.alive_ids:
			if sim.entities.owners[id - 1] == 1:
				ids.append(id)
		input.selection.ids = ids
		input.selection.changed.emit()
	elif (_action == "nethost" or _action.begins_with("netjoin:")) and main.get("sim") != null:
		var input: PlayerInput = main.get_node("UI/PlayerInput")
		var sim: Simulation = main.get("sim")
		var ids := PackedInt32Array()
		for id in sim.entities.alive_ids:
			if sim.entities.owners[id - 1] == input.player:
				ids.append(id)
		input.selection.ids = ids
		input.selection.changed.emit()
		print("network game: player %d at tick %d" % [input.player, sim.tick])
		var chat: NetChat = main.get_node("UI/NetChat")
		if _action == "nethost":
			chat._on_submitted("Gotowi? Zaczynamy.")
			NetSession.current.set_paused(true)
		else:
			chat._on_submitted("Да, пачынаем!")
	elif _action == "net" and main.get("_net") != null:
		main._network.pressed.emit()
		var lobby: NetLobby = main.get("_net")
		lobby.player_name.text = "Vitaut"
		lobby.create.pressed.emit()
	elif _action.begins_with("netlobby:") and main.get("_net") != null:
		main._network.pressed.emit()
		var lobby: NetLobby = main.get("_net")
		lobby.player_name.text = "Jagiello"
		lobby.address.text = _action.split(":")[1]
		lobby.join.pressed.emit()
		await create_timer(1.5).timeout
		lobby.mine.select(SkirmishSetup.FACTIONS.find(&"pl"))
		lobby.mine.item_selected.emit(lobby.mine.selected)
		await create_timer(0.5).timeout
		lobby.ready_box.button_pressed = true
	elif _action == "single" and main.get("_single") != null:
		main._single_button.pressed.emit()
	elif _action == "about" and main.get("_about") != null:
		(main.get("_about") as AboutPanel).open()
	elif _action == "rally":
		_rally(main)
	elif _action == "play" and main.get("briefing") != null:
		(main.get("briefing") as MissionBriefing).close()
	elif _action == "talk" and main.get("briefing") != null:
		(main.get("briefing") as MissionBriefing).close()
		await create_timer(0.5).timeout
		var panel: MissionPanel = main.get("mission_panel")
		if panel.in_cutscene():
			panel.end_cutscene()
	elif _action == "briefing" and main.get("briefing") != null:
		var briefing: MissionBriefing = main.get("briefing")
		briefing.close()
		await create_timer(4.0).timeout
		briefing.open()
	elif _action == "menu" and main.has_node("UI/Hud"):
		if main.get("briefing") != null:
			(main.get("briefing") as MissionBriefing).close()
		(main.get_node("UI/Hud") as Hud).menu.open()
	elif _action.begins_with("look:"):
		var xy := _action.split(":")
		var sim: Simulation = main.get("sim")
		sim.vision.rules = null
		(main.get_node("World/Fog") as Node2D).visible = false
		var cam: RtsCamera = main.get_node("Camera")
		cam.look_at_point(Iso.cell_to_screen(Vector2(float(xy[1]), float(xy[2]))))
	elif _action.begins_with("showcase:"):
		var parts := _action.split(":")
		_showcase(main, parts[1], int(parts[2]), int(parts[3]))
	elif _action == "dismantle" or _action == "work":
		_dismantle(main, _action == "work")
	elif _action == "fight":
		_fight(main)
	elif _action == "alerts":
		_alerts(main)
	elif _action == "effects":
		_effects(main)
	elif _action.begins_with("towers:"):
		var parts := _action.split(":")
		_towers(main, int(parts[1]), int(parts[2]))
	elif _action.begins_with("forest:"):
		var parts := _action.split(":")
		_forest(main, int(parts[1]), int(parts[2]))
	elif _action.begins_with("units:"):
		var parts := _action.split(":")
		_units(main, int(parts[1]), int(parts[2]), parts[3].split(","))
	elif _action.begins_with("click:"):
		_click(main, _action.split(":")[1])
	elif _action.begins_with("panel:"):
		_panel(main, _action.split(":"))
	elif _action.begins_with("resource:"):
		_resource_tip.call_deferred(main, int(_action.split(":")[1]))
	elif _action.begins_with("speed:"):
		for i in int(_action.split(":")[1]):
			(main.get_node("UI/Hud") as Hud).step_speed(1)
	elif _action.begins_with("idle:"):
		for i in int(_action.split(":")[1]):
			(main.get_node("UI/Hud") as Hud)._idle_button.pressed.emit()
	elif _action == "help" and main.has_node("UI/Hud"):
		(main.get_node("UI/Hud") as Hud).help.open(true)


## Lays out every prototype building of `faction` from cell (x0, y0) in rows, a palisade line
## with a gate and a corner, and one of each unit in front; no fog, camera on the middle.
func _showcase(main: Node, faction: String, x0: int, y0: int) -> void:
	var sim: Simulation = main.get("sim")
	sim.vision.rules = null
	(main.get_node("World/Fog") as Node2D).visible = false
	var proto: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tools/catalog/prototype.json")
	)
	var grass := sim.nav.terrain_index(&"t_grass")
	for y in range(y0 - 1, y0 + 24):
		for x in range(x0 - 1, x0 + 26):
			if sim.nav.in_bounds(x, y):
				sim.nav.set_terrain(sim.nav.cell_at(x, y), grass)
	var x := x0
	var y := y0
	var row_h := 0
	for id: String in proto["buildings"]:
		if not id.begins_with(faction + "_"):
			continue
		var def: BuildingDef = load("res://data/buildings/%s.tres" % id)
		if def.base_id in [&"palisade", &"gate"]:
			continue
		var w: int = def.params.get(&"size_w", 1)
		var h: int = def.params.get(&"size_h", 1)
		if x + w > x0 + 24:
			x = x0
			y += row_h + 1
			row_h = 0
		_finish(sim, sim.economy._found(1, def, x, y, false))
		x += w + 1
		row_h = maxi(row_h, h)
	y += row_h + 1
	var pal: BuildingDef = load("res://data/buildings/%s_palisade.tres" % faction)
	var gate: BuildingDef = load("res://data/buildings/%s_gate.tres" % faction)
	for i in 7:
		_finish(sim, sim.economy._found(1, gate if i == 3 else pal, x0 + i, y, false))
	for i in 3:
		_finish(sim, sim.economy._found(1, pal, x0 + 6, y + 1 + i, false))
	var ux := x0 + 8
	for id: String in proto["units"]:
		if id.begins_with(faction + "_") or (faction == "gdl" and id.begins_with("nt_")):
			var at := Fixed.from_cells(ux) + Fixed.ONE / 2
			sim.spawn_unit(StringName(id), 1, at, Fixed.from_cells(y + 1) + Fixed.ONE / 2)
			ux += 1
	var cam: RtsCamera = main.get_node("Camera")
	cam.look_at_point(Iso.cell_to_screen(Vector2(x0 + 12, y0 + 9)))


## The listed units of player 1 in a row from cell (x0, y0), two cells apart; no fog.
func _units(main: Node, x0: int, y0: int, ids: PackedStringArray) -> void:
	var sim: Simulation = main.get("sim")
	sim.vision.rules = null
	(main.get_node("World/Fog") as Node2D).visible = false
	var grass := sim.nav.terrain_index(&"t_grass")
	for y in range(y0 - 2, y0 + 3):
		for x in range(x0 - 2, x0 + ids.size() * 2 + 2):
			if sim.nav.in_bounds(x, y):
				sim.nav.set_terrain(sim.nav.cell_at(x, y), grass)
	for i in ids.size():
		var at := Fixed.from_cells(x0 + i * 2) + Fixed.ONE / 2
		sim.spawn_unit(StringName(ids[i]), 1, at, Fixed.from_cells(y0) + Fixed.ONE / 2)
	var cam: RtsCamera = main.get_node("Camera")
	cam.look_at_point(Iso.cell_to_screen(Vector2(x0 + ids.size(), y0)))


## A forest patch from cell X, Y with the player's units in and around it, two selected, and
## one behind a house, the camera on them: trees and the house in front of them turn
## see-through; the tree tints.
func _forest(main: Node, x0: int, y0: int) -> void:
	var sim: Simulation = main.get("sim")
	sim.vision.rules = null
	(main.get_node("World/Fog") as Node2D).visible = false
	var grass := sim.nav.terrain_index(&"t_grass")
	var forest := sim.nav.terrain_index(NavGrid.FOREST)
	for y in range(y0 - 4, y0 + 12):
		for x in range(x0 - 4, x0 + 20):
			if sim.nav.in_bounds(x, y):
				var inside := x >= x0 and x < x0 + 12 and y >= y0 and y < y0 + 10
				sim.nav.set_terrain(sim.nav.cell_at(x, y), forest if inside else grass)
	var places := [
		[&"gdl_spearman", 3, 3],
		[&"gdl_spearman", 4, 4],
		[&"gdl_peasant", 7, 2],
		[&"gdl_samogitian", 6, 6],
		[&"gdl_light_horse", 9, 5],
		[&"gdl_peasant", 2, 8],
		[&"gdl_spearman", -2, 2],
		[&"gdl_peasant", 5, -2],
		[&"gdl_spearman", 13, -1],
	]
	var input: PlayerInput = main.get_node("UI/PlayerInput")
	var ids := PackedInt32Array()
	for p: Array in places:
		var at_x := Fixed.from_cells(x0 + Num.of(p[1])) + Fixed.ONE / 2
		var at_y := Fixed.from_cells(y0 + Num.of(p[2])) + Fixed.ONE / 2
		var id := sim.spawn_unit(str(p[0]), 1, at_x, at_y)
		if ids.size() < 2:
			ids.append(id)
	var eco := sim.economy
	var house := eco._found(1, sim.catalog().building(&"gdl_house"), x0 + 15, y0 + 3, false)
	eco.complete(house)
	var behind := Fixed.from_cells(x0 + 14) + Fixed.HALF
	sim.spawn_unit(&"gdl_spearman", 1, behind, Fixed.from_cells(y0 + 2) + Fixed.HALF)
	input.selection.ids = ids
	input.selection.changed.emit()
	var cam: RtsCamera = main.get_node("Camera")
	cam.look_at_point(Iso.cell_to_screen(Vector2(x0 + 9, y0 + 6)))


func _towers(main: Node, x0: int, y0: int) -> void:
	var sim: Simulation = main.get("sim")
	sim.vision.rules = null
	(main.get_node("World/Fog") as Node2D).visible = false
	var grass := sim.nav.terrain_index(&"t_grass")
	for y in range(y0, y0 + 14):
		for x in range(x0, x0 + 18):
			sim.nav.set_terrain(sim.nav.cell_at(x, y), grass)
	var eco := sim.economy
	var corners := [Vector2i(5, 2), Vector2i(13, 2), Vector2i(5, 10), Vector2i(13, 10)]
	for y in range(2, 11):
		for x in range(5, 14):
			if x != 5 and x != 13 and y != 2 and y != 10:
				continue
			var id := &"gdl_palisade"
			if Vector2i(x, y) in corners:
				id = &"gdl_tower"
			elif Vector2i(x, y) == Vector2i(5, 6):
				id = &"gdl_gate"
			eco.complete(eco._found(1, sim.catalog().building(id), x0 + x, y0 + y, false))
	var house := eco._found(1, sim.catalog().building(&"gdl_house"), x0 + 9, y0 + 5, false)
	eco.complete(house)
	var knechts := PackedInt32Array()
	for i in 6:
		var at := Vector2i(Fixed.from_cells(x0) + Fixed.HALF, Fixed.from_cells(y0 + 3 + i))
		knechts.append(sim.spawn_unit(&"to_knecht", 2, at.x, at.y))
	sim.enqueue(SimCommand.on_building(sim.tick, 2, SimCommand.Kind.ASSAULT, knechts, house))
	for i in 3:
		var at := Fixed.from_cells(x0 + 7 + i) + Fixed.HALF
		sim.spawn_unit(&"gdl_spearman", 1, at, Fixed.from_cells(y0 + 8) + Fixed.HALF)
	var cam: RtsCamera = main.get_node("Camera")
	cam.look_at_point(Iso.cell_to_screen(Vector2(x0 + 8, y0 + 6)))


func _finish(sim: Simulation, id: int) -> void:
	var b := sim.economy.buildings
	b.done[id - 1] = 1
	b.progress[id - 1] = b.work[id - 1]
	b.hp[id - 1] = b.max_hp[id - 1]


## Turns the fog off, puts the camera on the first thing of the kind and clicks it.
func _click(main: Node, what: String) -> void:
	var sim: Simulation = main.get("sim")
	sim.vision.rules = null
	(main.get_node("World/Fog") as Node2D).visible = false
	var at := Vector2(-1, -1)
	match what:
		"node":
			var cell := sim.economy.nodes.cells[sim.economy.nodes.alive_ids[0] - 1]
			at = Vector2(cell % sim.nav.width, cell / sim.nav.width) + Vector2(0.5, 0.5)
		"forest":
			for cell in sim.nav.cell_count():
				if sim.economy.nodes.wood[cell] > 0:
					at = Vector2(cell % sim.nav.width, cell / sim.nav.width) + Vector2(0.5, 0.5)
					break
		"building":
			for b in sim.economy.buildings.alive_ids:
				if sim.economy.buildings.owners[b - 1] != 1:
					var s := b - 1
					var store := sim.economy.buildings
					at = Vector2(
						store.cell_x[s] + store.w[s] / 2.0, store.cell_y[s] + store.h[s] / 2.0
					)
					break
		"animal":
			for id in sim.entities.alive_ids:
				if sim.entities.owners[id - 1] == 0:
					at = Iso.screen_to_cell(
						Iso.fixed_to_screen(sim.entities.pos_x[id - 1], sim.entities.pos_y[id - 1])
					)
					break
	var cam: RtsCamera = main.get_node("Camera")
	var world := Iso.cell_to_screen(at)
	cam.look_at_point(world)
	await process_frame
	await process_frame
	var point := root.get_canvas_transform() * world
	if what == "animal":
		point.y -= UnitView.RADIUS
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = point
		ev.global_position = point
		root.push_input(ev)


func _dismantle(main: Node, working := false) -> void:
	var sim: Simulation = main.get("sim")
	var store := sim.economy.buildings
	var tc := store.alive_ids[0]
	for b in store.alive_ids:
		if store.owners[b - 1] == 1 and store.defs[b - 1].base_id == &"town_center":
			tc = b
	var house: BuildingDef = load("res://data/buildings/gdl_house.tres")
	var hx := store.cell_x[tc - 1] + 5
	var hy := store.cell_y[tc - 1]
	while sim.economy.placement.can_place(1, house, hx, hy, false, true) != EconomySystem.Fail.OK:
		hy += 1
	var b := sim.economy._found(1, house, hx, hy, false)
	_finish(sim, b)
	var ids := PackedInt32Array()
	for id in sim.entities.alive_ids:
		if sim.entities.owners[id - 1] == 1:
			ids.append(id)
	sim.enqueue(SimCommand.on_building(sim.tick, 1, SimCommand.Kind.DISMANTLE, ids, b))
	sim.step()
	if not working:
		store.dismantle_left[b - 1] = 600
	var at := Vector2(hx, hy)
	for i in 300 if not working else 80:
		if not store.is_alive(b):
			break
		sim.step()
	var cam: RtsCamera = main.get_node("Camera")
	cam.look_at_point(Iso.cell_to_screen(at))


func _fight(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	sim.vision.rules = null
	(main.get_node("World/Fog") as Node2D).visible = false
	var store := sim.economy.buildings
	var tc := store.alive_ids[0]
	for b in store.alive_ids:
		if store.owners[b - 1] == 1 and store.defs[b - 1].base_id == &"town_center":
			tc = b
	var x := store.cell_x[tc - 1] + 6
	var y := store.cell_y[tc - 1] + 6
	for i in 4:
		var fy := Fixed.from_cells(y + i) + Fixed.ONE / 2
		sim.spawn_unit(&"gdl_spearman", 1, Fixed.from_cells(x), fy)
		sim.spawn_unit(&"to_knecht", 2, Fixed.from_cells(x + 3), fy)
	sim.spawn_unit(&"to_crossbow", 2, Fixed.from_cells(x + 6), Fixed.from_cells(y + 2))
	sim.spawn_unit(&"gdl_forest_archer", 1, Fixed.from_cells(x - 3), Fixed.from_cells(y + 2))
	for i in 50:
		sim.step()
	var cam: RtsCamera = main.get_node("Camera")
	cam.look_at_point(Iso.cell_to_screen(Vector2(x + 2, y + 2)))


func _alerts(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	var store := sim.economy.buildings
	var tc := store.alive_ids[0]
	for b in store.alive_ids:
		if store.owners[b - 1] == 1 and store.defs[b - 1].base_id == &"town_center":
			tc = b
	var house := sim.economy._found(
		1,
		sim.catalog().building(&"gdl_house"),
		store.cell_x[tc - 1] + 14,
		store.cell_y[tc - 1] - 2,
		false
	)
	_fight(main)
	var minimap := (main.get_node("UI/Hud") as Hud).minimap
	while minimap._pings.is_empty():
		await process_frame
	_finish(sim, house)
	var tc_cell := Vector2(store.cell_x[tc - 1], store.cell_y[tc - 1])
	minimap.ping(MinimapAlerts.Kind.SIGNAL, tc_cell + Vector2(4, 22))
	while minimap._pings.size() < 3:
		await process_frame
	# Frames under Xvfb are slow: shoot the blinks at a set point of a blink, SHOT_PHASE (0..1,
	# 0.45 near the brightest).
	var phase := 0.45
	if not OS.get_environment("SHOT_PHASE").is_empty():
		phase = float(OS.get_environment("SHOT_PHASE"))
	minimap.set_process(false)
	for p: Dictionary in minimap._pings:
		p["age"] = Minimap.BLINK * phase
	minimap._age_pings(0.0)
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(_out)
	print("saved ", _out)
	quit()


func _effects(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	sim.vision.rules = null
	(main.get_node("World/Fog") as Node2D).visible = false
	var store := sim.economy.buildings
	var tc := store.alive_ids[0]
	for b in store.alive_ids:
		if store.owners[b - 1] == 1 and store.defs[b - 1].base_id == &"town_center":
			tc = b
	var x := store.cell_x[tc - 1]
	var y := store.cell_y[tc - 1]
	var house: BuildingDef = load("res://data/buildings/%s.tres" % "gdl_house")
	var hut := sim.economy._found(1, house, x + 5, y, false)
	_finish(sim, hut)
	sim.fire.ignite(tc)
	sim.fire.ignite(hut)
	store.hp[tc - 1] = store.max_hp[tc - 1] / 3
	var magic := sim.magic
	var mist: SpellDef = load("res://data/spells/sp_bog_mist.tres")
	magic._add_effect(mist, 1, 0, Fixed.from_cells(x + 2), Fixed.from_cells(y + 7), 3)
	var bearer := sim.spawn_unit(
		&"gdl_spearman", 1, Fixed.from_cells(x + 7), Fixed.from_cells(y + 5)
	)
	var relic: SpellDef = load("res://data/spells/sp_relic.tres")
	magic._add_effect(relic, 1, bearer, Fixed.from_cells(x + 7), Fixed.from_cells(y + 5), 2)
	for i in 10:
		sim.step()
	var cam: RtsCamera = main.get_node("Camera")
	cam.look_at_point(Iso.cell_to_screen(Vector2(x + 4, y + 4)))


func _rally(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	var input: PlayerInput = main.get_node("UI/PlayerInput")
	var store := sim.economy.buildings
	var tc := store.alive_ids[0]
	for b in store.alive_ids:
		if store.owners[b - 1] == 1 and store.defs[b - 1].base_id == &"town_center":
			tc = b
	var x := Fixed.from_cells(store.cell_x[tc - 1] + 7)
	var y := Fixed.from_cells(store.cell_y[tc - 1] + 5)
	sim.enqueue(SimCommand.building_rally(sim.tick, 1, PackedInt32Array([tc]), x, y))
	input.selected_building = tc
	input.buildings.selected = tc
	input.economy_changed.emit()


func _panel(main: Node, parts: PackedStringArray) -> void:
	var sim: Simulation = main.get("sim")
	var input: PlayerInput = main.get_node("UI/PlayerInput")
	var state := sim.economy.player(1)
	for r in 4:
		state.stock[r] = 600
	var store := sim.economy.buildings
	var tc := store.alive_ids[0]
	for b in store.alive_ids:
		if store.owners[b - 1] == 1 and store.defs[b - 1].base_id == &"town_center":
			tc = b
	var x := store.cell_x[tc - 1]
	var y := store.cell_y[tc - 1]
	var ids := PackedInt32Array()
	match parts[1]:
		"peasants":
			for id in sim.entities.alive_ids:
				if sim.entities.owners[id - 1] == 1:
					ids.append(id)
		"army":
			for i in 5:
				var at := Fixed.from_cells(x + 5 + i)
				ids.append(sim.spawn_unit(&"gdl_spearman", 1, at, Fixed.from_cells(y + 6)))
			ids.append(
				sim.spawn_unit(
					&"gdl_light_horse", 1, Fixed.from_cells(x + 5), Fixed.from_cells(y + 7)
				)
			)
			ids.append(
				sim.spawn_unit(
					&"gdl_light_horse", 1, Fixed.from_cells(x + 6), Fixed.from_cells(y + 7)
				)
			)
			ids.append(
				sim.spawn_unit(
					&"gdl_znakharka", 1, Fixed.from_cells(x + 7), Fixed.from_cells(y + 7)
				)
			)
			for i in 30:
				sim.step()
		_:
			var b := tc
			if parts[1] != "town_center":
				var def := sim.economy.db.building(StringName("gdl_" + parts[1]))
				b = sim.economy._found(1, def, x + 6, y - 1, false)
				_finish(sim, b)
			input.selected_building = b
	if not ids.is_empty():
		input.selection.ids = ids
	input.selection.changed.emit()
	if parts.size() > 2:
		_hover.call_deferred(main, parts[2])


func _resource_tip(main: Node, r: int) -> void:
	var sim: Simulation = main.get("sim")
	var hud: Hud = main.get_node("UI/Hud")
	var eco := sim.economy
	var state := eco.player(1)
	var peasants := PackedInt32Array()
	var tc := BuildingStore.NO_ID
	for id in sim.entities.alive_ids:
		if sim.entities.owners[id - 1] == 1 and eco.unit_defs[id - 1] != null:
			if eco.unit_defs[id - 1].has_class(&"peasant"):
				peasants.append(id)
	for b in eco.buildings.alive_ids:
		if eco.buildings.owners[b - 1] == 1 and eco.buildings.defs[b - 1].base_id == &"town_center":
			tc = b
	var at := Vector2i(eco.buildings.cell_x[tc - 1], eco.buildings.cell_y[tc - 1])
	var farm := sim.economy._found(1, eco.db.building(&"gdl_farm"), at.x + 5, at.y + 1, false)
	_finish(sim, farm)
	var forest := -1
	var best := 1 << 30
	for c in sim.nav.cell_count():
		var d := absi(c % sim.nav.width - at.x) + absi(c / sim.nav.width - at.y)
		if eco.nodes.wood[c] > 0 and d < best:
			best = d
			forest = c
	var fx := Fixed.from_cells(forest % sim.nav.width) + Fixed.HALF
	var fy := Fixed.from_cells(forest / sim.nav.width) + Fixed.HALF
	sim.enqueue(SimCommand.gather_at(sim.tick, 1, peasants.slice(0, 3), fx, fy))
	sim.enqueue(
		SimCommand.gather(sim.tick, 1, peasants.slice(3, 5), EconomySystem.Target.BUILDING, farm)
	)
	state.techs[&"t_saw"] = true
	state.gather_bonus[ResourceNodes.Source.WOOD] += 200
	main.get_node("SimClock").paused = true
	for i in 1800:
		sim.step()
		hud.flow.sample(sim.tick, state)
		if i == 1500:
			var peasant := SkirmishSetup.peasant_of(eco.db, state.faction)
			sim.enqueue(SimCommand.queue_item(sim.tick, 1, tc, peasant))
	hud.refresh()
	await process_frame
	var box: Control = hud._resource_boxes[r]
	var tip := Tips.make_label(ResourceTip.make(eco, 1, r, hud.flow).bbcode(), IconButton.TIP_WIDTH)
	var panel_box := PanelContainer.new()
	panel_box.add_theme_stylebox_override("panel", hud.get_theme_stylebox("panel", "TooltipPanel"))
	panel_box.add_child(tip)
	hud.add_child(panel_box)
	await process_frame
	var rect := box.get_global_rect()
	panel_box.position = Vector2(rect.position.x, rect.end.y + 6)


func _hover(main: Node, what: String) -> void:
	var hud: Hud = main.get_node("UI/Hud")
	hud.refresh()
	for i in 20:
		await process_frame
	var panel := hud.commands
	var button: Control = null
	if what.begins_with("order"):
		button = panel._orders.get_child(int(what.substr(5)))
	elif panel._build_buttons.has(StringName(what)):
		button = panel._build_buttons[StringName(what)]
	elif panel._item_buttons.has(StringName(what)):
		button = panel._item_buttons[StringName(what)]
	elif panel._spell_buttons.has(StringName(what)):
		button = panel._spell_buttons[StringName(what)]
	if button == null:
		push_warning("no button " + what)
		return
	# The tooltip as Godot would show it, put above the button (no real mouse under Xvfb).
	var tip := (button as IconButton)._make_custom_tooltip(button.tooltip_text) as Control
	var panel_box := PanelContainer.new()
	panel_box.theme_type_variation = &"TooltipPanel"
	panel_box.add_theme_stylebox_override("panel", hud.get_theme_stylebox("panel", "TooltipPanel"))
	panel_box.add_child(tip)
	hud.add_child(panel_box)
	await process_frame
	var rect := button.get_global_rect()
	var at := Vector2(rect.position.x, rect.position.y - panel_box.size.y - 6)
	at.x = clampf(at.x, 8, hud.size.x - panel_box.size.x - 8)
	panel_box.position = at
	button.add_theme_stylebox_override("normal", button.get_theme_stylebox("hover"))
