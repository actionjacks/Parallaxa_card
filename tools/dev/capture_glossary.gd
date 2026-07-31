extends SceneTree
## Shoots the glossary screen. "The code looks right" is not evidence that a wall of text is
## readable at 720p -- this is how we look at it.
## Run: tools/dev/run_hidden.sh -s res://tools/dev/capture_glossary.gd

const RUN := "res://src/game/region/run.tscn"

func _initialize() -> void:
	OS.set_environment("TEST_PROFILE", "bot")
	_go()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _go() -> void:
	await _frames(2)
	var rn: Node = load(RUN).instantiate()
	root.add_child(rn)
	await _frames(25)
	var ov := root.get_node_or_null("Overlays")
	if ov == null:
		print("[gloss] no Overlays autoload")
		quit()
		return
	ov.call("_open_glossary")
	await _frames(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/glossary.png")
	print("[gloss] wrote screenshots/glossary.png")
	quit()
