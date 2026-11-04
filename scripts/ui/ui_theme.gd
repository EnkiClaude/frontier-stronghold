class_name UiTheme
extends RefCounted
## The HUD's visual style, built in code: one [Theme] applied to the HUD root
## so every button, panel, slider, tooltip and scrollbar looks the same.
## Colours are named here so HUD code never hardcodes its own palette.

# --- Palette -----------------------------------------------------------------
const BG := Color(0.055, 0.075, 0.105, 0.92)        ## Panels.
const BG_SOLID := Color(0.07, 0.09, 0.125)           ## Menus, tooltips.
const SURFACE := Color(0.11, 0.14, 0.19)             ## Buttons, cards.
const SURFACE_HOVER := Color(0.15, 0.19, 0.25)
const SURFACE_PRESSED := Color(0.09, 0.12, 0.16)
const BORDER := Color(1, 1, 1, 0.07)
const ACCENT := Color(0.38, 0.86, 1.0)               ## Selection, headings.
const ACCENT_SOFT := Color(0.38, 0.86, 1.0, 0.16)
const TEXT := Color(0.9, 0.93, 0.97)
const TEXT_DIM := Color(0.58, 0.64, 0.72)
const GOOD := Color(0.4, 0.92, 0.55)
const WARN := Color(1.0, 0.76, 0.3)
const BAD := Color(1.0, 0.4, 0.36)
const GOLD := Color(1.0, 0.84, 0.4)                  ## Credits.

const RADIUS := 8
const FONT_SIZE := 14


## Rounded box with optional border, shadow and padding.
static func box(bg: Color, radius: int = RADIUS, border: Color = BORDER, pad: float = 8.0, shadow: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	if border.a > 0.0:
		s.border_color = border
		s.set_border_width_all(1)
	if shadow:
		s.shadow_color = Color(0, 0, 0, 0.35)
		s.shadow_size = 8
		s.shadow_offset = Vector2(0, 3)
	s.anti_aliasing = true
	return s


## Floating panel (status bar, dock, info panel).
static func panel(pad: float = 10.0) -> StyleBoxFlat:
	return box(BG, 12, BORDER, pad, true)


static func build(touch: bool) -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_SIZE

	# Buttons: flat surfaces, accent ring on hover, accent fill when toggled on.
	var pad := 10.0 if touch else 8.0
	var normal := box(SURFACE, RADIUS, BORDER, pad)
	normal.content_margin_top = 5
	normal.content_margin_bottom = 5
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = SURFACE_HOVER
	hover.border_color = Color(ACCENT, 0.45)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(ACCENT, 0.22)
	pressed.border_color = ACCENT
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(SURFACE, 0.5)
	for cls in ["Button", "CheckBox"]:
		t.set_stylebox("normal", cls, normal if cls == "Button" else StyleBoxEmpty.new())
		t.set_stylebox("hover", cls, hover if cls == "Button" else StyleBoxEmpty.new())
		t.set_stylebox("pressed", cls, pressed if cls == "Button" else StyleBoxEmpty.new())
		t.set_stylebox("hover_pressed", cls, pressed if cls == "Button" else StyleBoxEmpty.new())
		t.set_stylebox("disabled", cls, disabled if cls == "Button" else StyleBoxEmpty.new())
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_pressed_color", cls, ACCENT)
		t.set_color("font_hover_pressed_color", cls, ACCENT)
		t.set_color("font_disabled_color", cls, Color(TEXT_DIM, 0.6))
		t.set_color("icon_normal_color", cls, Color.WHITE)
		t.set_color("icon_disabled_color", cls, Color(1, 1, 1, 0.4))

	var cb := 22 if touch else 18
	t.set_icon("unchecked", "CheckBox", _check_icon(cb, false))
	t.set_icon("checked", "CheckBox", _check_icon(cb, true))
	t.set_constant("h_separation", "CheckBox", 8)

	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_stylebox("panel", "TooltipPanel", box(BG_SOLID, 8, Color(ACCENT, 0.35), 10.0, true))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 13)
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)

	# Progress bars (Core health, assault timer).
	t.set_stylebox("background", "ProgressBar", box(Color(0, 0, 0, 0.45), 4, Color(0, 0, 0, 0), 0.0))
	t.set_stylebox("fill", "ProgressBar", box(GOOD, 4, Color(0, 0, 0, 0), 0.0))
	t.set_constant("outline_size", "ProgressBar", 0)

	# Sliders.
	t.set_stylebox("slider", "HSlider", box(Color(1, 1, 1, 0.1), 3, Color(0, 0, 0, 0), 2.0))
	t.set_stylebox("grabber_area", "HSlider", box(Color(ACCENT, 0.7), 3, Color(0, 0, 0, 0), 2.0))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT, 3, Color(0, 0, 0, 0), 2.0))
	var knob := _circle(18 if touch else 14, ACCENT)
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", _circle(18 if touch else 14, Color.WHITE))

	# Thin scrollbars.
	for cls in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", cls, box(Color(1, 1, 1, 0.04), 3, Color(0, 0, 0, 0), 2.0))
		t.set_stylebox("grabber", cls, box(Color(1, 1, 1, 0.22), 3, Color(0, 0, 0, 0), 2.0))
		t.set_stylebox("grabber_highlight", cls, box(Color(ACCENT, 0.6), 3, Color(0, 0, 0, 0), 2.0))
		t.set_stylebox("grabber_pressed", cls, box(ACCENT, 3, Color(0, 0, 0, 0), 2.0))

	t.set_stylebox("separator", "HSeparator", box(Color(1, 1, 1, 0.08), 0, Color(0, 0, 0, 0), 0.0))
	t.set_constant("separation", "HSeparator", 12)
	return t


## Small caption + big value, the building block of the status bar.
static func stat(caption: String, value_size: int = 17) -> Array:
	var box_v := VBoxContainer.new()
	box_v.add_theme_constant_override("separation", -2)
	box_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap := Label.new()
	cap.text = caption.to_upper()
	cap.add_theme_font_size_override("font_size", 10)
	cap.add_theme_color_override("font_color", TEXT_DIM)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var val := Label.new()
	val.add_theme_font_size_override("font_size", value_size)
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box_v.add_child(cap)
	box_v.add_child(val)
	return [box_v, val]


## Thin coloured progress bar.
static func bar(width: float, height: float, col: Color) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = Vector2(width, height)
	p.max_value = 1.0
	p.step = 0.0
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("fill", box(col, 3, Color(0, 0, 0, 0), 0.0))
	p.add_theme_stylebox_override("background", box(Color(0, 0, 0, 0.5), 3, Color(0, 0, 0, 0), 0.0))
	return p


## Rounded checkbox: outlined when off, accent-filled with a tick when on.
static func _check_icon(px: int, on: bool) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var r := 4.0
	for x in px:
		for y in px:
			# Signed distance to a rounded square inset by 1 px.
			var q := (Vector2(x + 0.5, y + 0.5) - Vector2(px, px) * 0.5).abs() - Vector2(px * 0.5 - 1.0 - r, px * 0.5 - 1.0 - r)
			var d := q.max(Vector2.ZERO).length() + minf(maxf(q.x, q.y), 0.0) - r
			var inside := clampf(0.5 - d, 0.0, 1.0)
			var col := Color(0, 0, 0, 0)
			if on:
				col = Color(ACCENT, inside)
			else:
				var ring := clampf(1.25 - absf(d + 1.0), 0.0, 1.0)
				col = Color(TEXT_DIM, maxf(ring, 0.0)).blend(Color(0, 0, 0, 0.3 * inside))
			img.set_pixel(x, y, col)
	if on:
		# Tick: two strokes.
		var a := Vector2(px * 0.26, px * 0.52)
		var b := Vector2(px * 0.43, px * 0.7)
		var c := Vector2(px * 0.75, px * 0.32)
		for x in px:
			for y in px:
				var p := Vector2(x + 0.5, y + 0.5)
				var d := minf(_seg_dist(p, a, b), _seg_dist(p, b, c))
				var t := clampf(px * 0.09 - d + 0.5, 0.0, 1.0)
				if t > 0.0:
					img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color(0.02, 0.06, 0.1), t))
	return ImageTexture.create_from_image(img)


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _circle(px: int, col: Color) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var r := px * 0.5
	for x in px:
		for y in px:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			img.set_pixel(x, y, Color(col, clampf(r - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)
