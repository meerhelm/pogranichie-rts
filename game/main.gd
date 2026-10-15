extends Node2D
## Entry scene: the skirmish map with a GDL and an Order army that fight (M4), and from M5
## each side's town centre and peasants to gather, build and train.
## Left click or drag selects, right click moves or attacks, Ctrl+right click attack-moves;
## Q / E / R pick line, column or wedge; Z / X / C set the stance; with peasants, right click
## gathers or builds and B places a building; a selected building queues with Z X C V B N M
## (see PlayerInput).

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
## Each side's faction and the top-left cell of its town centre.
const BASES := [[1, &"gdl", Vector2i(5, 5)], [2, &"to", Vector2i(108, 96)]]
## Peasants at the start next to each town centre.
const START_PEASANTS := 5

var sim: Simulation

@onready var _clock: SimClock = $SimClock
@onready var _map: MapView = $World/Map
@onready var _buildings: BuildingLayer = $World/Buildings
@onready var _units: UnitLayer = $World/Units
@onready var _shots: ShotLayer = $World/Shots
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
	_set_up_bases()
	_spawn_army(PLAYER, GDL_ARMY, Vector2i(14, 14))
	_spawn_army(2, ORDER_ARMY, Vector2i(104, 104))
	_map.build(grid)
	_clock.sim = sim
	_units.local_player = PLAYER
	_units.attach(sim, _clock)
	_shots.attach(sim, _clock, _units)
	_buildings.attach(sim, _clock)
	_camera.bounds = Iso.map_rect(grid.width, grid.height)
	_camera.look_at_point(Iso.cell_to_screen(Vector2(14, 14)))
	_input.attach(sim, _units, _camera, _buildings)
	_input.formation_changed.connect(func(_k: Formation.Kind) -> void: _update_status())
	_input.selection.changed.connect(_update_status)
	_input.economy_changed.connect(_update_status)
	_clock.ticked.connect(_on_ticked)
	_update_status()


func _on_ticked(_tick: int) -> void:
	_input.sim_ticked_cleanup()
	_map.refresh()
	if _tick % 5 == 0:
		_update_status()


## Players join; each gets a finished town centre and peasants beside it (map setup).
func _set_up_bases() -> void:
	for base: Array in BASES:
		var player: int = base[0]
		var faction: StringName = base[1]
		var at: Vector2i = base[2]
		sim.enqueue(SimCommand.join(0, player, faction))
		var center := StringName("%s_town_center" % faction)
		var x := Fixed.from_cells(at.x) + Fixed.HALF
		var y := Fixed.from_cells(at.y) + Fixed.HALF
		sim.enqueue(SimCommand.place(0, player, center, x, y))
		var peasant := StringName("%s_peasant" % faction)
		for i in START_PEASANTS:
			var px := Fixed.from_cells(at.x + i) + Fixed.HALF
			sim.enqueue(SimCommand.spawn(0, player, peasant, px, Fixed.from_cells(at.y + 5)))


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
	var lines := PackedStringArray(
		[
			(
				tr("Formation: %s (Q/E/R) · Selected: %d")
				% [names[_input.formation], _input.selection.ids.size()]
			)
		]
	)
	var eco := sim.economy
	var state := eco.player(PLAYER)
	if state != null:
		var age := sim.economy.db.age_by_index(state.age)
		lines.append(
			(
				tr("Food %d · Wood %d · Iron %d · Silver %d · Population %d/%d · %s")
				% [
					state.stock[0],
					state.stock[1],
					state.stock[2],
					state.stock[3],
					state.pop_used(),
					eco.pop_cap(PLAYER),
					tr(String(age.id)) if age != null else ""
				]
			)
		)
	if _input.placing != null:
		var cost := eco.placement.building_cost(PLAYER, _input.placing)
		lines.append(
			(
				tr("Build %s: %s (B next, F turn, Esc cancel) · %s")
				% [
					tr(String(_input.placing.id)),
					_cost_text(cost),
					(
						tr("OK")
						if _input.place_fail == 0
						else tr(EconomySystem.Fail.keys()[_input.place_fail])
					)
				]
			)
		)
	if _input.selected_building != BuildingStore.NO_ID:
		lines.append(_building_text(_input.selected_building))
	_status.text = "\n".join(lines)


func _building_text(b: int) -> String:
	var eco := sim.economy
	var s := b - 1
	var store := eco.buildings
	var text := "%s %d/%d HP" % [tr(String(store.type_ids[s])), store.hp[s], store.max_hp[s]]
	if store.done[s] == 0:
		return text + " · " + tr("building %d%%") % (store.progress[s] * 100 / store.work[s])
	var q: Array = store.queues[s]
	if not q.is_empty():
		var parts := PackedStringArray()
		for item: StringName in q:
			parts.append(tr(String(item)))
		text += " · " + tr("queue: %s") % ", ".join(parts)
	var keys := "ZXCVBNM"
	var items := _input.queue_items()
	var offers := PackedStringArray()
	for i in mini(items.size(), keys.length()):
		var cost := eco.production.item_cost(PLAYER, b, items[i])
		offers.append("%s: %s (%s)" % [keys[i], tr(String(items[i])), _cost_text(cost)])
	if not offers.is_empty():
		text += "\n" + "   ".join(offers)
	return text


func _cost_text(cost: PackedInt32Array) -> String:
	var parts := PackedStringArray()
	var marks := [tr("F"), tr("W"), tr("I"), tr("S")]
	for r in 4:
		if cost[r] > 0:
			parts.append("%d%s" % [cost[r], marks[r]])
	return " ".join(parts) if not parts.is_empty() else tr("free")
