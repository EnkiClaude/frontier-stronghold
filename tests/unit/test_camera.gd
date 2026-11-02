extends TestCase
## Camera input: smooth-scroll devices, trackpad gestures and zoom limits.
## (Regression for the macOS report "zoomed all the way out and could not zoom back in".)


func _camera() -> CameraController:
	var cam := CameraController.new()
	cam.world_rect = Rect2(0, 0, 256 * 32, 160 * 32)
	cam.zoom = Vector2.ONE
	cam.position = Vector2(4000, 2500)
	(Engine.get_main_loop() as SceneTree).root.add_child(cam)
	return cam


func _wheel(cam: CameraController, up: bool, factor: float) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	ev.factor = factor
	ev.position = Vector2(800, 450)
	cam._unhandled_input(ev)


func test_smooth_scroll_zooms_gradually_and_back() -> void:
	var cam := _camera()
	# A trackpad / Magic Mouse flick: 20 tiny events.
	for i in 20:
		_wheel(cam, false, 0.1)
	assert_true(cam.zoom.x > 0.7, "20 tiny scroll events must not slam to min zoom (got %.2f)" % cam.zoom.x)
	for i in 20:
		_wheel(cam, true, 0.1)
	assert_true(absf(cam.zoom.x - 1.0) < 0.01, "scrolling back restores zoom (got %.3f)" % cam.zoom.x)
	cam.queue_free()


func test_classic_wheel_without_factor() -> void:
	var cam := _camera()
	_wheel(cam, true, 0.0)
	assert_true(absf(cam.zoom.x - cam.zoom_step) < 0.001)
	cam.queue_free()


func test_can_zoom_in_from_minimum() -> void:
	var cam := _camera()
	for i in 200:
		_wheel(cam, false, 1.0)
	var lo := cam.zoom.x
	assert_true(absf(lo - cam.min_zoom()) < 0.001)
	assert_true(lo >= 0.12, "min zoom keeps tiles visible (got %.3f)" % lo)
	_wheel(cam, true, 1.0)
	assert_true(cam.zoom.x > lo, "must zoom back in from the minimum")
	cam.queue_free()


func test_pinch_gesture_zooms() -> void:
	var cam := _camera()
	var ev := InputEventMagnifyGesture.new()
	ev.factor = 1.2
	ev.position = Vector2(800, 450)
	cam._unhandled_input(ev)
	assert_true(absf(cam.zoom.x - 1.2) < 0.001)
	cam.queue_free()


func test_two_finger_pan_moves_camera() -> void:
	var cam := _camera()
	var before := cam.position
	var ev := InputEventPanGesture.new()
	ev.delta = Vector2(5, 0)
	cam._unhandled_input(ev)
	assert_true(cam.position.x > before.x)
	assert_eq(cam.zoom.x, 1.0, "panning does not zoom")
	cam.queue_free()


func test_buttons_zoom_and_center() -> void:
	var cam := _camera()
	cam.zoom_by(1.3)
	assert_true(absf(cam.zoom.x - 1.3) < 0.001)
	cam.center_on(Vector2(3000, 2000))
	assert_eq(cam.position, Vector2(3000, 2000))
	cam.queue_free()
