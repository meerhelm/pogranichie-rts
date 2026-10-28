class_name ResourceTip
extends RefCounted
## The top bar's tooltip of a resource: where it comes from, how many peasants work on it now,
## what came in and went out over the last minute, and which techs make it come faster (those
## researched and those the player can still research).

## Tech effects (TechDef.effects keys) that bring each resource faster, by resource.
const EFFECTS := {
	EconomySystem.FOOD: ["gather_farm", "gather_hunt", "gather_bort", "farm_food"],
	EconomySystem.WOOD: ["gather_wood"],
	EconomySystem.IRON: ["gather_iron"],
	EconomySystem.SILVER: ["gather_silver", "salt_rate"],
}


static func t(text: String) -> String:
	return TranslationServer.translate(text)


## Peasants of the player gathering each resource: [food, wood, iron, silver] and, for food,
## [fields, hunting, hives] after them.
static func workers(eco: EconomySystem, p: int) -> PackedInt32Array:
	var out := PackedInt32Array([0, 0, 0, 0, 0, 0, 0])
	var e := eco.entities
	for id in e.alive_ids:
		var slot := id - 1
		if e.owners[slot] != p:
			continue
		var job := eco.job[slot]
		var source := -1
		if job == EconomySystem.Job.HUNT:
			source = ResourceNodes.Source.HUNT
		elif job == EconomySystem.Job.GATHER:
			source = eco.job_source[slot]
		if source < 0:
			continue
		out[ResourceNodes.SOURCE_RESOURCE[source]] += 1
		match source:
			ResourceNodes.Source.FARM:
				out[4] += 1
			ResourceNodes.Source.HUNT:
				out[5] += 1
			ResourceNodes.Source.BORT:
				out[6] += 1
	return out


## Techs of the player's faction that make resource `r` come faster, in catalog order: those
## researched ("done"), being researched ("researching") and still to research ("open"; not
## those a mission keeps shut).
static func techs_for(eco: EconomySystem, p: int, r: int) -> Dictionary:
	var out := {"done": [], "researching": [], "open": []}
	var state := eco.player(p)
	var fac := eco.db.faction(state.faction) if state != null else null
	if fac == null:
		return out
	for id in fac.tech_ids:
		var def := eco.db.tech(id)
		if def == null or not _touches(def, r):
			continue
		var key := ""
		if state.techs.has(id):
			key = "done"
		elif state.researching.has(id):
			key = "researching"
		elif not state.locked.has(id):
			key = "open"
		if not key.is_empty():
			var list: Array = out[key]
			list.append(def)
	return out


static func _touches(def: TechDef, r: int) -> bool:
	var keys: Array = EFFECTS.get(r, [])
	for k: StringName in def.effects:
		if keys.has(String(k)):
			return true
	return false


## Where the tech is researched, by name, for the player's faction ("" if unknown).
static func where(eco: EconomySystem, faction: StringName, def: TechDef) -> String:
	var b := def.building
	if def.faction == &"":
		var fac := eco.db.faction(faction)
		if fac != null:
			b = fac.building_for(def.building)
	return UiText.name_of(b) if eco.db.building(b) != null else ""


## The tooltip of resource `r` for player `p`, with the flow over the last minute.
static func make(eco: EconomySystem, p: int, r: int, flow: ResourceFlow) -> Tips.Tip:
	var tip := Tips.Tip.new()
	var state := eco.player(p)
	var count := str(state.stock[r]) if state != null else ""
	tip.header(IconDB.small(r), "%s: %s" % [UiText.resource(r), count], "", "", "")
	tip.text(UiText.resource_help(r), Tips.MUTED)
	var w := workers(eco, p)
	var line := t("Peasants at work: %d") % w[r]
	if r == EconomySystem.FOOD and w[r] > 0:
		var parts := PackedStringArray()
		for i: int in 3:
			if w[4 + i] > 0:
				parts.append(_food_part(i) % w[4 + i])
		line += " (%s)" % ", ".join(parts)
	tip.text(line)
	var gain := flow.income(r) if flow != null else 0
	var spent := flow.spending(r) if flow != null else 0
	tip.text(t("Income: +%d a minute") % gain, Tips.GOOD)
	var out := "−%d" % spent if spent > 0 else "0"  # notr
	tip.text(t("Spending: %s a minute") % out, Tips.BAD if spent > 0 else "")
	tip.text(t("(over the last minute of game time)"), Tips.MUTED)
	var techs := techs_for(eco, p, r)
	var done := PackedStringArray()
	for def: TechDef in techs["done"]:
		done.append(_tech_line(def))
	if done.is_empty():
		tip.text("%s %s" % [t("Bonuses applied:"), t("none yet")])
	else:
		tip.points(t("Bonuses applied:"), done)
	var can := PackedStringArray()
	for def: TechDef in techs["researching"]:
		can.append(_tech_line(def) + " — " + t("being researched"))
	for def: TechDef in techs["open"]:
		can.append(_tech_line(def) + " — " + _how(eco, state, def))
	if can.is_empty():
		tip.text("%s %s" % [t("Bonuses to research:"), t("none left")])
	else:
		tip.points(t("Bonuses to research:"), can)
	return tip


static func _food_part(i: int) -> String:
	match i:
		0:
			return t("fields %d")
		1:
			return t("hunting %d")
	return t("hives %d")


static func _tech_line(def: TechDef) -> String:
	return "%s: %s" % [UiText.name_of(def.id), Tips.tech_effect(def.id)]


## "building: Granary, age: Хоругвь".
static func _how(eco: EconomySystem, state: PlayerState, def: TechDef) -> String:
	var at := where(eco, state.faction, def)
	var out := t("building: %s") % at if not at.is_empty() else ""
	if def.age > state.age:
		var age := eco.db.age_by_index(def.age)
		if age != null:
			var from := t("age: %s") % UiText.name_of(age.id)
			out = from if out.is_empty() else out + ", " + from
	return out
