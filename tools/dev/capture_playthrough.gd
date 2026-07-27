extends SceneTree
## Full-JOURNEY real-input playthrough: a screen-state machine that detects what is on screen
## (draft / map+omen / combat / reward / shop / region-clear / victory / defeat) and acts like a
## player, across ALL regions. Run: tools/dev/run_hidden.sh -s res://tools/dev/capture_playthrough.gd

const RUN := "res://src/game/region/run.tscn"
var _rn: Node
var _omen_shot := false
var _fight_no := 0
var _logf: FileAccess
## PT_BOOST=1 grants a power boost at run start: verifies the VICTORY path (boss claim screens,
## region transitions, the winning spread) without pretending the base difficulty is beatable
## by this deliberately-weak bot. PT_ELITE=1 makes the bot take elite forks when offered.
var _boost := false
var _take_elite := false

func _initialize() -> void:
	# File isolation: automated runs must never pollute the player's real meta/save files.
	# (Autoloads already read the real files into memory; every WRITE from here on is redirected.)
	if OS.get_environment("TEST_PROFILE") == "":
		OS.set_environment("TEST_PROFILE", "bot")
	# Godot's stdout is block-buffered into a pipe and LOST if the process is killed mid-run,
	# so the driver also logs to a flushed file -- the only reliable trace when something hangs.
	_logf = FileAccess.open("res://screenshots/pt2_log.txt", FileAccess.WRITE)
	_go()

func _log(s: String) -> void:
	print(s)
	if _logf != null:
		_logf.store_line(s)
		_logf.flush()

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

func _collect(node: Node, pred: Callable, acc: Array) -> void:
	if node is Control and pred.call(node):
		acc.append(node)
	for c in node.get_children():
		_collect(c, pred, acc)

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
	if combat == null:
		return
	var shot := false
	var guard := 0
	while guard < 250:
		guard += 1
		if not is_instance_valid(combat):
			return
		var c = combat.controller
		if c.phase == "ended" or c.enemy_hp <= 0:
			for w in 60:
				if not is_instance_valid(combat):
					break
				await _frames(3)
			return
		if c.phase != "player":
			await _frames(3)
			continue
		var kids: Array = combat._hand_row.get_children()
		var best: Array = _best(c.hand)
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
		_log("[bc]  t%d best=%d ehp=%d" % [c.turn, best.size(), c.enemy_hp])
		for idx in best:
			if idx < kids.size():
				await _click(_center(kids[idx]))
		if not shot:
			await _shoot(tag + "_sel")
			shot = true
		if not combat._play_btn.disabled:
			await _click(_center(combat._play_btn))
		await _frames(45)

func _pass_draft() -> void:
	await _shoot("00_draft")
	if _rn._arc_panels.size() > 0:
		await _click(_center(_rn._arc_panels[0]))
	var offers: Array = []
	for a in _rn._arc_offers:
		offers.append(tr(a.name_key))
	_log("[pt2] draft offers: " + ", ".join(offers))
	var take = _button_with("DRAFT_TAKE")
	if take != null and not take.disabled:
		await _click(_center(take))
	await _frames(15)

func _handle_map() -> void:
	if _rn._pending_omen != null:
		var oid: String = _rn._pending_omen.id
		_log("[pt2] omen: " + oid)
		if not _omen_shot:
			await _shoot("omen")
			_omen_shot = true
		var b = _button_with("OMEN_TAKE" if oid != "justice" else "OMEN_SKIP")
		if b == null or b.disabled:
			b = _button_with("OMEN_SKIP")
		if b != null:
			await _click(_center(b))
		await _frames(12)
	if _take_elite:
		var rs := root.get_node("RunState")
		var elite_text := ""
		if rs.region != null and rs.region.elite != null:
			elite_text = TranslationServer.translate("MAP_ELITE") % TranslationServer.translate(rs.region.elite.name_key)
		var el = _find(_rn, func(c): return c is Button and c.text == elite_text and c.is_visible_in_tree())
		if el != null:
			_log("[bc] taking the ELITE fork")
			await _click(_center(el))
			await _frames(25)
			return
	var go = _button_with("MAP_GO")
	if go != null:
		await _click(_center(go))
	await _frames(25)

func _foes() -> String:
	var names: Array = []
	for f in root.get_node("RunState").fights:
		names.append(tr(f.name_key))
	names.append(tr(root.get_node("RunState").region.boss.name_key))
	return " | ".join(names)

func _go() -> void:
	_boost = OS.get_environment("PT_BOOST") == "1"
	_take_elite = OS.get_environment("PT_ELITE") == "1"
	await _frames(2)
	_rn = load(RUN).instantiate()
	root.add_child(_rn)
	await _frames(20)
	var rs := root.get_node("RunState")
	if _boost:
		# Victory-path harness: a deck a good player COULD assemble by region 2 (glass + avalanche
		# + leveled hands + funded shop). The UI is still driven by real clicks.
		for i in 3:
			var g := CardData.new()
			g.rank = 7
			g.aspect = Aspects.Id.DEATH
			g.rarity = CardData.Rarity.RARE
			rs.deck.append(g)
		var glass := CardData.new()
		glass.rank = 9
		glass.aspect = Aspects.Id.CHAOS
		glass.keyword = CardData.Keyword.PRZECIAZENIE
		glass.keyword_value = 3
		rs.deck.append(glass)
		var law := CardData.new()
		law.rank = 7
		law.aspect = Aspects.Id.CHAOS
		law.keyword = CardData.Keyword.LAWINA
		rs.deck.append(law)
		rs.hand_levels = {Poker.Hand.PAIR: 3, Poker.Hand.THREE: 3, Poker.Hand.FLUSH: 4, Poker.Hand.FIVE: 2}
		rs.rtec = 30
		_log("[pt2] BOOST active: +5 cards, leveled hands, 30 rtec")
	_log("[pt2] region 1 foes: " + _foes())
	var result := "TIMEOUT"
	var guard := 0
	while guard < 80:
		guard += 1
		await _frames(8)
		if _find_combat() != null:
			_fight_no += 1
			_log("[bc] fight %d start" % _fight_no)
			await _play_fight("f%02d" % _fight_no)
			await _frames(30)
			continue
		if _button_with("DRAFT_TAKE") != null:
			_log("[bc] draft")
			await _pass_draft()
			continue
		# Boss claim: pick the REVERSED option on odd regions (exercises both paths), else upright.
		var claim = _button_with("CLAIM_TAKE")
		if claim != null:
			var pick: int = 1 if (rs.region_index % 2 == 1 and _rn._claim_panels.size() > 1) else 0
			_log("[bc] boss claim: option %d of %d" % [pick, _rn._claim_panels.size()])
			await _shoot("claim_r%d" % (rs.region_index + 1))
			if _rn._claim_panels.size() > pick:
				await _click(_center(_rn._claim_panels[pick]))
			claim = _button_with("CLAIM_TAKE")
			if claim != null and not claim.disabled:
				await _click(_center(claim))
			await _frames(15)
			continue
		var b = _button_with("COMPLETE_NEXT")
		if b != null:
			_log("[pt2] region %d cleared (hp=%d rtec=%d relics=%d)" % [rs.region_index + 1, rs.player_hp, rs.rtec, rs.relics.size()])
			await _shoot("clear_r%d" % (rs.region_index + 1))
			await _click(_center(b))
			await _frames(20)
			_log("[pt2] region %d foes: " % (rs.region_index + 1) + _foes())
			continue
		# classify end screens by the SPREAD titles (win and loss share the same layout)
		if _find(_rn, func(c): return c is Label and c.text == tr("SPREAD_LOSS") and c.is_visible_in_tree()) != null:
			result = "DEFEAT"
			await _shoot("spread_loss")
			break
		if _find(_rn, func(c): return c is Label and c.text == tr("SPREAD_WIN") and c.is_visible_in_tree()) != null:
			result = "VICTORY"
			await _shoot("spread_win")
			break
		b = _button_with("REWARD_TAKE")
		if b != null:
			_log("[bc] reward")
			var rc := _reward_cards()
			if rc.size() > 0:
				await _click(_center(rc[0]))
			b = _button_with("REWARD_TAKE")
			if b != null and not b.disabled:
				await _click(_center(b))
			else:
				var sk = _button_with("REWARD_SKIP")
				if sk != null:
					await _click(_center(sk))
			await _frames(15)
			continue
		b = _button_with("SHOP_NEXT")
		if b != null:
			_log("[bc] shop rtec=%d" % rs.rtec)
			# spend like a player: hoarded Mercury converts into deck power
			# Stars first (the growth engine), then cards, while rich
			var star = _find(_rn, func(c): return c is Button \
				and c.text == (tr("SHOP_STAR_BUY") % 7) and c.is_visible_in_tree() and not c.disabled)
			if star != null and rs.rtec >= 10:
				await _click(_center(star))
				await _frames(12)
				continue
			var buy = _find(_rn, func(c): return c is Button \
				and c.text == (tr("SHOP_BUY") % 5) and c.is_visible_in_tree() and not c.disabled)
			if buy != null and rs.rtec >= 12:
				await _click(_center(buy))
				await _frames(12)
				continue
			await _click(_center(b))
			await _frames(15)
			continue
		if _button_with("MAP_GO") != null:
			_log("[bc] map")
			await _handle_map()
			continue
	_log("journey: %s  region=%d fights_won=%d hp=%d/%d rtec=%d deck=%d relics=%d" % [
		result, rs.region_index + 1, rs.fights_won, rs.player_hp, rs.player_max_hp,
		rs.rtec, rs.deck.size(), rs.relics.size()])
	quit(0)
