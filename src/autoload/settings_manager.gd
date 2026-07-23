extends Node
## Global user settings: persistence (`user://settings.cfg`) and engine application.
##
## Design notes (why it looks like this):
##
## * ConfigFile, not a custom Resource. Settings must survive engine/format updates and stay
##   hand-editable when a player breaks their own video config and cannot reach the menu.
##   A binary/`.tres` store would fail both goals.
## * An in-memory cache (`_values`) seeded from `DEFAULTS` is the single read path. After
##   `load_settings()` every known key is guaranteed present, so `get_value()` never has to
##   guess and consumers never branch on "unset".
## * `set_value()` deliberately does NOT write to disk. Settings UIs mutate on every slider
##   frame; saving there would hammer the filesystem. The UI calls `save_settings()` on commit.
## * This is autoload #3 and must not call any other manager. Localization/Audio/Input read
##   from here during their own `_ready()`, so any outbound call would invert the dependency
##   order declared in docs/ARCHITECTURE.md.
## * Every windowing call is guarded by `_is_headless()`. Tests run with the headless driver,
##   where DisplayServer window functions are stubs that error out instead of no-oping.

signal changed(section: String, key: String, value: Variant)
signal applied()

## Backing store. Plain text, user-editable, lives next to saves.
const CONFIG_PATH := "user://settings.cfg"

## Internal render target of the pixel-art path. Resolutions whose height is an exact multiple
## of 360 upscale by a whole factor and stay free of moire; the rest are still offered because
## refusing a player's native resolution is worse than a slightly soft image.
const PIXEL_ART_BASE := Vector2i(640, 360)

## Common desktop modes, ascending. The settings UI marks the integer-scale ones (see
## `is_integer_scale()`) but never hides the others.
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(640, 360),
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3440, 1440),
	Vector2i(3840, 2160),
]

## Window mode values for `video/window_mode`.
const WINDOW_MODE_WINDOWED := 0
const WINDOW_MODE_BORDERLESS := 1
const WINDOW_MODE_FULLSCREEN := 2

## Shadow quality values for `video/shadow_quality`.
const SHADOW_QUALITY_OFF := 0
const SHADOW_QUALITY_LOW := 1
const SHADOW_QUALITY_MEDIUM := 2
const SHADOW_QUALITY_HIGH := 3

## Directional shadow atlas size per quality step. Index = `video/shadow_quality`.
const _SHADOW_ATLAS_SIZES: Array[int] = [512, 1024, 2048, 4096]

## Soft shadow filter quality per quality step. Index = `video/shadow_quality`.
const _SHADOW_FILTER_QUALITY: Array[int] = [
	RenderingServer.SHADOW_QUALITY_HARD,
	RenderingServer.SHADOW_QUALITY_SOFT_LOW,
	RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
	RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
]

## Bounds for `video/render_scale`. Below 0.25 the image is unreadable, above 2.0 the cost is
## quadratic for no visible gain on a pixel-art target.
const RENDER_SCALE_MIN := 0.25
const RENDER_SCALE_MAX := 2.0

## Bounds for the colour-grade keys. Centred on 1.0 = "untouched", so a player who drags a
## slider to an extreme can always find neutral again by looking for the middle.
const BRIGHTNESS_MIN := 0.5
const BRIGHTNESS_MAX := 1.5
const CONTRAST_MIN := 0.5
const CONTRAST_MAX := 1.5
const SATURATION_MIN := 0.0
const SATURATION_MAX := 2.0

## Every effect-intensity key (CRT sliders, bloom strength, sharpen) is a normalised 0..1
## amount. The shader decides what "1.0" means; the setting never carries shader units, so
## retuning the effect does not invalidate saved configs.
const EFFECT_AMOUNT_MIN := 0.0
const EFFECT_AMOUNT_MAX := 1.0

## Every known setting with its default. Doubles as the type schema: values loaded from disk are
## coerced to the type of their default, so a corrupted or hand-mangled file degrades to a
## default instead of throwing a type error deep inside `apply_all()`.
const DEFAULTS := {
	"video": {
		"resolution": Vector2i(1280, 720),
		"window_mode": 0,
		"vsync": 1,
		"max_fps": 0,
		"msaa": 0,
		"shadow_quality": 2,
		"render_scale": 1.0,
		# Post-processing. This manager only stores these and emits `changed`; the
		# ScreenEffects autoload owns the shaders and reacts to that signal. Keeping the
		# application out of here preserves the "Settings calls nobody" rule that the
		# autoload order in docs/ARCHITECTURE.md depends on.
		"sharpen": 0.0,
		"ssao_enabled": false,
		"bloom_enabled": true,
		"bloom_strength": 0.25,
		"fog_enabled": false,
		# CRT. Off by default: it is a strong stylistic filter, and a fresh install must
		# show the game as authored before the player opts into a look.
		"crt_enabled": false,
		"crt_scanlines": 0.35,
		"crt_aberration": 0.25,
		"crt_vignette": 0.30,
		"crt_mask": 0.25,
		"crt_flicker": 0.15,
		# Colour grade, applied after everything else.
		"brightness": 1.0,
		"contrast": 1.0,
		"saturation": 1.0,
	},
	"audio": {
		"master": 1.0,
		"music": 0.8,
		"sfx": 1.0,
	},
	"game": {
		"language": "pl",
	},
	"input": {
		"bindings": {},
	},
}

var _values: Dictionary = {}
var _loaded := false


func _ready() -> void:
	# Autoloads are children of the scene tree root, so the viewport that apply_all() needs
	# already exists here. Applying at boot lets the saved window state win over project.godot.
	load_settings()
	apply_all()


# --- Public API -------------------------------------------------------------------------------


## Returns the current value. `fallback` is only consulted for keys absent from [constant DEFAULTS],
## because after [method load_settings] every known key is guaranteed to be present in the cache.
func get_value(section: String, key: String, fallback: Variant = null) -> Variant:
	if not _loaded:
		load_settings()
	var bucket: Variant = _values.get(section)
	if bucket is Dictionary and (bucket as Dictionary).has(key):
		return (bucket as Dictionary)[key]
	return fallback


## Stores a value in memory and emits [signal changed]. Does not touch the disk: call
## [method save_settings] when the user commits.
func set_value(section: String, key: String, value: Variant) -> void:
	if not _loaded:
		load_settings()
	if not _values.has(section):
		if not DEFAULTS.has(section):
			push_warning("Settings: writing unknown section '%s'." % section)
		_values[section] = {}
	var bucket: Dictionary = _values[section]
	if bucket.has(key):
		var coerced: Variant = _coerce(value, bucket[key], section, key)
		# Re-emitting for an unchanged value makes UI round-trips (signal -> control -> setter)
		# loop, and gives listeners like AudioManager pointless work every slider frame.
		if _is_same(coerced, bucket[key]):
			return
		bucket[key] = coerced
		changed.emit(section, key, coerced)
		return
	if not _has_default(section, key):
		push_warning("Settings: writing unknown key '%s/%s'." % [section, key])
	bucket[key] = value
	changed.emit(section, key, value)


## Writes the whole cache to [constant CONFIG_PATH]. Failures warn instead of raising: losing a
## settings write must never take the game down.
func save_settings() -> void:
	if not _loaded:
		load_settings()
	var config := ConfigFile.new()
	for section: String in _values.keys():
		var bucket: Variant = _values[section]
		if not (bucket is Dictionary):
			continue
		for key: String in (bucket as Dictionary).keys():
			config.set_value(section, key, (bucket as Dictionary)[key])
	var err := config.save(CONFIG_PATH)
	if err != OK:
		push_warning("Settings: could not save '%s' (error %d)." % [CONFIG_PATH, err])


## Rebuilds the cache from defaults, then overlays whatever the config file holds.
## A missing file is the normal first-run case and is not an error.
func load_settings() -> void:
	_values = DEFAULTS.duplicate(true)
	_loaded = true

	var config := ConfigFile.new()
	var err := config.load(CONFIG_PATH)
	if err == ERR_FILE_NOT_FOUND or err == ERR_FILE_CANT_OPEN:
		return
	if err != OK:
		push_warning("Settings: '%s' unreadable (error %d), using defaults." % [CONFIG_PATH, err])
		return

	for section: String in config.get_sections():
		if not _values.has(section):
			_values[section] = {}
		var bucket: Dictionary = _values[section]
		for key: String in config.get_section_keys(section):
			var raw: Variant = config.get_value(section, key)
			if bucket.has(key):
				bucket[key] = _coerce(raw, bucket[key], section, key)
			else:
				# Unknown keys are kept verbatim so a downgrade does not silently drop a
				# newer version's settings from the file.
				bucket[key] = raw


## Pushes every value into the engine and emits [signal applied].
func apply_all() -> void:
	if not _loaded:
		load_settings()
	_apply_window()
	_apply_frame_pacing()
	_apply_rendering()
	applied.emit()


## Restores every value to its default, persists, and re-applies. Emits [signal changed] per key
## so open settings screens refresh without needing a separate "reloaded" signal.
func reset_to_defaults() -> void:
	var previous: Dictionary = _values
	_values = DEFAULTS.duplicate(true)
	_loaded = true
	for section: String in _values.keys():
		var bucket: Dictionary = _values[section]
		for key: String in bucket.keys():
			var was: Variant = null
			var old_bucket: Variant = previous.get(section)
			if old_bucket is Dictionary and (old_bucket as Dictionary).has(key):
				was = (old_bucket as Dictionary)[key]
			if not _is_same(was, bucket[key]):
				changed.emit(section, key, bucket[key])
	save_settings()
	apply_all()


## True when `res` upscales from the 640x360 pixel-art target by a whole factor, i.e. when its
## height is an exact multiple of 360. Non-integer scales still render, they just alias.
func is_integer_scale(res: Vector2i) -> bool:
	if res.y <= 0:
		return false
	return res.y % PIXEL_ART_BASE.y == 0


# --- Application ------------------------------------------------------------------------------


func _apply_window() -> void:
	if _is_headless():
		return

	var mode: int = get_value("video", "window_mode", WINDOW_MODE_WINDOWED)
	if mode < WINDOW_MODE_WINDOWED or mode > WINDOW_MODE_FULLSCREEN:
		push_warning("Settings: invalid window_mode %d, falling back to windowed." % mode)
		mode = WINDOW_MODE_WINDOWED

	if mode == WINDOW_MODE_FULLSCREEN:
		# Godot's WINDOW_MODE_FULLSCREEN is already borderless-fullscreen. Exclusive fullscreen
		# is avoided on purpose: it triggers a display mode switch and alt-tab stalls, and buys
		# nothing for a game that renders at 640x360 internally.
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return

	# Leave fullscreen before resizing, otherwise the size request is swallowed.
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(
		DisplayServer.WINDOW_FLAG_BORDERLESS, mode == WINDOW_MODE_BORDERLESS
	)

	var size: Vector2i = get_value("video", "resolution", RESOLUTIONS[1])
	if size.x <= 0 or size.y <= 0:
		push_warning("Settings: invalid resolution %s, ignoring." % str(size))
		return

	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	# A resolution saved on a bigger monitor must not push the title bar off-screen on a
	# smaller one, so clamp to what the current screen can actually show.
	if usable.size.x > 0 and usable.size.y > 0:
		size.x = mini(size.x, usable.size.x)
		size.y = mini(size.y, usable.size.y)

	DisplayServer.window_set_size(size)
	if usable.size.x > 0 and usable.size.y > 0:
		DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)


func _apply_frame_pacing() -> void:
	var fps: int = get_value("video", "max_fps", 0)
	Engine.max_fps = maxi(0, fps)

	if _is_headless():
		return
	var vsync: int = get_value("video", "vsync", DisplayServer.VSYNC_ENABLED)
	if vsync < DisplayServer.VSYNC_DISABLED or vsync > DisplayServer.VSYNC_MAILBOX:
		push_warning("Settings: invalid vsync mode %d, falling back to enabled." % vsync)
		vsync = DisplayServer.VSYNC_ENABLED
	DisplayServer.window_set_vsync_mode(vsync)


func _apply_rendering() -> void:
	var shadow: int = get_value("video", "shadow_quality", SHADOW_QUALITY_MEDIUM)
	shadow = clampi(shadow, SHADOW_QUALITY_OFF, SHADOW_QUALITY_HIGH)
	# "Off" is expressed as the smallest atlas plus hard filtering rather than by disabling
	# shadows outright: switching shadows off is a per-Light3D property, and a global setting
	# has no business walking the scene tree to flip every light it finds.
	RenderingServer.directional_shadow_atlas_set_size(_SHADOW_ATLAS_SIZES[shadow], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(_SHADOW_FILTER_QUALITY[shadow])

	var viewport := get_viewport()
	if viewport == null:
		push_warning("Settings: no viewport available, skipping viewport-local settings.")
		return

	var msaa: int = get_value("video", "msaa", Viewport.MSAA_DISABLED)
	if msaa < Viewport.MSAA_DISABLED or msaa >= Viewport.MSAA_MAX:
		push_warning("Settings: invalid msaa %d, falling back to disabled." % msaa)
		msaa = Viewport.MSAA_DISABLED
	viewport.msaa_3d = msaa

	var scale: float = get_value("video", "render_scale", 1.0)
	if not is_finite(scale):
		push_warning("Settings: non-finite render_scale, falling back to 1.0.")
		scale = 1.0
	viewport.scaling_3d_scale = clampf(scale, RENDER_SCALE_MIN, RENDER_SCALE_MAX)


# --- Helpers ----------------------------------------------------------------------------------


## The headless display driver stubs out window functions and errors on them; tests run there.
func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _has_default(section: String, key: String) -> bool:
	if not DEFAULTS.has(section):
		return false
	return (DEFAULTS[section] as Dictionary).has(key)


## Forces `value` to the type of `template`, so a hand-edited config cannot inject a String
## where the engine expects an int. Numeric widening/narrowing is allowed because ConfigFile
## writes `1.0` as a float and a user may type `1`.
func _coerce(value: Variant, template: Variant, section: String, key: String) -> Variant:
	var want := typeof(template)
	var got := typeof(value)
	if got == want:
		return value
	if want == TYPE_INT and (got == TYPE_FLOAT or got == TYPE_BOOL):
		return int(value)
	if want == TYPE_FLOAT and (got == TYPE_INT or got == TYPE_BOOL):
		return float(value)
	# Toggles are the keys players are most likely to flip by hand, and `crt_enabled=1` is
	# the obvious thing to type. Accept it rather than warning and reverting the edit.
	if want == TYPE_BOOL and (got == TYPE_INT or got == TYPE_FLOAT):
		return bool(value)
	if want == TYPE_VECTOR2I and got == TYPE_VECTOR2:
		return Vector2i(value as Vector2)
	if want == TYPE_STRING and got == TYPE_STRING_NAME:
		return String(value)
	push_warning(
		"Settings: '%s/%s' expected %s, got %s - using default."
		% [section, key, type_string(want), type_string(got)]
	)
	return template


## Equality that does not raise on mismatched types (`==` across Dictionary and int, for example).
func _is_same(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	return a == b
