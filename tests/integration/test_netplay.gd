extends GutTest
## Network play (NetSession, Lockstep, NetMessage) over LoopbackTransport: the handshake, two
## worlds that stay equal while both sides' AIs give orders over a slow line, a drift between
## them found by the hashes, and what a peer may not send.

var _db: CatalogDB
var _sessions: Array[NetSession] = []
var _games: Array[NetMatch] = []


func before_all() -> void:
	_db = CatalogDB.load_prototype()


func after_each() -> void:
	for g in _games:
		g.free_ai()
	_games.clear()
	for s in _sessions:
		s.queue_free()
	_sessions.clear()


## Host and guest over a loopback line, in the lobby.
func _lobby(
	factions: Array[StringName] = [&"gdl", &"to"], lag: int = 0, delay: int = 6
) -> Array[NetSession]:
	var ends := LoopbackTransport.pair()
	ends[1].lag_polls = lag
	var host := NetSession.create(get_tree(), ends[0])
	var guest := NetSession.create(get_tree(), ends[1])
	_sessions.append_array([host, guest])
	host.host_game(SkirmishSetup.MAP_ID, factions, delay, "Vitaut")
	guest.join_game("Jagiello")
	_poll([host, guest])
	return [host, guest]


func _poll(pair: Array[NetSession], times: int = 10) -> void:
	for i in times + 2 * Num.of(pair[1].transport.get("lag_polls")):
		for s in pair:
			s.poll()


## Host and guest through the lobby (both ready) to the start.
func _pair(
	factions: Array[StringName] = [&"gdl", &"to"], lag: int = 0, delay: int = 6
) -> Array[NetSession]:
	var pair := _lobby(factions, lag, delay)
	for s in pair:
		s.set_ready(true)
		_poll(pair)
	assert_true(pair[0].start_game(), "the host starts")
	_poll(pair)
	return pair


func _games_of(pair: Array[NetSession]) -> Array[NetMatch]:
	var out: Array[NetMatch] = []
	for s in pair:
		var g := NetMatch.new(s)
		g.begin(_db)
		out.append(g)
	_games.append_array(out)
	return out


## Pumps both sides a few ticks at a time until both reach `ticks`.
func _play(games: Array[NetMatch], ticks: int) -> void:
	var idle := 0
	while (games[0].sim.tick < ticks or games[1].sim.tick < ticks) and idle < 50:
		var n := 0
		for g in games:
			n += g.pump(mini(3, ticks - g.sim.tick))
		idle = idle + 1 if n == 0 else 0


func test_handshake_gives_the_guest_the_hosts_game() -> void:
	var pair := _pair([&"pl", &"to"])
	assert_eq(pair[0].state, NetSession.State.STARTED)
	assert_eq(pair[1].state, NetSession.State.STARTED)
	assert_eq(pair[1].setup["map"], pair[0].setup["map"])
	assert_eq(pair[1].setup["seed"], pair[0].setup["seed"])
	assert_eq(pair[1].factions(), [&"pl", &"to"] as Array[StringName])
	assert_eq(pair[0].local_player, 1)
	assert_eq(pair[1].local_player, 2)


func test_the_lobby_carries_picks_and_takes_ready_back() -> void:
	var pair := _lobby()
	var host := pair[0]
	var guest := pair[1]
	assert_eq(host.state, NetSession.State.LOBBY)
	assert_eq(guest.state, NetSession.State.LOBBY)
	assert_eq(host.remote_name(), "Jagiello")
	assert_eq(guest.remote_name(), "Vitaut")
	host.set_ready(true)
	guest.set_ready(true)
	_poll(pair)
	assert_true(host.both_ready())
	assert_true(guest.both_ready())
	guest.pick_faction(&"pl")
	_poll(pair)
	assert_eq(host.factions(), [&"gdl", &"pl"] as Array[StringName])
	assert_eq(guest.factions(), [&"gdl", &"pl"] as Array[StringName])
	assert_false(host.both_ready(), "a new faction takes «ready» back")
	assert_false(host.start_game(), "no start before both are ready")
	host.pick_map("map_sk_grunwald")
	_poll(pair)
	assert_eq(guest.map_id(), "map_sk_grunwald")
	assert_false(guest.start_game(), "only the host starts")


func test_a_guest_leaving_the_lobby_ends_it() -> void:
	var pair := _lobby()
	var left := []
	pair[0].opponent_left.connect(func() -> void: left.append(true))
	pair[1].leave()
	_poll(pair)
	assert_eq(left.size(), 1)
	assert_eq(pair[0].state, NetSession.State.CLOSED)


func test_a_different_version_is_refused() -> void:
	var ends := LoopbackTransport.pair()
	var host := NetSession.create(get_tree(), ends[0])
	_sessions.append(host)
	host.host_game(SkirmishSetup.MAP_ID, [&"gdl", &"to"] as Array[StringName], 6)
	var why := []
	host.failed.connect(func(w: String) -> void: why.append(w))
	var hello := NetMessage.versions()
	hello["m"] = "hello"
	hello["game"] = "0.0.0"
	hello["data"] = NetSession.data_hash()
	ends[0].poll()
	ends[1].send(NetMessage.encode(hello))
	ends[0].poll()
	assert_eq(host.state, NetSession.State.CLOSED)
	assert_eq(why.size(), 1)
	assert_true(why[0].contains("0.0.0"), str(why[0]))


func test_both_worlds_stay_equal_with_ai_orders_over_a_slow_line() -> void:
	var games := _games_of(_pair([&"gdl", &"to"], 4))
	_play(games, 1200)
	assert_eq(games[0].sim.tick, 1200)
	assert_eq(games[1].sim.tick, 1200)
	assert_eq(games[0].sim.state_hash(), games[1].sim.state_hash())
	assert_eq(games[0].session.lockstep.desync_tick, -1)
	assert_eq(games[1].session.lockstep.desync_tick, -1)
	assert_eq(games[0].session.lockstep.checkpoints, games[1].session.lockstep.checkpoints)
	var players := {}
	for c in games[0].sim.command_log:
		if c.tick > 0:
			players[c.player] = true
	assert_eq(players.keys().size(), 2, "both AIs gave orders")


func test_the_saved_game_replays_to_the_same_hash() -> void:
	var games := _games_of(_pair([&"pl", &"gdl"]))
	_play(games, 600)
	var s := games[1].session
	var r := Replay.of_game(games[1].sim, s.map_id(), s.lockstep.checkpoints, Lockstep.HASH_EVERY)
	var back := Replay.from_dict(JSON.parse_string(r.to_json()) as Dictionary)
	var result := back.play(_db)
	assert_true(result.ok, result.message)
	assert_eq(result.final_hash, games[0].sim.state_hash())


func test_a_drift_between_the_worlds_is_found() -> void:
	var games := _games_of(_pair())
	_play(games, 100)
	var found := []
	for g in games:
		g.session.lockstep.desynced.connect(
			func(t: int, _a: String, _b: String) -> void: found.append(t)
		)
	# Something only one machine did: a bug the hashes must catch.
	games[1].sim.rng.state ^= 0x55
	_play(games, 200)
	assert_eq(found.size(), 2, "both sides see it")
	assert_eq(Num.of(found[0]), 120)
	assert_eq(games[0].session.lockstep.desync_tick, 120)


func test_a_drift_names_the_part_of_the_world_that_differs() -> void:
	var games := _games_of(_pair())
	_play(games, 100)
	var parts := []
	games[0].session.desync_parts.connect(func(p: PackedStringArray) -> void: parts.append(p))
	# A unit's hit points on one machine only.
	var e := games[1].sim.entities
	e.hp[e.alive_ids[0] - 1] -= 1
	_play(games, 200)
	_poll([games[0].session, games[1].session])
	assert_eq(parts.size(), 1)
	assert_true("entities" in parts[0], str(parts))
	assert_false("economy" in parts[0], str(parts))


func test_a_resignation_ends_the_game_for_both() -> void:
	var games := _games_of(_pair())
	_play(games, 60)
	games[1].session.lockstep.submit(SimCommand.resign(0, 2))
	_play(games, 100)
	for g in games:
		assert_true(g.sim.victory.is_over())
		assert_eq(g.sim.victory.winner, 1)
		assert_eq(g.sim.victory.reason, SkirmishVictory.Reason.RESIGN)
	assert_eq(games[0].sim.state_hash(), games[1].sim.state_hash())


func test_pause_and_chat_reach_the_other_player() -> void:
	var games := _games_of(_pair())
	var host := games[0].session
	var guest := games[1].session
	var lines := []
	host.chat.connect(func(t: String) -> void: lines.append(t))
	var pauses := []
	host.paused_changed.connect(func(on: bool, me: bool) -> void: pauses.append([on, me]))
	guest.set_paused(true)
	guest.send_chat("Do Wilna!")
	_poll([host, guest])
	assert_true(host.paused)
	assert_eq(pauses, [[true, false]])
	assert_eq(lines, ["Do Wilna!"])
	host.set_paused(false)
	_poll([host, guest])
	assert_false(guest.paused)


func test_the_delay_follows_the_line_and_the_worlds_stay_equal() -> void:
	assert_eq(Lockstep.delay_for(0), Lockstep.MIN_DELAY)
	assert_eq(Lockstep.delay_for(200), 6)
	assert_eq(Lockstep.delay_for(100_000), Lockstep.MAX_DELAY)
	var games := _games_of(_pair([&"pl", &"to"], 2))
	var ls := games[1].session.lockstep
	_play(games, 300)
	ls.note_rtt(600)
	assert_gt(ls.delay, Lockstep.DEFAULT_DELAY, "a slow line: commands run later")
	_play(games, 600)
	for i in Lockstep.RTT_SAMPLES:
		ls.note_rtt(0)
	assert_eq(ls.delay, Lockstep.MIN_DELAY, "a quick line: sooner")
	_play(games, 900)
	assert_eq(games[0].sim.state_hash(), games[1].sim.state_hash())
	assert_eq(ls.desync_tick, -1)


func test_commands_a_player_may_not_send_are_dropped() -> void:
	var games := _games_of(_pair())
	var ls := games[1].session.lockstep
	# The host's own lockstep refuses a SPAWN, and the guest refuses one that comes in a turn.
	games[0].session.lockstep.submit(SimCommand.spawn(0, 1, &"gdl_spearman", 4096, 4096))
	var spawn := SimCommand.spawn(0, 1, &"gdl_spearman", 4096, 4096).to_dict()
	ls.receive({"m": "turn", "t": 50, "c": [spawn, {"k": "MOVE", "ids": "x"}, 7]})
	ls.receive({"m": "turn", "t": "x", "c": []})
	assert_eq(ls.rejected, 4)
	_play(games, 100)
	assert_eq(games[0].sim.state_hash(), games[1].sim.state_hash())
	for g in games:
		for c in g.sim.command_log:
			assert_false(c.kind == SimCommand.Kind.SPAWN and c.tick > 0, "no SPAWN got in")


func test_a_tick_waits_for_the_other_sides_turn() -> void:
	var pair := _pair([&"gdl", &"to"], 0, 2)
	var sim := pair[0].new_simulation(_db)
	var ls := pair[0].attach(sim)
	assert_true(ls.try_step())
	assert_true(ls.try_step())
	# Tick 2 needs the guest's turn 2, which has not come.
	assert_false(ls.try_step())
	assert_eq(sim.tick, 2)
	assert_eq(ls.stalls, 1)


func test_the_clock_waits_while_the_stepper_cannot_step() -> void:
	var clock := SimClock.new()
	clock.sim = Simulation.new(1, null, 16, 16)
	var allow := [false]
	clock.stepper = func() -> bool:
		if not allow[0]:
			return false
		clock.sim.step()
		return true
	clock.add_time_usec(Fixed.TICK_USEC * 4)
	assert_eq(clock.advance_accumulated(), 0)
	assert_eq(clock.waiting, 1)
	allow[0] = true
	assert_eq(clock.advance_accumulated(), SimClock.WAIT_BACKLOG)
	assert_eq(clock.waiting, 0)
	clock.free()


func test_messages_that_are_not_ours_decode_to_nothing() -> void:
	assert_eq(NetMessage.decode(PackedByteArray([1, 2])), {})
	assert_eq(NetMessage.decode(var_to_bytes([1, 2, 3])), {})
	assert_eq(NetMessage.decode(var_to_bytes({"x": 1})), {})
	var msg := {"m": "turn", "t": 5, "c": []}
	assert_eq(NetMessage.decode(NetMessage.encode(msg)), msg)
