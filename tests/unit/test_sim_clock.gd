extends TestCase

var ticks: Array[int] = []


func _on_tick(t: int) -> void:
	ticks.append(t)


func test_runs_fixed_ticks_per_second() -> void:
	var clock := SimClock.new(30)
	for i in 60:
		clock.advance(1.0 / 60.0, _on_tick)
	assert_true(ticks.size() >= 29 and ticks.size() <= 30, "got %d ticks" % ticks.size())
	assert_eq(clock.tick_count, ticks.size())


func test_paused_runs_nothing() -> void:
	var clock := SimClock.new(30)
	clock.paused = true
	assert_eq(clock.advance(1.0, _on_tick), 0)
	assert_eq(ticks.size(), 0)


func test_speed_multiplies_ticks() -> void:
	var clock := SimClock.new(30)
	clock.speed = 2.0
	for i in 60:
		clock.advance(1.0 / 60.0, _on_tick)
	assert_true(ticks.size() >= 59 and ticks.size() <= 60, "got %d ticks" % ticks.size())


func test_long_frame_is_capped() -> void:
	var clock := SimClock.new(30)
	clock.max_ticks_per_frame = 8
	assert_eq(clock.advance(10.0, _on_tick), 8)
	assert_true(clock.dropped_time > 9.0, "dropped %f" % clock.dropped_time)
	assert_true(clock.alpha < 1.0)


func test_step_ignores_pause() -> void:
	var clock := SimClock.new(30)
	clock.paused = true
	clock.step(5, _on_tick)
	assert_eq(ticks, [1, 2, 3, 4, 5] as Array[int])
