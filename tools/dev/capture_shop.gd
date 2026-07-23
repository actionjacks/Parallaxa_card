extends SceneTree
## Dev tool: screenshot the deep shop (buy/enchant/reroll) and the deck-picker (with editioned
## cards). Run: tools/dev/run_hidden.sh -s res://tools/dev/capture_shop.gd

const RUN := "res://src/game/region/run.tscn"

func _initialize() -> void:
	_go()

func _shoot(name: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/shop_%s.png" % name)

func _go() -> void:
	await process_frame
	var rs: Node = root.get_node("RunState")
	var run: Node = load(RUN).instantiate()
	root.add_child(run)
	for i in 10:
		await process_frame
	rs.rtec = 30
	# Pre-enchant a few deck cards so the picker shows editions.
	rs.deck[0].edition = CardData.Edition.POLYCHROME
	rs.deck[1].edition = CardData.Edition.FOIL
	rs.deck[2].edition = CardData.Edition.HOLO
	run._show_shop()
	await _shoot("deep")
	run._enchant(CardData.Edition.HOLO)   # opens the deck-picker
	await _shoot("picker")
	print("shop_capture done")
	quit(0)
