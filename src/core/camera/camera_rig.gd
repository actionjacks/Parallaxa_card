## Orbiting, zooming camera rig for the isometric-ish 3D view.
##
## Builds its entire Phantom Camera rig in code (Camera3D > PhantomCameraHost, plus a sibling
## PhantomCamera3D), so a level only has to contain an empty node named `CameraRig`.
##
## The rig keeps the target dead centre and never changes pitch: yaw and distance are the only
## two degrees of freedom the player controls.
class_name CameraRig
extends Node3D

## Emitted when the orbit yaw changes, in degrees, wrapped to [0, 360).
## The player sprite picks its 8-way facing from this, so it is a public contract.
signal yaw_changed(deg: float)

## Emitted when the smoothed camera distance changes, in metres.
signal distance_changed(m: float)

## Camera pitch, in degrees below the horizon. FREE - change it and look.
##
## This used to be a locked constant, and the lock was real: characters were flat billboards baked
## from a 3D model at exactly 33 degrees, so any other angle made the painted-on ground contact stop
## matching the floor and the whole cast visibly floated or sank. Choosing a new angle meant re-baking
## every sheet, which is why 33 was chosen once and then defended.
##
## Characters are real rigged meshes now. Geometry looks correct from wherever the camera is put, so
## the angle is a design choice again rather than an asset constraint. 33 is kept as the default only
## because that is what the game has been played at; nothing downstream depends on it.
@export_range(10.0, 80.0, 0.5) var pitch_deg: float = 33.0:
	set(value):
		pitch_deg = value
		_apply_placement()

const _ORBIT_ACTION: StringName = &"camera_orbit"
const _ZOOM_IN_ACTION: StringName = &"camera_zoom_in"
const _ZOOM_OUT_ACTION: StringName = &"camera_zoom_out"

const _PCAM_MANAGER_NAME: String = "PhantomCameraManager"
const _INPUT_MANAGER_PATH: String = "/root/InputManager"

## Mirrors of PhantomCamera3D.FollowMode.SIMPLE and LookAtMode.SIMPLE. Spelled out as plain ints
## because the rig holds the addon nodes as untyped Node references (see _instantiate_by_class),
## and reading an enum off an untyped reference is a dynamic lookup this file should not depend on.
const _PCAM_FOLLOW_MODE_SIMPLE: int = 2
const _PCAM_LOOK_AT_MODE_SIMPLE: int = 2

## Below this the change is not worth a signal emission.
const _YAW_EPSILON: float = 0.01
const _DISTANCE_EPSILON: float = 0.001

## Node the camera orbits around and looks at. "The player is the centre of the game."
@export var target_path: NodePath

@export_group("Zoom")
## Closest the camera may get to the pivot, in metres.
@export_range(0.5, 100.0, 0.1) var min_distance: float = 4.0
## Furthest the camera may get from the pivot, in metres.
@export_range(0.5, 200.0, 0.1) var max_distance: float = 30.0
## Distance the rig starts at. Clamped into [min_distance, max_distance] on ready.
@export var start_distance: float = 12.0
## Metres added or removed per discrete zoom notch (one mouse-wheel click, one key tap).
@export var zoom_step: float = 1.5
## Notches per second while a zoom key is held down. Mouse wheel is inherently discrete and
## is unaffected by this.
@export var zoom_hold_rate: float = 8.0
## How fast the actual distance converges on the requested one. Higher is snappier.
## Applied through an exponential decay, so the feel does not change with framerate.
@export var zoom_smoothing: float = 12.0

@export_group("Orbit")
## Degrees of yaw per pixel of horizontal mouse movement while orbiting.
@export var orbit_sensitivity: float = 0.30
## Flips the orbit direction for players who expect "drag the world" instead of "drag the camera".
@export var orbit_invert: bool = false
## Yaw the rig starts at, in degrees.
@export var start_yaw: float = 0.0

@export_group("Framing")
## Height above the target's origin that the camera aims at, in metres. The target origin sits at
## the feet, so aiming at the origin would push the character into the top half of the screen.
## The orbit is computed around this raised pivot, which is what keeps the pitch exactly pitch_deg.
@export var pivot_height: float = 0.9

@export_group("Follow dead zone")
## Radius, in metres, of the region the player may move within before the camera starts to follow.
## The camera HOLDS STILL while the player stays inside it, and only begins trailing once the player
## reaches the edge. This is what stops the view lurching on every single tile step: a step or two
## costs no camera motion at all, while walking a real distance still keeps the character on screen.
## One tile is 1 m, so 2.5 lets the player roam ~2-3 tiles from centre before the camera moves. Set 0
## to disable the dead zone and glue the camera to the player as before.
@export_range(0.0, 12.0, 0.1) var follow_dead_zone: float = 2.5
## Once the player has left the dead zone, the fraction of the remaining gap the camera closes per
## second. Higher catches up faster and tighter; lower trails more loosely behind a moving player.
@export_range(1.0, 30.0, 0.5) var follow_catch_up: float = 9.0
## Vertical field of view in degrees, used by the perspective projection.
@export_range(1.0, 179.0, 0.1) var fov: float = 45.0
## Sprites are baked orthographically, so an orthographic view matches them exactly. Off by
## default because zoom is specified as a change in distance, which only reads as zoom under a
## perspective projection; in orthographic mode the distance is mapped to the camera size instead
## so that both projections frame the same amount of world.
@export var orthographic: bool = false

var _target: Node3D = null
var _camera: Camera3D = null
var _pcam: Node3D = null  # PhantomCamera3D, kept loosely typed so a missing addon cannot break parsing.

## The point the camera actually centres on. It TRAILS the target through a dead zone rather than
## being the target itself: the PhantomCamera follows this, not the player, so the player can move
## within `follow_dead_zone` without the camera reacting at all. Placed at the target on spawn, then
## dragged along only when the player crosses the edge - see `_update_anchor`.
var _anchor: Node3D = null

var _yaw_deg: float = 0.0
var _distance: float = 12.0
## Where the zoom is heading; _distance chases this.
var _requested_distance: float = 12.0

var _orbiting: bool = false
## Restored when orbiting ends, so the rig never fights whatever mode the game was already in.
var _mouse_mode_before_orbit: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
## Accumulated horizontal mouse motion, consumed once per frame.
var _pending_orbit_pixels: float = 0.0

var _input_manager: Node = null
## InputManager is written by another module and may not expose these yet, so every call is
## feature-detected once instead of being guarded on every frame.
var _has_zoom_step_api: bool = false
var _has_orbit_delta_api: bool = false

var _has_orbit_action: bool = false
var _has_zoom_actions: bool = false

## Last values broadcast, so signals only fire on real change.
var _last_signalled_yaw: float = NAN
var _last_signalled_distance: float = NAN


func _ready() -> void:
	min_distance = maxf(0.1, min_distance)
	max_distance = maxf(min_distance, max_distance)

	_yaw_deg = wrapf(start_yaw, 0.0, 360.0)
	_distance = clampf(start_distance, min_distance, max_distance)
	_requested_distance = _distance

	_has_orbit_action = InputMap.has_action(_ORBIT_ACTION)
	_has_zoom_actions = InputMap.has_action(_ZOOM_IN_ACTION) and InputMap.has_action(_ZOOM_OUT_ACTION)

	_input_manager = get_node_or_null(_INPUT_MANAGER_PATH)
	if _input_manager != null:
		_has_zoom_step_api = _input_manager.has_method(&"get_zoom_step")
		_has_orbit_delta_api = _input_manager.has_method(&"consume_orbit_delta")

	# The camera follows this, not the player. Created before the rig so set_follow_target can point at
	# it. A plain Node3D marker in world space; the rig moves it with the dead-zone logic.
	_anchor = Node3D.new()
	_anchor.name = "FollowAnchor"
	add_child(_anchor)

	_build_rig()
	_resolve_target_from_path()
	_apply_placement()

	# Deferred so a parent that connects in its own _ready() (parents are ready after children)
	# still receives the initial state instead of silently missing it.
	_emit_state_signals.call_deferred()


func _exit_tree() -> void:
	# Leaving the tree mid-orbit must not strand the player with a captured cursor.
	_end_orbit()


func _notification(what: int) -> void:
	# Alt-tabbing away while the middle button is held would otherwise never deliver the release
	# event, leaving the mouse captured and the game unusable.
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and _orbiting:
		_end_orbit()


func _input(event: InputEvent) -> void:
	# Release is handled here rather than in _unhandled_input: if the pointer ends up over a
	# Control that eats the event, we would never learn the button came back up.
	if _orbiting and _has_orbit_action and event.is_action_released(_ORBIT_ACTION):
		_end_orbit()
		return

	# Only read motion ourselves when InputManager does not already accumulate it for us,
	# otherwise the same pixels would be applied twice.
	if _orbiting and not _has_orbit_delta_api and event is InputEventMouseMotion:
		_pending_orbit_pixels += (event as InputEventMouseMotion).relative.x


func _unhandled_input(event: InputEvent) -> void:
	# Starting an orbit goes through _unhandled_input so UI panels can claim the click first.
	if not _orbiting and _has_orbit_action and event.is_action_pressed(_ORBIT_ACTION):
		_begin_orbit()


func _process(delta: float) -> void:
	_apply_zoom_input(delta)
	_apply_orbit_input()
	_update_anchor(delta)

	# Exponential decay: the fraction of the remaining gap closed per second is constant, so the
	# motion looks identical at 30 and 240 fps (a plain lerp with delta does not have this property).
	var blend: float = 1.0 - exp(-maxf(0.0, zoom_smoothing) * delta)
	_distance = lerpf(_distance, _requested_distance, blend)
	if absf(_requested_distance - _distance) < _DISTANCE_EPSILON:
		_distance = _requested_distance

	_apply_placement()
	_emit_state_signals()


## Drags the follow anchor toward the player, but only once the player has left the dead zone.
##
## Horizontal only: the vertical always tracks, so a future slope or a fall moves the camera with the
## character, while the dead zone that stops per-step lurching lives purely in the ground plane. While
## the player is inside the radius the anchor does not move at all - that stillness IS the feature.
## The moment the player crosses the edge, the anchor eases toward the point that would place the
## player back exactly on the edge, so the camera trails at the rim of the dead zone rather than
## snapping to centre the player.
func _update_anchor(delta: float) -> void:
	if _anchor == null or not is_instance_valid(_target):
		return
	var target_pos: Vector3 = _target.global_position
	var anchor_pos: Vector3 = _anchor.global_position
	# Vertical tracks immediately.
	anchor_pos.y = target_pos.y

	var flat := Vector2(target_pos.x - anchor_pos.x, target_pos.z - anchor_pos.z)
	var slack: float = flat.length() - follow_dead_zone
	if slack > 0.0:
		# How far the anchor must move to sit `follow_dead_zone` behind the player: the overshoot past
		# the rim, along the direction to the player.
		var pull: Vector2 = flat.normalized() * slack
		var blend: float = 1.0 - exp(-follow_catch_up * delta)
		anchor_pos.x += pull.x * blend
		anchor_pos.z += pull.y * blend

	_anchor.global_position = anchor_pos


#region Public API

## Points the rig at a new node. Passing null is legal: the rig simply stops updating and holds
## its last pose rather than erroring every frame.
func set_target(n: Node3D) -> void:
	if _target == n:
		return
	_target = n
	# Snap the anchor onto the new target so a fresh level or a possession does not begin with the
	# camera lazily trailing in from wherever the last one stood.
	if _anchor != null and is_instance_valid(n):
		_anchor.global_position = n.global_position
	# The camera follows and aims at the ANCHOR, never the player directly. That indirection is the
	# dead zone: the player can move inside it while the anchor - and therefore the view - stays put.
	if is_instance_valid(_pcam):
		_pcam.set_follow_target(_anchor)
		_pcam.set_look_at_target(_anchor)
	_apply_placement()


func get_target() -> Node3D:
	return _target


## Current orbit yaw in degrees, wrapped to [0, 360).
func get_yaw() -> float:
	return _yaw_deg


## Current smoothed distance from the pivot in metres. This is the live value, not the value the
## zoom is heading towards.
func get_distance() -> float:
	return _distance


func is_orbiting() -> bool:
	return _orbiting


## The Camera3D this rig owns, or null if it could not be built.
func get_camera() -> Camera3D:
	return _camera


func set_yaw(deg: float) -> void:
	_yaw_deg = wrapf(deg, 0.0, 360.0)
	_apply_placement()


## Requests a distance; the rig eases towards it instead of snapping.
func set_distance(m: float) -> void:
	_requested_distance = clampf(m, min_distance, max_distance)

#endregion


#region Rig construction

func _build_rig() -> void:
	_camera = Camera3D.new()
	_camera.name = &"Camera3D"
	_camera.fov = fov
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL if orthographic else Camera3D.PROJECTION_PERSPECTIVE
	# Far enough to keep a fully zoomed-out view of a large level inside the frustum.
	_camera.far = 500.0
	add_child(_camera)
	_camera.make_current()

	if not _is_phantom_camera_available():
		# No addon (bare test scene, or the autoload was removed): the rig still works, it just
		# drives the Camera3D directly. A camera module must never take the whole game down.
		push_warning("CameraRig: PhantomCamera not available, driving Camera3D directly.")
		return

	var host: Node = _instantiate_by_class(&"PhantomCameraHost")
	if host == null:
		push_warning("CameraRig: PhantomCameraHost could not be instantiated, driving Camera3D directly.")
		return
	host.name = &"PhantomCameraHost"
	# The host must be a CHILD of the Camera3D - that is how it discovers which camera to drive.
	_camera.add_child(host)

	var pcam: Node = _instantiate_by_class(&"PhantomCamera3D")
	if pcam == null:
		push_warning("CameraRig: PhantomCamera3D could not be instantiated, driving Camera3D directly.")
		return
	pcam.name = &"PhantomCamera3D"

	# ORDER IS LOAD-BEARING. PhantomCamera3D.set_follow_target() and set_look_at_target() both
	# early-return while their respective mode is NONE, so assigning a target before its mode
	# silently does nothing. A missing look_at target is the known cause of a black screen in this
	# project: the camera is positioned correctly but is left aiming at nothing.
	pcam.follow_mode = _PCAM_FOLLOW_MODE_SIMPLE
	pcam.look_at_mode = _PCAM_LOOK_AT_MODE_SIMPLE
	# Positional damping stays off: this rig already smooths its own zoom, and a second smoothing
	# pass on top would make the camera lag behind the player during normal movement.
	pcam.follow_damping = false
	pcam.priority = 10

	add_child(pcam)
	_pcam = pcam as Node3D


func _is_phantom_camera_available() -> bool:
	# The addon's nodes reach for this autoload in _enter_tree() and error out without it, so
	# check before building anything rather than after.
	return get_tree() != null and get_tree().root.has_node(NodePath(_PCAM_MANAGER_NAME))


## Instantiates an addon class by name without a hard dependency, so this file still parses and
## runs in a checkout where the addon is absent.
func _instantiate_by_class(class_name_hint: StringName) -> Node:
	if not ClassDB.class_exists(class_name_hint):
		# Script classes registered via class_name live in the global script class table.
		var global_classes: Array = ProjectSettings.get_global_class_list()
		for entry in global_classes:
			if not entry is Dictionary:
				continue
			if (entry as Dictionary).get("class", "") != String(class_name_hint):
				continue
			var script_path: String = str((entry as Dictionary).get("path", ""))
			if script_path.is_empty() or not ResourceLoader.exists(script_path):
				return null
			var script: Script = load(script_path) as Script
			if script == null:
				return null
			return script.new() as Node
		return null
	return ClassDB.instantiate(class_name_hint) as Node


func _resolve_target_from_path() -> void:
	if target_path.is_empty():
		return
	var n: Node = get_node_or_null(target_path)
	if n == null:
		push_warning("CameraRig: target_path '%s' does not resolve to a node." % String(target_path))
		return
	var n3d: Node3D = n as Node3D
	if n3d == null:
		push_warning("CameraRig: target_path '%s' is not a Node3D." % String(target_path))
		return
	set_target(n3d)

#endregion


#region Input

func _apply_zoom_input(delta: float) -> void:
	var notches: float = 0.0

	if _has_zoom_step_api:
		# Positive means "zoom in" (get closer), matching the camera_zoom_in action name.
		# Type-checked rather than blindly cast: InputManager is authored by another module and a
		# null or non-numeric return must degrade to "no zoom this frame", not throw every frame.
		var step: Variant = _input_manager.call(&"get_zoom_step")
		if step is float or step is int:
			notches = float(step)
	elif _has_zoom_actions:
		# Discrete part: one notch per wheel click or key tap.
		if Input.is_action_just_pressed(_ZOOM_IN_ACTION):
			notches += 1.0
		if Input.is_action_just_pressed(_ZOOM_OUT_ACTION):
			notches -= 1.0
		# Continuous part: holding + or - keeps zooming. The just_pressed frame is excluded so a
		# tap is worth exactly one notch, and so a mouse wheel - which is only ever "pressed" on
		# the frame it fires - can never reach this branch and get counted twice.
		if Input.is_action_pressed(_ZOOM_IN_ACTION) and not Input.is_action_just_pressed(_ZOOM_IN_ACTION):
			notches += zoom_hold_rate * delta
		if Input.is_action_pressed(_ZOOM_OUT_ACTION) and not Input.is_action_just_pressed(_ZOOM_OUT_ACTION):
			notches -= zoom_hold_rate * delta

	if is_zero_approx(notches):
		return

	# Zooming IN reduces the distance, hence the subtraction.
	_requested_distance = clampf(_requested_distance - notches * zoom_step, min_distance, max_distance)


func _apply_orbit_input() -> void:
	if not _orbiting:
		return

	var pixels: float = _pending_orbit_pixels
	_pending_orbit_pixels = 0.0

	if _has_orbit_delta_api:
		# consume_orbit_delta() is destructive by contract, so it is called exactly once a frame.
		var d: Variant = _input_manager.call(&"consume_orbit_delta")
		if d is Vector2:
			pixels = (d as Vector2).x
		elif d is float or d is int:
			pixels = float(d)

	if is_zero_approx(pixels):
		return

	# Dragging right swings the camera to the right around the target. Negated because a positive
	# yaw is a counter-clockwise turn seen from above, which moves the camera left.
	var direction: float = 1.0 if orbit_invert else -1.0
	_yaw_deg = wrapf(_yaw_deg + pixels * orbit_sensitivity * direction, 0.0, 360.0)
	# Pitch is deliberately untouched by orbiting: dragging turns the camera AROUND the player, it
	# does not tilt it. Tilting is a setting (pitch_deg), not a gesture.


func _begin_orbit() -> void:
	if _orbiting:
		return
	_orbiting = true
	_pending_orbit_pixels = 0.0
	# Drop whatever InputManager buffered while we were not orbiting, so the first frame of the
	# drag does not snap the camera by however far the mouse happened to travel beforehand.
	if _has_orbit_delta_api:
		_input_manager.call(&"consume_orbit_delta")
	_mouse_mode_before_orbit = Input.mouse_mode
	# CAPTURED rather than CONFINED for two reasons. First, a confined cursor stops producing
	# relative motion once it reaches a window edge, which would cut an orbit short mid-drag;
	# captured motion is unbounded, so the player can spin the camera as far as they like.
	# Second, the OS restores the cursor to where it was captured when the mode is released,
	# which matters because this game uses click-to-move: the pointer must come back exactly
	# where the player left it, not jump to the screen centre.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _end_orbit() -> void:
	if not _orbiting:
		return
	_orbiting = false
	_pending_orbit_pixels = 0.0
	# Restoring the previous mode instead of hardcoding VISIBLE keeps the rig compatible with any
	# other system that had its own reason to change the cursor mode.
	Input.mouse_mode = _mouse_mode_before_orbit

#endregion


#region Placement

## Places the camera on a circle around the pivot.
##
## Coordinate system (Godot, right-handed, Y up, cameras look down their local -Z):
##   pivot     = target origin raised by pivot_height
##   horizontal = distance * cos(PITCH)   - ground-plane radius
##   vertical   = distance * sin(PITCH)   - height above the pivot
##   offset     = (sin(yaw) * horizontal, vertical, cos(yaw) * horizontal)
##
## At yaw 0 the offset is (0, vertical, horizontal): the camera sits on +Z and therefore looks
## towards -Z, Godot's default forward. Increasing yaw walks the camera counter-clockwise as seen
## from above, and matches the Y euler angle a node would need to face the same way - which is why
## get_yaw() can be fed straight into the sprite's facing lookup.
##
## The angle below the horizon works out to atan(vertical / horizontal) = atan(tan(pitch_deg)) =
## pitch_deg exactly, for every distance and yaw. That identity only holds because the offset is
## measured from the RAISED pivot and the camera aims at that same raised pivot; offsetting from
## the target origin while aiming higher up would quietly flatten the pitch as the player zooms.
func _apply_placement() -> void:
	if not is_instance_valid(_target):
		return

	var pitch: float = deg_to_rad(pitch_deg)
	var yaw: float = deg_to_rad(_yaw_deg)
	var horizontal: float = _distance * cos(pitch)
	var vertical: float = _distance * sin(pitch)

	var pivot: Vector3 = Vector3(0.0, pivot_height, 0.0)
	var offset: Vector3 = pivot + Vector3(sin(yaw) * horizontal, vertical, cos(yaw) * horizontal)

	# Everything is measured from the ANCHOR, which trails the player through the dead zone, so the
	# whole rig (orbit, zoom, aim) centres on the held point rather than on the player's every step.
	var centre: Vector3 = _anchor.global_position if is_instance_valid(_anchor) else _target.global_position
	if is_instance_valid(_pcam):
		# Both offsets are plain world-space additions to the follow target's (the anchor's) position,
		# so the camera lands on pivot + orbit vector while aiming at the pivot itself.
		_pcam.set_follow_offset(offset)
		_pcam.set_look_at_offset(pivot)
	elif is_instance_valid(_camera):
		# Fallback path used when the addon is unavailable.
		var pivot_world: Vector3 = centre + pivot
		_camera.global_position = centre + offset
		_camera.look_at(pivot_world, Vector3.UP)

	_apply_projection()


func _apply_projection() -> void:
	if not is_instance_valid(_camera):
		return
	if orthographic:
		_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		# Match the vertical extent a perspective camera would see at this distance, so switching
		# projections reframes nothing and distance keeps behaving like zoom.
		_camera.size = 2.0 * _distance * tan(deg_to_rad(fov) * 0.5)
	else:
		_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		_camera.fov = fov


func _emit_state_signals() -> void:
	if is_nan(_last_signalled_yaw) or absf(_yaw_deg - _last_signalled_yaw) > _YAW_EPSILON:
		_last_signalled_yaw = _yaw_deg
		yaw_changed.emit(_yaw_deg)
	if is_nan(_last_signalled_distance) or absf(_distance - _last_signalled_distance) > _DISTANCE_EPSILON:
		_last_signalled_distance = _distance
		distance_changed.emit(_distance)

#endregion
