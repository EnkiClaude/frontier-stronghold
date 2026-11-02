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
## Supply item that refills this tower. Empty = no supply needed.
@export var ammo_item: StringName = &""
## Rounds added per delivered ammo item.
@export var rounds_per_item: int = 10
## Rounds the tower can hold.
@export var magazine_size: int = 100
## Rounds a newly built tower starts with.
@export var starter_ammo: int = 50
