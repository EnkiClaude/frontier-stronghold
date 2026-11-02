class_name GameSettings
extends Node
## Player options (autoload "Settings"), saved to [constant PATH].
## Views read these; the simulation never does. Access with [method get_instance]
## (works even where the autoload isn't registered yet, e.g. tool scripts).

signal changed

const PATH := "user://settings.cfg"
const SECTION := "options"
const KEYS := ["ui_scale", "pan_speed", "zoom_speed", "show_routes", "fullscreen"]

## HUD scale factor (0.75 - 2.0).
var ui_scale: float = 1.0
## Camera pan speed multiplier.
var pan_speed: float = 1.0
## Zoom sensitivity multiplier.
var zoom_speed: float = 1.0
var show_routes: bool = true
var fullscreen: bool = false


static var _fallback: GameSettings


## The autoload instance, or a default instance when it isn't available.
static func get_instance() -> GameSettings:
	var tree := Engine.get_main_loop() as SceneTree
	var node := tree.root.get_node_or_null("Settings") if tree != null else null
	if node is GameSettings:
		return node
	if _fallback == null:
		_fallback = GameSettings.new()
	return _fallback


func _ready() -> void:
	load_settings()
	_apply_window()


func set_option(key: String, value: Variant) -> void:
	if not KEYS.has(key):
		push_error("Unknown setting " + key)
		return
	set(key, value)
	save_settings()
	_apply_window()
	changed.emit()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in KEYS:
		if cfg.has_section_key(SECTION, key):
			set(key, cfg.get_value(SECTION, key))
	ui_scale = clampf(ui_scale, 0.75, 2.0)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in KEYS:
		cfg.set_value(SECTION, key, get(key))
	cfg.save(PATH)


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want and not (want == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
		DisplayServer.window_set_mode(want)
