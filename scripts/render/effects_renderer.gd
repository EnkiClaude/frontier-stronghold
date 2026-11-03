class_name EffectsRenderer
extends Node2D
## Short-lived combat effects for every attack pattern (ADR-007). Purely
## visual; fed from [method GameSim.drain_shots]. Lives in tile space.

const LIFE := {"shot": 0.07, "cone": 0.12, "splash": 0.25, "pulse": 0.3, "chain": 0.18}
const MAX_EFFECTS := 600

var sim: GameSim
var _fx: Array = []  # [event: Dictionary, life_left: float, life: float]


func _process(delta: float) -> void:
	if sim == null:
		return
	for e in sim.drain_shots():
		if _fx.size() < MAX_EFFECTS:
			var life: float = LIFE.get(e["k"], 0.1)
			_fx.append([e, life, life])
	for f in _fx:
		f[1] -= delta
	_fx = _fx.filter(func(f: Array) -> bool: return f[1] > 0.0)
	queue_redraw()


func _draw() -> void:
	for f in _fx:
		var e: Dictionary = f[0]
		var a: float = f[1] / f[2]
		match e["k"]:
			"shot":
				draw_line(e["from"], e["to"], Color(1.0, 0.9, 0.5, a), 0.08)
				draw_circle(e["to"], 0.12, Color(1.0, 0.95, 0.7, a))
			"cone":
				var from: Vector2 = e["from"]
				var pts := PackedVector2Array([from])
				for k in 7:
					var ang: float = e["a"] - e["w"] + e["w"] * 2.0 * k / 6.0
					pts.append(from + Vector2.from_angle(ang) * e["r"] * (0.85 + 0.15 * sin(k * 2.1)))
				draw_colored_polygon(pts, Color(1.0, 0.45, 0.1, 0.35 * a))
			"splash":
				draw_line(e["from"], e["to"], Color(0.6, 0.95, 1.0, 0.6 * a), 0.08)
				draw_circle(e["to"], e["r"] * (1.2 - 0.2 * a), Color(0.55, 0.9, 1.0, 0.25 * a))
				draw_arc(e["to"], e["r"], 0.0, TAU, 24, Color(0.8, 1.0, 1.0, 0.8 * a), 0.06)
			"pulse":
				draw_arc(e["from"], e["r"] * (1.0 - 0.6 * a), 0.0, TAU, 32, Color(0.6, 0.7, 1.0, a), 0.12)
				draw_circle(e["from"], e["r"] * (1.0 - 0.6 * a), Color(0.5, 0.6, 1.0, 0.12 * a))
			"chain":
				var pts: PackedVector2Array = e["pts"]
				for k in range(1, pts.size()):
					draw_polyline(_jagged(pts[k - 1], pts[k], k), Color(0.85, 0.75, 1.0, a), 0.08)


## A zig-zag line between two points (deterministic per segment).
static func _jagged(a: Vector2, b: Vector2, seed_value: int) -> PackedVector2Array:
	var out := PackedVector2Array([a])
	var d := b - a
	var side := Vector2(-d.y, d.x).normalized()
	for k in range(1, 5):
		out.append(a + d * (k / 5.0) + side * 0.25 * sin(seed_value * 3.7 + k * 2.3))
	out.append(b)
	return out
