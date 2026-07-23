extends SceneTree
## Dev tool: render each region screen and save a screenshot. Run:
## tools/dev/run_hidden.sh -s res://tools/dev/capture_run_flow.gd
## (RunState is fetched via node path because autoload globals aren't bound in -s script mode.)

const RUN := "res://src/game/region/run.tscn"

var _rs: Node

func _initialize() -> void:
	_go()

func _shoot(name: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/run_%s.png" % name)

func _go() -> void:
	await process_frame
	_rs = root.get_node("RunState")
	var run: Node = load(RUN).instantiate()
	root.add_child(run)
	await _shoot("map")

	_rs.rtec = 12
	run._show_reward()
	await _shoot("reward")

	run._show_shop()
	await _shoot("shop")

	_rs.step = 2
	run._start_encounter()
	await _shoot("boss")

	run._show_complete()
	await _shoot("complete")

	print("run_flow: done")
	quit(0)
