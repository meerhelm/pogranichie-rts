class_name GameInput
extends RefCounted
## Input actions of the game, registered in code so they live next to the code that uses them.

const KEYS := {
	&"cam_left": [KEY_A, KEY_LEFT],
	&"cam_right": [KEY_D, KEY_RIGHT],
	&"cam_up": [KEY_W, KEY_UP],
	&"cam_down": [KEY_S, KEY_DOWN],
	&"formation_line": [KEY_Q],
	&"formation_column": [KEY_E],
	&"formation_wedge": [KEY_R],
	&"stop": [KEY_H],
	&"stance_aggressive": [KEY_Z],
	&"stance_defensive": [KEY_X],
	&"stance_stand": [KEY_C],
	&"lithuanian_retreat": [KEY_T],
	&"turn_around": [KEY_G],
	&"dismount": [KEY_V],
}


static func ensure_actions() -> void:
	for action: StringName in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
