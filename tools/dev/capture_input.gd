extends SceneTree
## REAL-INPUT tester: drives the game with synthesized mouse motion + clicks (Input.parse_input_event)
## exactly as a player would, on the hidden Xvfb screen. Detects hover flicker and verifies that
## clicking cards/buttons actually works. Run: tools/dev/run_hidden.sh -s res://tools/dev/capture_input.gd

const RUN := "res://src/game/region/run.tscn"

var _rn: Node

func _initialize() -> void:
	_go()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shoot(name: String) -> void:
	await _frames(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/in_%s.png" % name)

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

func _center(ctrl: Control) -> Vector2:
	return ctrl.get_global_rect().get_center()

func _button_with(text_key: String):
	var want := TranslationServer.translate(text_key)
	return _find(_rn, func(c): return c is Button and c.text == want and c.is_visible_in_tree())

func _find_combat():
	return _find(_rn, func(c): return c.has_method("setup"))

func _go() -> void:
	await _frames(2)
	_rn = load(RUN).instantiate()
	root.add_child(_rn)
	await _frames(20)
	# run may open with the Arcanum draft -- click through it like a player
	var take = _button_with("DRAFT_TAKE")
	if take != null:
		if _rn._arc_panels.size() > 0:
			await _click(_center(_rn._arc_panels[0]))
		take = _button_with("DRAFT_TAKE")
		if take != null and not take.disabled:
			await _click(_center(take))
		await _frames(15)
	await _shoot("01_map")

	# --- click ENTER as a real player ---
	var enter = _button_with("MAP_GO")
	print("[in] Enter button found: %s" % str(enter != null))
	if enter == null:
		quit(1)
		return
	await _click(_center(enter))
	await _frames(25)

	var combat = _find_combat()
	print("[in] combat found: %s" % str(combat != null))
	if combat == null:
		quit(1)
		return
	var cards: Array = combat._hand_row.get_children()
	print("[in] hand cards: %d" % cards.size())
	if cards.size() < 2:
		quit(1)
		return

	# --- FLICKER TEST: hover one card steadily and count enter/exit ---
	var counts := {"enter": 0, "exit": 0}
	var card0: Control = cards[0]
	card0.mouse_entered.connect(func(): counts.enter += 1)
	card0.mouse_exited.connect(func(): counts.exit += 1)
	var fixed := _center(card0)          # a real player holds the cursor still
	var idx_before := card0.get_index()
	var pos_before := card0.global_position
	for i in 30:
		_motion(fixed)
		await _frames(1)
	await _shoot("02_hover")
	print("[in] card index %d->%d  pos %s->%s" % [idx_before, card0.get_index(), str(pos_before), str(card0.global_position)])
	print("[in] HOVER FLICKER (fixed cursor, 30 frames): enter=%d exit=%d" % [counts.enter, counts.exit])

	# --- play the WHOLE fight with real clicks until we win ---
	var guard := 0
	while guard < 90:
		guard += 1
		if not is_instance_valid(combat):
			break
		var c = combat.controller
		if c.phase == "ended" or c.enemy_hp <= 0:
			break
		if c.phase != "player":
			await _frames(3)
			continue
		var kids: Array = combat._hand_row.get_children()
		for idx in _best(c.hand):
			if idx < kids.size():
				await _click(_center(kids[idx]))
		var play = _button_with("COMBAT_PLAY")
		if play != null and not play.disabled:
			await _click(_center(play))
		await _frames(45)   # fly-out + paused enemy turn
	print("[in] fight1 finished (combat freed = won): valid=%s" % str(is_instance_valid(combat)))

	# --- the win should transition to the reward screen ---
	await _frames(55)
	await _shoot("05_reward")
	var take = _button_with("REWARD_TAKE")
	print("[in] reward screen reached: take_btn=%s" % str(take != null))
	if take != null:
		var rcards := _find_all(_rn, func(x): return x is PanelContainer and x.has_meta("card") and x.is_visible_in_tree())
		print("[in] reward cards: %d" % rcards.size())
		if rcards.size() > 0:
			await _click(_center(rcards[0]))
		var take2 = _button_with("REWARD_TAKE")
		if take2 != null:
			await _click(_center(take2))
		await _frames(40)
		await _shoot("06_map_after_reward")
		print("[in] after taking reward: deck=%d, back on map" % root.get_node("RunState").deck.size())

	print("input_test: done")
	quit(0)

func _find_all(node: Node, pred: Callable, acc: Array = []) -> Array:
	if node is Control and pred.call(node):
		acc.append(node)
	for c in node.get_children():
		_find_all(c, pred, acc)
	return acc

func _best(hand: Array) -> Array:
	var asp := {}
	var rank := {}
	for i in hand.size():
		var a: int = hand[i].aspect
		var r: int = hand[i].rank
		if not asp.has(a): asp[a] = []
		asp[a].append(i)
		if not rank.has(r): rank[r] = []
		rank[r].append(i)
	for a in asp:
		if (asp[a] as Array).size() >= 5:
			return (asp[a] as Array).slice(0, 5)
	var best: Array = []
	for r in rank:
		if (rank[r] as Array).size() > best.size():
			best = rank[r]
	if best.size() >= 2:
		return best.slice(0, mini(5, best.size()))
	var hi := 0
	for i in hand.size():
		if hand[i].chip_value() > hand[hi].chip_value(): hi = i
	return [hi]
