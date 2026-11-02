extends TestCase

const WALL := 1


func _map(w: int, h: int) -> PathMap:
	var reg := DataRegistry.load_default()
	var g := WorldGrid.new(w, h)
	var pm := PathMap.new(g, reg.walkable_lut)
	pm.goal_cells = PackedInt32Array([g.idx(0, h / 2)])
	pm.spawn_cells = PackedInt32Array([g.idx(w - 1, h / 2)])
	pm.rebuild_now()
	return pm


func _block(pm: PathMap, x: int, y: int) -> void:
	pm.set_blocked(pm.grid.idx(x, y), true)


func test_flow_field_distances() -> void:
	var pm := _map(10, 5)
	assert_eq(pm.dist[pm.grid.idx(0, 2)], 0)
	assert_eq(pm.dist[pm.grid.idx(9, 2)], 9)


func test_next_cell_moves_downhill() -> void:
	var pm := _map(10, 5)
	var c := pm.grid.idx(5, 2)
	var n := pm.next_cell(c)
	assert_true(pm.dist[n] < pm.dist[c])
	var route := pm.trace(pm.grid.idx(9, 2))
	assert_eq(route[route.size() - 1], pm.goal_cells[0], "trace must end at the goal")


func test_no_corner_cutting() -> void:
	var pm := _map(6, 6)
	# Goal at (0,3). From (1,2) the diagonal to (0,3) needs (0,2) and (1,3) open.
	_block(pm, 1, 3)
	pm.rebuild_now()
	var n := pm.next_cell(pm.grid.idx(1, 2))
	assert_ne(n, pm.grid.idx(0, 3), "must not cut the blocked corner")


func test_can_block_open_tile() -> void:
	var pm := _map(10, 7)
	assert_true(pm.can_block(PackedInt32Array([pm.grid.idx(5, 3)])))


func test_cannot_close_the_last_gap() -> void:
	var pm := _map(10, 7)
	for y in 6:
		_block(pm, 5, y)
	# Only (5, 6) remains open.
	assert_false(pm.can_block(PackedInt32Array([pm.grid.idx(5, 6)])))
	assert_true(pm.plan_passable[pm.grid.idx(5, 6)] == 1, "validation must not leave changes behind")


func test_non_simple_tile_with_alternative_route_is_allowed() -> void:
	var pm := _map(10, 7)
	# Two gaps in a wall at x=5: closing one is fine (needs the full BFS fallback).
	for y in 7:
		if y != 1 and y != 5:
			_block(pm, 5, y)
	assert_true(pm.can_block(PackedInt32Array([pm.grid.idx(5, 1)])))
	assert_false(pm.can_block(PackedInt32Array([pm.grid.idx(5, 1), pm.grid.idx(5, 5)])))


func test_cannot_block_goal_or_spawn() -> void:
	var pm := _map(10, 7)
	assert_false(pm.can_block(PackedInt32Array([pm.goal_cells[0]])))
	assert_false(pm.can_block(PackedInt32Array([pm.spawn_cells[0]])))


func test_must_reach_cells_are_protected() -> void:
	var pm := _map(10, 7)
	# Enclose (8,0) except via (8,1)... an enemy standing in a pocket must stay connected.
	_block(pm, 7, 0)
	_block(pm, 7, 1)
	_block(pm, 9, 1)
	var pocket := pm.grid.idx(8, 0)
	var seal := PackedInt32Array([pm.grid.idx(8, 1)])
	assert_true(pm.can_block(seal), "fine without an enemy in the pocket")
	assert_false(pm.can_block(seal, PackedInt32Array([pocket])), "must not trap an enemy")


func test_time_sliced_recompute_matches_full() -> void:
	var pm := _map(40, 20)
	for y in range(0, 15):
		_block(pm, 20, y)
	pm.nodes_per_tick = 50
	var before := pm.version
	var ticks := 0
	while pm.is_updating():
		pm.tick()
		ticks += 1
	assert_true(ticks > 5, "recompute should take several ticks at 50 nodes/tick")
	assert_eq(pm.version, before + 1)
	var sliced := pm.dist.duplicate()
	pm.rebuild_now()
	assert_true(sliced == pm.dist, "sliced and full recompute must agree")
	assert_eq(pm.dist[pm.grid.idx(39, 10)] > 39, true, "path detours around the wall")


func test_relocation_frees_old_cells() -> void:
	var pm := _map(10, 7)
	for y in 7:
		if y != 3:
			_block(pm, 5, y)
	_block(pm, 5, 3)  # Fully blocked (simulates an existing wall in the gap).
	pm.rebuild_now()
	# Moving that wall to (2,2) is valid because (5,3) is freed.
	var ok := pm.can_block(PackedInt32Array([pm.grid.idx(2, 2)]), PackedInt32Array(), PackedInt32Array([pm.grid.idx(5, 3)]))
	assert_true(ok)
