class_name DebugOverlay
extends CanvasLayer
## F3 debug panel: frame rate, simulation timing and the hovered tile.
##
## Pulls its data from [member stats_provider] (a Callable returning a
## Dictionary of label -> value) a few times per second to stay cheap.

const REFRESH_INTERVAL := 0.25

var stats_provider: Callable
var _label: Label
var _timer := 0.0


func _ready() -> void:
	layer = 100
	var panel := PanelContainer.new()
	panel.position = Vector2(8, 8)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	panel.add_child(_label)
	add_child(panel)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or not visible or not stats_provider.is_valid():
		return
	_timer = REFRESH_INTERVAL
	var stats: Dictionary = stats_provider.call()
	var lines := PackedStringArray()
	for key in stats:
		lines.append("%s: %s" % [key, stats[key]])
	_label.text = "\n".join(lines)
