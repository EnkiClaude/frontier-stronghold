class_name RecipeDef
extends Resource
## A crafting recipe (res://data/recipes). Item ids map to counts.

@export var id: StringName
## Item id -> count consumed per craft.
@export var inputs: Dictionary = {}
## Item id -> count produced per craft.
@export var outputs: Dictionary = {}
## Seconds per craft.
@export var time: float = 1.0
