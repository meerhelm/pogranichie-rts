class_name NetSession
extends Node
## One network game of two players, from the main menu's «Network play» to the end of the game.
## It sits under the scene tree's root (not in a scene), so it lives on when the menu changes to
## the game scene, and it runs while the tree is paused.
##
## 1. The host waits (host_game), the guest connects (join_game) and sends its versions; the host
##    refuses a guest whose game differs (NetMessage.versions and the catalog's hash).
## 2. The lobby: the host picks the map and its faction, the guest its own; each marks itself
##    ready. Every change goes to the host, which sends the whole lobby back (`lobby_changed` on
##    both sides); a change of the map or a faction takes both players' «ready» back.
## 3. When both are ready the host starts (start_game): seed, map, factions, input delay. Both
##    games open the game scene, which hands its world to attach() and steps it through
##    `lockstep`. The host is player 1 (the map's first base), the guest player 2.
## In the game: either player may pause (set_paused) and either may go on; chat lines go both
## ways; the game ends for both through the simulation (victory or RESIGN), or for one side when
## the other leaves or the line breaks (`opponent_left`).
##
## Each side keeps a replay of the game: saved to user://net/ when the worlds drift apart (both
## sides save one, to compare and play back with sim_cli) and when the game is left.

## Both players are in the lobby, or it changed (map, factions, ready, names).
signal lobby_changed
## The host started the game; the game scene can open (setup holds seed, map, factions, delay).
signal started
## Could not start: no connection, or the versions differ. `why` is already translated.
signal failed(why: String)
## The other player left or the connection broke.
signal opponent_left
## The worlds drifted apart at `tick`; the replay of this side was saved at `path`.
signal desynced(tick: int, path: String)
## Which parts of the world (Simulation.part_hashes) differed at the desync tick.
signal desync_parts(parts: PackedStringArray)
## The game was paused or went on; `by_me`: this player did it.
signal paused_changed(on: bool, by_me: bool)
## A chat line from the other player.
signal chat(text: String)

enum State { IDLE, WAITING, CONNECTING, LOBBY, STARTED, PLAYING, CLOSED }

const HOST_PLAYER := 1
const GUEST_PLAYER := 2
const REPLAY_DIR := "user://net"
## Longest chat line and player name, in characters.
const MAX_CHAT := 200
const MAX_NAME := 24
## Every PING_MSEC the host and the guest measure the round trip (Lockstep.adapt_delay).
const PING_MSEC := 500

## The game in progress (null when there is none).
static var current: NetSession
## The catalog's content hash, worked out once (loading the catalog takes a moment).
static var _data_hash := ""

var state := State.IDLE
var is_host := false
var transport: NetTransport
## seed, map, factions (player 1's, player 2's), delay; complete once started.
var setup: Dictionary = {}
var local_player := HOST_PLAYER
var lockstep: Lockstep
## The lobby, as the host keeps it: whether each player (1, 2) is ready, and their names.
var ready_flags: Array[bool] = [false, false]
var names: Array[String] = ["", ""]
## The game stands paused (by either player).
var paused := false
## The last round trip to the other side in milliseconds (-1: not measured yet).
var rtt_msec := -1

var _sim: Simulation
## Turns and hashes that came before the game scene attached its world.
var _early: Array[Dictionary] = []
var _next_ping := 0
## This side's part hashes at recent checkpoints (tick -> Dictionary), for a desync report.
var _parts: Dictionary[int, Dictionary] = {}


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
	poll()


## Delivers what came over the network and measures the line now and then.
func poll() -> void:
	transport.poll()
	if state in [State.LOBBY, State.STARTED, State.PLAYING]:
		var now := Time.get_ticks_msec()
		if now >= _next_ping:
			_next_ping = now + PING_MSEC
			_send({"m": "ping", "at": now})


## The host waits for a guest, with the map and both factions as the host last picked them.
func host_game(
	p_map: String, p_factions: Array[StringName], delay: int, my_name: String = ""
) -> void:
	is_host = true
	local_player = HOST_PLAYER
	state = State.WAITING
	setup = {
		"map": p_map,
		"factions": [String(p_factions[0]), String(p_factions[1])],
		"delay": delay,
	}
	names[0] = _clean_name(my_name)


## The guest, once the transport is connecting.
func join_game(my_name: String = "") -> void:
	is_host = false
	local_player = GUEST_PLAYER
	state = State.CONNECTING
	names[1] = _clean_name(my_name)


func factions() -> Array[StringName]:
	var out: Array[StringName] = []
	for f: Variant in setup.get("factions", []):
		out.append(StringName(str(f)))
	return out


func map_id() -> String:
	return str(setup.get("map", SkirmishSetup.MAP_ID))


func remote_player() -> int:
	return GUEST_PLAYER if local_player == HOST_PLAYER else HOST_PLAYER


func remote_name() -> String:
	return names[remote_player() - 1]


# --- lobby ----------------------------------------------------------------------------------


## The host changes the map (both players' «ready» go back).
func pick_map(id: String) -> void:
	if not is_host or state != State.LOBBY and state != State.WAITING or not SkirmishMaps.has(id):
		return
	setup["map"] = id
	ready_flags = [false, false]
	_send_lobby()


## A player picks their own faction (both players' «ready» go back).
func pick_faction(faction: StringName) -> void:
	if not faction in SkirmishSetup.FACTIONS:
		return
	if is_host and state in [State.WAITING, State.LOBBY]:
		_set_faction(HOST_PLAYER, faction)
	elif not is_host and state == State.LOBBY:
		_send({"m": "pick", "faction": String(faction)})


## The host also picks the guest's faction before anyone has joined (the guest may change it).
func pick_guest_faction(faction: StringName) -> void:
	if is_host and state in [State.WAITING, State.LOBBY] and faction in SkirmishSetup.FACTIONS:
		_set_faction(GUEST_PLAYER, faction)


func set_ready(on: bool) -> void:
	if state != State.LOBBY:
		return
	if is_host:
		ready_flags[0] = on
		_send_lobby()
	else:
		_send({"m": "ready", "on": on})


func both_ready() -> bool:
	return ready_flags[0] and ready_flags[1]


## The host starts the game once both players are ready.
func start_game() -> bool:
	if not is_host or state != State.LOBBY or not both_ready():
		return false
	setup["seed"] = randi_range(1, 0x7FFFFFFF)
	var start := setup.duplicate()
	start["m"] = "start"
	_send(start)
	state = State.STARTED
	started.emit()
	return true


func _set_faction(player: int, faction: StringName) -> void:
	var sides: Array = setup["factions"]
	sides[player - 1] = String(faction)
	ready_flags = [false, false]
	_send_lobby()


func _send_lobby() -> void:
	if state == State.LOBBY:
		_send(
			{
				"m": "lobby",
				"map": map_id(),
				"factions": setup["factions"],
				"ready": ready_flags.duplicate(),
				"names": names.duplicate(),
			}
		)
	lobby_changed.emit()


# --- game -----------------------------------------------------------------------------------


## The world both games start from: the skirmish map and factions of setup, with its seed.
func new_simulation(db: CatalogDB) -> Simulation:
	var sim_seed: int = setup["seed"]
	return SkirmishSetup.new_simulation(sim_seed, db, factions(), map_id())


## The game scene's world, made from setup; from now on it steps through lockstep.
func attach(sim: Simulation) -> Lockstep:
	_sim = sim
	var turn_delay: int = setup.get("delay", 6)
	lockstep = Lockstep.new(sim, local_player, remote_player(), turn_delay)
	lockstep.send = _send
	lockstep.desynced.connect(_on_desynced)
	lockstep.checkpointed.connect(_on_checkpoint)
	state = State.PLAYING
	for msg in _early:
		_on_message(msg)
	_early.clear()
	return lockstep


## Pauses the game for both players, or lets it go on.
func set_paused(on: bool) -> void:
	if state != State.PLAYING or on == paused:
		return
	paused = on
	_send({"m": "pause", "on": on})
	paused_changed.emit(on, true)


func send_chat(text: String) -> void:
	text = text.strip_edges().left(MAX_CHAT)
	if not text.is_empty() and state in [State.LOBBY, State.STARTED, State.PLAYING]:
		_send({"m": "chat", "text": text})


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
		hello["name"] = names[1]
		_send(hello)


func _on_disconnected() -> void:
	match state:
		State.WAITING, State.CONNECTING:
			state = State.CLOSED
			failed.emit(tr("Could not connect to the other player"))
		State.LOBBY, State.STARTED, State.PLAYING:
			_gone()


## The other side is gone: the session ends here (the lobby's host waits for nobody new).
func _gone() -> void:
	if state == State.CLOSED:
		return
	state = State.CLOSED
	save_replay("last")
	transport.close()
	opponent_left.emit()


func _on_received(data: PackedByteArray) -> void:
	var msg := NetMessage.decode(data)
	if not msg.is_empty():
		_on_message(msg)


func _on_message(msg: Dictionary) -> void:
	match msg["m"]:
		"hello":
			if is_host and state == State.WAITING:
				_on_hello(msg)
		"welcome", "lobby":
			if not is_host and state in [State.CONNECTING, State.LOBBY]:
				_on_lobby(msg)
		"pick":
			if is_host and state == State.LOBBY:
				var f := StringName(str(msg.get("faction")))
				if f in SkirmishSetup.FACTIONS:
					_set_faction(GUEST_PLAYER, f)
		"ready":
			if is_host and state == State.LOBBY and msg.get("on") is bool:
				var on: bool = msg["on"]
				ready_flags[1] = on
				_send_lobby()
		"start":
			if not is_host and state == State.LOBBY:
				_on_start(msg)
		"refuse":
			if not is_host and state == State.CONNECTING:
				state = State.CLOSED
				failed.emit(_version_note(msg))
				transport.close()
		"bye":
			if state in [State.LOBBY, State.STARTED, State.PLAYING]:
				_gone()
			else:
				transport.close()
		"ping":
			_send({"m": "pong", "at": msg.get("at")})
		"pong":
			if msg.get("at") is int:
				var sent_at: int = msg["at"]
				rtt_msec = Time.get_ticks_msec() - sent_at
				if lockstep != null:
					lockstep.note_rtt(rtt_msec)
		"chat":
			if msg.get("text") is String:
				var text: String = msg["text"]
				chat.emit(text.left(MAX_CHAT))
		"pause":
			if state == State.PLAYING and msg.get("on") is bool and msg["on"] != paused:
				var on: bool = msg["on"]
				paused = on
				paused_changed.emit(paused, false)
		"parts":
			_on_parts(msg)
		"turn", "hash":
			if lockstep != null:
				lockstep.receive(msg)
			elif state == State.STARTED:
				_early.append(msg)


func _on_hello(msg: Dictionary) -> void:
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
	names[1] = _clean_name(msg.get("name"))
	state = State.LOBBY
	ready_flags = [false, false]
	_send_lobby()


func _on_lobby(msg: Dictionary) -> void:
	var map: Variant = msg.get("map")
	var sides: Variant = msg.get("factions")
	var flags: Variant = msg.get("ready")
	var who: Variant = msg.get("names")
	if not (map is String and sides is Array and flags is Array and who is Array):
		return
	var map_name: String = map
	var side_list: Array = sides
	var flag_list: Array = flags
	var who_list: Array = who
	if not _valid_setup(map_name, side_list):
		return
	setup["map"] = map
	setup["factions"] = [str(side_list[0]), str(side_list[1])]
	for i in 2:
		ready_flags[i] = flag_list.size() > i and flag_list[i] == true
		names[i] = _clean_name(who_list[i] if who_list.size() > i else "")
	state = State.LOBBY
	lobby_changed.emit()


func _on_start(msg: Dictionary) -> void:
	var map: Variant = msg.get("map")
	var sides: Variant = msg.get("factions")
	var ok: bool = msg.get("seed") is int and msg.get("delay") is int and map is String
	ok = ok and sides is Array
	if ok:
		var map_name: String = map
		var side_list: Array = sides
		ok = _valid_setup(map_name, side_list)
	if not ok:
		state = State.CLOSED
		failed.emit(tr("The other game sent a start this game cannot read"))
		transport.close()
		return
	var side_names: Array = sides
	var turn_delay: int = msg["delay"]
	setup = {
		"seed": msg["seed"],
		"map": map,
		"factions": [str(side_names[0]), str(side_names[1])],
		"delay": clampi(turn_delay, 1, Lockstep.MAX_DELAY),
	}
	state = State.STARTED
	started.emit()


static func _valid_setup(map: String, sides: Array) -> bool:
	if not SkirmishMaps.has(map) or sides.size() != 2:
		return false
	for f: Variant in sides:
		if not StringName(str(f)) in SkirmishSetup.FACTIONS:
			return false
	return true


static func _clean_name(n: Variant) -> String:
	return str(n).strip_edges().left(MAX_NAME) if n is String else ""


## Keeps this side's part hashes of the last checkpoints (Simulation.part_hashes).
func _on_checkpoint(tick: int) -> void:
	_parts[tick] = _sim.part_hashes()
	_parts.erase(tick - Lockstep.HASH_EVERY * 8)


func _on_desynced(tick: int, _mine: String, _theirs: String) -> void:
	var path := save_replay("desync")
	desynced.emit(tick, path)
	if _parts.has(tick):
		_send({"m": "parts", "t": tick, "parts": _parts[tick]})


## The other side's part hashes at the desync tick: the parts that differ from this side's.
func _on_parts(msg: Dictionary) -> void:
	var t: Variant = msg.get("t")
	var theirs: Variant = msg.get("parts")
	if not (t is int and theirs is Dictionary):
		return
	var turn: int = t
	if not _parts.has(turn):
		return
	var their_parts: Dictionary = theirs
	var mine: Dictionary = _parts[turn]
	var differ := PackedStringArray()
	for key: String in mine:
		if str(their_parts.get(key)) != str(mine[key]):
			differ.append(key)
	desync_parts.emit(differ)


## «The other player has version X, you have Y» for whichever part differs.
func _version_note(theirs: Dictionary) -> String:
	var mine := NetMessage.versions()
	if str(theirs.get("game")) != str(mine["game"]):
		return (
			tr("Different game versions: the other player has %s, you have %s")
			% [str(theirs.get("game")), str(mine["game"])]
		)
	return tr("The games differ in rules or data; both players need the same build")
