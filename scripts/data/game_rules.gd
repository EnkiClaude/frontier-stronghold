class_name GameRules
extends Resource
## Global balance and rule numbers (res://data/rules/default_rules.tres).

@export var start_credits: int = 400
@export var core_hp: int = 20
@export_group("Construction")
## Fraction of invested credits refunded on sale.
@export_range(0.0, 1.0) var sell_refund: float = 0.85
## Seconds after placement during which selling refunds 100%.
@export var undo_window: float = 10.0
## Fraction of invested credits paid to relocate.
@export_range(0.0, 1.0) var relocate_fee: float = 0.10
## Seconds a relocated structure is offline.
@export var relocate_time: float = 3.0
## No construction changes within this many tiles of a living enemy.
@export var no_build_radius: float = 6.0
@export_group("Excavation")
@export var excavate_cost: int = 15
@export var excavate_time: float = 2.0
@export_group("Simulation")
@export var tick_rate: int = 30
## Flow field tiles processed per tick during a recompute.
@export var flow_nodes_per_tick: int = 8000
