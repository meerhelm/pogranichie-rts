class_name NetLobby
extends VBoxContainer
## The main menu's «Network play» page: one player creates a game (picking the map and both
## sides' factions) and waits; the other types the host's address and joins. Once the two games
## have shaken hands (NetSession), `start` asks the menu to open the game scene. The address may
## carry a port («192.168.1.5:24610»); without it EnetTransport.DEFAULT_PORT. Back cancels.

## Both games agreed; the game scene can open.
signal start
signal back

const BUTTON_SIZE := Vector2(340, 50)
const HEAD_COLOR := Color(0.93, 0.84, 0.66)
const NOTE_COLOR := Color(0.85, 0.72, 0.45)
const ERROR_COLOR := Color(0.95, 0.55, 0.45)

var head := Label.new()
var map := OptionButton.new()
var mine := OptionButton.new()
var theirs := OptionButton.new()
var create := Button.new()
var join_note := Label.new()
var address := LineEdit.new()
var join := Button.new()
var status := Label.new()
var back_button := Button.new()

## Makes the status line's text (empty: no line), so it follows the language.
var _status := Callable()
var _status_error := false


func _init() -> void:
	name = "Net"  # notr
	add_theme_constant_override("separation", 12)
	head.add_theme_color_override("font_color", HEAD_COLOR)
	head.add_theme_font_size_override("font_size", 28)
	add_child(head)
	for box: OptionButton in [map, mine, theirs]:
		box.custom_minimum_size = BUTTON_SIZE
		add_child(box)
	for m: Dictionary in SkirmishMaps.all():
		map.add_item(str(m["id"]))
	for box: OptionButton in [mine, theirs]:
		for f in SkirmishSetup.FACTIONS:
			box.add_item(String(f))
	create.custom_minimum_size = BUTTON_SIZE
	add_child(create)
	join_note.add_theme_color_override("font_color", NOTE_COLOR)
	add_child(join_note)
	address.custom_minimum_size = BUTTON_SIZE
	add_child(address)
	join.custom_minimum_size = BUTTON_SIZE
	add_child(join)
	status.custom_minimum_size = Vector2(460, 0)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	back_button.custom_minimum_size = BUTTON_SIZE
	add_child(back_button)
	map.item_selected.connect(_on_map)
	mine.item_selected.connect(_on_faction.bind(true))
	theirs.item_selected.connect(_on_faction.bind(false))
	create.pressed.connect(_on_create)
	join.pressed.connect(_on_join)
	address.text_submitted.connect(func(_t: String) -> void: _on_join())
	back_button.pressed.connect(_on_back)


func _ready() -> void:
	retranslate()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		retranslate()


## Shows the page as the settings stand; any old network game is closed.
func open() -> void:
	NetSession.close_current()
	map.selected = maxi(SkirmishMaps.ids().find(GameSettings.skirmish_map), 0)
	mine.selected = maxi(SkirmishSetup.FACTIONS.find(GameSettings.player_faction), 0)
	theirs.selected = maxi(SkirmishSetup.FACTIONS.find(GameSettings.enemy_faction), 0)
	address.text = GameSettings.net_address
	_set_status(Callable())
	_busy(false)
	create.grab_focus.call_deferred()


func retranslate() -> void:
	head.text = tr("Network play")
	for i in mini(SkirmishSetup.FACTIONS.size(), mine.item_count):
		var faction := UiText.name_of(SkirmishSetup.FACTIONS[i])
		mine.set_item_text(i, tr("You play: %s") % faction)
		theirs.set_item_text(i, tr("Opponent plays: %s") % faction)
	var maps := SkirmishMaps.all()
	for i in mini(maps.size(), map.item_count):
		map.set_item_text(i, tr("Map: %s") % tr(str((maps[i] as Dictionary)["title"])))
	create.text = tr("Create a game")
	join_note.text = tr("Or join a game: the host's address")
	address.placeholder_text = tr("such as 192.168.1.5")
	join.text = tr("Join a game")
	back_button.text = tr("Back")
	_show_status()


## Esc on this page: cancels the wait, then goes back.
func cancel() -> void:
	_on_back()


func _on_map(index: int) -> void:
	GameSettings.skirmish_map = SkirmishMaps.ids()[index]
	GameSettings.save()


func _on_faction(index: int, own: bool) -> void:
	if own:
		GameSettings.player_faction = SkirmishSetup.FACTIONS[index]
	else:
		GameSettings.enemy_faction = SkirmishSetup.FACTIONS[index]
	GameSettings.save()


func _on_create() -> void:
	var t := EnetTransport.new()
	var err := t.host(EnetTransport.DEFAULT_PORT)
	if err != OK:
		var why := error_string(err)
		_set_status(
			func() -> String:
				return (
					tr("Cannot wait for players on port %d: %s") % [EnetTransport.DEFAULT_PORT, why]
				),
			true
		)
		return
	var s := _open_session(t)
	var factions: Array[StringName] = [GameSettings.player_faction, GameSettings.enemy_faction]
	s.host_game(GameSettings.skirmish_map, factions, Lockstep.DEFAULT_DELAY)
	var mine := t.describe()
	_set_status(
		func() -> String: return tr("Waiting for the other player. Your address: %s") % mine
	)
	_busy(true)


func _on_join() -> void:
	var where := address.text.strip_edges()
	if where.is_empty():
		_set_status(func() -> String: return tr("Type the host's address"), true)
		return
	var host := where
	var port := EnetTransport.DEFAULT_PORT
	var colon := where.rfind(":")
	if colon > 0 and where.count(":") == 1:
		host = where.left(colon)
		port = int(where.substr(colon + 1))
		if port <= 0 or port > 65535:
			_set_status(
				func() -> String: return tr("The port after «:» must be a number from 1 to 65535"),
				true
			)
			return
	GameSettings.net_address = where
	GameSettings.save()
	var t := EnetTransport.new()
	var err := t.join(host, port)
	if err != OK:
		var why := error_string(err)
		_set_status(func() -> String: return tr("Cannot connect to %s: %s") % [where, why], true)
		return
	var s := _open_session(t)
	s.join_game()
	_set_status(func() -> String: return tr("Connecting to %s…") % where)
	_busy(true)


func _open_session(t: NetTransport) -> NetSession:
	var s := NetSession.open(get_tree(), t)
	s.started.connect(func() -> void: start.emit())
	s.failed.connect(_on_failed)
	return s


func _on_failed(why: String) -> void:
	NetSession.close_current()
	_set_status(func() -> String: return why, true)
	_busy(false)


func _on_back() -> void:
	if NetSession.current != null:
		NetSession.close_current()
		_set_status(Callable())
		_busy(false)
		return
	back.emit()


func _busy(on: bool) -> void:
	for c: Control in [map, mine, theirs, create, address, join]:
		if c is BaseButton:
			(c as BaseButton).disabled = on
		elif c is LineEdit:
			(c as LineEdit).editable = not on


func _set_status(text: Callable, error: bool = false) -> void:
	_status = text
	_status_error = error
	_show_status()


func _show_status() -> void:
	status.visible = _status.is_valid()
	if not status.visible:
		return
	status.text = _status.call()
	status.add_theme_color_override("font_color", ERROR_COLOR if _status_error else NOTE_COLOR)
