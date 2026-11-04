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
var _colors := PackedColorArray()
## Items are not drawn when a tile is smaller than this on screen (pixels).
const HIDE_BELOW_PX := 7.0


func _ready() -> void:
	for def in sim.reg.items:
		_icons.append(DataRegistry.art(def.icon))
		_colors.append(def.color)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var belts := sim.belts
	belts.ensure_built()
	var xf := get_global_transform_with_canvas()
	var px_per_tile := xf.get_scale().x
	if px_per_tile < HIDE_BELOW_PX:
		return  # Zoomed far out: items would be sub-pixel noise.
	var view := (xf.affine_inverse() * get_viewport_rect()).grow(1.0)
	var min_size := MIN_SCREEN_PX / maxf(px_per_tile, 0.001)
	var icon_s := maxf(ICON_SIZE, min_size)
	var rect_s := maxf(ITEM_SIZE, min_size)
	var colors := _colors
	for line in belts.lines:
		var n := line.items.size()
		if n == 0 or not view.intersects(line.bounds):
			continue
		var whole := view.encloses(line.bounds)
		var pos := line.pos
		var items := line.items
		var centers := line.centers
		var dirs := line.dirs
		var last := centers.size() - 1
		for i in n:
			var p := pos[i]
			var ti := clampi(int(p), 0, last)
			var at := centers[ti] + dirs[ti] * (p - ti - 0.5)
			if not whole and not view.has_point(at):
				continue
			var item := items[i]
			var icon := _icons[item]
			if icon != null:
				draw_texture_rect(icon, Rect2(at.x - icon_s * 0.5, at.y - icon_s * 0.5, icon_s, icon_s), false)
			else:
				draw_rect(Rect2(at.x - rect_s * 0.5, at.y - rect_s * 0.5, rect_s, rect_s), colors[item])
