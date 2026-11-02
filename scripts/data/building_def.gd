class_name BuildingDef
extends Resource
## Definition of a placeable structure (res://data/buildings/*.tres).

@export var id: StringName
## Behaviour: core, wall, tower, belt, inserter, drill, crafter.
@export var kind: StringName = &"wall"
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
## Whether R rotates it in a meaningful way (shows a direction arrow).
@export var directional: bool = false

@export_group("Logistics")
## Crafter: the recipe it runs.
@export var recipe: RecipeDef
## Drill: seconds per mined item.
@export var mining_time: float = 1.0
## Inserter: seconds per transfer.
@export var swing_time: float = 0.6
## Crafter: max units of each input buffered.
@export var input_limit: int = 10
## Crafter: max total items held in the output buffer.
@export var output_limit: int = 20
