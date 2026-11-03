class_name SpawnConfig
extends Resource
## Pacing of enemy spawning (res://data/rules/*.tres).

## Preparation time in seconds before the first enemy appears (skippable).
@export var grace_period: float = 165.0
@export_group("Waves")
## Seconds between small waves.
@export var wave_interval: float = 20.0
## Enemies per nest in a small wave at the start, and extra per minute of waves.
@export var wave_base_size: int = 3
@export var wave_growth_per_minute: float = 0.6
## Quiet seconds after each assault finishes spawning (time to rebuild the maze).
@export var lull_after_assault: float = 20.0
@export_group("Assaults")
## Seconds after preparation ends until the first assault.
@export var assault_first_at: float = 75.0
@export var assault_interval: float = 120.0
## Enemies per nest in the first assault.
@export var assault_base_size: int = 10
## Extra enemies per nest for each later assault.
@export var assault_size_growth: int = 4
## Seconds between enemies within a wave or assault.
@export var assault_spawn_spacing: float = 0.35
@export_group("Scaling")
## Enemy HP multiplier added per minute of game time (0.1 = +10%/min).
@export var hp_growth_per_minute: float = 0.08
