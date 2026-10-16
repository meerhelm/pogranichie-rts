extends SceneTree
## Opens the skirmish, lets it run a few seconds and saves a screenshot, to see the art in the
## game. Needs a display (on a server: xvfb-run with the opengl3 driver):
##   godot --rendering-driver opengl3 -s tools/art/screenshot.gd -- out.png [seconds] [zoom]
##   [scene] [action], action: select (the player's units), menu (game menu), help (F1 page),
##   look:X:Y (no fog, camera on cell X, Y), showcase:FACTION:X:Y (every prototype building
##   and unit of a faction, gdl or to, laid out from cell X, Y, finished, the camera on them)

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
	change_scene_to_file(_scene)
	_shoot.call_deferred()


func _shoot() -> void:
	await create_timer(0.5).timeout
	var cam := current_scene.get_node_or_null("Camera") as Camera2D
	if cam != null:
		cam.zoom = Vector2.ONE * _zoom
	await create_timer(_seconds).timeout
	_act()
	await create_timer(1.0).timeout
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
	elif _action == "menu" and main.has_node("UI/Hud"):
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


func _finish(sim: Simulation, id: int) -> void:
	var b := sim.economy.buildings
	b.done[id - 1] = 1
	b.progress[id - 1] = b.work[id - 1]
	b.hp[id - 1] = b.max_hp[id - 1]
