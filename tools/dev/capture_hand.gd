extends SceneTree
## Visual check of the Arena-style hand: enter a fight, hover a middle card with REAL input,
## screenshot the grown card over its overlapped neighbours.
## Run: tools/dev/run_hidden.sh -s res://tools/dev/capture_hand.gd

const RUN := "res://src/game/region/run.tscn"

func _initialize() -> void:
	if OS.get_environment("TEST_PROFILE") == "":
		OS.set_environment("TEST_PROFILE", "bot")
	_go()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shoot(name: String) -> void:
	await _frames(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/hand_%s.png" % name)

func _motion(pos: Vector2) -> void:
	Input.warp_mouse(pos)
	var mm := InputEventMouseMotion.new()
	mm.position = pos
	mm.global_position = pos
	Input.parse_input_event(mm)

func _click(pos: Vector2) -> void:
	_motion(pos)
	await _frames(1)
	var d := InputEventMouseButton.new()
	d.button_index = MOUSE_BUTTON_LEFT
	d.pressed = true
	d.position = pos
	d.global_position = pos
	d.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(d)
	await _frames(1)
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT
	u.pressed = false
	u.position = pos
	u.global_position = pos
	Input.parse_input_event(u)
	await _frames(2)

func _find(node: Node, pred: Callable):
	if node is Control and pred.call(node):
		return node
	for c in node.get_children():
		var r = _find(c, pred)
		if r:
			return r
	return null

func _button_with(root_n: Node, key: String):
	var want := TranslationServer.translate(key)
	return _find(root_n, func(c): return c is Button and c.text == want and c.is_visible_in_tree())

func _go() -> void:
	await _frames(2)
	var rn: Node = load(RUN).instantiate()
	root.add_child(rn)
	await _frames(20)
	var take = _button_with(rn, "DRAFT_TAKE")
	if take != null:
		if rn._arc_panels.size() > 0:
			await _click(rn._arc_panels[0].get_global_rect().get_center())
		take = _button_with(rn, "DRAFT_TAKE")
		if take != null and not take.disabled:
			await _click(take.get_global_rect().get_center())
		await _frames(15)
	var go = _button_with(rn, "MAP_GO")
	if go != null:
		await _click(go.get_global_rect().get_center())
	await _frames(30)
	var combat = _find(rn, func(c): return c.has_method("setup"))
	if combat == null:
		print("hand_capture: no combat")
		quit(1)
		return
	await _frames(10)
	await _shoot("resting")
	# hover the middle card (real motion), let the grow tween finish, then shoot
	var kids: Array = combat._hand_row.get_children()
	if kids.size() >= 4:
		var mid: Control = kids[3]
		_motion(mid.get_global_rect().get_center())
		await _frames(14)
		await _shoot("hover")
	print("hand_capture: done")
	quit(0)
