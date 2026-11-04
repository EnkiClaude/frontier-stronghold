class_name BuildingIcons
extends Node
## Toolbar/info-panel icons for buildings, rendered once by the game's own
## [BuildingRenderer] into small off-screen viewports, so icons always match
## what is drawn on the map (art or fallback shapes). View-only.

const PX := 64

var sim: GameSim
var _cache: Dictionary = {}  # BuildingDef or StringName -> Texture2D


func icon_for(def: BuildingDef) -> Texture2D:
	if _cache.has(def):
		return _cache[def]
	var b := Building.new()
	b.def = def
	b.state = Building.State.ACTIVE
	b.origin = Vector2i.ZERO
	b.rotation = 0
	b.aim_angle = -PI * 0.25
	b.progress = 0.15
	if def.tower != null:
		b.ammo = def.tower.magazine_size
	var view := BuildingRenderer.new()
	view.sim = sim
	view.icon_building = b
	var tex := _render(view, Vector2(b.size()))
	_cache[def] = tex
	return tex


## Excavate tool: a rock tile with the excavation frame.
func excavate_icon() -> Texture2D:
	if _cache.has(&"excavate"):
		return _cache[&"excavate"]
	var node := Node2D.new()
	node.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, Vector2.ONE)
		node.draw_rect(r, Color(0.36, 0.27, 0.5))
		for k in 3:
			var c := Vector2(0.25 + 0.25 * k, 0.3 + 0.18 * (k % 2))
			node.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -0.14), c + Vector2(0.09, 0), c + Vector2(0, 0.14), c + Vector2(-0.09, 0)]), Color(0.7, 0.55, 0.95))
		node.draw_rect(r.grow(-0.08), Color(1.0, 0.8, 0.2, 0.95), false, 0.08)
		node.draw_rect(Rect2(Vector2(0.15, 0.74), Vector2(0.45, 0.12)), Color(1.0, 0.8, 0.2)))
	var tex := _render(node, Vector2.ONE)
	_cache[&"excavate"] = tex
	return tex


## Draws [param drawer] (tile units, [param tiles] in size) centred in a
## transparent PX x PX viewport that renders once.
func _render(drawer: Node2D, tiles: Vector2) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = Vector2i(PX, PX)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var holder := Node2D.new()
	var scale_px := (PX - 6.0) / maxf(tiles.x, tiles.y)
	holder.scale = Vector2.ONE * scale_px
	holder.position = (Vector2(PX, PX) - tiles * scale_px) * 0.5
	holder.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	holder.add_child(drawer)
	vp.add_child(holder)
	add_child(vp)
	return vp.get_texture()
