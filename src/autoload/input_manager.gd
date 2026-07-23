extends Node
## InputManager -- the single gateway between hardware input and gameplay code.
##
## Why this exists instead of calling `Input` directly everywhere:
##   1. Movement must be defined ONCE. Eight separate actions (WASD/arrows + numpad diagonals) collapse
##      into one screen-space vector here, so no consumer ever re-derives diagonal handling and no two
##      consumers can disagree about what "up" means.
##   2. Rebinds must survive a restart. `InputMap` is runtime-only; persistence goes through `Settings`
##      (section `input`, key `bindings`) and is re-applied here on boot.
##   3. Gameplay code must never see raw keycodes. The settings UI asks this module for labels instead
##      of formatting `InputEventKey` itself.
##   4. Camera control (zoom, orbit) is normalized ONCE. Wheel notches, held keys and mouse drags each
##      arrive in a different shape; a camera rig that handled them itself would re-solve the same
##      momentary-versus-held problem in every scene that owns a camera, and get it subtly different.
##
## Serialization decision (deliberate, see `_serialize_event`): a rebind is stored as a plain dictionary
## of scalar fields, NOT as `var_to_str(event)`. `var_to_str` on an `InputEvent` emits an
## `Object(InputEventKey, ...)` literal whose exact property set changes between engine versions, and
## reading it back with `str_to_var` instantiates an arbitrary object from a file the user can edit by
## hand. Both the forward-compatibility risk and the "settings.cfg can construct objects" risk are
## unacceptable for a file we advertise as user-editable. A field dictionary is boring, diffable, and
## fails closed: an unrecognised entry is warned about and skipped, leaving the default binding intact.

signal rebound(action: StringName)
signal device_changed(device: Device)

## Raised when the player grabs / releases the orbit control. A camera rig uses these to switch into
## and out of a manual-look state; polling `is_orbit_held()` would make that transition frame-dependent.
signal orbit_started()
signal orbit_ended()

enum Device { KEYBOARD, GAMEPAD }

## Gameplay actions the settings UI may show. `ui_*` actions are deliberately absent: Escape and the
## Godot built-ins are system-level, and letting a player rebind the way out of a menu is a soft-lock.
##
## `camera_orbit` IS listed: it ships bound to the middle mouse button, which plenty of hardware
## (trackpads, three-button-less mice, tilt-wheels that misfire) either lacks or reports unreliably.
## An unbindable orbit would simply be unusable for those players. It also serializes cleanly -- it is
## a single mouse button, and `_serialize_event` already round-trips `InputEventMouseButton`.
const REBINDABLE_ACTIONS: Array[StringName] = [
	&"move_up", &"move_down", &"move_left", &"move_right",
	&"move_up_left", &"move_up_right", &"move_down_left", &"move_down_right",
	&"interact", &"wait",
	&"camera_rotate_left", &"camera_rotate_right",
	&"camera_zoom_in", &"camera_zoom_out",
	&"camera_orbit",
]

const _ACTION_ZOOM_IN := &"camera_zoom_in"
const _ACTION_ZOOM_OUT := &"camera_zoom_out"
const _ACTION_ORBIT := &"camera_orbit"

## How often a HELD zoom key emits another step. Tuned so keyboard zoom reaches the same travel as a
## few wheel notches in well under a second, without a single tap ever producing two steps: the first
## step fires on the press event, the second only after a full interval of continuous hold.
const _ZOOM_REPEAT_INTERVAL := 0.06

## Diagonal actions contribute to BOTH axes, which is what makes a numpad key a true 8-way input.
## Screen space: +x is right, -y is up (matches Godot's 2D/screen convention).
const _MOVE_CONTRIBUTIONS: Dictionary = {
	&"move_right": Vector2(1.0, 0.0),
	&"move_left": Vector2(-1.0, 0.0),
	&"move_down": Vector2(0.0, 1.0),
	&"move_up": Vector2(0.0, -1.0),
	&"move_up_right": Vector2(1.0, -1.0),
	&"move_up_left": Vector2(-1.0, -1.0),
	&"move_down_right": Vector2(1.0, 1.0),
	&"move_down_left": Vector2(-1.0, 1.0),
}

const _SETTINGS_SECTION := "input"
const _SETTINGS_KEY := "bindings"

## Serialized event discriminators. Stored as ints so a hand-edited cfg stays terse; the values are
## frozen -- never renumber them, old settings files depend on them.
const _EVENT_KEY := 0
const _EVENT_MOUSE_BUTTON := 1
const _EVENT_JOYPAD_BUTTON := 2

## Sentinel for "this event does not identify a device". Kept out of the `Device` enum so the enum
## stays a clean two-value contract for consumers.
const _DEVICE_UNKNOWN := -1

## Below this the stick is considered at rest, so drift on a plugged-in pad cannot flip the device icon.
const _JOY_DEVICE_DEADZONE := 0.5
## Mouse jitter of a hand resting on the desk should not count as "the player is on keyboard+mouse".
const _MOUSE_MOTION_THRESHOLD := 2.0

var _device: Device = Device.KEYBOARD

## Captured BEFORE any saved rebind is applied -- this is the only record of what the project shipped
## with, and `reset_bindings()` plus the "don't persist defaults" rule both depend on it.
var _default_events: Dictionary = {}

## Zoom steps queued by `_input` since the last frame boundary. Collapsed into `_zoom_step` in
## `_process` -- see `get_zoom_step()` for why the value is buffered instead of read live.
var _zoom_pending: int = 0
var _zoom_step: int = 0
## +1 / -1 while a zoom key is physically held, 0 for a wheel notch or nothing.
var _zoom_hold_dir: int = 0
var _zoom_repeat_timer: float = 0.0

var _orbit_active: bool = false
var _orbit_delta: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_default_events()
	_apply_saved_bindings()


## Runs before any scene node's `_process` because autoloads sit at the top of the tree. That ordering
## is what lets `get_zoom_step()` hand the same value to every consumer within one frame.
func _process(delta: float) -> void:
	_update_zoom_repeat(delta)
	_zoom_step = signi(_zoom_pending)
	_zoom_pending = 0
	_release_orbit_if_lost()


func _input(event: InputEvent) -> void:
	# Camera input is sampled here rather than in `_unhandled_input` to match the device detection
	# below, and because zoom/orbit belong to the camera rig, which has no Control to swallow them.
	_handle_zoom_input(event)
	_handle_orbit_input(event)

	var detected := _detect_device(event)
	if detected == _DEVICE_UNKNOWN or detected == int(_device):
		return
	# Plain assignment, not `as Device`: `as` does not accept enum types in GDScript, and `detected` is
	# already guaranteed to be a valid Device value by the sentinel check above.
	_device = detected
	device_changed.emit(_device)


## Screen-space movement intent. The consumer rotates this by the active camera yaw -- see the
## camera-relative movement note in docs/ARCHITECTURE.md.
##
## Length is clamped to 1 rather than force-normalized: a digital key already yields length 1, a
## diagonal yields sqrt(2) and gets scaled down (so diagonal movement is not faster), and a
## half-pushed analog stick keeps its magnitude instead of being snapped to a full-speed run.
func get_move_vector() -> Vector2:
	var vector := Vector2.ZERO
	for action: StringName in _MOVE_CONTRIBUTIONS:
		if not InputMap.has_action(action):
			continue
		var strength := Input.get_action_strength(action)
		if strength <= 0.0:
			continue
		vector += (_MOVE_CONTRIBUTIONS[action] as Vector2) * strength
	return vector.limit_length(1.0)


# --- camera control ------------------------------------------------------------------------------

## Zoom intent for the current frame: +1 to move closer, -1 to move away, 0 for nothing.
##
## Two input shapes have to feel the same here, which is the whole reason this lives in one place:
##   * A MOUSE WHEEL notch is momentary -- the OS reports press and release back to back, sometimes
##     inside a single input batch, so polling `Input.is_action_pressed` would miss it entirely. Every
##     notch is therefore counted the moment its press event arrives.
##   * A ZOOM KEY (`=`, `+`, numpad +/-, `-`) can be held down. It emits one step on press and then a
##     further step every `_ZOOM_REPEAT_INTERVAL` seconds for as long as it stays down, so the player
##     can glide to the distance they want instead of hammering the key. The engine's own key echo is
##     ignored (it is OS-typematic-rate, which is both laggy and user-configurable).
##
## The result is buffered and refreshed once per frame, NOT consumed: this is a poll, so any number of
## consumers may call it in the same frame and all of them see the same answer. Consequently the value
## saturates at one step per frame -- a violent wheel spin zooms at frame rate, not faster, which keeps
## the zoom speed predictable regardless of how the mouse reports notches.
##
## Read it from `_process`, not `_physics_process`: the value refreshes once per rendered frame, and a
## frame that runs two physics ticks would otherwise apply the same step twice.
func get_zoom_step() -> int:
	return _zoom_step


## True while the orbit control (default: middle mouse button) is held down.
func is_orbit_held() -> bool:
	return _orbit_active


## Mouse movement accumulated while the orbit control was held, in pixels, since the last call.
##
## READING CLEARS IT -- hence `consume`. Calling this twice in one frame returns the real delta and
## then `Vector2.ZERO`, so exactly one node (the camera rig) may own this input. If a second consumer
## ever needs the same data, give it a signal rather than a second read.
##
## Motion is only accumulated while the orbit action is held, and the buffer is cleared when orbit
## starts, so a drag never begins by replaying stale movement. It is deliberately NOT cleared when the
## drag ends: the last few pixels of a flick are still valid input, and a consumer that reads once per
## frame would otherwise lose them.
func consume_orbit_delta() -> Vector2:
	var delta := _orbit_delta
	_orbit_delta = Vector2.ZERO
	return delta


## Replaces every event bound to `action` with `event`. Replace-all (rather than append) is what the
## settings UI implies: it shows one label per action, so leaving a stale second binding alive would
## mean the action still fires from a key the UI no longer mentions.
func rebind(action: StringName, event: InputEvent) -> void:
	if event == null:
		push_warning("InputManager.rebind: null event for action '%s', ignored." % action)
		return
	if not _is_rebindable(action):
		push_warning("InputManager.rebind: action '%s' is not rebindable, ignored." % action)
		return
	var payload := _serialize_event(event)
	if payload.is_empty():
		push_warning("InputManager.rebind: unsupported event type %s for action '%s', ignored."
				% [event.get_class(), action])
		return

	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)

	var bindings := _get_saved_bindings()
	if _matches_default(action, payload):
		# Rebinding back to a shipped default: drop the override so settings.cfg only ever lists real
		# deviations, and so a future change to the default binding reaches players who never rebound.
		bindings.erase(String(action))
	else:
		bindings[String(action)] = payload
	_store_bindings(bindings)

	rebound.emit(action)


## Restores every rebindable action to the events captured at boot and clears the persisted overrides.
func reset_bindings() -> void:
	for action: StringName in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for event: InputEvent in _defaults_for(action):
			InputMap.action_add_event(action, event)
		rebound.emit(action)
	_store_bindings({})


## Human-readable name of the action's primary binding, e.g. "W", "Numpad 7", "Left Mouse", "Wheel Up".
## Returns an empty string when the action is unknown or unbound; the UI decides how to render that.
func get_binding_label(action: StringName) -> String:
	if not InputMap.has_action(action):
		push_warning("InputManager.get_binding_label: unknown action '%s'." % action)
		return ""
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return ""
	return describe_event(events[0])


func get_rebindable_actions() -> Array[StringName]:
	var result: Array[StringName] = []
	for action: StringName in REBINDABLE_ACTIONS:
		if InputMap.has_action(action):
			result.append(action)
		else:
			push_warning("InputManager: rebindable action '%s' is missing from the InputMap." % action)
	return result


func get_device() -> Device:
	return _device


## Public because the rebind prompt has to label a key the player just pressed, before it is bound.
func describe_event(event: InputEvent) -> String:
	if event is InputEventKey:
		return _describe_key(event as InputEventKey)
	if event is InputEventMouseButton:
		return _describe_mouse_button((event as InputEventMouseButton).button_index)
	if event is InputEventJoypadButton:
		return "Pad %d" % (event as InputEventJoypadButton).button_index
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		return "Pad Axis %d%s" % [motion.axis, "+" if motion.axis_value >= 0.0 else "-"]
	if event != null:
		return event.as_text()
	return ""


# --- binding persistence -------------------------------------------------------------------------

func _capture_default_events() -> void:
	for action: StringName in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		# `action_get_events` hands back a fresh array, but the events inside are shared resources.
		# We never mutate an event, only add/erase, so holding the references is safe and cheap.
		_default_events[action] = InputMap.action_get_events(action)


func _apply_saved_bindings() -> void:
	var bindings := _get_saved_bindings()
	if bindings.is_empty():
		return
	for key: Variant in bindings:
		var action := StringName(str(key))
		# settings.cfg is user-editable, so treat it as untrusted: a hand-written entry must not be
		# able to rebind a ui_* action or invent an action that gameplay never checks.
		if not _is_rebindable(action):
			push_warning("InputManager: saved binding for non-rebindable action '%s' ignored." % action)
			continue
		var payload: Variant = bindings[key]
		if typeof(payload) != TYPE_DICTIONARY:
			push_warning("InputManager: saved binding for '%s' is not a dictionary, ignored." % action)
			continue
		var event := _deserialize_event(payload as Dictionary)
		if event == null:
			push_warning("InputManager: saved binding for '%s' could not be restored, default kept." % action)
			continue
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, event)


func _get_saved_bindings() -> Dictionary:
	# Settings is autoloaded before InputManager, but guard anyway: a test scene may run this script
	# standalone, and a missing manager must degrade to "defaults only", never to a crash.
	if not is_instance_valid(Settings):
		push_warning("InputManager: Settings autoload unavailable, rebinds will not persist.")
		return {}
	var value: Variant = Settings.get_value(_SETTINGS_SECTION, _SETTINGS_KEY, {})
	if typeof(value) != TYPE_DICTIONARY:
		push_warning("InputManager: 'input/bindings' is not a dictionary, treating it as empty.")
		return {}
	return (value as Dictionary).duplicate(true)


func _store_bindings(bindings: Dictionary) -> void:
	if not is_instance_valid(Settings):
		return
	Settings.set_value(_SETTINGS_SECTION, _SETTINGS_KEY, bindings)
	# `set_value` deliberately does not write to disk (see the contract), but a rebind is an explicit,
	# discrete user decision -- losing it to a crash before the next save would be indefensible.
	Settings.save_settings()


func _is_rebindable(action: StringName) -> bool:
	return REBINDABLE_ACTIONS.has(action) and InputMap.has_action(action)


func _matches_default(action: StringName, payload: Dictionary) -> bool:
	for event: InputEvent in _defaults_for(action):
		if _serialize_event(event) == payload:
			return true
	return false


func _defaults_for(action: StringName) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	var stored: Variant = _default_events.get(action, null)
	if stored is Array:
		for event: Variant in stored as Array:
			if event is InputEvent:
				events.append(event as InputEvent)
	return events


# --- serialization -------------------------------------------------------------------------------

## Returns an empty dictionary for event types we refuse to persist, which the caller treats as
## "unsupported" rather than silently writing half an event.
func _serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key := event as InputEventKey
		return {
			"type": _EVENT_KEY,
			# This project binds by physical_keycode (keycode is 0 in project.godot), so layout-shifted
			# keyboards keep WASD in the same physical place. Both are stored so a rebind captured from
			# a logical-keycode event round-trips too.
			"physical_keycode": int(key.physical_keycode),
			"keycode": int(key.keycode),
			"alt": key.alt_pressed,
			"shift": key.shift_pressed,
			"ctrl": key.ctrl_pressed,
			"meta": key.meta_pressed,
		}
	if event is InputEventMouseButton:
		return {
			"type": _EVENT_MOUSE_BUTTON,
			"button_index": int((event as InputEventMouseButton).button_index),
		}
	if event is InputEventJoypadButton:
		return {
			"type": _EVENT_JOYPAD_BUTTON,
			"button_index": int((event as InputEventJoypadButton).button_index),
		}
	return {}


func _deserialize_event(payload: Dictionary) -> InputEvent:
	if not payload.has("type"):
		return null
	match int(payload.get("type", -1)):
		_EVENT_KEY:
			var physical := int(payload.get("physical_keycode", 0))
			var logical := int(payload.get("keycode", 0))
			if physical == 0 and logical == 0:
				return null
			var key := InputEventKey.new()
			key.physical_keycode = physical
			key.keycode = logical
			key.alt_pressed = bool(payload.get("alt", false))
			key.shift_pressed = bool(payload.get("shift", false))
			key.ctrl_pressed = bool(payload.get("ctrl", false))
			key.meta_pressed = bool(payload.get("meta", false))
			return key
		_EVENT_MOUSE_BUTTON:
			var mouse_index := int(payload.get("button_index", 0))
			if mouse_index <= 0:
				return null
			var mouse := InputEventMouseButton.new()
			mouse.button_index = mouse_index
			return mouse
		_EVENT_JOYPAD_BUTTON:
			var pad_index := int(payload.get("button_index", -1))
			if pad_index < 0:
				return null
			var pad := InputEventJoypadButton.new()
			pad.button_index = pad_index
			return pad
	return null


# --- labels --------------------------------------------------------------------------------------

func _describe_key(key: InputEventKey) -> String:
	# physical_keycode first: it is what this project actually binds, and `keycode` is 0 on those
	# events, so reading keycode first would label every movement key as "(unset)".
	var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
	if code == 0:
		return ""

	var base := _numpad_name(code)
	if base.is_empty():
		# OS.get_keycode_string is used rather than DisplayServer.keyboard_get_label_from_physical
		# because the latter returns nothing on headless/no-keyboard setups, which would blank the
		# whole settings screen in a test run.
		base = OS.get_keycode_string(code)
	if base.is_empty():
		return ""

	var prefix := ""
	if key.ctrl_pressed:
		prefix += "Ctrl+"
	if key.alt_pressed:
		prefix += "Alt+"
	if key.shift_pressed:
		prefix += "Shift+"
	return prefix + base


## Godot renders the numeric keypad as "Kp 7"; players call it Numpad 7, and these keys are the
## project's diagonal movement, so the label has to be unambiguous.
func _numpad_name(code: int) -> String:
	match code:
		KEY_KP_0: return "Numpad 0"
		KEY_KP_1: return "Numpad 1"
		KEY_KP_2: return "Numpad 2"
		KEY_KP_3: return "Numpad 3"
		KEY_KP_4: return "Numpad 4"
		KEY_KP_5: return "Numpad 5"
		KEY_KP_6: return "Numpad 6"
		KEY_KP_7: return "Numpad 7"
		KEY_KP_8: return "Numpad 8"
		KEY_KP_9: return "Numpad 9"
		KEY_KP_ADD: return "Numpad +"
		KEY_KP_SUBTRACT: return "Numpad -"
		KEY_KP_MULTIPLY: return "Numpad *"
		KEY_KP_DIVIDE: return "Numpad /"
		KEY_KP_PERIOD: return "Numpad ."
		KEY_KP_ENTER: return "Numpad Enter"
	return ""


func _describe_mouse_button(button_index: int) -> String:
	match button_index:
		MOUSE_BUTTON_LEFT: return "Left Mouse"
		MOUSE_BUTTON_RIGHT: return "Right Mouse"
		MOUSE_BUTTON_MIDDLE: return "Middle Mouse"
		MOUSE_BUTTON_WHEEL_UP: return "Wheel Up"
		MOUSE_BUTTON_WHEEL_DOWN: return "Wheel Down"
		MOUSE_BUTTON_WHEEL_LEFT: return "Wheel Left"
		MOUSE_BUTTON_WHEEL_RIGHT: return "Wheel Right"
		MOUSE_BUTTON_XBUTTON1: return "Mouse 4"
		MOUSE_BUTTON_XBUTTON2: return "Mouse 5"
	return "Mouse %d" % button_index


# --- camera input plumbing -----------------------------------------------------------------------

func _handle_zoom_input(event: InputEvent) -> void:
	var pressed_dir := _zoom_dir_pressed(event)
	if pressed_dir != 0:
		_zoom_pending += pressed_dir
		if not _is_wheel_event(event):
			# Only a real, holdable button arms the repeat clock. A wheel notch that armed it would keep
			# zooming after the flick, because its release can arrive before the clock is ever checked.
			_zoom_hold_dir = pressed_dir
			_zoom_repeat_timer = 0.0
		return

	var released_dir := _zoom_dir_released(event)
	if released_dir != 0 and released_dir == _zoom_hold_dir:
		_zoom_hold_dir = 0


func _update_zoom_repeat(delta: float) -> void:
	if _zoom_hold_dir == 0:
		return
	# Safety net: a release event is lost whenever the window loses focus mid-press. Without this the
	# key would stay "held" forever and the camera would zoom on its own.
	var action := _zoom_action_for(_zoom_hold_dir)
	if not InputMap.has_action(action) or not Input.is_action_pressed(action):
		_zoom_hold_dir = 0
		return
	_zoom_repeat_timer += delta
	while _zoom_repeat_timer >= _ZOOM_REPEAT_INTERVAL:
		_zoom_repeat_timer -= _ZOOM_REPEAT_INTERVAL
		_zoom_pending += _zoom_hold_dir


## Returns +1 for a zoom-in press, -1 for a zoom-out press, 0 otherwise. Echo events are excluded
## (`is_action_pressed` ignores them by default): `_update_zoom_repeat` owns the repeat rate, so it
## does not depend on the player's OS typematic settings.
func _zoom_dir_pressed(event: InputEvent) -> int:
	if InputMap.has_action(_ACTION_ZOOM_IN) and event.is_action_pressed(_ACTION_ZOOM_IN):
		return 1
	if InputMap.has_action(_ACTION_ZOOM_OUT) and event.is_action_pressed(_ACTION_ZOOM_OUT):
		return -1
	return 0


func _zoom_dir_released(event: InputEvent) -> int:
	if InputMap.has_action(_ACTION_ZOOM_IN) and event.is_action_released(_ACTION_ZOOM_IN):
		return 1
	if InputMap.has_action(_ACTION_ZOOM_OUT) and event.is_action_released(_ACTION_ZOOM_OUT):
		return -1
	return 0


func _zoom_action_for(direction: int) -> StringName:
	return _ACTION_ZOOM_IN if direction > 0 else _ACTION_ZOOM_OUT


## Wheel buttons are momentary by nature -- the OS sends press and release back to back, often inside
## a single input batch, so they must never arm the hold-repeat clock. Every other mouse button can be
## held and is treated like a key.
func _is_wheel_event(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton):
		return false
	var index := (event as InputEventMouseButton).button_index
	return index == MOUSE_BUTTON_WHEEL_UP or index == MOUSE_BUTTON_WHEEL_DOWN \
			or index == MOUSE_BUTTON_WHEEL_LEFT or index == MOUSE_BUTTON_WHEEL_RIGHT


func _handle_orbit_input(event: InputEvent) -> void:
	if InputMap.has_action(_ACTION_ORBIT):
		if event.is_action_pressed(_ACTION_ORBIT):
			_begin_orbit()
			return
		if event.is_action_released(_ACTION_ORBIT):
			_end_orbit()
			return
	# Gathered here, not in `_process`, because a frame can carry several motion events and only their
	# sum describes the drag. Sampling `Input` once per frame would throw the rest away.
	if _orbit_active and event is InputEventMouseMotion:
		_orbit_delta += (event as InputEventMouseMotion).relative


func _begin_orbit() -> void:
	if _orbit_active:
		return
	_orbit_active = true
	# Drop anything the previous drag left unread, otherwise the camera snaps on the next grab.
	_orbit_delta = Vector2.ZERO
	orbit_started.emit()


func _end_orbit() -> void:
	if not _orbit_active:
		return
	_orbit_active = false
	orbit_ended.emit()


## Same focus-loss problem as the zoom hold: a button released outside the window never reports back,
## and a camera stuck in orbit mode would keep swallowing mouse movement.
func _release_orbit_if_lost() -> void:
	if not _orbit_active:
		return
	if not InputMap.has_action(_ACTION_ORBIT) or not Input.is_action_pressed(_ACTION_ORBIT):
		_end_orbit()


# --- device detection ----------------------------------------------------------------------------

## Returns a `Device` value, or `_DEVICE_UNKNOWN` when the event says nothing about which device the
## player is actually holding. An int sentinel is used instead of a nullable return so the function
## stays statically typed -- `Device` is an int enum and cannot express "no answer" on its own.
func _detect_device(event: InputEvent) -> int:
	if event is InputEventKey or event is InputEventMouseButton:
		return Device.KEYBOARD
	if event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).relative.length() > _MOUSE_MOTION_THRESHOLD:
			return Device.KEYBOARD
		return _DEVICE_UNKNOWN
	if event is InputEventJoypadButton:
		return Device.GAMEPAD
	if event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > _JOY_DEVICE_DEADZONE:
			return Device.GAMEPAD
		return _DEVICE_UNKNOWN
	return _DEVICE_UNKNOWN
