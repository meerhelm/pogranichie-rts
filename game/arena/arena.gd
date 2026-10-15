extends Node2D
## Debug arena (M4): pick two unit types and counts, press «Fight!» and the squads clash on a
## small field (open or forest). The left squad is yours to command like in the main scene.
## «Reset» rebuilds the field with the current choice; «Equal money» sizes both squads by the
## balance arena budget. Open with: godot res://game/arena/arena.tscn

## The choice survives reload_current_scene() through these.
static var type_a := &"gdl_spearman"
static var type_b := &"to_knight_brother"
static var count_a := 10
static var count_b := 3
static var forest := false
static var battle_seed := 1

var sim: Simulation
var _arena: BalanceArena
var _types: Array[StringName] = []
var _pick_a: OptionButton
var _pick_b: OptionButton
var _count_a: SpinBox
var _count_b: SpinBox
var _forest: CheckBox
var _result: Label

@onready var _clock: SimClock = $SimClock
@onready var _map: MapView = $World/Map
@onready var _units: UnitLayer = $World/Units
@onready var _shots: ShotLayer = $World/Shots
@onready var _camera: RtsCamera = $Camera
@onready var _input: PlayerInput = $UI/PlayerInput


func _ready() -> void:
	var db := CatalogDB.load_all()
	_arena = BalanceArena.new(db)
	for id: StringName in db.index.prototype_units:
		_types.append(id)
	if not _types.has(&"gdl_samogitian"):
		_types.append(&"gdl_samogitian")
	sim = _arena.setup(battle_seed, type_a, count_a, type_b, count_b, forest)
	_map.build(sim.nav)
	_clock.sim = sim
	_units.local_player = 1
	_units.attach(sim, _clock)
	_shots.attach(sim, _clock, _units)
	_camera.bounds = Iso.map_rect(sim.nav.width, sim.nav.height)
	_camera.look_at_point(Iso.cell_to_screen(Vector2(sim.nav.width / 2.0, sim.nav.height / 2.0)))
	_input.attach(sim, _units, _camera)
	_clock.ticked.connect(_on_ticked)
	_build_panel()
	_on_ticked(sim.tick)


func _build_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	$UI.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_pick_a = _type_picker(box, tr("Left (you)"), type_a)
	_count_a = _counter(box, count_a)
	_pick_b = _type_picker(box, tr("Right"), type_b)
	_count_b = _counter(box, count_b)
	_forest = CheckBox.new()
	_forest.text = tr("Forest")
	_forest.button_pressed = forest
	box.add_child(_forest)
	var row := HBoxContainer.new()
	box.add_child(row)
	_button(row, tr("Fight!"), _fight)
	_button(row, tr("Reset"), _reset)
	_button(row, tr("Equal money"), _equal_money)
	_result = Label.new()
	box.add_child(_result)


func _type_picker(box: VBoxContainer, title: String, selected: StringName) -> OptionButton:
	var label := Label.new()
	label.text = title
	box.add_child(label)
	var pick := OptionButton.new()
	for id in _types:
		pick.add_item(String(id))
	pick.select(maxi(_types.find(selected), 0))
	box.add_child(pick)
	return pick


func _counter(box: VBoxContainer, value: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = 60
	spin.value = value
	box.add_child(spin)
	return spin


func _button(row: HBoxContainer, title: String, action: Callable) -> void:
	var b := Button.new()
	b.text = title
	b.pressed.connect(action)
	row.add_child(b)


func _fight() -> void:
	BalanceArena.charge(sim)


func _reset() -> void:
	type_a = _types[_pick_a.selected]
	type_b = _types[_pick_b.selected]
	count_a = int(_count_a.value)
	count_b = int(_count_b.value)
	forest = _forest.button_pressed
	battle_seed += 1
	get_tree().reload_current_scene()


func _equal_money() -> void:
	_count_a.value = _arena.army_size(_types[_pick_a.selected])
	_count_b.value = _arena.army_size(_types[_pick_b.selected])
	_reset()


func _on_ticked(_tick: int) -> void:
	_input.sim_ticked_cleanup()
	var lines := PackedStringArray()
	for player: int in [1, 2]:
		var ids := BalanceArena.units_of(sim, player)
		var hp := 0
		var fleeing := 0
		for id in ids:
			hp += maxi(sim.entities.hp[id - 1], 0)
			if sim.combat.is_fleeing(id):
				fleeing += 1
		lines.append(tr("Side %d: %d units, %d HP, %d fleeing") % [player, ids.size(), hp, fleeing])
	lines.append(tr("Time: %d s") % (sim.tick / Fixed.TICKS_PER_SECOND))
	if _result != null:
		_result.text = "\n".join(lines)
