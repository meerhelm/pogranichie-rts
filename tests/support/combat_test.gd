class_name CombatTest
extends GutTest
## Helpers for the M4 combat tests: small open or text maps, spawning at cell coordinates,
## stepping until a unit is hurt.

const SPEARMAN := &"gdl_spearman"
const KNIGHT := &"to_knight_brother"
const KNECHT := &"to_knecht"
const CROSSBOW := &"to_crossbow"
const LIGHT_HORSE := &"gdl_light_horse"
const HALFBROTHER := &"to_halfbrother"
const LANCE := &"gdl_lit_lance"
const PEASANT := &"gdl_peasant"

var _db: CatalogDB
var _rules: CombatRulesDef


func before_all() -> void:
	_db = CatalogDB.load_all()
	_rules = _db.rules


func _at(cells: float) -> int:
	return int(cells * Fixed.ONE)


func _open(w: int = 40, h: int = 20) -> Simulation:
	return Simulation.new(1, _db, w, h)


func _on_map(text: String) -> Simulation:
	return Simulation.new(1, _db, 0, 0, MapText.parse(text, _db))


## Spawns a unit at cell coordinates (fractions allowed) and returns its id.
func _spawn(sim: Simulation, player: int, type_id: StringName, x: float, y: float) -> int:
	var id := sim.entities.next_id
	sim.enqueue(SimCommand.spawn(sim.tick, player, type_id, _at(x), _at(y)))
	sim.step()
	return id


func _ids(id: int) -> PackedInt32Array:
	return PackedInt32Array([id])


func _face(sim: Simulation, id: int, fx: int, fy: int) -> void:
	sim.entities.facing_x[id - 1] = fx
	sim.entities.facing_y[id - 1] = fy


func _passive(sim: Simulation, id: int) -> void:
	sim.enqueue(SimCommand.set_stance(sim.tick, sim.entities.owners[id - 1], _ids(id), 3))
	sim.step()


## Steps until the unit's HP changes (at most `limit` ticks) and returns the HP lost.
func _first_damage(sim: Simulation, id: int, limit: int = 600) -> int:
	var before := sim.entities.hp[id - 1]
	for i in limit:
		sim.step()
		if sim.entities.hp[id - 1] != before:
			return before - sim.entities.hp[id - 1]
	return 0


func _morale(sim: Simulation, id: int) -> int:
	return sim.entities.morale[id - 1] / CombatSystem.MORALE_SCALE
