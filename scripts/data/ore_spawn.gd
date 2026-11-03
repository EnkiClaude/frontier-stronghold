class_name OreSpawn
extends Resource
## World-generation rule for one surface ore deposit type.

## Terrain id to place (must be a drillable TerrainDef).
@export var terrain_id: StringName
## Noise frequency for natural patches (higher = smaller, more frequent).
@export var frequency: float = 0.06
## Noise value above which the ore appears (-1..1, higher = rarer).
@export_range(-1.0, 1.0) var threshold: float = 0.6
## Radius of the guaranteed patches near the Core (0 = none).
@export var starter_patch_radius: int = 0
## How many guaranteed patches near the Core.
@export var starter_patches: int = 1
