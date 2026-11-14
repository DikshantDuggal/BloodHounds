extends RefCounted

const KEYS := {
	"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT],
	"leap": [KEY_SPACE, KEY_UP], "light": [KEY_J], "heavy": [KEY_K],
	"dash": [KEY_SHIFT], "parry": [KEY_L], "flash": [KEY_F], "reversal": [KEY_Q],
	"phantom": [KEY_E], "sever": [KEY_U], "echo": [KEY_I],
	"confirm": [KEY_ENTER, KEY_KP_ENTER], "retry": [KEY_R], "pause": [KEY_ESCAPE]
}

static func install() -> void:
	for action: String in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: int in KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
