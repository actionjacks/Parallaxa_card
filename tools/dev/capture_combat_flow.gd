extends SceneTree
## Dev tool: drive the combat scene (select two Death 7s -> preview -> play) and screenshot
## each state, to verify the interactive loop renders. Run:
## tools/dev/run_hidden.sh -s res://tools/dev/capture_combat_flow.gd

const SCENE := "res://src/game/combat/combat.tscn"

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var scene: Node = load(SCENE).instantiate()
	root.add_child(scene)
	for i in 30:
		await process_frame

	# Select the two Death 7s (hand indices 0 and 1) and show the preview.
	scene._selected.clear()
	scene._selected.append(0)
	scene._selected.append(1)
	scene._refresh_card_styles()
	scene._update_selection_ui()
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/combat_preview.png")

	# Play them: 72 damage + Rot 3, then the enemy acts.
	scene._on_play()
	for i in 25:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/combat_after.png")

	print("capture_flow: done")
	quit(0)
