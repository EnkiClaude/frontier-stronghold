class_name TerrainDef
extends Resource
## Definition of one terrain type. Instances live in res://data/terrain/*.tres.

## Stable string identifier used by code and other definitions.
@export var id: StringName
## Compact numeric code stored in the world grid (0-255). Must be unique.
@export_range(0, 255) var code: int = 0
@export var display_name: String = ""
## Placeholder render colour until real art exists.
@export var color: Color = Color.MAGENTA
## Enemies can walk on it (before buildings are considered).
@export var walkable: bool = true
## Structures can be placed on it.
@export var buildable: bool = true
## Can be excavated or blasted by the player.
@export var destructible: bool = false
## A mining drill can extract [member yield_item] from it.
@export var drillable: bool = false
## Item produced by drilling or excavating this tile.
@export var yield_item: StringName = &""
## Terrain id this tile turns into when excavated.
@export var becomes: StringName = &""
