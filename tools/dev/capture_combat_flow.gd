extends SceneTree
## Dev tool: screenshot the card preview (hover), the selection, cards mid-flight to the enemy on
## play, and the settled state. Run: tools/dev/run_hidden.sh -s res://tools/dev/capture_combat_flow.gd

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

	# Large card preview (as if hovering the first card).
	scene._show_card_preview(scene.controller.hand[0])
	await _shoot("preview", 4)
	scene._hide_card_preview()

	# Select two cards and play them; capture the cards mid-flight to the enemy.
	scene._selected.clear()
	scene._selected.append(scene.controller.hand[0])
	scene._selected.append(scene.controller.hand[1])
	scene._refresh_card_styles()
	scene._update_selection_ui()
	await _shoot("selected", 4)
	scene._on_play()
	await _shoot("fly", 8)       # cards mid-flight to the enemy
	await _shoot("after", 55)    # settled after the paused enemy turn

	print("capture_flow: done")
	quit(0)
