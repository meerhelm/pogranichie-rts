class_name Tips
extends RefCounted
## Tooltips of the HUD order buttons: what a building is for and what it gives, what a unit
## does, what a tech, an age or a spell brings, and what an order does. Each comes twice, as
## BBCode for the rich tooltip (IconButton) with icons and the price in resource icons, and as
## plain text for tooltip_text. Numbers come from the catalog defs; the prose is per id here.

const HEAD := "#6b3f12"
const MUTED := "#5a4a35"
const BAD := "#9a1a10"
const GOOD := "#2f5a14"
const ICON_SIZE := 64
const SMALL := 18


## The text in the current language (UiText.t).
static func t(text: String) -> String:
	return TranslationServer.translate(text)


## One tooltip in both forms.
class Tip:
	extends RefCounted
	var rich := PackedStringArray()
	var plain := PackedStringArray()

	## Picture, name and hotkey, and under them the price and the time it takes.
	func header(
		icon_path: String, name: String, key: String, cost_rich: String, cost_plain: String
	) -> void:
		var title := "[font_size=22][b]%s[/b][/font_size]" % name
		if not key.is_empty():
			title += "  [color=%s](%s)[/color]" % [MUTED, key]
		var right := title + ("\n" + cost_rich if not cost_rich.is_empty() else "")
		if icon_path.is_empty():
			rich.append(right)
		else:
			(
				rich
				. append(
					(
						"[table=2][cell][img=%dx%d]%s[/img][/cell][cell padding=10,0,0,0]%s[/cell][/table]"  # notr
						% [ICON_SIZE, ICON_SIZE, icon_path, right]
					)
				)
			)
		plain.append(name + (" (%s)" % key if not key.is_empty() else ""))
		if not cost_plain.is_empty():
			plain.append(cost_plain)

	func text(line: String, color := "") -> void:
		if line.is_empty():
			return
		rich.append("[color=%s]%s[/color]" % [color, line] if not color.is_empty() else line)
		plain.append(line)

	## A heading and its points as a bulleted list.
	func points(heading: String, lines: PackedStringArray) -> void:
		if lines.is_empty():
			return
		var out := "[color=%s][b]%s[/b][/color]" % [HEAD, heading]
		for l in lines:
			out += "\n  • " + l
		rich.append(out)
		plain.append(heading + "\n" + "\n".join(lines))

	func bbcode() -> String:
		return "\n".join(rich)

	func plain_text() -> String:
		return "\n".join(plain)


## A tooltip label for a rich tip `bbcode`, `width` wide (dark text on the parchment panel).
static func make_label(bbcode: String, width: float) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	label.add_theme_color_override("default_color", IconButton.TIP_TEXT)
	label.add_theme_constant_override("table_h_separation", 0)
	label.text = bbcode
	return label


## "[food] 50  [wood] 100  [time] 25 s" with icons, and the plain "50 food, 100 wood".
static func price(c: PackedInt32Array, seconds: int, power := 0) -> Array[String]:
	var rich := PackedStringArray()
	for r in 4:
		if c[r] > 0:
			rich.append("[img=%d]%s[/img] %d" % [SMALL, IconDB.small(r), c[r]])  # notr
	if power > 0:
		rich.append("[img=%d]%s[/img] %d" % [SMALL, IconDB.small(-1), power])  # notr
	if rich.is_empty():
		rich.append(t("free"))
	if seconds > 0:
		rich.append("[img=%d]%s[/img] %s" % [SMALL, IconDB.small("time"), t("%d s") % seconds])  # notr
	var plain := UiText.cost(c)
	if power > 0:
		plain += ", " + t("%d Power") % power
	if seconds > 0:
		plain += " · " + t("%d s") % seconds
	return ["   ".join(rich), plain]


static func _seconds(ticks: int) -> int:
	return ceili(ticks / float(Fixed.TICKS_PER_SECOND))


static func _fail(tip: Tip, reason: String) -> void:
	tip.text(reason, BAD)


# --- buildings -------------------------------------------------------------------------------


## A building's button: price and build time, what it is for, what it gives, its strength,
## where it may stand and, if it cannot be had now, why.
static func building(def: BuildingDef, eco: EconomySystem, p: int, fail := "", key := "") -> Tip:
	var tip := Tip.new()
	var cost := price(eco.placement.building_cost(p, def), _seconds(def.build_ticks))
	tip.header(IconDB.path_of(def.id), UiText.name_of(def.id), key, cost[0], cost[1])
	if def.cost_per_tile:
		tip.text(t("The price is for each cell of the line."), MUTED)
	tip.text(purpose(def))
	tip.points(t("Gives"), gives(def, eco.db))
	tip.text(
		t("HP %d · armor %d melee / %d pierce") % [def.hp, def.armor_melee, def.armor_pierce], MUTED
	)
	tip.points(t("Where it stands"), placement(def))
	_fail(tip, fail)
	return tip


## Why to build it, in a sentence or two.
static func purpose(def: BuildingDef) -> String:
	match def.id:
		&"gdl_bort":
			return t(
				# gdlint:ignore = max-line-length
				"A hive hollowed out in a forest tree. Two peasants take honey from it: food that never runs out."
			)
		&"gdl_zaseka":
			return t(
				"A barrier of felled trees laid in the forest. Nobody passes it; fire burns it away."
			)
		&"to_brickworks":
			return t("Brickworks: while one stands, your towers, walls and castles cost less.")
		&"gdl_shrine":
			return t(
				# gdlint:ignore = max-line-length
				"An alka, a pagan sanctuary. It gathers Power for spells and trains wise women; near it their spells recharge faster."
			)
		&"to_shrine":
			return t(
				# gdlint:ignore = max-line-length
				"A chapel of the Order. It gathers Power for spells and consecrates the land: shrines of other sides near it give half the Power."
			)
	match def.base_id:
		&"town_center":
			return t(
				# gdlint:ignore = max-line-length
				"The heart of your land: trains peasants, takes in every resource and leads your people into the next age. In a skirmish, a side that loses every town centre and castle is out."
			)
		&"house":
			return t(
				# gdlint:ignore = max-line-length
				"Homes for your people. Every unit takes room: when the population is full, nothing more can be trained until you build houses."
			)
		&"farm":
			return t(
				# gdlint:ignore = max-line-length
				"A field. A peasant working it brings in food; when it is worked out, it is sown again for its price."
			)
		&"granary":
			return t(
				# gdlint:ignore = max-line-length
				"A store for food near the fields: peasants carry the harvest a shorter way. Researches farming improvements."
			)
		&"lumber_yard":
			return t(
				# gdlint:ignore = max-line-length
				"A store at the forest edge: woodcutters carry wood a shorter way. Researches forestry improvements."
			)
		&"mine":
			return t(
				# gdlint:ignore = max-line-length
				"A store by bog ore or a silver mine: miners carry a shorter way. Researches mining improvements."
			)
		&"barracks":
			return t("Trains foot soldiers.")
		&"range":
			return t("Trains archers and crossbowmen.")
		&"stable":
			return t("Trains horsemen.")
		&"siege_workshop":
			return t("Builds wagons and siege engines.")
		&"palisade":
			return t(
				# gdlint:ignore = max-line-length
				"A wall of sharpened stakes: drag to lay a line. Holds enemies off until they break through; it burns."
			)
		&"gate":
			return t("A gate in your wall: your own people pass, enemies have to break it down.")
		&"tower":
			return t(
				"A tower that shoots arrows at enemies in range. Palisades and walls join onto it."
			)
		&"market":
			return t("A trading house. Trade is not in this version yet.")
		&"smithy":
			return t("A smithy: researches better weapons and armor for your troops.")
		&"temple":
			return t("A church: trains priests and researches the faith's improvements.")
		&"castle":
			return t(
				# gdlint:ignore = max-line-length
				"A castle, the stronghold of the land: trains the best troops and houses many people. Like a town centre, it keeps your side in the game."
			)
	return ""


## What a finished building gives: population, storage, troops, research, Power, shots.
static func gives(def: BuildingDef, db: CatalogDB) -> PackedStringArray:
	var lines := PackedStringArray()
	if def.pop_provided > 0:
		lines.append(t("+%d population") % def.pop_provided)
	if def.base_id == &"farm":
		lines.append(t("%d food per sowing") % def.param(&"food_capacity"))
	if def.base_id == EconomySystem.TOWN_CENTER:
		lines.append(t("Peasants bring here every resource"))
	elif not def.accepts.is_empty():
		var names := PackedStringArray()
		for res: StringName in def.accepts:
			names.append(UiText.resource(EconomySystem.RESOURCE_NAMES.find(res)).to_lower())
		lines.append(t("Peasants bring here: %s") % ", ".join(names))
	var trains := PackedStringArray()
	for id: StringName in def.trains:
		var unit := db.unit(id)
		if unit != null and unit.faction == def.faction and not unit.campaign_only:
			trains.append(UiText.name_of(id))
	if not trains.is_empty():
		lines.append(t("Trains: %s") % ", ".join(trains))
	var techs := PackedStringArray()
	var faction := db.faction(def.faction)
	for id: StringName in db.techs:
		var t: TechDef = db.techs[id]
		var here := t.building == def.id or t.building == def.base_id
		if here and faction != null and faction.tech_ids.has(id) and not t.effects.is_empty():
			techs.append(UiText.name_of(id))
	if not techs.is_empty():
		lines.append(t("Researches: %s") % ", ".join(techs))
	if def.base_id == EconomySystem.TOWN_CENTER:
		lines.append(t("Advance to the next age"))
	if def.power_rate_milli > 0:
		lines.append(t("%s Power a second on a place of power") % _decimal(def.power_rate_milli))
	if def.damage > 0:
		lines.append(
			(
				t("Shoots: %d damage (%s), range %d")
				% [def.damage, UiText.damage_type(def.damage_type), def.attack_range]
			)
		)
	if def.tags.has(&"brickworks"):
		lines.append(t("Cheaper towers, walls and castles"))
	if def.tags.has(&"spell_recharge"):
		lines.append(t("Spells of wise women nearby recharge faster"))
	if lines.is_empty() and def.base_id in [&"barracks", &"range", &"stable", &"siege_workshop"]:
		lines.append(t("Nothing to train here yet in this version"))
	return lines


## Where it may stand and how it behaves on the map (catalog tags).
static func placement(def: BuildingDef) -> PackedStringArray:
	var lines := PackedStringArray()
	if def.tags.has(&"power_place_only"):
		lines.append(t("Only on a place of power"))
	if def.tags.has(&"in_forest"):
		lines.append(t("Only in the forest"))
	if def.tags.has(&"near_forest_only"):
		lines.append(t("Only next to the forest"))
	if def.tags.has(&"walkable"):
		lines.append(t("Units walk over it"))
	if BuildingPlacement.REPLACING.has(def.base_id):
		lines.append(t("Can be put into your own palisade or wall"))
	if def.tags.has(&"fireproof"):
		lines.append(t("Does not burn"))
	var w := def.param(&"size_w", 1)
	var h := def.param(&"size_h", 1)
	lines.append(t("Size %d×%d cells") % [w, h])
	return lines


static func _decimal(milli: int) -> String:
	return ("%.1f" % (milli / 1000.0)).trim_suffix(".0")


# --- units -----------------------------------------------------------------------------------


## A unit's train button: price, time, room, what it does, its numbers and abilities.
static func unit(def: UnitDef, cost: PackedInt32Array, ticks: int, fail := "", key := "") -> Tip:
	var tip := Tip.new()
	var p := price(cost, _seconds(ticks), def.cost_power)
	tip.header(IconDB.path_of(def.id), UiText.name_of(def.id), key, p[0], p[1])
	tip.text(role(def))
	var stats := PackedStringArray()
	stats.append(t("HP %d") % def.hp)
	if def.damage > 0:
		var attack := t("Damage %d (%s)") % [def.damage, UiText.damage_type(def.damage_type)]
		if def.attack_range > 0:
			attack += ", " + t("range %d") % def.attack_range
		stats.append(attack)
	stats.append(t("Armor %d melee / %d pierce") % [def.armor_melee, def.armor_pierce])
	stats.append(t("Speed %.2f cells/s") % (def.speed_milli / 1000.0))
	tip.text(" · ".join(stats), MUTED)
	tip.points(t("Abilities"), abilities(def))
	if def.pop > 1:
		tip.text(t("Takes %d population") % def.pop, MUTED)
	_fail(tip, fail)
	return tip


## What the unit is for, in a sentence.
static func role(def: UnitDef) -> String:
	match def.id:
		&"gdl_peasant", &"to_peasant":
			return t("Gathers food, wood, iron and silver, builds and repairs.")
		&"gdl_camp_servant":
			return t("Builds and repairs, but gathers nothing.")
		&"gdl_spearman":
			return t("Cheap foot militia with boar spears, good against horsemen.")
		&"to_knecht":
			return t("Foot spearman of the Order, good against horsemen.")
		&"gdl_forest_archer":
			return t("An archer at home in the forest.")
		&"gdl_castle_archer":
			return t("A sturdy archer of the castle garrisons.")
		&"to_crossbow":
			return t("A crossbowman: slow to load, hits hard.")
		&"gdl_light_horse":
			return t("A fast light horseman with javelins.")
		&"gdl_lit_lance":
			return t("A heavy Lithuanian lancer.")
		&"to_prussian_rider":
			return t("A light horseman from the Prussian lands.")
		&"to_halfbrother":
			return t("A half-brother in a grey cloak: the Order's medium horse.")
		&"to_knight_brother":
			return t("A knight brother in a white cloak: the Order's heavy horse.")
		&"gdl_znakharka":
			return t("A wise woman: heals those around her and casts the Duchy's spells.")
		&"to_priest":
			return t("A brother priest: consecrates the land and casts the Order's spells.")
		&"gdl_wagon":
			return t("A wagon of the baggage train.")
	if def.has_class(&"peasant"):
		return t("Gathers resources and builds.")
	return ""


## Bonuses and special rules of a unit, from its catalog classes, tags and parameters.
static func abilities(def: UnitDef) -> PackedStringArray:
	var lines := PackedStringArray()
	for cls: StringName in def.bonuses:
		lines.append(t("+%d damage against %s") % [def.bonuses[cls], class_name_of(cls)])
	if def.tags.has(&"charge"):
		lines.append(
			(
				t("Charge: ×%s damage after a run-up of %d cells")
				% [_decimal(def.param(&"charge_permille")), def.param(&"charge_distance")]
			)
		)
	if def.tags.has(&"javelin"):
		lines.append(
			(
				t("Javelin: %d damage at %d cells, every %d s")
				% [
					def.param(&"javelin_damage"),
					def.param(&"javelin_range"),
					_seconds(def.param(&"javelin_cooldown_ticks"))
				]
			)
		)
	if def.tags.has(&"lithuanian_retreat"):
		lines.append(t("Lithuanian retreat: flees, then turns on the chasers (T)"))
	if def.tags.has(&"forest_stealth"):
		lines.append(t("Unseen in the forest until it shoots"))
	if def.param(&"forest_range_bonus") > 0:
		lines.append(t("+%d range shooting from the forest") % def.param(&"forest_range_bonus"))
	if def.tags.has(&"can_dismount"):
		lines.append(t("Can dismount to fight on foot (V)"))
	if def.tags.has(&"no_pursuit"):
		lines.append(t("Does not chase fleeing enemies"))
	if def.param(&"heal_hp_per_s") > 0:
		lines.append(
			(
				t("Heals %d HP a second to her people within %d cells")
				% [def.param(&"heal_hp_per_s"), def.param(&"heal_radius")]
			)
		)
	if def.never_flees:
		lines.append(t("Never flees"))
	if def.param(&"limit") > 0:
		lines.append(t("At most %d at a time") % def.param(&"limit"))
	if def.param(&"limit_per_castle") > 0:
		lines.append(t("At most %d for each castle") % def.param(&"limit_per_castle"))
	return lines


## A unit class as the player reads it ("against cavalry").
static func class_name_of(cls: StringName) -> String:
	match cls:
		&"cavalry":
			return t("cavalry")
		&"heavy_cavalry":
			return t("heavy cavalry")
		&"light_cavalry":
			return t("light cavalry")
		&"infantry":
			return t("infantry")
		&"spearman":
			return t("spearmen")
		&"archer":
			return t("archers")
		&"creature":
			return t("creatures")
		&"siege":
			return t("siege engines")
	return String(cls)


# --- techs, ages, spells, orders -------------------------------------------------------------


static func tech(def: TechDef, cost: PackedInt32Array, ticks: int, fail := "", key := "") -> Tip:
	var tip := Tip.new()
	var p := price(cost, _seconds(ticks))
	tip.header(IconDB.path_of(def.id), UiText.name_of(def.id), key, p[0], p[1])
	tip.text(tech_effect(def.id), GOOD)
	tip.text(t("Researched once, works for all your people."), MUTED)
	_fail(tip, fail)
	return tip


## What a tech does (the catalog's «Эффект», as the game does it).
static func tech_effect(id: StringName) -> String:
	match id:
		&"t_watch":
			return t("Towers, walls and gates see 2 cells farther.")
		&"t_horse_collar":
			return t("Fields give food faster: +15%.")
		&"t_three_field":
			return t("Each field holds more food: +50%.")
		&"t_gdl_forest":
			return t("Food comes faster: honey from hives +40%, hunting and fields +25%.")
		&"t_saw":
			return t("Woodcutters work faster: +20%.")
		&"t_gdl_zaseka":
			return t("Zasekas are felled twice as fast and have +50% HP.")
		&"t_bloomery":
			return t("Iron is mined faster: +20%.")
		&"t_assay":
			return t("Silver is mined faster: +20%.")
		&"t_gdl_herbs":
			return t("Wise women heal 2 HP a second instead of 1.")
		&"t_arrows":
			return t("Archers: +1 pierce damage and +1 range.")
		&"t_cav_armor_1":
			return t("Horsemen: +1 melee and +1 pierce armor.")
		&"t_inf_armor_1":
			return t("Foot soldiers: +1 melee and +1 pierce armor.")
		&"t_weapons_1":
			return t("Foot soldiers and horsemen: +1 melee damage.")
		&"t_to_great_stud":
			return t("Heavy horse: +10% HP.")
		&"t_to_reliquary":
			return t("Brother priests: +50% HP; Exorcism reaches 2 cells farther.")
	return ""


static func age(
	def: AgeDef,
	db: CatalogDB,
	faction: StringName,
	cost: PackedInt32Array,
	ticks: int,
	fail := "",
	key := ""
) -> Tip:
	var tip := Tip.new()
	var p := price(cost, _seconds(ticks))
	var title := t("Advance to: %s") % UiText.name_of(def.id)
	tip.header(IconDB.path_of(def.id), title, key, p[0], p[1])
	tip.text(t("A new age opens new buildings, troops and improvements."))
	var opens := PackedStringArray()
	for id: StringName in db.buildings:
		var b: BuildingDef = db.buildings[id]
		if b.faction == faction and b.age == def.index and not b.campaign_only:
			opens.append(UiText.name_of(id))
	tip.points(t("New buildings"), opens)
	var need := def.params.get(&"required_buildings", 0) as int
	if need > 0:
		tip.text(t("Needs %d finished buildings of the age before.") % need, MUTED)
	_fail(tip, fail)
	return tip


static func spell(def: SpellDef, fail := "") -> Tip:
	var tip := Tip.new()
	var p := price(PackedInt32Array([0, 0, 0, 0]), 0, def.power_cost)
	tip.header(IconDB.path_of(def.id), UiText.name_of(def.id), "", p[0], p[1])
	match def.id:
		&"sp_bog_mist":
			(
				tip
				. text(
					t(
						# gdlint:ignore = max-line-length
						"Mist over the bog: your people and buildings in it are hidden from the enemy farther than 2 cells."
					)
				)
			)
		&"sp_exorcism":
			tip.text(t("Breaks other sides' spells; a creature loses 150 HP and falls back."))
		&"sp_relic":
			(
				tip
				. text(
					t(
						# gdlint:ignore = max-line-length
						"Your men near the relic do not flee while their morale is above 10; enemies nearby lose 10 morale."
					)
				)
			)
	var facts := PackedStringArray()
	if def.radius > 0:
		facts.append(t("radius %d") % def.radius)
	if def.duration_ticks > 0:
		facts.append(t("lasts %d s") % _seconds(def.duration_ticks))
	facts.append(t("Cooldown %d s") % _seconds(def.cooldown_ticks))
	tip.text(" · ".join(facts), MUTED)
	_fail(tip, fail)
	return tip


## An order button: its name, key and what it does.
static func order(icon: String, name: String, key: String, what: String) -> Tip:
	var tip := Tip.new()
	var path := IconDB.ROOT.path_join("orders/%s.svg" % icon)
	tip.header(path, name, key, "", "")
	tip.text(what)
	return tip
