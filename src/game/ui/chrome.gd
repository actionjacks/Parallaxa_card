class_name Chrome
## THE FURNITURE OF THE GAME, IN ONE PLACE.
##
## Every panel, bar and button in this project was a flat rectangle with a one-pixel border, drawn
## wherever it was needed, with its colours typed in at the call site. That is why the interface
## read as a prototype however good the art behind it got: the CHROME was the flat thing, not the
## picture. Screens do not look expensive because their content is expensive -- they look expensive
## because the frame around the content is made of the same material everywhere.
##
## So: one file, one vocabulary. A bevelled plate with a warm inner edge and a cold outer one, a
## bar that is a gradient in a socket rather than a coloured rectangle, and a button that answers
## the cursor. Everything takes an accent, so a screen wears its biome without asking.
##
## Deliberately StyleBoxes and gradients rather than bitmaps: they scale to any size, cost nothing
## on the software-GL test screen, and cannot go missing from an export.

const INK := Color(0.045, 0.040, 0.058)

static func _sb(bg: Color, border: Color, w: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(w)
	sb.set_corner_radius_all(radius)
	return sb


## THE PLATE. Two borders doing different jobs: a bright top edge that reads as a lit bevel and a
## dark body that reads as depth. One StyleBox cannot do both, so the caller stacks a thin
## highlight strip over it -- see `bevel()`.
static func panel(accent: Color, lift: float = 0.0) -> StyleBoxFlat:
	var sb := _sb(INK.lerp(accent, 0.05 + 0.05 * lift), accent.lerp(Color(1, 1, 1), 0.25), 1, 3)
	sb.bg_color.a = 0.86 + 0.10 * lift
	sb.border_color.a = 0.30 + 0.45 * lift
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = int(4 + 6 * lift)
	sb.shadow_offset = Vector2(0, 2)
	sb.set_content_margin_all(8)
	return sb


## A BUTTON THAT ANSWERS. Flat until touched is what makes an interface feel dead; the hover state
## has to be a different MATERIAL, not a different tint -- brighter edge, lifted bevel, warmer face.
static func button(b: Button, accent: Color) -> Button:
	var normal := _sb(INK.lerp(accent, 0.10), accent.lerp(Color(1, 1, 1), 0.20), 1, 3)
	normal.bg_color.a = 0.90
	normal.border_color.a = 0.42
	normal.set_content_margin_all(9)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.shadow_color = Color(0, 0, 0, 0.5)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 2)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = INK.lerp(accent, 0.30)
	hover.border_color = accent.lerp(Color(1, 1, 1), 0.55)
	hover.border_color.a = 0.95
	hover.set_border_width_all(2)
	hover.shadow_size = 9
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = INK.lerp(accent, 0.18)
	pressed.shadow_size = 1
	pressed.shadow_offset = Vector2(0, 0)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = INK
	disabled.bg_color.a = 0.55
	disabled.border_color = Color(0.35, 0.34, 0.40, 0.25)
	disabled.shadow_size = 0
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_color_override("font_color", Color(0.94, 0.92, 0.86))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.44, 0.50))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


## A BAR IS A LIQUID IN A SOCKET, not a coloured rectangle. The socket is dark and inset; the fill
## is a gradient that is brightest at its leading edge, so a bar that is draining reads as draining
## even in a still frame.
static func bar(p: ProgressBar, low: Color, high: Color) -> ProgressBar:
	var back := _sb(Color(0.02, 0.02, 0.03, 0.92), Color(0, 0, 0, 0.85), 1, 2)
	back.set_content_margin_all(0)
	var g := Gradient.new()
	g.set_color(0, low)
	g.set_color(1, high)
	g.add_point(0.82, high.lerp(Color(1, 1, 1), 0.35))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 128
	gt.height = 1
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	var fill := StyleBoxTexture.new()
	fill.texture = gt
	p.add_theme_stylebox_override("background", back)
	p.add_theme_stylebox_override("fill", fill)
	p.show_percentage = false
	return p


## The thin lit strip that sells a bevel. Added as a child of the plate it crowns.
static func bevel(host: Control, accent: Color) -> void:
	var line := ColorRect.new()
	line.color = accent.lerp(Color(1, 1, 1), 0.55)
	line.color.a = 0.22
	line.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	line.offset_top = 1.0
	line.offset_bottom = 2.0
	line.offset_left = 2.0
	line.offset_right = -2.0
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(line)
