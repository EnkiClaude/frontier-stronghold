class_name EffectsRenderer
extends Node2D
## Short-lived combat effects (tracers). Purely visual; fed from
## [method GameSim.drain_shots]. Lives in tile space.

const TRACER_LIFE := 0.07
const MAX_TRACERS := 600

var sim: GameSim
var _tracers: Array = []  # [from: Vector2, to: Vector2, life: float]


func _process(delta: float) -> void:
	if sim == null:
		return
	for s in sim.drain_shots():
		if _tracers.size() < MAX_TRACERS:
			_tracers.append([s[0], s[1], TRACER_LIFE])
	for t in _tracers:
		t[2] -= delta
	_tracers = _tracers.filter(func(t: Array) -> bool: return t[2] > 0.0)
	queue_redraw()


func _draw() -> void:
	for t in _tracers:
		var a: float = t[2] / TRACER_LIFE
		draw_line(t[0], t[1], Color(1.0, 0.9, 0.5, a), 0.08)
		draw_circle(t[1], 0.12, Color(1.0, 0.95, 0.7, a))
