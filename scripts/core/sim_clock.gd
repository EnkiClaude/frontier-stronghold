class_name SimClock
extends RefCounted
## Fixed-timestep simulation clock.
##
## Converts variable frame time into a whole number of fixed ticks so the
## simulation is deterministic and independent of frame rate. Rendering can use
## [member alpha] to interpolate between the last two simulation states.

## Simulation ticks per second at 1x speed.
var tick_rate: int = 30:
	set(value):
		tick_rate = maxi(1, value)
		tick_dt = 1.0 / float(tick_rate)

## Fixed simulation step in seconds (derived from [member tick_rate]).
var tick_dt: float = 1.0 / 30.0

## Game speed multiplier (1x, 2x, 3x ...).
var speed: float = 1.0:
	set(value):
		speed = clampf(value, 0.0, 8.0)

var paused: bool = false

## Upper bound of ticks per frame. Prevents the "spiral of death" when a frame
## takes too long: excess time is dropped and the game slows down instead.
var max_ticks_per_frame: int = 8

## Total ticks simulated since start.
var tick_count: int = 0

## Real time discarded because the simulation could not keep up.
var dropped_time: float = 0.0

var _accum: float = 0.0


func _init(rate: int = 30) -> void:
	tick_rate = rate


## Interpolation factor (0..1) between the previous and current tick.
var alpha: float:
	get:
		return clampf(_accum / tick_dt, 0.0, 1.0)


## Advances the clock by [param delta] real seconds and calls [param on_tick]
## (signature: func(tick: int) -> void) once per fixed tick. Returns the number
## of ticks run.
func advance(delta: float, on_tick: Callable) -> int:
	if paused or speed <= 0.0:
		return 0
	_accum += delta * speed
	var ticks := 0
	while _accum >= tick_dt and ticks < max_ticks_per_frame:
		_accum -= tick_dt
		tick_count += 1
		ticks += 1
		on_tick.call(tick_count)
	if _accum >= tick_dt:
		dropped_time += _accum - fmod(_accum, tick_dt)
		_accum = fmod(_accum, tick_dt)
	return ticks


## Runs exactly [param count] ticks regardless of pause state (tests, headless sim).
func step(count: int, on_tick: Callable) -> void:
	for i in count:
		tick_count += 1
		on_tick.call(tick_count)
