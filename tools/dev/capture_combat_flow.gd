extends SceneTree
## Dev tool: drive the combat scene (select two Death 7s -> preview -> play) and screenshot
## the preview, a mid-animation frame (damage popup), and the settled state.
## Run: tools/dev/run_hidden.sh -s res://tools/dev/capture_combat_flow.gd

const SCENE := "res://src/game/combat/combat.tscn"

func _initialize() -> void:
	_run()

func _shoot(name: String, frames: int) -> void:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/combat_%s.png" % name)

func _run() -> void:
	await process_frame
	var scene: Node = load(SCENE).instantiate()
	root.add_child(scene)
	for i in 30:
		await process_frame

	scene._selected.clear()
	scene._selected.append(0)
	scene._selected.append(1)
	scene._refresh_card_styles()
	scene._update_selection_ui()
	await _shoot("preview", 3)

	scene._on_play()
	await _shoot("fx", 6)       # mid-animation: damage popup rising
	await _shoot("after", 40)   # settled

	print("capture_flow: done")
	quit(0)
