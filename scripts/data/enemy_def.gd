class_name EnemyDef
extends Resource
## Definition of an enemy type (res://data/enemies/*.tres).

@export var id: StringName
@export var display_name: String = ""
@export var hp: float = 30.0
## Movement speed in tiles per second.
@export var speed: float = 1.5
## Flat damage reduction per hit (a hit always deals at least 20%).
@export var armor: float = 0.0
## Core HP removed when this enemy reaches the Core.
@export var core_damage: int = 1
## Credits awarded on kill.
@export var reward: int = 2
## Tint (multiplied with [member texture]) and fallback colour.
@export var color: Color = Color.RED
## Optional sprite, ideally light/greyscale so [member color] can tint it.
@export var texture: Texture2D
## Visual radius in tiles.
@export var radius: float = 0.3
@export_group("Spawning")
## Relative chance among unlocked enemy types.
@export var spawn_weight: float = 1.0
## Seconds after preparation ends before this type starts appearing.
@export var unlock_time: float = 0.0
