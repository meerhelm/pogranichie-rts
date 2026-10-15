class_name MagicTest
extends EconomyTest
## Base for the M7 tests: a grass map with one place of power, the casters and spells by id.

const ZNAKHARKA := &"gdl_znakharka"
const PRIEST := &"to_priest"
const ARCHER := &"gdl_forest_archer"
const ALKA := &"gdl_shrine"
const CHAPEL := &"to_shrine"
const MIST := &"sp_bog_mist"
const EXORCISM := &"sp_exorcism"
const RELIC := &"sp_relic"
## Site of the test place of power: cells (10, 10)–(11, 11), centre (11, 11).
const SITE := Vector2i(10, 10)


## A grass map with one place of power of the kind, both sides joined.
func _world(kind: StringName = &"pp_spring", w: int = 40, h: int = 30) -> Simulation:
	var sim := _open(w, h)
	sim.magic.places.add(_db.power_places[kind], sim.nav.cell_at(SITE.x, SITE.y))
	_join(sim, 1, GDL)
	_join(sim, 2, ORDER)
	return sim


func _power(sim: Simulation, player: int) -> int:
	return sim.economy.player(player).power


func _give_power(sim: Simulation, player: int, points: int) -> void:
	sim.economy.player(player).power = points * MagicSystem.POWER_UNIT
