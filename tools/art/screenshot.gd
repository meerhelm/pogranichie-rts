extends SceneTree
## Opens the skirmish, lets it run a few seconds and saves a screenshot, to see the art in the
## game. Needs a display (on a server: xvfb-run with the opengl3 driver):
##   godot --rendering-driver opengl3 -s tools/art/screenshot.gd -- out.png [seconds] [zoom]

var _out := "user://screenshot.png"
var _seconds := 6.0
var _zoom := 1.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_seconds = float(args[1])
	if args.size() > 2:
		_zoom = float(args[2])
	root.size = Vector2i(1600, 900)
	change_scene_to_file("res://game/main.tscn")
	_shoot.call_deferred()


func _shoot() -> void:
	await create_timer(0.5).timeout
	var cam := current_scene.get_node_or_null("Camera") as Camera2D
	if cam != null:
		cam.zoom = Vector2.ONE * _zoom
	await create_timer(_seconds).timeout
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(_out)
	print("saved ", _out)
	quit()
