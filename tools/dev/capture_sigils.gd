extends SceneTree
## Renders the five Aspect sigils at every size they will actually be used at, so
## "is this readable at 14 px?" is answered by LOOKING, not by assuming.
## Run: tools/dev/run_hidden.sh -s res://tools/dev/capture_sigils.gd

const SIZES := [14, 20, 28, 44, 80, 140]

func _initialize() -> void:
	OS.set_environment("TEST_PROFILE", "bot")
	_go()

func _go() -> void:
	await process_frame
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.10)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var y := 40
	for aspect in [Aspects.Id.LIFE, Aspects.Id.MIND, Aspects.Id.DEATH, Aspects.Id.CHAOS, Aspects.Id.NATURE]:
		var name_l := Label.new()
		name_l.text = TranslationServer.translate(Aspects.name_key(aspect))
		name_l.add_theme_font_size_override("font_size", 14)
		name_l.add_theme_color_override("font_color", Aspects.color(aspect))
		name_l.position = Vector2(24, y + 50)
		root.add_child(name_l)
		var x := 150
		for s in SIZES:
			var sig := AspectSigil.new(aspect, Aspects.color(aspect), true)
			sig.position = Vector2(x, y + 70 - s / 2)
			sig.size = Vector2(s, s)
			root.add_child(sig)
			var outline := AspectSigil.new(aspect, Aspects.color(aspect), false)
			outline.position = Vector2(x, y + 70 - s / 2 + 0)
			outline.size = Vector2(s, s)
			outline.position.x += 620
			root.add_child(outline)
			x += s + 34
		y += 130
	var caption := Label.new()
	caption.text = "filled (left)                                                   outline (right)"
	caption.position = Vector2(150, 8)
	root.add_child(caption)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/sigils.png")
	print("[sigils] wrote screenshots/sigils.png")
	quit()
