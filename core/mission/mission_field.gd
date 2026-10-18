class_name MissionField
extends RefCounted
## The rules of «Корона 1. Грюнвальд, 1410» (def.rules.field), run by MissionRuntime.step() on
## this object's state, which the runtime's save and hash carry: the summer heat on men in
## heavy armour, the line nobody crosses before the order, the great banner of the kingdom that
## keeps up the spirit of the whole Polish army and the guest knights taken for ransom.
##
## Rules (field):
##   heat {players, every_ticks, sun, shade, max, shade_cells, start {player: permille}}: units of
##     those players tagged heat_morale or of class heavy_cavalry (heroes and units that never
##     flee left out) heat up by `sun` permille every every_ticks in the sun and cool down by
##     `shade` in the shade: within shade_cells of a forest or on a boggy hollow. Their morale
##     cannot rise above full × (1000 − heat) / 1000; heat stops at `max`. `start`: the heat the
##     player's units begin with (the Order has stood in the sun since morning);
##   line {player, y, until, back_y}: until the trigger `until` fires, the player's units that
##     go north of row y are sent back to row back_y (flag line_crossed the first time);
##   royal_banner {group, players, morale, raiser, radius, ticks}: the group's first member
##     carries the great banner; while it stands every unit of `players` gets `morale` (catalog
##     points). Dropped (action drop_banner) it lies where the bearer stood; a unit of type
##     `raiser` of the mission's player within radius cells of it sets the flag banner_reached;
##     not raised (action raise_banner) in `ticks`: flag royal_banner_lost;
##   capture {group, permille, radius}: members of the group cannot fall below permille of their
##     HP; there, with a unit of the player's side within radius cells, one is taken captive (he
##     leaves the map, flag captive).
## Conditions: captives {at_least}. Actions: drop_banner, raise_banner.

const CONDITIONS: Array[String] = ["captives"]
const ACTIONS: Array[String] = ["drop_banner", "raise_banner"]
## A unit sent back over the line is sent again after this many ticks if it still stands there.
const RESEND_TICKS := 100

## Heat per unit id, in permille.
var heat: Dictionary[int, int] = {}
## Cells in the shade (1) or in the sun (0), made at the start from the map.
var shade := PackedByteArray()
## Units sent back over the line: id -> the tick they were sent.
var sent_back: Dictionary[int, int] = {}
## The great banner: who carries it, where it lies and since when (-1: it stands).
var bearer := 0
var banner_x := 0
var banner_y := 0
var banner_down := -1
## Guest knights taken captive.
var captured := 0


func set_up(m: MissionRuntime) -> void:
	var r := _rules(m)
	if r.is_empty():
		return
	var h: Dictionary = r.get("heat", {})
	if not h.is_empty():
		_make_shade(m, int(h.get("shade_cells", 2)))
		var start: Dictionary = h.get("start", {})
		for id in m.entities.alive_ids:
			if _feels_heat(m, h, id - 1):
				heat[id] = int(start.get(str(m.entities.owners[id - 1]), 0))
	var b: Dictionary = r.get("royal_banner", {})
	if not b.is_empty():
		var carriers := m.alive_of(b["group"])
		if not carriers.is_empty():
			bearer = carriers[0]
			_banner_morale(m, b, true)
	var c: Dictionary = r.get("capture", {})
	if not c.is_empty():
		for id in m.alive_of(c["group"]):
			var floor_hp := maxi(m.entities.max_hp[id - 1] * int(c["permille"]) / 1000, 1)
			m.combat.hp_floor[id] = floor_hp


func step(m: MissionRuntime, tick: int) -> void:
	var r := _rules(m)
	if r.is_empty():
		return
	_heat(m, r.get("heat", {}), tick)
	_line(m, r.get("line", {}), tick)
	_banner(m, r.get("royal_banner", {}), tick)
	_capture(m, r.get("capture", {}), tick)


func test(_m: MissionRuntime, c: Dictionary) -> bool:
	match c["type"]:
		"captives":
			return captured >= int(c["at_least"])
	return false


func run(m: MissionRuntime, a: Dictionary, tick: int) -> void:
	var b: Dictionary = _rules(m).get("royal_banner", {})
	if b.is_empty():
		return
	match a["do"]:
		"drop_banner":
			if banner_down >= 0:
				return
			if m.entities.is_alive(bearer):
				banner_x = m.entities.pos_x[bearer - 1]
				banner_y = m.entities.pos_y[bearer - 1]
			banner_down = tick
			_banner_morale(m, b, false)
			m.flags["royal_banner_down"] = tick
			var at := [Fixed.to_cells(banner_x), Fixed.to_cells(banner_y)]
			m.run({"do": "ping", "at": at, "radius": 3}, tick)
		"raise_banner":
			if banner_down < 0:
				return
			banner_down = -1
			if not m.entities.is_alive(bearer):
				bearer = _raiser_near(m, b)
			_banner_morale(m, b, true)
			m.flags["royal_banner_raised"] = tick


## Whether the great banner stands now.
func banner_up() -> bool:
	return banner_down < 0 and bearer != 0


## The mean heat of the player's units that feel it, in permille (0 with none).
func player_heat(m: MissionRuntime) -> int:
	var total := 0
	var n := 0
	for id: int in heat:
		if m.entities.is_alive(id) and m.entities.owners[id - 1] == m.def.player:
			total += heat[id]
			n += 1
	return total / n if n > 0 else 0


# --- heat -----------------------------------------------------------------------------------


func _feels_heat(m: MissionRuntime, h: Dictionary, slot: int) -> bool:
	var e := m.entities
	if not (h["players"] as Array).has(e.owners[slot]):
		return false
	var def := m.combat.defs[slot] if slot < m.combat.defs.size() else null
	if def == null or m.combat.flags[slot] & (CombatSystem.F_HERO | CombatSystem.F_NEVER_FLEES):
		return false
	return def.tags.has(&"heat_morale") or def.has_class(&"heavy_cavalry")


## Shade: cells within `reach` cells of a forest, and boggy hollows.
func _make_shade(m: MissionRuntime, reach: int) -> void:
	var nav := m.magic.nav
	var w := nav.width
	var hgt := nav.height
	shade.resize(w * hgt)
	shade.fill(0)
	for cell in w * hgt:
		var t := nav.terrain_at(cell)
		if t == NavGrid.BOG:
			shade[cell] = 1
		elif String(t).contains("forest"):
			shade[cell] = 2
	for k in reach:
		var grown := shade.duplicate()
		for cy in hgt:
			for cx in w:
				if shade[cy * w + cx] == 2:
					for dy in range(-1, 2):
						for dx in range(-1, 2):
							if (
								nav.in_bounds(cx + dx, cy + dy)
								and grown[(cy + dy) * w + cx + dx] == 0
							):
								grown[(cy + dy) * w + cx + dx] = 2
		shade = grown


func in_shade(m: MissionRuntime, x: int, y: int) -> bool:
	var cell := m.magic.nav.cell_of(x, y)
	return cell >= 0 and cell < shade.size() and shade[cell] != 0


func _heat(m: MissionRuntime, h: Dictionary, tick: int) -> void:
	if h.is_empty():
		return
	var e := m.entities
	var every := int(h["every_ticks"])
	var top := int(h["max"])
	if tick % every == 0:
		for id in e.alive_ids:
			var s := id - 1
			if not heat.has(id):
				if not _feels_heat(m, h, s):
					continue
				heat[id] = 0
			if in_shade(m, e.pos_x[s], e.pos_y[s]):
				heat[id] = maxi(heat[id] - int(h["shade"]), 0)
			else:
				heat[id] = mini(heat[id] + int(h["sun"]), top)
	var gone := PackedInt32Array()
	for id: int in heat:
		if not e.is_alive(id):
			gone.append(id)
			continue
		var s := id - 1
		var cap := m.combat.defs[s].morale * CombatSystem.MORALE_SCALE * (1000 - heat[id]) / 1000
		if e.morale[s] > cap:
			e.morale[s] = cap
	for id in gone:
		heat.erase(id)


# --- the line -------------------------------------------------------------------------------


func _line(m: MissionRuntime, l: Dictionary, tick: int) -> void:
	if l.is_empty() or m.fired.has(l["until"]):
		if not sent_back.is_empty():
			sent_back.clear()
		return
	var e := m.entities
	var p := int(l["player"])
	var row := Fixed.from_cells(int(l["y"]))
	var back := PackedInt32Array()
	var sum_x := 0
	for id in e.alive_ids:
		var s := id - 1
		if e.owners[s] != p:
			continue
		if e.pos_y[s] >= row:
			sent_back.erase(id)
			continue
		if sent_back.has(id) and tick - sent_back[id] < RESEND_TICKS:
			continue
		sent_back[id] = tick
		back.append(id)
		sum_x += e.pos_x[s]
	if back.is_empty():
		return
	if not m.flags.has("line_crossed"):
		m.flags["line_crossed"] = tick
	var x := sum_x / back.size()
	var y := Fixed.from_cells(int(l["back_y"])) + Fixed.HALF
	m._apply.call(SimCommand.move(tick, p, back, x, y))


# --- the great banner -----------------------------------------------------------------------


func _banner(m: MissionRuntime, b: Dictionary, tick: int) -> void:
	if b.is_empty() or banner_down < 0 or m.flags.has("royal_banner_lost"):
		return
	if not m.flags.has("banner_reached") and _raiser_near(m, b) != 0:
		m.flags["banner_reached"] = tick
	if tick - banner_down >= int(b["ticks"]) and not m.flags.has("banner_reached"):
		m.flags["royal_banner_lost"] = tick


## The raiser of the mission's player within reach of the lying banner, or 0.
func _raiser_near(m: MissionRuntime, b: Dictionary) -> int:
	var e := m.entities
	var reach := Fixed.from_cells(int(b["radius"]))
	var kind := StringName(b["raiser"])
	for id in e.alive_ids:
		var s := id - 1
		if e.owners[s] != m.def.player or e.type_ids[s] != kind or e.hp[s] <= 0:
			continue
		var dx := e.pos_x[s] - banner_x
		var dy := e.pos_y[s] - banner_y
		if dx * dx + dy * dy <= reach * reach:
			return id
	return 0


func _banner_morale(m: MissionRuntime, b: Dictionary, on: bool) -> void:
	var crown := m.combat.crown
	for p: int in b["players"]:
		if on and bearer != 0:
			crown.army_morale[p] = int(b["morale"])
		else:
			crown.army_morale.erase(p)


# --- captives -------------------------------------------------------------------------------


func _capture(m: MissionRuntime, c: Dictionary, tick: int) -> void:
	if c.is_empty():
		return
	var reach := Fixed.from_cells(int(c["radius"]))
	for id in m.alive_of(c["group"]):
		if not m.combat.hp_floor.has(id) or m.entities.hp[id - 1] > m.combat.hp_floor[id]:
			continue
		if not _friend_near(m, id - 1, reach):
			continue
		captured += 1
		m.captives += 1
		m.flags["captive"] = tick
		var s := id - 1
		var at := [Fixed.to_cells(m.entities.pos_x[s]), Fixed.to_cells(m.entities.pos_y[s])]
		m.run({"do": "ping", "at": at, "radius": 2}, tick)
		m.combat.hp_floor.erase(id)
		m._remove.call(id)
		return


func _friend_near(m: MissionRuntime, s: int, reach: int) -> bool:
	var e := m.entities
	var p := m.def.player
	for other in m.combat.buckets.near(e.pos_x[s], e.pos_y[s], reach):
		var o := other - 1
		if e.hp[o] <= 0 or not m.are_friendly(p, e.owners[o]):
			continue
		var dx := e.pos_x[o] - e.pos_x[s]
		var dy := e.pos_y[o] - e.pos_y[s]
		if dx * dx + dy * dy <= reach * reach:
			return true
	return false


func _rules(m: MissionRuntime) -> Dictionary:
	return m.def.rules.get("field", {})


func write_to(buf: StreamPeerBuffer) -> void:
	# Nothing outside this mission, so older replays keep their hashes.
	if heat.is_empty() and bearer == 0 and captured == 0 and sent_back.is_empty():
		return
	var ids := heat.keys()
	ids.sort()
	buf.put_32(ids.size())
	for id: int in ids:
		buf.put_32(id)
		buf.put_32(heat[id])
	ids = sent_back.keys()
	ids.sort()
	buf.put_32(ids.size())
	for id: int in ids:
		buf.put_32(id)
		buf.put_64(sent_back[id])
	buf.put_32(bearer)
	buf.put_64(banner_x)
	buf.put_64(banner_y)
	buf.put_64(banner_down)
	buf.put_32(captured)
