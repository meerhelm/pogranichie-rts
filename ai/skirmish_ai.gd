# gdlint:ignore = max-public-methods
class_name SkirmishAi
extends Node
## A computer player for the skirmish (M8): an Order or GDL side that runs its economy by a build
## order, gathers an army, attacks in waves, defends its base and pulls a beaten wave back.
##
## It plays like a person at the keyboard: it looks at the world only through AiView (its own
## fog of war) and changes it only with the same SimCommands a player gives, so a game against it
## records and replays like any other. Its decisions are a LimboAI behaviour tree (SkirmishTree)
## ticked once every AiProfile.think_ticks; the tree's steps call the methods below, which hand
## the work to AiEconomy and AiMilitary. Its only randomness is its own SimRng, never the
## simulation's, and it walks ids in ascending order, so the same game plays out the same.

var sim: Simulation
var player: int
var profile: AiProfile
var view: AiView
var rng: SimRng
var economy_ai: AiEconomy
var military_ai: AiMilitary
## Where its commands go instead of straight into the world (a network game: Lockstep.submit).
var sink := Callable()
## Thinks so far.
var thinks := 0
## With `timing` on, step_usec sums the microseconds each tree step took (for profiling).
var timing := false
var step_usec: Dictionary[StringName, int] = {}

## Filled at the start of every think: own peasants, fighting units, spiritual units (casters)
## and own buildings by base id (BuildingDef.base_id; for a faction's own building its id
## without the faction prefix, as in AiProfile.build_order).
var peasants := PackedInt32Array()
var army := PackedInt32Array()
var casters := PackedInt32Array()
var buildings_by_base: Dictionary[StringName, PackedInt32Array] = {}

var _tree: BTInstance


## Plays `p_player` of the simulation with the profile; `ai_seed` drives its own choices.
func setup(p_sim: Simulation, p_player: int, p_profile: AiProfile, ai_seed: int = 1) -> void:
	sim = p_sim
	player = p_player
	profile = p_profile
	view = AiView.new(sim, player)
	rng = SimRng.new(mix_seed(ai_seed, player))
	economy_ai = AiEconomy.new(self)
	military_ai = AiMilitary.new(self)
	name = "SkirmishAi%d" % player
	_tree = SkirmishTree.build().instantiate(self, Blackboard.new(), self, self)


## Call before every simulation step (Replay.record's `orders`, or SimClock.ticked): thinks when
## its turn comes. The commands it gives run at the coming step.
func issue(_p_sim: Simulation = null) -> void:
	if sim == null or (sim.tick + player) % maxi(profile.think_ticks, 1) != 0:
		return
	if not sim.economy.players.has(player) or sim.victory.is_out(player) or sim.victory.is_over():
		return
	think()


func think() -> void:
	thinks += 1
	var t0 := Time.get_ticks_usec() if timing else 0
	view.refresh()
	_sort_own()
	economy_ai.begin_think()
	if timing:
		step_usec[&"look"] = step_usec.get(&"look", 0) + Time.get_ticks_usec() - t0
	_tree.update(0.0)


## Spreads small, close seeds over 32 bits (xorshift's first outputs from nearby small seeds
## are alike), so seeds 1, 2, 3... give different games.
static func mix_seed(a: int, b: int) -> int:
	var x := (a * 0x9E3779B1 + b * 0x85EBCA77 + 0x165667B1) & SimRng.MASK
	x ^= x >> 15
	x = (x * 0x2C1B3C6D) & SimRng.MASK
	x ^= x >> 12
	return x


# --- what the behaviour tree calls (SkirmishTree) -------------------------------------------


func train_peasants() -> bool:
	return economy_ai.train_peasants()


func assign_workers() -> bool:
	return economy_ai.assign_workers()


func explore() -> bool:
	return economy_ai.explore()


func finish_foundations() -> bool:
	return economy_ai.finish_foundations()


func build_houses() -> bool:
	return economy_ai.build_houses()


func follow_build_order() -> bool:
	return economy_ai.follow_build_order()


func build_mines() -> bool:
	return economy_ai.build_mines()


func build_producers() -> bool:
	return economy_ai.build_producers()


func build_fields() -> bool:
	return economy_ai.build_fields()


func take_places() -> bool:
	return economy_ai.take_places()


func train_army() -> bool:
	return economy_ai.train_army()


func base_threatened() -> bool:
	return military_ai.base_threatened()


func defend_base() -> bool:
	return military_ai.defend_base()


func wave_weak() -> bool:
	return military_ai.wave_weak()


func retreat_wave() -> bool:
	return military_ai.retreat_wave()


func wave_ready() -> bool:
	return military_ai.wave_ready()


func launch_wave() -> bool:
	return military_ai.launch_wave()


func wave_out() -> bool:
	return military_ai.wave_out()


func press_attack() -> bool:
	return military_ai.press_attack()


func gather_army() -> bool:
	return military_ai.gather_army()


func cast_spells() -> bool:
	return military_ai.cast_spells()


# --- helpers for AiEconomy and AiMilitary ---------------------------------------------------


func state() -> PlayerState:
	return sim.economy.players.get(player)


func order(cmd: SimCommand) -> void:
	if sink.is_valid():
		sink.call(cmd)
	else:
		sim.enqueue(cmd)


func unit_def(id: int) -> UnitDef:
	return sim.economy.unit_defs[id - 1]


## The faction's own id of a building or unit: "barracks" -> "to_barracks".
func own_id(base: StringName) -> StringName:
	if base == &"peasant":
		return SkirmishSetup.peasant_of(sim.economy.db, profile.faction)
	return StringName("%s_%s" % [profile.faction, base])


func buildings_of(base: StringName) -> PackedInt32Array:
	return buildings_by_base.get(base, PackedInt32Array())


## The first standing town centre, 0 when there is none.
func town_center() -> int:
	var store := sim.economy.buildings
	for b in buildings_of(EconomySystem.TOWN_CENTER):
		if store.done[b - 1] == 1:
			return b
	return 0


## The heart of the base in cells: the town centre's middle, or the first own building's, or the
## middle of the own units.
func base_cell() -> Vector2i:
	var store := sim.economy.buildings
	var b := town_center()
	if b == 0:
		var mine := view.my_buildings()
		b = mine[0] if not mine.is_empty() else 0
	if b != 0:
		return Vector2i(
			store.cell_x[b - 1] + store.w[b - 1] / 2, store.cell_y[b - 1] + store.h[b - 1] / 2
		)
	return center_of(view.my_units())


## Middle of the units, in cells (the map's middle for none).
func center_of(ids: PackedInt32Array) -> Vector2i:
	if ids.is_empty():
		return Vector2i(sim.nav.width / 2, sim.nav.height / 2)
	var sx := 0
	var sy := 0
	for id in ids:
		sx += sim.entities.pos_x[id - 1]
		sy += sim.entities.pos_y[id - 1]
	return Vector2i(
		Fixed.to_cells(Fixed.floor_div(sx, ids.size())),
		Fixed.to_cells(Fixed.floor_div(sy, ids.size()))
	)


func unit_cell(id: int) -> Vector2i:
	var e := sim.entities
	return Vector2i(Fixed.to_cells(e.pos_x[id - 1]), Fixed.to_cells(e.pos_y[id - 1]))


static func point(cell: Vector2i) -> Vector2i:
	return Vector2i(Fixed.from_cells(cell.x) + Fixed.HALF, Fixed.from_cells(cell.y) + Fixed.HALF)


## How much a group can fight: the sum of HP times damage per strike.
func strength(ids: PackedInt32Array) -> int:
	var total := 0
	var e := sim.entities
	for id in ids:
		var def := unit_def(id)
		if def != null and e.hp[id - 1] > 0:
			total += e.hp[id - 1] * maxi(def.damage, 1)
	return total


## The fighters among `ids`: no peasants or other civilians.
func fighters(ids: PackedInt32Array) -> PackedInt32Array:
	var result := PackedInt32Array()
	for id in ids:
		var def := unit_def(id)
		if def != null and not def.has_class(&"peasant") and not def.has_class(&"civilian"):
			result.append(id)
	return result


## Units of `ids` within `cells` of the cell.
func near(ids: PackedInt32Array, at: Vector2i, cells: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	var r := Fixed.from_cells(cells)
	var px := Fixed.from_cells(at.x) + Fixed.HALF
	var py := Fixed.from_cells(at.y) + Fixed.HALF
	var e := sim.entities
	for id in ids:
		var dx := e.pos_x[id - 1] - px
		var dy := e.pos_y[id - 1] - py
		if dx * dx + dy * dy <= r * r:
			result.append(id)
	return result


func _sort_own() -> void:
	peasants = PackedInt32Array()
	army = PackedInt32Array()
	casters = PackedInt32Array()
	buildings_by_base.clear()
	for id in view.my_units():
		var def := unit_def(id)
		if def == null:
			continue
		if def.has_class(&"peasant"):
			if not def.tags.has(&"no_gather"):
				peasants.append(id)
		elif def.has_class(&"spiritual"):
			casters.append(id)
		elif def.damage > 0 and not def.has_class(&"civilian"):
			army.append(id)
	var store := sim.economy.buildings
	for b in view.my_buildings():
		var def := store.defs[b - 1]
		var key := def.base_id
		if key.is_empty():
			key = StringName(String(def.id).trim_prefix("%s_" % def.faction))
		var list: PackedInt32Array = buildings_by_base.get(key, PackedInt32Array())
		list.append(b)
		buildings_by_base[key] = list
