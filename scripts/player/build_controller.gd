class_name BuildController
extends Node2D
## Player construction input and the world overlay (ghosts, ranges, enemy
## routes). Lives in tile space (1 unit = 1 tile). All changes go through
## [GameSim] commands; this node holds no game state of its own.

signal message(text: String)
## Tool or selection changed (HUD refreshes its buttons and panels).
signal changed

enum Mode { SELECT, BUILD, EXCAVATE, MOVE }

## Seconds the cursor must rest before the "what if" route is computed.
const WHATIF_DELAY := 0.12
const ROUTE_COLOR := Color(1.0, 0.55, 0.15, 0.55)
const WHATIF_COLOR := Color(0.3, 0.9, 1.0, 0.8)
const OK_COLOR := Color(0.3, 1.0, 0.4, 0.35)
const BAD_COLOR := Color(1.0, 0.25, 0.2, 0.35)

var sim: GameSim
var building_view: BuildingRenderer

var mode: Mode = Mode.SELECT
var build_def: BuildingDef
var rotation_steps: int = 0
var selected: Building

var _hover := Vector2i(-9999, -9999)
var _mouse := Vector2.ZERO
var _dragging := false
var _drag_start := Vector2i.ZERO
## Ghosts: Array of [origin: Vector2i, size: Vector2i, ok: bool]
var _ghosts: Array = []
var _ghost_reason := ""
var _ghost_key := ""
var _routes: Array[PackedVector2Array] = []
var _routes_version := -1
var _whatif: Array[PackedVector2Array] = []
var _whatif_key := ""
var _rest := 0.0


# --- Public API (HUD buttons call these) -----------------------------------

func select_build(def: BuildingDef) -> void:
	if mode == Mode.BUILD and build_def == def:
		cancel()
		return
	mode = Mode.BUILD
	build_def = def
	_set_selected(null)
	changed.emit()


func select_excavate() -> void:
	if mode == Mode.EXCAVATE:
		cancel()
		return
	mode = Mode.EXCAVATE
	_set_selected(null)
	changed.emit()


func cancel() -> void:
	mode = Mode.SELECT
	build_def = null
	_dragging = false
	changed.emit()


func sell_selected() -> void:
	if selected == null:
		return
	var value := sim.sell_value(selected)
	var err := sim.sell(selected.id)
	if err != "":
		message.emit(err)
		return
	message.emit("Sold for +%d" % value)
	_set_selected(null)
	cancel()


func start_move_selected() -> void:
	if selected == null or not selected.def.relocatable:
		return
	if not selected.is_active():
		message.emit(GameSim.ERR_NOT_MOVABLE)
		return
	mode = Mode.MOVE
	rotation_steps = selected.rotation
	changed.emit()


# --- Frame update ------------------------------------------------------------

func _process(delta: float) -> void:
	if sim == null:
		return
	_mouse = get_local_mouse_position()
	_hover = Vector2i(floori(_mouse.x), floori(_mouse.y))
	if selected != null and not sim.buildings.has(selected.id):
		_set_selected(null)
	if mode == Mode.SELECT and _dragging:
		_dragging = false
	_update_routes()
	_update_ghosts()
	_update_whatif(delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if sim == null:
		return
	if event.is_action_pressed("primary"):
		_on_primary_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("primary"):
		if _dragging:
			_commit_drag()
	elif event.is_action_pressed("secondary"):
		if mode != Mode.SELECT:
			cancel()
		else:
			var b := sim.building_at(_hover)
			if b != null and b.def.sellable:
				_set_selected(b)
				sell_selected()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("rotate"):
		rotation_steps = (rotation_steps + 1) % 4
	elif event.is_action_pressed("cancel"):
		cancel()
		_set_selected(null)
	elif event.is_action_pressed("tool_excavate"):
		select_excavate()
	elif event.is_action_pressed("sell_selected"):
		sell_selected()
	elif event.is_action_pressed("move_selected"):
		start_move_selected()
	else:
		for def in sim.reg.toolbar_buildings():
			if event.is_action_pressed("tool_%d" % def.toolbar_slot):
				select_build(def)
				break


func _on_primary_pressed() -> void:
	match mode:
		Mode.SELECT:
			_set_selected(sim.building_at(_hover))
		Mode.BUILD, Mode.EXCAVATE:
			_dragging = true
			_drag_start = _anchor()
		Mode.MOVE:
			var err := sim.relocate(selected.id, _anchor(), rotation_steps)
			if err != "":
				message.emit(err)
			else:
				message.emit("Moved (-%d)" % sim.relocate_fee(selected))
				cancel()


func _commit_drag() -> void:
	_dragging = false
	var placed := 0
	var first_err := ""
	for g in _line_origins():
		var err := sim.excavate(g) if mode == Mode.EXCAVATE else sim.place(build_def.id, g, rotation_steps)
		if err == "":
			placed += 1
		elif first_err == "":
			first_err = err
	if first_err != "":
		message.emit(first_err if placed == 0 else "%s (%d placed)" % [first_err, placed])
	_ghost_key = ""


# --- Ghosts ------------------------------------------------------------------

func _footprint() -> Vector2i:
	if mode == Mode.BUILD:
		return Building.footprint_size(build_def, rotation_steps)
	if mode == Mode.MOVE and selected != null:
		return Building.footprint_size(selected.def, rotation_steps)
	return Vector2i.ONE


## Top-left tile of a footprint centred on the cursor.
func _anchor() -> Vector2i:
	var s := Vector2(_footprint())
	return Vector2i(floori(_mouse.x - s.x * 0.5 + 0.5), floori(_mouse.y - s.y * 0.5 + 0.5))


## Origins along the drag line (dominant axis, stepping by footprint size).
func _line_origins() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var end := _anchor()
	if not _dragging:
		out.append(end)
		return out
	var s := _footprint()
	var d := end - _drag_start
	var horizontal := absi(d.x) >= absi(d.y)
	var step := s.x if horizontal else s.y
	var count := (absi(d.x) if horizontal else absi(d.y)) / step
	var dir := Vector2i(signi(d.x), 0) if horizontal else Vector2i(0, signi(d.y))
	for k in count + 1:
		out.append(_drag_start + dir * step * k)
	return out


func _update_ghosts() -> void:
	if mode == Mode.SELECT:
		_ghosts.clear()
		_ghost_key = ""
		return
	var origins := _line_origins()
	var key := "%d|%s|%d|%s|%s|%d|%d" % [mode, build_def.id if build_def else &"", rotation_steps, origins[0], origins[-1], sim.structures_version, sim.credits]
	if key == _ghost_key and not _dragging:
		return
	if key == _ghost_key and sim.tick_count % 10 != 0:
		return
	_ghost_key = key
	_ghosts.clear()
	_ghost_reason = ""
	var single := origins.size() == 1
	for o in origins:
		var err := ""
		match mode:
			Mode.BUILD:
				err = sim.check_place(build_def.id, o, rotation_steps, null, not single)
			Mode.EXCAVATE:
				err = sim.check_excavate(o)
			Mode.MOVE:
				err = sim.check_place(selected.def.id, o, rotation_steps, selected)
				if err == "" and sim.credits < sim.relocate_fee(selected):
					err = GameSim.ERR_CREDITS
		_ghosts.append([o, _footprint(), err == ""])
		if single:
			_ghost_reason = err


## Draws the enemy routes; called by [RouteRenderer] (which sits below enemies).
func draw_routes(canvas: CanvasItem) -> void:
	for r in _routes:
		canvas.draw_polyline(r, ROUTE_COLOR, 0.14)
	for r in _whatif:
		canvas.draw_polyline(r, WHATIF_COLOR, 0.1)


## Explains why the hovered placement is invalid ("" if valid or not building).
func ghost_reason() -> String:
	return _ghost_reason


# --- Routes ------------------------------------------------------------------

func _update_routes() -> void:
	if _routes_version == sim.path.version:
		return
	_routes_version = sim.path.version
	_routes = _trace_routes(sim.path.dist)


func _update_whatif(delta: float) -> void:
	var want: bool = mode == Mode.BUILD and build_def.blocks_path and not _dragging \
		and _ghosts.size() == 1 and _ghosts[0][2]
	if not want:
		_whatif.clear()
		_whatif_key = ""
		_rest = 0.0
		return
	var key := "%s|%d|%d" % [_ghosts[0][0], sim.path.version, sim.structures_version]
	if key != _whatif_key:
		_whatif_key = key
		_whatif.clear()
		_rest = 0.0
		return
	_rest += delta
	if _rest >= WHATIF_DELAY and _whatif.is_empty():
		var cells := Building.footprint_cells(sim.grid, build_def, _ghosts[0][0], rotation_steps)
		_whatif = _trace_routes(sim.path.preview_field(cells))


func _trace_routes(field: PackedInt32Array) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for at in sim.nests:
		var pts := PackedVector2Array()
		for tile in sim.path.trace(sim.grid.idx(at.x, at.y), field):
			var c := sim.grid.cell_of(tile)
			pts.append(Vector2(c) + Vector2(0.5, 0.5))
		if pts.size() > 1:
			out.append(pts)
	return out


# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	if sim == null:
		return
	for g in _ghosts:
		var rect := Rect2(g[0], g[1])
		var ok: bool = g[2]
		draw_rect(rect, OK_COLOR if ok else BAD_COLOR)
		draw_rect(rect, Color(OK_COLOR if ok else BAD_COLOR, 0.9), false, 0.06)
	var range_def: BuildingDef = build_def if mode == Mode.BUILD else (selected.def if selected != null else null)
	if range_def != null and range_def.tower != null:
		var center: Vector2
		if mode == Mode.SELECT:
			center = selected.center()
		else:
			center = Vector2(_anchor()) + Vector2(_footprint()) * 0.5
		draw_arc(center, range_def.tower.range_tiles, 0.0, TAU, 64, Color(1, 1, 1, 0.5), 0.06)
	# Show the no-build radius of enemies near the cursor while building.
	if mode != Mode.SELECT:
		var r := sim.rules.no_build_radius
		var shown := 0
		for i in sim.spatial.query(sim.enemies, _mouse.x, _mouse.y, r + 2.0):
			if i < sim.enemies.count and shown < 8:
				shown += 1
				draw_arc(Vector2(sim.enemies.x[i], sim.enemies.y[i]), r, 0.0, TAU, 40, Color(1, 0.3, 0.2, 0.2), 0.05)


func _set_selected(b: Building) -> void:
	selected = b
	if building_view != null:
		building_view.selected_id = b.id if b != null else 0
	changed.emit()
