extends Node
## Owns the game's whole post-process look: the full-frame CRT overlay plus the
## `WorldEnvironment`-side grade (bloom, SSAO, fog, brightness/contrast/saturation) and viewport
## sharpening. Every value comes from the `video` section of `Settings`.
##
## Design notes (why it looks like this):
##
## * ONE module for both halves. The CRT is a shader on a `CanvasLayer`, the grade lives on the
##   level's `WorldEnvironment`, and sharpening is a `Viewport` property - three different owners,
##   but from the player's point of view they are one screen of sliders. Splitting them across
##   modules would mean three places to keep in sync with one settings page, and a "reset video"
##   that half-applies.
## * The overlay is HIDDEN, not zeroed, when the CRT is off. A full-screen `ColorRect` with a
##   shader costs a back-buffer copy plus one pass over every pixel every frame even when the
##   shader is a mathematical no-op. `visible = false` skips the draw entirely, so a player who
##   turned the effect off pays nothing for it.
## * Every `Settings` access goes through `get_node_or_null("/root/Settings")` and typed readers.
##   A test scene may load this autoload without the rest of the stack, and `user://settings.cfg`
##   is hand-editable, so both "manager missing" and "value has the wrong type" are realistic and
##   must degrade to defaults rather than raise.
## * A missing shader or a missing `WorldEnvironment` warns and is skipped. A level that has not
##   been given an environment yet still has to boot so it can be fixed in the editor.

## Shader driving the overlay. Absent = warning + no CRT; the rest of the module still works.
const CRT_SHADER_PATH := "res://assets/shaders/crt.gdshader"

## Canvas layer of the CRT overlay.
##
## Why 120: it has to sit ABOVE the game and above the UI (SettingsMenu is layer 100), because a
## simulated tube covers the entire monitor - a HUD floating crisply on top of a scanlined world
## would read as if the UI were painted on the glass rather than displayed by it.
## It has to sit BELOW `SceneTransition.OVERLAY_LAYER` (128), because that layer holds the fade
## rect. Above the fade, the CRT would not be covered by it - it would filter it, and a fade to
## black would end on a scanlined, flickering black instead of on black.
const OVERLAY_LAYER := 120

const VIDEO_SECTION := "video"

## CRT settings keys with their contract defaults. Doubles as the type schema for the readers.
const CRT_DEFAULTS := {
	"crt_enabled": false,
	"crt_scanlines": 0.35,
	"crt_aberration": 0.25,
	"crt_vignette": 0.30,
	"crt_mask": 0.25,
	"crt_flicker": 0.15,
}

## Settings key -> shader uniform. `crt_enabled` is absent on purpose: it toggles the layer's
## visibility instead of a uniform, see the class docs.
const CRT_UNIFORMS := {
	"crt_scanlines": &"scanlines",
	"crt_aberration": &"aberration",
	"crt_vignette": &"vignette",
	"crt_mask": &"mask_strength",
	"crt_flicker": &"flicker",
}

## Non-shader effects with their contract defaults.
const ENVIRONMENT_DEFAULTS := {
	"bloom_enabled": true,
	"bloom_strength": 0.25,
	"ssao_enabled": false,
	"fog_enabled": false,
	"brightness": 1.0,
	"contrast": 1.0,
	"saturation": 1.0,
}

const SHARPEN_KEY := "sharpen"

## Bounds from the settings contract. Clamped here as well: a hand-edited config must not be able
## to push the engine into a nonsensical state.
const BRIGHTNESS_MIN := 0.5
const BRIGHTNESS_MAX := 1.5
const CONTRAST_MIN := 0.5
const CONTRAST_MAX := 1.5
const SATURATION_MIN := 0.0
const SATURATION_MAX := 2.0

## Glow intensity at `bloom_strength` = 1.0. Godot's glow keeps rising well past this, but beyond
## roughly 2.0 bright surfaces stop blooming and just wash out.
const GLOW_INTENSITY_AT_FULL := 2.0

## Godot expresses FSR sharpening INVERTED: 0.0 is sharpest and sharpness halves with every whole
## number. Our slider runs the intuitive way (0 = off), so it is remapped on the way in.
const FSR_SHARPNESS_SOFTEST := 2.0

## Group joined by every `Level`, used to find the active level's `WorldEnvironment` without
## hardcoding a scene path. Mirrors `Level.LEVEL_GROUP`; duplicated as a literal so this autoload
## does not fail to parse when `level.gd` is absent from a stripped-down test project.
const LEVEL_GROUP: StringName = &"level"

var _settings: Node = null
var _layer: CanvasLayer = null
var _rect: ColorRect = null
var _material: ShaderMaterial = null

## Cached so `apply_environment()` does not walk the tree on every settings change. Re-resolved
## automatically once the cached node is freed or leaves the tree.
var _environment: Environment = null

## Sharpening needs an upscaling render path to exist; warn about that at most once instead of
## every time a slider moves.
var _sharpen_warned := false


func _ready() -> void:
	# The overlay must keep drawing while the tree is paused: the settings menu pauses the game,
	# and that is exactly when the player is looking at the CRT sliders.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_settings = get_node_or_null(^"/root/Settings")
	if _settings == null:
		push_warning("ScreenEffects: autoload 'Settings' not found; using contract defaults.")
	elif _settings.has_signal(&"changed"):
		_settings.changed.connect(_on_settings_changed)

	# Re-grade after every scene change: the new level brings its own WorldEnvironment, and the
	# cached one belongs to a scene that is being freed.
	var transition := get_node_or_null(^"/root/SceneTransition")
	if transition != null and transition.has_signal(&"transition_finished"):
		transition.transition_finished.connect(_on_transition_finished)

	_build_overlay()
	_apply_crt()

	# The main scene is instantiated after the autoloads are ready, so there is nothing to grade
	# yet on this frame.
	apply_environment.call_deferred()


# --- Public API -------------------------------------------------------------------------------


## Turns the CRT overlay on or off. Writes through to `Settings` (without persisting, matching
## `set_value` semantics) so the settings screen and any other reader see the same state.
func set_crt_enabled(enabled: bool) -> void:
	if _settings != null and _settings.has_method(&"set_value"):
		_settings.set_value(VIDEO_SECTION, "crt_enabled", enabled)
		# `set_value` emits `changed`, which already routed us through `_apply_crt()`; applying
		# again here would be redundant but is harmless and keeps the call correct when Settings
		# suppresses the echo for an unchanged value.
	_apply_crt()


func is_crt_enabled() -> bool:
	return _get_bool("crt_enabled")


## Re-reads every setting and re-applies both halves. Call after changing settings in bulk.
func refresh() -> void:
	_apply_crt()
	apply_environment()


## Pushes bloom / SSAO / fog / brightness / contrast / saturation onto the active level's
## `WorldEnvironment`, and sharpening onto the viewport. A level without a `WorldEnvironment`
## warns and is skipped - it is a content bug, not a reason to take the game down.
func apply_environment() -> void:
	_apply_sharpen()

	var env := _resolve_environment()
	if env == null:
		push_warning("ScreenEffects: no WorldEnvironment in the current scene; grade not applied.")
		return

	env.glow_enabled = _get_bool("bloom_enabled")
	if env.glow_enabled:
		env.glow_intensity = clampf(_get_float("bloom_strength"), 0.0, 1.0) * GLOW_INTENSITY_AT_FULL

	env.ssao_enabled = _get_bool("ssao_enabled")
	env.fog_enabled = _get_bool("fog_enabled")

	var brightness := clampf(_get_float("brightness"), BRIGHTNESS_MIN, BRIGHTNESS_MAX)
	var contrast := clampf(_get_float("contrast"), CONTRAST_MIN, CONTRAST_MAX)
	var saturation := clampf(_get_float("saturation"), SATURATION_MIN, SATURATION_MAX)
	env.adjustment_brightness = brightness
	env.adjustment_contrast = contrast
	env.adjustment_saturation = saturation
	# The adjustment pass is only switched on when it would actually change something: at
	# 1/1/1 it is an identity transform, and paying for a full-screen pass to multiply by one is
	# the kind of cost that never shows up in a profile as anything but "the game is slower".
	env.adjustment_enabled = (
		not is_equal_approx(brightness, 1.0)
		or not is_equal_approx(contrast, 1.0)
		or not is_equal_approx(saturation, 1.0)
	)


# --- Overlay ----------------------------------------------------------------------------------


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "ScreenEffectsLayer"
	_layer.layer = OVERLAY_LAYER
	# Same reason as this node: the effect must survive a paused tree.
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_layer.visible = false
	add_child(_layer)

	_rect = ColorRect.new()
	_rect.name = "CRT"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# A full-screen Control over the whole UI would otherwise swallow every click in the game.
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.process_mode = Node.PROCESS_MODE_ALWAYS
	_layer.add_child(_rect)

	var shader := load(CRT_SHADER_PATH) as Shader
	if shader == null:
		push_warning("ScreenEffects: '%s' missing or invalid; CRT disabled." % CRT_SHADER_PATH)
		return
	_material = ShaderMaterial.new()
	_material.shader = shader
	_rect.material = _material


func _apply_crt() -> void:
	if _layer == null:
		return

	# Without a material there is nothing to draw but the raw ColorRect, which would paint the
	# screen a flat colour - strictly worse than showing no effect at all.
	var enabled := is_crt_enabled() and _material != null
	_layer.visible = enabled
	if not enabled:
		return

	for key: String in CRT_UNIFORMS:
		var uniform: StringName = CRT_UNIFORMS[key]
		_material.set_shader_parameter(uniform, clampf(_get_float(key), 0.0, 1.0))
	# Not a player-facing setting: the flicker runs at its authored rate and is scaled by the
	# `crt_flicker` amount instead. The uniform exists so tooling can freeze it for screenshots.
	_material.set_shader_parameter(&"time_scale", 1.0)


# --- Environment ------------------------------------------------------------------------------


## Sharpening runs through FSR rather than `Viewport.screen_space_aa`.
##
## `screen_space_aa` is FXAA - an anti-aliasing filter that BLURS edge pixels. Wiring a "sharpen"
## slider to it would do the opposite of what the label promises, and on a pixel-art frame FXAA is
## actively harmful: it smears exactly the hard one-pixel edges the art style is built on.
## `fsr_sharpness` is a real contrast-adaptive sharpening pass and is the only screen-space
## sharpening the engine exposes, so that is what the slider drives.
##
## The catch, stated here so nobody rediscovers it in a debugger: FSR is part of the 3D upscaling
## path and is bypassed when `scaling_3d_scale` is 1.0. Sharpening therefore only has a visible
## effect when the player also lowered `video/render_scale` below 1.0. We warn once rather than
## silently forcing a render scale behind the player's back - overriding one video setting from
## another is how settings screens become impossible to reason about.
func _apply_sharpen() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return

	var sharpen := clampf(_get_float(SHARPEN_KEY, 0.0), 0.0, 1.0)
	if is_zero_approx(sharpen):
		# Back to the plain path: leaving FSR engaged with no sharpening still costs an upscale.
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		return

	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
	viewport.fsr_sharpness = (1.0 - sharpen) * FSR_SHARPNESS_SOFTEST

	if not _sharpen_warned and viewport.scaling_3d_scale >= 1.0:
		_sharpen_warned = true
		push_warning(
			"ScreenEffects: video/sharpen has no effect while video/render_scale is 1.0 or above"
			+ " (FSR sharpening only runs on the upscaling path)."
		)


## Finds the active `WorldEnvironment`'s `Environment`, preferring the level's own accessor.
func _resolve_environment() -> Environment:
	if _environment != null:
		return _environment

	var tree := get_tree()
	if tree == null:
		return null

	# Levels expose `get_world_environment()` and know which branch holds it, so ask them first
	# instead of guessing from the scene root.
	for level: Node in tree.get_nodes_in_group(LEVEL_GROUP):
		if not level.has_method(&"get_world_environment"):
			continue
		var found: Variant = level.call(&"get_world_environment")
		if found is WorldEnvironment:
			return _cache_environment(found as WorldEnvironment)

	# Fallback for test scenes and levels that do not extend `Level`.
	var root := tree.current_scene
	if root == null:
		return null
	if root is WorldEnvironment:
		return _cache_environment(root as WorldEnvironment)
	# "*" and not "": an empty pattern matches no node at all, which would make this fallback a
	# silent no-op.
	for node: Node in root.find_children("*", "WorldEnvironment", true, false):
		return _cache_environment(node as WorldEnvironment)
	return null


func _cache_environment(holder: WorldEnvironment) -> Environment:
	if holder.environment == null:
		push_warning("ScreenEffects: '%s' has no Environment resource; grade not applied." % holder.name)
		return null
	_environment = holder.environment
	# Drop the cache the moment the level owning it is freed, so the next call re-resolves against
	# the new scene instead of writing into a dead resource.
	if not holder.tree_exiting.is_connected(_on_environment_gone):
		holder.tree_exiting.connect(_on_environment_gone, CONNECT_ONE_SHOT)
	return _environment


func _on_environment_gone() -> void:
	_environment = null


func _on_transition_finished(_path: String) -> void:
	_environment = null
	apply_environment()


func _on_settings_changed(section: String, key: String, _value: Variant) -> void:
	if section != VIDEO_SECTION:
		return
	if key == "crt_enabled" or CRT_UNIFORMS.has(key):
		_apply_crt()
	elif ENVIRONMENT_DEFAULTS.has(key) or key == SHARPEN_KEY:
		apply_environment()


# --- Settings readers -------------------------------------------------------------------------


## Merged default lookup, so every reader has one source for "what should this be".
func _default_for(key: String, fallback: Variant) -> Variant:
	if CRT_DEFAULTS.has(key):
		return CRT_DEFAULTS[key]
	if ENVIRONMENT_DEFAULTS.has(key):
		return ENVIRONMENT_DEFAULTS[key]
	return fallback


func _get_bool(key: String, fallback: Variant = false) -> bool:
	var default_value: Variant = _default_for(key, fallback)
	if _settings == null or not _settings.has_method(&"get_value"):
		return bool(default_value)
	var value: Variant = _settings.get_value(VIDEO_SECTION, key, default_value)
	if value is bool or value is int or value is float:
		return bool(value)
	push_warning("ScreenEffects: video/%s is not a bool; using the default." % key)
	return bool(default_value)


func _get_float(key: String, fallback: Variant = 0.0) -> float:
	var default_value: Variant = _default_for(key, fallback)
	if _settings == null or not _settings.has_method(&"get_value"):
		return float(default_value)
	var value: Variant = _settings.get_value(VIDEO_SECTION, key, default_value)
	if value is float or value is int or value is bool:
		var number := float(value)
		# NaN/inf reach here through a hand-edited config and would poison a shader uniform or an
		# Environment property with a value that never clamps back out.
		if is_finite(number):
			return number
		push_warning("ScreenEffects: video/%s is not finite; using the default." % key)
		return float(default_value)
	push_warning("ScreenEffects: video/%s is not a number; using the default." % key)
	return float(default_value)
