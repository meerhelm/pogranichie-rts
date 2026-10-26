class_name UiAnim
extends RefCounted
## Small Tween animations for the interface: a window fades in and its panel grows to size from
## its centre when it opens. Closing stays instant, so a closed window is gone at once. Runs
## while the game is paused (menus pause it).

## Seconds a window takes to appear.
const OPEN_TIME := 0.18
## Panel size it grows from.
const FROM_SCALE := Vector2(0.94, 0.94)


## Fades `window` in and, when given, grows `panel` (its pivot_offset_ratio sets the centre).
static func pop_in(window: Control, panel: Control = null) -> void:
	if not window.is_inside_tree():
		return
	window.modulate.a = 0.0
	var t := window.create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(window, ^"modulate:a", 1.0, OPEN_TIME)
	if panel != null:
		panel.scale = FROM_SCALE
		(
			t
			. parallel()
			. tween_property(panel, ^"scale", Vector2.ONE, OPEN_TIME)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)
