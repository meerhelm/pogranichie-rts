class_name Lockstep
extends RefCounted
## Deterministic lockstep for two players. The world is simulated on both machines; only the
## players' commands go over the network. A command given at tick t runs at tick t + delay on
## both sides; each side sends its commands of every tick as one `turn` message (empty turns
## too, so the other side knows there is nothing more for that tick). A side steps tick t only
## once it has the other side's turn for t, so a slow line or machine makes both wait instead of
## drifting apart. The first `delay` ticks have no commands on either side.
##
## Every hash_every ticks both sides send their state hash; if they differ, the worlds have
## drifted apart (a determinism bug), and `desynced` says so once. `checkpoints` keeps every hash
## of this side, so the game can be saved as a Replay and the first bad tick found later.

## The other side's hash for a tick differs from this side's.
signal desynced(tick: int, mine: String, theirs: String)
## This side has hashed its world after `tick` (a checkpoint), before comparing it.
signal checkpointed(tick: int)

## Ticks between giving a command and running it. At the game's 40 ticks a second, 6 is 150 ms,
## enough for a line across Europe.
const DEFAULT_DELAY := 6
## Ticks between state hashes: one sim second.
const HASH_EVERY := 20
## The game waits for a command at most this far ahead (a buggy or hostile peer could flood).
const MAX_AHEAD := 2000
## Bounds of the delay as the line is measured (adapt_delay).
const MIN_DELAY := 3
const MAX_DELAY := 40
## Real milliseconds of one tick at the game's pace (40 ticks a second, Hud.BASE_SPEED).
const TICK_MSEC := 25
## Room in milliseconds for a frame and for the line's ups and downs, on top of half the round trip.
const DELAY_MARGIN_MSEC := 45
## Round trips remembered; the delay follows the slowest of them.
const RTT_SAMPLES := 8

var sim: Simulation
var local_player: int
var remote_player: int
## How many ticks ahead this side's commands run. It starts at the delay both sides agreed on and
## then follows the measured line on each side for itself (note_rtt): a side may send its turns
## further ahead or hold them back without the other side knowing, since the other side only needs
## each turn before it steps that tick. Off with `adapt` false.
var delay := DEFAULT_DELAY
var adapt := true
## Sends one message to the other side (NetSession: encode and hand to the transport).
var send: Callable
## This side's state hashes, one every HASH_EVERY ticks from the start on (as Replay).
var checkpoints := PackedStringArray()
## The first tick whose hashes differed (-1: none so far).
var desync_tick := -1
## Ticks this side could not step because the other side's turn had not come (statistics).
var stalls := 0
## Bad messages from the other side, dropped (statistics).
var rejected := 0

## Commands this side gave since its last turn went out.
var _pending: Array[SimCommand] = []
## Last tick whose turn this side has sent.
var _sent_through := -1
## The other side's commands by tick.
var _remote: Dictionary[int, Array] = {}
## This side's commands by tick, kept until they run.
var _local: Dictionary[int, Array] = {}
## The other side's hashes not yet compared, by tick.
var _remote_hashes: Dictionary[int, String] = {}
## The tick the game started at here (0 for a new game).
var _start := 0
## The first tick that has turns; before it both sides step without any (the agreed delay).
var _first := 0
var _rtts: Array[int] = []


func _init(p_sim: Simulation, p_local: int, p_remote: int, p_delay: int = DEFAULT_DELAY) -> void:
	sim = p_sim
	local_player = p_local
	remote_player = p_remote
	delay = maxi(p_delay, 1)
	_start = sim.tick
	_first = _start + delay
	_sent_through = _first - 1


## A command of the local player (PlayerInput's sink). It runs at the first tick whose turn has
## not gone out yet, delay ticks from now.
func submit(cmd: SimCommand) -> void:
	if not NetMessage.is_player_command(cmd):
		push_warning("command %s is not for network play" % SimCommand.Kind.keys()[cmd.kind])
		return
	_pending.append(cmd)


## Steps the world one tick if the other side's commands for it are here. False: still waiting.
func try_step() -> bool:
	var t := sim.tick
	_send_turns_through(t + delay)
	if t >= _first_turn() and not _remote.has(t):
		stalls += 1
		return false
	var cmds: Array = []
	if local_player < remote_player:
		cmds = _local.get(t, []) + _remote.get(t, [])
	else:
		cmds = _remote.get(t, []) + _local.get(t, [])
	_local.erase(t)
	_remote.erase(t)
	for c: SimCommand in cmds:
		c.tick = t
		sim.enqueue(c)
	sim.step()
	if sim.tick % HASH_EVERY == 0:
		var h := sim.state_hash()
		checkpoints.append(h)
		send.call({"m": "hash", "t": sim.tick, "h": h})
		checkpointed.emit(sim.tick)
		_compare(sim.tick)
	return true


## Whether the next tick can be stepped now.
func can_step() -> bool:
	return sim.tick < _first_turn() or _remote.has(sim.tick)


## A message from the other side (turn or hash); the rest is NetSession's.
func receive(msg: Dictionary) -> void:
	match msg.get("m"):
		"turn":
			_receive_turn(msg)
		"hash":
			var t: Variant = msg.get("t")
			var h: Variant = msg.get("h")
			if not (t is int and h is String):
				rejected += 1
				return
			var turn: int = t
			var hash_text: String = h
			_remote_hashes[turn] = hash_text
			_compare(turn)


func _first_turn() -> int:
	return _first


## A measured round trip: the delay becomes what the slowest of the last RTT_SAMPLES needs.
func note_rtt(msec: int) -> void:
	_rtts.append(maxi(msec, 0))
	if _rtts.size() > RTT_SAMPLES:
		_rtts.pop_front()
	if adapt:
		var slowest: int = _rtts.max()
		delay = delay_for(slowest)


## Ticks of delay a round trip of `msec` needs.
static func delay_for(msec: int) -> int:
	var need := (msec / 2 + DELAY_MARGIN_MSEC + TICK_MSEC - 1) / TICK_MSEC
	return clampi(need, MIN_DELAY, MAX_DELAY)


func _send_turns_through(last: int) -> void:
	while _sent_through < last:
		_sent_through += 1
		var mine: Array[SimCommand] = []
		for c in _pending:
			c.player = local_player
			c.tick = _sent_through
			mine.append(c)
		_pending.clear()
		_local[_sent_through] = mine
		var dicts: Array = []
		for c in mine:
			dicts.append(c.to_dict())
		send.call({"m": "turn", "t": _sent_through, "c": dicts})


func _receive_turn(msg: Dictionary) -> void:
	var t: Variant = msg.get("t")
	var raw: Variant = msg.get("c")
	if not (t is int and raw is Array):
		rejected += 1
		return
	var tick: int = t
	if tick < maxi(sim.tick, _first_turn()) or tick > sim.tick + MAX_AHEAD or _remote.has(tick):
		rejected += 1
		return
	var cmds: Array[SimCommand] = []
	var raw_list: Array = raw
	for d: Variant in raw_list.slice(0, NetMessage.MAX_COMMANDS):
		var c := NetMessage.command_from(d)
		if c == null:
			rejected += 1
			continue
		c.player = remote_player
		c.tick = tick
		cmds.append(c)
	_remote[tick] = cmds


## The first tick after the start whose hash goes in checkpoints.
func _first_hash_tick() -> int:
	return (_start / HASH_EVERY + 1) * HASH_EVERY


func _compare(t: int) -> void:
	if not _remote_hashes.has(t) or t > sim.tick:
		return
	var at := (t - _first_hash_tick()) / HASH_EVERY
	if at < 0 or at >= checkpoints.size():
		_remote_hashes.erase(t)
		return
	var mine := checkpoints[at]
	var theirs: String = _remote_hashes[t]
	_remote_hashes.erase(t)
	if mine != theirs and desync_tick < 0:
		desync_tick = t
		desynced.emit(t, mine, theirs)
