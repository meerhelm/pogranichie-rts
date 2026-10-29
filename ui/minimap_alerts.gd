class_name MinimapAlerts
extends RefCounted
## What the minimap blinks about: the local player's units or buildings under attack, and its
## buildings just finished. Only reads the simulation (hp, done, owners) a few times a second and
## compares with what it saw last time, so the simulation itself knows nothing about alerts.
##
## A hit counts as an attack only with an enemy unit or building near the one hurt, so the slow
## sickness of a besieged garrison or a hero's own magic does not raise alarms. One fight blinks
## once per COOLDOWN_TICKS: further hits within RADIUS cells of the last alert stay quiet.

enum Kind { ATTACK, BUILT }

## Game ticks one area keeps quiet after an attack alert (15 s at 20 ticks a second).
const COOLDOWN_TICKS := 300
## Cells around an alert where other hits count as the same fight.
const RADIUS := 16
## Cells around a hurt unit or building looked at for an enemy.
const ENEMY_NEAR := 14

var sim: Simulation
var player := 1

## Own unit ids seen last time, with their hp by slot.
var _units := PackedInt32Array()
var _unit_hp := PackedInt32Array()
## Own building id -> hp seen last time; unfinished own buildings.
var _building_hp: Dictionary[int, int] = {}
var _unfinished: Dictionary[int, bool] = {}
## Recent attack alerts: [tick, cell x, cell y].
var _recent: Array[Vector3i] = []


func _init(p_sim: Simulation, p_player: int) -> void:
	sim = p_sim
	player = p_player
	_snapshot()


## Alerts since the last call, each {kind: Kind, cell: Vector2 (map cells)}.
func poll(tick: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var hurt: Array[Vector2] = []
	_poll_units(hurt)
	_poll_buildings(hurt, out)
	_recent = _recent.filter(func(r: Vector3i) -> bool: return tick - r.x < COOLDOWN_TICKS)
	for at in hurt:
		if _quiet_near(at) or not _enemy_near(at):
			continue
		_recent.append(Vector3i(tick, int(at.x), int(at.y)))
		out.append({"kind": Kind.ATTACK, "cell": at})
	return out


func _snapshot() -> void:
	var e := sim.entities
	_unit_hp.resize(e.next_id)
	_units = PackedInt32Array()
	for id in e.alive_ids:
		if e.owners[id - 1] == player:
			_units.append(id)
			_unit_hp[id - 1] = e.hp[id - 1]
	var b := sim.economy.buildings
	_building_hp.clear()
	_unfinished.clear()
	for id in b.alive_ids:
		if b.owners[id - 1] == player:
			_building_hp[id] = b.hp[id - 1]
			if not b.is_done(id):
				_unfinished[id] = true


func _poll_units(hurt: Array[Vector2]) -> void:
	var e := sim.entities
	if _unit_hp.size() < e.next_id:
		_unit_hp.resize(e.next_id)
	for id in _units:
		var s := id - 1
		var lost := e.hp[s] < _unit_hp[s]
		var killed := not e.is_alive(id) and e.hp[s] <= 0
		if (lost and e.owners[s] == player) or killed:
			hurt.append(_unit_cell(s))
	_units = PackedInt32Array()
	for id in e.alive_ids:
		if e.owners[id - 1] == player:
			_units.append(id)
			_unit_hp[id - 1] = e.hp[id - 1]


func _poll_buildings(hurt: Array[Vector2], out: Array[Dictionary]) -> void:
	var b := sim.economy.buildings
	var seen: Dictionary[int, int] = {}
	for id in b.alive_ids:
		var s := id - 1
		if b.owners[s] != player:
			continue
		seen[id] = b.hp[s]
		var before: int = _building_hp.get(id, -1)
		var dismantled := b.dismantling[s] == 1 if s < b.dismantling.size() else false
		if before > b.hp[s] and not dismantled:
			hurt.append(_building_cell(s))
		if not b.is_done(id):
			_unfinished[id] = true
		elif _unfinished.has(id):
			_unfinished.erase(id)
			out.append({"kind": Kind.BUILT, "cell": _building_cell(s)})
	# A building destroyed between two looks: its hp went to nothing.
	for id: int in _building_hp:
		if not seen.has(id) and b.hp[id - 1] <= 0 and b.owners[id - 1] == player:
			hurt.append(_building_cell(id - 1))
	for id: int in _unfinished.keys():
		if not seen.has(id):
			_unfinished.erase(id)
	_building_hp = seen


func _unit_cell(s: int) -> Vector2:
	var e := sim.entities
	return Vector2(float(e.pos_x[s]) / Fixed.ONE, float(e.pos_y[s]) / Fixed.ONE)


func _building_cell(s: int) -> Vector2:
	var b := sim.economy.buildings
	return Vector2(b.cell_x[s] + b.w[s] / 2.0, b.cell_y[s] + b.h[s] / 2.0)


func _quiet_near(at: Vector2) -> bool:
	for r in _recent:
		if Vector2(r.y, r.z).distance_squared_to(at) <= RADIUS * RADIUS:
			return true
	return false


## True if a unit or building of an enemy of the player is within ENEMY_NEAR cells.
func _enemy_near(at: Vector2) -> bool:
	var sides := sim.sides
	var e := sim.entities
	var r2 := ENEMY_NEAR * ENEMY_NEAR
	for id in e.alive_ids:
		if (
			sides.hostile(player, e.owners[id - 1])
			and _unit_cell(id - 1).distance_squared_to(at) <= r2
		):
			return true
	var b := sim.economy.buildings
	for id in b.alive_ids:
		if (
			sides.hostile(player, b.owners[id - 1])
			and _building_cell(id - 1).distance_squared_to(at) <= r2
		):
			return true
	return false
