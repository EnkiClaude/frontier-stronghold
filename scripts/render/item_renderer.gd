class_name ItemRenderer
extends Node2D
## Draws items travelling on belts (icons, or coloured squares without art),
## culled to the visible area. Lives in tile space. See ADR-006.

const ITEM_SIZE := 0.32
const ICON_SIZE := 0.46
## Items never get smaller than this on screen (pixels).
const MIN_SCREEN_PX := 6.0

var sim: GameSim
var _icons: Array[Texture2D] = []


func _ready() -> void:
	for def in sim.reg.items:
		_icons.append(DataRegistry.art(def.icon))


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var belts := sim.belts
	belts.ensure_built()
	var xf := get_global_transform_with_canvas()
	var view := (xf.affine_inverse() * get_viewport_rect()).grow(1.0)
	var min_size := MIN_SCREEN_PX / maxf(xf.get_scale().x, 0.001)
	for line in belts.lines:
		for i in line.items.size():
			var p := belts.item_position(line, i)
			if not view.has_point(p):
				continue
			var item := line.items[i]
			var icon := _icons[item]
			if icon != null:
				var s := maxf(ICON_SIZE, min_size)
				draw_texture_rect(icon, Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), false)
			else:
				var s := maxf(ITEM_SIZE, min_size)
				draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), sim.reg.items[item].color)
