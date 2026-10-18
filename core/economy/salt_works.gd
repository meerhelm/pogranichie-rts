class_name SaltWorks
extends RefCounted
## The Crown's salt works (pl_salt_works, tag on_salt_spring) and salt springs (map object
## o_salt_spring). A spring is a silver deposit of EconomyRulesDef.salt_spring_silver anyone's
## peasants may mine; the Crown may instead set salt works over it (the deposit is gone then).
## Finished salt works give their owner silver_milli silver a second without workers, more
## with «Соляной устав» (PlayerState.salt_rate_bonus). Part of EconomySystem.

const SPRING := &"o_salt_spring"


## Whether the footprint covers a salt spring.
static func covers_spring(nav: NavGrid, cx: int, cy: int, size: Vector2i) -> bool:
	for y in range(cy, cy + size.y):
		for x in range(cx, cx + size.x):
			if nav.in_bounds(x, y) and nav.object_at(nav.cell_at(x, y)) == SPRING:
				return true
	return false


## Salt works going up take the spring's deposit away (its cells are the building's now).
static func take_spring(eco: EconomySystem, cx: int, cy: int, size: Vector2i) -> void:
	for y in range(cy, cy + size.y):
		for x in range(cx, cx + size.x):
			var at := eco.nodes.at_cell(eco.nav.cell_at(x, y))
			if at != ResourceNodes.NO_ID:
				eco.nodes.remove(at)


## Silver from finished salt works this tick (PlayerState.salt_acc keeps the thousandths).
static func step(eco: EconomySystem) -> void:
	var store := eco.buildings
	for b in store.alive_ids:
		var s := b - 1
		if store.done[s] == 0 or not store.defs[s].tags.has(&"on_salt_spring"):
			continue
		var state: PlayerState = eco.players.get(store.owners[s])
		if state == null:
			continue
		var rate := store.defs[s].param(&"silver_milli") * (1000 + state.salt_rate_bonus) / 1000
		state.salt_acc += rate
		if state.salt_acc >= EconomySystem.UNIT_ACC:
			var whole := state.salt_acc / EconomySystem.UNIT_ACC
			state.salt_acc -= whole * EconomySystem.UNIT_ACC
			state.stock[EconomySystem.SILVER] += whole
			state.gathered[EconomySystem.SILVER] += whole


## How many of this building the player has (standing or going up).
static func count_of(store: BuildingStore, p: int, id: StringName) -> int:
	var n := 0
	for b in store.alive_ids:
		if store.owners[b - 1] == p and store.type_ids[b - 1] == id:
			n += 1
	return n
