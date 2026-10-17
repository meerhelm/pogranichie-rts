class_name TowerFire
extends RefCounted
## Towers and gates shoot: every finished building with damage and a range in the catalog
## (tower «5 С, дальн. 7, стрела раз в 0,6 с», gate «5 С, дальн. 6, стрела раз в 1,3 с»)
## sends an arrow every params.reload_ticks at the nearest enemy unit its side can see within
## range of its walls. Arrows fly and land like the archers' (CombatSystem.tower_shot) with
## no class bonus; the shooter is minus the building id.
## A gateway two or more cells wide is one gate: only its lowest-id cell shoots.
## Run by Simulation after CombatSystem.step (its unit buckets are fresh then).

## Ticks between arrows when the data gives none.
const DEFAULT_RELOAD := 40

var buildings: BuildingStore
var entities: EntityStore
var combat: CombatSystem
## Fog of war: a tower only shoots at what its side sees (null: sees everything).
var vision: VisionSystem


func _init(p_buildings: BuildingStore, p_entities: EntityStore, p_combat: CombatSystem) -> void:
	buildings = p_buildings
	entities = p_entities
	combat = p_combat


static func shoots(def: BuildingDef) -> bool:
	return def.damage > 0 and def.attack_range > 0


func step() -> void:
	if not combat.enabled():
		return
	for b in buildings.alive_ids:
		var s := b - 1
		if buildings.done[s] == 0 or not shoots(buildings.defs[s]):
			continue
		if buildings.cooldown[s] > 0:
			buildings.cooldown[s] -= 1
			continue
		if _gate_wing(b):
			continue
		var t := _nearest_enemy(b)
		if t == EntityStore.NO_ID:
			continue
		var def := buildings.defs[s]
		buildings.cooldown[s] = maxi(def.param(&"reload_ticks", DEFAULT_RELOAD), 1)
		_shoot(b, t - 1)


## True for a gate cell next to an own gate cell with a lower id: the same gateway, whose
## archers stand on that one.
func _gate_wing(b: int) -> bool:
	var s := b - 1
	if not buildings.defs[s].tags.has(&"gate"):
		return false
	for o in buildings.alive_ids:
		if o >= b:
			continue
		var q := o - 1
		if buildings.owners[q] != buildings.owners[s] or not buildings.defs[q].tags.has(&"gate"):
			continue
		if (
			(
				absi(buildings.cell_x[q] - buildings.cell_x[s])
				+ absi(buildings.cell_y[q] - buildings.cell_y[s])
			)
			== 1
		):
			return true
	return false


func _shoot(b: int, t: int) -> void:
	var s := b - 1
	var def := buildings.defs[s]
	var sx := buildings.center_x(b)
	var sy := buildings.center_y(b)
	combat.tower_shot(b, buildings.owners[s], sx, sy, t, def.damage, def.damage_type)


## The nearest unit of another side within range of the tower's walls that its side sees;
## ties go to the lower id.
func _nearest_enemy(b: int) -> int:
	var s := b - 1
	var owner := buildings.owners[s]
	var reach := Fixed.from_cells(buildings.defs[s].attack_range)
	var cx := buildings.center_x(b)
	var cy := buildings.center_y(b)
	# The buckets search a circle round the centre: wide enough for the corners too.
	var radius := reach + Fixed.from_cells(maxi(buildings.w[s], buildings.h[s]))
	var e := entities
	var best := EntityStore.NO_ID
	var best_d := 0
	for id in combat.buckets.near(cx, cy, radius):
		var o := id - 1
		if not combat.sides.hostile(e.owners[o], owner) or e.hp[o] <= 0 or combat.defs[o] == null:
			continue
		if combat.untouchable.has(id) or combat.defs[o].tags.has(&"not_targeted"):
			continue
		if combat.defs[o].tags.has(&"witness_meter"):
			continue
		if combat.is_hidden(id) or (vision != null and not vision.sees_unit(owner, id)):
			continue
		var d := buildings.distance_sq(b, e.pos_x[o], e.pos_y[o])
		if d > reach * reach:
			continue
		if best == EntityStore.NO_ID or d < best_d or (d == best_d and id < best):
			best = id
			best_d = d
	return best
