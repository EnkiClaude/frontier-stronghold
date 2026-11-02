class_name BuildingDef
extends Resource
## Definition of a placeable structure (res://data/buildings/*.tres).

@export var id: StringName
@export var display_name: String = ""
## Footprint in tiles before rotation.
@export var size: Vector2i = Vector2i.ONE
## Blocks enemy movement (walls, towers). Belts and machines do not.
@export var blocks_path: bool = false
## Construction cost in credits (Phase 1 currency).
@export var cost: int = 10
## Seconds from placement until the structure is active.
@export var build_time: float = 1.0
@export var color: Color = Color.WHITE
@export var sellable: bool = true
@export var relocatable: bool = true
## Toolbar slot (1-9) and hotkey. 0 = not shown in the toolbar.
@export_range(0, 9) var toolbar_slot: int = 0
## Combat stats if this structure is a tower.
@export var tower: TowerDef
