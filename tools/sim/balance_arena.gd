class_name BalanceArena
extends RefCounted
## Balance arena (plan, section 5): two armies of the same money fight on an open or forest field,
## many seeds per pair, and the result is a CSV row "pair → win share, HP left".
## Armies are worth CombatRulesDef.arena_budget, with iron and silver weighted as in the
## catalog's «Сверка статов». Both sides attack-move at each other; a simple commander sends
## idle units back into the fight, so a battle ends with one side gone (or a draw at MAX_TICKS).
## Used headless by `sim_cli.gd -- arena` and, for one battle at a time, by the debug arena scene.

## Field size in cells and the gap between the armies.
const WIDTH := 48
const HEIGHT := 32
const GAP := 14
## A battle that takes longer than this (3 minutes) is a draw.
const MAX_TICKS := 3600
## The commander re-sends idle units every this many ticks.
const COMMAND_EVERY := 40
## Units stand in rows this wide, a cell apart.
const ROW := 8
## Starting positions shift by up to this much per seed (fixed units), so seeds differ.
const JITTER := 300
const CSV_HEADER := (
	"pair,a,b,terrain,script,seeds,a_count,b_count,a_wins,b_wins,draws,"
	+ "a_win_share_permille,a_hp_left_permille,b_hp_left_permille,avg_ticks"
)

## The checks the catalog asks for first (plan, «Проверки баланса из каталога»):
## [id, unit A (player 1), unit B (player 2), forest, Lithuanian retreat micro for A].
const DEFAULT_PAIRS := [
	["crossbow_vs_spear", &"to_crossbow", &"gdl_spearman", false, false],
	["spear_vs_halfbrother", &"gdl_spearman", &"to_halfbrother", false, false],
	["spear_vs_knight", &"gdl_spearman", &"to_knight_brother", false, false],
	["knecht_vs_lit_lance", &"to_knecht", &"gdl_lit_lance", false, false],
	["samogitian_vs_knecht", &"gdl_samogitian", &"to_knecht", false, false],
	["samogitian_vs_knecht_forest", &"gdl_samogitian", &"to_knecht", true, false],
	["light_horse_retreat_vs_halfbrother", &"gdl_light_horse", &"to_halfbrother", false, true],
	["light_horse_frontal_vs_halfbrother", &"gdl_light_horse", &"to_halfbrother", false, false],
]


## Outcome of one battle.
class Outcome:
	extends RefCounted
	## 1 or 2, 0 for a draw.
	var winner := 0
	var ticks := 0
	## HP left over max HP of each army at the start, per-mille.
	var hp_left := PackedInt32Array([0, 0, 0])
	var counts := PackedInt32Array([0, 0, 0])


var db: CatalogDB


func _init(p_db: CatalogDB) -> void:
	db = p_db


## Units of this type the arena budget buys (at least one).
func army_size(type_id: StringName) -> int:
	var def := db.unit(type_id)
	var r := db.rules
	var cost := (
		def.cost_food
		+ def.cost_wood
		+ def.cost_iron * r.arena_iron_permille / 1000
		+ def.cost_silver * r.arena_silver_permille / 1000
	)
	return maxi(1, r.arena_budget / maxi(cost, 1))


## Open grass, or with `forest` the whole fighting ground is forest.
func make_map(forest: bool) -> NavGrid:
	var rows := PackedStringArray()
	for y in HEIGHT:
		var row := ""
		for x in WIDTH:
			var inner := x >= 6 and x < WIDTH - 6 and y >= 4 and y < HEIGHT - 4
			row += "f" if forest and inner else "."
		rows.append(row)
	return MapText.parse("\n".join(rows), db)


## A new battle: player 1 with `count_a` of `a` on the left, player 2 on the right, facing.
func setup(
	battle_seed: int, a: StringName, count_a: int, b: StringName, count_b: int, forest: bool
) -> Simulation:
	var sim := Simulation.new(battle_seed, db, 0, 0, make_map(forest))
	var jitter := SimRng.new(battle_seed * 7919 + 1)
	var cy := HEIGHT / 2
	var left := (WIDTH - GAP) / 2
	place(sim, 1, a, count_a, left, cy, -1, jitter)
	place(sim, 2, b, count_b, left + GAP, cy, 1, jitter)
	sim.step()
	return sim


## Rows of ROW units a cell apart around (cx, cy), the rows growing away from the enemy (side
## -1 grows left, 1 right).
static func place(
	sim: Simulation,
	player: int,
	type_id: StringName,
	count: int,
	cx: int,
	cy: int,
	side: int,
	jitter: SimRng
) -> void:
	for i in count:
		var col := i / ROW
		var row := i % ROW - ROW / 2
		var x := Fixed.from_cells(cx + side * col) + Fixed.HALF + jitter.range_int(-JITTER, JITTER)
		var y := Fixed.from_cells(cy + row) + Fixed.HALF + jitter.range_int(-JITTER, JITTER)
		sim.enqueue(SimCommand.spawn(sim.tick, player, type_id, x, y))


## Both armies attack-move at each other.
static func charge(sim: Simulation) -> void:
	for player: int in [1, 2]:
		var mine := units_of(sim, player)
		var enemy := centroid(sim, units_of(sim, 3 - player))
		if not mine.is_empty() and enemy.x >= 0:
			sim.enqueue(SimCommand.attack_move(sim.tick, player, mine, enemy.x, enemy.y))


## Plays one battle to the end. `micro_a` runs the Lithuanian retreat script for player 1.
func battle(battle_seed: int, a: StringName, b: StringName, forest: bool, micro_a: bool) -> Outcome:
	var out := Outcome.new()
	var sim := setup(battle_seed, a, army_size(a), b, army_size(b), forest)
	var start_hp := PackedInt32Array([0, _hp_of(sim, 1), _hp_of(sim, 2)])
	out.counts = PackedInt32Array([0, units_of(sim, 1).size(), units_of(sim, 2).size()])
	charge(sim)
	while sim.tick < MAX_TICKS:
		if sim.tick % COMMAND_EVERY == 0:
			command_idle(sim)
		if micro_a:
			retreat_micro(sim, 1)
		sim.step()
		var alive_a := units_of(sim, 1).size()
		var alive_b := units_of(sim, 2).size()
		if alive_a == 0 or alive_b == 0:
			out.winner = 0 if alive_a == alive_b else (1 if alive_a > 0 else 2)
			break
	out.ticks = sim.tick
	for p: int in [1, 2]:
		out.hp_left[p] = _hp_of(sim, p) * 1000 / maxi(start_hp[p], 1)
	return out


## Idle units without a target go back at the enemy.
static func command_idle(sim: Simulation) -> void:
	var e := sim.entities
	for player: int in [1, 2]:
		var idle := PackedInt32Array()
		for id in units_of(sim, player):
			var slot := id - 1
			if (
				e.orders[slot] == EntityStore.Order.IDLE
				and e.target[slot] == EntityStore.NO_ID
				and e.intents[slot] == EntityStore.Intent.NONE
			):
				idle.append(id)
		var enemy := centroid(sim, units_of(sim, 3 - player))
		if not idle.is_empty() and enemy.x >= 0:
			sim.enqueue(SimCommand.attack_move(sim.tick, player, idle, enemy.x, enemy.y))


## Lithuanian micro: units in melee with the retreat ready ride off; once the retreat is over
## and «Разворот» is still allowed, they turn on the enemy.
static func retreat_micro(sim: Simulation, player: int) -> void:
	var e := sim.entities
	var go := PackedInt32Array()
	var turn := PackedInt32Array()
	var close := Fixed.from_cells(2)
	for id in units_of(sim, player):
		var slot := id - 1
		if not sim.combat.flags[slot] & CombatSystem.F_RETREAT:
			continue
		if e.intents[slot] == EntityStore.Intent.NONE:
			if e.turn_ticks[slot] > 0 and e.turn_bonus[slot] == 0:
				turn.append(id)
				continue
			var t := e.target[slot]
			if t != EntityStore.NO_ID and e.retreat_cd[slot] == 0:
				var d := Fixed.distance(
					e.pos_x[slot], e.pos_y[slot], e.pos_x[t - 1], e.pos_y[t - 1]
				)
				if d <= close:
					go.append(id)
	if not go.is_empty():
		sim.enqueue(SimCommand.order(sim.tick, player, SimCommand.Kind.RETREAT, go))
	if not turn.is_empty():
		sim.enqueue(SimCommand.order(sim.tick, player, SimCommand.Kind.TURN, turn))


## One CSV row for a pair over `seeds` battles (seeds 1..seeds).
func run_pair(pair: Array, seeds: int) -> String:
	var a: StringName = pair[1]
	var b: StringName = pair[2]
	var forest: bool = pair[3]
	var micro: bool = pair[4]
	var wins := PackedInt32Array([0, 0, 0])
	var hp_a := 0
	var hp_b := 0
	var ticks := 0
	for s in range(1, seeds + 1):
		var o := battle(s, a, b, forest, micro)
		wins[o.winner] += 1
		hp_a += o.hp_left[1]
		hp_b += o.hp_left[2]
		ticks += o.ticks
	var cols := [
		pair[0],
		a,
		b,
		"forest" if forest else "open",
		"retreat" if micro else "-",
		seeds,
		army_size(a),
		army_size(b),
		wins[1],
		wins[2],
		wins[0],
		wins[1] * 1000 / seeds,
		hp_a / seeds,
		hp_b / seeds,
		ticks / seeds,
	]
	var parts := PackedStringArray()
	for v: Variant in cols:
		parts.append(str(v))
	return ",".join(parts)


static func units_of(sim: Simulation, player: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	for id in sim.entities.alive_ids:
		if sim.entities.owners[id - 1] == player:
			result.append(id)
	return result


## Average position of the units, or (-1, -1) for none.
static func centroid(sim: Simulation, ids: PackedInt32Array) -> Vector2i:
	if ids.is_empty():
		return Vector2i(-1, -1)
	var sx := 0
	var sy := 0
	for id in ids:
		sx += sim.entities.pos_x[id - 1]
		sy += sim.entities.pos_y[id - 1]
	return Vector2i(Fixed.floor_div(sx, ids.size()), Fixed.floor_div(sy, ids.size()))


static func _hp_of(sim: Simulation, player: int) -> int:
	var sum := 0
	for id in units_of(sim, player):
		sum += maxi(sim.entities.hp[id - 1], 0)
	return sum
