class_name SpawnConfig
extends Resource
## Pacing of enemy spawning (res://data/rules/*.tres).

## Seconds before the first enemy appears.
@export var grace_period: float = 25.0
@export_group("Trickle")
## Seconds between spawns per nest at the start.
@export var trickle_interval_start: float = 4.0
## Fastest the trickle can become.
@export var trickle_interval_min: float = 1.2
## Seconds to ramp from start to min interval.
@export var trickle_ramp_seconds: float = 600.0
@export_group("Assaults")
## Game time of the first assault (seconds).
@export var assault_first_at: float = 120.0
@export var assault_interval: float = 120.0
## Enemies per nest in the first assault.
@export var assault_base_size: int = 10
## Extra enemies per nest for each later assault.
@export var assault_size_growth: int = 4
## Seconds between enemies within an assault.
@export var assault_spawn_spacing: float = 0.35
@export_group("Scaling")
## Enemy HP multiplier added per minute of game time (0.1 = +10%/min).
@export var hp_growth_per_minute: float = 0.08
