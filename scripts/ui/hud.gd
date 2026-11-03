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
signal quit_requested

const PANEL_BG := Color(0.03, 0.05, 0.08, 0.88)
const PANEL_BORDER := Color(0.3, 0.9, 1.0, 0.35)
const ACCENT := Color(0.45, 0.95, 1.0)
const CREDITS_PATH := "res://assets/CREDITS.md"
const RATE_WINDOW := 60  # seconds of history for "per minute" rates

var sim: GameSim
var clock: SimClock
var controller: BuildController
var camera: CameraController

var _status: Label
var _resources: RichTextLabel
var _credits: PanelContainer
var _info_panel: PanelContainer
var _info_title: Label
var _info_body: Label
var _info_buttons: HBoxContainer
var _sell_btn: Button
var _move_btn: Button
var _recipe_btn: Button
var _toolbar: HFlowContainer
var _tabs_row: HBoxContainer
var _shown_category: StringName = &""
var _tool_buttons: Dictionary = {}  # BuildingDef or &"excavate" -> Button
var _toast: Label
var _toast_time := 0.0
var _hint: Label
var _game_over: PanelContainer
var _game_over_label: Label
## Everything lives under this node so the whole HUD can be scaled (UI scale option).
var _root: Control
var _skip_btn: Button
var _menu: PanelContainer
var _menu_backdrop: ColorRect
var _paused_before_menu := false

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
	controller.menu_requested.connect(toggle_menu)
	_refresh_tools()
	apply_ui_scale()


func show_message(text: String) -> void:
	_toast.text = text
	_toast_time = 2.5
	_toast.modulate.a = 1.0


func _process(delta: float) -> void:
	if sim == null:
		return
	_sample_production()
	var sp := sim.spawner
	var assault: String
	if sp.is_assault_active():
		assault = "ASSAULT #%d!" % sp.assault_number()
	elif sp.in_lull(sim.time):
		assault = "Lull — rebuild! %ds" % ceili(sp.lull_until - sim.time)
	elif sp.is_wave_active():
		assault = "Wave %d   ·   Assault in %ds" % [sp.wave_number(), ceili(sim.seconds_to_assault())]
	else:
		assault = "Next wave %ds   ·   Assault in %ds" % [ceili(maxf(0.0, sp.next_wave_at - sim.time)), ceili(sim.seconds_to_assault())]
	var prep := sim.in_preparation()
	if prep:
		assault = "Enemies arrive in %s" % _clock_text(sim.spawner.waves_start - sim.time + 0.99)
	_skip_btn.visible = prep and not sim.game_over
	var speed := "PAUSED" if clock.paused else "%dx" % int(clock.speed)
	_status.text = "Credits %d    Core %d/%d    Enemies %d    Kills %d    %s    %s    [%s]    v%s" % [
		sim.credits, sim.core_hp, sim.rules.core_hp, sim.enemies.count, sim.kills, assault, _clock_text(sim.time), speed,
		ProjectSettings.get_setting("application/config/version", "dev")]
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time / 0.5, 0.0, 1.0)
	var reason := controller.ghost_reason()
	if reason == "" and controller.power_warning():
		reason = "No Power Node in range — this tower needs power (Power tab)."
	_hint.text = reason if reason != "" else "LMB build/select · drag for lines · RMB cancel/sell · R rotate · X excavate · M move · Space pause · +/- speed · scroll/pinch zoom"
	_hint.modulate = Color(1, 0.55, 0.5) if reason != "" else Color(1, 1, 1, 0.75)
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.2
		_resources.text = _resources_text()
		_refresh_tools()
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
	lines.append("[color=#73f2ff][b]RESOURCES[/b][/color]")
	lines.append("Credits: [b]%d[/b]%s" % [sim.credits, "   [color=#9aa](+%d recycled)[/color]" % sim.factory.recycled_total if sim.factory.recycled_total > 0 else ""])
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
		lines.append("%s%s: [b]%d[/b] [color=#9fe](%d stored)[/color]  [color=#9aa]%+.0f/min[/color]" % [
			_item_img(i), sim.reg.items[i].display_name, totals[i], sim.stock(i), rate])
	if not any:
		lines.append("No production yet —\nbuild a Mining Drill on ore.")
	lines.append("[color=#9aa]Stored = Core + Storage, used for building materials.[/color]")
	if not sim.power.nodes.is_empty() or not sim.power.consumers.is_empty():
		lines.append("")
		lines.append("[color=#73f2ff][b]POWER[/b][/color]")
		var gen := 0.0
		for st in sim.power.network_stats:
			gen += st.x
		var short := sim.power.total_demand > gen + 0.01
		lines.append("Generating %.0f / needed %.0f%s" % [gen, sim.power.total_demand, "   [color=#ff5a4a]SHORTAGE[/color]" if short else ""])
		var unpowered := 0
		for c in sim.power.consumers:
			if c.network < 0:
				unpowered += 1
		if unpowered > 0:
			lines.append("[color=#ff5a4a]%d tower(s) not connected — add a Power Node[/color]" % unpowered)
	var ammo := sim.ammo_summary()
	if ammo[1] > 0:
		lines.append("")
		lines.append("[color=#73f2ff][b]TOWER AMMO[/b][/color]")
		lines.append("Loaded: [b]%d[/b] / %d rounds" % [ammo[0], ammo[1]])
		lines.append("Supply drones in flight: %d" % sim.supply.drones.size())
		if ammo[2] > 0:
			lines.append("[color=#ff5a4a]EMPTY towers: %d[/color]" % ammo[2])
		if ammo[3] > 0:
			lines.append("[color=#ffc04a]Low (<25%%): %d[/color]" % ammo[3])
	return "\n".join(lines)


func _item_img(i: int) -> String:
	var icon := DataRegistry.art(sim.reg.items[i].icon)
	if icon != null and icon.resource_path != "":
		return "[img=18x18]%s[/img] " % icon.resource_path
	return "[color=#%s]■[/color] " % sim.reg.items[i].color.to_html(false)


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
		_recipe_btn.visible = not b.def.recipes.is_empty()
		if _recipe_btn.visible:
			_recipe_btn.text = "Recipe: %s  ▶" % _recipe_name(b.recipe())
		_info_panel.visible = true
	elif tool_def != null:
		_info_title.text = "Build: %s" % tool_def.display_name
		_info_body.text = _def_text(tool_def) + "\n\nCost: %s · %dx%d tiles%s" % [
			_cost_text(tool_def), tool_def.size.x, tool_def.size.y, " · R to rotate" if tool_def.directional else ""]
		_info_buttons.visible = false
		_recipe_btn.visible = false
		_info_panel.visible = true
	elif controller.mode == BuildController.Mode.EXCAVATE:
		_info_title.text = "Excavate"
		_info_body.text = "Removes rock (purple crystal) to open new routes and adds %d Stone to the Core.\nCost %d credits · takes %.0f s." % [sim.rules.excavate_stone, sim.rules.excavate_cost, sim.rules.excavate_time]
		_info_buttons.visible = false
		_recipe_btn.visible = false
		_info_panel.visible = true
	else:
		_info_panel.visible = false


## "175 credits + 10 Steel (have 3)".
func _cost_text(def: BuildingDef) -> String:
	var parts := PackedStringArray(["%d credits" % def.cost])
	for id in def.material_cost:
		var idx := sim.reg.item_index(StringName(id))
		var have := sim.stock(idx)
		var need := int(def.material_cost[id])
		parts.append("%s%d %s (have %d)%s" % ["[!] " if have < need else "", need, sim.reg.items[idx].display_name, have, ""])
	return " + ".join(parts)


func _recipe_name(r: RecipeDef) -> String:
	if r == null:
		return "-"
	return r.display_name if r.display_name != "" else String(r.id).capitalize()


func _cycle_recipe() -> void:
	var b := controller.selected
	if b == null or b.def.recipes.is_empty():
		return
	sim.set_recipe(b.id, b.recipe_index + 1)
	controller.remember_recipe(b)
	_refresh_info()


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
		match t.attack:
			&"cone":
				lines.append("Attack: %.0f° cone, hits every enemy in it" % t.cone_angle)
			&"splash":
				lines.append("Attack: blast of %.1f tiles around the target" % t.splash_radius)
			&"pulse":
				lines.append("Attack: pulse hitting everything within range")
			&"chain":
				lines.append("Attack: chains to %d more enemies (%.0f%% damage per jump)" % [t.chain_count, t.chain_falloff * 100.0])
		if t.slow_time > 0.0:
			lines.append("Slows by %.0f%% for %.1f s" % [(1.0 - t.slow_factor) * 100.0, t.slow_time])
		if t.burn_time > 0.0:
			lines.append("Burns for %.0f damage/s over %.0f s" % [t.burn_dps, t.burn_time])
		if t.stun_time > 0.0:
			lines.append("Stuns for %.2f s" % t.stun_time)
		if t.ammo_item != &"":
			var ammo_name := sim.reg.items[sim.reg.item_index(t.ammo_item)].display_name
			lines.append("Ammo: %s (+%d rounds each)" % [ammo_name, t.rounds_per_item])
			lines.append("Magazine: %d rounds (new towers start with %d)" % [t.magazine_size, t.starter_ammo])
		if t.power_draw > 0.0:
			lines.append("Power: uses %.0f while enemies are in range" % t.power_draw)
	if def.power_output > 0.0:
		lines.append("")
		lines.append("Produces %.0f power, burning 1 %s every %.0f s while needed." % [def.power_output, sim.reg.items[sim.reg.item_index(def.fuel_item)].display_name, def.fuel_time])
	if def.supply_radius > 0.0:
		lines.append("")
		lines.append("Powers buildings within %.1f tiles; links to nodes within %.0f tiles." % [def.supply_radius, def.link_range])
	if def.storage_capacity > 0:
		lines.append("")
		lines.append("Holds %d items." % def.storage_capacity)
	if not def.recipes.is_empty():
		lines.append("")
		lines.append("Recipes (choose after building):")
		for r in def.recipes:
			lines.append("  %s → %s  (%.1f s)" % [_items_text(r.inputs), _items_text(r.outputs), r.time])
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
			lines.append("Loaded: %d / %d rounds%s" % [b.ammo, t.magazine_size, "   — EMPTY!" if b.ammo <= 0 else ""])
			lines.append(_supply_text(b))
		if t.power_draw > 0.0:
			if b.network < 0:
				lines.append("[!] Not connected to power — place a Power Node within 4.5 tiles.")
			elif b.wants_power:
				lines.append("Power: %.0f%%%s" % [b.power_satisfaction * 100.0, "  [!] not enough generators/coal" if b.power_satisfaction < 1.0 else ""])
			else:
				lines.append("Power: connected (idle)")
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
		&"storage", &"core":
			var cap := "%d / %d" % [b.stored_count(), b.def.storage_capacity] if b.def.storage_capacity > 0 else "%d" % b.stored_count()
			lines.append("Contents (%s): %s" % [cap, _inv_text(b.inv_out)])
		&"generator":
			var fuel := sim.reg.item_index(b.def.fuel_item)
			lines.append("Fuel: %d %s%s" % [b.inv_in.get(fuel, 0), sim.reg.items[fuel].display_name, "   (burning)" if b.burning else ""])
			if b.network < 0:
				lines.append("[!] Not connected — place a Power Node within 4.5 tiles.")
		&"pump":
			if b.held >= 0:
				lines.append("Output blocked — put a belt or machine in front (arrow).")
		&"recycler":
			lines.append("Queue: %s" % _inv_text(b.inv_in))
	if b.def.sellable:
		lines.append("Value: %d credits" % b.invested)
	return "\n".join(lines)


## Where this tower's ammo comes from (supply drones, ADR-008).
func _supply_text(b: Building) -> String:
	var t := b.def.tower
	var item := sim.reg.item_index(t.ammo_item)
	var name := sim.reg.items[item].display_name
	if sim.supply.is_in_flight(b.id):
		return "Supply: drone on the way"
	var src := sim.supply.nearest_source(sim, b, item)
	if src != null:
		return "Supply: drones from %s (%.0f tiles)" % [src.def.display_name, src.center().distance_to(b.center())]
	if sim.supply.distance_to_stockpile(sim, b) > sim.rules.supply_range:
		return "[!] Out of drone range (%.0f tiles) — build a Storage nearby and stock it with %s" % [sim.rules.supply_range, name]
	return "[!] No %s in stock — produce some and deliver it to the Core or a Storage" % name


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
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var root := _root
	get_viewport().size_changed.connect(apply_ui_scale)
	GameSettings.get_instance().changed.connect(apply_ui_scale)

	# Top status bar (+ "start waves" button during preparation).
	var top := _panel()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 16)
	_status = _label(17)
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(_status)
	_skip_btn = _button("Start waves now [N]")
	_skip_btn.custom_minimum_size.y = 30
	_skip_btn.tooltip_text = "Skip the rest of the preparation time."
	_skip_btn.pressed.connect(func() -> void: sim.skip_preparation())
	top_row.add_child(_skip_btn)
	top.add_child(top_row)
	root.add_child(top)

	# Left: resources.
	var res := _panel()
	res.position = Vector2(10, 52)
	res.custom_minimum_size = Vector2(250, 0)
	_resources = RichTextLabel.new()
	_resources.bbcode_enabled = true
	_resources.fit_content = true
	_resources.scroll_active = false
	_resources.autowrap_mode = TextServer.AUTOWRAP_OFF
	_resources.custom_minimum_size = Vector2(250, 0)
	_resources.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resources.add_theme_font_size_override("normal_font_size", 15)
	_resources.add_theme_font_size_override("bold_font_size", 15)
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
	_info_title.add_theme_color_override("font_color", ACCENT)
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
	_recipe_btn = _button("Recipe")
	_recipe_btn.tooltip_text = "Click to switch recipe. Buffered inputs go back to the Core."
	_recipe_btn.pressed.connect(_cycle_recipe)
	_recipe_btn.visible = false
	info_box.add_child(_recipe_btn)
	_info_panel.add_child(info_box)
	_info_panel.visible = false
	root.add_child(_info_panel)

	# Bottom left: hint + toolbar. Spans up to the minimap and wraps into
	# several rows when the HUD is scaled up.
	var bottom := VBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_left = 10
	bottom.offset_right = -330  # Room for the minimap.
	bottom.offset_bottom = -10
	bottom.alignment = BoxContainer.ALIGNMENT_END
	_hint = _label(14)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(_hint)
	var bar := _panel()
	bar.size_flags_horizontal = Control.SIZE_FILL
	var bar_box := VBoxContainer.new()
	_tabs_row = HBoxContainer.new()
	_tabs_row.add_theme_constant_override("separation", 4)
	for cat in DataRegistry.CATEGORIES:
		var tab := _button(String(cat).capitalize())
		tab.custom_minimum_size = Vector2(96, 28)
		tab.toggle_mode = true
		tab.pressed.connect(controller.set_category.bind(cat))
		tab.set_meta("category", cat)
		_tabs_row.add_child(tab)
	var hint_tab := _label(12)
	hint_tab.text = "  [Tab] next tab"
	hint_tab.modulate = Color(1, 1, 1, 0.55)
	_tabs_row.add_child(hint_tab)
	bar_box.add_child(_tabs_row)
	_toolbar = HFlowContainer.new()
	_toolbar.add_theme_constant_override("h_separation", 6)
	_toolbar.add_theme_constant_override("v_separation", 6)
	bar_box.add_child(_toolbar)
	bar.add_child(bar_box)
	bottom.add_child(bar)
	root.add_child(bottom)
	_rebuild_toolbar()

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
			["Core [H]", func() -> void: camera.center_on(sim.core.center() * WorldGrid.TILE_PX)],
			["Credits", func() -> void: _credits.visible = not _credits.visible],
			["Menu [Esc]", func() -> void: toggle_menu()]]:
		var b := _button(spec[0])
		b.pressed.connect(spec[1])
		cam_row.add_child(b)
	map_box.add_child(cam_row)
	var minimap := Minimap.new()
	minimap.setup(sim, camera, 300.0)
	map_box.add_child(minimap)
	root.add_child(map_box)

	# Credits screen (same content as assets/CREDITS.md).
	_credits = _panel()
	_credits.set_anchors_preset(Control.PRESET_CENTER)
	_credits.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_credits.grow_vertical = Control.GROW_DIRECTION_BOTH
	var cr_box := VBoxContainer.new()
	var cr_title := _label(22)
	cr_title.text = "Credits"
	cr_title.add_theme_color_override("font_color", ACCENT)
	cr_box.add_child(cr_title)
	var cr_text := RichTextLabel.new()
	cr_text.bbcode_enabled = true
	cr_text.custom_minimum_size = Vector2(820, 520)
	cr_text.text = credits_bbcode(_read_credits())
	cr_box.add_child(cr_text)
	var close := _button("Close")
	close.pressed.connect(func() -> void: _credits.visible = false)
	cr_box.add_child(close)
	_credits.add_child(cr_box)
	_credits.visible = false
	root.add_child(_credits)

	_build_menu(root)

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


## Fills the toolbar with the buildings of the controller's current tab.
func _rebuild_toolbar() -> void:
	_shown_category = controller.category
	for child in _toolbar.get_children():
		child.queue_free()
	_tool_buttons.clear()
	for def in sim.reg.toolbar_buildings(_shown_category):
		var mats := PackedStringArray()
		for id in def.material_cost:
			mats.append("%d %s" % [def.material_cost[id], String(id).split("_")[0]])
		var btn := _button("%s\n[%d] %d cr%s" % [def.display_name, def.toolbar_slot, def.cost, (" + " + ", ".join(mats)) if not mats.is_empty() else ""])
		btn.tooltip_text = def.description
		btn.pressed.connect(controller.select_build.bind(def))
		_toolbar.add_child(btn)
		_tool_buttons[def] = btn
	var dig := _button("Excavate\n[X] %d cr" % sim.rules.excavate_cost)
	dig.pressed.connect(controller.select_excavate)
	_toolbar.add_child(dig)
	_tool_buttons[&"excavate"] = dig
	for tab in _tabs_row.get_children():
		if tab is Button:
			(tab as Button).button_pressed = tab.get_meta("category") == _shown_category


func _refresh_tools() -> void:
	if controller.category != _shown_category:
		_rebuild_toolbar()
	for key in _tool_buttons:
		var btn: Button = _tool_buttons[key]
		var active := false
		if key is BuildingDef:
			active = controller.mode == BuildController.Mode.BUILD and controller.build_def == key
		else:
			active = controller.mode == BuildController.Mode.EXCAVATE
		var affordable: bool = not (key is BuildingDef) or (sim.credits >= key.cost and sim.has_materials(key.material_cost))
		btn.modulate = Color(1.0, 0.85, 0.3) if active else (Color.WHITE if affordable else Color(1, 1, 1, 0.45))
	_refresh_info()


## Scales the whole HUD by the "UI scale" option, keeping anchors correct.
func apply_ui_scale() -> void:
	if _root == null:
		return
	var s := clampf(GameSettings.get_instance().ui_scale, 0.75, 2.0)
	_root.scale = Vector2(s, s)
	_root.size = get_viewport().get_visible_rect().size / s


func is_menu_open() -> bool:
	return _menu != null and _menu.visible


## Opens/closes the game menu; the game is paused while it is open.
func toggle_menu() -> void:
	if not _menu.visible:
		_paused_before_menu = clock.paused
		clock.paused = true
		_menu.visible = true
		_menu_backdrop.visible = true
	else:
		_menu.visible = false
		_menu_backdrop.visible = false
		_credits.visible = false
		clock.paused = _paused_before_menu


func _build_menu(root: Control) -> void:
	# Dims the game and swallows clicks while the menu is open.
	_menu_backdrop = ColorRect.new()
	_menu_backdrop.color = Color(0, 0, 0, 0.45)
	_menu_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_backdrop.visible = false
	root.add_child(_menu_backdrop)
	_menu = _panel()
	_menu.set_anchors_preset(Control.PRESET_CENTER)
	_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(440, 0)
	var title := _label(24)
	title.text = "Paused"
	title.add_theme_color_override("font_color", ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	for spec in [["Resume", func() -> void: toggle_menu()],
			["Restart", func() -> void: restart_requested.emit()],
			["Credits", func() -> void:
				_credits.visible = true
				_credits.move_to_front()],
			["Quit", func() -> void: quit_requested.emit()]]:
		var b := _button(spec[0])
		b.custom_minimum_size.x = 96
		b.pressed.connect(spec[1])
		actions.add_child(b)
	box.add_child(actions)
	box.add_child(HSeparator.new())
	var opts := _label(18)
	opts.text = "Options"
	opts.add_theme_color_override("font_color", ACCENT)
	box.add_child(opts)
	box.add_child(_slider_row("HUD scale", "ui_scale", 0.75, 2.0, 0.05))
	box.add_child(_slider_row("Camera pan speed", "pan_speed", 0.5, 2.5, 0.1))
	box.add_child(_slider_row("Zoom sensitivity", "zoom_speed", 0.3, 2.5, 0.1))
	box.add_child(_check_row("Show enemy routes", "show_routes"))
	box.add_child(_check_row("Fullscreen", "fullscreen"))
	var note := _label(13)
	note.text = "Options are saved automatically."
	note.modulate = Color(1, 1, 1, 0.6)
	box.add_child(note)
	_menu.add_child(box)
	_menu.visible = false
	root.add_child(_menu)


func _slider_row(text: String, key: String, lo: float, hi: float, step: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name_label := _label(15)
	name_label.text = text
	name_label.custom_minimum_size.x = 170
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = GameSettings.get_instance().get(key)
	slider.custom_minimum_size = Vector2(190, 28)
	slider.focus_mode = Control.FOCUS_NONE
	row.add_child(slider)
	var value_label := _label(15)
	value_label.custom_minimum_size.x = 60
	value_label.text = "%d%%" % roundi(slider.value * 100.0)
	row.add_child(value_label)
	# Apply on release so the HUD doesn't rescale under the cursor while dragging.
	slider.value_changed.connect(func(v: float) -> void: value_label.text = "%d%%" % roundi(v * 100.0))
	slider.drag_ended.connect(func(_changed: bool) -> void: GameSettings.get_instance().set_option(key, slider.value))
	return row


func _check_row(text: String, key: String) -> CheckBox:
	var check := CheckBox.new()
	check.text = text
	check.button_pressed = GameSettings.get_instance().get(key)
	check.focus_mode = Control.FOCUS_NONE
	check.add_theme_font_size_override("font_size", 15)
	check.toggled.connect(func(on: bool) -> void: GameSettings.get_instance().set_option(key, on))
	return check


func _read_credits() -> String:
	var f := FileAccess.open(CREDITS_PATH, FileAccess.READ)
	if f == null:
		return "Credits file not found (%s)." % CREDITS_PATH
	return f.get_as_text()


## Converts the subset of Markdown used in CREDITS.md to BBCode.
static func credits_bbcode(md: String) -> String:
	var out := PackedStringArray()
	var bold := RegEx.create_from_string("\\*\\*(.+?)\\*\\*")
	var code := RegEx.create_from_string("`([^`]+)`")
	for line in md.split("\n"):
		if line.begins_with("---") or line.begins_with("|---"):
			continue
		line = bold.sub(line, "[b]$1[/b]", true)
		line = code.sub(line, "[color=#9fe]$1[/color]", true)
		if line.begins_with("### "):
			line = "[color=#ffd866][b]%s[/b][/color]" % line.substr(4)
		elif line.begins_with("## "):
			line = "\n[color=#73f2ff][font_size=20][b]%s[/b][/font_size][/color]" % line.substr(3)
		elif line.begins_with("# "):
			continue
		out.append(line)
	return "\n".join(out)


static func _clock_text(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]


static func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
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
