class_name PlayerState
extends RefCounted
## One player's economy: faction, age, stock, population and what research has given.

var player: int
var faction: StringName
## 1 Удел, 2 Хоругвь, 3 Держава.
var age := 1
## Food, wood, iron, silver (EconomySystem.FOOD...).
var stock := PackedInt64Array([0, 0, 0, 0])
## Population of living units, and of units whose training has started.
var pop_units := 0
var pop_training := 0
## Population the finished houses, centres and castles give (before the hard limit).
var pop_provided := 0
## Researched techs and ages being researched, by id.
var techs: Dictionary[StringName, bool] = {}
var researching: Dictionary[StringName, bool] = {}
## Per-mille increases from techs: gathering by ResourceNodes.Source, field food, zaseka
## felling speed and HP.
var gather_bonus := PackedInt32Array([0, 0, 0, 0, 0, 0])
var farm_food_bonus := 0
var zaseka_speed_bonus := 0
var zaseka_hp_bonus := 0
## Unit stat changes from techs: "<class or unit id>.<stat>" -> sum.
var unit_mods: Dictionary[StringName, int] = {}


func _init(p_player: int, p_faction: StringName) -> void:
	player = p_player
	faction = p_faction


func pop_used() -> int:
	return pop_units + pop_training


func can_pay(cost: PackedInt32Array) -> bool:
	for r in 4:
		if stock[r] < cost[r]:
			return false
	return true


func pay(cost: PackedInt32Array) -> void:
	for r in 4:
		stock[r] -= cost[r]


func refund(cost: PackedInt32Array, permille: int) -> void:
	for r in 4:
		stock[r] += cost[r] * permille / 1000


func write_to(buf: StreamPeerBuffer) -> void:
	buf.put_32(player)
	buf.put_utf8_string(String(faction))
	buf.put_32(age)
	for v in stock:
		buf.put_64(v)
	buf.put_32(pop_units)
	buf.put_32(pop_training)
	buf.put_32(pop_provided)
	for d: Dictionary in [techs, researching]:
		var ids := PackedStringArray()
		for k: StringName in d:
			ids.append(String(k))
		ids.sort()
		buf.put_32(ids.size())
		for k in ids:
			buf.put_utf8_string(k)
	for v in gather_bonus:
		buf.put_32(v)
	buf.put_32(farm_food_bonus)
	buf.put_32(zaseka_speed_bonus)
	buf.put_32(zaseka_hp_bonus)
	var keys := PackedStringArray()
	for k: StringName in unit_mods:
		keys.append(String(k))
	keys.sort()
	for k in keys:
		buf.put_utf8_string(k)
		buf.put_32(unit_mods[StringName(k)])
