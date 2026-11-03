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
## Drill: which front tile to try first next time (round robin).
var output_cursor: int = 0
## Tick of the last item received / handed out (activity indicators).
var last_in_tick: int = -100000
var last_out_tick: int = -100000
## Drill: tile the last item was delivered to.
var last_out_tile: int = -1

## Crafter: index into def.recipes of the active recipe.
var recipe_index: int = 0
## Materials paid at construction (item id -> count), refunded on sale.
var invested_materials: Dictionary = {}
## Generator: seconds of fuel left in the current item.
var fuel_left: float = 0.0
## Generator: true while producing power this tick.
var burning := false
## Electric tower / power consumer: share of demanded power received (0..1).
var power_satisfaction: float = 0.0
## Power network id this building is attached to (-1 = none).
var network: int = -1
## Electric tower: enemies in range, so it draws power (set each tick).
var wants_power := false

# Tower runtime state.
## Rounds loaded.
var ammo: int = 0
## Lifetime statistics.
var kills: int = 0
var rounds_fired: int = 0
var cooldown: float = 0.0
var target_uid: int = -1
var aim_angle: float = 0.0


## Active recipe of a crafter (null for other kinds).
func recipe() -> RecipeDef:
	if def.recipes.is_empty():
		return null
	return def.recipes[clampi(recipe_index, 0, def.recipes.size() - 1)]


## Total items held in inv_out (storage fill level).
func stored_count() -> int:
	var n := 0
	for item: int in inv_out:
		n += inv_out[item]
	return n


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
