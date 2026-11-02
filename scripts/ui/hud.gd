class_name Hud
extends CanvasLayer
## In-game HUD, built in code:
## - top: status bar (credits, Core, enemies, assault timer, speed)
## - left: resources panel (items in the factory, production rates, tower ammo)
## - right: info panel (selected building, or the building/tool about to be used)
## - bottom: hint line + build toolbar; bottom-right: minimap + zoom buttons
## - centre: toasts and the game-over screen
## All buttons work with mouse now and touch later.

signal restart_requested

const PANEL_BG := Color(0.06, 0.07, 0.06, 0.82)
const RATE_WINDOW := 60  # seconds of history for "per minute" rates

var sim: GameSim
var clock: SimClock
var controller: BuildController
var camera: CameraController

var _status: Label
var _resources: Label
var _info_panel: PanelContainer
var _info_title: Label
var _info_body: Label
var _info_buttons: HBoxContainer
var _sell_btn: Button
var _move_btn: Button
var _tool_buttons: Dictionary = {}  # BuildingDef or &"excavate" -> Button
var _toast: Label
var _toast_time := 0.0
var _hint: Label
var _game_over: PanelContainer
var _game_over_label: Label

## produced-item snapshots, one per game second, for per-minute rates.
var _history: Array[PackedInt32Array] = []
var _last_sample_second := -1
var _refresh := 0.0


func setup(game: GameSim, sim_clock: SimClock, ctrl: BuildController, cam: CameraController) -> void:
	sim = game
	clock = sim_clock
	controller = ctrl
	camera = cam
	_build()
	controller.message.connect(show_message)
	controller.changed.connect(_refresh_tools)
	_refresh_tools()


func show_message(text: String) -> void:
	_toast.text = text
	_toast_time = 2.5
	_toast.modulate.a = 1.0


func _process(delta: float) -> void:
	if sim == null:
		return
	_sample_production()
	var assault := "ASSAULT #%d!" % sim.spawner.assault_number() if sim.spawner.is_assault_active() \
		else "Next assault: %ds" % ceili(sim.seconds_to_assault())
	if sim.time < sim.reg.spawning.grace_period:
		assault = "Enemies arrive in %ds — build your maze!" % ceili(sim.reg.spawning.grace_period - sim.time)
	var speed := "PAUSED" if clock.paused else "%dx" % int(clock.speed)
	_status.text = "Credits %d    Core %d/%d    Enemies %d    Kills %d    %s    %s    [%s]    v%s" % [
		sim.credits, sim.core_hp, sim.rules.core_hp, sim.enemies.count, sim.kills, assault, _clock_text(sim.time), speed,
		ProjectSettings.get_setting("application/config/version", "dev")]
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time / 0.5, 0.0, 1.0)
	var reason := controller.ghost_reason()
	_hint.text = reason if reason != "" else "LMB build/select · drag for lines · RMB cancel/sell · R rotate · X excavate · M move · Space pause · +/- speed · scroll/pinch zoom"
	_hint.modulate = Color(1, 0.55, 0.5) if reason != "" else Color(1, 1, 1, 0.75)
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.2
		_resources.text = _resources_text()
		_refresh_info()
	if sim.game_over and not _game_over.visible:
		_game_over_label.text = "THE CORE HAS FALLEN\n\nSurvived %s · %d kills · %d assaults" % [_clock_text(sim.time), sim.kills, sim.spawner.assault_number()]
		_game_over.visible = true


# --- Resources ---------------------------------------------------------------

func _sample_production() -> void:
	var second := int(sim.time)
	if second == _last_sample_second:
		return
	_last_sample_second = second
	_history.append(sim.factory.produced.duplicate())
	if _history.size() > RATE_WINDOW + 1:
		_history.pop_front()


func _resources_text() -> String:
	var lines := PackedStringArray()
	lines.append("RESOURCES")
	lines.append("Credits: %d" % sim.credits)
	var totals := sim.item_totals()
	var now := sim.factory.produced
	var past: PackedInt32Array = _history[0] if not _history.is_empty() else now
	var span := maxf(1.0, float(_history.size() - 1))
	var any := false
	for i in sim.reg.items.size():
		var rate := (now[i] - past[i]) * 60.0 / span
		if totals[i] == 0 and now[i] == 0:
			continue
		any = true
		lines.append("%s: %d   (%+.0f/min)" % [sim.reg.items[i].display_name, totals[i], rate])
	if not any:
		lines.append("No production yet —\nbuild a Mining Drill on ore.")
	var ammo := sim.ammo_summary()
	if ammo[1] > 0:
		lines.append("")
		lines.append("TOWER AMMO")
		lines.append("Loaded: %d / %d rounds" % [ammo[0], ammo[1]])
		if ammo[2] > 0:
			lines.append("EMPTY towers: %d" % ammo[2])
		if ammo[3] > 0:
			lines.append("Low (<25%%): %d" % ammo[3])
	return "\n".join(lines)


# --- Info panel --------------------------------------------------------------

func _refresh_info() -> void:
	var b := controller.selected
	var tool_def: BuildingDef = controller.build_def if controller.mode == BuildController.Mode.BUILD else null
	if b != null:
		_info_title.text = b.def.display_name
		_info_body.text = _building_text(b)
		_info_buttons.visible = b.def.sellable or b.def.relocatable
		_sell_btn.text = "Sell (+%d)" % sim.sell_value(b)
		_sell_btn.disabled = not b.def.sellable
		_move_btn.text = "Move (-%d)" % sim.relocate_fee(b)
		_move_btn.disabled = not b.def.relocatable or not b.is_active()
		_info_panel.visible = true
	elif tool_def != null:
		_info_title.text = "Build: %s" % tool_def.display_name
		_info_body.text = _def_text(tool_def) + "\n\nCost %d credits · %dx%d tiles%s" % [
			tool_def.cost, tool_def.size.x, tool_def.size.y, " · R to rotate" if tool_def.directional else ""]
		_info_buttons.visible = false
		_info_panel.visible = true
	elif controller.mode == BuildController.Mode.EXCAVATE:
		_info_title.text = "Excavate"
		_info_body.text = "Removes rock (grey, speckled) to open new routes.\nCost %d credits · takes %.0f s." % [sim.rules.excavate_cost, sim.rules.excavate_time]
		_info_buttons.visible = false
		_info_panel.visible = true
	else:
		_info_panel.visible = false


## Static description of a building type (used for tools and selections).
func _def_text(def: BuildingDef) -> String:
	var lines := PackedStringArray()
	if def.description != "":
		lines.append(def.description)
	if def.tower != null:
		var t := def.tower
		lines.append("")
		lines.append("Damage: %.0f %s" % [t.damage, String(t.damage_type).capitalize()])
		lines.append("Fire rate: %.1f shots/s   (%.0f DPS)" % [t.fire_rate, t.damage * t.fire_rate])
		lines.append("Range: %.1f tiles" % t.range_tiles)
		lines.append("Targeting: %s" % _targeting_text(t.targeting))
		if t.ammo_item != &"":
			var ammo_name := sim.reg.items[sim.reg.item_index(t.ammo_item)].display_name
			lines.append("Ammo: %s (+%d rounds each)" % [ammo_name, t.rounds_per_item])
			lines.append("Magazine: %d rounds (new towers start with %d)" % [t.magazine_size, t.starter_ammo])
	if def.recipe != null:
		lines.append("")
		lines.append("Recipe: %s → %s  (%.1f s)" % [_items_text(def.recipe.inputs), _items_text(def.recipe.outputs), def.recipe.time])
	if def.kind == &"drill":
		lines.append("")
		lines.append("Mines 1 ore every %.1f s (%.0f/min)." % [def.mining_time, 60.0 / def.mining_time])
	if def.kind == &"inserter":
		lines.append("")
		lines.append("Moves 1 item every %.1f s." % def.swing_time)
	lines.append("Blocks enemies: %s" % ("yes" if def.blocks_path else "no"))
	return "\n".join(lines)


func _building_text(b: Building) -> String:
	var lines := PackedStringArray([_def_text(b.def), ""])
	var state: String = ["Under construction", "Active", "Redeploying"][b.state]
	lines.append("Status: %s" % state)
	if b.def.tower != null:
		var t := b.def.tower
		if not sim.infinite_ammo and t.ammo_item != &"":
			lines.append("Loaded: %d / %d rounds%s" % [b.ammo, t.magazine_size, "   — EMPTY! Feed it ammo." if b.ammo <= 0 else ""])
		lines.append("Kills: %d   Rounds fired: %d" % [b.kills, b.rounds_fired])
	match b.def.kind:
		&"crafter":
			lines.append("Input: %s" % _inv_text(b.inv_in))
			lines.append("Output: %s" % _inv_text(b.inv_out))
			if b.crafting:
				lines.append("Crafting… %d%%" % int(b.progress * 100.0))
		&"drill":
			var y := sim.factory.drill_yield(b.cells)
			lines.append("Mining: %s" % (sim.reg.items[y].display_name if y >= 0 else "-"))
			if b.held >= 0:
				lines.append("Output blocked — put a belt or machine in front (arrow).")
		&"inserter":
			if b.held >= 0:
				lines.append("Holding: %s" % sim.reg.items[b.held].display_name)
	if b.def.sellable:
		lines.append("Value: %d credits" % b.invested)
	return "\n".join(lines)


func _targeting_text(mode: StringName) -> String:
	match mode:
		&"first":
			return "First (closest to the Core)"
		&"last":
			return "Last"
		&"strongest":
			return "Strongest"
		&"weakest":
			return "Weakest"
		&"closest":
			return "Closest to tower"
	return String(mode)


func _items_text(map: Dictionary) -> String:
	var parts := PackedStringArray()
	for id in map:
		var idx := sim.reg.item_index(StringName(id))
		parts.append("%d %s" % [map[id], sim.reg.items[idx].display_name if idx >= 0 else String(id)])
	return " + ".join(parts)


func _inv_text(inv: Dictionary) -> String:
	var parts := PackedStringArray()
	for item: int in inv:
		if inv[item] > 0:
			parts.append("%s ×%d" % [sim.reg.items[item].display_name, inv[item]])
	return ", ".join(parts) if not parts.is_empty() else "empty"


# --- Layout ------------------------------------------------------------------

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Top status bar.
	var top := _panel()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_status = _label(17)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_status)
	root.add_child(top)

	# Left: resources.
	var res := _panel()
	res.position = Vector2(10, 52)
	res.custom_minimum_size = Vector2(250, 0)
	_resources = _label(15)
	res.add_child(_resources)
	root.add_child(res)

	# Right: info panel.
	_info_panel = _panel()
	_info_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_info_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_info_panel.offset_top = 52
	_info_panel.offset_right = -10
	_info_panel.custom_minimum_size = Vector2(340, 0)
	var info_box := VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 6)
	_info_title = _label(19)
	_info_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	info_box.add_child(_info_title)
	_info_body = _label(14)
	_info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_body.custom_minimum_size = Vector2(320, 0)
	info_box.add_child(_info_body)
	_info_buttons = HBoxContainer.new()
	_sell_btn = _button("Sell")
	_sell_btn.pressed.connect(controller.sell_selected)
	_move_btn = _button("Move")
	_move_btn.pressed.connect(controller.start_move_selected)
	_info_buttons.add_child(_sell_btn)
	_info_buttons.add_child(_move_btn)
	info_box.add_child(_info_buttons)
	_info_panel.add_child(info_box)
	_info_panel.visible = false
	root.add_child(_info_panel)

	# Bottom centre: hint + toolbar.
	var bottom := VBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_bottom = -10
	bottom.offset_left = -170  # Shift left of centre to leave room for the minimap.
	bottom.offset_right = -170
	_hint = _label(14)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_hint)
	var bar := _panel()
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	bar.add_child(toolbar)
	bottom.add_child(bar)
	root.add_child(bottom)
	for def in sim.reg.toolbar_buildings():
		var btn := _button("%s\n[%d]  %d cr" % [def.display_name, def.toolbar_slot, def.cost])
		btn.tooltip_text = def.description
		btn.pressed.connect(controller.select_build.bind(def))
		toolbar.add_child(btn)
		_tool_buttons[def] = btn
	var dig := _button("Excavate\n[X]  %d cr" % sim.rules.excavate_cost)
	dig.pressed.connect(controller.select_excavate)
	toolbar.add_child(dig)
	_tool_buttons[&"excavate"] = dig

	# Bottom right: minimap + camera buttons.
	var map_box := VBoxContainer.new()
	map_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	map_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	map_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	map_box.offset_right = -10
	map_box.offset_bottom = -10
	var cam_row := HBoxContainer.new()
	cam_row.alignment = BoxContainer.ALIGNMENT_END
	for spec in [["Zoom +", func() -> void: camera.zoom_by(1.3)], ["Zoom −", func() -> void: camera.zoom_by(1.0 / 1.3)],
			["Core [H]", func() -> void: camera.center_on(sim.core.center() * WorldGrid.TILE_PX)]]:
		var b := _button(spec[0])
		b.pressed.connect(spec[1])
		cam_row.add_child(b)
	map_box.add_child(cam_row)
	var minimap := Minimap.new()
	minimap.setup(sim, camera, 300.0)
	map_box.add_child(minimap)
	root.add_child(map_box)

	# Toast.
	_toast = _label(22)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = 60
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.modulate.a = 0.0
	root.add_child(_toast)

	# Game over.
	_game_over = _panel()
	_game_over.set_anchors_preset(Control.PRESET_CENTER)
	_game_over.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_game_over.grow_vertical = Control.GROW_DIRECTION_BOTH
	var go_box := VBoxContainer.new()
	go_box.add_theme_constant_override("separation", 16)
	_game_over_label = _label(24)
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_box.add_child(_game_over_label)
	var restart := _button("Restart")
	restart.pressed.connect(func() -> void: restart_requested.emit())
	go_box.add_child(restart)
	_game_over.add_child(go_box)
	_game_over.visible = false
	root.add_child(_game_over)


func _refresh_tools() -> void:
	for key in _tool_buttons:
		var btn: Button = _tool_buttons[key]
		var active := false
		if key is BuildingDef:
			active = controller.mode == BuildController.Mode.BUILD and controller.build_def == key
		else:
			active = controller.mode == BuildController.Mode.EXCAVATE
		btn.modulate = Color(1.0, 0.85, 0.3) if active else Color.WHITE
	_refresh_info()


static func _clock_text(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]


static func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.set_content_margin_all(10)
	style.set_corner_radius_all(6)
	p.add_theme_stylebox_override("panel", style)
	return p


static func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 13)
	return b
