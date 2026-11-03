class_name WorldGenConfig
extends Resource
## Parameters for procedural world generation (res://data/world/*.tres).

@export_group("Size")
## Initial map length in tiles (west -> east).
@export var width: int = 256
## Strip height in tiles (north -> south). Fixed for the whole game.
@export var height: int = 160

@export_group("Zones")
## Columns at the west edge kept clear for the Core and starter base.
@export var core_clear_cols: int = 28
## Width of the clear zone around the enemy nests.
@export var nest_clear_cols: int = 12
## Column of the first enemy nests (the frontier). Later sectors push it east.
@export var nest_column: int = 115

@export_group("Rock")
@export var rock_frequency: float = 0.035
@export_range(-1.0, 1.0) var rock_threshold: float = 0.22
## Extra fractal detail on rock edges.
@export var rock_octaves: int = 3

@export_group("Water")
@export var water_frequency: float = 0.02
@export_range(-1.0, 1.0) var water_threshold: float = 0.62

@export_group("Ores")
## Ore thresholds drop by this much from the Core zone to the east edge, so
## deposits get denser (more ore) the further you expand.
@export var ore_density_gain: float = 0.12
@export var ore_spawns: Array[OreSpawn] = []
