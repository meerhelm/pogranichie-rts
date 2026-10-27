class_name HelpPanel
extends Control
## «How to play»: what a new player needs for a skirmish (selecting, gathering, the first
## buildings, training, the next age, Power, winning) and the keys, on one scrolling page.
## Opened from the main menu, the game menu and with F1 in the game; Esc, F1 or the button
## close it. Runs while the tree is paused; in the game it pauses the game while open.

signal closed

const SCENE := "res://ui/help_panel.tscn"

## Whether opening paused the tree (so closing resumes it).
var _paused_it := false

@onready var _title: Label = %Title
@onready var _text: RichTextLabel = %Text
@onready var _close: Button = %Close


## A new window (the scene, laid out in help_panel.tscn).
static func create() -> HelpPanel:
	return (load(SCENE) as PackedScene).instantiate()


func _ready() -> void:
	_close.pressed.connect(close)
	_retranslate()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_retranslate()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not visible or key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode in [KEY_ESCAPE, KEY_F1, KEY_F10]:
		close()
		get_viewport().set_input_as_handled()


## Shows the page; with pause_game the game stops until it is closed.
func open(pause_game: bool = false) -> void:
	_retranslate()
	_text.scroll_to_line(0)
	visible = true
	UiAnim.pop_in(self, %Panel)
	_paused_it = pause_game and not get_tree().paused
	if _paused_it:
		get_tree().paused = true
	_close.grab_focus.call_deferred()


func close() -> void:
	visible = false
	if _paused_it:
		get_tree().paused = false
		_paused_it = false
	closed.emit()


func _retranslate() -> void:
	_title.text = tr("How to play")
	_close.text = tr("Close (F1)")
	_text.text = page()


## The page as BBCode, in the current language.
func page() -> String:
	var n := {
		center = UiText.name_of(&"gdl_town_center"),
		house = UiText.name_of(&"gdl_house"),
		farm = UiText.name_of(&"gdl_farm"),
		bort = UiText.name_of(&"gdl_bort"),
		lumber = UiText.name_of(&"gdl_lumber_yard"),
		granary = UiText.name_of(&"gdl_granary"),
		mine = UiText.name_of(&"gdl_mine"),
		barracks = UiText.name_of(&"gdl_barracks"),
		range = UiText.name_of(&"gdl_range"),
		stable = UiText.name_of(&"gdl_stable"),
		shrine = UiText.name_of(&"gdl_shrine"),
		caster = UiText.name_of(&"gdl_znakharka"),
		age = UiText.name_of(&"age_khorugv"),
		enemy = UiText.name_of(&"to_town_center"),
	}
	var rules := load("res://data/rules/economy.tres") as EconomyRulesDef
	var refund := rules.dismantle_refund_permille / 10 if rules != null else 0
	var sections: Array[Array] = [
		[
			tr("Goal"),
			[
				tr("You lead Lithuania from the north-west; the Order is in the south-east."),
				tr("Destroy the enemy's capital («%s») and castles to win.") % n.enemy,
				tr("Or hold every place of power on the map for 5 minutes."),
			],
		],
		[
			tr("Select and order"),
			[
				tr("Left click selects; drag a box to select several."),
				tr("Double click selects all units of that type on screen."),
				tr("Right click orders: walk, attack the enemy, or work on what you click."),
				tr("Ctrl+1…9 makes a group, 1…9 selects it."),
				tr(
					". or the idle worker button in the top bar finds a peasant with nothing to do."
				),
				tr("W A S D, the arrows or the screen edge move the view."),
			],
		],
		[
			tr("Resources"),
			[
				tr("Select peasants and right-click what they should gather."),
				tr("Forest gives wood."),
				tr("Bog ore (brown blocks in the bog) gives iron."),
				tr("A silver mine (grey blocks on a hill) gives silver."),
				(
					tr("Food: build «%s» right by the forest, then right-click it with a peasant.")
					% n.farm
				),
				tr("«%s» (a hive) stands in the forest; two peasants gather food there.") % n.bort,
				tr("Peasants carry everything to «%s» or to a nearer store.") % n.center,
				(
					tr("«%s» takes wood, «%s» food, «%s» iron and silver.")
					% [n.lumber, n.granary, n.mine]
				),
			],
		],
		[
			tr("First steps"),
			[
				tr("1. You start with «%s», 5 peasants and room for 5 people only.") % n.center,
				tr("2. Send peasants to the forest, then build «%s»: +5 population.") % n.house,
				tr("3. Build «%s» by the forest and put a peasant on it.") % n.farm,
				tr("4. Click «%s» and train more peasants (50 food each).") % n.center,
				(
					tr("5. Build «%s», «%s» or «%s» and train an army.")
					% [n.barracks, n.range, n.stable]
				),
			],
		],
		[
			tr("Building and training"),
			[
				tr("With peasants selected, the buttons at the bottom right are buildings."),
				tr("Pick one and left-click the ground; F turns it, Shift lays several."),
				tr("Green means it can stand there; the line at the top says why red cannot."),
				tr("Click your building to train units; Z X C V B N M press its buttons."),
				tr("Right click with a building selected sets where its units gather."),
				tr("Hover a button to see its price and why it is not available."),
				tr("Y with peasants, then a click on your building: they take it apart."),
				tr("%d%% of its price is left in heaps; peasants carry it to the stores.") % refund,
				tr("Left click on anything else (enemy, deposit, forest) shows it below."),
			],
		],
		[
			tr("Ages"),
			[
				tr("«%s» leads to the next age, «%s», for 500 food.") % [n.center, n.age],
				tr("It needs two other first-age buildings and opens new units."),
			],
		],
		[
			tr("Power and spells"),
			[
				tr("«%s» stands only on a place of power and gives Power.") % n.shrine,
				tr("«%s», trained there, casts spells for Power.") % n.caster,
			],
		],
		[
			tr("Army"),
			[
				tr("Q E R: line, column, wedge."),
				tr("Z X C: aggressive, defensive, stand ground. H: stop."),
				tr("Ctrl+right click: attack-move. Alt+right click: set a building on fire."),
				tr("Lithuanian troops can feign a retreat (T) and turn around (G)."),
			],
		],
		[
			tr("Game"),
			[
				tr("P pauses, Esc or F10 opens the menu, F1 shows this page."),
				tr("The hints at the top left can be turned off in the settings."),
			],
		],
	]
	var out := PackedStringArray()
	var head := get_theme_default_font_size() + 6
	for section: Array in sections:
		out.append("[font_size=%d][b]%s[/b][/font_size]" % [head, section[0]])
		for line: String in section[1]:
			out.append(line)
		out.append("")
	return "\n".join(out)
