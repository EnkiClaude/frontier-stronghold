extends TestCase

const E := 0
const S := 1
const W := 2
const N := 3
const DT := 1.0 / 30.0


func _net() -> BeltNetwork:
	return BeltNetwork.new(WorldGrid.new(12, 12))


func _belt(net: BeltNetwork, x: int, y: int, rot: int) -> int:
	var t := net.grid.idx(x, y)
	net.add_belt(t, rot)
	return t


func _run(net: BeltNetwork, seconds: float) -> void:
	for i in int(seconds * 30):
		net.tick(DT)


func _items_on(net: BeltNetwork, x: int, y: int) -> int:
	net.ensure_built()
	var t := net.grid.idx(x, y)
	var line := net.lines[net.line_at[t]]
	var n := 0
	for p in line.pos:
		if int(p) == net.index_at[t]:
			n += 1
	return n


func test_straight_line_is_one_line() -> void:
	var net := _net()
	for x in 5:
		_belt(net, x, 2, E)
	net.ensure_built()
	assert_eq(net.lines.size(), 1)
	assert_eq(net.lines[0].tiles.size(), 5)


func test_items_move_and_stop_at_dead_end() -> void:
	var net := _net()
	for x in 4:
		_belt(net, x, 2, E)
	assert_true(net.insert_at_tile(net.grid.idx(0, 2), 7))
	_run(net, 5.0)
	var line := net.lines[0]
	assert_eq(line.items[0], 7)
	assert_true(line.pos[0] > 3.5 and line.pos[0] < 4.0, "front item waits at the end, got %f" % line.pos[0])


func test_items_compress_with_spacing() -> void:
	var net := _net()
	for x in 4:
		_belt(net, x, 2, E)
	var start := net.grid.idx(0, 2)
	var inserted := 0
	for i in 300:
		if net.insert_at_tile(start, 1, 0.1):
			inserted += 1
		net.tick(DT)
	assert_true(inserted >= 14 and inserted <= 16, "4 tiles hold ~15-16 items, got %d" % inserted)
	var pos := net.lines[0].pos
	for k in range(1, pos.size()):
		assert_true(pos[k] - pos[k - 1] >= BeltNetwork.SPACING - 0.001, "spacing violated at %d" % k)
	assert_false(net.can_insert_at_tile(start, 0.1), "full belt applies back-pressure")


func test_curve_continues_line() -> void:
	var net := _net()
	_belt(net, 0, 0, E)
	_belt(net, 1, 0, E)
	_belt(net, 2, 0, S)
	_belt(net, 2, 1, S)
	_belt(net, 2, 2, S)
	net.ensure_built()
	assert_eq(net.lines.size(), 1, "a curve is part of the same line")
	net.insert_at_tile(net.grid.idx(0, 0), 3)
	_run(net, 4.0)
	assert_eq(_items_on(net, 2, 2), 1)


func test_side_load_merges_into_other_line() -> void:
	var net := _net()
	for x in 6:
		_belt(net, x, 4, E)
	_belt(net, 2, 1, S)
	_belt(net, 2, 2, S)
	_belt(net, 2, 3, S)  # Feeds into the side of (2, 4).
	net.ensure_built()
	assert_eq(net.lines.size(), 2)
	net.insert_at_tile(net.grid.idx(2, 1), 9)
	_run(net, 6.0)
	assert_eq(_items_on(net, 5, 4), 1, "side-loaded item reaches the end of the main line")
	assert_eq(net.item_count(), 1)


func test_opposite_belts_do_not_connect() -> void:
	var net := _net()
	_belt(net, 0, 0, E)
	_belt(net, 1, 0, W)
	net.ensure_built()
	assert_eq(net.lines.size(), 2)
	assert_eq(net.lines[0].out_line, -1)
	assert_eq(net.lines[1].out_line, -1)


func test_loop_keeps_items() -> void:
	var net := _net()
	_belt(net, 0, 0, E)
	_belt(net, 1, 0, S)
	_belt(net, 1, 1, W)
	_belt(net, 0, 1, N)
	net.insert_at_tile(net.grid.idx(0, 0), 1)
	net.insert_at_tile(net.grid.idx(1, 1), 2)
	_run(net, 10.0)
	assert_eq(net.item_count(), 2, "items circulate forever")
	assert_eq(net.lines.size(), 1)


func test_rebuild_preserves_items() -> void:
	var net := _net()
	for x in 3:
		_belt(net, x, 2, E)
	net.insert_at_tile(net.grid.idx(1, 2), 5)
	net.ensure_built()
	_belt(net, 3, 2, E)  # Extend the line.
	assert_eq(_items_on(net, 1, 2), 1, "item stays on its tile")
	net.remove_belt(net.grid.idx(1, 2))
	net.ensure_built()
	assert_eq(net.item_count(), 0, "items on a removed belt are lost")
	assert_eq(net.lines.size(), 2, "removing the middle splits the line")


func test_take_from_tile_respects_filter() -> void:
	var net := _net()
	for x in 3:
		_belt(net, x, 2, E)
	net.insert_at_tile(net.grid.idx(1, 2), 4, 0.2)
	net.insert_at_tile(net.grid.idx(1, 2), 6, 0.7)
	var tile := net.grid.idx(1, 2)
	assert_eq(net.take_from_tile(tile, func(i: int) -> bool: return i == 4), 4)
	assert_eq(net.take_from_tile(tile, func(i: int) -> bool: return i == 4), -1)
	assert_eq(net.take_from_tile(net.grid.idx(0, 2), func(_i: int) -> bool: return true), -1, "empty tile")
	assert_eq(net.item_count(), 1)
