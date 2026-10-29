class_name Sfx
extends Node
## Plays the sound effects: audio/sfx/<id>_<k>.ogg, the k-th picked variant of a sound from
## art_src/elevenlabs/sfx.json (one is picked at random, never the same twice in a row when there
## are more). Everything goes to the Sfx bus through a small pool of players; a sound asked for
## again within its gap is dropped, so a burst of events gives one sound, not a roar.
##
## One instance lives under the scene tree root (made by ensure(), kept across scene changes and
## working while the game is paused). It also gives every button in the game a click: buttons
## «ui_click», check boxes and option lists «ui_tab».

const DIR := "res://audio/sfx/"
## Players in the pool: the most sounds at once.
const VOICES := 12
## Default gap between two plays of the same sound, ms.
const GAP_MS := 80

static var _instance: Sfx

## Sound id -> its variant streams (empty: none on disk).
var _variants: Dictionary[StringName, Array] = {}
## Sound id -> Time.get_ticks_msec() of its last play, and the variant played.
var _last_time: Dictionary[StringName, int] = {}
var _last_variant: Dictionary[StringName, int] = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0


## The instance, made on first use.
static func ensure() -> Sfx:
	if _instance != null and is_instance_valid(_instance):
		return _instance
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	_instance = Sfx.new()
	_instance.name = "Sfx"  # notr
	tree.root.add_child.call_deferred(_instance)
	return _instance


## Plays sound `id` (if it has files). `gap_ms`: the least time between two plays of it;
## `pitch`: random pitch spread, 0.05 = ±5 %; `volume_db` on top of the file's level.
static func play(
	id: StringName, gap_ms: int = GAP_MS, pitch: float = 0.0, volume_db: float = 0.0
) -> void:
	var s := ensure()
	if s != null:
		s._play(id, gap_ms, pitch, volume_db)


## Whether sound `id` has at least one file.
static func has(id: StringName) -> bool:
	var s := ensure()
	return s != null and not s._streams(id).is_empty()


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Made here, not in _ready: sounds may be asked for before the node enters the tree.
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"Sfx"
		add_child(p)
		_pool.append(p)


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	_hook_buttons(get_tree().root)


func _play(id: StringName, gap_ms: int, pitch: float, volume_db: float) -> void:
	var streams := _streams(id)
	if streams.is_empty():
		return
	var now := Time.get_ticks_msec()
	if _last_time.has(id) and now - _last_time[id] < gap_ms:
		return
	_last_time[id] = now
	var k := randi() % streams.size()
	if streams.size() > 1 and k == _last_variant.get(id, -1):
		k = (k + 1) % streams.size()
	_last_variant[id] = k
	if not is_inside_tree():
		return
	var p := _free_player()
	p.stream = streams[k]
	p.pitch_scale = 1.0 + randf_range(-pitch, pitch)
	p.volume_db = volume_db
	p.play()


func _streams(id: StringName) -> Array:
	if _variants.has(id):
		return _variants[id]
	var out: Array = []
	var k := 1
	while ResourceLoader.exists("%s%s_%d.ogg" % [DIR, id, k]):
		var stream := load("%s%s_%d.ogg" % [DIR, id, k]) as AudioStream
		if stream != null:
			out.append(stream)
		k += 1
	_variants[id] = out
	return out


## A player that is free, or the one that started longest ago.
func _free_player() -> AudioStreamPlayer:
	for i in VOICES:
		var p := _pool[(_next + i) % VOICES]
		if not p.playing:
			_next = (_next + i + 1) % VOICES
			return p
	var oldest := _pool[_next]
	_next = (_next + 1) % VOICES
	return oldest


func _hook_buttons(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_hook_buttons(child)


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button == null or button.has_meta(&"sfx_hooked"):
		return
	button.set_meta(&"sfx_hooked", true)
	if button is CheckBox or button is CheckButton or button is OptionButton:
		button.pressed.connect(func() -> void: Sfx.play(&"ui_tab"))
	else:
		button.pressed.connect(func() -> void: Sfx.play(&"ui_click"))
