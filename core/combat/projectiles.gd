class_name Projectiles
extends RefCounted
## Arrows, bolts and javelins in flight (CombatSystem), as flat arrays in launch order. Damage
## is settled when a shot lands, against the target's armor at that moment; the side of the hit,
## the class bonus and the shooter's wavering are fixed at launch.

const MISS := 1
const CANNON := 2
const DAMAGE_TYPES: Array[StringName] = [Damage.MELEE, Damage.PIERCE, Damage.FIREARM, Damage.SIEGE]

## Shooter id and side, target id.
var from := PackedInt32Array()
var owner := PackedInt32Array()
var target := PackedInt32Array()
## Tick it was shot and the tick it lands; where it was shot from (fixed units).
var launched := PackedInt32Array()
var lands := PackedInt32Array()
var x := PackedInt64Array()
var y := PackedInt64Array()
var damage := PackedInt32Array()
## Index into DAMAGE_TYPES.
var type := PackedByteArray()
var bonus := PackedInt32Array()
## The shooter's multipliers at launch, per-mille.
var mult := PackedInt32Array()
var side := PackedByteArray()
## MISS (lost in the forest), CANNON (morale hit around the target).
var flags := PackedByteArray()


func size() -> int:
	return from.size()


## Adds a shot from unit `shooter` at (sx, sy) to unit `aim`, landing after `flight` ticks.
func launch(
	shooter: int,
	side_of: int,
	aim: int,
	sx: int,
	sy: int,
	now: int,
	flight: int,
	hit: Damage.Hit,
	mult_permille: int,
	shot_flags: int
) -> void:
	from.append(shooter)
	owner.append(side_of)
	target.append(aim)
	launched.append(now)
	lands.append(now + flight)
	x.append(sx)
	y.append(sy)
	damage.append(hit.damage)
	type.append(DAMAGE_TYPES.find(hit.damage_type))
	bonus.append(hit.bonus)
	mult.append(mult_permille)
	side.append(hit.side)
	flags.append(shot_flags)


## Indices of the shots that land at or before `now`, in launch order.
func landing(now: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	for i in from.size():
		if lands[i] <= now:
			result.append(i)
	return result


## Removes every shot that lands at or before `now`.
func drop_landed(now: int) -> void:
	var keep := PackedInt32Array()
	for i in from.size():
		if lands[i] > now:
			keep.append(i)
	if keep.size() == from.size():
		return
	_keep_ints(from, keep)
	_keep_ints(owner, keep)
	_keep_ints(target, keep)
	_keep_ints(launched, keep)
	_keep_ints(lands, keep)
	_keep_longs(x, keep)
	_keep_longs(y, keep)
	_keep_ints(damage, keep)
	_keep_bytes(type, keep)
	_keep_ints(bonus, keep)
	_keep_ints(mult, keep)
	_keep_bytes(side, keep)
	_keep_bytes(flags, keep)


## The Hit of shot i, without the target's armor (the caller fills it in when it lands).
func hit_of(i: int) -> Damage.Hit:
	var hit := Damage.Hit.new()
	hit.damage = damage[i]
	hit.damage_type = DAMAGE_TYPES[type[i]]
	hit.bonus = bonus[i]
	hit.side = side[i]
	hit.multipliers.append(mult[i])
	return hit


func write_to(buf: StreamPeerBuffer) -> void:
	buf.put_32(from.size())
	for i in from.size():
		buf.put_32(from[i])
		buf.put_32(owner[i])
		buf.put_32(target[i])
		buf.put_32(launched[i])
		buf.put_32(lands[i])
		buf.put_64(x[i])
		buf.put_64(y[i])
		buf.put_32(damage[i])
		buf.put_8(type[i])
		buf.put_32(bonus[i])
		buf.put_32(mult[i])
		buf.put_8(side[i])
		buf.put_8(flags[i])


static func _keep_ints(arr: PackedInt32Array, keep: PackedInt32Array) -> void:
	for k in keep.size():
		arr[k] = arr[keep[k]]
	arr.resize(keep.size())


static func _keep_longs(arr: PackedInt64Array, keep: PackedInt32Array) -> void:
	for k in keep.size():
		arr[k] = arr[keep[k]]
	arr.resize(keep.size())


static func _keep_bytes(arr: PackedByteArray, keep: PackedInt32Array) -> void:
	for k in keep.size():
		arr[k] = arr[keep[k]]
	arr.resize(keep.size())
