extends Node2D
## Game entry point. Builds the world and wires simulation, views and input.
##
## Simulation state (grid, clock, future systems) is owned here as plain data
## objects; Nodes created here are views/controllers only.

const WORLDGEN_CONFIG := "res://data/world/default_worldgen.tres"
const SPEEDS: Array[float] = [1.0, 2.0, 3.0]

@export var world_seed: int = 1337
@export var tick_rate: int = 30

var registry: DataRegistry
var grid: WorldGrid
var clock: SimClock

var camera: CameraController
var terrain_view: TerrainRenderer
var debug_overlay: DebugOverlay

var _speed_index := 0
var _tick_usec_avg := 0.0
var _worldgen_ms := 0.0


func _ready() -> void:
	registry = DataRegistry.load_default()
	for err in registry.errors:
		push_error("Data: " + err)
	clock = SimClock.new(tick_rate)

	var cfg := load(WORLDGEN_CONFIG) as WorldGenConfig
	var t0 := Time.get_ticks_usec()
	grid = WorldGenerator.generate(cfg, registry, world_seed)
	_worldgen_ms = (Time.get_ticks_usec() - t0) / 1000.0

	terrain_view = TerrainRenderer.new()
	terrain_view.name = "Terrain"
	add_child(terrain_view)
	terrain_view.setup(grid, registry)

	var world_size := Vector2(grid.width, grid.height) * WorldGrid.TILE_PX
	camera = CameraController.new()
	camera.name = "Camera"
	camera.world_rect = Rect2(Vector2.ZERO, world_size)
	camera.position = Vector2(cfg.core_clear_cols * 0.5, grid.height * 0.5) * WorldGrid.TILE_PX
	camera.zoom = Vector2(0.75, 0.75)
	add_child(camera)
	camera.make_current()
	camera.clamp_to_world()

	debug_overlay = DebugOverlay.new()
	debug_overlay.name = "DebugOverlay"
	debug_overlay.stats_provider = _debug_stats
	add_child(debug_overlay)

	Events.world_generated.emit(grid.width, grid.height)


func _process(delta: float) -> void:
	clock.advance(delta, _sim_tick)


## One fixed simulation step. Systems are added here in later phases, in a
## fixed order: spawning -> movement -> combat -> logistics -> cleanup.
func _sim_tick(_tick: int) -> void:
	var t0 := Time.get_ticks_usec()
	# (No simulation systems yet in Phase 0.)
	var spent := float(Time.get_ticks_usec() - t0)
	_tick_usec_avg = lerpf(_tick_usec_avg, spent, 0.05)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		clock.paused = not clock.paused
		_speed_changed()
	elif event.is_action_pressed("speed_up"):
		_set_speed_index(_speed_index + 1)
	elif event.is_action_pressed("speed_down"):
		_set_speed_index(_speed_index - 1)
	elif event.is_action_pressed("toggle_debug"):
		debug_overlay.visible = not debug_overlay.visible


func _set_speed_index(i: int) -> void:
	_speed_index = clampi(i, 0, SPEEDS.size() - 1)
	clock.speed = SPEEDS[_speed_index]
	_speed_changed()


func _speed_changed() -> void:
	Events.sim_speed_changed.emit(clock.speed, clock.paused)


func _debug_stats() -> Dictionary:
	var cell := WorldGrid.world_to_cell(get_global_mouse_position())
	var tile := "-"
	if grid.in_bounds(cell.x, cell.y):
		var def: TerrainDef = registry.terrain_by_code[grid.get_terrain(cell.x, cell.y)]
		tile = "%d,%d %s" % [cell.x, cell.y, def.display_name if def else "?"]
	return {
		"FPS": Engine.get_frames_per_second(),
		"Speed": "PAUSED" if clock.paused else "%dx" % int(clock.speed),
		"Tick": "%d @ %d Hz (%.3f ms avg)" % [clock.tick_count, clock.tick_rate, _tick_usec_avg / 1000.0],
		"World": "%d x %d tiles (gen %.0f ms)" % [grid.width, grid.height, _worldgen_ms],
		"Zoom": "%.2f" % camera.zoom.x,
		"Tile": tile,
	}
