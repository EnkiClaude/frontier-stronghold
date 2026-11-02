class_name Building
extends RefCounted
## One placed structure. Buildings are few (hundreds), so plain objects are fine.

enum State { CONSTRUCTING, ACTIVE, RELOCATING }

var id: int
var def: BuildingDef
## Top-left tile of the footprint.
var origin: Vector2i
## Quarter turns (0-3). Odd values swap the footprint width/height.
var rotation: int = 0
var state: State = State.CONSTRUCTING
## Ticks left in CONSTRUCTING / RELOCATING.
var timer: int = 0
## Credits spent on construction and upgrades (basis for refunds).
var invested: int = 0
var placed_tick: int = 0
## Footprint tile indices (cached).
var cells := PackedInt32Array()

# Logistics runtime state.
## Crafter input buffer: item index -> count.
var inv_in: Dictionary = {}
## Crafter output buffer: item index -> count.
var inv_out: Dictionary = {}
## Crafting / mining / swing progress (0..1).
var progress: float = 0.0
var crafting := false
## Item held by an inserter hand or waiting in a drill (-1 = none).
var held: int = -1

# Tower runtime state.
## Rounds loaded.
var ammo: int = 0
var cooldown: float = 0.0
var target_uid: int = -1
var aim_angle: float = 0.0


func size() -> Vector2i:
	return footprint_size(def, rotation)


func center() -> Vector2:
	return Vector2(origin) + Vector2(size()) * 0.5


func is_active() -> bool:
	return state == State.ACTIVE


static func footprint_size(d: BuildingDef, rot: int) -> Vector2i:
	return Vector2i(d.size.y, d.size.x) if rot % 2 == 1 else d.size


static func footprint_cells(grid: WorldGrid, d: BuildingDef, at: Vector2i, rot: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var s := footprint_size(d, rot)
	for x in range(at.x, at.x + s.x):
		for y in range(at.y, at.y + s.y):
			out.append(grid.idx(x, y) if grid.in_bounds(x, y) else -1)
	return out
