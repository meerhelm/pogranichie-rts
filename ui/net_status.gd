class_name NetStatus
extends PanelContainer
## A line under the top bar in a network game: «Waiting for the other player…» while the world
## stands waiting for the other side's orders, and for good once the other player has left or the
## two worlds have drifted apart (with where the replay was saved). Runs while the tree is paused,
## as the network game does.

## Frames of waiting before the line shows (a short wait is normal on a slow line).
const WAIT_FRAMES := 20

var session: NetSession
var clock: SimClock
var _label := Label.new()
## Makes the text of a line that stays (once the other player has left or a desync).
var _final := Callable()
var _left := false


func _init() -> void:
	name = "NetStatus"  # notr
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	position.y = 64
	_label.add_theme_color_override("font_color", Color(0.98, 0.88, 0.62))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	visible = false


func attach(p_session: NetSession, p_clock: SimClock) -> void:
	session = p_session
	clock = p_clock
	session.opponent_left.connect(_on_left)
	session.desynced.connect(_on_desynced)


func _process(_delta: float) -> void:
	if _final.is_valid():
		return
	visible = clock != null and clock.waiting > WAIT_FRAMES
	if visible:
		_label.text = tr("Waiting for the other player…")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _final.is_valid():
		_show_final()


func _on_left() -> void:
	_left = true
	_final = func() -> String: return tr("The other player has left the game")
	_show_final()


func _on_desynced(tick: int, path: String) -> void:
	if _left:
		return
	var at := UiText.clock(tick)
	var where := ProjectSettings.globalize_path(path)
	_final = func() -> String:
		return tr("The two games have drifted apart at %s. Replay saved: %s") % [at, where]
	_show_final()


func _show_final() -> void:
	_label.text = _final.call()
	visible = true
