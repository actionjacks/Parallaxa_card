extends SceneTree
## Full real-input playthrough for UX review: plays the whole run with synthesized mouse
## motion + clicks and screenshots every stage the player actually sees.
## Run: tools/dev/run_hidden.sh -s res://tools/dev/capture_playthrough.gd

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
	root.get_texture().get_image().save_png("res://screenshots/pt2_%s.png" % name)

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

func _reward_cards() -> Array:
	var acc: Array = []
	_collect(_rn, func(x): return x is PanelContainer and x.has_meta("card") and x.is_visible_in_tree(), acc)
	return acc

func _collect(node: Node, pred: Callable, acc: Array) -> void:
	if node is Control and pred.call(node):
		acc.append(node)
	for c in node.get_children():
		_collect(c, pred, acc)

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

func _play_fight(tag: String) -> void:
	var combat = _find_combat()
	var shot_turn := false
	var shot_enemy := false
	var guard := 0
	while guard < 90:
		guard += 1
		if not is_instance_valid(combat):
			return
		var c = combat.controller
		if c.phase == "ended" or c.enemy_hp <= 0:
			return
		if c.phase != "player":
			if not shot_enemy:
				await _shoot(tag + "_enemyturn")   # the paused enemy turn / wind-up
				shot_enemy = true
			await _frames(3)
			continue
		var kids: Array = combat._hand_row.get_children()
		var best: Array = _best(c.hand)
		# Fish like a real player: a weak hand (<3 of a kind) is worth a discard when available.
		if best.size() < 3 and c.discards_left > 0 and c.hand.size() >= 5:
			var junk: Array = []
			for i in c.hand.size():
				if not best.has(i):
					junk.append(i)
			for idx in junk.slice(0, 5):
				if idx < kids.size():
					await _click(_center(kids[idx]))
			if not combat._discard_btn.disabled:
				await _click(_center(combat._discard_btn))
				await _frames(15)
				continue
		for idx in best:
			if idx < kids.size():
				await _click(_center(kids[idx]))
		if not shot_turn:
			await _shoot(tag + "_selected")   # selection + score preview
			shot_turn = true
		if not combat._play_btn.disabled:
			await _click(_center(combat._play_btn))
		await _frames(45)

func _proceed() -> void:   # click the map "Enter" to start the next encounter
	await _frames(6)
	var go = _button_with("MAP_GO")
	if go != null:
		await _click(_center(go))
	await _frames(25)

func _go() -> void:
	await _frames(2)
	_rn = load(RUN).instantiate()
	root.add_child(_rn)
	await _frames(20)
	var rs := root.get_node("RunState")
	var top: Array = []
	for i in mini(5, rs.deck.size()):
		top.append("%s-%d" % [str(rs.deck[i].aspect), rs.deck[i].rank])
	print("[pt2] deck top5: ", " ".join(top))
	await _shoot("01_map")

	# hover a card to show the preview
	await _proceed()
	var combat = _find_combat()
	if combat != null and combat._hand_row.get_child_count() > 0:
		_motion(_center(combat._hand_row.get_child(2)))
		await _shoot("02_combat_hover")

	# fight 1
	await _play_fight("03_fight1")
	await _frames(55)
	await _shoot("04_reward")
	var offer_desc: Array = []
	for c in _rn._reward_cards:
		offer_desc.append("%s-%d" % [str(c.aspect), c.rank])
	print("[pt2] reward offers: ", " ".join(offer_desc))
	# take a reward card
	var rc := _reward_cards()
	if rc.size() > 0:
		await _click(_center(rc[0]))
	var take = _button_with("REWARD_TAKE")
	if take != null:
		await _click(_center(take))
	await _frames(30)
	await _shoot("05_map2")

	# fight 2 -> shop
	await _proceed()
	await _play_fight("06_fight2")
	await _frames(55)
	await _shoot("07_shop")
	var next = _button_with("SHOP_NEXT")
	if next != null:
		await _click(_center(next))
	await _frames(30)
	await _shoot("08_map3")

	# boss
	await _proceed()
	await _shoot("09_boss")
	await _play_fight("10_boss")
	await _frames(70)
	await _shoot("11_end")

	print("playthrough: done  relics=%d hp=%d" % [root.get_node("RunState").relics.size(), root.get_node("RunState").player_hp])
	quit(0)
