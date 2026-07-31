extends SceneTree
## Asserts the ink reaches the LIVE scenes, not just the string table. A marker that works in a
## unit probe and never appears on screen is exactly the failure mode this project keeps hitting.
const RUN := "res://src/game/region/run.tscn"

func _initialize() -> void:
	OS.set_environment("TEST_PROFILE", "bot")
	_go()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _walk(node: Node, out: Array) -> void:
	if node is RichTextLabel and String(node.text).contains("[url="):
		out.append(String(node.text).substr(0, 70))
	for c in node.get_children():
		_walk(c, out)

func _go() -> void:
	await _frames(2)
	var rn: Node = load(RUN).instantiate()
	root.add_child(rn)
	await _frames(40)
	var hits: Array = []
	_walk(root, hits)
	print("[lex] map screen inked labels: %d" % hits.size())
	rn.queue_free()
	await _frames(6)
	# ...and the duel, where the jargon is densest and the player is least willing to leave.
	var boss: EnemyData = load("res://data/combat/boss_hermit.tres")
	var scene: Node = load("res://src/game/combat/combat.tscn").instantiate()
	scene.setup(DeckLibrary.starter_deck_pure(), boss, [], 55, 55, {}, 0, 0, 0, 1)
	root.add_child(scene)
	await _frames(30)
	var chits: Array = []
	_walk(scene, chits)
	print("[lex] duel inked labels: %d" % chits.size())
	for h in chits:
		print("[lex]   %s" % h)
	quit()
