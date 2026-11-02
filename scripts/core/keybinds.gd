extends Node
## Input action registry (autoload "Keybinds").
##
## Registers the default bindings at startup and applies user overrides from
## [constant CONFIG_PATH]. Gameplay code reads named actions only, never raw keys,
## so a touch input layer can be added later without touching gameplay code.
## Keys use physical keycodes so WASD stays in place on AZERTY/QWERTZ layouts.

const CONFIG_PATH := "user://keybindings.cfg"
const SECTION := "keys"


func _enter_tree() -> void:
	register_defaults()
	load_overrides()


static func default_bindings() -> Dictionary:
	return {
		"cam_up": [_key(KEY_W), _key(KEY_UP)],
		"cam_down": [_key(KEY_S), _key(KEY_DOWN)],
		"cam_left": [_key(KEY_A), _key(KEY_LEFT)],
		"cam_right": [_key(KEY_D), _key(KEY_RIGHT)],
		"cam_zoom_in": [_mouse(MOUSE_BUTTON_WHEEL_UP), _key(KEY_PAGEUP)],
		"cam_zoom_out": [_mouse(MOUSE_BUTTON_WHEEL_DOWN), _key(KEY_PAGEDOWN)],
		"cam_drag": [_mouse(MOUSE_BUTTON_MIDDLE)],
		"cam_home": [_key(KEY_H)],
		"skip_preparation": [_key(KEY_N)],
		"primary": [_mouse(MOUSE_BUTTON_LEFT)],
		"secondary": [_mouse(MOUSE_BUTTON_RIGHT)],
		"rotate": [_key(KEY_R)],
		"pipette": [_key(KEY_Q)],
		"pause": [_key(KEY_SPACE)],
		"speed_up": [_key(KEY_EQUAL), _key(KEY_KP_ADD)],
		"speed_down": [_key(KEY_MINUS), _key(KEY_KP_SUBTRACT)],
		"toggle_debug": [_key(KEY_F3)],
		"cancel": [_key(KEY_ESCAPE)],
		"tool_excavate": [_key(KEY_X)],
		"sell_selected": [_key(KEY_DELETE), _key(KEY_BACKSPACE)],
		"move_selected": [_key(KEY_M)],
		"tool_1": [_key(KEY_1)],
		"tool_2": [_key(KEY_2)],
		"tool_3": [_key(KEY_3)],
		"tool_4": [_key(KEY_4)],
		"tool_5": [_key(KEY_5)],
		"tool_6": [_key(KEY_6)],
		"tool_7": [_key(KEY_7)],
		"tool_8": [_key(KEY_8)],
		"tool_9": [_key(KEY_9)],
	}


static func register_defaults() -> void:
	var defaults := default_bindings()
	for action: String in defaults:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for ev: InputEvent in defaults[action]:
			InputMap.action_add_event(action, ev)


## Replaces the keyboard bindings of [param action] with [param physical_keycodes]
## and persists the change. Mouse bindings are kept.
static func rebind_keys(action: String, physical_keycodes: Array) -> void:
	_apply_keys(action, physical_keycodes)
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)  # Missing file is fine.
	cfg.set_value(SECTION, action, physical_keycodes)
	cfg.save(CONFIG_PATH)


static func load_overrides() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK or not cfg.has_section(SECTION):
		return
	for action in cfg.get_section_keys(SECTION):
		if InputMap.has_action(action):
			_apply_keys(action, cfg.get_value(SECTION, action, []))


static func _apply_keys(action: String, physical_keycodes: Array) -> void:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	for code in physical_keycodes:
		InputMap.action_add_event(action, _key(int(code)))


static func _key(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code as Key
	return ev


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	return ev
