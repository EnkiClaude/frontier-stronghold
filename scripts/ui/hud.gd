class_name Hud
extends CanvasLayer
## In-game HUD: status bar, build toolbar, selection panel, messages and the
## game-over screen. Built in code; reads [GameSim] and talks to
## [BuildController]. Buttons double as touch controls later.

signal restart_requested

var sim: GameSim
var clock: SimClock
var controller: BuildController

var _status: Label
var _toolbar: HBoxContainer
var _tool_buttons: Dictionary = {}  # BuildingDef or &"excavate" -> Button
var _sel_panel: PanelContainer
var _sel_label: Label
var _sell_btn: Button
var _move_btn: Button
var _toast: Label
var _toast_time := 0.0
var _hint: Label
var _game_over: PanelContainer
var _game_over_label: Label


func setup(game: GameSim, sim_clock: SimClock, ctrl: BuildController) -> void:
	sim = game
	clock = sim_clock
	controller = ctrl
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
	var assault := "ASSAULT #%d!" % sim.spawner.assault_number() if sim.spawner.is_assault_active() \
		else "Next assault: %ds" % ceili(sim.seconds_to_assault())
	var speed := "PAUSED" if clock.paused else "%dx" % int(clock.speed)
	_status.text = "Credits: %d     Core: %d/%d     Enemies: %d     Kills: %d     %s     Time: %s     [%s]" % [
		sim.credits, sim.core_hp, sim.rules.core_hp, sim.enemies.count, sim.kills, assault, _clock_text(sim.time), speed]
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time / 0.5, 0.0, 1.0)
	var reason := controller.ghost_reason()
	_hint.text = reason if reason != "" else "LMB build/select · drag for lines · RMB cancel/sell · R rotate · X excavate · M move · Space pause · +/- speed"
	_hint.modulate = Color(1, 0.55, 0.5) if reason != "" else Color(1, 1, 1, 0.7)
	_refresh_selection()
	if sim.game_over and not _game_over.visible:
		_game_over_label.text = "THE CORE HAS FALLEN\n\nSurvived %s · %d kills · %d assaults" % [_clock_text(sim.time), sim.kills, sim.spawner.assault_number()]
		_game_over.visible = true


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Top status bar.
	var top := _panel(Color(0, 0, 0, 0.6))
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_status = _label(16)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_status)
	root.add_child(top)

	# Bottom: hint line + toolbar.
	var bottom := VBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_bottom = -10
	_hint = _label(14)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_hint)
	var bar := _panel(Color(0, 0, 0, 0.6))
	_toolbar = HBoxContainer.new()
	_toolbar.add_theme_constant_override("separation", 8)
	bar.add_child(_toolbar)
	bottom.add_child(bar)
	root.add_child(bottom)
	for def in sim.reg.toolbar_buildings():
		var btn := _button("[%d] %s %d" % [def.toolbar_slot, def.display_name, def.cost])
		btn.pressed.connect(controller.select_build.bind(def))
		_toolbar.add_child(btn)
		_tool_buttons[def] = btn
	var dig := _button("[X] Excavate %d" % sim.rules.excavate_cost)
	dig.pressed.connect(controller.select_excavate)
	_toolbar.add_child(dig)
	_tool_buttons[&"excavate"] = dig

	# Selection panel (bottom right).
	_sel_panel = _panel(Color(0, 0, 0, 0.7))
	_sel_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_sel_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_sel_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_sel_panel.offset_right = -10
	_sel_panel.offset_bottom = -10
	var sel_box := VBoxContainer.new()
	_sel_label = _label(15)
	sel_box.add_child(_sel_label)
	var sel_buttons := HBoxContainer.new()
	_sell_btn = _button("Sell")
	_sell_btn.pressed.connect(controller.sell_selected)
	_move_btn = _button("Move")
	_move_btn.pressed.connect(controller.start_move_selected)
	sel_buttons.add_child(_sell_btn)
	sel_buttons.add_child(_move_btn)
	sel_box.add_child(sel_buttons)
	_sel_panel.add_child(sel_box)
	root.add_child(_sel_panel)

	# Toast.
	_toast = _label(20)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = 48
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.modulate.a = 0.0
	root.add_child(_toast)

	# Game over.
	_game_over = _panel(Color(0.05, 0.02, 0.02, 0.9))
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


func _refresh_selection() -> void:
	var b := controller.selected
	_sel_panel.visible = b != null and b != sim.core
	if not _sel_panel.visible:
		return
	var state: String = ["Under construction", "Active", "Redeploying"][b.state]
	var text := "%s\n%s · Value %d" % [b.def.display_name, state, b.invested]
	if b.def.tower != null:
		var t := b.def.tower
		text += "\nDamage %.0f · %.1f/s · Range %.1f" % [t.damage, t.fire_rate, t.range_tiles]
		if not sim.infinite_ammo:
			text += "\nAmmo %d/%d%s" % [b.ammo, t.magazine_size, "  — EMPTY!" if b.ammo <= 0 else ""]
	if b.def.kind == &"crafter":
		text += "\nIn: %s\nOut: %s" % [_inv_text(b.inv_in), _inv_text(b.inv_out)]
	elif b.def.kind == &"drill":
		var y := sim.factory.drill_yield(b.cells)
		text += "\nMining: %s%s" % [sim.reg.items[y].display_name if y >= 0 else "-", "  (output blocked)" if b.held >= 0 else ""]
	_sel_label.text = text
	_sell_btn.text = "Sell (+%d)" % sim.sell_value(b)
	_sell_btn.disabled = not b.def.sellable
	_move_btn.text = "Move (-%d)" % sim.relocate_fee(b)
	_move_btn.disabled = not b.def.relocatable or not b.is_active()


func _inv_text(inv: Dictionary) -> String:
	var parts := PackedStringArray()
	for item: int in inv:
		if inv[item] > 0:
			parts.append("%s ×%d" % [sim.reg.items[item].display_name, inv[item]])
	return ", ".join(parts) if not parts.is_empty() else "empty"


static func _clock_text(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]


static func _panel(bg: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_content_margin_all(8)
	style.set_corner_radius_all(4)
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
	b.custom_minimum_size = Vector2(0, 40)
	b.add_theme_font_size_override("font_size", 14)
	return b
