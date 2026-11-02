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
