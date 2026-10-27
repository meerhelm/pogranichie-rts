class_name NetMessage
extends RefCounted
## The messages the two games send each other, as dictionaries packed with var_to_bytes (no
## objects, so a packet from the other side cannot make this side run code).
##
## - hello (guest → host): versions and the guest's name; welcome/lobby (host → guest): map,
##   factions, who is ready, names; pick, ready (guest → host): the guest's faction, readiness.
## - start (host → guest): seed, map, factions, input delay, once both are ready.
## - refuse (host → guest): why the game cannot start (versions differ).
## - turn: one player's commands for one tick (Lockstep).
## - hash: the state hash after a tick, to find out when the games have drifted apart; parts:
##   the hash of each part of the world at the tick they drifted (where to look).
## - ping / pong: the round trip, for Lockstep's delay; pause: the game stops or goes on for
##   both; chat: a line of text; bye: the player leaves the game.

## Bump when the messages change in a way older games cannot read.
const PROTOCOL := 2

## Commands a player may send over the network. The rest (SPAWN, REMOVE, JOIN, PLACE, CHOOSE)
## are the game's own (start of a skirmish, missions, tests) and are refused from a player.
const PLAYER_KINDS: Array[SimCommand.Kind] = [
	SimCommand.Kind.MOVE,
	SimCommand.Kind.STOP,
	SimCommand.Kind.ATTACK,
	SimCommand.Kind.ATTACK_MOVE,
	SimCommand.Kind.STANCE,
	SimCommand.Kind.RETREAT,
	SimCommand.Kind.TURN,
	SimCommand.Kind.DISMOUNT,
	SimCommand.Kind.RALLY,
	SimCommand.Kind.BUILD,
	SimCommand.Kind.WALL,
	SimCommand.Kind.GATHER,
	SimCommand.Kind.WORK,
	SimCommand.Kind.ASSAULT,
	SimCommand.Kind.QUEUE,
	SimCommand.Kind.CANCEL,
	SimCommand.Kind.BUILDING_RALLY,
	SimCommand.Kind.CAST,
	SimCommand.Kind.IGNITE,
	SimCommand.Kind.DISMANTLE,
	SimCommand.Kind.TABOR,
	SimCommand.Kind.RESIGN,
]
## No order names more units than this (a whole army is a few hundred).
const MAX_IDS := 1000
## Nor does a player send more commands in one tick.
const MAX_COMMANDS := 64


static func encode(msg: Dictionary) -> PackedByteArray:
	return var_to_bytes(msg)


## The message in the packet, or an empty dictionary if it is not one.
static func decode(data: PackedByteArray) -> Dictionary:
	if data.size() < 4:
		return {}
	var v: Variant = bytes_to_var(data)
	if not v is Dictionary:
		return {}
	var d: Dictionary = v
	if not d.get("m") is String:
		return {}
	return d


static func versions() -> Dictionary:
	return {
		"protocol": PROTOCOL,
		"game": str(ProjectSettings.get_setting("application/config/version")),
		"sim": Simulation.SIM_VERSION,
	}


## The command a player sent, or null if it is malformed or not a player's command.
static func command_from(d: Variant) -> SimCommand:
	if not d is Dictionary:
		return null
	var dict: Dictionary = d
	var kind_name: Variant = dict.get("k")
	if not kind_name is String:
		return null
	var kind := SimCommand.Kind.keys().find(kind_name as String)
	if kind < 0 or not (kind as SimCommand.Kind) in PLAYER_KINDS:
		return null
	for key: String in ["t", "p", "x", "y", "x2", "y2", "f", "tg", "v"]:
		if dict.has(key) and not (dict[key] is int or dict[key] is float):
			return null
	if dict.has("u") and not dict["u"] is String:
		return null
	if dict.has("ids"):
		var ids: Variant = dict["ids"]
		if not ids is Array or (ids as Array).size() > MAX_IDS:
			return null
		for v: Variant in ids as Array:
			if not (v is int or v is float):
				return null
	var safe := dict.duplicate()
	# Tick and player are the receiver's to set (Lockstep); a sender cannot pick them.
	safe["t"] = 0
	safe["p"] = 0
	return SimCommand.from_dict(safe)


static func is_player_command(cmd: SimCommand) -> bool:
	return cmd.kind in PLAYER_KINDS
