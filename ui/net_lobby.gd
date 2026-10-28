class_name NetLobby
extends VBoxContainer
## The main menu's «Network play» page. First the player types a name and either creates a game
## (picking the map and both factions; the address to give the other player shows) or types the
## host's address and joins. Once both are connected the page is the lobby (NetSession): the
## host picks the map, each player their own faction, each marks «Ready», and the host starts the
## game when both are ready; `start` then asks the menu to open the game scene on both sides.
## The address may carry a port («192.168.1.5:24610»); without it EnetTransport.DEFAULT_PORT.
## Back leaves the lobby (or stops waiting), then goes back to the first page.

## Both games agreed; the game scene can open.
signal start
signal back

const BUTTON_SIZE := Vector2(340, 50)
const HEAD_COLOR := Color(0.93, 0.84, 0.66)
const NOTE_COLOR := Color(0.85, 0.72, 0.45)
const ERROR_COLOR := Color(0.95, 0.55, 0.45)
const READY_COLOR := Color(0.6, 0.85, 0.45)

var head := Label.new()
var player_name := LineEdit.new()
var map := OptionButton.new()
var mine := OptionButton.new()
var theirs := OptionButton.new()
var create := Button.new()
var join_note := Label.new()
var address := LineEdit.new()
var join := Button.new()
## The lobby: who is in it and who is ready.
var players := Label.new()
var ready_box := CheckButton.new()
var start_button := Button.new()
var status := Label.new()
var back_button := Button.new()

## Makes the status line's text (empty: no line), so it follows the language.
var _status := Callable()
var _status_error := false
## Set while the controls are filled from the session, so their signals are not echoed back.
var _filling := false


func _init() -> void:
	name = "Net"  # notr
	add_theme_constant_override("separation", 12)
	head.add_theme_color_override("font_color", HEAD_COLOR)
	head.add_theme_font_size_override("font_size", 28)
	add_child(head)
	player_name.custom_minimum_size = BUTTON_SIZE
	player_name.max_length = NetSession.MAX_NAME
	add_child(player_name)
	add_child(players)
	for box: OptionButton in [map, mine, theirs]:
		box.custom_minimum_size = BUTTON_SIZE
		add_child(box)
	for m: Dictionary in SkirmishMaps.all():
		map.add_item(str(m["id"]))
	for box: OptionButton in [mine, theirs]:
		for f in SkirmishSetup.FACTIONS:
			box.add_item(String(f))
	ready_box.custom_minimum_size = BUTTON_SIZE
	add_child(ready_box)
	start_button.custom_minimum_size = BUTTON_SIZE
	add_child(start_button)
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
	player_name.text_changed.connect(_on_name)
	ready_box.toggled.connect(_on_ready)
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back)


func _ready() -> void:
	retranslate()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		retranslate()


## Shows the page as the settings stand; any old network game is closed.
func open() -> void:
	NetSession.close_current()
	_filling = true
	map.selected = maxi(SkirmishMaps.ids().find(GameSettings.skirmish_map), 0)
	mine.selected = maxi(SkirmishSetup.FACTIONS.find(GameSettings.player_faction), 0)
	theirs.selected = maxi(SkirmishSetup.FACTIONS.find(GameSettings.enemy_faction), 0)
	_filling = false
	address.text = GameSettings.net_address
	player_name.text = GameSettings.player_name
	_set_status(Callable())
	_show_state()
	create.grab_focus.call_deferred()


func retranslate() -> void:
	head.text = tr("Network play")
	player_name.placeholder_text = tr("Your name")
	_name_factions()
	var maps := SkirmishMaps.all()
	for i in mini(maps.size(), map.item_count):
		var m: Dictionary = maps[i]
		map.set_item_text(i, tr("Map: %s") % tr(str(m["title"])))
	create.text = tr("Create a game")
	join_note.text = tr("Or join a game: the host's address")
	address.placeholder_text = tr("such as 192.168.1.5")
	join.text = tr("Join a game")
	ready_box.text = tr("Ready")
	start_button.text = tr("Start the game")
	back_button.text = tr("Back")
	_show_players()
	_show_status()


## In the lobby the other side's box names the other player, before it the opponent.
func _name_factions() -> void:
	var s := NetSession.current
	var other := tr("Opponent")
	if s != null and not s.remote_name().is_empty():
		other = s.remote_name()
	for i in mini(SkirmishSetup.FACTIONS.size(), mine.item_count):
		var faction := UiText.name_of(SkirmishSetup.FACTIONS[i])
		mine.set_item_text(i, tr("You play: %s") % faction)
		theirs.set_item_text(i, "%s: %s" % [other, faction])


## Esc on this page: leaves the lobby or stops waiting, then goes back.
func cancel() -> void:
	_on_back()


func _session() -> NetSession:
	return NetSession.current


func _on_name(text: String) -> void:
	GameSettings.player_name = text.strip_edges().left(NetSession.MAX_NAME)
	GameSettings.save()


func _on_map(index: int) -> void:
	if _filling:
		return
	var id := SkirmishMaps.ids()[index]
	GameSettings.skirmish_map = id
	GameSettings.save()
	if _session() != null:
		_session().pick_map(id)


func _on_faction(index: int, own: bool) -> void:
	if _filling:
		return
	var f := SkirmishSetup.FACTIONS[index]
	var s := _session()
	if s == null or s.is_host:
		if own:
			GameSettings.player_faction = f
		else:
			GameSettings.enemy_faction = f
		GameSettings.save()
	if s == null:
		return
	if own:
		s.pick_faction(f)
	else:
		s.pick_guest_faction(f)


func _on_ready(on: bool) -> void:
	if not _filling and _session() != null:
		_session().set_ready(on)


func _on_start_pressed() -> void:
	if _session() != null:
		_session().start_game()


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
	s.host_game(GameSettings.skirmish_map, factions, Lockstep.DEFAULT_DELAY, player_name.text)
	var where := t.describe()
	_set_status(
		func() -> String: return tr("Waiting for the other player. Your address: %s") % where
	)
	_show_state()


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
	s.join_game(player_name.text)
	_set_status(func() -> String: return tr("Connecting to %s…") % where)
	_show_state()


func _open_session(t: NetTransport) -> NetSession:
	var s := NetSession.open(get_tree(), t)
	s.started.connect(func() -> void: start.emit())
	s.failed.connect(_on_failed)
	s.lobby_changed.connect(_on_lobby_changed)
	s.opponent_left.connect(_on_opponent_left)
	return s


func _on_failed(why: String) -> void:
	NetSession.close_current()
	_set_status(func() -> String: return why, true)
	_show_state()


func _on_opponent_left() -> void:
	NetSession.close_current()
	_set_status(func() -> String: return tr("The other player has left the game"), true)
	_show_state()


func _on_lobby_changed() -> void:
	var s := _session()
	if s == null:
		return
	if s.state == NetSession.State.LOBBY:
		_set_status(
			func() -> String:
				return (
					tr("Both ready: the host starts the game")
					if s.both_ready()
					else tr("Pick your faction and press «Ready»")
				)
		)
	_show_state()


func _on_back() -> void:
	if _session() != null:
		NetSession.close_current()
		_set_status(Callable())
		_show_state()
		return
	back.emit()


## Which controls show and what they hold: before connecting, waiting, or in the lobby.
func _show_state() -> void:
	var s := _session()
	var lobby := s != null and s.state == NetSession.State.LOBBY
	var waiting := s != null and not lobby
	player_name.visible = s == null
	create.visible = s == null or (waiting and s.is_host)
	create.disabled = waiting
	join_note.visible = s == null
	address.visible = s == null
	join.visible = s == null
	players.visible = lobby
	ready_box.visible = lobby
	start_button.visible = lobby and s.is_host
	if s != null and s.factions().size() == 2:
		_filling = true
		var sides := s.factions()
		var me := s.local_player - 1
		map.selected = maxi(SkirmishMaps.ids().find(s.map_id()), 0)
		mine.selected = maxi(SkirmishSetup.FACTIONS.find(sides[me]), 0)
		theirs.selected = maxi(SkirmishSetup.FACTIONS.find(sides[1 - me]), 0)
		ready_box.button_pressed = s.ready_flags[me]
		_filling = false
	if s != null:
		start_button.disabled = not s.both_ready()
	map.disabled = s != null and not s.is_host
	mine.disabled = waiting and not s.is_host
	theirs.disabled = s != null and not (s.is_host and s.state == NetSession.State.WAITING)
	_name_factions()
	_show_players()


func _show_players() -> void:
	var s := _session()
	if s == null or s.state != NetSession.State.LOBBY:
		return
	var rows := PackedStringArray()
	for i in 2:
		var who := s.names[i]
		if who.is_empty():
			who = tr("Host") if i == 0 else tr("Guest")
		if i == s.local_player - 1:
			who = tr("%s (you)") % who
		var mark := tr("ready") if s.ready_flags[i] else tr("not ready")
		rows.append("%s · %s" % [who, mark])
	players.text = "\n".join(rows)
	players.add_theme_color_override("font_color", READY_COLOR if s.both_ready() else NOTE_COLOR)


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
