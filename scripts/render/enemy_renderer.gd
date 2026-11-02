class_name EnemyRenderer
extends Node2D
## Draws all enemies with two MultiMeshes (bodies + health bars) built from
## packed buffers once per frame. Positions are interpolated between ticks.
## Lives in tile space (1 unit = 1 tile).

## Floats per instance: 8 for a 2D transform + 4 for colour.
const STRIDE := 12
## Enemies never get smaller than this on screen (pixels), so they stay
## visible when zoomed far out.
const MIN_SCREEN_PX := 7.0

var sim: GameSim
var clock: SimClock

## One body MultiMesh per enemy type (each can have its own texture).
var _bodies: Array[MultiMeshInstance2D] = []
var _body_bufs: Array[PackedFloat32Array] = []
var _bars := MultiMeshInstance2D.new()
var _bar_buf := PackedFloat32Array()


func _ready() -> void:
	var fallback := _circle_texture(32)
	for def in sim.reg.enemies:
		var mmi := MultiMeshInstance2D.new()
		mmi.multimesh = make_multimesh()
		var tex := DataRegistry.art(def.texture)
		mmi.texture = tex if tex != null else fallback
		add_child(mmi)
		_bodies.append(mmi)
		_body_bufs.append(PackedFloat32Array())
	_bars.multimesh = make_multimesh()
	add_child(_bars)


func _process(_delta: float) -> void:
	if sim == null:
		return
	var e := sim.enemies
	var n := e.count
	var a := clock.alpha if clock != null and not clock.paused else 1.0
	var types := sim.reg.enemies.size()
	var counts := PackedInt32Array()
	counts.resize(types)
	counts.fill(0)
	for i in n:
		counts[e.type[i]] += 1
	for t in types:
		ensure_capacity(_bodies[t].multimesh, counts[t], _body_bufs[t])
	ensure_capacity(_bars.multimesh, n * 2, _bar_buf)
	counts.fill(0)
	var bars := 0
	var px_per_tile := get_global_transform_with_canvas().get_scale().x
	var min_size := MIN_SCREEN_PX / maxf(px_per_tile, 0.001)
	var show_bars := px_per_tile >= 12.0  # Health bars only when close enough to read.
	for i in n:
		var t := e.type[i]
		var def: EnemyDef = sim.reg.enemies[t]
		var px := lerpf(e.prev_x[i], e.x[i], a)
		var py := lerpf(e.prev_y[i], e.y[i], a)
		# Textured sprites include a glow margin, so draw them a bit larger.
		var s := maxf(def.radius * (2.6 if _bodies[t].texture != null and def.texture != null and DataRegistry.art_enabled else 2.0), min_size)
		write_instance(_body_bufs[t], counts[t], px, py, s, s, def.color)
		counts[t] += 1
		var frac := e.hp[i] / e.max_hp[i]
		if show_bars and frac < 0.999:
			var w := maxf(0.6, def.radius * 2.0)
			var top := py - def.radius - 0.22
			write_instance(_bar_buf, bars, px, top, w, 0.1, Color(0, 0, 0, 0.75))
			write_instance(_bar_buf, bars + 1, px - w * 0.5 * (1.0 - frac), top, w * frac, 0.1, Color(0.35, 0.9, 0.35).lerp(Color(0.95, 0.25, 0.2), 1.0 - frac))
			bars += 2
	for t in types:
		_bodies[t].multimesh.buffer = _body_bufs[t]
		_bodies[t].multimesh.visible_instance_count = counts[t]
	_bars.multimesh.buffer = _bar_buf
	_bars.multimesh.visible_instance_count = bars


static func make_multimesh() -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mm.mesh = quad
	return mm


## Grows the instance count in steps so the buffer is rarely reallocated.
static func ensure_capacity(mm: MultiMesh, needed: int, buf: PackedFloat32Array) -> void:
	if mm.instance_count >= needed and buf.size() == mm.instance_count * STRIDE:
		return
	var cap := maxi(256, mm.instance_count)
	while cap < needed:
		cap *= 2
	mm.instance_count = cap
	buf.resize(cap * STRIDE)


static func write_instance(buf: PackedFloat32Array, i: int, x: float, y: float, sx: float, sy: float, c: Color) -> void:
	var o := i * STRIDE
	buf[o] = sx
	buf[o + 1] = 0.0
	buf[o + 2] = 0.0
	buf[o + 3] = x
	buf[o + 4] = 0.0
	buf[o + 5] = sy
	buf[o + 6] = 0.0
	buf[o + 7] = y
	buf[o + 8] = c.r
	buf[o + 9] = c.g
	buf[o + 10] = c.b
	buf[o + 11] = c.a


static func _circle_texture(px: int) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var r := px * 0.5
	for x in px:
		for y in px:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - d, 0.0, 1.0)
			var shade := 1.0 if d < r - 3.0 else 0.55
			img.set_pixel(x, y, Color(shade, shade, shade, a))
	return ImageTexture.create_from_image(img)
