extends SceneTree
## Shoots the two Wave-G duels (docs/todo.md par.2) so a human can LOOK at them: the Hermit's
## three-card spread and Temperance's Celtic Cross. Neither mechanic can be judged from the test
## suite -- the whole point of both is what the player can READ on the screen before committing.
## Run: tools/dev/run_hidden.sh -s res://tools/dev/capture_spreads.gd

const COMBAT := "res://src/game/combat/combat.tscn"
const BOSSES := {
	"hermit": "res://data/combat/boss_hermit.tres",
	"temperance": "res://data/combat/boss_temperance.tres",
}

func _initialize() -> void:
	OS.set_environment("TEST_PROFILE", "bot")
	_go()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _find(node: Node, pred: Callable):
	if node is Control and pred.call(node):
		return node
	for c in node.get_children():
		var r = _find(c, pred)
		if r:
			return r
	return null

func _click(c: Control) -> void:
	var pos: Vector2 = c.get_global_rect().get_center()
	Input.warp_mouse(pos)
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.position = pos
		mb.global_position = pos
		Input.parse_input_event(mb)
		await _frames(1)
	await _frames(3)

func _go() -> void:
	await _frames(2)
	for id in BOSSES:
		var boss: EnemyData = load(BOSSES[id])
		var deck: Array = DeckLibrary.starter_deck_pure()
		var scene: Node = load(COMBAT).instantiate()
		# setup() BEFORE the tree: _ready() replays the stored params, and calling it after entry
		# leaves the scene showing its standalone default opponent instead.
		scene.setup(deck, boss, [], 55, 55)
		root.add_child(scene)
		await _frames(30)
		# stage a couple of cards so the cockpit has something to price
		var hand_cards: Array = []
		var row = _find(scene, func(c: Control) -> bool: return c is HandFan)
		if row != null:
			for ch in row.get_children():
				if ch is Control:
					hand_cards.append(ch)
		for i in mini(2, hand_cards.size()):
			await _click(hand_cards[i])
		await _frames(6)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://screenshots/spread_%s.png" % id)
		print("[spread] wrote screenshots/spread_%s.png  rule=%d" % [id, boss.rule])
		# ...and then actually PLAY it. A screenshot proves the scene renders; only turns prove the
		# rule survives contact with the real scene, the real deck and the real enemy clock.
		var ctl = scene.controller
		if boss.rule == EnemyData.Rule.CELTIC_CROSS:
			ctl.freeze([0])
			print("[spread] celtic: stash=%d hand=%d discards=%d" % [ctl.stash.size(), ctl.hand.size(), ctl.discards_left])
			ctl.play([0, 1])
			ctl.resolve_enemy_turn()
			ctl.recall(0)
			print("[spread] celtic after a turn: stash=%d hand=%d hp=%d" % [ctl.stash.size(), ctl.hand.size(), ctl.enemy_hp])
		else:
			var seats: Array = []
			var hp0: int = ctl.enemy_hp
			for t in 5:
				if ctl.phase != "player":
					break
				seats.append(ctl.spread_seat())
				ctl.play([0, 1])
				ctl.resolve_enemy_turn()
			print("[spread] hermit seats=%s banked_mult=%.1f pending=%d hp %d->%d" % [
				str(seats), ctl.spread_mult, ctl.pending_total(), hp0, ctl.enemy_hp])
		await _frames(4)
		scene.queue_free()
		await _frames(8)
	quit()
