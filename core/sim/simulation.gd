class_name Simulation
extends RefCounted
## The deterministic game world. It changes only in step(), only through commands, and uses
## only integers, its own SimRng and ascending-id iteration, so the same seed, data and
## commands give the same state on every machine. Rendering reads it and never writes it.

## Bump when a change to the rules makes old replays play out differently.
const SIM_VERSION := 1
## Map size when none is given; the skirmish map default from the implementation plan.
const DEFAULT_MAP_CELLS := 120
## Stats for unit types the catalog does not know (tests without data).
const FALLBACK_HP := 100
const FALLBACK_SPEED_MILLI := 1000

## Number of ticks already simulated; commands for this tick run at the next step().
var tick := 0
var seed_value: int
var rng: SimRng
var entities := EntityStore.new()
var queue := CommandQueue.new()
var map_width: int
var map_height: int
var data_version: String
## Every accepted command, in arrival order, for recording replays.
var command_log: Array[SimCommand] = []

var _db: CatalogDB


func _init(
	p_seed: int = 1,
	db: CatalogDB = null,
	width_cells: int = DEFAULT_MAP_CELLS,
	height_cells: int = DEFAULT_MAP_CELLS
) -> void:
	seed_value = p_seed
	rng = SimRng.new(p_seed)
	_db = db
	data_version = db.content_hash() if db != null else "none"
	map_width = Fixed.from_cells(width_cells)
	map_height = Fixed.from_cells(height_cells)


## Queues a command for its tick. Commands for a tick already simulated are refused,
## because applying them late would change the past differently on each machine.
func enqueue(cmd: SimCommand) -> bool:
	if cmd.tick < tick:
		push_warning("command for past tick %d refused at tick %d" % [cmd.tick, tick])
		return false
	queue.push(cmd)
	command_log.append(cmd)
	return true


func step() -> void:
	for cmd in queue.take_due(tick):
		_apply(cmd)
	_move_units()
	tick += 1


func run(ticks: int) -> void:
	for i in ticks:
		step()


## SHA-256 of the whole simulation state, as hex. Equal hashes mean equal worlds.
func state_hash() -> String:
	var buf := StreamPeerBuffer.new()
	buf.big_endian = false
	buf.put_32(SIM_VERSION)
	buf.put_64(tick)
	buf.put_64(rng.state)
	buf.put_64(map_width)
	buf.put_64(map_height)
	entities.write_to(buf)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(buf.data_array)
	return ctx.finish().hex_encode()


func clamp_x(x: int) -> int:
	return clampi(x, 0, map_width - 1)


func clamp_y(y: int) -> int:
	return clampi(y, 0, map_height - 1)


func _apply(cmd: SimCommand) -> void:
	match cmd.kind:
		SimCommand.Kind.SPAWN:
			_spawn(cmd)
		SimCommand.Kind.MOVE:
			var x := clamp_x(cmd.x)
			var y := clamp_y(cmd.y)
			for id in _owned(cmd):
				entities.set_move_target(id, x, y)
		SimCommand.Kind.STOP:
			for id in _owned(cmd):
				entities.stop(id)
		SimCommand.Kind.REMOVE:
			for id in _owned(cmd):
				entities.remove(id)


func _spawn(cmd: SimCommand) -> void:
	var hit_points := FALLBACK_HP
	var speed_milli := FALLBACK_SPEED_MILLI
	if _db != null:
		var def := _db.unit(cmd.type_id)
		if def == null:
			push_warning("spawn of unknown unit %s ignored" % cmd.type_id)
			return
		hit_points = def.hp
		speed_milli = def.speed_milli
	entities.spawn(
		cmd.type_id,
		cmd.player,
		clamp_x(cmd.x),
		clamp_y(cmd.y),
		hit_points,
		Fixed.speed_per_tick(speed_milli)
	)


## Ids from the command that are alive and belong to its player, ascending, without repeats.
func _owned(cmd: SimCommand) -> PackedInt32Array:
	var result := PackedInt32Array()
	for id in cmd.ids:
		if entities.is_alive(id) and entities.owners[id - 1] == cmd.player:
			result.append(id)
	result.sort()
	var unique := PackedInt32Array()
	for id in result:
		if unique.is_empty() or unique[-1] != id:
			unique.append(id)
	return unique


## Straight-line movement toward the order target; pathfinding replaces this in M3.
func _move_units() -> void:
	var e := entities
	for id in e.alive_ids:
		var slot := id - 1
		if e.orders[slot] != EntityStore.Order.MOVE:
			continue
		var dx := e.target_x[slot] - e.pos_x[slot]
		var dy := e.target_y[slot] - e.pos_y[slot]
		var dist := Fixed.isqrt(dx * dx + dy * dy)
		var step_len := e.speed[slot]
		if dist <= step_len:
			e.pos_x[slot] = e.target_x[slot]
			e.pos_y[slot] = e.target_y[slot]
			e.orders[slot] = EntityStore.Order.IDLE
		else:
			# '/' truncates toward zero, symmetric for both directions and the same everywhere.
			e.pos_x[slot] += dx * step_len / dist
			e.pos_y[slot] += dy * step_len / dist
