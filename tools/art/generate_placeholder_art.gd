extends SceneTree
## Generates the self-made sci-fi placeholder art (CC0, made for this project).
##
##   godot --headless --path . -s res://tools/art/generate_placeholder_art.gd
##
## Deterministic: same code -> same PNGs. Everything is drawn with antialiased
## signed-distance shapes at 64 px per tile (buildings: footprint x 64 px).
## Replace individual files with real CC0 art later by pointing the data
## definitions at the new textures; nothing else needs to change.

const OUT := "res://assets/sprites/selfmade_scifi_placeholders/"
const T := 64

# Palette.
const METAL_DARK := Color(0.11, 0.13, 0.17)
const METAL := Color(0.2, 0.23, 0.29)
const METAL_LIGHT := Color(0.33, 0.38, 0.46)
const CYAN := Color(0.3, 0.92, 1.0)
const AMBER := Color(1.0, 0.72, 0.2)
const HAZARD := Color(0.98, 0.62, 0.1)


class Canvas:
	extends RefCounted
	var img: Image
	var w: int
	var h: int

	func _init(width: int, height: int, bg: Color = Color(0, 0, 0, 0)) -> void:
		w = width
		h = height
		img = Image.create(width, height, false, Image.FORMAT_RGBA8)
		img.fill(bg)

	func blend(x: int, y: int, c: Color, a: float) -> void:
		a = clampf(a * c.a, 0.0, 1.0)
		if a <= 0.0 or x < 0 or y < 0 or x >= w or y >= h:
			return
		var d := img.get_pixel(x, y)
		var out_a := a + d.a * (1.0 - a)
		var r := (c.r * a + d.r * d.a * (1.0 - a)) / out_a
		var g := (c.g * a + d.g * d.a * (1.0 - a)) / out_a
		var b := (c.b * a + d.b * d.a * (1.0 - a)) / out_a
		img.set_pixel(x, y, Color(r, g, b, out_a))

	## Fills the shape described by [param sdf] (func(p: Vector2) -> float, <0 inside).
	func shape(sdf: Callable, c: Color, soft: float = 1.0) -> void:
		for y in h:
			for x in w:
				var d: float = sdf.call(Vector2(x + 0.5, y + 0.5))
				if d < soft:
					blend(x, y, c, clampf(0.5 - d / soft, 0.0, 1.0))

	func glow(center: Vector2, radius: float, c: Color, power: float = 2.0) -> void:
		for y in h:
			for x in w:
				var t := 1.0 - Vector2(x + 0.5, y + 0.5).distance_to(center) / radius
				if t > 0.0:
					blend(x, y, c, pow(t, power))

	## Multiplies brightness by a seamless noise texture (strength 0..1).
	func noise(seed_value: int, freq: float, strength: float) -> void:
		var n := FastNoiseLite.new()
		n.seed = seed_value
		n.frequency = freq
		n.fractal_octaves = 3
		var nimg := n.get_seamless_image(w, h)
		for y in h:
			for x in w:
				var c := img.get_pixel(x, y)
				var k := 1.0 + (nimg.get_pixel(x, y).r - 0.5) * 2.0 * strength
				img.set_pixel(x, y, Color(c.r * k, c.g * k, c.b * k, c.a))


# --- SDF helpers ---------------------------------------------------------------

static func circle(c: Vector2, r: float) -> Callable:
	return func(p: Vector2) -> float: return p.distance_to(c) - r


static func ring(c: Vector2, r: float, width: float) -> Callable:
	return func(p: Vector2) -> float: return absf(p.distance_to(c) - r) - width * 0.5


static func box(c: Vector2, half: Vector2, rad: float = 0.0) -> Callable:
	return func(p: Vector2) -> float:
		var q := (p - c).abs() - half + Vector2(rad, rad)
		return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - rad


static func segment(a: Vector2, b: Vector2, width: float) -> Callable:
	return func(p: Vector2) -> float:
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		return p.distance_to(a + ab * t) - width * 0.5


## Regular polygon with [param n] sides and apothem [param r].
static func ngon(c: Vector2, r: float, n: int, rot: float = 0.0) -> Callable:
	return func(p: Vector2) -> float:
		var d := -INF
		for k in n:
			var normal := Vector2.from_angle(rot + TAU * k / n)
			d = maxf(d, (p - c).dot(normal) - r)
		return d


static func outline(sdf: Callable, width: float) -> Callable:
	return func(p: Vector2) -> float: return absf(sdf.call(p)) - width * 0.5


# --- Generation ----------------------------------------------------------------

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save("terrain_ground", ground())
	_save("terrain_rock", rock())
	_save("terrain_bedrock", bedrock())
	_save("terrain_water", water())
	_save("terrain_ore_iron", ore(Color(0.6, 0.75, 1.0), 11, true))
	_save("terrain_ore_copper", ore(Color(1.0, 0.55, 0.22), 12, true))
	_save("terrain_ore_coal", ore(Color(0.34, 0.34, 0.38), 13, false))
	_save("terrain_ore_stone", ore(Color(0.72, 0.68, 0.58), 14, false))
	_save("building_core", core())
	_save("building_wall", wall())
	_save("building_chain_gun_base", gun_base())
	_save("building_chain_gun_turret", gun_turret())
	_save("building_conveyor_belt", belt())
	_save("building_inserter", inserter())
	_save("building_mining_drill", drill())
	_save("building_smelter", smelter())
	_save("building_ammo_factory", ammo_factory())
	_save("enemy_swarm", enemy_swarm())
	_save("enemy_armoured", enemy_armoured())
	_save("item_iron_ore", item_chunk(Color(0.58, 0.66, 0.85)))
	_save("item_copper_ore", item_chunk(Color(0.95, 0.52, 0.22)))
	_save("item_coal", item_chunk(Color(0.15, 0.15, 0.17)))
	_save("item_stone", item_chunk(Color(0.74, 0.7, 0.6)))
	_save("item_iron_plate", item_plate())
	_save("item_ammo_magazine", item_magazine())
	print("Art generated in ", OUT)
	quit(0)


func _save(file_name: String, c: Canvas) -> void:
	var err := c.img.save_png(OUT + file_name + ".png")
	if err != OK:
		push_error("Could not save %s: %d" % [file_name, err])


# Terrain ------------------------------------------------------------------------

func ground() -> Canvas:
	var c := Canvas.new(T, T, Color(0.1, 0.125, 0.16))
	c.noise(1, 0.06, 0.12)
	# Floor panel seams (tile edge + half seam) and bolts: reads as a futuristic deck.
	c.shape(outline(box(Vector2(32, 32), Vector2(31.5, 31.5)), 1.4), Color(0.06, 0.08, 0.1))
	c.shape(segment(Vector2(32, 4), Vector2(32, 60), 0.8), Color(0.07, 0.09, 0.12, 0.7))
	for p in [Vector2(5, 5), Vector2(59, 5), Vector2(5, 59), Vector2(59, 59)]:
		c.shape(circle(p, 1.6), Color(0.2, 0.25, 0.32))
	c.shape(segment(Vector2(10, 58), Vector2(22, 58), 1.2), Color(0.25, 0.75, 0.85, 0.25))
	return c


func rock() -> Canvas:
	var c := Canvas.new(T, T, Color(0.27, 0.23, 0.35))
	c.noise(2, 0.09, 0.35)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 9:
		var a := Vector2(rng.randf_range(0, T), rng.randf_range(0, T))
		var b := a + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(8, 20)
		c.shape(segment(a, b, 1.3), Color(0.36, 0.33, 0.44, 0.8) if i % 2 == 0 else Color(0.08, 0.07, 0.1, 0.8))
	for i in 3:
		var p := Vector2(rng.randf_range(10, 54), rng.randf_range(10, 54))
		c.glow(p, 9, Color(0.65, 0.4, 1.0, 0.35))
		c.shape(ngon(p, 2.5, 6, rng.randf()), Color(0.8, 0.6, 1.0, 0.9))
	return c


func bedrock() -> Canvas:
	var c := Canvas.new(T, T, Color(0.04, 0.045, 0.06))
	c.noise(3, 0.1, 0.2)
	for k in 4:
		c.shape(segment(Vector2(k * 16 - 8, 64), Vector2(k * 16 + 24, 0), 3.0), Color(0.09, 0.08, 0.04, 0.9))
	return c


func water() -> Canvas:
	var c := Canvas.new(T, T, Color(0.03, 0.11, 0.2))
	c.noise(4, 0.05, 0.25)
	for k in 4:
		var y := 8.0 + k * 16.0
		for x in range(0, T, 2):
			var y1 := y + sin(x * TAU / 32.0) * 2.5
			var y2 := y + sin((x + 2) * TAU / 32.0) * 2.5
			c.shape(segment(Vector2(x, y1), Vector2(x + 2, y2), 1.2), Color(0.25, 0.75, 0.95, 0.35))
	return c


func ore(col: Color, seed_value: int, glowing: bool) -> Canvas:
	var c := ground()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in 6:
		var p := Vector2(rng.randf_range(10, 54), rng.randf_range(10, 54))
		var r := rng.randf_range(4.0, 7.5)
		if glowing:
			c.glow(p, r * 2.6, Color(col, 0.45))
		c.shape(ngon(p, r, 6, rng.randf()), col.darkened(0.25))
		c.shape(ngon(p - Vector2(1, 1), r * 0.55, 6, rng.randf()), col.lightened(0.35))
	return c


# Buildings ----------------------------------------------------------------------

func _housing(size: int) -> Canvas:
	var c := Canvas.new(size, size)
	var m := size * 0.5
	c.shape(box(Vector2(m, m), Vector2(m - 3, m - 3), 9), METAL)
	c.shape(outline(box(Vector2(m, m), Vector2(m - 3, m - 3), 9), 2.0), METAL_LIGHT)
	c.shape(box(Vector2(m, m), Vector2(m - 12, m - 12), 6), METAL_DARK)
	for p in [Vector2(10, 10), Vector2(size - 10, 10), Vector2(10, size - 10), Vector2(size - 10, size - 10)]:
		c.shape(circle(p, 2.5), METAL_LIGHT)
	return c


func core() -> Canvas:
	var s := 3 * T
	var m := Vector2(s, s) * 0.5
	var c := Canvas.new(s, s)
	c.shape(ngon(m, 90, 6, PI / 6), METAL)
	c.shape(outline(ngon(m, 90, 6, PI / 6), 3), METAL_LIGHT)
	c.shape(ngon(m, 70, 6, PI / 6), METAL_DARK)
	for k in 6:
		var a := TAU * k / 6.0
		c.shape(segment(m + Vector2.from_angle(a) * 40, m + Vector2.from_angle(a) * 82, 6), METAL_LIGHT)
	c.glow(m, 70, Color(CYAN, 0.6), 1.6)
	c.shape(ring(m, 40, 4), CYAN)
	c.shape(circle(m, 24), Color(0.6, 1.0, 1.0))
	c.shape(circle(m, 12), Color(1, 1, 1))
	return c


func wall() -> Canvas:
	var c := Canvas.new(T, T)
	c.shape(box(Vector2(32, 32), Vector2(31, 31), 5), METAL)
	c.shape(box(Vector2(32, 30), Vector2(27, 25), 4), METAL_LIGHT.darkened(0.15))
	c.shape(box(Vector2(32, 33), Vector2(27, 25), 4), METAL.darkened(0.1))
	c.shape(outline(box(Vector2(32, 32), Vector2(31, 31), 5), 1.5), METAL_DARK)
	c.glow(Vector2(32, 32), 22, Color(CYAN, 0.35))
	c.shape(box(Vector2(32, 32), Vector2(20, 2.5), 2), CYAN)
	return c


func gun_base() -> Canvas:
	var s := 2 * T
	var m := Vector2(s, s) * 0.5
	var c := Canvas.new(s, s)
	c.shape(ngon(m, 58, 8, PI / 8), METAL)
	c.shape(outline(ngon(m, 58, 8, PI / 8), 2.5), METAL_LIGHT)
	c.shape(ring(m, 44, 7), HAZARD)
	for k in 12:
		var a := TAU * k / 12.0
		c.shape(segment(m + Vector2.from_angle(a) * 40, m + Vector2.from_angle(a + 0.15) * 48, 4), Color(0.08, 0.08, 0.08))
	c.shape(circle(m, 36), METAL_DARK)
	for k in 8:
		c.shape(circle(m + Vector2.from_angle(TAU * k / 8.0 + PI / 8) * 52, 2.5), METAL_LIGHT)
	return c


func gun_turret() -> Canvas:
	var s := 2 * T
	var c := Canvas.new(s, s)
	var m := Vector2(s, s) * 0.5
	for y in [m.y - 8.0, m.y + 8.0]:
		c.shape(box(Vector2(96, y), Vector2(26, 4.5), 2), Color(0.14, 0.15, 0.18))
		c.shape(box(Vector2(120, y), Vector2(3, 5.5), 1.5), METAL_LIGHT)
	c.shape(box(m + Vector2(-4, 0), Vector2(28, 22), 9), METAL_LIGHT)
	c.shape(box(m + Vector2(-4, 2), Vector2(24, 17), 7), METAL)
	c.shape(outline(box(m + Vector2(-4, 0), Vector2(28, 22), 9), 2), METAL_DARK)
	c.glow(m + Vector2(-12, 0), 12, Color(CYAN, 0.6))
	c.shape(circle(m + Vector2(-12, 0), 4), CYAN)
	return c


func belt() -> Canvas:
	var c := Canvas.new(T, T, Color(0.09, 0.1, 0.12))
	for x in range(0, T, 8):
		c.shape(segment(Vector2(x + 4, 9), Vector2(x + 4, 55), 1.5), Color(0.14, 0.15, 0.18))
	c.shape(box(Vector2(32, 3.5), Vector2(32, 3.5)), METAL_LIGHT)
	c.shape(box(Vector2(32, 60.5), Vector2(32, 3.5)), METAL_LIGHT)
	for x0 in [18.0, 36.0]:
		c.shape(segment(Vector2(x0, 20), Vector2(x0 + 11, 32), 4), Color(AMBER, 0.85))
		c.shape(segment(Vector2(x0 + 11, 32), Vector2(x0, 44), 4), Color(AMBER, 0.85))
	return c


func inserter() -> Canvas:
	var c := Canvas.new(T, T)
	c.shape(box(Vector2(32, 32), Vector2(22, 22), 5), Color(0.1, 0.1, 0.1))
	for k in 6:
		c.shape(segment(Vector2(10 + k * 9, 10), Vector2(4 + k * 9, 18), 3), HAZARD)
		c.shape(segment(Vector2(10 + k * 9, 46), Vector2(4 + k * 9, 54), 3), HAZARD)
	c.shape(box(Vector2(32, 32), Vector2(16, 16), 4), METAL)
	c.shape(circle(Vector2(32, 32), 8), METAL_LIGHT)
	return c


func drill() -> Canvas:
	var s := 2 * T
	var m := Vector2(s, s) * 0.5
	var c := _housing(s)
	c.shape(circle(m, 40), Color(0.13, 0.14, 0.17))
	c.shape(ring(m, 40, 3), METAL_LIGHT)
	for k in 3:
		var a := TAU * k / 3.0
		c.shape(segment(m, m + Vector2.from_angle(a) * 36, 7), METAL_LIGHT.darkened(0.1))
	c.glow(m, 16, Color(AMBER, 0.7))
	c.shape(circle(m, 7), AMBER)
	return c


func smelter() -> Canvas:
	var s := 2 * T
	var c := _housing(s)
	c.glow(Vector2(64, 74), 46, Color(1.0, 0.45, 0.1, 0.45))
	c.shape(box(Vector2(64, 74), Vector2(30, 18), 5), Color(1.0, 0.45, 0.12))
	c.shape(box(Vector2(64, 78), Vector2(26, 10), 4), Color(1.0, 0.82, 0.4))
	for k in 4:
		c.shape(box(Vector2(34 + k * 20, 34), Vector2(6, 3), 1.5), Color(0.06, 0.06, 0.07))
	return c


func ammo_factory() -> Canvas:
	var s := 2 * T
	var c := _housing(s)
	c.shape(box(Vector2(64, 60), Vector2(42, 14), 3), Color(0.08, 0.09, 0.1))
	for k in 3:
		var x := 40.0 + k * 24.0
		c.shape(box(Vector2(x, 62), Vector2(7, 10), 2), Color(0.85, 0.62, 0.18))
		c.shape(box(Vector2(x, 50), Vector2(5, 3), 2), Color(0.98, 0.85, 0.45))
	for k in 7:
		c.shape(segment(Vector2(22 + k * 13, 100), Vector2(14 + k * 13, 110), 4), HAZARD)
	return c


# Enemies (light greyscale, tinted by EnemyDef.color) --------------------------------

func enemy_swarm() -> Canvas:
	var c := Canvas.new(T, T)
	var m := Vector2(32, 32)
	c.glow(m, 31, Color(1, 1, 1, 0.35))
	for k in 8:
		var a := TAU * k / 8.0
		c.shape(segment(m + Vector2.from_angle(a) * 12, m + Vector2.from_angle(a) * 27, 5.0 - (k % 2) * 2.0), Color(0.75, 0.75, 0.75))
	c.shape(circle(m, 15), Color(0.95, 0.95, 0.95))
	c.shape(ring(m, 15, 2), Color(0.55, 0.55, 0.55))
	c.shape(circle(m, 6), Color(0.15, 0.15, 0.15))
	c.shape(circle(m - Vector2(1.5, 1.5), 2.2), Color(1, 1, 1))
	return c


func enemy_armoured() -> Canvas:
	var c := Canvas.new(T, T)
	var m := Vector2(32, 32)
	c.glow(m, 31, Color(1, 1, 1, 0.3))
	c.shape(ngon(m, 27, 6, PI / 6), Color(0.72, 0.72, 0.72))
	c.shape(outline(ngon(m, 27, 6, PI / 6), 2.5), Color(0.4, 0.4, 0.4))
	for k in 6:
		var a := TAU * k / 6.0
		c.shape(segment(m + Vector2.from_angle(a) * 12, m + Vector2.from_angle(a) * 25, 2), Color(0.45, 0.45, 0.45))
	c.shape(ngon(m, 12, 6, PI / 6), Color(0.95, 0.95, 0.95))
	c.shape(circle(m, 4), Color(0.2, 0.2, 0.2))
	return c


# Items (32 px icons) ----------------------------------------------------------------

func item_chunk(col: Color) -> Canvas:
	var c := Canvas.new(32, 32)
	var m := Vector2(16, 16)
	c.shape(ngon(m, 11, 6, 0.3), col.darkened(0.35))
	c.shape(ngon(m + Vector2(-1, -1), 9, 6, 0.3), col)
	c.shape(ngon(m + Vector2(-3, -3), 3.5, 6, 0.3), col.lightened(0.45))
	return c


func item_plate() -> Canvas:
	var c := Canvas.new(32, 32)
	c.shape(box(Vector2(16, 17), Vector2(12, 8), 2), Color(0.45, 0.5, 0.58))
	c.shape(box(Vector2(16, 15), Vector2(12, 8), 2), Color(0.8, 0.85, 0.92))
	c.shape(segment(Vector2(7, 11), Vector2(25, 11), 1.2), Color(1, 1, 1, 0.7))
	return c


func item_magazine() -> Canvas:
	var c := Canvas.new(32, 32)
	c.shape(box(Vector2(16, 19), Vector2(9, 9), 2), Color(0.55, 0.4, 0.12))
	c.shape(box(Vector2(16, 18), Vector2(8, 8), 2), Color(0.88, 0.65, 0.2))
	for k in 3:
		c.shape(box(Vector2(10 + k * 6, 8), Vector2(2, 3.5), 1.8), Color(1.0, 0.88, 0.5))
	return c
