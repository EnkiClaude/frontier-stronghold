class_name BuildController
extends Node2D
## Player construction input and the world overlay (ghosts, ranges, enemy
## routes). Lives in tile space (1 unit = 1 tile). All changes go through
## [GameSim] commands; this node holds no game state of its own.

signal message(text: String)
## Tool or selection changed (HUD refreshes its buttons and panels).
signal changed
## Esc pressed with nothing to cancel: open the game menu.
signal menu_requested

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

## Pipette (middle click): pick the building under the cursor as the build
## tool, with its rotation. Pointing at nothing just drops the current tool.
func pipette() -> void:
	var b := sim.building_at(_hover)
	if b == null or b.def.toolbar_slot <= 0:
		cancel()
		return
	mode = Mode.BUILD
	build_def = b.def
	rotation_steps = b.rotation
	_set_selected(null)
	changed.emit()


## Right-button sell swipe: everything the cursor passes over is sold. After
## the first tile of movement the swipe locks to that row or column.
var _swiping := false
var _swipe_start := Vector2i.ZERO
var _swipe_axis := -1  # -1 undecided, 0 horizontal, 1 vertical
var _swipe_count := 0
var _swipe_value := 0


func begin_sell_swipe() -> void:
	_swiping = true
	_swipe_start = _hover
	_swipe_axis = -1
	_swipe_count = 0
	_swipe_value = 0
	_sell_at(_hover)


func end_sell_swipe() -> void:
	if not _swiping:
		return
	_swiping = false
	if _swipe_count > 1:
		message.emit("Sold %d structures (+%d)" % [_swipe_count, _swipe_value])
	elif _swipe_count == 1:
		message.emit("Sold for +%d" % _swipe_value)


## Cursor position projected onto the locked swipe line.
func _swipe_target() -> Vector2i:
	var d := _hover - _swipe_start
	if _swipe_axis == -1 and (absi(d.x) >= 1 or absi(d.y) >= 1):
		_swipe_axis = 0 if absi(d.x) >= absi(d.y) else 1
	match _swipe_axis:
		0:
			return Vector2i(_hover.x, _swipe_start.y)
		1:
			return Vector2i(_swipe_start.x, _hover.y)
	return _swipe_start


func _update_swipe() -> void:
	if not _swiping:
		return
	var target := _swipe_target()
	var step := Vector2i(signi(target.x - _swipe_start.x), signi(target.y - _swipe_start.y))
	var cell := _swipe_start
	while true:
		_sell_at(cell)
		if cell == target:
			break
		cell += step


func _sell_at(cell: Vector2i) -> void:
	var b := sim.building_at(cell)
	if b == null or not b.def.sellable:
		return
	var value := sim.sell_value(b)
	if sim.sell(b.id) == "":
		_swipe_count += 1
		_swipe_value += value
		if selected == b:
			_set_selected(null)

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

## When set, replaces the real mouse position (tile units); used by tests.
var mouse_override: Variant = null


func _process(delta: float) -> void:
	if sim == null:
		return
	_mouse = mouse_override if mouse_override != null else get_local_mouse_position()
	_hover = Vector2i(floori(_mouse.x), floori(_mouse.y))
	if selected != null and not sim.buildings.has(selected.id):
		_set_selected(null)
	if mode == Mode.SELECT and _dragging:
		_dragging = false
	_update_swipe()
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
			begin_sell_swipe()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("secondary"):
		end_sell_swipe()
	elif event.is_action_pressed("pipette"):
		pipette()
	elif event.is_action_pressed("rotate"):
		rotation_steps = (rotation_steps + 1) % 4
	elif event.is_action_pressed("cancel"):
		if mode == Mode.SELECT and selected == null:
			menu_requested.emit()
		else:
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


## Rotation used for placement. Dragging a line of directional 1x1 buildings
## (belts) points them along the drag, like Factorio.
func _effective_rotation() -> int:
	if mode == Mode.BUILD and _dragging and build_def.directional and build_def.size == Vector2i.ONE:
		var d := _anchor() - _drag_start
		if d != Vector2i.ZERO:
			if absi(d.x) >= absi(d.y):
				return 0 if d.x > 0 else 2
			return 1 if d.y > 0 else 3
	return rotation_steps


func _commit_drag() -> void:
	var rot := _effective_rotation()
	var origins := _line_origins()  # Must be computed while still dragging.
	_dragging = false
	var placed := 0
	var first_err := ""
	for g in origins:
		var err := sim.excavate(g) if mode == Mode.EXCAVATE else sim.place(build_def.id, g, rot)
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
				err = sim.check_place(build_def.id, o, _effective_rotation(), null, not single)
			Mode.EXCAVATE:
				err = sim.check_excavate(o)
			Mode.MOVE:
				err = sim.check_place(selected.def.id, o, rotation_steps, selected)
				if err == "" and sim.credits < sim.relocate_fee(selected):
					err = GameSim.ERR_CREDITS
		_ghosts.append([o, _footprint(), err == "", _effective_rotation()])
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
		var dir_def: BuildingDef = build_def if mode == Mode.BUILD else (selected.def if mode == Mode.MOVE and selected != null else null)
		if dir_def != null and dir_def.directional:
			_draw_chevron(rect, g[3])
		if dir_def != null and (dir_def.kind == &"drill" or dir_def.kind == &"inserter" or dir_def.kind == &"crafter" or dir_def.tower != null):
			# Show where the ghost would take items in / put them out.
			var probe := Building.new()
			probe.def = dir_def
			probe.origin = g[0]
			probe.rotation = g[3]
			BuildingRenderer.draw_io(self, sim, probe)
	var range_def: BuildingDef = build_def if mode == Mode.BUILD else (selected.def if selected != null else null)
	if range_def != null and range_def.tower != null:
		var center: Vector2
		if mode == Mode.SELECT:
			center = selected.center()
		else:
			center = Vector2(_anchor()) + Vector2(_footprint()) * 0.5
		draw_arc(center, range_def.tower.range_tiles, 0.0, TAU, 64, Color(1, 1, 1, 0.5), 0.06)
	# Show the no-build radius of enemies near the cursor while building.
	if mode != Mode.SELECT and sim.rules.no_build_radius > 0.0:
		var r := sim.rules.no_build_radius
		var shown := 0
		for i in sim.spatial.query(sim.enemies, _mouse.x, _mouse.y, r + 2.0):
			if i < sim.enemies.count and shown < 8:
				shown += 1
				draw_arc(Vector2(sim.enemies.x[i], sim.enemies.y[i]), r, 0.0, TAU, 40, Color(1, 0.3, 0.2, 0.2), 0.05)


func _draw_chevron(r: Rect2, rot: int) -> void:
	var c := r.get_center()
	var d := Vector2(BeltNetwork.DIRS[rot % 4])
	var side := Vector2(-d.y, d.x)
	var s := minf(r.size.x, r.size.y) * 0.3
	draw_polyline(PackedVector2Array([c - d * s + side * s, c + d * s * 0.8, c - d * s - side * s]), Color(1, 1, 1, 0.9), 0.1)


func _set_selected(b: Building) -> void:
	selected = b
	if building_view != null:
		building_view.selected_id = b.id if b != null else 0
	changed.emit()
