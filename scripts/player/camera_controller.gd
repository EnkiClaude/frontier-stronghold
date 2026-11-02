class_name CameraController
extends Camera2D
## Factorio-style RTS camera: WASD/arrow panning, wheel zoom anchored at the
## cursor, middle-mouse drag. Reads input actions only (see Keybinds).

## Pan speed in screen pixels per second (independent of zoom).
@export var pan_speed: float = 1100.0
@export var zoom_step: float = 1.15
@export var min_zoom: float = 0.08
@export var max_zoom: float = 4.0

## Playable area in world units; the view is kept inside it.
var world_rect := Rect2()
## Extra space allowed beyond the world edge, in world units.
@export var edge_margin: float = 64.0

var _dragging := false


func _process(delta: float) -> void:
	var dir := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	if dir != Vector2.ZERO:
		position += dir * pan_speed * delta / zoom.x
		clamp_to_world()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cam_zoom_in"):
		zoom_at(_mouse_screen_pos(), zoom_step)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cam_zoom_out"):
		zoom_at(_mouse_screen_pos(), 1.0 / zoom_step)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cam_drag"):
		_dragging = true
	elif event.is_action_released("cam_drag"):
		_dragging = false
	elif _dragging and event is InputEventMouseMotion:
		position -= (event as InputEventMouseMotion).relative / zoom.x
		clamp_to_world()


## Zooms by [param factor] keeping the world point under [param screen_pos] fixed.
func zoom_at(screen_pos: Vector2, factor: float) -> void:
	var old := zoom.x
	var nz := clampf(old * factor, min_zoom, max_zoom)
	if is_equal_approx(nz, old):
		return
	var offset_px := screen_pos - get_viewport_rect().size * 0.5
	var world_at := position + offset_px / old
	zoom = Vector2(nz, nz)
	position = world_at - offset_px / nz
	clamp_to_world()


func _mouse_screen_pos() -> Vector2:
	return get_viewport().get_mouse_position()


## Keeps the visible area inside [member world_rect] (plus [member edge_margin]).
## On an axis where the view is larger than the world, the world is centred.
func clamp_to_world() -> void:
	if not world_rect.has_area():
		return
	var area := world_rect.grow(edge_margin)
	var half := get_viewport_rect().size * 0.5 / zoom.x
	var lo := area.position + half
	var hi := area.end - half
	position.x = area.get_center().x if lo.x > hi.x else clampf(position.x, lo.x, hi.x)
	position.y = area.get_center().y if lo.y > hi.y else clampf(position.y, lo.y, hi.y)
