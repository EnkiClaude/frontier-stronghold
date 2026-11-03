extends Node2D
## Game entry point. Builds the world and wires simulation, views and input.
##
## The simulation ([GameSim]) is plain data advanced by [SimClock]. Every Node
## created here is a view or an input controller (ADR-001).

const WORLDGEN_CONFIG := "res://data/world/default_worldgen.tres"
const SPEEDS: Array[float] = [1.0, 2.0, 3.0]

## World seed; 0 picks a random seed each run.
@export var world_seed: int = 0

var registry: DataRegistry
var sim: GameSim
var clock: SimClock

var camera: CameraController
var terrain_view: TerrainRenderer
var building_view: BuildingRenderer
var enemy_view: EnemyRenderer
var effects_view: EffectsRenderer
var controller: BuildController
var hud: Hud
var debug_overlay: DebugOverlay

var seed_used: int
var _speed_index := 0
var _tick_usec_avg := 0.0
var _worldgen_ms := 0.0


## Game version from project settings (application/config/version).
static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "dev"))


func _ready() -> void:
	get_window().title = "Frontier Stronghold v%s" % version()
	if OS.get_cmdline_args().has("--no-art") or OS.get_cmdline_user_args().has("--no-art"):
		DataRegistry.art_enabled = false  # Fallback colours only (debugging, comparisons).
	registry = DataRegistry.load_default()
	for err in registry.errors:
		push_error("Data: " + err)

	seed_used = world_seed if world_seed != 0 else int(Time.get_unix_time_from_system()) % 1000000
	var cfg := load(WORLDGEN_CONFIG) as WorldGenConfig
	var t0 := Time.get_ticks_usec()
	var grid := WorldGenerator.generate(cfg, registry, seed_used)
	sim = GameSim.new(registry, grid, seed_used)
	_worldgen_ms = (Time.get_ticks_usec() - t0) / 1000.0
	clock = SimClock.new(registry.rules.tick_rate)

	terrain_view = TerrainRenderer.new()
	terrain_view.name = "Terrain"
	add_child(terrain_view)
	terrain_view.setup(grid, registry)

	# Everything simulation-related is drawn in tile units under this node.
	var tile_space := Node2D.new()
	tile_space.name = "TileSpace"
	tile_space.scale = Vector2.ONE * WorldGrid.TILE_PX
	tile_space.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(tile_space)

	building_view = BuildingRenderer.new()
	building_view.sim = sim
	tile_space.add_child(building_view)

	var item_view := ItemRenderer.new()
	item_view.sim = sim
	tile_space.add_child(item_view)

	var route_view := RouteRenderer.new()
	tile_space.add_child(route_view)

	enemy_view = EnemyRenderer.new()
	enemy_view.sim = sim
	enemy_view.clock = clock
	tile_space.add_child(enemy_view)

	effects_view = EffectsRenderer.new()
	effects_view.sim = sim
	tile_space.add_child(effects_view)

	controller = BuildController.new()
	controller.sim = sim
	controller.building_view = building_view
	tile_space.add_child(controller)
	route_view.controller = controller

	var world_size := Vector2(grid.width, grid.height) * WorldGrid.TILE_PX
	camera = CameraController.new()
	camera.name = "Camera"
	camera.world_rect = Rect2(Vector2.ZERO, world_size)
	camera.position = sim.core.center() * WorldGrid.TILE_PX + Vector2(14, 0) * WorldGrid.TILE_PX
	camera.zoom = Vector2(0.75, 0.75)
	add_child(camera)
	camera.make_current()
	camera.clamp_to_world()
	camera.middle_clicked.connect(controller.pipette)
	camera.multi_touch_started.connect(controller.abort_gesture)
	camera.one_finger_pan = func() -> bool: return controller.mode == BuildController.Mode.SELECT

	hud = Hud.new()
	add_child(hud)
	hud.setup(sim, clock, controller, camera)
	hud.restart_requested.connect(func() -> void: get_tree().reload_current_scene())
	hud.quit_requested.connect(func() -> void: get_tree().quit())
	hud.pause_toggled.connect(func() -> void:
		clock.paused = not clock.paused
		_speed_changed())
	hud.speed_cycled.connect(func() -> void: _set_speed_index((_speed_index + 1) % SPEEDS.size()))
	GameSettings.get_instance().changed.connect(_apply_settings.bind(route_view))
	_apply_settings(route_view)

	debug_overlay = DebugOverlay.new()
	debug_overlay.name = "DebugOverlay"
	debug_overlay.stats_provider = _debug_stats
	debug_overlay.visible = false
	add_child(debug_overlay)

	Events.world_generated.emit(grid.width, grid.height)


func _process(delta: float) -> void:
	if not sim.game_over:
		clock.advance(delta, _sim_tick)


func _sim_tick(tick: int) -> void:
	var t0 := Time.get_ticks_usec()
	sim.tick(tick)
	var spent := float(Time.get_ticks_usec() - t0)
	_tick_usec_avg = lerpf(_tick_usec_avg, spent, 0.05)


func _unhandled_input(event: InputEvent) -> void:
	if hud.is_menu_open():
		return  # The menu owns pausing while it is open.
	if event.is_action_pressed("pause"):
		clock.paused = not clock.paused
		_speed_changed()
	elif event.is_action_pressed("speed_up"):
		_set_speed_index(_speed_index + 1)
	elif event.is_action_pressed("speed_down"):
		_set_speed_index(_speed_index - 1)
	elif event.is_action_pressed("skip_preparation"):
		sim.skip_preparation()
	elif event.is_action_pressed("cam_home"):
		camera.center_on(sim.core.center() * WorldGrid.TILE_PX)
	elif event.is_action_pressed("toggle_debug"):
		debug_overlay.visible = not debug_overlay.visible


## Applies player options that affect views (never the simulation).
func _apply_settings(route_view: RouteRenderer) -> void:
	camera.pan_mult = GameSettings.get_instance().pan_speed
	camera.zoom_mult = GameSettings.get_instance().zoom_speed
	route_view.visible = GameSettings.get_instance().show_routes


func _set_speed_index(i: int) -> void:
	_speed_index = clampi(i, 0, SPEEDS.size() - 1)
	clock.speed = SPEEDS[_speed_index]
	_speed_changed()


func _speed_changed() -> void:
	Events.sim_speed_changed.emit(clock.speed, clock.paused)


func _debug_stats() -> Dictionary:
	var grid := sim.grid
	var cell := WorldGrid.world_to_cell(get_global_mouse_position())
	var tile := "-"
	if grid.in_bounds(cell.x, cell.y):
		var i := grid.idx(cell.x, cell.y)
		var def: TerrainDef = registry.terrain_by_code[grid.terrain[i]]
		tile = "%d,%d %s (path dist %d)" % [cell.x, cell.y, def.display_name if def else "?", sim.path.dist[i]]
	return {
		"FPS": Engine.get_frames_per_second(),
		"Tick": "%d @ %d Hz (%.2f ms avg)" % [clock.tick_count, clock.tick_rate, _tick_usec_avg / 1000.0],
		"Enemies": sim.enemies.count,
		"Flow field": "v%d%s" % [sim.path.version, " (updating)" if sim.path.is_updating() else ""],
		"World": "%d x %d, seed %d (gen %.0f ms)" % [grid.width, grid.height, seed_used, _worldgen_ms],
		"Zoom": "%.2f" % camera.zoom.x,
		"Tile": tile,
	}
