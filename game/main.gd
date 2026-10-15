extends Node2D
## Entry scene (M3): the skirmish map with a few GDL and Order units to command.
## Left click or drag selects, right click moves; Q / E / R pick line, column or wedge.

const MAP_ID := "map_proto_samogitia"
const SEED := 1
const PLAYER := 1
## Starting units for the M3 test build: (type, count) for each side.
const GDL_ARMY := [
	[&"gdl_spearman", 10],
	[&"gdl_forest_archer", 6],
	[&"gdl_light_horse", 4],
	[&"gdl_lit_lance", 3],
	[&"gdl_znakharka", 2],
	[&"gdl_peasant", 4],
	[&"gdl_wagon", 1],
]
const ORDER_ARMY := [
	[&"to_knight_brother", 4],
	[&"to_halfbrother", 4],
	[&"to_knecht", 8],
	[&"to_crossbow", 6],
	[&"to_peasant", 4],
]

var sim: Simulation

@onready var _clock: SimClock = $SimClock
@onready var _map: MapView = $World/Map
@onready var _units: UnitLayer = $World/Units
@onready var _camera: RtsCamera = $Camera
@onready var _input: PlayerInput = $UI/PlayerInput
@onready var _status: Label = $UI/Status


func _ready() -> void:
	var game_name: String = ProjectSettings.get_setting("application/config/name")
	var version: String = ProjectSettings.get_setting("application/config/version")
	var label: Label = $UI/VersionLabel
	label.text = "%s %s" % [game_name, version]
	print("Main scene ready: ", label.text)

	var db := CatalogDB.load_prototype()
	var grid := MapText.load_map(MAP_ID, db)
	sim = Simulation.new(SEED, db, 0, 0, grid)
	_spawn_army(PLAYER, GDL_ARMY, Vector2i(14, 14))
	_spawn_army(2, ORDER_ARMY, Vector2i(104, 104))
	_map.build(grid)
	_clock.sim = sim
	_units.attach(sim, _clock)
	_camera.bounds = Iso.map_rect(grid.width, grid.height)
	_camera.look_at_point(Iso.cell_to_screen(Vector2(14, 14)))
	_input.attach(sim, _units, _camera)
	_input.formation_changed.connect(func(_k: Formation.Kind) -> void: _update_status())
	_input.selection.changed.connect(_update_status)
	_clock.ticked.connect(func(_t: int) -> void: _input.sim_ticked_cleanup())
	_update_status()


## Spawn commands for an army in rows around a cell, the way a mission script would.
func _spawn_army(player: int, army: Array, at: Vector2i) -> void:
	var i := 0
	for entry: Array in army:
		var type: StringName = entry[0]
		var count: int = entry[1]
		for n in count:
			var x := Fixed.from_cells(at.x + i % 8 - 4) + Fixed.HALF
			var y := Fixed.from_cells(at.y + i / 8 * 2 - 3) + Fixed.HALF
			sim.enqueue(SimCommand.spawn(0, player, type, x, y))
			i += 1


func _update_status() -> void:
	var names := [tr("Line"), tr("Column"), tr("Wedge")]
	_status.text = (
		tr("Formation: %s (Q/E/R) · Selected: %d")
		% [names[_input.formation], _input.selection.ids.size()]
	)
