extends TestCase

const LUT_WALK := 0
const LUT_WALL := 1


func _lut() -> PackedByteArray:
	var lut := PackedByteArray()
	lut.resize(256)
	lut.fill(0)
	lut[LUT_WALK] = 1
	return lut


func test_distances_on_open_grid() -> void:
	var g := WorldGrid.new(5, 5)
	var dist := Reachability.distance_field(g, _lut(), PackedInt32Array([g.idx(0, 0)]))
	assert_eq(dist[g.idx(0, 0)], 0)
	assert_eq(dist[g.idx(4, 4)], 8)
	assert_eq(dist[g.idx(2, 1)], 3)


func test_wall_blocks_and_detours() -> void:
	var g := WorldGrid.new(5, 5)
	# Vertical wall at x=2 with a gap at y=4.
	for y in 4:
		g.set_terrain(2, y, LUT_WALL)
	var dist := Reachability.distance_field(g, _lut(), PackedInt32Array([g.idx(0, 0)]))
	assert_eq(dist[g.idx(2, 0)], -1, "wall tiles are unreachable")
	assert_eq(dist[g.idx(4, 0)], 12, "path must detour through the gap")


func test_fully_blocked_is_unreachable() -> void:
	var g := WorldGrid.new(5, 5)
	for y in 5:
		g.set_terrain(2, y, LUT_WALL)
	assert_false(Reachability.all_reachable(g, _lut(), PackedInt32Array([g.idx(0, 2)]), PackedInt32Array([g.idx(4, 2)])))


func test_no_wraparound_between_columns() -> void:
	# In column-major storage, (0, h-1) and (1, 0) are adjacent in memory but not in the world.
	var g := WorldGrid.new(2, 3)
	g.set_terrain(0, 0, LUT_WALL)
	g.set_terrain(0, 1, LUT_WALL)
	g.set_terrain(1, 1, LUT_WALL)
	g.set_terrain(1, 2, LUT_WALL)
	var dist := Reachability.distance_field(g, _lut(), PackedInt32Array([g.idx(0, 2)]))
	assert_eq(dist[g.idx(1, 0)], -1, "(0,2) and (1,0) must not be neighbours")
