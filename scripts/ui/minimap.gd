class_name Minimap
extends Control
## Overview of the whole map: terrain, structures, nests, the Core, every
## enemy (red dots) and the camera view (white frame). Click or drag on it to
## move the camera.

const REDRAW_INTERVAL := 0.1
const ENEMY_COLOR := Color(1.0, 0.2, 0.15)

var sim: GameSim
var camera: CameraController

var _img: Image
var _tex: ImageTexture
var _terrain_dirty := false
var _timer := 0.0
var _dragging := false


func setup(game: GameSim, cam: CameraController, width_px: float) -> void:
	sim = game
	camera = cam
	var g := sim.grid
	_img = Image.create(g.width, g.height, false, Image.FORMAT_RGBA8)
	for x in g.width:
		for y in g.height:
			_img.set_pixel(x, y, _terrain_color(g.get_terrain(x, y)))
	_tex = ImageTexture.create_from_image(_img)
	g.terrain_changed.connect(_on_terrain_changed)
	custom_minimum_size = Vector2(width_px, width_px * g.height / g.width)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Minimap: click or drag to move the camera"


func _terrain_color(code: int) -> Color:
	var def: TerrainDef = sim.reg.terrain_by_code[code] if code < sim.reg.terrain_by_code.size() else null
	return def.color if def != null else Color.MAGENTA


func _on_terrain_changed(cell: Vector2i) -> void:
	_img.set_pixelv(cell, _terrain_color(sim.grid.get_terrain(cell.x, cell.y)))
	_terrain_dirty = true


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or sim == null:
		return
	_timer = REDRAW_INTERVAL
	if _terrain_dirty:
		_terrain_dirty = false
		_tex.update(_img)
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var g := sim.grid
	var s := size / Vector2(g.width, g.height)
	draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false)
	for b: Building in sim.buildings.values():
		var col: Color
		match b.def.kind:
			&"core":
				col = Color(0.3, 0.75, 1.0)
			&"wall":
				col = Color(0.95, 0.92, 0.85)
			&"tower":
				col = Color(1.0, 0.7, 0.1) if b.ammo > 0 or sim.infinite_ammo else Color(1.0, 0.3, 0.9)
			_:
				col = Color(0.65, 0.65, 0.7)
		draw_rect(Rect2(Vector2(b.origin) * s, Vector2(b.size()) * s).grow(0.3), col)
	for at in sim.nests:
		draw_rect(Rect2(Vector2(at) * s, Vector2(GameSim.NEST_SIZE) * s).grow(2.0), Color(0.8, 0.1, 0.1))
	var e := sim.enemies
	var dot := Vector2(3, 3)
	for i in e.count:
		draw_rect(Rect2(Vector2(e.x[i], e.y[i]) * s - dot * 0.5, dot), ENEMY_COLOR)
	# Camera view.
	if camera != null:
		var half := camera.get_viewport_rect().size * 0.5 / camera.zoom.x / WorldGrid.TILE_PX
		var center := camera.position / WorldGrid.TILE_PX
		var view := Rect2((center - half) * s, half * 2.0 * s).intersection(Rect2(Vector2.ZERO, size).grow(-1.0))
		draw_rect(view, Color(1, 1, 1, 0.9), false, 1.5)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.8), false, 2.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_move_camera(event.position)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_move_camera(event.position)
		accept_event()
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		_move_camera(event.position)
		accept_event()


func _move_camera(local: Vector2) -> void:
	if camera == null:
		return
	var tile := local / size * Vector2(sim.grid.width, sim.grid.height)
	camera.center_on(tile * WorldGrid.TILE_PX)
