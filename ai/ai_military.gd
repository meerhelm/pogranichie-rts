class_name AiMilitary
extends RefCounted
## The skirmish AI's army (M8): gathers at a rally point in front of the base, sends waves at
## the enemy it has found (or out to scout for it), presses the attack on buildings, defends
## its base and pulls a beaten wave back home. Steps of the behaviour tree; it orders through
## SimCommands only and knows the enemy only through AiView.

## Enemies within this many cells of the wave count against it.
const WAVE_SIGHT := 12
## The wave assaults its target building when no enemy unit is this close (cells) to it...
const CLEAR_CELLS := 8
## ...and it is this close to the building.
const ASSAULT_CELLS := 14
## The rally point is this far from the base toward the middle of the map.
const RALLY_CELLS := 9
## Home units farther than this from the rally point walk back to it.
const RALLY_SLACK := 6
## Scouting points lie on a grid this many cells apart.
const SCOUT_STEP := 10
## Each AI adds up to this many units to its waves and ticks to its first attack, so games
## with different seeds differ.
const WAVE_JITTER := 6
const ATTACK_JITTER := 2400
## While a wave is out, units at home go out to join it together once there are this many, or
## half a wave if that is more (one at a time they would die on the way).
const REINFORCE := 5
## A wave worn down below this share (per mille) of the most units it had goes home to regroup.
const WORN_PERMILLE := 400
## After this tick (35 game minutes) the AI masses its largest wave (AiProfile.max_wave, or
## all it has at the population limit) and neither turns it back nor calls it home: one big
## push breaks the deadlock that trading small waves at the bases ends in.
const ALL_IN_TICK := 42000
## Only buildings this close (cells) to the base's heart are defended: a shrine out at a place
## of power does not call the wave home.
const HOME_CELLS := 24
## Before it goes at a building the wave forms up this many cells short of it, so it arrives
## together and not strung out along the road; it waits there at most STAGE_TICKS once its
## centre is there.
const STAGE_CELLS := 18
const STAGE_TICKS := 900
## Formed up: this share (per mille) of the wave is within STAGE_SLACK cells of its centre.
const STAGE_PERMILLE := 800
const STAGE_SLACK := 6
## A counter-attack leaves this many ticks after the last attacker was seen at the base, if
## it is still within COUNTER_WINDOW ticks.
const COUNTER_DELAY := 100
const COUNTER_WINDOW := 1200
## After a retreat no wave leaves for this many ticks.
const REGROUP_TICKS := 600
## Defenders are re-sent at the threat at most once in this many thinks.
const DEFEND_EVERY := 3
## A wave this much weaker than the threat to the base comes home (per-mille of the threat).
const RECALL_PERMILLE := 1500
## Other buildings count as this many cells farther than a capital when picking a target.
const CAPITAL_FIRST := 1000
## Buildings farther than this (cells) from the likely enemy start are outposts: the wave
## scouts for the enemy base first and takes them only when there is nowhere left to look.
const OUTPOST_CELLS := 40
const OUTPOST_LAST := 100000
## Buildings not worth a wave's time.
const IGNORED: Array[StringName] = [&"palisade", &"gate", &"wall"]

var ai: SkirmishAi
## Units out on the current wave, and how many waves have left.
var wave := PackedInt32Array()
var waves := 0
## Where the wave is going: an enemy building (0 for none) or a point (cells).
var target_building := 0
var target_cell := Vector2i(-1, -1)
var assaulting := 0

## Its own variation (from SkirmishAi.rng): extra units for the next wave (drawn again at each
## launch) and ticks before the first.
var wave_extra := 0
var attack_delay := 0

var _threat := PackedInt32Array()
## The strongest attack on the base lately (AiMilitary.strength) and when it was last seen.
var _attack_peak := 0
var _attack_tick := 0
## Whether the wave has formed up short of its target (or met the enemy on the way).
var _staged := false
## When the wave's centre reached the form-up point, -1 before.
var _stage_tick := -1
var _launch_tick := 0
var _wave_peak := 0
var _retreat_tick := -(1 << 30)
var _defend_think := -(1 << 30)
var _reserved: Dictionary[int, bool] = {}
var _rally_set: Dictionary[int, bool] = {}


func _init(p_ai: SkirmishAi) -> void:
	ai = p_ai
	wave_extra = ai.rng.range_int(0, WAVE_JITTER)
	attack_delay = ai.rng.range_int(0, ATTACK_JITTER)


func in_wave(id: int) -> bool:
	return wave.has(id)


## A unit the economy took (to stand on a place of power): not ordered about by the army.
func reserve_unit(id: int) -> void:
	_reserved[id] = true


## Fighters and casters at home: not in the wave, not taken by the economy.
func home() -> PackedInt32Array:
	var result := PackedInt32Array()
	for list: PackedInt32Array in [ai.army, ai.casters]:
		for id: int in list:
			if not wave.has(id) and not ai.economy_ai.is_capturer(id):
				result.append(id)
	result.sort()
	return result


func rally_cell() -> Vector2i:
	var base := ai.base_cell()
	var mid := Vector2i(ai.sim.nav.width / 2, ai.sim.nav.height / 2)
	var d := mid - base
	var length := maxi(Fixed.isqrt(d.x * d.x + d.y * d.y), 1)
	var cell := base + d * RALLY_CELLS / length
	return Vector2i(
		clampi(cell.x, 1, ai.sim.nav.width - 2), clampi(cell.y, 1, ai.sim.nav.height - 2)
	)


# --- defence --------------------------------------------------------------------------------


## Enemy fighters the AI sees within AiProfile.defend_cells of its buildings at home.
func base_threatened() -> bool:
	_threat = PackedInt32Array()
	var store := ai.sim.economy.buildings
	var r := ai.profile.defend_cells
	var home_cell := ai.base_cell()
	var mine := PackedInt32Array()
	for b in ai.view.my_buildings():
		var at := Vector2i(store.cell_x[b - 1], store.cell_y[b - 1])
		if _cells_apart(at, home_cell) <= HOME_CELLS:
			mine.append(b)
	for id in ai.fighters(ai.view.enemy_units()):
		var c := ai.unit_cell(id)
		for b in mine:
			var bx := store.cell_x[b - 1]
			var by := store.cell_y[b - 1]
			var dx := maxi(maxi(bx - c.x, 0), c.x - (bx + store.w[b - 1] - 1))
			var dy := maxi(maxi(by - c.y, 0), c.y - (by + store.h[b - 1] - 1))
			if maxi(dx, dy) <= r:
				_threat.append(id)
				break
	return not _threat.is_empty()


## The home army goes for the threat; a wave far weaker than it comes back to help.
func defend_base() -> bool:
	var defenders := home()
	var theirs := ai.strength(_threat)
	if _threat.size() * 2 >= ai.profile.first_wave:
		_attack_peak = maxi(_attack_peak, theirs)
		_attack_tick = ai.sim.tick
	# After ALL_IN_TICK the wave is not called back: the race to the other base ends the game.
	var recall := ai.sim.tick < ALL_IN_TICK and not wave.is_empty()
	if recall and ai.strength(defenders) * 1000 < theirs * RECALL_PERMILLE:
		_bring_wave_home()
		defenders = home()
	if defenders.is_empty() or ai.thinks - _defend_think < DEFEND_EVERY:
		return true
	_defend_think = ai.thinks
	var p := SkirmishAi.point(ai.center_of(_threat))
	ai.order(SimCommand.attack_move(ai.sim.tick, ai.player, defenders, p.x, p.y))
	return true


# --- waves ----------------------------------------------------------------------------------


## The wave is losing: worn down to a few of its units, or it sees more enemy strength around
## it than it can take.
func wave_weak() -> bool:
	_prune_wave()
	if wave.is_empty() or ai.profile.retreat_permille <= 0 or ai.sim.tick >= ALL_IN_TICK:
		return false
	if wave.size() * 1000 < _wave_peak * WORN_PERMILLE:
		return true
	var enemies := ai.near(ai.view.enemy_units(), ai.center_of(wave), WAVE_SIGHT)
	if enemies.is_empty():
		return false
	return ai.strength(wave) * 1000 < ai.strength(enemies) * ai.profile.retreat_permille


func retreat_wave() -> bool:
	_bring_wave_home()
	return true


func _bring_wave_home() -> void:
	if wave.is_empty():
		return
	var p := SkirmishAi.point(rally_cell())
	ai.order(SimCommand.move(ai.sim.tick, ai.player, wave, p.x, p.y))
	wave = PackedInt32Array()
	assaulting = 0
	_retreat_tick = ai.sim.tick


func wave_size() -> int:
	var prof := ai.profile
	if ai.sim.tick >= ALL_IN_TICK:
		return prof.max_wave
	return mini(prof.max_wave, prof.first_wave + wave_extra + waves * prof.wave_growth)


func wave_ready() -> bool:
	if not wave.is_empty() or ai.sim.tick < ai.profile.first_attack_tick + attack_delay:
		return false
	var ready := ai.army.size()
	if _counter_now(ready):
		return true
	if ai.sim.tick - _retreat_tick < REGROUP_TICKS:
		return false
	var st := ai.state()
	# At the population limit it goes with what it has.
	var full := st != null and st.pop_used() >= ai.sim.economy.pop_cap(ai.player) - 1
	return ready >= wave_size() or (full and ready >= ai.profile.first_wave)


## Just after beating off an attack, with a home army still stronger than the attack was:
## out at once, before the enemy rebuilds (the defender's edge at home turns into a push).
func _counter_now(ready: int) -> bool:
	if _attack_peak == 0:
		return false
	var since := ai.sim.tick - _attack_tick
	if since >= COUNTER_WINDOW:
		_attack_peak = 0
		return false
	if since < COUNTER_DELAY or ready < ai.profile.first_wave:
		return false
	if ai.strength(ai.army) <= _attack_peak:
		return false
	_attack_peak = 0
	return true


func launch_wave() -> bool:
	wave = home()
	waves += 1
	_wave_peak = wave.size()
	wave_extra = ai.rng.range_int(0, WAVE_JITTER)
	target_building = 0
	target_cell = Vector2i(-1, -1)
	assaulting = 0
	_staged = false
	_stage_tick = -1
	_launch_tick = ai.sim.tick
	_pick_target()
	_march(wave)
	return true


func wave_out() -> bool:
	return not wave.is_empty()


## Keeps the wave going: reinforcements from home, a new target when the old one is gone, an
## assault once the way is clear, and stragglers sent on.
func press_attack() -> bool:
	var known := ai.view.known_buildings
	if target_building != 0 and not known.has(target_building):
		target_building = 0
		assaulting = 0
	var fresh := home()
	if fresh.size() >= maxi(REINFORCE, wave_size() / 2):
		wave.append_array(fresh)
		wave.sort()
		_wave_peak = maxi(_wave_peak, wave.size())
		_march(fresh)
	var center := ai.center_of(wave)
	if target_building == 0:
		var reached := target_cell.x < 0 or _cells_apart(center, target_cell) <= 4
		if reached or ai.view.explored(ai.sim.nav.cell_at(target_cell.x, target_cell.y)):
			if _pick_target():
				_march(wave)
				return true
	if not _staged and target_building != 0 and not _form_up(center):
		return true
	# Peasants about the target do not hold the assault up.
	var enemies := ai.fighters(ai.near(ai.view.enemy_units(), center, CLEAR_CELLS))
	var clear := enemies.is_empty()
	if target_building != 0 and clear and assaulting != target_building:
		if _cells_apart(center, target_cell) <= ASSAULT_CELLS:
			var assault := SimCommand.Kind.ASSAULT
			ai.order(SimCommand.on_building(ai.sim.tick, ai.player, assault, wave, target_building))
			assaulting = target_building
			return true
	var idle := _idle(wave)
	if not idle.is_empty():
		if assaulting != 0 and clear:
			var assault := SimCommand.Kind.ASSAULT
			ai.order(SimCommand.on_building(ai.sim.tick, ai.player, assault, idle, assaulting))
		else:
			_march(idle)
	return true


## The nearest remembered enemy capital (town centre or castle: taking them wins), else the
## building worth attacking nearest the likely enemy start (the cell opposite home across the
## map's centre), else the unexplored point nearest that cell, else an outpost. False if there
## is nowhere to go.
func _pick_target() -> bool:
	var store := ai.sim.economy.buildings
	var from := ai.center_of(wave) if not wave.is_empty() else ai.base_cell()
	# Other buildings are taken in order of nearness to the likely enemy start, so the waves
	# work their way to the heart of the enemy base.
	var guess := _enemy_start_guess()
	var best := 0
	var best_d := 0
	for b in ai.view.enemy_buildings():
		var def := store.defs[b - 1] if store.is_alive(b) else null
		if def != null and IGNORED.has(def.base_id):
			continue
		var cell := ai.view.known_buildings[b]
		var at := Vector2i(cell % ai.sim.nav.width, cell / ai.sim.nav.width)
		var d := _cells_apart(from, at)
		if def == null or not SkirmishVictory.CAPITALS.has(def.base_id):
			d = _cells_apart(guess, at)
			# A lone shrine out at a place of power is left for later: the base comes first.
			if d > OUTPOST_CELLS:
				d += OUTPOST_LAST
			d += CAPITAL_FIRST
		if best == 0 or d < best_d:
			best = b
			best_d = d
	var scout := _scout_point()
	if best != 0 and best_d >= OUTPOST_LAST and scout.x >= 0:
		best = 0
	if best != 0:
		target_building = best
		var cell := ai.view.known_buildings[best]
		target_cell = Vector2i(cell % ai.sim.nav.width, cell / ai.sim.nav.width)
		assaulting = 0
		return true
	if scout.x < 0:
		return false
	target_building = 0
	target_cell = scout
	return true


func _scout_point() -> Vector2i:
	var nav := ai.sim.nav
	var guess := _enemy_start_guess()
	var best := Vector2i(-1, -1)
	var best_d := 0
	for y in range(SCOUT_STEP / 2, nav.height, SCOUT_STEP):
		for x in range(SCOUT_STEP / 2, nav.width, SCOUT_STEP):
			var c := nav.cell_at(x, y)
			if ai.view.explored(c) or not nav.passable(NavGrid.MoveClass.FOOT, c):
				continue
			var d := _cell_dist_sq(guess, Vector2i(x, y))
			if best.x < 0 or d < best_d:
				best = Vector2i(x, y)
				best_d = d
	return best


## The cell opposite home across the map's centre.
func _enemy_start_guess() -> Vector2i:
	var base := ai.base_cell()
	return Vector2i(ai.sim.nav.width - 1 - base.x, ai.sim.nav.height - 1 - base.y)


## Waits for the wave to form up short of the target; true once it has (or has waited long
## enough, meets enemy fighters on the way or is already that close), and then sends it on.
func _form_up(center: Vector2i) -> bool:
	var met := ai.fighters(ai.near(ai.view.enemy_units(), center, WAVE_SIGHT))
	var close := ai.near(wave, center, STAGE_SLACK).size() * 1000 >= wave.size() * STAGE_PERMILLE
	var there := _cells_apart(center, _goal()) <= STAGE_SLACK
	var past := _cells_apart(center, target_cell) < STAGE_CELLS
	if there and _stage_tick < 0:
		_stage_tick = ai.sim.tick
	var waited := _stage_tick >= 0 and ai.sim.tick - _stage_tick >= STAGE_TICKS
	# The point may be hard to reach (river, forest): it does not wait for it for ever.
	waited = waited or ai.sim.tick - _launch_tick >= STAGE_TICKS * 5
	if not met.is_empty() or past or (there and close) or waited:
		_staged = true
		_march(wave)
		return true
	var idle := _idle(wave)
	if not idle.is_empty():
		_march(idle)
	return false


## Where the wave walks: the target, or while it has not formed up, the point STAGE_CELLS
## short of the target on the way from home.
func _goal() -> Vector2i:
	if _staged or target_building == 0:
		return target_cell
	var base := ai.base_cell()
	var dx := base.x - target_cell.x
	var dy := base.y - target_cell.y
	var far := maxi(_cells_apart(base, target_cell), 1)
	if far <= STAGE_CELLS:
		return target_cell
	return target_cell + Vector2i(dx * STAGE_CELLS / far, dy * STAGE_CELLS / far)


func _march(ids: PackedInt32Array) -> void:
	if ids.is_empty() or target_cell.x < 0:
		return
	var p := SkirmishAi.point(_goal())
	ai.order(SimCommand.attack_move(ai.sim.tick, ai.player, ids, p.x, p.y))


func _prune_wave() -> void:
	var alive := PackedInt32Array()
	for id in wave:
		if ai.sim.entities.is_alive(id) and ai.sim.entities.owners[id - 1] == ai.player:
			alive.append(id)
	wave = alive


## Units standing about with nothing to do: no walk, no target, no job.
func _idle(ids: PackedInt32Array) -> PackedInt32Array:
	var e := ai.sim.entities
	var eco := ai.sim.economy
	var result := PackedInt32Array()
	for id in ids:
		var slot := id - 1
		if e.orders[slot] != EntityStore.Order.IDLE or e.target[slot] != EntityStore.NO_ID:
			continue
		if eco.job[slot] != EconomySystem.Job.NONE or ai.sim.combat.is_fleeing(id):
			continue
		result.append(id)
	return result


# --- at home --------------------------------------------------------------------------------


## Fighting buildings send their units to the rally point; idle units at home gather there.
func gather_army() -> bool:
	var rally := rally_cell()
	var p := SkirmishAi.point(rally)
	var store := ai.sim.economy.buildings
	var producers := PackedInt32Array()
	for b in ai.view.my_buildings():
		var def := store.defs[b - 1]
		if def.trains.is_empty() or def.base_id == EconomySystem.TOWN_CENTER:
			continue
		if not _rally_set.has(b):
			_rally_set[b] = true
			producers.append(b)
	if not producers.is_empty():
		ai.order(SimCommand.building_rally(ai.sim.tick, ai.player, producers, p.x, p.y))
	var strays := PackedInt32Array()
	for id in _idle(home()):
		if _cells_apart(ai.unit_cell(id), rally) > RALLY_SLACK:
			strays.append(id)
	if not strays.is_empty():
		ai.order(SimCommand.move(ai.sim.tick, ai.player, strays, p.x, p.y))
	return true


# --- spells ---------------------------------------------------------------------------------


## Casters use what they can when enemies are near: the mist around themselves, exorcism on
## the enemy, the relic in their own ranks.
func cast_spells() -> bool:
	if not ai.profile.casts_spells:
		return true
	var magic := ai.sim.magic
	var enemies := ai.view.enemy_units()
	for id in ai.casters:
		var close := ai.near(enemies, ai.unit_cell(id), WAVE_SIGHT)
		if close.is_empty():
			continue
		for spell in magic.spells_of(id):
			if magic.can_cast(ai.player, id, spell.id) != MagicSystem.Cast.OK:
				continue
			var at := ai.unit_cell(id)
			if spell.tags.has(&"dispel"):
				at = ai.center_of(close)
			var p := SkirmishAi.point(at)
			var one := PackedInt32Array([id])
			ai.order(SimCommand.cast(ai.sim.tick, ai.player, one, spell.id, p.x, p.y))
			break
	return true


static func _cells_apart(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func _cell_dist_sq(a: Vector2i, b: Vector2i) -> int:
	return (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)
