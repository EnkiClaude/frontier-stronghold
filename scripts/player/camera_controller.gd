class_name CameraController
extends Camera2D
## RTS camera that works with mice, trackpads and (later) touch:
## - Mouse wheel: zoom at the cursor. Smooth-scrolling devices (Magic Mouse,
##   trackpads, high-resolution wheels) send many small events; each one is
##   scaled by the event's `factor` so a gesture zooms smoothly, not in jumps.
## - Trackpad pinch: zoom. Trackpad two-finger swipe: pan.
## - WASD / arrows: pan. Middle-mouse drag: pan. Page Up/Down, +/- buttons: zoom.

## Pan speed in screen pixels per second (independent of zoom).
@export var pan_speed: float = 1100.0
## Zoom multiplier for one full wheel notch / keypress.
@export var zoom_step: float = 1.15
@export var max_zoom: float = 3.0
## Hard lower limit; the effective minimum also stops at "whole map height visible".
@export var min_zoom_floor: float = 0.12

## Playable area in world units; the view is kept inside it.
var world_rect := Rect2()
## Extra space allowed beyond the world edge, in world units.
@export var edge_margin: float = 64.0
## Fraction of half the view width that may extend past the left/right map
## edge (1.0 = the edge can reach the screen centre).
@export var overscroll_x: float = 1.0

## Player option multipliers (set from Settings by Main).
var pan_mult: float = 1.0
var zoom_mult: float = 1.0

var _dragging := false
## Screen distance moved during the current middle-button press.
var _drag_moved := 0.0
## Middle button released without dragging (pipette in the build controller).
signal middle_clicked
## A second finger touched the screen (the build controller aborts its drag).
signal multi_touch_started

## Returns true when a one-finger drag should pan the camera (no build tool
## active). Set by Main; unset = never.
var one_finger_pan: Callable
## Active touches: index -> screen position.
var _touches: Dictionary = {}
var _touch_moved := 0.0
## Movement (px) below which a middle press counts as a click, not a pan.
const CLICK_SLOP := 6.0


func _process(delta: float) -> void:
	var dir := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	if dir != Vector2.ZERO:
		position += dir * pan_speed * pan_mult * delta / zoom.x
		clamp_to_world()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_handle_touch(event)
		return
	var handled := true
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		var mb := event as InputEventMouseButton
		# factor is 0 on devices that don't report it: treat as one notch.
		var notches := mb.factor if mb.factor > 0.0 else 1.0
		var f := pow(zoom_step, minf(notches, 3.0) * zoom_mult)
		zoom_at(mb.position, f if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / f)
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		zoom_at(mg.position, pow(mg.factor, zoom_mult))
	elif event is InputEventPanGesture:
		position += (event as InputEventPanGesture).delta * 12.0 * pan_mult / zoom.x
		clamp_to_world()
	elif event is InputEventKey and event.is_action_pressed("cam_zoom_in"):
		zoom_by(zoom_step)
	elif event is InputEventKey and event.is_action_pressed("cam_zoom_out"):
		zoom_by(1.0 / zoom_step)
	elif event.is_action_pressed("cam_drag"):
		_dragging = true
		_drag_moved = 0.0
	elif event.is_action_released("cam_drag"):
		_dragging = false
		if _drag_moved < CLICK_SLOP:
			middle_clicked.emit()
	elif _dragging and event is InputEventMouseMotion:
		_drag_moved += (event as InputEventMouseMotion).relative.length()
		position -= (event as InputEventMouseMotion).relative / zoom.x
		clamp_to_world()
	else:
		handled = false
	if handled and is_inside_tree():
		get_viewport().set_input_as_handled()


## Touch gestures: two fingers pan + pinch-zoom; one finger pans when no tool is active.
func _handle_touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
			if _touches.size() == 1:
				_touch_moved = 0.0
			elif _touches.size() == 2:
				multi_touch_started.emit()
		else:
			_touches.erase(st.index)
		return
	var sd := event as InputEventScreenDrag
	if not _touches.has(sd.index):
		_touches[sd.index] = sd.position
	if _touches.size() >= 2:
		var keys := _touches.keys()
		var a: Vector2 = _touches[keys[0]]
		var b: Vector2 = _touches[keys[1]]
		var before_center := (a + b) * 0.5
		var before_dist := a.distance_to(b)
		_touches[sd.index] = sd.position
		a = _touches[keys[0]]
		b = _touches[keys[1]]
		var center := (a + b) * 0.5
		position -= (center - before_center) / zoom.x
		if before_dist > 1.0:
			zoom_at(center, pow(a.distance_to(b) / before_dist, zoom_mult))
		clamp_to_world()
		if is_inside_tree():
			get_viewport().set_input_as_handled()
		return
	_touches[sd.index] = sd.position
	_touch_moved += sd.relative.length()
	if one_finger_pan.is_valid() and one_finger_pan.call() and _touch_moved > CLICK_SLOP:
		position -= sd.relative * pan_mult / zoom.x
		clamp_to_world()


func touch_count() -> int:
	return _touches.size()


## Smallest allowed zoom: the whole strip height fits on screen, never less.
func min_zoom() -> float:
	if not world_rect.has_area():
		return min_zoom_floor
	var fit := _view_size().y / (world_rect.size.y + edge_margin * 2.0)
	return maxf(min_zoom_floor, fit)


## Zooms around the screen centre (buttons, keys).
func zoom_by(factor: float) -> void:
	zoom_at(_view_size() * 0.5, factor)


## Zooms by [param factor] keeping the world point under [param screen_pos] fixed.
func zoom_at(screen_pos: Vector2, factor: float) -> void:
	var old := zoom.x
	var nz := clampf(old * factor, min_zoom(), max_zoom)
	if is_equal_approx(nz, old):
		return
	var offset_px := screen_pos - _view_size() * 0.5
	var world_at := position + offset_px / old
	zoom = Vector2(nz, nz)
	position = world_at - offset_px / nz
	clamp_to_world()


func center_on(world_pos: Vector2) -> void:
	position = world_pos
	clamp_to_world()


## Half the visible area in world units at the current zoom.
func view_half_size() -> Vector2:
	return _view_size() * 0.5 / zoom.x


func _view_size() -> Vector2:
	return get_viewport_rect().size if is_inside_tree() else Vector2(1600, 900)


## Keeps the visible area inside [member world_rect] (plus [member edge_margin]).
## On an axis where the view is larger than the world, the world is centred.
func clamp_to_world() -> void:
	if not world_rect.has_area():
		return
	if zoom.x < min_zoom():
		zoom = Vector2.ONE * min_zoom()
	var half := _view_size() * 0.5 / zoom.x
	# Horizontally the view may go far past the map ends, so the Core (near the
	# west edge) and the nests can be centred on any screen.
	var mx := maxf(edge_margin, half.x * overscroll_x)
	var area := world_rect.grow_individual(mx, edge_margin, mx, edge_margin)
	var lo := area.position + half
	var hi := area.end - half
	position.x = area.get_center().x if lo.x > hi.x else clampf(position.x, lo.x, hi.x)
	position.y = area.get_center().y if lo.y > hi.y else clampf(position.y, lo.y, hi.y)
