extends TestCase
## Drives the real input controller with a simulated mouse.


func _controller(sim: GameSim) -> BuildController:
	var c := BuildController.new()
	c.sim = sim
	return c


func _drag(c: BuildController, from: Vector2, to: Vector2) -> void:
	c.mouse_override = from
	c._process(0.016)
	c._on_primary_pressed()
	c.mouse_override = to
	c._process(0.016)
	c._commit_drag()


func test_drag_places_a_line_of_walls() -> void:
	var sim := SimHelpers.open_sim()
	var c := _controller(sim)
	c.select_build(sim.reg.buildings_by_id[&"wall"])
	_drag(c, Vector2(20.5, 4.5), Vector2(25.5, 4.5))
	for x in range(20, 26):
		assert_true(sim.building_at(Vector2i(x, 4)) != null, "wall missing at x=%d" % x)
	assert_eq(sim.building_at(Vector2i(26, 4)), null)
	c.free()


func test_belt_drag_points_along_drag_direction() -> void:
	var sim := SimHelpers.open_sim()
	var c := _controller(sim)
	c.select_build(sim.reg.buildings_by_id[&"conveyor_belt"])
	_drag(c, Vector2(20.5, 8.5), Vector2(20.5, 3.5))
	for y in range(3, 9):
		var b := sim.building_at(Vector2i(20, y))
		assert_true(b != null and b.rotation == 3, "belt at y=%d should face north" % y)
	c.free()


func test_click_selects_and_right_click_sells() -> void:
	var sim := SimHelpers.open_sim()
	sim.place(&"wall", Vector2i(20, 4))
	var c := _controller(sim)
	c.mouse_override = Vector2(20.5, 4.5)
	c._process(0.016)
	c._on_primary_pressed()
	assert_eq(c.selected, sim.building_at(Vector2i(20, 4)))
	c.sell_selected()
	assert_eq(sim.building_at(Vector2i(20, 4)), null)
	c.free()


func test_pipette_picks_building_and_rotation() -> void:
	var sim := SimHelpers.open_sim()
	sim.place(&"conveyor_belt", Vector2i(20, 4), 3)
	var c := _controller(sim)
	c.mouse_override = Vector2(20.5, 4.5)
	c._process(0.016)
	c.pipette()
	assert_eq(c.mode, BuildController.Mode.BUILD)
	assert_eq(c.build_def.id, &"conveyor_belt")
	assert_eq(c.rotation_steps, 3)
	c.mouse_override = Vector2(30.5, 4.5)
	c._process(0.016)
	c.pipette()
	assert_eq(c.mode, BuildController.Mode.SELECT, "pipette on empty ground drops the tool")
	c.free()


func test_right_drag_sells_a_locked_line() -> void:
	var sim := SimHelpers.open_sim()
	for x in range(20, 26):
		sim.place(&"wall", Vector2i(x, 4))
	sim.place(&"wall", Vector2i(23, 5))  # Just off the line.
	var c := _controller(sim)
	c.mouse_override = Vector2(20.5, 4.5)
	c._process(0.016)
	c.begin_sell_swipe()
	c.mouse_override = Vector2(23.5, 4.5)
	c._process(0.016)
	c.mouse_override = Vector2(25.5, 5.4)  # Wobble down a row: stays locked to y = 4.
	c._process(0.016)
	c.end_sell_swipe()
	for x in range(20, 26):
		assert_eq(sim.building_at(Vector2i(x, 4)), null, "wall at x=%d should be sold" % x)
	assert_true(sim.building_at(Vector2i(23, 5)) != null, "off-line wall must survive")
	c.free()


func test_sell_mode_tap_and_swipe() -> void:
	var sim := SimHelpers.open_sim()
	for x in range(20, 24):
		sim.place(&"wall", Vector2i(x, 4))
	var c := _controller(sim)
	c.select_sell_mode()
	assert_eq(c.mode, BuildController.Mode.SELL)
	c.mouse_override = Vector2(20.5, 4.5)
	c._process(0.016)
	c._on_primary_pressed()
	c.mouse_override = Vector2(23.5, 4.5)
	c._process(0.016)
	c.end_sell_swipe()
	for x in range(20, 24):
		assert_eq(sim.building_at(Vector2i(x, 4)), null)
	c.free()


func test_second_finger_aborts_build_drag() -> void:
	var sim := SimHelpers.open_sim()
	var c := _controller(sim)
	c.select_build(sim.reg.buildings_by_id[&"wall"])
	c.mouse_override = Vector2(20.5, 4.5)
	c._process(0.016)
	c._on_primary_pressed()
	c.abort_gesture()
	c.mouse_override = Vector2(25.5, 4.5)
	c._process(0.016)
	if c._dragging:
		c._commit_drag()
	assert_eq(sim.building_at(Vector2i(20, 4)), null, "pinching must not place walls")
	c.free()


func test_tap_emulated_mouse_matches_primary() -> void:
	# iOS taps arrive as mouse clicks from the emulation device (-1); every
	# default binding must match any device (v0.3.2 couldn't build on phones).
	var kb: GDScript = load("res://scripts/core/keybinds.gd")
	var defaults: Dictionary = kb.default_bindings()
	for action: String in defaults:
		for ev: InputEvent in defaults[action]:
			assert_eq(ev.device, -1, "%s binding must match any device" % action)
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	tap.device = InputEvent.DEVICE_ID_EMULATION
	var binding: InputEvent = defaults["primary"][0]
	assert_true(binding.is_match(tap), "emulated tap must match the primary binding")
