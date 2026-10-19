class_name Maneuvers
extends RefCounted
## Orders that move a unit in a fight by its own rules (split out of CombatSystem): the
## «Литовский отход» and the «Разворот» after it, getting off the horse and on again, and the
## Crown's wagons drawn up in a tabor ring.

## Directions of a ring, thousandths, 16 round the circle (cos, sin of k * 22.5°).
const RING_DIRS: Array[Vector2i] = [
	Vector2i(1000, 0),
	Vector2i(924, 383),
	Vector2i(707, 707),
	Vector2i(383, 924),
	Vector2i(0, 1000),
	Vector2i(-383, 924),
	Vector2i(-707, 707),
	Vector2i(-924, 383),
	Vector2i(-1000, 0),
	Vector2i(-924, -383),
	Vector2i(-707, -707),
	Vector2i(-383, -924),
	Vector2i(0, -1000),
	Vector2i(383, -924),
	Vector2i(707, -707),
	Vector2i(924, -383),
]


## «Литовский отход»: the group turns and rides retreat_cells toward its rally point, faster and
## without losing morale for a while; «Разворот» may follow within turn_window_ticks.
static func retreat(c: CombatSystem, player: int, ids: PackedInt32Array) -> void:
	var e := c.entities
	var ready := PackedInt32Array()
	var sum_x := 0
	var sum_y := 0
	for id in ids:
		var slot := id - 1
		if c.flags[slot] & CombatSystem.F_RETREAT and e.retreat_cd[slot] == 0:
			ready.append(id)
			sum_x += e.pos_x[slot]
			sum_y += e.pos_y[slot]
	if ready.is_empty():
		return
	var cx := Fixed.floor_div(sum_x, ready.size())
	var cy := Fixed.floor_div(sum_y, ready.size())
	var goal := c._rally_of(player, ready[0] - 1)
	var dx := goal.x - cx
	var dy := goal.y - cy
	var d := Fixed.isqrt(dx * dx + dy * dy)
	if d < Fixed.ONE:
		# Already at the rally point: ride away from where the first unit faces.
		dx = -e.facing_x[ready[0] - 1]
		dy = -e.facing_y[ready[0] - 1]
		d = Fixed.ONE
	var off_x := dx * Fixed.from_cells(c.rules.retreat_cells) / d
	var off_y := dy * Fixed.from_cells(c.rules.retreat_cells) / d
	for id in ready:
		var slot := id - 1
		c._clear_target(slot)
		e.attack_move[slot] = 0
		e.intents[slot] = EntityStore.Intent.RETREAT
		e.intent_ticks[slot] = c.rules.retreat_fearless_ticks
		e.retreat_cd[slot] = c.rules.retreat_cooldown_ticks
		e.turn_ticks[slot] = c.rules.turn_window_ticks
		e.turn_bonus[slot] = 0
		c._walk.call(id, c._clamp_x(e.pos_x[slot] + off_x), c._clamp_y(e.pos_y[slot] + off_y))


## «Разворот»: within the window after a retreat, turn on the enemy (the given one or the
## nearest) with +turn_damage_bonus and a ×turn_charge_permille charge on the next hit. The
## bonus waits up to turn_window_ticks for that hit; one turn per retreat.
static func turn(c: CombatSystem, id: int, enemy: int) -> void:
	var e := c.entities
	var slot := id - 1
	if e.turn_ticks[slot] == 0 or e.turn_bonus[slot] == 1:
		return
	c._end_retreat(slot)
	e.turn_bonus[slot] = 1
	e.turn_ticks[slot] = c.rules.turn_window_ticks
	e.attack_move[slot] = 0
	var owner := e.owners[slot]
	if (
		e.is_alive(enemy)
		and not c.sides.friendly(e.owners[enemy - 1], owner)
		and not c._hidden_from(enemy - 1, owner)
	):
		e.target[slot] = enemy
		e.target_kind[slot] = EntityStore.TargetKind.ORDERED
	else:
		c._acquire(slot, c._sight(slot))
	e.chase_x[slot] = e.pos_x[slot]
	e.chase_y[slot] = e.pos_y[slot]


static func toggle_dismount(c: CombatSystem, id: int) -> void:
	var e := c.entities
	var slot := id - 1
	var def := c.defs[slot]
	if not c.flags[slot] & CombatSystem.F_DISMOUNT:
		return
	var down := e.dismounted[slot] == 0
	e.dismounted[slot] = 1 if down else 0
	c.flags[slot] = CombatFlags.of(def, down)
	var speed_milli := c.rules.dismount_speed_milli if down else def.speed_milli
	e.speed[slot] = Fixed.speed_per_tick(speed_milli)
	e.move_class[slot] = NavGrid.MoveClass.FOOT if down else NavGrid.move_class_for(def)
	c._stop.call(id)


## TABOR: the selected wagons (UnitDef param tabor_wagons) drive out to a ring round where they
## stand together, a cell of radius per four wagons (at least two), evenly spaced. Four keeps
## the widest gap of the 16 directions within tabor_link_cells, so the ring links up.
static func tabor(c: CombatSystem, ids: PackedInt32Array) -> void:
	var e := c.entities
	var wagons := PackedInt32Array()
	var sum_x := 0
	var sum_y := 0
	for id in ids:
		var def := c.defs[id - 1]
		if def != null and def.param(&"tabor_wagons") > 0:
			wagons.append(id)
			sum_x += e.pos_x[id - 1]
			sum_y += e.pos_y[id - 1]
	if wagons.size() < 2:
		return
	wagons.sort()
	var n := wagons.size()
	var cx := Fixed.floor_div(sum_x, n)
	var cy := Fixed.floor_div(sum_y, n)
	var r := Fixed.from_cells(maxi(2, n / 4))
	for i in n:
		var d := RING_DIRS[i * RING_DIRS.size() / n % RING_DIRS.size()]
		var x := c._clamp_x(cx + r * d.x / 1000)
		var y := c._clamp_y(cy + r * d.y / 1000)
		c._clear_target(wagons[i] - 1)
		c._walk.call(wagons[i], x, y)


## «Богородица»: a fleeing unit turns back to fight.
static func rally(c: CombatSystem, id: int) -> void:
	var e := c.entities
	if e.intents[id - 1] == EntityStore.Intent.FLEE:
		e.intents[id - 1] = EntityStore.Intent.NONE
		e.intent_ticks[id - 1] = 0
		c._stop.call(id)
