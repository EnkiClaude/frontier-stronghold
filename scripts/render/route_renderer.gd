class_name RouteRenderer
extends Node2D
## Draws the enemy route lines from [BuildController] underneath enemies and
## buildings' effects, so the overlay never hides units.

var controller: BuildController


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if controller != null:
		controller.draw_routes(self)
