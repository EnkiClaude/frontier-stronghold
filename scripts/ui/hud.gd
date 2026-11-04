class_name Hud
extends CanvasLayer
## In-game HUD, built in code and styled by [UiTheme]:
## - top: status bar (credits, Core health, enemies, wave/assault timer, speed)
## - left: resources panel (items, production rates, power, tower ammo)
## - right: info panel (selected building, or the tool about to be used)
## - bottom: build dock (category tabs + building cards with icons and costs);
##   bottom right: minimap with camera buttons
## - next to the cursor: why a placement is not possible
## - centre: toasts, menu and the game-over screen
## Phones get a compact variant of the same pieces (see [method _build_touch]).

signal restart_requested
signal quit_requested
## Main owns the clock speed index.
signal pause_toggled
signal speed_cycled
signal speed_selected(index: int)

const ACCENT := UiTheme.ACCENT
const CREDITS_PATH := "res://assets/CREDITS.md"
const RATE_WINDOW := 60  # seconds of history for "per minute" rates
const SPEED_LABELS: Array[String] = ["1x", "2x", "3x"]

var sim: GameSim
var clock: SimClock
var controller: BuildController
var camera: CameraController

var _touch := false
var _icons: BuildingIcons
## Everything lives under this node so the whole HUD can be scaled (UI scale option).
var _root: Control

# Status bar.
var _credits_val: Label
var _core_val: Label
var _core_bar: ProgressBar
var _enemies_val: Label
var _kills_val: Label
var _wave_cap: Label
var _wave_val: Label
var _wave_bar: ProgressBar
var _time_val: Label
var _ammo_alert: Label
var _skip_btn: Button
var _pause_btn: Button
var _speed_btns: Array[Button] = []
var _speed_btn: Button  # Phones: one cycling button.

# Panels.
var _res_panel: PanelContainer
var _resources: RichTextLabel
var _res_body: Control
var _res_toggle: Button
var _info_panel: PanelContainer
var _info_icon: TextureRect
var _info_title: Label
var _info_sub: Label
var _info_body: RichTextLabel
var _info_buttons: HBoxContainer
var _sell_btn: Button
var _move_btn: Button
var _recipe_btn: Button
var _minimap_box: Control

# Build dock.
var _toolbar: Container
var _tabs_row: HBoxContainer
var _cat_btn: Button
var _shown_category: StringName = &""
var _tool_buttons: Dictionary = {}  # BuildingDef or &"excavate" -> Button
var _tool_costs: Dictionary = {}  # same keys -> cost Label

# Hints and messages.
var _hint: Label
var _keys_hint: Label
var _cursor_tip: PanelContainer
var _cursor_label: Label
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween

# Phone extras.
var _sell_mode_btn: Button
var _rotate_btn: Button
var _cancel_btn: Button
var _portrait_note: Label

# Overlays.
var _credits: PanelContainer
var _game_over: PanelContainer
var _game_over_label: Label
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
	_icons = BuildingIcons.new()
	_icons.sim = sim
	add_child(_icons)
	_build()
	controller.message.connect(show_message)
	controller.changed.connect(_refresh_tools)
	controller.menu_requested.connect(toggle_menu)
	_refresh_tools()
	_resources.text = _resources_text()
	apply_ui_scale()


## Short message in a pill at the top of the screen. Errors are red, results
## (sold, moved, ...) green, anything else neutral.
func show_message(text: String) -> void:
	var col := UiTheme.ACCENT
	var lower := text.to_lower()
	if lower.begins_with("sold") or lower.begins_with("moved") or lower.begins_with("+"):
		col = UiTheme.GOOD
	elif lower.begins_with("need") or lower.contains("not ") or lower.contains("can't") or lower.contains("cannot") \
			or lower.contains("occupied") or lower.contains("block") or lower.contains("outside") or lower.contains("enough"):
		col = UiTheme.BAD
	_toast_label.text = text
	_toast.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.BG_SOLID, 18, Color(col, 0.7), 10.0, true))
	_toast_label.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.55))
	if _toast_tween != null:
		_toast_tween.kill()
	_toast.visible = true
	_toast.modulate.a = 0.0
	_toast.pivot_offset = _toast.size * 0.5
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.12)
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)


func _process(delta: float) -> void:
	if sim == null:
		return
	_sample_production()
	_update_status()
	_update_hints()
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.25
		if _res_body.visible and _res_panel.visible:
			_resources.text = _resources_text()
		_refresh_tools()
	if sim.game_over and not _game_over.visible:
		_game_over_label.text = "Survived %s  ·  %d kills  ·  %d assaults" % [_clock_text(sim.time), sim.kills, sim.spawner.assault_number()]
		_game_over.visible = true
		_game_over.modulate.a = 0.0
		create_tween().tween_property(_game_over, "modulate:a", 1.0, 0.5)


# --- Status bar --------------------------------------------------------------

func _update_status() -> void:
	var sp := sim.spawner
	_credits_val.text = _thousands(sim.credits)
	_core_val.text = "%d/%d" % [sim.core_hp, sim.rules.core_hp]
	var core_frac := float(sim.core_hp) / float(sim.rules.core_hp)
	_core_bar.value = core_frac
	_core_val.add_theme_color_override("font_color", UiTheme.TEXT if core_frac > 0.5 else (UiTheme.WARN if core_frac > 0.25 else UiTheme.BAD))
	if _enemies_val != null:
		_enemies_val.text = str(sim.enemies.count)
		_kills_val.text = str(sim.kills)
		_time_val.text = _clock_text(sim.time)
	var prep := sim.in_preparation()
	var interval := sp.cfg.assault_interval
	if prep:
		_wave_cap.text = "PREPARATION"
		_wave_val.text = "Enemies in %s" % _clock_text(sp.waves_start - sim.time + 0.99)
		_wave_bar.value = 1.0 - clampf((sp.waves_start - sim.time) / maxf(1.0, sp.waves_start), 0.0, 1.0)
		_set_bar_color(_wave_bar, UiTheme.ACCENT)
	elif sp.is_assault_active():
		_wave_cap.text = "ASSAULT #%d" % sp.assault_number()
		_wave_val.text = "Hold the line!"
		_wave_bar.value = 1.0
		_set_bar_color(_wave_bar, UiTheme.BAD)
	elif sp.in_lull(sim.time):
		_wave_cap.text = "LULL"
		_wave_val.text = "Rebuild  %ds" % ceili(sp.lull_until - sim.time)
		_wave_bar.value = clampf((sp.lull_until - sim.time) / maxf(1.0, sp.cfg.lull_after_assault), 0.0, 1.0)
		_set_bar_color(_wave_bar, UiTheme.GOOD)
	else:
		_wave_cap.text = "WAVE %d" % sp.wave_number() if sp.wave_number() > 0 else "WAVES"
		_wave_val.text = "Assault in %ds" % ceili(sim.seconds_to_assault())
		_wave_bar.value = 1.0 - clampf(sim.seconds_to_assault() / maxf(1.0, interval), 0.0, 1.0)
		_set_bar_color(_wave_bar, UiTheme.WARN)
	_skip_btn.visible = prep and not sim.game_over
	var ammo := sim.ammo_summary()
	_ammo_alert.visible = ammo[2] > 0
	if ammo[2] > 0:
		_ammo_alert.text = "%d EMPTY" % ammo[2] if _touch else "%d tower%s out of ammo" % [ammo[2], "" if ammo[2] == 1 else "s"]
	if _touch:
		_pause_btn.text = "Play" if clock.paused else "Pause"
		_speed_btn.text = "%dx" % int(clock.speed)
	else:
		_pause_btn.set_pressed_no_signal(clock.paused)
		for k in _speed_btns.size():
			_speed_btns[k].set_pressed_no_signal(not clock.paused and is_equal_approx(clock.speed, float(k + 1)))


func _set_bar_color(bar: ProgressBar, col: Color) -> void:
	var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null and fill.bg_color != col:
		fill.bg_color = col


## 12345 -> "12,345".
static func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


# --- Hints -------------------------------------------------------------------

func _update_hints() -> void:
	var reason := controller.ghost_reason()
	var warn := reason == "" and controller.power_warning()
	if warn:
		reason = "No Power Node in range: this tower needs power (Power tab)"
	var m := controller.mode
	if _touch:
		var note := ""
		if m == BuildController.Mode.SELL:
			reason = "Sell mode: tap or swipe buildings"
		elif reason == "" and m == BuildController.Mode.BUILD and controller.build_def != null:
			note = "%s: %s%s" % [controller.build_def.display_name, _cost_text(controller.build_def),
				"  ·  drag for a line" if controller.build_def.size == Vector2i.ONE else ""]
		elif reason == "" and m == BuildController.Mode.EXCAVATE:
			note = "Excavate: tap rock to remove it (%d cr, +%d Stone)" % [sim.rules.excavate_cost, sim.rules.excavate_stone]
		_hint.visible = reason != "" or note != ""
		_hint.text = reason if reason != "" else note
		_hint.add_theme_color_override("font_color", (UiTheme.WARN if warn else UiTheme.BAD) if reason != "" else UiTheme.TEXT)
		_rotate_btn.visible = (m == BuildController.Mode.BUILD and controller.build_def != null and controller.build_def.directional) \
			or m == BuildController.Mode.MOVE
		_cancel_btn.visible = m != BuildController.Mode.SELECT or controller.selected != null
		_sell_mode_btn.set_pressed_no_signal(m == BuildController.Mode.SELL)
		return
	# Desktop: the reason floats next to the cursor; the dock shows key hints.
	if m == BuildController.Mode.SELL:
		reason = "Sell mode: click or drag over buildings"
	var show := reason != "" and m != BuildController.Mode.SELECT and not is_menu_open()
	_cursor_tip.visible = show
	if show:
		_cursor_label.text = reason
		_cursor_label.add_theme_color_override("font_color", UiTheme.WARN if warn else UiTheme.BAD.lerp(Color.WHITE, 0.25))
		var s := _root.scale.x
		var p := (get_viewport().get_mouse_position() - _root.position) / s + Vector2(18, 20)
		var limit := _root.size - _cursor_tip.size - Vector2(4, 4)
		_cursor_tip.position = p.clamp(Vector2.ZERO, limit.max(Vector2.ZERO))
		_cursor_tip.reset_size()
	match m:
		BuildController.Mode.BUILD:
			_keys_hint.text = "Click to build  ·  drag for a line  ·  R rotate  ·  Right-click / Esc cancel  ·  Middle-click copies a building"
		BuildController.Mode.EXCAVATE:
			_keys_hint.text = "Click rock to excavate  ·  drag for a line  ·  Right-click cancel"
		BuildController.Mode.MOVE:
			_keys_hint.text = "Click to place  ·  R rotate  ·  Right-click cancel"
		_:
			_keys_hint.text = "1-9 build  ·  Tab next category  ·  X excavate  ·  Right-drag sell  ·  Space pause  ·  +/- speed  ·  H home"


# --- Resources ---------------------------------------------------------------

func _sample_production() -> void:
	var second := int(sim.time)
	if second == _last_sample_second:
		return
	_last_sample_second = second
	_history.append(sim.factory.produced.duplicate())
	if _history.size() > RATE_WINDOW + 1:
		_history.pop_front()


const _DIM := "#8f9bab"
const _HEAD := "#61dbff"


func _resources_text() -> String:
	var out := PackedStringArray()
	var totals := sim.item_totals()
	var now := sim.factory.produced
	var past: PackedInt32Array = _history[0] if not _history.is_empty() else now
	var span := maxf(1.0, float(_history.size() - 1))
	var rows := PackedStringArray()
	for i in sim.reg.items.size():
		if totals[i] == 0 and now[i] == 0:
			continue
		var rate := (now[i] - past[i]) * 60.0 / span
		var rate_txt := "[color=%s]%s[/color]" % ["#66eb8c" if rate > 0.5 else _DIM, ("+%.0f/min" % rate) if rate > 0.5 else "-"]
		rows.append("[cell]%s[/cell][cell]%s[/cell][cell][right][b]%d[/b][/right][/cell][cell][right][color=%s]%d[/color][/right][/cell][cell][right]%s[/right][/cell]" % [
			_item_img(i), sim.reg.items[i].display_name, totals[i], _DIM, sim.stock(i), rate_txt])
	if rows.is_empty():
		out.append("[color=%s]No production yet.\nBuild a Mining Drill on ore.[/color]" % _DIM)
	else:
		out.append("[table=5][cell][/cell][cell][color=%s][font_size=11]ITEM[/font_size][/color][/cell][cell][right][color=%s][font_size=11]TOTAL[/font_size][/color][/right][/cell][cell][right][color=%s][font_size=11]STORED[/font_size][/color][/right][/cell][cell][right][color=%s][font_size=11]RATE[/font_size][/color][/right][/cell]%s[/table]" % [
			_DIM, _DIM, _DIM, _DIM, "".join(rows)])
	if sim.factory.recycled_total > 0:
		out.append("[color=%s]Recycled for +%d credits so far[/color]" % [_DIM, sim.factory.recycled_total])
	if not sim.power.nodes.is_empty() or not sim.power.consumers.is_empty():
		var gen := 0.0
		for st in sim.power.network_stats:
			gen += st.x
		var short := sim.power.total_demand > gen + 0.01
		out.append("")
		out.append("[color=%s][b][font_size=11]POWER[/font_size][/b][/color]" % _HEAD)
		out.append("%s%.0f[/color] generated / %.0f needed%s" % ["[color=#ff6b5c]" if short else "[color=#66eb8c]", gen, sim.power.total_demand,
			"  [color=#ff6b5c]SHORTAGE[/color]" if short else ""])
		var unpowered := 0
		for c in sim.power.consumers:
			if c.network < 0:
				unpowered += 1
		if unpowered > 0:
			out.append("[color=#ff6b5c]%d tower%s not connected: add a Power Node[/color]" % [unpowered, "" if unpowered == 1 else "s"])
	var ammo := sim.ammo_summary()
	if ammo[1] > 0:
		out.append("")
		out.append("[color=%s][b][font_size=11]TOWER AMMO[/font_size][/b][/color]" % _HEAD)
		out.append("[b]%d[/b] / %d rounds loaded  ·  %d drone%s flying" % [ammo[0], ammo[1], sim.supply.drones.size(), "" if sim.supply.drones.size() == 1 else "s"])
		if ammo[2] > 0:
			out.append("[color=#ff6b5c]%d tower%s EMPTY[/color]" % [ammo[2], "" if ammo[2] == 1 else "s"])
		if ammo[3] > 0:
			out.append("[color=#ffc24d]%d low (<25%%)[/color]" % ammo[3])
	return "\n".join(out)


func _item_img(i: int) -> String:
	var icon := DataRegistry.art(sim.reg.items[i].icon)
	if icon != null and icon.resource_path != "":
		return "[img=16x16]%s[/img]" % icon.resource_path
	return "[color=#%s]■[/color]" % sim.reg.items[i].color.to_html(false)


# --- Info panel --------------------------------------------------------------

func _refresh_info() -> void:
	var b := controller.selected
	var tool_def: BuildingDef = controller.build_def if controller.mode == BuildController.Mode.BUILD else null
	if b != null:
		_info_icon.texture = _icons.icon_for(b.def)
		_info_title.text = b.def.display_name
		var state: String = ["Under construction", "Active", "Redeploying"][b.state]
		_info_sub.text = "%s  ·  %s" % [String(b.def.category).capitalize(), state]
		_set_info_body(_building_text(b))
		_info_buttons.visible = b.def.sellable or b.def.relocatable
		_sell_btn.text = "Sell  +%d" % sim.sell_value(b)
		_sell_btn.disabled = not b.def.sellable
		_move_btn.text = "Move  -%d" % sim.relocate_fee(b)
		_move_btn.disabled = not b.def.relocatable or not b.is_active()
		_recipe_btn.visible = not b.def.recipes.is_empty()
		if _recipe_btn.visible:
			_recipe_btn.text = "Recipe: %s   >" % _recipe_name(b.recipe())
		_info_panel.visible = true
	elif tool_def != null and not _touch:
		_info_icon.texture = _icons.icon_for(tool_def)
		_info_title.text = tool_def.display_name
		_info_sub.text = "Build  ·  %dx%d tiles%s" % [tool_def.size.x, tool_def.size.y, "  ·  R rotates" if tool_def.directional else ""]
		_set_info_body("Cost: %s\n\n%s" % [_cost_text(tool_def), _def_text(tool_def)])
		_info_buttons.visible = false
		_recipe_btn.visible = false
		_info_panel.visible = true
	elif controller.mode == BuildController.Mode.EXCAVATE and not _touch:
		_info_icon.texture = _icons.excavate_icon()
		_info_title.text = "Excavate"
		_info_sub.text = "Tool"
		_set_info_body("Removes rock (purple crystal) to open new routes and adds %d Stone to the Core.\nCost: %d credits\nTakes: %.0f s" % [sim.rules.excavate_stone, sim.rules.excavate_cost, sim.rules.excavate_time])
		_info_buttons.visible = false
		_recipe_btn.visible = false
		_info_panel.visible = true
	else:
		_info_panel.visible = false


## Plain description text -> BBCode: "Name: value" lines get a dim label,
## "[!]" warnings turn red, and the first paragraph (flavour) is dimmed.
func _set_info_body(text: String) -> void:
	var out := PackedStringArray()
	for line in text.split("\n"):
		var esc := line.replace("[", "[lb]")
		if line.begins_with("[!]"):
			out.append("[color=#ff6b5c]%s[/color]" % line.substr(3).strip_edges().replace("[", "[lb]"))
			continue
		var colon := esc.find(": ")
		if colon > 0 and colon < 22 and not esc.begins_with(" "):
			out.append("[color=%s]%s[/color]  %s" % [_DIM, esc.substr(0, colon), esc.substr(colon + 2)])
		else:
			out.append(esc)
	var body := "\n".join(out)
	if _info_body.text != body:
		_info_body.text = body


# --- Text helpers ------------------------------------------------------------

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
			lines.append("  %s -> %s  (%.1f s)" % [_items_text(r.inputs), _items_text(r.outputs), r.time])
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
	_touch = GameSettings.touch_ui()
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.build(_touch)
	add_child(_root)
	get_viewport().size_changed.connect(apply_ui_scale)
	GameSettings.get_instance().changed.connect(apply_ui_scale)
	if _touch:
		_build_touch(_root)
	else:
		_build_desktop(_root)
	_build_info_panel(_root)
	_build_overlays(_root)
	_rebuild_toolbar()


func _build_desktop(root: Control) -> void:
	# Top centre: status bar.
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", UiTheme.panel(8))
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.offset_top = 10
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.add_child(_spacer(4))
	var credits := UiTheme.stat("Credits", 19)
	_credits_val = credits[1]
	_credits_val.add_theme_color_override("font_color", UiTheme.GOLD)
	row.add_child(credits[0])
	row.add_child(_core_stat(96))
	var enemies := UiTheme.stat("Enemies")
	_enemies_val = enemies[1]
	row.add_child(enemies[0])
	var kills := UiTheme.stat("Kills")
	_kills_val = kills[1]
	row.add_child(kills[0])
	row.add_child(_wave_stat(150))
	var time := UiTheme.stat("Time")
	_time_val = time[1]
	row.add_child(time[0])
	row.add_child(VSeparator.new())
	row.add_child(_speed_group())
	_skip_btn = _accent_button("Start waves  [N]")
	_skip_btn.tooltip_text = "Skip the rest of the preparation time."
	_skip_btn.pressed.connect(func() -> void: sim.skip_preparation())
	row.add_child(_skip_btn)
	row.add_child(_spacer(2))
	top.add_child(row)
	root.add_child(top)
	_ammo_alert = _alert_label()
	_ammo_alert.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_ammo_alert.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ammo_alert.offset_top = 80
	root.add_child(_ammo_alert)

	# Left: resources.
	_build_resources(root, Vector2(10, 10), true)

	# Bottom centre: build dock.
	var dock := VBoxContainer.new()
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dock.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dock.offset_bottom = -8
	dock.alignment = BoxContainer.ALIGNMENT_END
	dock.add_theme_constant_override("separation", 6)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UiTheme.panel(8))
	var bar_box := VBoxContainer.new()
	bar_box.add_theme_constant_override("separation", 8)
	_tabs_row = HBoxContainer.new()
	_tabs_row.add_theme_constant_override("separation", 4)
	for cat in DataRegistry.CATEGORIES:
		var tab := Button.new()
		tab.text = String(cat).capitalize()
		tab.toggle_mode = true
		tab.focus_mode = Control.FOCUS_NONE
		tab.custom_minimum_size = Vector2(104, 30)
		tab.add_theme_font_size_override("font_size", 13)
		tab.add_theme_stylebox_override("normal", UiTheme.box(Color(0, 0, 0, 0), 8, Color(0, 0, 0, 0), 6.0))
		tab.pressed.connect(controller.set_category.bind(cat))
		tab.set_meta("category", cat)
		_tabs_row.add_child(tab)
	var tab_hint := _label(11)
	tab_hint.text = "   Tab: next"
	tab_hint.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	_tabs_row.add_child(tab_hint)
	bar_box.add_child(_tabs_row)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	_toolbar = tools
	bar_box.add_child(tools)
	bar.add_child(bar_box)
	dock.add_child(bar)
	_keys_hint = _label(11)
	_keys_hint.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	_keys_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keys_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_keys_hint.add_theme_constant_override("outline_size", 4)
	dock.add_child(_keys_hint)
	root.add_child(dock)

	# Bottom right: minimap with camera buttons.
	var map_panel := PanelContainer.new()
	map_panel.add_theme_stylebox_override("panel", UiTheme.panel(6))
	map_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	map_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	map_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	map_panel.offset_right = -10
	map_panel.offset_bottom = -10
	var map_box := VBoxContainer.new()
	map_box.add_theme_constant_override("separation", 6)
	var cam_row := HBoxContainer.new()
	cam_row.add_theme_constant_override("separation", 4)
	for spec in [["+", "Zoom in", func() -> void: camera.zoom_by(1.3)],
			["-", "Zoom out", func() -> void: camera.zoom_by(1.0 / 1.3)],
			["Core", "Centre on the Core [H]", func() -> void: _home()],
			["Menu", "Menu, options and credits [Esc]", func() -> void: toggle_menu()]]:
		var b := _small_button(spec[0], spec[2], 34 if spec[0].length() == 1 else 0)
		b.tooltip_text = spec[1]
		if spec[0].length() > 1:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cam_row.add_child(b)
	map_box.add_child(cam_row)
	var minimap := Minimap.new()
	minimap.setup(sim, camera, 250.0)
	map_box.add_child(minimap)
	map_panel.add_child(map_box)
	root.add_child(map_panel)
	_minimap_box = map_panel

	# Floating reason next to the cursor.
	_cursor_tip = PanelContainer.new()
	_cursor_tip.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.BG_SOLID, 6, Color(UiTheme.BAD, 0.5), 6.0, true))
	_cursor_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_label = _label(13)
	_cursor_tip.add_child(_cursor_label)
	_cursor_tip.visible = false
	root.add_child(_cursor_tip)
	_hint = _cursor_label


## Phone layout: one slim status bar on top, one toolbar row at the bottom,
## and buttons only for what needs a right-click or key on desktop.
func _build_touch(root: Control) -> void:
	# Top: [Menu] credits core wave ...... [Start] [Res] [Map] [Pause] [1x]
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", UiTheme.panel(5))
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_small_button("Menu", toggle_menu, 58))
	var credits := UiTheme.stat("Credits", 16)
	_credits_val = credits[1]
	_credits_val.add_theme_color_override("font_color", UiTheme.GOLD)
	row.add_child(credits[0])
	row.add_child(_core_stat(64))
	row.add_child(_wave_stat(120))
	_ammo_alert = _alert_label()
	row.add_child(_ammo_alert)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(fill)
	_skip_btn = _accent_button("Start now")
	_skip_btn.pressed.connect(func() -> void: sim.skip_preparation())
	row.add_child(_skip_btn)
	row.add_child(_small_button("Res", func() -> void: _res_panel.visible = not _res_panel.visible, 48))
	row.add_child(_small_button("Map", func() -> void: _minimap_box.visible = not _minimap_box.visible, 48))
	_pause_btn = _small_button("Pause", func() -> void: pause_toggled.emit(), 58)
	row.add_child(_pause_btn)
	_speed_btn = _small_button("1x", func() -> void: speed_cycled.emit(), 40)
	row.add_child(_speed_btn)
	top.add_child(row)
	root.add_child(top)

	# Bottom: context buttons + hint, then [category] [cards...] [Core].
	var bottom := VBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 6)
	var ctx := HBoxContainer.new()
	ctx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctx.add_theme_constant_override("separation", 6)
	_sell_mode_btn = _small_button("Sell", func() -> void: controller.select_sell_mode(), 60)
	_sell_mode_btn.toggle_mode = true
	_sell_mode_btn.add_theme_color_override("font_pressed_color", UiTheme.BAD)
	_sell_mode_btn.add_theme_color_override("font_hover_pressed_color", UiTheme.BAD)
	_cancel_btn = _small_button("Cancel", func() -> void:
		controller.cancel()
		controller._set_selected(null), 72)
	_rotate_btn = _small_button("Rotate", func() -> void: controller.rotation_steps = (controller.rotation_steps + 1) % 4, 72)
	for b in [_sell_mode_btn, _rotate_btn, _cancel_btn]:
		b.custom_minimum_size.y = 40
		ctx.add_child(b)
	_hint = _label(13)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 5)
	ctx.add_child(_hint)
	bottom.add_child(ctx)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UiTheme.panel(5))
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 6)
	_cat_btn = _small_button("Defense", controller.next_category, 96)
	_cat_btn.custom_minimum_size.y = 58
	_cat_btn.add_theme_color_override("font_color", ACCENT)
	brow.add_child(_cat_btn)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 4)
	scroll.add_child(tools)
	_toolbar = tools
	brow.add_child(scroll)
	brow.add_child(_small_button("Core", _home, 54))
	bar.add_child(brow)
	bottom.add_child(bar)
	root.add_child(bottom)
	_tabs_row = HBoxContainer.new()  # Unused on phones (the category button cycles).
	_keys_hint = _label(11)

	_build_resources(root, Vector2(0, 50), false)
	_res_panel.visible = false

	# Minimap: hidden until "Map" is tapped (top right, under the status bar).
	_minimap_box = PanelContainer.new()
	_minimap_box.add_theme_stylebox_override("panel", UiTheme.panel(5))
	_minimap_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_minimap_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_minimap_box.offset_top = 50
	var minimap := Minimap.new()
	minimap.setup(sim, camera, 260.0)
	_minimap_box.add_child(minimap)
	_minimap_box.visible = false
	root.add_child(_minimap_box)

	_portrait_note = _label(22)
	_portrait_note.text = "Rotate your phone to landscape"
	_portrait_note.set_anchors_preset(Control.PRESET_CENTER)
	_portrait_note.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_portrait_note.add_theme_color_override("font_outline_color", Color.BLACK)
	_portrait_note.add_theme_constant_override("outline_size", 8)
	_portrait_note.visible = false
	root.add_child(_portrait_note)


func _home() -> void:
	camera.center_on(sim.core.center() * WorldGrid.TILE_PX)


## Core health: caption, value and a bar.
func _core_stat(bar_width: float) -> Control:
	var core := UiTheme.stat("Core")
	_core_val = core[1]
	_core_bar = UiTheme.bar(bar_width, 4, UiTheme.GOOD)
	core[0].add_child(_core_bar)
	return core[0]


## Wave / assault state: caption, countdown and a progress bar.
func _wave_stat(width: float) -> Control:
	var wave := UiTheme.stat("Wave")
	_wave_cap = wave[0].get_child(0)
	_wave_val = wave[1]
	_wave_val.custom_minimum_size.x = width
	_wave_bar = UiTheme.bar(width, 4, UiTheme.WARN)
	wave[0].add_child(_wave_bar)
	return wave[0]


## Pause + 1x/2x/3x as a segmented control.
func _speed_group() -> Control:
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", 2)
	_pause_btn = _small_button("II", func() -> void: pause_toggled.emit(), 34)
	_pause_btn.toggle_mode = true
	_pause_btn.tooltip_text = "Pause [Space]"
	group.add_child(_pause_btn)
	for k in SPEED_LABELS.size():
		var b := _small_button(SPEED_LABELS[k], func() -> void: speed_selected.emit(k), 36)
		b.toggle_mode = true
		b.tooltip_text = "Game speed %s [+/-]" % SPEED_LABELS[k]
		group.add_child(b)
		_speed_btns.append(b)
	return group


func _alert_label() -> Label:
	var l := _label(12)
	l.add_theme_color_override("font_color", UiTheme.BAD)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.visible = false
	return l


func _build_resources(root: Control, at: Vector2, expanded: bool) -> void:
	_res_panel = PanelContainer.new()
	_res_panel.position = at
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	var title := _label(12)
	title.text = "RESOURCES"
	title.add_theme_color_override("font_color", ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_res_toggle = _small_button("-" if expanded else "+", func() -> void:
		_res_body.visible = not _res_body.visible
		_res_toggle.text = "-" if _res_body.visible else "+"
		_resources.text = _resources_text()
		_res_panel.reset_size(), 26)
	_res_toggle.custom_minimum_size.y = 22
	_res_toggle.tooltip_text = "Collapse / expand"
	_res_toggle.visible = not _touch  # Phones: the "Res" button shows/hides the panel.
	head.add_child(_res_toggle)
	box.add_child(head)
	_resources = RichTextLabel.new()
	_resources.bbcode_enabled = true
	_resources.fit_content = true
	_resources.scroll_active = false
	_resources.autowrap_mode = TextServer.AUTOWRAP_OFF
	_resources.custom_minimum_size = Vector2(270, 0)
	_resources.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key in ["normal_font_size", "bold_font_size"]:
		_resources.add_theme_font_size_override(key, 13)
	_resources.add_theme_constant_override("table_h_separation", 10)
	_resources.add_theme_constant_override("line_separation", 2)
	_res_body = _resources
	_res_body.visible = expanded or _touch
	box.add_child(_resources)
	_res_panel.add_child(box)
	root.add_child(_res_panel)


func _build_info_panel(root: Control) -> void:
	_info_panel = PanelContainer.new()
	_info_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_info_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_info_panel.offset_top = 50 if _touch else 10
	_info_panel.offset_right = 0 if _touch else -10
	var width := 300.0 if _touch else 330.0
	_info_panel.custom_minimum_size = Vector2(width, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var icon_bg := PanelContainer.new()
	icon_bg.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.SURFACE, 8, UiTheme.BORDER, 3.0))
	_info_icon = TextureRect.new()
	_info_icon.custom_minimum_size = Vector2(40, 40)
	_info_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_info_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_bg.add_child(_info_icon)
	head.add_child(icon_bg)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	_info_title = _label(17)
	_info_title.add_theme_color_override("font_color", Color.WHITE)
	_info_sub = _label(12)
	_info_sub.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	titles.add_child(_info_title)
	titles.add_child(_info_sub)
	head.add_child(titles)
	box.add_child(head)
	box.add_child(HSeparator.new())
	_info_body = RichTextLabel.new()
	_info_body.bbcode_enabled = true
	_info_body.fit_content = true
	_info_body.scroll_active = false
	_info_body.custom_minimum_size = Vector2(width - 24, 0)
	_info_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key in ["normal_font_size", "bold_font_size"]:
		_info_body.add_theme_font_size_override(key, 13)
	_info_body.add_theme_constant_override("line_separation", 3)
	if _touch:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(width - 20, 120)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_info_body.custom_minimum_size.x = width - 36
		scroll.add_child(_info_body)
		box.add_child(scroll)
	else:
		box.add_child(_info_body)
	_info_buttons = HBoxContainer.new()
	_info_buttons.add_theme_constant_override("separation", 6)
	_sell_btn = Button.new()
	_sell_btn.focus_mode = Control.FOCUS_NONE
	_sell_btn.tooltip_text = "Sell [Delete]: refunds credits and materials; contents go to the Core."
	_sell_btn.add_theme_color_override("font_color", UiTheme.BAD.lerp(Color.WHITE, 0.35))
	_sell_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_btn.custom_minimum_size.y = 34
	_sell_btn.pressed.connect(controller.sell_selected)
	_move_btn = Button.new()
	_move_btn.focus_mode = Control.FOCUS_NONE
	_move_btn.tooltip_text = "Move [M]: pick it up and place it elsewhere."
	_move_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_move_btn.custom_minimum_size.y = 34
	_move_btn.pressed.connect(controller.start_move_selected)
	_info_buttons.add_child(_sell_btn)
	_info_buttons.add_child(_move_btn)
	box.add_child(_info_buttons)
	_recipe_btn = Button.new()
	_recipe_btn.focus_mode = Control.FOCUS_NONE
	_recipe_btn.custom_minimum_size.y = 34
	_recipe_btn.tooltip_text = "Switch recipe. Buffered inputs go back to the Core."
	_recipe_btn.pressed.connect(_cycle_recipe)
	_recipe_btn.visible = false
	box.add_child(_recipe_btn)
	_info_panel.add_child(box)
	_info_panel.visible = false
	root.add_child(_info_panel)


## Credits, toast, game over and the menu (shared by both layouts).
func _build_overlays(root: Control) -> void:
	_credits = PanelContainer.new()
	_credits.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.BG_SOLID, 14, UiTheme.BORDER, 18.0, true))
	_credits.set_anchors_preset(Control.PRESET_CENTER)
	_credits.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_credits.grow_vertical = Control.GROW_DIRECTION_BOTH
	var cr_box := VBoxContainer.new()
	cr_box.add_theme_constant_override("separation", 10)
	var cr_title := _label(22)
	cr_title.text = "Credits"
	cr_title.add_theme_color_override("font_color", ACCENT)
	cr_box.add_child(cr_title)
	var cr_text := RichTextLabel.new()
	cr_text.bbcode_enabled = true
	cr_text.custom_minimum_size = Vector2(560, 300) if _touch else Vector2(820, 520)
	cr_text.text = credits_bbcode(_read_credits())
	cr_box.add_child(cr_text)
	var close := Button.new()
	close.text = "Close"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(120, 36)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(func() -> void: _credits.visible = false)
	cr_box.add_child(close)
	_credits.add_child(cr_box)
	_credits.visible = false
	root.add_child(_credits)

	_build_menu(root)

	_toast = PanelContainer.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = 60 if _touch else 104
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = _label(15)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_label)
	_toast.visible = false
	root.add_child(_toast)

	_game_over = PanelContainer.new()
	_game_over.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.BG_SOLID, 16, Color(UiTheme.BAD, 0.5), 28.0, true))
	_game_over.set_anchors_preset(Control.PRESET_CENTER)
	_game_over.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_game_over.grow_vertical = Control.GROW_DIRECTION_BOTH
	var go_box := VBoxContainer.new()
	go_box.add_theme_constant_override("separation", 14)
	var go_title := _label(30)
	go_title.text = "THE CORE HAS FALLEN"
	go_title.add_theme_color_override("font_color", UiTheme.BAD)
	go_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_box.add_child(go_title)
	_game_over_label = _label(16)
	_game_over_label.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_box.add_child(_game_over_label)
	var restart := _accent_button("Play again")
	restart.custom_minimum_size = Vector2(180, 42)
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart.pressed.connect(func() -> void: restart_requested.emit())
	go_box.add_child(restart)
	_game_over.add_child(go_box)
	_game_over.visible = false
	root.add_child(_game_over)


## Fills the dock with cards for the buildings of the controller's current tab.
func _rebuild_toolbar() -> void:
	_shown_category = controller.category
	for child in _toolbar.get_children():
		child.queue_free()
	_tool_buttons.clear()
	_tool_costs.clear()
	for def in sim.reg.toolbar_buildings(_shown_category):
		var card := _tool_card(_icons.icon_for(def), def.display_name, "", def.toolbar_slot)
		card.tooltip_text = "%s  [%d]\n%s\n\nCost: %s" % [def.display_name, def.toolbar_slot, def.description, _plain_cost(def)]
		card.pressed.connect(controller.select_build.bind(def))
		_toolbar.add_child(card)
		_tool_buttons[def] = card
		_tool_costs[def] = card.get_meta("cost_label")
	var dig := _tool_card(_icons.excavate_icon(), "Excavate", "%d cr" % sim.rules.excavate_cost, -1)
	dig.tooltip_text = "Excavate  [X]\nRemove rock to open new routes; adds Stone."
	dig.pressed.connect(controller.select_excavate)
	_toolbar.add_child(dig)
	_tool_buttons[&"excavate"] = dig
	for tab in _tabs_row.get_children():
		if tab is Button and tab.has_meta("category"):
			(tab as Button).set_pressed_no_signal(tab.get_meta("category") == _shown_category)
	if _cat_btn != null:
		_cat_btn.text = "%s  >" % String(_shown_category).capitalize()


## A building card: icon, name, cost line and (desktop) a hotkey badge.
func _tool_card(icon: Texture2D, title: String, cost: String, slot: int) -> Button:
	var card := Button.new()
	card.toggle_mode = true
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(84, 64) if _touch else Vector2(100, 96)
	card.add_theme_stylebox_override("pressed", UiTheme.box(Color(ACCENT, 0.2), UiTheme.RADIUS, ACCENT, 4.0))
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0 if _touch else 2)
	var tex := TextureRect.new()
	tex.texture = icon
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.custom_minimum_size = Vector2(0, 26) if _touch else Vector2(0, 40)
	col.add_child(tex)
	var name_label := _label(11 if _touch else 12)
	name_label.text = title
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	col.add_child(name_label)
	var cost_label := _label(11)
	cost_label.text = cost
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_color_override("font_color", UiTheme.GOLD)
	col.add_child(cost_label)
	var mats_label := _label(10)
	mats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mats_label.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	mats_label.visible = not _touch
	col.add_child(mats_label)
	card.add_child(col)
	card.set_meta("cost_label", cost_label)
	card.set_meta("mats_label", mats_label)
	if slot > 0 and not _touch:
		var key := _label(10)
		key.text = str(slot)
		key.position = Vector2(6, 3)
		key.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
		card.add_child(key)
	return card


## Material part of a card's cost: "10 Copper, 5 Steel" ("" when credits only).
func _card_mats(def: BuildingDef) -> String:
	var parts := PackedStringArray()
	for id in def.material_cost:
		var idx := sim.reg.item_index(StringName(id))
		parts.append("%d %s" % [def.material_cost[id], sim.reg.items[idx].display_name.split(" ")[0]])
	return ", ".join(parts)


## Cost without "(have N)" markers, for tooltips.
func _plain_cost(def: BuildingDef) -> String:
	var parts := PackedStringArray(["%d credits" % def.cost])
	for id in def.material_cost:
		var idx := sim.reg.item_index(StringName(id))
		parts.append("%d %s" % [def.material_cost[id], sim.reg.items[idx].display_name])
	return " + ".join(parts)


func _refresh_tools() -> void:
	if controller.category != _shown_category:
		_rebuild_toolbar()
	for tab in _tabs_row.get_children():
		if tab is Button and tab.has_meta("category"):
			(tab as Button).set_pressed_no_signal(tab.get_meta("category") == _shown_category)
	for key in _tool_buttons:
		var btn: Button = _tool_buttons[key]
		var active := false
		var affordable := true
		if key is BuildingDef:
			active = controller.mode == BuildController.Mode.BUILD and controller.build_def == key
			var cr_ok: bool = sim.credits >= key.cost
			var mat_ok: bool = sim.has_materials(key.material_cost)
			affordable = cr_ok and mat_ok
			var cost: Label = _tool_costs[key]
			cost.text = "%d cr%s" % [key.cost, " +" if _touch and not key.material_cost.is_empty() else ""]
			cost.add_theme_color_override("font_color", UiTheme.GOLD if cr_ok else UiTheme.BAD)
			var mats: Label = btn.get_meta("mats_label")
			mats.text = _card_mats(key)
			mats.add_theme_color_override("font_color", UiTheme.TEXT_DIM if mat_ok else UiTheme.BAD)
		else:
			active = controller.mode == BuildController.Mode.EXCAVATE
			affordable = sim.credits >= sim.rules.excavate_cost
		btn.set_pressed_no_signal(active)
		btn.modulate = Color.WHITE if affordable or active else Color(1, 1, 1, 0.6)
	_refresh_info()


## Scales the whole HUD by the "UI scale" option, keeping anchors correct.
func apply_ui_scale() -> void:
	if _root == null:
		return
	var s := clampf(GameSettings.get_instance().ui_scale, 0.75, 2.5)
	var vp := get_viewport().get_visible_rect().size
	# Phones: keep clear of rounded corners / the notch in landscape.
	var margin := Vector2(36, 6) if _touch else Vector2.ZERO
	_root.scale = Vector2(s, s)
	_root.position = margin
	_root.size = (vp - margin * 2.0) / s
	if _portrait_note != null:
		_portrait_note.visible = vp.y > vp.x


func is_menu_open() -> bool:
	return _menu != null and _menu.visible


## Opens/closes the game menu; the game is paused while it is open.
func toggle_menu() -> void:
	if not _menu.visible:
		_paused_before_menu = clock.paused
		clock.paused = true
		_menu.visible = true
		_menu_backdrop.visible = true
		_menu.modulate.a = 0.0
		create_tween().tween_property(_menu, "modulate:a", 1.0, 0.15)
	else:
		_menu.visible = false
		_menu_backdrop.visible = false
		_credits.visible = false
		clock.paused = _paused_before_menu


func _build_menu(root: Control) -> void:
	# Dims the game and swallows clicks while the menu is open.
	_menu_backdrop = ColorRect.new()
	_menu_backdrop.color = Color(0.01, 0.02, 0.04, 0.6)
	_menu_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_backdrop.visible = false
	root.add_child(_menu_backdrop)
	_menu = PanelContainer.new()
	_menu.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.BG_SOLID, 16, UiTheme.BORDER, 22.0, true))
	_menu.set_anchors_preset(Control.PRESET_CENTER)
	_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(420, 0)
	var title := _label(26)
	title.text = "Paused"
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var version := _label(12)
	version.text = "Frontier Stronghold  v%s" % ProjectSettings.get_setting("application/config/version", "dev")
	version.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(version)
	var resume := _accent_button("Resume")
	resume.custom_minimum_size.y = 40
	resume.pressed.connect(toggle_menu)
	box.add_child(resume)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	for spec in [["Restart", func() -> void: restart_requested.emit()],
			["Credits", func() -> void:
				_credits.visible = true
				_credits.move_to_front()],
			["Quit", func() -> void: quit_requested.emit()]]:
		var b := Button.new()
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size.y = 36
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(spec[1])
		actions.add_child(b)
	box.add_child(actions)
	box.add_child(HSeparator.new())
	var opts := _label(12)
	opts.text = "OPTIONS"
	opts.add_theme_color_override("font_color", ACCENT)
	box.add_child(opts)
	box.add_child(_slider_row("HUD scale", "ui_scale", 0.75, 2.5, 0.05))
	box.add_child(_slider_row("Camera pan speed", "pan_speed", 0.5, 2.5, 0.1))
	box.add_child(_slider_row("Zoom sensitivity", "zoom_speed", 0.3, 2.5, 0.1))
	box.add_child(_check_row("Show enemy routes", "show_routes"))
	if not _touch:
		box.add_child(_check_row("Fullscreen", "fullscreen"))
	var note := _label(12)
	note.text = "Options are saved automatically."
	note.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
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




static func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Compact button with a minimum width (0 = fit the text).
static func _small_button(text: String, action: Callable, width: float) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(width, 32)
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(action)
	return b


## Call-to-action button (accent fill).
static func _accent_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 34)
	b.add_theme_font_size_override("font_size", 13)
	var n := UiTheme.box(Color(UiTheme.ACCENT, 0.85), UiTheme.RADIUS, Color(0, 0, 0, 0), 10.0)
	var h := UiTheme.box(UiTheme.ACCENT.lightened(0.25), UiTheme.RADIUS, Color(0, 0, 0, 0), 10.0)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", n)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(key, Color(0.02, 0.06, 0.1))
	return b


static func _spacer(width: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.x = width
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
