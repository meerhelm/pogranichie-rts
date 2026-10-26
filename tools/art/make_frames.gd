extends SceneTree
## Writes art/sprites/units/<id>/frames.tres for every unit sheet: the SpriteFrames UnitView's
## AnimatedSprite2D nodes play, one animation per action and facing ("walk_2"), cut from
## color.png as sheet.json describes (SpriteDB.build_frames). Run after rendering units, so the
## editor shows and can tune their animations; tests/unit/test_sprites.gd checks they match.
##   godot --headless -s tools/art/make_frames.gd [-- <unit id> ...]

const UNITS := "res://art/sprites/units"


func _init() -> void:
	var ids: Array[String] = []
	for a in OS.get_cmdline_user_args():
		ids.append(a)
	if ids.is_empty():
		for dir in DirAccess.get_directories_at(UNITS):
			ids.append(dir)
	var written := 0
	for id in ids:
		var s := SpriteDB.unit(StringName(id))
		if s == null:
			push_warning("no sheet for %s" % id)
			continue
		var path := UNITS.path_join(id).path_join("frames.tres")
		var err := ResourceSaver.save(SpriteDB.build_frames(s), path)
		if err != OK:
			push_error("cannot write %s: %s" % [path, error_string(err)])
			quit(1)
			return
		written += 1
	print("frames written: %d" % written)
	quit(0)
