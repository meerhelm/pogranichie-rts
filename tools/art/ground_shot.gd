extends SceneTree
## Screenshot of every ground type, to judge the ground art without starting a game: a grass
## map with a round patch of each other terrain, the ground details on it. Needs a display
## (on a server: xvfb-run with the opengl3 driver):
##   godot --rendering-driver opengl3 -s tools/art/ground_shot.gd -- out.png [zoom] [size]

const SIZE := 44


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://ground.png"
	var zoom := float(args[1]) if args.size() > 1 else 0.5
	var n := int(args[2]) if args.size() > 2 else SIZE
	root.size = Vector2i(1600, 900)
	var db := CatalogDB.load_prototype()
	var grid := NavGrid.for_catalog(n, n, db)
	var grass := grid.terrain_index(&"t_grass")
	var others: Array[int] = []
	for i in grid.terrain_ids.size():
		if i != grass:
			others.append(i)
	for c in grid.cell_count():
		grid.terrain[c] = grass
	# Patches on a 4-column lattice, each a rough disc.
	var cols := 4
	var step := n / (cols + 1)
	for k in others.size():
		var cx := step * (k % cols + 1)
		var cy := step * (k / cols + 1)
		for y in range(cy - 4, cy + 5):
			for x in range(cx - 4, cx + 5):
				if not grid.in_bounds(x, y):
					continue
				var d := (x - cx) * (x - cx) + (y - cy) * (y - cy)
				if d <= 12 + (x * 7 + y * 3) % 5:
					grid.terrain[grid.cell_at(x, y)] = others[k]
	var world := Node2D.new()
	root.add_child(world)
	var map := MapView.new()
	world.add_child(map)
	map.build(grid)
	var decals := DecalLayer.new()
	world.add_child(decals)
	decals.build(grid)
	var cam := Camera2D.new()
	cam.zoom = Vector2.ONE * zoom
	cam.position = Iso.cell_to_screen(Vector2(n / 2.0, n / 2.0))
	world.add_child(cam)
	cam.make_current()
	for i in 4:
		await process_frame
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
