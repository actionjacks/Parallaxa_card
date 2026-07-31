extends SceneTree
## LIVE TACTICS PASS. Everything else in tools/dev/ either drives the controller directly or plays
## a run to see if it finishes. This one asks a different question: in an ACTUAL duel, driven by
## ACTUAL mouse events, does the player have real choices -- and do they work?
##
## It exercises every in-turn option the way a person would (click, drag, reorder, discard, freeze,
## toggle, click a glossary term), and for every turn it measures the DECISION SPREAD: the best
## legal play against the naive one (the five biggest cards) and against the median. A game where
## those are the same number is a game where the player is pressing a button, not making a play.
##
## Run: tools/dev/run_hidden.sh -s res://tools/dev/capture_tactics.gd
## Env: TAC_BOSS=<res path> to fight a specific opponent (default: a Cups knight).

const COMBAT := "res://src/game/combat/combat.tscn"
const LOG := "res://screenshots/tactics_log.txt"

var _f: FileAccess
var _scene: Node
var _ctrl                       ## CombatController of the live scene

func _initialize() -> void:
	OS.set_environment("TEST_PROFILE", "bot")
	_f = FileAccess.open(LOG, FileAccess.WRITE)
	_go()

func _log(s: String) -> void:
	print(s)
	if _f != null:
		_f.store_line(s)
		_f.flush()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _collect(node: Node, pred: Callable, out: Array) -> void:
	if node is Control and pred.call(node):
		out.append(node)
	for c in node.get_children():
		_collect(c, pred, out)

func _find(pred: Callable):
	var out: Array = []
	_collect(_scene, pred, out)
	return out[0] if not out.is_empty() else null

func _btn(key: String):
	var want := TranslationServer.translate(key)
	return _find(func(c: Control) -> bool:
		return c is Button and c.is_visible_in_tree() and String(c.text).begins_with(want.split("%")[0].strip_edges()))

func _click(c: Control) -> void:
	if c == null:
		return
	var pos: Vector2 = c.get_global_rect().get_center()
	Input.warp_mouse(pos)
	var mm := InputEventMouseMotion.new()
	mm.position = pos
	mm.global_position = pos
	Input.parse_input_event(mm)
	await _frames(1)
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.position = pos
		mb.global_position = pos
		Input.parse_input_event(mb)
		await _frames(1)
	await _frames(3)

func _shoot(name: String) -> void:
	await _frames(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/tac_%s.png" % name)

## Cards currently laid out in the fan, left to right as the player sees them.
func _hand_widgets() -> Array:
	var rows: Array = []
	_collect(_scene, func(c: Control) -> bool: return c is HandFan, rows)
	if rows.is_empty():
		return []
	var out: Array = []
	for ch in rows[0].get_children():
		if ch is Control and ch.visible:
			out.append(ch)
	return out

## THE MEASUREMENT. Every legal subset of the hand, scored through the REAL Scoring, so the numbers
## are the game's own. Returns [best, naive, median, distinct_hand_types, legal_plays].
func _decision_spread() -> Array:
	var n: int = _ctrl.hand.size()
	var vals: Array = []
	var types: Dictionary = {}
	var best: int = 0
	for mask in range(1, 1 << n):
		var idx: Array = []
		for i in n:
			if mask & (1 << i):
				idx.append(i)
		if idx.size() > 5:
			continue
		var r: Dictionary = _ctrl.preview(idx)
		var d: int = _ctrl.effective_damage(int(r["damage"]), idx.size(), int(r["hand"]))
		if _ctrl.spread_seat() >= 0:
			d = _ctrl.spread_now(d)
		vals.append(d)
		types[int(r["hand"])] = true
		best = maxi(best, d)
	# the naive play: the five highest-ranked cards, which is what a new player reaches for
	var order: Array = []
	for i in n:
		order.append(i)
	order.sort_custom(func(a, b): return _ctrl.hand[a].chip_value() > _ctrl.hand[b].chip_value())
	var naive_idx: Array = order.slice(0, mini(5, n))
	var nr: Dictionary = _ctrl.preview(naive_idx)
	var naive: int = _ctrl.effective_damage(int(nr["damage"]), naive_idx.size(), int(nr["hand"]))
	if _ctrl.spread_seat() >= 0:
		naive = _ctrl.spread_now(naive)
	vals.sort()
	var med: int = int(vals[vals.size() / 2]) if not vals.is_empty() else 0
	return [best, naive, med, types.size(), vals.size()]

func _go() -> void:
	await _frames(2)
	var path: String = OS.get_environment("TAC_BOSS")
	if path == "":
		path = "res://data/combat/biome_life_2.tres"
	var foe: EnemyData = load(path)
	_scene = load(COMBAT).instantiate()
	_scene.setup(DeckLibrary.starter_deck_pure(), foe, [], 55, 55, {}, 0, 0, 0, 1)
	root.add_child(_scene)
	await _frames(30)
	_ctrl = _scene.controller
	_log("[tac] === %s  hp=%d  rule=%d ===" % [tr(foe.name_key), _ctrl.enemy_hp, foe.rule])

	# ---- 1. does the choice matter? measured before a single click -----------------------------
	for t in 8:
		if _ctrl.phase != "player":
			_log("[tac] walka skonczona po %d turach (hp wroga %d)" % [t, _ctrl.enemy_hp])
			break
		# WHAT the best play actually is -- a ceiling without a name cannot be tuned.
		var bi0: Array = _best_indices()
		var br: Dictionary = _ctrl.preview(bi0)
		var names := ""
		for i in bi0:
			var c: CardData = _ctrl.hand[i]
			names += "%s%s " % [c.rank_glyph(), CardData.keyword_name_key(c.keyword).replace("KW_", "")]
		_log("[tac]   najlepsze = %s | chips=%d mult=%.2f | karty: %s"
			% [tr(Poker.name_key(int(br["hand"]))), int(br["chips"]), float(br["mult"]), names])
		var s: Array = _decision_spread()
		var gain: float = (float(s[0]) / maxf(1.0, float(s[1])) - 1.0) * 100.0
		_log("[tac] tura %d: legalnych zagran=%d, typow ukladu=%d | najlepsze=%d naiwne=%d mediana=%d | zysk z myslenia +%.0f%%"
			% [_ctrl.turn, s[4], s[3], s[0], s[1], s[2], gain])
		# play the BEST five-card set so the fight advances like a competent player's would
		var bi: Array = _best_indices()
		_scene.call("_selected_clear_for_test") if _scene.has_method("_selected_clear_for_test") else null
		_ctrl.play(bi)
		if _ctrl.phase == "enemy":
			_ctrl.resolve_enemy_turn()

	# ---- 2. every option, clicked for real -----------------------------------------------------
	_scene.queue_free()
	await _frames(6)
	_scene = load(COMBAT).instantiate()
	_scene.setup(DeckLibrary.starter_deck_pure(), foe, [], 55, 55, {}, 0, 0, 0, 1)
	root.add_child(_scene)
	await _frames(30)
	_ctrl = _scene.controller
	var w: Array = _hand_widgets()
	_log("[tac] widgetow w rece: %d (kontroler ma %d)" % [w.size(), _ctrl.hand.size()])

	# select three cards by clicking them
	for i in mini(3, w.size()):
		await _click(w[i])
	var sel1: int = int(_scene.get("_selected").size())
	_log("[tac] klik x3 -> zaznaczone=%d" % sel1)

	# deselect the middle one
	if w.size() > 1:
		await _click(w[1])
	var sel2: int = int(_scene.get("_selected").size())
	_log("[tac] odklik srodkowej -> zaznaczone=%d (spodziewane %d)" % [sel2, sel1 - 1])

	# reorder: click the first "<" handle in the order strip
	var before_order: Array = []
	for c in _scene.get("_selected"):
		before_order.append(c.rank_glyph())
	var swaps: Array = []
	_collect(_scene, func(c: Control) -> bool: return c is Button and c.text == "<" and c.is_visible_in_tree(), swaps)
	if not swaps.is_empty():
		await _click(swaps[0])
	var after_order: Array = []
	for c in _scene.get("_selected"):
		after_order.append(c.rank_glyph())
	_log("[tac] pasek PORZADEK: %s -> %s (uchwytow: %d)" % [str(before_order), str(after_order), swaps.size()])

	# the Keystone: does moving a card to the last seat change the preview?
	var r_a: Dictionary = _ctrl.preview(_scene.call("_selected_indices"))
	var sel_arr: Array = _scene.get("_selected")
	if sel_arr.size() > 1:
		var tmp = sel_arr[0]
		sel_arr[0] = sel_arr[sel_arr.size() - 1]
		sel_arr[sel_arr.size() - 1] = tmp
	var r_b: Dictionary = _ctrl.preview(_scene.call("_selected_indices"))
	_log("[tac] ZWORNIK: ta sama piatka, inna kolejnosc -> %d vs %d obrazen (roznica %d)"
		% [int(r_a["damage"]), int(r_b["damage"]), absi(int(r_a["damage"]) - int(r_b["damage"]))])

	# toggles the player can reach
	for key in ["PAYTABLE_TOGGLE", "LOG_TOGGLE", "SORT_DEALT", "SORT_RANK", "SORT_ASPECT"]:
		var b = _btn(key)
		if b != null:
			await _click(b)
	_log("[tac] przelaczniki (tabela/dziennik/sortowanie): klikniete")

	# a glossary term, clicked in place
	var links: Array = []
	_collect(_scene, func(c: Control) -> bool:
		return c is RichTextLabel and String(c.text).contains("[url=") and c.is_visible_in_tree(), links)
	# Sweep the label: a link sits somewhere inside a sentence, so aiming at the left edge proves
	# nothing. Walk across it until the panel opens -- that is the only proof the feature is
	# reachable with a mouse rather than merely present in the markup.
	var opened := false
	var hit_x := -1.0
	for lr: RichTextLabel in links:
		if opened:
			break
		var rect: Rect2 = lr.get_global_rect()
		var x: float = rect.position.x + 4.0
		while x < rect.position.x + rect.size.x - 2.0 and not opened:
			var p := Vector2(x, rect.position.y + rect.size.y * 0.5)
			Input.warp_mouse(p)
			var mm2 := InputEventMouseMotion.new()
			mm2.position = p
			mm2.global_position = p
			Input.parse_input_event(mm2)
			await _frames(1)
			for pressed in [true, false]:
				var mb := InputEventMouseButton.new()
				mb.button_index = MOUSE_BUTTON_LEFT
				mb.pressed = pressed
				mb.position = p
				mb.global_position = p
				Input.parse_input_event(mb)
				await _frames(1)
			await _frames(2)
			if root.get_node_or_null("LexPanel") != null:
				opened = true
				hit_x = x - rect.position.x
			x += 6.0
	var panel = root.get_node_or_null("LexPanel")
	_log("[tac] leksykon: inkowanych etykiet=%d, panel otwarty=%s (trafienie %.0f px od lewej)"
		% [links.size(), opened, hit_x])
	await _shoot("lexicon")
	if panel != null:
		panel.queue_free()
	await _frames(3)

	# discard, for real
	var d0: int = _ctrl.discards_left
	var db = _btn("COMBAT_DISCARD")
	if db != null and not db.disabled:
		await _click(db)
	_log("[tac] ODRZUT: %d -> %d, reka %d" % [d0, _ctrl.discards_left, _ctrl.hand.size()])

	# play, for real
	var w2: Array = _hand_widgets()
	for i in mini(5, w2.size()):
		await _click(w2[i])
	var hp0: int = _ctrl.enemy_hp
	var pb = _btn("COMBAT_PLAY")
	if pb != null and not pb.disabled:
		await _click(pb)
	await _frames(60)
	_log("[tac] ZAGRANIE przez przycisk: hp wroga %d -> %d" % [hp0, _ctrl.enemy_hp])
	await _shoot("after_play")
	_log("[tac] koniec")
	quit()

## Indices of the highest-damage legal play (used to advance the fight like a good player).
func _best_indices() -> Array:
	var n: int = _ctrl.hand.size()
	var best: int = -1
	var best_idx: Array = []
	for mask in range(1, 1 << n):
		var idx: Array = []
		for i in n:
			if mask & (1 << i):
				idx.append(i)
		if idx.size() > 5:
			continue
		var r: Dictionary = _ctrl.preview(idx)
		var d: int = _ctrl.effective_damage(int(r["damage"]), idx.size(), int(r["hand"]))
		if d > best:
			best = d
			best_idx = idx
	return best_idx
