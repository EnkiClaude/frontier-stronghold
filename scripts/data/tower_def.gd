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
## Supply item consumed per shot (Phase 1.5+). Empty = no supply needed.
@export var ammo_item: StringName = &""
