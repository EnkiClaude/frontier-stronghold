class_name BuildingRenderer
extends Node2D
## Draws buildings, nests and excavation orders. Lives in tile space (parent
## scaled by TILE_PX), so 1 unit = 1 tile. Read-only view of [GameSim].
##
## Uses [member BuildingDef.texture] / [member BuildingDef.turret_texture] when
## art is available and falls back to generated shapes otherwise. Status
## overlays (construction, ammo, empty ✕, Core HP) are always drawn in code.

var sim: GameSim
## Building id highlighted by the build controller (0 = none).
var selected_id: int = 0

const NEST_COLOR := Color(0.55, 0.12, 0.12)
const IN_COLOR := Color(0.35, 0.85, 1.0)
const OUT_COLOR := Color(0.35, 1.0, 0.45)
## Input/output markers are drawn only when tiles are at least this big on screen.
const IO_MIN_PX := 14.0
const OUTLINE := Color(0, 0, 0, 0.55)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
	for at in sim.nests:
		var r := Rect2(at, GameSim.NEST_SIZE)
		draw_circle(r.get_center(), 1.6 + pulse * 0.3, Color(1.0, 0.15, 0.2, 0.18))
		draw_rect(r, NEST_COLOR)
		draw_rect(r.grow(-0.35), NEST_COLOR.lightened(0.25 + pulse * 0.2))
		draw_rect(r, OUTLINE, false, 0.08)
	for tile: int in sim.excavations:
		var c := sim.grid.cell_of(tile)
		var r := Rect2(c, Vector2.ONE)
		var left: float = float(sim.excavations[tile]) / (sim.rules.excavate_time * sim.tick_rate)
		draw_rect(r.grow(-0.08), Color(1.0, 0.8, 0.2, 0.9), false, 0.1)
		draw_rect(Rect2(r.position + Vector2(0.15, 0.75), Vector2(0.7 * (1.0 - left), 0.12)), Color(1.0, 0.8, 0.2))
	var show_io := get_global_transform_with_canvas().get_scale().x >= IO_MIN_PX
	for b: Building in sim.buildings.values():
		var r := Rect2(b.origin, b.size())
		var tex := DataRegistry.art(b.def.texture)
		if tex != null:
			_draw_textured(b, r, tex)
		else:
			_draw_fallback(b, r)
		_draw_overlays(b, r, tex != null)
		if show_io:
			draw_io(self, sim, b)


## Draws where a building takes items in (cyan) and puts them out (green).
## Static so the build controller can reuse it for placement ghosts.
static func draw_io(canvas: CanvasItem, game: GameSim, b: Building) -> void:
	var r := Rect2(b.origin, b.size())
	match b.def.kind:
		&"drill":
			var d := Vector2(BeltNetwork.DIRS[b.rotation % 4])
			for t in game.factory.front_tiles(b):
				io_arrow(canvas, Vector2(game.grid.cell_of(t)) + Vector2(0.5, 0.5) - d * 0.22, d, OUT_COLOR)
		&"inserter":
			var d := Vector2(BeltNetwork.DIRS[b.rotation % 4])
			var c := r.get_center()
			io_arrow(canvas, c - d * 0.78, d, IN_COLOR)
			io_arrow(canvas, c + d * 0.78, d, OUT_COLOR)
		&"crafter":
			var ins: Array = b.def.recipe.inputs.keys()
			var outs: Array = b.def.recipe.outputs.keys()
			for k in ins.size():
				_badge(canvas, game, Rect2(r.position + Vector2(0.08 + k * 0.5, 0.08), Vector2(0.44, 0.44)), StringName(ins[k]), IN_COLOR)
			for k in outs.size():
				_badge(canvas, game, Rect2(Vector2(r.end.x - 0.52 - k * 0.5, r.position.y + 0.08), Vector2(0.44, 0.44)), StringName(outs[k]), OUT_COLOR)
	if b.def.tower != null and b.def.tower.ammo_item != &"":
		_badge(canvas, game, Rect2(r.position + Vector2(0.06, 0.06), Vector2(0.42, 0.42)), b.def.tower.ammo_item, IN_COLOR)


## Small triangle at [param at] pointing along [param dir].
static func io_arrow(canvas: CanvasItem, at: Vector2, dir: Vector2, col: Color) -> void:
	var side := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([at + dir * 0.16, at - dir * 0.12 + side * 0.15, at - dir * 0.12 - side * 0.15])
	canvas.draw_colored_polygon(pts, col)
	canvas.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(0, 0, 0, 0.6), 0.03)


static func _badge(canvas: CanvasItem, game: GameSim, r: Rect2, item_id: StringName, frame: Color) -> void:
	var idx := game.reg.item_index(item_id)
	if idx < 0:
		return
	canvas.draw_rect(r.grow(0.03), Color(0, 0, 0, 0.75))
	var icon := DataRegistry.art(game.reg.items[idx].icon)
	if icon != null:
		canvas.draw_texture_rect(icon, r, false)
	else:
		canvas.draw_rect(r.grow(-0.08), game.reg.items[idx].color)
	canvas.draw_rect(r.grow(0.03), frame, false, 0.04)


## Draws a chevron pointing along [param rotation] inside [param r].
func draw_direction(r: Rect2, rotation: int, col: Color, width: float = 0.08) -> void:
	var c := r.get_center()
	var d := Vector2(BeltNetwork.DIRS[rotation % 4])
	var side := Vector2(-d.y, d.x)
	var s := minf(r.size.x, r.size.y) * 0.22
	draw_polyline(PackedVector2Array([c - d * s + side * s, c + d * s * 0.6, c - d * s - side * s]), col, width)


func _draw_rotated(tex: Texture2D, r: Rect2, angle: float, mod: Color) -> void:
	draw_set_transform(r.get_center(), angle, Vector2.ONE)
	draw_texture_rect(tex, Rect2(-r.size * 0.5, r.size), false, mod)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_textured(b: Building, r: Rect2, tex: Texture2D) -> void:
	var mod := Color(1, 1, 1, 0.45 if not b.is_active() else 1.0)
	if b.def.kind == &"belt":
		_draw_rotated(tex, r, b.rotation * PI * 0.5, mod)
	else:
		draw_texture_rect(tex, r, false, mod)
	var turret := DataRegistry.art(b.def.turret_texture)
	if turret != null:
		_draw_rotated(turret, r, b.aim_angle, mod)


func _draw_fallback(b: Building, r: Rect2) -> void:
	var col := b.def.color
	if not b.is_active():
		col.a = 0.45
	match b.def.kind:
		&"belt":
			draw_rect(r, col)
			draw_rect(Rect2(r.position + Vector2(0, 0.08), Vector2(1, 0.84)) if b.rotation % 2 == 0 else Rect2(r.position + Vector2(0.08, 0), Vector2(0.84, 1)), col.lightened(0.12))
			draw_direction(r, b.rotation, Color(0.75, 0.75, 0.55, col.a * 0.9), 0.06)
			return
		&"inserter":
			draw_rect(r.grow(-0.22), col.darkened(0.3))
			return
	var inset := 0.04 if b.def.blocks_path else 0.0
	draw_rect(r.grow(-inset), col)
	draw_rect(r.grow(-inset), OUTLINE, false, 0.06)
	if b == sim.core:
		draw_rect(r.grow(-0.6), col.lightened(0.4))
	elif b.def.tower != null:
		var c := r.get_center()
		var radius := minf(r.size.x, r.size.y) * 0.32
		draw_circle(c, radius, col.darkened(0.35))
		draw_line(c, c + Vector2.from_angle(b.aim_angle) * radius * 1.6, Color(0.15, 0.15, 0.15, col.a), 0.22)
	match b.def.kind:
		&"drill":
			draw_circle(r.get_center(), 0.55, b.def.color.darkened(0.4))
			draw_line(r.get_center(), r.get_center() + Vector2.from_angle(b.progress * TAU) * 0.5, Color(0.9, 0.9, 0.9, 0.8), 0.1)
		&"crafter":
			var out_items := b.def.recipe.outputs.keys()
			var swatch: Color = sim.reg.items[sim.reg.item_index(StringName(out_items[0]))].color
			draw_rect(Rect2(r.position + Vector2(0.55, 0.45), Vector2(0.9, 0.9)), swatch.darkened(0.2))


## Status information drawn on top of every building, textured or not.
func _draw_overlays(b: Building, r: Rect2, textured: bool) -> void:
	var building := not b.is_active()
	match b.def.kind:
		&"inserter":
			_draw_inserter_arm(b, r)
		&"drill":
			if textured:
				# Spinning bit indicator over the art.
				draw_line(r.get_center(), r.get_center() + Vector2.from_angle(b.progress * TAU) * 0.55, Color(1.0, 0.8, 0.3, 0.8), 0.08)
			draw_direction(r, b.rotation, Color(1, 1, 1, 0.85), 0.1)
			if b.held >= 0:
				_draw_item(Rect2(r.end - Vector2(0.5, 0.5), Vector2(0.36, 0.36)), b.held)
		&"crafter":
			if b.crafting:
				draw_rect(Rect2(r.position + Vector2(0.15, 1.62), Vector2(1.7 * b.progress, 0.16)), Color(0.4, 1.0, 0.5))
	if b == sim.core:
		var frac := float(sim.core_hp) / float(sim.rules.core_hp)
		var bar := Rect2(r.position + Vector2(0, -0.45), Vector2(r.size.x, 0.25))
		draw_rect(bar, Color(0, 0, 0, 0.7))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), Color(0.3, 0.9, 0.4).lerp(Color(0.95, 0.25, 0.2), 1.0 - frac))
	if b.def.tower != null and not sim.infinite_ammo and b.is_active():
		var t := b.def.tower
		var frac := float(b.ammo) / float(t.magazine_size)
		var bar := Rect2(r.position + Vector2(0.1, r.size.y - 0.22), Vector2(r.size.x - 0.2, 0.14))
		draw_rect(bar, Color(0, 0, 0, 0.7))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), Color(1.0, 0.8, 0.2))
		if b.ammo <= 0:
			# Empty: red tint over the whole tower plus a flashing ✕.
			draw_rect(r.grow(-0.05), Color(1.0, 0.1, 0.1, 0.22))
			if int(Time.get_ticks_msec() / 400) % 2 == 0:
				var c := r.get_center()
				draw_line(c + Vector2(-0.45, -0.45), c + Vector2(0.45, 0.45), Color(1, 0.2, 0.15), 0.18)
				draw_line(c + Vector2(-0.45, 0.45), c + Vector2(0.45, -0.45), Color(1, 0.2, 0.15), 0.18)
	if building:
		var total := b.def.build_time if b.state == Building.State.CONSTRUCTING else sim.rules.relocate_time
		var frac := 1.0 - float(b.timer) / maxf(1.0, total * sim.tick_rate)
		var bar := Rect2(r.position + Vector2(0.1, r.size.y - 0.25), Vector2((r.size.x - 0.2) * frac, 0.15))
		draw_rect(bar, Color(0.4, 0.95, 1.0, 0.9))
	if b.id == selected_id:
		draw_rect(r.grow(0.1), Color(0.5, 0.95, 1.0, 0.95), false, 0.1)


func _draw_inserter_arm(b: Building, r: Rect2) -> void:
	var c := r.get_center()
	var d := Vector2(BeltNetwork.DIRS[b.rotation % 4])
	var col := b.def.color
	# Arm swings from the pickup side (-d) to the drop side (+d) while holding an item.
	var t := b.progress if b.held >= 0 else 0.0
	var hand := c + d.rotated(PI * (1.0 - t)) * 0.55
	draw_line(c, hand, col, 0.12)
	draw_circle(c, 0.14, col)
	if b.held >= 0:
		_draw_item(Rect2(hand - Vector2(0.15, 0.15), Vector2(0.3, 0.3)), b.held)


func _draw_item(r: Rect2, item: int) -> void:
	var def := sim.reg.items[item]
	var icon := DataRegistry.art(def.icon)
	if icon != null:
		draw_texture_rect(icon, r, false)
	else:
		draw_rect(r, def.color)
