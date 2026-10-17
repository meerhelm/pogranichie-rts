class_name Banners
extends RefCounted
## Khorugv banners (ВКЛ 2): units that carry one. Own units within CombatRulesDef.banner_radius
## of a bearer get banner_morale (CombatSystem.morale_bonus). The mission says who carries a
## banner and what happens when he falls (MissionRuntime._banner).

## Bearer unit id -> true, in the order they took up their banners.
var bearers: Dictionary[int, bool] = {}


func is_empty() -> bool:
	return bearers.is_empty()


## True if an alive bearer of `owner` stands within `r` (fixed units) of the point.
func near(e: EntityStore, owner: int, px: int, py: int, r: int) -> bool:
	for id: int in bearers:
		var o := id - 1
		if not e.is_alive(id) or e.owners[o] != owner or e.hp[o] <= 0:
			continue
		var dx := e.pos_x[o] - px
		var dy := e.pos_y[o] - py
		if dx * dx + dy * dy <= r * r:
			return true
	return false


func write_to(buf: StreamPeerBuffer) -> void:
	# Nothing without banners on the field, so older replays keep their hashes.
	if bearers.is_empty():
		return
	var ids := bearers.keys()
	ids.sort()
	buf.put_32(ids.size())
	for id: int in ids:
		buf.put_32(id)
