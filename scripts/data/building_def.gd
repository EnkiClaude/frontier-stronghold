class_name BuildingDef
extends Resource
## Definition of a placeable structure (res://data/buildings/*.tres).

@export var id: StringName
## Behaviour: core, wall, tower, belt, inserter, drill, pump, crafter,
## storage, recycler, generator, power_node.
@export var kind: StringName = &"wall"
## Toolbar tab: defense, logistics, production, power.
@export var category: StringName = &"defense"
@export var display_name: String = ""
## One or two sentences shown in the info panel.
@export_multiline var description: String = ""
## Footprint in tiles before rotation.
@export var size: Vector2i = Vector2i.ONE
## Blocks enemy movement (walls, towers). Belts and machines do not.
@export var blocks_path: bool = false
## Construction cost in credits.
@export var cost: int = 10
## Extra construction cost in items taken from the stockpile (Core + Storage):
## item id -> count.
@export var material_cost: Dictionary = {}
## Seconds from placement until the structure is active.
@export var build_time: float = 1.0
## Fallback colour when no texture is set.
@export var color: Color = Color.WHITE
## Optional art covering the whole footprint (drawn unrotated, except belts,
## which rotate with the building). Falls back to [member color].
@export var texture: Texture2D
## Optional tower head drawn on top of [member texture], rotated to the aim
## angle. Must point east (+x) in the source image.
@export var turret_texture: Texture2D
@export var sellable: bool = true
@export var relocatable: bool = true
## Order (and hotkey 1-9) within its toolbar tab. 0 = not shown in the toolbar.
@export_range(0, 9) var toolbar_slot: int = 0
## Combat stats if this structure is a tower.
@export var tower: TowerDef
## Whether R rotates it in a meaningful way (shows a direction arrow).
@export var directional: bool = false

@export_group("Logistics")
## Crafter: recipes the player can choose from (first = default).
@export var recipes: Array[RecipeDef] = []
## Drill / pump: seconds per produced item.
@export var mining_time: float = 1.0
## Pump: item produced while touching water.
@export var pump_item: StringName = &""
## Storage / Core: total items it can hold (0 = unlimited).
@export var storage_capacity: int = 0
## Recycler: seconds per recycled item.
@export var recycle_time: float = 0.5
## Inserter: seconds per transfer.
@export var swing_time: float = 0.6
## Crafter: max units of each input buffered.
@export var input_limit: int = 10
## Crafter: max total items held in the output buffer.
@export var output_limit: int = 20

@export_group("Power")
## Generator: power produced while burning fuel.
@export var power_output: float = 0.0
## Generator: fuel item and seconds one item lasts.
@export var fuel_item: StringName = &""
@export var fuel_time: float = 5.0
## Power node: buildings within this distance (tiles, centre to footprint) are connected.
@export var supply_radius: float = 0.0
## Power node: links to other nodes within this distance (tiles).
@export var link_range: float = 0.0
