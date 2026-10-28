class_name SkirmishVictory
extends RefCounted
## How a skirmish ends (M8, concept doc «Победа в схватке»): a side whose capital and castles
## are all destroyed is out, and the last side left wins (CONQUEST); a side that holds every place
## of power on the map for SkirmishRulesDef.hold_all_places_ticks in a row wins at once (PLACES).
## Run by Simulation at the end of every step; integers only, part of state_hash().
##
## A side counts as out only once it has had a finished capital, so a player who has not set up
## yet (or a test without town centres) is never knocked out. With fewer than two players there
## is nobody to win against and nothing ends.
##
## A player may give up (RESIGN, network play 2026-10-27): they are out at once, and when one
## side is left it wins with reason RESIGN.
##
## In a mission (M9) these rules are off (no rules): the mission's script ends the game and
## fills in winner, reason MISSION, its end text (message) and end_tick.

enum Reason { NONE, CONQUEST, PLACES, MISSION, RESIGN }

## BuildingDef.base_id of the buildings a side must keep: «столица и замки».
const CAPITALS: Array[StringName] = [&"town_center", &"castle"]

var rules: SkirmishRulesDef
var economy: EconomySystem
var places: PowerPlaces
## The winning player once the game is over; 0 while it goes on or when all sides fell at once.
var winner := 0
var reason := Reason.NONE
## The mission's end text (an English key), for reason MISSION.
var message := ""
## Tick the game ended, -1 while it goes on.
var end_tick := -1
## Players who are out -> the tick they lost their last capital.
var out: Dictionary[int, int] = {}
## The side holding every place of power right now (0: nobody) and for how many ticks.
var holder := 0
var held_ticks := 0

var _had_capital: Dictionary[int, bool] = {}
## Players who gave up -> the tick (also in `out`).
var _resigned: Dictionary[int, int] = {}


func _init(p_rules: SkirmishRulesDef, p_economy: EconomySystem, p_places: PowerPlaces) -> void:
	rules = p_rules
	economy = p_economy
	places = p_places


func enabled() -> bool:
	return rules != null and economy.enabled()


func is_over() -> bool:
	return end_tick >= 0


func is_out(p: int) -> bool:
	return out.has(p)


## The player gives up: out now, and the game ends at once if one side is left.
func resign(p: int, tick: int) -> void:
	if not enabled() or is_over() or out.has(p) or not economy.players.has(p):
		return
	out[p] = tick
	_resigned[p] = tick
	var left: Array[int] = []
	var ids := economy.players.keys()
	ids.sort()
	for q: int in ids:
		if not out.has(q):
			left.append(q)
	if left.size() <= 1:
		_end(left[0] if left.size() == 1 else 0, Reason.RESIGN, tick)


## Finished capitals and castles of each player.
func capitals() -> Dictionary[int, int]:
	var result: Dictionary[int, int] = {}
	var store := economy.buildings
	for b in store.alive_ids:
		var s := b - 1
		if store.done[s] == 1 and CAPITALS.has(store.defs[s].base_id):
			result[store.owners[s]] = result.get(store.owners[s], 0) + 1
	return result


func step(tick: int) -> void:
	if not enabled() or is_over():
		return
	var ids := economy.players.keys()
	ids.sort()
	if ids.size() < 2:
		return
	var standing := capitals()
	var left: Array[int] = []
	for p: int in ids:
		if out.has(p):
			continue
		if standing.get(p, 0) > 0:
			_had_capital[p] = true
		elif _had_capital.has(p):
			out[p] = tick
			continue
		left.append(p)
	if left.size() <= 1 and not out.is_empty():
		_end(left[0] if left.size() == 1 else 0, Reason.CONQUEST, tick)
		return
	_hold_places(tick)


## One side holding every place counts on; anything else starts it over.
func _hold_places(tick: int) -> void:
	var side := places.holders[0] if places.count() > 0 else 0
	for i in places.count():
		if places.holders[i] != side:
			side = 0
			break
	if side == 0 or out.has(side):
		holder = 0
		held_ticks = 0
		return
	if side != holder:
		holder = side
		held_ticks = 0
	held_ticks += 1
	if held_ticks >= rules.hold_all_places_ticks:
		_end(side, Reason.PLACES, tick)


func _end(p: int, why: Reason, tick: int) -> void:
	winner = p
	reason = why
	end_tick = tick


func write_to(buf: StreamPeerBuffer) -> void:
	if not enabled():
		return
	buf.put_32(winner)
	buf.put_8(reason)
	buf.put_64(end_tick)
	buf.put_32(holder)
	buf.put_64(held_ticks)
	for d: Dictionary in [out, _had_capital]:
		var keys := d.keys()
		keys.sort()
		buf.put_32(keys.size())
		for p: int in keys:
			buf.put_32(p)
			buf.put_64(Num.of(d[p]))
	# Only games with a resignation write it, so older replays keep their hashes.
	if not _resigned.is_empty():
		var gave_up := _resigned.keys()
		gave_up.sort()
		buf.put_32(gave_up.size())
		for p: int in gave_up:
			buf.put_32(p)
