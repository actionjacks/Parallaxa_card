extends SceneTree
## Full-loop playtest: drives a real run (map -> fight -> reward -> fight -> shop -> boss -> complete),
## making actual plays (flush / best rank group) and screenshotting every stage.
## Run: tools/dev/run_hidden.sh -s res://tools/dev/capture_playtest.gd

const RUN := "res://src/game/region/run.tscn"

var _rs: Node
var _run: Node

func _initialize() -> void:
	_go()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shoot(name: String) -> void:
	await _frames(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/pt_%s.png" % name)

func _find_combat() -> Node:
	for ch in _run._stage.get_children():
		if ch.has_method("setup"):
			return ch
	return null

func _best(hand: Array) -> Array:
	var asp: Dictionary = {}
	var rank: Dictionary = {}
	for i in hand.size():
		var a: int = hand[i].aspect
		var r: int = hand[i].rank
		if not asp.has(a): asp[a] = []
		asp[a].append(i)
		if not rank.has(r): rank[r] = []
		rank[r].append(i)
	for a in asp:
		if asp[a].size() >= 5:
			return (asp[a] as Array).slice(0, 5)   # flush
	var best: Array = []
	for r in rank:
		if (rank[r] as Array).size() > best.size():
			best = rank[r]
	if best.size() >= 2:
		return best.slice(0, mini(5, best.size()))
	var hi: int = 0
	for i in hand.size():
		if hand[i].chip_value() > hand[hi].chip_value():
			hi = i
	return [hi]

func _do_play(combat: Node, sel: Array) -> void:
	combat._selected.clear()
	for idx in sel:
		combat._selected.append(idx)
	combat._refresh_card_styles()
	combat._update_selection_ui()

func _pick(c) -> Array:
	# Simple, reliable demo bot: always race with the best offence. (Block/heal math is covered
	# by the headless scoring test; a defensive bot spirals and never verifies the full loop.)
	return _best(c.hand)

func _win_fight(tag: String) -> void:
	var combat: Node = _find_combat()
	if combat == null:
		print("[pt] %s: NO COMBAT FOUND (stage kids=%d)" % [tag, _run._stage.get_child_count()])
		return
	print("[pt] %s start: enemy=%s hp=%d player_hp=%d" % [tag, combat._enemy.name_key, combat.controller.enemy_hp, combat.controller.player_hp])
	var shot_play := false
	var shot_t2 := false
	var guard := 0
	while guard < 80:
		guard += 1
		if not is_instance_valid(combat):
			return
		var c = combat.controller
		if c.phase == "ended" or c.enemy_hp <= 0:
			return
		if c.phase != "player":
			await _frames(2)
			continue
		if c.turn >= 2 and not shot_t2:
			await _shoot(tag + "_turn2")   # after an enemy attack: HP loss, intent advanced, Rot ticked
			shot_t2 = true
		var sel: Array = _pick(c)
		print("[pt] %s t%d play sel=%d ehp=%d php=%d phase=%s" % [tag, c.turn, sel.size(), c.enemy_hp, c.player_hp, c.phase])
		_do_play(combat, sel)
		if not shot_play:
			await _shoot(tag + "_play")   # selection + preview visible
			shot_play = true
		combat._on_play()
		await _frames(8)
	print("[pt] %s end: guard=%d valid=%s enemy_hp=%s" % [tag, guard, str(is_instance_valid(combat)), str(combat.controller.enemy_hp) if is_instance_valid(combat) else "freed"])

func _go() -> void:
	await _frames(1)
	_rs = root.get_node("RunState")
	_run = load(RUN).instantiate()
	root.add_child(_run)
	await _shoot("01_map")

	# Fight 1
	_run._start_encounter()
	await _frames(10)
	await _shoot("02_fight1_start")
	await _win_fight("02_fight1")
	await _frames(10)
	await _shoot("03_reward")

	_run._reward_pick = 0
	_run._take_reward()
	await _frames(10)
	await _shoot("04_map2")

	# Fight 2
	_run._start_encounter()
	await _frames(10)
	await _win_fight("05_fight2")
	await _frames(10)
	await _shoot("06_shop")

	# Shop: make it affordable, buy first offer, thin, then leave
	_rs.rtec = 20
	_run._show_shop()
	await _shoot("06b_shop_rich")
	_run._thin_deck()
	await _frames(6)
	await _shoot("06c_after_thin")
	_run._leave_shop()
	await _frames(10)
	await _shoot("07_map3")

	# Boss
	_run._start_encounter()
	await _frames(10)
	await _shoot("08_boss_start")
	await _win_fight("08_boss")
	await _frames(12)
	await _shoot("09_complete")

	print("playtest: done  hp=%d rtec=%d deck=%d relics=%d"
		% [_rs.player_hp, _rs.rtec, _rs.deck.size(), _rs.relics.size()])
	quit(0)
