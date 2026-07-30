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

	# The hovered card IS the preview now (the side panel was removed): grow the first card
	# through the hand's own hover path and shoot that.
	var first: Control = scene._widgets.get(scene.controller.hand[0])
	if first != null:
		scene._hand_row._on_child_hover(first, true)
		await _shoot("preview", 4)
		scene._hand_row._on_child_hover(first, false)

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
