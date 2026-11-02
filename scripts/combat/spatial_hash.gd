class_name SpatialHash
extends RefCounted
## Uniform bucket grid over enemy positions, rebuilt every tick with a
## counting sort (no allocations after warm-up). Used for tower targeting and
## the no-build radius check.

const BUCKET := 4  # tiles per bucket side

var cols: int = 0
var rows: int = 0
## Bucket b holds items[start[b] .. start[b + 1]).
var start := PackedInt32Array()
var items := PackedInt32Array()
var _bucket_of := PackedInt32Array()


func _init(world_width: int, world_height: int) -> void:
	resize(world_width, world_height)


func resize(world_width: int, world_height: int) -> void:
	cols = (world_width + BUCKET - 1) / BUCKET
	rows = (world_height + BUCKET - 1) / BUCKET
	start.resize(cols * rows + 1)


func rebuild(enemies: EnemyStore) -> void:
	var n := enemies.count
	start.fill(0)
	_bucket_of.resize(n)
	items.resize(n)
	for i in n:
		var bx := clampi(int(enemies.x[i]) / BUCKET, 0, cols - 1)
		var by := clampi(int(enemies.y[i]) / BUCKET, 0, rows - 1)
		var b := bx * rows + by
		_bucket_of[i] = b
		start[b + 1] += 1
	for b in range(1, start.size()):
		start[b] += start[b - 1]
	var fill := start.duplicate()
	for i in n:
		var b := _bucket_of[i]
		items[fill[b]] = i
		fill[b] += 1


## Enemy indices within [param radius] tiles of ([param cx], [param cy]).
func query(enemies: EnemyStore, cx: float, cy: float, radius: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var r2 := radius * radius
	var bx0 := clampi(int(cx - radius) / BUCKET, 0, cols - 1)
	var bx1 := clampi(int(cx + radius) / BUCKET, 0, cols - 1)
	var by0 := clampi(int(cy - radius) / BUCKET, 0, rows - 1)
	var by1 := clampi(int(cy + radius) / BUCKET, 0, rows - 1)
	var ex := enemies.x
	var ey := enemies.y
	for bx in range(bx0, bx1 + 1):
		for by in range(by0, by1 + 1):
			var b := bx * rows + by
			for k in range(start[b], start[b + 1]):
				var i := items[k]
				var dx := ex[i] - cx
				var dy := ey[i] - cy
				if dx * dx + dy * dy <= r2:
					out.append(i)
	return out


## True if any enemy is within [param radius] of the rectangle [param rect] (tiles).
func any_near_rect(enemies: EnemyStore, rect: Rect2, radius: float) -> bool:
	var c := rect.get_center()
	var reach := radius + rect.size.length() * 0.5
	for i in query(enemies, c.x, c.y, reach):
		var px := clampf(enemies.x[i], rect.position.x, rect.end.x)
		var py := clampf(enemies.y[i], rect.position.y, rect.end.y)
		var dx := enemies.x[i] - px
		var dy := enemies.y[i] - py
		if dx * dx + dy * dy <= radius * radius:
			return true
	return false
