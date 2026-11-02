class_name BuildingRenderer
extends Node2D
## Draws buildings, nests and excavation orders. Lives in tile space (parent
## scaled by TILE_PX), so 1 unit = 1 tile. Read-only view of [GameSim].

var sim: GameSim
## Building id highlighted by the build controller (0 = none).
var selected_id: int = 0

const NEST_COLOR := Color(0.55, 0.12, 0.12)
const OUTLINE := Color(0, 0, 0, 0.55)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	for at in sim.nests:
		var r := Rect2(at, GameSim.NEST_SIZE)
		draw_rect(r, NEST_COLOR)
		draw_rect(r.grow(-0.35), NEST_COLOR.lightened(0.25))
		draw_rect(r, OUTLINE, false, 0.08)
	for tile: int in sim.excavations:
		var c := sim.grid.cell_of(tile)
		var r := Rect2(c, Vector2.ONE)
		var left: float = float(sim.excavations[tile]) / (sim.rules.excavate_time * sim.tick_rate)
		draw_rect(r.grow(-0.08), Color(1.0, 0.8, 0.2, 0.9), false, 0.1)
		draw_rect(Rect2(r.position + Vector2(0.15, 0.75), Vector2(0.7 * (1.0 - left), 0.12)), Color(1.0, 0.8, 0.2))
	for b: Building in sim.buildings.values():
		_draw_building(b)


## Draws a chevron pointing along [param rotation] inside [param r].
func draw_direction(r: Rect2, rotation: int, col: Color, width: float = 0.08) -> void:
	var c := r.get_center()
	var d := Vector2(BeltNetwork.DIRS[rotation % 4])
	var side := Vector2(-d.y, d.x)
	var s := minf(r.size.x, r.size.y) * 0.22
	draw_polyline(PackedVector2Array([c - d * s + side * s, c + d * s * 0.6, c - d * s - side * s]), col, width)


func _draw_building(b: Building) -> void:
	var r := Rect2(b.origin, b.size())
	var col := b.def.color
	var building := not b.is_active()
	if building:
		col.a = 0.45
	match b.def.kind:
		&"belt":
			draw_rect(r, col)
			draw_rect(Rect2(r.position + Vector2(0, 0.08), Vector2(1, 0.84)) if b.rotation % 2 == 0 else Rect2(r.position + Vector2(0.08, 0), Vector2(0.84, 1)), col.lightened(0.12))
			draw_direction(r, b.rotation, Color(0.75, 0.75, 0.55, 0.6 if building else 0.9), 0.06)
			_draw_extras(b, r, building)
			return
		&"inserter":
			_draw_inserter(b, r, col)
			_draw_extras(b, r, building)
			return
	var inset := 0.04 if b.def.blocks_path else 0.0
	draw_rect(r.grow(-inset), col)
	draw_rect(r.grow(-inset), OUTLINE, false, 0.06)
	if b == sim.core:
		draw_rect(r.grow(-0.6), col.lightened(0.4))
		var frac := float(sim.core_hp) / float(sim.rules.core_hp)
		var bar := Rect2(r.position + Vector2(0, -0.45), Vector2(r.size.x, 0.25))
		draw_rect(bar, Color(0, 0, 0, 0.7))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), Color(0.3, 0.9, 0.4).lerp(Color(0.95, 0.25, 0.2), 1.0 - frac))
	elif b.def.tower != null:
		var c := r.get_center()
		var radius := minf(r.size.x, r.size.y) * 0.32
		draw_circle(c, radius, col.darkened(0.35))
		draw_line(c, c + Vector2.from_angle(b.aim_angle) * radius * 1.6, Color(0.15, 0.15, 0.15, col.a), 0.22)
	_draw_extras(b, r, building)


func _draw_extras(b: Building, r: Rect2, building: bool) -> void:
	match b.def.kind:
		&"drill":
			draw_circle(r.get_center(), 0.55, b.def.color.darkened(0.4))
			draw_line(r.get_center(), r.get_center() + Vector2.from_angle(b.progress * TAU) * 0.5, Color(0.9, 0.9, 0.9, 0.8), 0.1)
			draw_direction(r, b.rotation, Color(1, 1, 1, 0.8), 0.1)
			if b.held >= 0:
				draw_rect(Rect2(r.end - Vector2(0.45, 0.45), Vector2(0.3, 0.3)), sim.reg.items[b.held].color)
		&"crafter":
			var out_items := b.def.recipe.outputs.keys()
			var swatch: Color = sim.reg.items[sim.reg.item_index(StringName(out_items[0]))].color
			draw_rect(Rect2(r.position + Vector2(0.55, 0.45), Vector2(0.9, 0.9)), swatch.darkened(0.2))
			if b.crafting:
				draw_rect(Rect2(r.position + Vector2(0.15, 1.6), Vector2(1.7 * b.progress, 0.18)), Color(0.4, 1.0, 0.5))
	if b.def.tower != null and not sim.infinite_ammo and b.is_active():
		var t := b.def.tower
		var frac := float(b.ammo) / float(t.magazine_size)
		var bar := Rect2(r.position + Vector2(0.1, r.size.y - 0.22), Vector2(r.size.x - 0.2, 0.14))
		draw_rect(bar, Color(0, 0, 0, 0.6))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), Color(1.0, 0.8, 0.2))
		if b.ammo <= 0 and int(Time.get_ticks_msec() / 400) % 2 == 0:
			var c := r.get_center()
			draw_line(c + Vector2(-0.4, -0.4), c + Vector2(0.4, 0.4), Color(1, 0.2, 0.15), 0.16)
			draw_line(c + Vector2(-0.4, 0.4), c + Vector2(0.4, -0.4), Color(1, 0.2, 0.15), 0.16)
	if building:
		var total := b.def.build_time if b.state == Building.State.CONSTRUCTING else sim.rules.relocate_time
		var frac := 1.0 - float(b.timer) / maxf(1.0, total * sim.tick_rate)
		var bar := Rect2(r.position + Vector2(0.1, r.size.y - 0.25), Vector2((r.size.x - 0.2) * frac, 0.15))
		draw_rect(bar, Color(1, 1, 1, 0.9))
	if b.id == selected_id:
		draw_rect(r.grow(0.1), Color(1, 1, 1, 0.95), false, 0.1)


func _draw_inserter(b: Building, r: Rect2, col: Color) -> void:
	var c := r.get_center()
	var d := Vector2(BeltNetwork.DIRS[b.rotation % 4])
	draw_rect(r.grow(-0.22), col.darkened(0.3))
	# Arm swings from the pickup side (-d) to the drop side (+d) while holding an item.
	var t := b.progress if b.held >= 0 else 0.0
	var hand := c + d.rotated(PI * (1.0 - t)) * 0.55
	draw_line(c, hand, col, 0.12)
	draw_circle(c, 0.14, col)
	if b.held >= 0:
		draw_rect(Rect2(hand - Vector2(0.12, 0.12), Vector2(0.24, 0.24)), sim.reg.items[b.held].color)
