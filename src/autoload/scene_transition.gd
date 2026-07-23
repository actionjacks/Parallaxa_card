extends Node
## Threaded scene loading with a fade overlay and a loading indicator.
##
## Why it is built this way:
##
## 1. Loading runs through `ResourceLoader.load_threaded_request()` and is polled in `_process()`.
##    A blocking `load()` would freeze the main thread, which means the fade would never render and
##    the player would stare at a frozen frame instead of a transition.
## 2. The fade is animated by hand from `_process()` instead of by a `Tween`. The overlay must work
##    while the tree is paused (a settings menu or a death screen may pause the game before asking
##    for a scene change), and hand-driven interpolation removes any doubt about tween pause modes
##    and tween lifetime across a scene swap that frees half the tree.
## 3. A failed load must never leave a black screen. On any failure the overlay fades back in
##    reverse, the old scene stays alive and `transition_finished` is still emitted, so callers
##    awaiting the signal do not hang forever.
## 4. The loading indicator is instantiated defensively (`ResourceLoader.exists` + `has_method`).
##    It is an independent module; a missing or half-written indicator scene must degrade to
##    "no spinner", never to a broken transition.

signal transition_started(path: String)
signal load_progress(ratio: float)
signal transition_finished(path: String)

## Rendered above every in-game CanvasLayer. 128 leaves room both below (HUD, menus) and above
## (debug overlays that intentionally want to draw on top of a transition).
const OVERLAY_LAYER: int = 128
const LOADING_INDICATOR_SCENE: String = "res://src/ui/loading/loading_indicator.tscn"
const FADE_COLOR: Color = Color(0.0, 0.0, 0.0, 1.0)

## Below this the fade is treated as instant; avoids a one-frame division by ~0.
const MIN_FADE_DURATION: float = 0.01

enum _Phase {
	IDLE,
	FADE_OUT,
	LOADING,
	FADE_IN,
}

var _phase: int = _Phase.IDLE
var _target_path: String = ""
var _fade_out_duration: float = 0.35
var _fade_in_duration: float = 0.35
var _fade_elapsed: float = 0.0
var _fade_alpha: float = 0.0
var _progress: float = 0.0
## Set when the pending load failed: the overlay reverses and the old scene is kept.
var _aborted: bool = false

var _layer: CanvasLayer = null
var _fade_rect: ColorRect = null
var _loading_indicator: Control = null
## Reused across polls so the poll does not allocate an Array every frame.
var _progress_buffer: Array = []
## Most recently registered Level, see `register_level()`.
var _current_level: Node = null


func _ready() -> void:
	# The whole module has to keep ticking while the game is paused, otherwise a transition
	# requested from a pause menu would never advance past the first frame.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	set_process(false)


# --- Public API -------------------------------------------------------------------------------

## Fades out, loads `path` on a worker thread, swaps the scene, fades back in.
## Calls made while a transition is running are rejected (see `is_busy()`).
func change_scene(path: String, fade_out: float = 0.35, fade_in: float = 0.35) -> void:
	if is_busy():
		push_warning("SceneTransition: change_scene(\"%s\") ignored, a transition to \"%s\" is already running." % [path, _target_path])
		return
	if path.is_empty():
		push_error("SceneTransition: change_scene() called with an empty path.")
		return
	if not ResourceLoader.exists(path):
		push_error("SceneTransition: scene \"%s\" does not exist, staying on the current scene." % path)
		# Emitted anyway so callers that await transition_finished are not left hanging.
		transition_finished.emit(path)
		return

	_target_path = path
	_fade_out_duration = maxf(fade_out, 0.0)
	_fade_in_duration = maxf(fade_in, 0.0)
	_aborted = false
	_progress = 0.0
	_fade_elapsed = 0.0
	_phase = _Phase.FADE_OUT
	_set_overlay_active(true)
	_apply_fade_alpha(0.0)
	set_process(true)
	transition_started.emit(path)

	if _fade_out_duration <= MIN_FADE_DURATION:
		# Skip the interpolation entirely rather than relying on a single-frame lerp.
		_apply_fade_alpha(1.0)
		_begin_load()


## Reloads the scene currently in the tree. No-op (with a warning) for scenes that were built at
## runtime and therefore have no source file to reload from.
func reload_current() -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		push_warning("SceneTransition: reload_current() called with no current scene.")
		return
	var path: String = tree.current_scene.scene_file_path
	if path.is_empty():
		push_warning("SceneTransition: current scene has no source file (built at runtime), cannot reload.")
		return
	change_scene(path)


func is_busy() -> bool:
	return _phase != _Phase.IDLE


## 0..1 progress of the pending load. 0.0 while idle.
func get_progress() -> float:
	return _progress


## Optional hook used by `Level._ready()` so gameplay code can ask which level is live without
## walking the tree. Additive to the documented API and safe to ignore.
func register_level(level: Node) -> void:
	if level == null:
		push_warning("SceneTransition: register_level() called with null.")
		return
	_current_level = level


func get_current_level() -> Node:
	# Levels are freed on a scene swap; never hand out a dangling reference.
	if _current_level != null and not is_instance_valid(_current_level):
		_current_level = null
	return _current_level


# --- Frame loop -------------------------------------------------------------------------------

func _process(delta: float) -> void:
	match _phase:
		_Phase.FADE_OUT:
			_process_fade_out(delta)
		_Phase.LOADING:
			_poll_load()
		_Phase.FADE_IN:
			_process_fade_in(delta)
		_:
			set_process(false)


func _process_fade_out(delta: float) -> void:
	_fade_elapsed += delta
	var ratio: float = 1.0
	if _fade_out_duration > MIN_FADE_DURATION:
		ratio = clampf(_fade_elapsed / _fade_out_duration, 0.0, 1.0)
	_apply_fade_alpha(ratio)
	if ratio >= 1.0:
		_begin_load()


func _process_fade_in(delta: float) -> void:
	_fade_elapsed += delta
	var ratio: float = 1.0
	if _fade_in_duration > MIN_FADE_DURATION:
		ratio = clampf(_fade_elapsed / _fade_in_duration, 0.0, 1.0)
	_apply_fade_alpha(1.0 - ratio)
	if ratio >= 1.0:
		_finish()


# --- Loading ----------------------------------------------------------------------------------

func _begin_load() -> void:
	_show_loader()
	# use_sub_threads = false: sub-thread loading is measurably faster for huge scenes but has a
	# history of import-order races on resources shared between levels. Correctness first.
	var err: int = ResourceLoader.load_threaded_request(_target_path, "PackedScene", false, ResourceLoader.CACHE_MODE_REUSE)
	if err != OK:
		push_error("SceneTransition: load_threaded_request(\"%s\") failed with error %d." % [_target_path, err])
		_abort()
		return
	_phase = _Phase.LOADING
	_emit_progress(0.0)


func _poll_load() -> void:
	_progress_buffer.clear()
	var status: int = ResourceLoader.load_threaded_get_status(_target_path, _progress_buffer)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if not _progress_buffer.is_empty():
				_emit_progress(float(_progress_buffer[0]))
		ResourceLoader.THREAD_LOAD_LOADED:
			_emit_progress(1.0)
			_swap_scene()
		ResourceLoader.THREAD_LOAD_FAILED:
			push_error("SceneTransition: loading \"%s\" failed (THREAD_LOAD_FAILED)." % _target_path)
			_abort()
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("SceneTransition: \"%s\" is not a valid resource (THREAD_LOAD_INVALID_RESOURCE)." % _target_path)
			_abort()
		_:
			push_error("SceneTransition: unknown thread load status %d for \"%s\"." % [status, _target_path])
			_abort()


func _swap_scene() -> void:
	var packed: Resource = ResourceLoader.load_threaded_get(_target_path)
	if packed == null or not (packed is PackedScene):
		push_error("SceneTransition: \"%s\" did not resolve to a PackedScene." % _target_path)
		_abort()
		return

	var tree: SceneTree = get_tree()
	if tree == null:
		push_error("SceneTransition: no SceneTree available, cannot swap scenes.")
		_abort()
		return

	var err: int = tree.change_scene_to_packed(packed as PackedScene)
	if err != OK:
		push_error("SceneTransition: change_scene_to_packed(\"%s\") failed with error %d." % [_target_path, err])
		_abort()
		return

	# The old scene is freed at the end of this frame; drop our reference now so nothing can
	# observe a freed Level through get_current_level().
	_current_level = null
	_hide_loader()
	_fade_elapsed = 0.0
	_phase = _Phase.FADE_IN
	if _fade_in_duration <= MIN_FADE_DURATION:
		_apply_fade_alpha(0.0)
		_finish()


## Failure path: keep the old scene, reverse the fade so the player is never left on black.
func _abort() -> void:
	_aborted = true
	_hide_loader()
	_fade_elapsed = 0.0
	_phase = _Phase.FADE_IN
	if _fade_in_duration <= MIN_FADE_DURATION:
		_apply_fade_alpha(0.0)
		_finish()


func _finish() -> void:
	var finished_path: String = _target_path
	_phase = _Phase.IDLE
	_target_path = ""
	_progress = 0.0
	_aborted = false
	_apply_fade_alpha(0.0)
	_set_overlay_active(false)
	set_process(false)
	transition_finished.emit(finished_path)


func _emit_progress(ratio: float) -> void:
	var clamped: float = clampf(ratio, 0.0, 1.0)
	# Progress from the loader is monotonic in practice, but guard anyway: a spinner that jumps
	# backwards reads as a bug to the player.
	if clamped < _progress:
		clamped = _progress
	_progress = clamped
	_set_loader_progress(clamped)
	load_progress.emit(clamped)


# --- Overlay ----------------------------------------------------------------------------------

func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "TransitionLayer"
	_layer.layer = OVERLAY_LAYER
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.color = Color(FADE_COLOR.r, FADE_COLOR.g, FADE_COLOR.b, 0.0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.process_mode = Node.PROCESS_MODE_ALWAYS
	# STOP while the overlay is up: the outgoing scene must not receive clicks aimed at nothing.
	# Toggled to IGNORE together with visibility in _set_overlay_active().
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.visible = false
	_layer.add_child(_fade_rect)

	_loading_indicator = _instantiate_loading_indicator()
	if _loading_indicator != null:
		_loading_indicator.process_mode = Node.PROCESS_MODE_ALWAYS
		# Added after the fade rect so the spinner draws on top of the black.
		_layer.add_child(_loading_indicator)


func _instantiate_loading_indicator() -> Control:
	if not ResourceLoader.exists(LOADING_INDICATOR_SCENE):
		push_warning("SceneTransition: \"%s\" not found, transitions will run without a loading indicator." % LOADING_INDICATOR_SCENE)
		return null
	var packed: Resource = load(LOADING_INDICATOR_SCENE)
	if packed == null or not (packed is PackedScene):
		push_warning("SceneTransition: \"%s\" is not a PackedScene, running without a loading indicator." % LOADING_INDICATOR_SCENE)
		return null
	var instance: Node = (packed as PackedScene).instantiate()
	if instance == null:
		push_warning("SceneTransition: failed to instantiate \"%s\"." % LOADING_INDICATOR_SCENE)
		return null
	if not (instance is Control):
		push_warning("SceneTransition: \"%s\" root is not a Control, discarding it." % LOADING_INDICATOR_SCENE)
		instance.queue_free()
		return null
	return instance as Control


func _set_overlay_active(active: bool) -> void:
	if _fade_rect == null or not is_instance_valid(_fade_rect):
		return
	_fade_rect.visible = active
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE


func _apply_fade_alpha(alpha: float) -> void:
	_fade_alpha = clampf(alpha, 0.0, 1.0)
	if _fade_rect == null or not is_instance_valid(_fade_rect):
		return
	_fade_rect.color = Color(FADE_COLOR.r, FADE_COLOR.g, FADE_COLOR.b, _fade_alpha)


# --- Loading indicator bridge -----------------------------------------------------------------
# The indicator is written by a separate module; every call is guarded so a partial implementation
# degrades to "no spinner" instead of taking the transition down with it.

func _show_loader() -> void:
	if _loading_indicator == null or not is_instance_valid(_loading_indicator):
		return
	if _loading_indicator.has_method("show_loader"):
		_loading_indicator.call("show_loader", true)
	else:
		push_warning("SceneTransition: loading indicator has no show_loader(), falling back to visible = true.")
		_loading_indicator.visible = true


func _hide_loader() -> void:
	if _loading_indicator == null or not is_instance_valid(_loading_indicator):
		return
	if _loading_indicator.has_method("hide_loader"):
		_loading_indicator.call("hide_loader", true)
	else:
		_loading_indicator.visible = false


func _set_loader_progress(ratio: float) -> void:
	if _loading_indicator == null or not is_instance_valid(_loading_indicator):
		return
	if _loading_indicator.has_method("set_progress"):
		_loading_indicator.call("set_progress", ratio)
