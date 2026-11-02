class_name WorldGrid
extends RefCounted
## Tile storage for the whole world.
##
## Layers are flat packed arrays in COLUMN-MAJOR order: index = x * height + y.
## The world only ever grows east (new sectors), so growing appends whole
## columns to the end of each array and existing indices never change.
## See docs/decisions/ADR-002-world-grid-storage.md.

## Size of a chunk in tiles (render batching, dirty tracking, saving).
const CHUNK_SIZE := 32
## World units (pixels at zoom 1) per tile. Only rendering and input use this.
const TILE_PX := 32

signal terrain_changed(cell: Vector2i)

## Column where the enemy nests sit (set by the generator; -1 = east edge).
var nest_column: int = -1
var width: int = 0
var height: int = 0
## Terrain code per tile (see DataRegistry / TerrainDef.code).
var terrain := PackedByteArray()


func _init(initial_width: int = 0, strip_height: int = 0) -> void:
	height = strip_height
	if initial_width > 0:
		extend_east(initial_width)


## Appends [param cols] columns of terrain code 0 to the east edge.
func extend_east(cols: int) -> void:
	var old_size := terrain.size()
	width += cols
	terrain.resize(width * height)
	for i in range(old_size, terrain.size()):
		terrain[i] = 0


func size() -> int:
	return width * height


func idx(x: int, y: int) -> int:
	return x * height + y


func cell_of(index: int) -> Vector2i:
	return Vector2i(index / height, index % height)


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func get_terrain(x: int, y: int) -> int:
	return terrain[x * height + y]


## Sets one tile and notifies listeners. For bulk generation write
## [member terrain] directly and redraw once instead.
func set_terrain(x: int, y: int, code: int) -> void:
	var i := x * height + y
	if terrain[i] == code:
		return
	terrain[i] = code
	terrain_changed.emit(Vector2i(x, y))


func chunk_of(x: int, y: int) -> Vector2i:
	return Vector2i(x / CHUNK_SIZE, y / CHUNK_SIZE)


static func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / TILE_PX), floori(world_pos.y / TILE_PX))


static func cell_to_world_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE_PX
