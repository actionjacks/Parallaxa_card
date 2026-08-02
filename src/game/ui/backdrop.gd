class_name Backdrop
## A shared themed background so screens don't float in flat black. An ash-toned vertical gradient
## plus a radial vignette. Built in code (no art assets). Add it first so it sits behind everything.

static func build(accent: Color = Color(0, 0, 0, 0)) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Region identity: the bottom ember stop leans toward the region accent (subtle, 18%).
	var bottom := Color(0.10, 0.06, 0.045)
	if accent.a > 0.0:
		bottom = bottom.lerp(accent, 0.18)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.055, 0.045, 0.05))   # top: cold ash
	grad.set_color(1, bottom)                      # bottom: faint ember warmth, region-tinted
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 8
	gt.height = 256
	root.add_child(_rect(gt))

	var vg := Gradient.new()
	vg.set_color(0, Color(0, 0, 0, 0.0))
	vg.set_color(1, Color(0, 0, 0, 0.55))
	var vgt := GradientTexture2D.new()
	vgt.gradient = vg
	vgt.fill = GradientTexture2D.FILL_RADIAL
	vgt.fill_from = Vector2(0.5, 0.5)
	vgt.fill_to = Vector2(1.05, 0.5)
	vgt.width = 256
	vgt.height = 256
	root.add_child(_rect(vgt))

	# DEPTH AND MOTION, ON EVERY SCREEN AT ONCE. Two static gradients is what every screen except
	# the map was standing on -- correct, and completely dead. Three cheap layers fix it for all of
	# them, because _refresh_backdrop() is shared:
	#   HAZE   a wide band of drifting noise, slow, low-contrast: the room has air in it
	#   MOTES  particles rising through the frame in the region's colour, at two speeds so the
	#          field reads as deep rather than as a flat sheet of dots
	#   PULSE  a radial glow that breathes -- the reason a still screenshot still feels alive
	root.add_child(_haze(accent))
	for layer in 2:
		root.add_child(_motes(accent, layer))
	root.add_child(_pulse(accent))
	root.set_script(preload("res://src/game/ui/backdrop_life.gd"))
	return root

## The drifting haze: one noise texture, scrolled by the live script.
static func _haze(accent: Color) -> TextureRect:
	var n := NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX
	fn.frequency = 0.0035
	fn.fractal_octaves = 3
	n.noise = fn
	n.width = 320
	n.height = 180
	n.seamless = true
	var r := _rect(n)
	r.name = "Haze"
	r.stretch_mode = TextureRect.STRETCH_TILE
	var tint: Color = accent if accent.a > 0.0 else Color(0.5, 0.4, 0.45)
	r.modulate = Color(tint.r, tint.g, tint.b, 0.075)
	return r

## Motes rising through the frame. Two layers at different speeds and sizes = parallax.
static func _motes(accent: Color, layer: int) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 26 if layer == 0 else 16
	p.lifetime = 13.0 if layer == 0 else 8.0
	p.preprocess = 8.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(660, 20)
	p.position = Vector2(640, 760)
	p.direction = Vector2(0, -1)
	p.spread = 14.0
	p.gravity = Vector2(6.0 * (1.0 if layer == 0 else -1.0), -14.0 - 12.0 * float(layer))
	p.scale_amount_min = 1.0 + 1.4 * float(layer)
	p.scale_amount_max = 2.2 + 2.0 * float(layer)
	var tint: Color = accent if accent.a > 0.0 else Color(0.95, 0.82, 0.55)
	p.color = Color(tint.r, tint.g, tint.b, 0.16 if layer == 0 else 0.09)
	# CPUParticles2D is a Node2D, not a Control -- it has no mouse_filter and never eats a click.
	return p

## The breathing glow. Alpha is driven by the live script; the texture never changes.
static func _pulse(accent: Color) -> TextureRect:
	var g := Gradient.new()
	var tint: Color = accent if accent.a > 0.0 else Color(0.9, 0.6, 0.35)
	g.set_color(0, Color(tint.r, tint.g, tint.b, 0.20))
	g.set_color(1, Color(tint.r, tint.g, tint.b, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.62)
	gt.fill_to = Vector2(1.0, 0.62)
	gt.width = 256
	gt.height = 256
	var r := _rect(gt)
	r.name = "Pulse"
	return r

static func _rect(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
