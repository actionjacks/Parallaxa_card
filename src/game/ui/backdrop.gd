class_name Backdrop
## A shared themed background so screens don't float in flat black. An ash-toned vertical gradient
## plus a radial vignette. Built in code (no art assets). Add it first so it sits behind everything.

static func build() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var grad := Gradient.new()
	grad.set_color(0, Color(0.055, 0.045, 0.05))   # top: cold ash
	grad.set_color(1, Color(0.10, 0.06, 0.045))    # bottom: faint ember warmth
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

	return root

static func _rect(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
