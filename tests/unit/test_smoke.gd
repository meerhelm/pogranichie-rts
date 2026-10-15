extends GutTest
## M0 smoke tests: the project boots and the pinned addons load on this Godot version.


func test_engine_is_pinned_4_7() -> void:
	var info: Dictionary = Engine.get_version_info()
	assert_eq(info["major"], 4)
	assert_eq(info["minor"], 7)


func test_main_scene_instantiates() -> void:
	var scene: PackedScene = load("res://game/main.tscn")
	assert_not_null(scene)
	var main: Node = scene.instantiate()
	add_child_autofree(main)
	var label: Label = main.get_node("UI/VersionLabel")
	assert_string_contains(label.text, "Pogranichie")


func test_limboai_extension_loaded() -> void:
	assert_true(ClassDB.class_exists("BTPlayer"), "LimboAI GDExtension is not loaded")
	assert_true(ClassDB.class_exists("LimboHSM"), "LimboAI GDExtension is not loaded")


func test_dialogic_autoload_present() -> void:
	assert_not_null(get_tree().root.get_node_or_null("Dialogic"), "Dialogic autoload missing")
