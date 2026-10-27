class_name NetSession
extends Node
## One network game of two players, from the main menu's «Network play» to the end of the game.
## It sits under the scene tree's root (not in a scene), so it lives on when the menu changes to
## the game scene, and it runs while the tree is paused. The host picks the map and both
## factions; the guest connects to the host's address. After the handshake (versions must match,
## see NetMessage) both games open the game scene with the same seed, map and factions; the
## game scene then hands its world to attach() and steps it through `lockstep`.
## The host is player 1 (the map's first base), the guest player 2.
##
## Each side keeps a replay of the game: saved to user://net/ when the worlds drift apart (both
## sides save one, to compare and play back with sim_cli) and when the game is left.

## The handshake is done; the game scene can open (setup holds seed, map, factions, delay).
signal started
## Could not start: no connection, or the versions differ. `why` is already translated.
signal failed(why: String)
## The other player left or the connection broke during the game.
signal opponent_left
## The worlds drifted apart at `tick`; the replay of this side was saved at `path`.
signal desynced(tick: int, path: String)

enum State { IDLE, WAITING, CONNECTING, STARTED, PLAYING, CLOSED }

const HOST_PLAYER := 1
const GUEST_PLAYER := 2
const REPLAY_DIR := "user://net"

## The game in progress (null when there is none).
static var current: NetSession
## The catalog's content hash, worked out once (loading the catalog takes a moment).
static var _data_hash := ""

var state := State.IDLE
var is_host := false
var transport: NetTransport
## seed, map, factions (player 1's, player 2's), delay; set by the host's start message.
var setup: Dictionary = {}
var local_player := HOST_PLAYER
var lockstep: Lockstep
## The other side's versions, for the refusal note.
var remote_versions: Dictionary = {}

var _sim: Simulation
## Turns and hashes that came before the game scene attached its world.
var _early: Array[Dictionary] = []


## A new session under the tree's root, replacing any old one as the current game.
static func open(tree: SceneTree, p_transport: NetTransport) -> NetSession:
	close_current()
	current = create(tree, p_transport)
	return current


## A session under the tree's root that is not the current game (tests run two in one process).
static func create(tree: SceneTree, p_transport: NetTransport) -> NetSession:
	var s := NetSession.new()
	s.name = "NetSession"  # notr
	s.transport = p_transport
	s.process_mode = Node.PROCESS_MODE_ALWAYS
	# Before the SimClock, so a tick sees the turns that came this frame.
	s.process_priority = -100
	s.transport.connected.connect(s._on_connected)
	s.transport.disconnected.connect(s._on_disconnected)
	s.transport.received.connect(s._on_received)
	tree.root.add_child(s)
	return s


## Leaves the game (telling the other side) and frees the session.
static func close_current() -> void:
	if current == null:
		return
	var s := current
	current = null
	s.leave()
	s.queue_free()


## Whether a network game is on (the game scene asks).
static func in_game() -> bool:
	return current != null and current.state in [State.STARTED, State.PLAYING]


static func data_hash() -> String:
	if _data_hash.is_empty():
		_data_hash = CatalogDB.load_prototype().content_hash()
	return _data_hash


func _process(_delta: float) -> void:
	transport.poll()


## The host waits for a guest; map and factions are its choice.
func host_game(map_id: String, factions: Array[StringName], delay: int) -> void:
	is_host = true
	local_player = HOST_PLAYER
	state = State.WAITING
	var game_seed := randi_range(1, 0x7FFFFFFF)
	setup = {
		"seed": game_seed,
		"map": map_id,
		"factions": [String(factions[0]), String(factions[1])],
		"delay": delay,
	}


## The guest, once the transport is connecting.
func join_game() -> void:
	is_host = false
	local_player = GUEST_PLAYER
	state = State.CONNECTING


func factions() -> Array[StringName]:
	var out: Array[StringName] = []
	for f: Variant in setup.get("factions", []):
		out.append(StringName(str(f)))
	return out


func map_id() -> String:
	return str(setup.get("map", SkirmishSetup.MAP_ID))


func remote_player() -> int:
	return GUEST_PLAYER if local_player == HOST_PLAYER else HOST_PLAYER


## The world both games start from: the skirmish map and factions of setup, with its seed.
func new_simulation(db: CatalogDB) -> Simulation:
	return SkirmishSetup.new_simulation(int(setup["seed"]), db, factions(), map_id())


## The game scene's world, made from setup; from now on it steps through lockstep.
func attach(sim: Simulation) -> Lockstep:
	_sim = sim
	lockstep = Lockstep.new(sim, local_player, remote_player(), int(setup.get("delay", 6)))
	lockstep.send = _send
	lockstep.desynced.connect(_on_desynced)
	state = State.PLAYING
	for msg in _early:
		lockstep.receive(msg)
	_early.clear()
	return lockstep


## Tells the other side and closes the connection; saves the replay if a game was played.
func leave() -> void:
	if state == State.CLOSED:
		return
	if transport.is_connected_to_peer():
		_send({"m": "bye"})
		transport.poll()
	save_replay("last")
	state = State.CLOSED
	transport.close()


## Saves this side's replay as user://net/<tag>_p<player>.json; returns the path ("" if none).
func save_replay(tag: String) -> String:
	if lockstep == null or _sim == null:
		return ""
	DirAccess.make_dir_recursive_absolute(REPLAY_DIR)
	var path := REPLAY_DIR.path_join("%s_p%d.json" % [tag, local_player])
	var r := Replay.of_game(_sim, map_id(), lockstep.checkpoints, Lockstep.HASH_EVERY)
	if r.save(path) != OK:
		push_warning("cannot save the network replay to %s" % path)
		return ""
	return path


func _send(msg: Dictionary) -> void:
	transport.send(NetMessage.encode(msg))


func _on_connected() -> void:
	if not is_host:
		var hello := NetMessage.versions()
		hello["m"] = "hello"
		hello["data"] = data_hash()
		_send(hello)


func _on_disconnected() -> void:
	match state:
		State.WAITING, State.CONNECTING:
			state = State.CLOSED
			failed.emit(tr("Could not connect to the other player"))
		State.STARTED, State.PLAYING:
			state = State.CLOSED
			save_replay("last")
			opponent_left.emit()


func _on_received(data: PackedByteArray) -> void:
	var msg := NetMessage.decode(data)
	if msg.is_empty():
		return
	match msg["m"]:
		"hello":
			if is_host and state == State.WAITING:
				_on_hello(msg)
		"start":
			if not is_host and state == State.CONNECTING:
				_on_start(msg)
		"refuse":
			if not is_host and state == State.CONNECTING:
				remote_versions = msg
				state = State.CLOSED
				failed.emit(_version_note(msg))
				transport.close()
		"bye":
			if state in [State.STARTED, State.PLAYING]:
				state = State.CLOSED
				save_replay("last")
				opponent_left.emit()
			transport.close()
		"turn", "hash":
			if lockstep != null:
				lockstep.receive(msg)
			elif state == State.STARTED:
				_early.append(msg)


func _on_hello(msg: Dictionary) -> void:
	remote_versions = msg
	var mine := NetMessage.versions()
	mine["data"] = data_hash()
	for key: String in ["protocol", "game", "sim", "data"]:
		if str(msg.get(key)) != str(mine[key]):
			var refuse := mine.duplicate()
			refuse["m"] = "refuse"
			_send(refuse)
			transport.poll()
			state = State.CLOSED
			failed.emit(_version_note(msg))
			return
	var start := setup.duplicate()
	start["m"] = "start"
	_send(start)
	state = State.STARTED
	started.emit()


func _on_start(msg: Dictionary) -> void:
	var map: Variant = msg.get("map")
	var sides: Variant = msg.get("factions")
	if not (
		msg.get("seed") is int and map is String and sides is Array and msg.get("delay") is int
	):
		state = State.CLOSED
		failed.emit(tr("The other game sent a start this game cannot read"))
		return
	if not SkirmishMaps.has(map as String) or (sides as Array).size() != 2:
		state = State.CLOSED
		failed.emit(tr("The other game sent a start this game cannot read"))
		return
	for f: Variant in sides as Array:
		if not StringName(str(f)) in SkirmishSetup.FACTIONS:
			state = State.CLOSED
			failed.emit(tr("The other game sent a start this game cannot read"))
			return
	setup = {
		"seed": msg["seed"],
		"map": map,
		"factions": sides,
		"delay": clampi(msg["delay"] as int, 1, 40),
	}
	state = State.STARTED
	started.emit()


func _on_desynced(tick: int, _mine: String, _theirs: String) -> void:
	var path := save_replay("desync")
	desynced.emit(tick, path)


## «The other player has version X, you have Y» for whichever part differs.
func _version_note(theirs: Dictionary) -> String:
	var mine := NetMessage.versions()
	if str(theirs.get("game")) != str(mine["game"]):
		return (
			tr("Different game versions: the other player has %s, you have %s")
			% [str(theirs.get("game")), str(mine["game"])]
		)
	return tr("The games differ in rules or data; both players need the same build")
