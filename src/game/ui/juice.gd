class_name Juice
## Shared game-feel primitives: hitstop, shake, screen flash. Every ceremony in the game is
## assembled from these three. All of them respect the accessibility toggles in Settings
## ("gameplay/reduce_motion", "gameplay/disable_flash") -- callers never have to check.
## Headless-safe: every helper no-ops without a running SceneTree.

static func reduce_motion() -> bool:
	return _setting("reduce_motion")

static func flash_disabled() -> bool:
	return _setting("disable_flash")

static func streamer_mode() -> bool:
	return _setting("streamer_mode")

static func fast_pace() -> bool:
	return _setting("fast_pace")

## Freeze the world for a beat (real-time seconds). The timer ignores time_scale, so the
## restore always fires. Reduce-motion swaps the freeze for nothing (the SFX still lands).
static func hitstop(duration: float = 0.12, scale: float = 0.05) -> void:
	var tree := _tree()
	if tree == null or reduce_motion():
		return
	if Engine.time_scale < 1.0:
		return   # a hitstop is already running; do not stack restores
	Engine.time_scale = scale
	tree.create_timer(duration, true, false, true).timeout.connect(func() -> void:
		Engine.time_scale = 1.0)

## Positional shake on a Control (combat root, panels). Strength in pixels.
static func shake(node: Control, strength: float = 6.0) -> void:
	if node == null or not is_instance_valid(node) or reduce_motion():
		return
	var tw := node.create_tween()
	for i in 4:
		var off := Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		tw.tween_property(node, "position", off, 0.04)
	tw.tween_property(node, "position", Vector2.ZERO, 0.05)

## Full-screen colour flash layered onto `host` (usually the combat _fx layer).
static func flash(host: Control, color: Color = Color(1, 1, 1, 0.45), fade: float = 0.30) -> void:
	if host == null or not is_instance_valid(host) or flash_disabled():
		return
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(r)
	var tw := host.create_tween()
	tw.tween_property(r, "modulate:a", 0.0, fade)
	tw.tween_callback(r.queue_free)

static func _setting(key: String) -> bool:
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		var s := (ml as SceneTree).root.get_node_or_null("Settings")
		if s != null and s.has_method("get_value"):
			return bool(s.call("get_value", "gameplay", key, false))
	return false

static func _tree() -> SceneTree:
	var ml := Engine.get_main_loop()
	return ml as SceneTree if ml is SceneTree else null
