class_name SimRng
extends RefCounted
## Deterministic random number generator.
##
## Every system should use its own stream obtained with [method fork] so that
## adding a random call in one system never shifts the sequence of another.
## Same seed + same inputs = same game.

var seed_value: int
var _rng := RandomNumberGenerator.new()


func _init(seed_in: int = 0) -> void:
	seed_value = seed_in
	_rng.seed = seed_in


## Returns an independent, reproducible stream derived from this seed and a name.
func fork(stream_name: String) -> SimRng:
	return SimRng.new(hash("%d:%s" % [seed_value, stream_name]))


## Returns a fresh 32-bit seed (e.g. for FastNoiseLite).
func next_seed() -> int:
	return _rng.randi()


## Float in [0, 1).
func next_float() -> float:
	return _rng.randf()


func next_float_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


## Integer in [from, to] (inclusive).
func next_int_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)
