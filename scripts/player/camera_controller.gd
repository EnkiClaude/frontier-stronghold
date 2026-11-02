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

## Player option multipliers (set from Settings by Main).
var pan_mult: float = 1.0
var zoom_mult: float = 1.0

var _dragging := false
## Screen distance moved during the current middle-button press.
var _drag_moved := 0.0
## Middle button released without dragging (pipette in the build controller).
signal middle_clicked
## Movement (px) below which a middle press counts as a click, not a pan.
const CLICK_SLOP := 6.0


func _process(delta: float) -> void:
	var dir := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	if dir != Vector2.ZERO:
		position += dir * pan_speed * pan_mult * delta / zoom.x
		clamp_to_world()


func _unhandled_input(event: InputEvent) -> void:
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


func _view_size() -> Vector2:
	return get_viewport_rect().size if is_inside_tree() else Vector2(1600, 900)


## Keeps the visible area inside [member world_rect] (plus [member edge_margin]).
## On an axis where the view is larger than the world, the world is centred.
func clamp_to_world() -> void:
	if not world_rect.has_area():
		return
	if zoom.x < min_zoom():
		zoom = Vector2.ONE * min_zoom()
	var area := world_rect.grow(edge_margin)
	var half := _view_size() * 0.5 / zoom.x
	var lo := area.position + half
	var hi := area.end - half
	position.x = area.get_center().x if lo.x > hi.x else clampf(position.x, lo.x, hi.x)
	position.y = area.get_center().y if lo.y > hi.y else clampf(position.y, lo.y, hi.y)
