extends SceneTree
## Verifies the todo.md GUI wave with real input: main menu, Collection, run save,
## TAB overview, ESC pause, RMB card inspection. Screenshots to screenshots/gui_*.png.
## Run: tools/dev/run_hidden.sh -s res://tools/dev/capture_menus.gd

const MENU := "res://src/game/menu/menu.tscn"
const RUN := "res://src/game/region/run.tscn"

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shoot(name: String) -> void:
	await _frames(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/gui_%s.png" % name)

func _motion(pos: Vector2) -> void:
	Input.warp_mouse(pos)
	var mm := InputEventMouseMotion.new()
	mm.position = pos
	mm.global_position = pos
	Input.parse_input_event(mm)

func _click(pos: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	_motion(pos)
	await _frames(1)
	var d := InputEventMouseButton.new()
	d.button_index = button
	d.pressed = true
	d.position = pos
	d.global_position = pos
	Input.parse_input_event(d)
	await _frames(1)
	var u := InputEventMouseButton.new()
	u.button_index = button
	u.pressed = false
	u.position = pos
	u.global_position = pos
	Input.parse_input_event(u)
	await _frames(2)

func _key(code: int) -> void:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.pressed = true
	Input.parse_input_event(k)
	await _frames(1)
	var k2 := InputEventKey.new()
	k2.physical_keycode = code
	k2.pressed = false
	Input.parse_input_event(k2)
	await _frames(4)

func _find(node: Node, pred: Callable):
	if node is Control and pred.call(node):
		return node
	for c in node.get_children():
		var r = _find(c, pred)
		if r:
			return r
	return null

func _button_with(key: String):
	var want := TranslationServer.translate(key)
	return _find(root, func(c): return c is Button and c.text == want and c.is_visible_in_tree())

func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()

func _initialize() -> void:
	_go()

func _go() -> void:
	await _frames(2)
	# --- main menu ---
	var menu: Node = load(MENU).instantiate()
	root.add_child(menu)
	await _frames(15)
	await _shoot("01_menu")
	var col = _button_with("MENU_COLLECTION")
	if col != null:
		await _click(_center(col))
		await _frames(10)
		await _shoot("02_collection")
		var cl = _button_with("COMMON_CLOSE")
		if cl != null:
			await _click(_center(cl))
	menu.queue_free()
	await _frames(5)

	# --- run: save at map, TAB, ESC, RMB in combat ---
	var run: Node = load(RUN).instantiate()
	root.add_child(run)
	await _frames(20)
	var take = _button_with("DRAFT_TAKE")
	if take != null:
		if run._arc_panels.size() > 0:
			await _click(_center(run._arc_panels[0]))
		take = _button_with("DRAFT_TAKE")
		if take != null and not take.disabled:
			await _click(_center(take))
		await _frames(15)
	print("[gui] run save exists after map: ", root.get_node("RunState").has_run_save())

	await _key(KEY_TAB)
	await _shoot("03_overview")
	await _key(KEY_TAB)
	await _frames(4)

	await _key(KEY_ESCAPE)
	await _shoot("04_pause")
	var res = _button_with("PAUSE_RESUME")
	if res != null:
		await _click(_center(res))
	await _frames(6)

	var go = _button_with("MAP_GO")
	if go != null:
		await _click(_center(go))
	await _frames(25)
	var combat = _find(root, func(c): return c.has_method("setup"))
	if combat != null and combat._hand_row.get_child_count() > 0:
		await _click(_center(combat._hand_row.get_child(1)), MOUSE_BUTTON_RIGHT)
		await _frames(6)
		await _shoot("05_inspect")
		await _key(KEY_ESCAPE)
	print("menus_capture: done")
	quit(0)
