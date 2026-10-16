extends SceneTree
## Opens the skirmish, lets it run a few seconds and saves a screenshot, to see the art in the
## game. Needs a display (on a server: xvfb-run with the opengl3 driver):
##   godot --rendering-driver opengl3 -s tools/art/screenshot.gd -- out.png [seconds] [zoom]
##   [scene] [action], action: select (the player's units), menu (game menu), help (F1 page),
##   look:X:Y (no fog, camera on cell X, Y)

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
	elif _action == "help" and main.has_node("UI/Hud"):
		(main.get_node("UI/Hud") as Hud).help.open(true)
