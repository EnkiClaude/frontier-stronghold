class_name ItemDef
extends Resource
## An item that can be carried on belts and stored in buildings (res://data/items).

@export var id: StringName
@export var display_name: String = ""
## Fallback colour for items on belts (used when [member icon] is not set).
@export var color: Color = Color.WHITE
## Optional icon for belts and UI panels.
@export var icon: Texture2D
## Credits paid by a Recycler per item.
@export var value: int = 1
