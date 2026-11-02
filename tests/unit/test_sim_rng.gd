extends TestCase


func test_same_seed_same_sequence() -> void:
	var a := SimRng.new(42)
	var b := SimRng.new(42)
	for i in 20:
		assert_eq(a.next_int_range(0, 1000), b.next_int_range(0, 1000))


func test_forks_are_stable_and_independent() -> void:
	var a := SimRng.new(7).fork("enemies")
	var b := SimRng.new(7).fork("enemies")
	var c := SimRng.new(7).fork("towers")
	var same := true
	var differs := false
	for i in 10:
		var va := a.next_seed()
		same = same and va == b.next_seed()
		differs = differs or va != c.next_seed()
	assert_true(same, "same fork name must give same stream")
	assert_true(differs, "different fork names must give different streams")
