class_name Advisor
extends PanelContainer
## Step-by-step hints for a new player in a skirmish, at the top left under the top bar: one
## step at a time (select peasants, cut wood, build a house, a farm, train peasants, mine, an
## army, a shrine, then how to win), each done once the player has done it, and the next one
## shown. Steps the player already did on their own are skipped. «Next» skips a step, «Hide»
## turns the hints off (also in the settings). Reads the simulation only; nothing here is
## part of the game state, so it never touches a replay.

const STEPS := [
	&"select", &"wood", &"house", &"farm", &"peasants", &"iron", &"army", &"shrine", &"win"
]

var sim: Simulation
var input: PlayerInput
var player := 1
## Index in STEPS of the hint shown; STEPS.size() when all are done or skipped.
var step := 0

var _title := Label.new()
var _text := Label.new()
var _next := Button.new()
var _hide := Button.new()
## Peasants the player had at the start, to see when more were trained.
var _start_peasants := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	position = Vector2(12, 64)
	custom_minimum_size = Vector2(520, 0)
	var box := VBoxContainer.new()
	add_child(box)
	_title.theme_type_variation = &"Title"
	box.add_child(_title)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(500, 0)
	box.add_child(_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(row)
	for b: Button in [_next, _hide]:
		b.focus_mode = Control.FOCUS_NONE
		row.add_child(b)
	_next.pressed.connect(func() -> void: _advance(step + 1))
	_hide.pressed.connect(_on_hide)


func attach(p_sim: Simulation, p_input: PlayerInput, p_player: int) -> void:
	sim = p_sim
	input = p_input
	player = p_player
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()


## Checks what the player has done and shows the current hint (called by the HUD after ticks).
func refresh() -> void:
	if sim == null:
		return
	var state := sim.economy.player(player)
	if state == null or not GameSettings.hints or sim.mission != null:
		visible = false
		return
	if _start_peasants < 0:
		_start_peasants = _count_peasants()
	var i := step
	while i < STEPS.size() - 1 and is_done(STEPS[i]):
		i += 1
	if i != step:
		_advance(i)
		return
	visible = step < STEPS.size()
	if not visible:
		return
	_title.text = tr("Hint %d of %d") % [step + 1, STEPS.size()]
	_text.text = hint(STEPS[step])
	_next.text = tr("Next") if step < STEPS.size() - 1 else tr("Got it")
	_hide.text = tr("Hide hints")


func _advance(to: int) -> void:
	step = to
	refresh()


func _on_hide() -> void:
	GameSettings.hints = false
	GameSettings.save()
	visible = false


## Whether the player has done what the step asks.
func is_done(id: StringName) -> bool:
	var state := sim.economy.player(player)
	var done := false
	match id:
		&"select":
			done = not input.peasants().is_empty() or _gathering(-1)
		&"wood":
			done = _gathering(EconomySystem.WOOD)
		&"house":
			done = _has_building(&"house")
		&"farm":
			done = _has_building(&"farm") or _has_building(&"bort")
		&"peasants":
			done = _count_peasants() > _start_peasants
		&"iron":
			done = state.stock[EconomySystem.IRON] > 150 or _gathering(EconomySystem.IRON)
		&"army":
			done = _has_building(&"barracks") or _has_building(&"range")
			done = done or _has_building(&"stable")
		&"shrine":
			done = _has_building(&"shrine")
	return done


## The step's text in the current language, with the faction's own building names.
func hint(id: StringName) -> String:
	var faction := sim.economy.player(player).faction
	var text := ""
	match id:
		&"select":
			text = tr(
				"Select your peasants: hold the left mouse button and drag a box around them."
			)
		&"wood":
			text = tr(
				"Right-click the forest with peasants selected: they cut wood and carry it home."
			)
		&"house":
			text = tr(
				"Population is full. With a peasant selected, build «%s» (button bottom right)."
			)
			text = text % _name(&"house", faction)
		&"farm":
			text = tr("Food: build «%s» right by the forest, then right-click it with a peasant.")
			text = text % _name(&"farm", faction)
		&"peasants":
			text = tr("Click «%s» and train more peasants: the more workers, the faster you grow.")
			text = text % _name(&"town_center", faction)
		&"iron":
			text = tr("Iron: right-click bog ore (brown blocks in the bog) with peasants.")
		&"army":
			text = tr("Build «%s», «%s» or «%s» and train an army. The Order will come.")
			var names := [&"barracks", &"range", &"stable"].map(_name.bind(faction))
			text = text % names
		&"shrine":
			text = tr("Build «%s» on a place of power: it gives Power for spells.")
			text = text % _name(&"shrine", faction)
		_:
			text = tr(
				"To win, destroy the enemy's capital, or hold every place of power for 5 minutes."
			)
			text += " " + tr("F1: how to play.")
	return text


func _name(base: StringName, faction: StringName) -> String:
	return UiText.name_of(StringName("%s_%s" % [faction, base]))


func _has_building(base: StringName) -> bool:
	var store := sim.economy.buildings
	for s in store.defs.size():
		var def := store.defs[s]
		if def != null and store.owners[s] == player and def.base_id == base:
			if store.is_alive(s + 1):
				return true
	return false


func _count_peasants() -> int:
	var n := 0
	var eco := sim.economy
	for id in sim.entities.alive_ids:
		var def := eco.unit_defs[id - 1] if id - 1 < eco.unit_defs.size() else null
		if def != null and def.has_class(&"peasant") and sim.entities.owners[id - 1] == player:
			n += 1
	return n


## Whether one of the player's peasants is gathering that resource (-1: any).
func _gathering(res: int) -> bool:
	var eco := sim.economy
	for id in sim.entities.alive_ids:
		var slot := id - 1
		if slot >= eco.job.size() or sim.entities.owners[slot] != player:
			continue
		if eco.job[slot] != EconomySystem.Job.GATHER:
			continue
		if res < 0 or ResourceNodes.SOURCE_RESOURCE[eco.job_source[slot]] == res:
			return true
	return false
