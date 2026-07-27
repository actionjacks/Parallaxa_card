extends SceneTree
## Visual check of Phase A/B: the New Run setup (seed entry), the PROPHECY stamp on a lethal
## selection, and the fulfilled roll-up after the click. Real input on the hidden screen.
## Run: tools/dev/run_hidden.sh -s res://tools/dev/capture_prophecy.gd

const MENU := "res://src/game/menu/menu.tscn"
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
	root.get_texture().get_image().save_png("res://screenshots/pr_%s.png" % name)

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

func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()

func _go() -> void:
	await _frames(2)
	# --- menu: Daily button + the setup overlay with the fate-code field ---
	var menu: Node = load(MENU).instantiate()
	root.add_child(menu)
	await _frames(15)
	await _shoot("menu")
	var nb = _button_with(menu, "MENU_NEW")
	if nb != null:
		await _click(_center(nb))
		await _frames(10)
		if _find(menu, func(c): return c is LineEdit and c.is_visible_in_tree()) != null:
			await _shoot("setup_seed")
			var cancel = _button_with(menu, "COMMON_CANCEL")
			if cancel != null:
				await _click(_center(cancel))
		else:
			print("[pr] fresh profile: no setup overlay (direct start path)")
	menu.queue_free()
	await _frames(5)

	# --- combat: force a lethal selection, capture the stamp, then the fulfilment ---
	var rn: Node = load(RUN).instantiate()
	root.add_child(rn)
	await _frames(20)
	var rs := root.get_node("RunState")
	# a guaranteed one-shot: five leveled 7s make the opening play lethal vs region-1 HP
	rs.hand_levels = {Poker.Hand.FIVE: 6, Poker.Hand.MAGNUM_OPUS: 4, Poker.Hand.THREE: 8}
	for i in 4:
		var c := CardData.new()
		c.rank = 7
		c.aspect = Aspects.Id.DEATH
		rs.deck.append(c)
	var take = _button_with(rn, "DRAFT_TAKE")
	if take != null:
		if rn._arc_panels.size() > 0:
			await _click(_center(rn._arc_panels[0]))
		take = _button_with(rn, "DRAFT_TAKE")
		if take != null and not take.disabled:
			await _click(_center(take))
		await _frames(15)
	var go = _button_with(rn, "MAP_GO")
	if go != null:
		await _click(_center(go))
	await _frames(30)
	var combat = _find(rn, func(c): return c.has_method("setup"))
	if combat == null:
		print("[pr] no combat")
		quit(1)
		return
	await _frames(8)
	# select the best trips/five: click all rank-7 cards in hand
	var ctrl = combat.controller
	var picked := 0
	for i in ctrl.hand.size():
		if ctrl.hand[i].rank == 7 and picked < 5:
			var kids: Array = combat._hand_row.get_children()
			# hand indices shift as selection raises cards; find widget by card identity
			var card = ctrl.hand[i]
			var w = combat._widgets.get(card)
			if w != null:
				await _click(_center(w))
				picked += 1
	await _frames(10)
	var r = ctrl.preview(combat._selected_indices())
	print("[pr] selected=%d preview_dmg=%d enemy_hp=%d lethal=%s" % [picked, int(r["damage"]), ctrl.enemy_hp, str(int(r["damage"]) >= ctrl.enemy_hp)])
	await _shoot("prophecy_stamp")
	if not combat._play_btn.disabled:
		await _click(_center(combat._play_btn))
	await _frames(25)
	await _shoot("fulfilled")
	print("prophecy_capture: done")
	quit(0)
