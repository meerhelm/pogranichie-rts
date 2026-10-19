class_name Sides
extends RefCounted
## Who fights whom (ВКЛ 2): each player is on a side, given by the side's lead player. Without
## an entry a player is a side of its own, so a skirmish of players 1 and 2 needs nothing here.
## Player 0 (animals, neutrals) is nobody's enemy. Allies do not fight each other and share
## what they see (VisionSystem keeps one grid per side).

## Player -> the lead player of its side.
var team: Dictionary[int, int] = {}
## Players who fight nobody and whom nobody fights unless ordered (Корона 5: Červenka's
## mercenaries in Malbork, waiting for their money). They see only for themselves.
var neutral: Dictionary[int, bool] = {}


func team_of(p: int) -> int:
	return team.get(p, p)


## True if units of `a` and `b` fight each other.
func hostile(a: int, b: int) -> bool:
	if neutral.has(a) or neutral.has(b):
		return false
	return a != 0 and b != 0 and team_of(a) != team_of(b)


## True for the same player or players of one side.
func friendly(a: int, b: int) -> bool:
	return a == b or (a != 0 and b != 0 and team_of(a) == team_of(b))


func write_to(buf: StreamPeerBuffer) -> void:
	# Nothing for a world without alliances, so the hashes of older replays stay as they were.
	if team.is_empty():
		return
	var players := team.keys()
	players.sort()
	buf.put_32(players.size())
	for p: int in players:
		buf.put_32(p)
		buf.put_32(team[p])
	# Neutrals only when there are any, for the same reason.
	if neutral.is_empty():
		return
	var ns := neutral.keys()
	ns.sort()
	buf.put_32(ns.size())
	for p: int in ns:
		buf.put_32(p)
