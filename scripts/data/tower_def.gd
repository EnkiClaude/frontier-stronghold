class_name TowerDef
extends Resource
## Combat stats of a tower. Referenced by a [BuildingDef].

## Attack range in tiles (measured from the tower centre).
@export var range_tiles: float = 6.0
@export var damage: float = 10.0
## Shots per second.
@export var fire_rate: float = 4.0
@export var damage_type: StringName = &"kinetic"
## Default targeting priority: first, last, strongest, weakest, closest.
@export var targeting: StringName = &"first"
## Attack pattern: single, cone, splash, pulse (around the tower), chain.
@export var attack: StringName = &"single"
## Cone: full opening angle in degrees.
@export var cone_angle: float = 45.0
## Splash / pulse: radius of the area hit (tiles). Pulse uses range_tiles.
@export var splash_radius: float = 1.5
## Chain: extra enemies hit, jump distance (tiles) and damage kept per jump.
@export var chain_count: int = 0
@export var chain_range: float = 3.0
@export var chain_falloff: float = 0.7

@export_group("Status effects")
## Slow: speed multiplier (0.55 = 45% slower) and duration.
@export var slow_factor: float = 1.0
@export var slow_time: float = 0.0
## Burn: damage per second and duration.
@export var burn_dps: float = 0.0
@export var burn_time: float = 0.0
## Stun: seconds the target cannot move.
@export var stun_time: float = 0.0

@export_group("Supply")
## Electric towers: power drawn while active (0 = not electric).
@export var power_draw: float = 0.0
## Supply item that refills this tower. Empty = no supply needed.
@export var ammo_item: StringName = &""
## Rounds added per delivered ammo item.
@export var rounds_per_item: int = 10
## Rounds the tower can hold.
@export var magazine_size: int = 100
## Rounds a newly built tower starts with.
@export var starter_ammo: int = 50
