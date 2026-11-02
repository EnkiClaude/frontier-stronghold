extends TestCase

var changed: Array[Vector2i] = []


func test_index_roundtrip() -> void:
	var g := WorldGrid.new(10, 6)
	assert_eq(g.size(), 60)
	assert_eq(g.idx(3, 4), 3 * 6 + 4)
	assert_eq(g.cell_of(g.idx(9, 5)), Vector2i(9, 5))


func test_bounds() -> void:
	var g := WorldGrid.new(4, 3)
	assert_true(g.in_bounds(0, 0))
	assert_true(g.in_bounds(3, 2))
	assert_false(g.in_bounds(4, 0))
	assert_false(g.in_bounds(0, -1))


func test_extend_east_keeps_existing_cells() -> void:
	var g := WorldGrid.new(4, 3)
	g.set_terrain(2, 1, 7)
	var before := g.idx(2, 1)
	g.extend_east(5)
	assert_eq(g.width, 9)
	assert_eq(g.idx(2, 1), before, "indices must be stable when growing east")
	assert_eq(g.get_terrain(2, 1), 7)
	assert_eq(g.get_terrain(8, 2), 0, "new columns start as code 0")


func test_set_terrain_emits_once() -> void:
	var g := WorldGrid.new(4, 4)
	g.terrain_changed.connect(func(c: Vector2i) -> void: changed.append(c))
	g.set_terrain(1, 2, 3)
	g.set_terrain(1, 2, 3)
	assert_eq(changed.size(), 1, "no signal when value is unchanged")
	assert_eq(changed[0], Vector2i(1, 2))


func test_world_cell_conversion() -> void:
	var px := WorldGrid.TILE_PX
	assert_eq(WorldGrid.world_to_cell(Vector2(px * 3 + 1, px * 2 - 1)), Vector2i(3, 1))
	assert_eq(WorldGrid.world_to_cell(Vector2(-1, -1)), Vector2i(-1, -1))
	assert_eq(WorldGrid.cell_to_world_center(Vector2i(0, 0)), Vector2(px, px) * 0.5)
