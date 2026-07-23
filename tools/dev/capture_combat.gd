extends SceneTree
## Dev tool: render the combat scene on the hidden display and save a screenshot, then quit.
## Run via: tools/dev/run_hidden.sh -s res://tools/dev/capture_combat.gd
## Output goes to screenshots/ (gitignored) for review, not commit.

const SCENE := "res://src/game/combat/combat.tscn"
const OUT := "res://screenshots/combat_capture.png"

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var scene: Node = load(SCENE).instantiate()
	root.add_child(scene)
	for i in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var err: int = img.save_png(OUT)
	if err != OK:
		printerr("capture: save failed (", err, ")")
	else:
		print("capture: saved ", OUT)
	quit(0)
