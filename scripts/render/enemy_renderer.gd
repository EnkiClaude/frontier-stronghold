class_name EnemyRenderer
extends Node2D
## Draws all enemies with plain canvas draw calls, culled to the visible area.
## Lives in tile space (1 unit = 1 tile). Positions are interpolated between ticks.
##
## (Until v0.2.3 this used MultiMeshInstance2D buffers, which rendered nothing
## on the player's Mac with the Compatibility renderer; see ADR-006.)

## Enemies never get smaller than this on screen (pixels), so they stay
## visible when zoomed far out.
const MIN_SCREEN_PX := 9.0
## Health bars only when tiles are at least this big on screen.
const BAR_MIN_PX := 12.0

var sim: GameSim
var clock: SimClock

var _textures: Array[Texture2D] = []
var _fallback: Texture2D
## Soft dark disc behind every enemy (a texture is much cheaper than draw_circle).
var _shadow: Texture2D


func _ready() -> void:
	_fallback = _circle_texture(32)
	_shadow = _disc_texture(32, Color(0, 0, 0, 0.55))
	for def in sim.reg.enemies:
		_textures.append(DataRegistry.art(def.texture))


func _process(_delta: float) -> void:
	queue_redraw()


## Visible area in this node's coordinates (tiles), grown by [param margin].
func visible_rect(margin: float = 1.0) -> Rect2:
	return (get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()).grow(margin)


func _draw() -> void:
	if sim == null:
		return
	var e := sim.enemies
	var a := clock.alpha if clock != null and not clock.paused else 1.0
	var px_per_tile := get_global_transform_with_canvas().get_scale().x
	var min_size := MIN_SCREEN_PX / maxf(px_per_tile, 0.001)
	var show_bars := px_per_tile >= BAR_MIN_PX
	var view := visible_rect()
	var x0 := view.position.x
	var y0 := view.position.y
	var x1 := view.end.x
	var y1 := view.end.y
	for i in e.count:
		var px := lerpf(e.prev_x[i], e.x[i], a)
		var py := lerpf(e.prev_y[i], e.y[i], a)
		if px < x0 or px > x1 or py < y0 or py > y1:
			continue
		var p := Vector2(px, py)
		var t := e.type[i]
		var def: EnemyDef = sim.reg.enemies[t]
		var tex := _textures[t]
		# Textured sprites include a glow margin, so draw them a bit larger.
		var s := maxf(def.radius * (2.6 if tex != null else 2.0), min_size)
		# Dark backing disc: keeps enemies readable on any terrain.
		draw_texture_rect(_shadow, Rect2(p - Vector2(s, s) * 0.42, Vector2(s, s) * 0.84), false)
		var tint := def.color
		if e.slow_t[i] > 0.0:
			tint = tint.lerp(Color(0.55, 0.9, 1.0), 0.55)
		if e.burn_t[i] > 0.0:
			tint = tint.lerp(Color(1.0, 0.6, 0.15), 0.45)
		draw_texture_rect(tex if tex != null else _fallback, Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), false, tint)
		if e.stun_t[i] > 0.0:
			draw_arc(p, s * 0.55, 0.0, TAU, 12, Color(0.85, 0.85, 1.0, 0.9), maxf(0.05, s * 0.08))
		var frac := e.hp[i] / e.max_hp[i]
		if show_bars and frac < 0.999:
			var w := maxf(0.6, def.radius * 2.0)
			var top := p.y - def.radius - 0.28
			draw_rect(Rect2(p.x - w * 0.5, top, w, 0.1), Color(0, 0, 0, 0.75))
			draw_rect(Rect2(p.x - w * 0.5, top, w * frac, 0.1), Color(0.35, 0.9, 0.35).lerp(Color(0.95, 0.25, 0.2), 1.0 - frac))


static func _disc_texture(px: int, col: Color) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var r := px * 0.5
	for x in px:
		for y in px:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			img.set_pixel(x, y, Color(col, col.a * clampf(r - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


static func _circle_texture(px: int) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var r := px * 0.5
	for x in px:
		for y in px:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var alpha := clampf(r - d, 0.0, 1.0)
			var shade := 1.0 if d < r - 3.0 else 0.55
			img.set_pixel(x, y, Color(shade, shade, shade, alpha))
	return ImageTexture.create_from_image(img)
