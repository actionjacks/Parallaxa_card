extends SceneTree
## Shoots the scoring ceremony frame by frame: select a hand, hit Play, and capture the
## card-by-card reckoning while it runs. "The code looks right" is not evidence that an
## animation reads -- this is how we look at it.
## Run: tools/dev/run_hidden.sh -s res://tools/dev/capture_reckoning.gd

const RUN := "res://src/game/region/run.tscn"
var _rn: Node

func _initialize() -> void:
	OS.set_environment("TEST_PROFILE", "bot")
	_go()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shoot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/reck_%s.png" % name)

func _find(node: Node, pred: Callable):
	if node is Control and pred.call(node):
		return node
	for c in node.get_children():
		var r = _find(c, pred)
		if r:
			return r
	return null

func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()

func _click(pos: Vector2) -> void:
	Input.warp_mouse(pos)
	var mm := InputEventMouseMotion.new()
	mm.position = pos
	mm.global_position = pos
	Input.parse_input_event(mm)
	await _frames(1)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		if pressed:
			e.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(e)
		await _frames(1)
	await _frames(2)

func _button(key: String):
	var want := TranslationServer.translate(key)
	return _find(_rn, func(c): return c is Button and c.text == want and c.is_visible_in_tree())

func _go() -> void:
	await _frames(2)
	_rn = load(RUN).instantiate()
	root.add_child(_rn)
	await _frames(20)
	# skip the draft, walk the map into fight 1
	var take = _button("DRAFT_TAKE")
	if take != null:
		var panels: Array = _rn._arc_panels
		if panels.size() > 0:
			await _click(_center(panels[0]))
		take = _button("DRAFT_TAKE")
		if take != null and not take.disabled:
			await _click(_center(take))
		await _frames(15)
	# the run now offers a road (biome) before the map
	var walk = _button("BIOME_WALK")
	if walk != null:
		await _click(_center(walk))
		await _frames(25)
	var go = _button("MAP_GO")
	if go != null:
		await _click(_center(go))
	await _frames(40)
	var combat = _find(_rn, func(c): return c.has_method("setup"))
	if combat == null:
		print("[reck] no combat found")
		quit()
		return
	# select the five biggest-chip cards so the ceremony has plenty to count
	var kids: Array = combat._hand_row.get_children()
	var order: Array = []
	for i in combat.controller.hand.size():
		order.append(i)
	order.sort_custom(func(a, b): return combat.controller.hand[a].chip_value() > combat.controller.hand[b].chip_value())
	for i in order.slice(0, 5):
		if i < kids.size():
			await _click(_center(kids[i]))
	await _frames(4)
	await _shoot("00_selected")
	# fire, then photograph the reckoning as it counts
	var play = combat._play_btn
	Input.warp_mouse(_center(play))
	var d := InputEventMouseButton.new()
	d.button_index = MOUSE_BUTTON_LEFT
	d.pressed = true
	d.position = _center(play)
	d.global_position = d.position
	d.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(d)
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT
	u.pressed = false
	u.position = d.position
	u.global_position = d.position
	Input.parse_input_event(u)
	for shot in 6:
		await _frames(7)
		await _shoot("%02d_tick" % (shot + 1))
	print("[reck] wrote screenshots/reck_*.png")
	quit()
