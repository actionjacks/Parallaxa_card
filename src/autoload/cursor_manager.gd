extends Node

## Owns the mouse cursor for the whole game. The project must never show an OS cursor.
##
## Design notes (why it looks like this):
##
## 1. Replacing the default arrow is not enough. Godot substitutes cursor shapes on its own:
##    `Control.mouse_default_cursor_shape` swaps to `CURSOR_POINTING_HAND` over a button,
##    `LineEdit` asks for `CURSOR_IBEAM`, a `SplitContainer` asks for `CURSOR_HSIZE`, and the
##    drag-and-drop machinery forces `CURSOR_FORBIDDEN` / `CURSOR_CAN_DROP` while a payload is held.
##    Every shape the engine can pick has its own texture slot; a slot we do not fill is drawn by the
##    operating system. That is the flicker of native cursors this manager exists to remove, so we
##    fill the whole `BUILTIN_SHAPE_MAP` table, not just the arrow.
## 2. Hotspots are data, not magic numbers, and they are NOT (0, 0). The authored PNGs are 32x32 with
##    roughly 6 px of transparent padding around the art, so the arrow's visual tip sits at pixel
##    (6, 6). Feeding (0, 0) would put the click point 6 px up-left of the drawn tip - the classic
##    "it clicked next to what I pointed at" bug. Hotspots are stored normalized (0..1) so a re-export
##    at 64x64 keeps working: the padding scales with the art, a pixel offset would not.
## 3. Loading is lazy and cached, with one deliberate exception. `apply()` pulls textures through
##    `_get_texture()`, which loads a shape at most once, ever. The arrow is loaded synchronously in
##    `_ready()` because it must be on screen before the first frame; the rest of the built-in table is
##    installed one idle frame later. Those shapes can only be triggered by user input, which cannot
##    happen before the first frame is presented - so deferring costs nothing and never exposes an OS
##    cursor. Installing them lazily "when needed" would not work at all: by the time we noticed the
##    engine wanting `CURSOR_IBEAM`, it would already have drawn the system one.
## 4. A missing file warns once per shape and keeps the cursor that is already on screen. Falling back
##    to the system cursor would produce exactly the look this manager is here to prevent, and a
##    warning per frame from a hovered control would bury the rest of the log.
## 5. `push()` / `pop()` exist because modes nest. Camera orbit sets ROTATE while held; if an inventory
##    drag starts under it and ends with `reset()`, a plain apply/reset pair leaves the orbit showing an
##    arrow - the outer mode has been silently overwritten and has no way to know. With a stack each
##    mode restores what it found, so no mode needs to know what ran before it or how deep it sits.

enum CursorShape {
	ARROW,
	POINTING_HAND,
	GRAB,
	ROTATE,
	ROTATE_AXIS,
	FORBIDDEN,
}

const CURSOR_DIR: String = "res://assets/ui/cursors/"

## Shape -> file. Every entry is a 32x32 PNG authored for this project; there is no system fallback.
const SHAPE_FILES: Dictionary = {
	CursorShape.ARROW: "arrow.png",
	CursorShape.POINTING_HAND: "pointing_hand.png",
	CursorShape.GRAB: "grab.png",
	CursorShape.ROTATE: "rotate.png",
	CursorShape.ROTATE_AXIS: "rotate_axis.png",
	CursorShape.FORBIDDEN: "forbidden.png",
}

## Click point per shape, normalized to texture size (see header note 2). Values come from the alpha
## bounds of the authored art, not from taste:
##  - ARROW          art starts at pixel (6, 6); that corner IS the tip.
##  - POINTING_HAND  topmost opaque row spans x 11..15 at y 6; the fingertip is its middle, (13, 6).
##  - GRAB           a fist has no tip - the grabbed point is the middle of the palm.
##  - ROTATE / ROTATE_AXIS / FORBIDDEN  radially symmetric glyphs; anything but the centre would make
##    the cursor appear to orbit its own click point while it is being drawn.
const SHAPE_HOTSPOTS: Dictionary = {
	CursorShape.ARROW: Vector2(6.0 / 32.0, 6.0 / 32.0),
	CursorShape.POINTING_HAND: Vector2(13.0 / 32.0, 6.0 / 32.0),
	CursorShape.GRAB: Vector2(0.5, 0.5),
	CursorShape.ROTATE: Vector2(0.5, 0.5),
	CursorShape.ROTATE_AXIS: Vector2(0.5, 0.5),
	CursorShape.FORBIDDEN: Vector2(0.5, 0.5),
}

## Every `Input.CURSOR_*` the engine can substitute on its own, mapped to one of our six shapes.
## We have six drawings and Godot has seventeen slots, so some slots share art. The reasoning:
##  - IBEAM, CROSS, WAIT, BUSY -> ARROW. We have no caret, crosshair or spinner art. The arrow's tip is
##    precise enough to place a text caret, and `Input` cannot animate a busy cursor anyway. Showing our
##    arrow is strictly better than dropping to the OS I-beam or the native hourglass.
##  - DRAG -> GRAB: the hand is closed because something is being carried.
##  - CAN_DROP -> POINTING_HAND and FORBIDDEN -> FORBIDDEN: these two are a pair. While dragging, the
##    cursor answers one question - is this a legal target? The open hand says yes, the barred circle
##    says no. Reusing GRAB for CAN_DROP would make the answer identical to "still carrying".
##  - MOVE -> ROTATE: free two-axis dragging, same affordance as the free rotation glyph.
##  - VSIZE, HSIZE, BDIAGSIZE, FDIAGSIZE, VSPLIT, HSPLIT -> ROTATE_AXIS: axis-constrained dragging gets
##    the axis-constrained glyph, and its centred hotspot is what a resize grip needs.
##  - HELP -> POINTING_HAND: an informational hover is the same affordance as a link.
const BUILTIN_SHAPE_MAP: Dictionary = {
	Input.CURSOR_ARROW: CursorShape.ARROW,
	Input.CURSOR_IBEAM: CursorShape.ARROW,
	Input.CURSOR_CROSS: CursorShape.ARROW,
	Input.CURSOR_WAIT: CursorShape.ARROW,
	Input.CURSOR_BUSY: CursorShape.ARROW,
	Input.CURSOR_POINTING_HAND: CursorShape.POINTING_HAND,
	Input.CURSOR_HELP: CursorShape.POINTING_HAND,
	Input.CURSOR_CAN_DROP: CursorShape.POINTING_HAND,
	Input.CURSOR_DRAG: CursorShape.GRAB,
	Input.CURSOR_FORBIDDEN: CursorShape.FORBIDDEN,
	Input.CURSOR_MOVE: CursorShape.ROTATE,
	Input.CURSOR_VSIZE: CursorShape.ROTATE_AXIS,
	Input.CURSOR_HSIZE: CursorShape.ROTATE_AXIS,
	Input.CURSOR_BDIAGSIZE: CursorShape.ROTATE_AXIS,
	Input.CURSOR_FDIAGSIZE: CursorShape.ROTATE_AXIS,
	Input.CURSOR_VSPLIT: CursorShape.ROTATE_AXIS,
	Input.CURSOR_HSPLIT: CursorShape.ROTATE_AXIS,
}

## Loaded textures, one entry per shape. A shape that failed to load is never cached, so a file added
## during a hot-reload can still come up on the next request.
var _textures: Dictionary[int, Texture2D] = {}

## Shapes we already complained about, so the warning fires once and not once per hover (note 4).
var _warned_shapes: Dictionary[int, bool] = {}

## The shape currently drawn as the ambient cursor.
var _current: CursorShape = CursorShape.ARROW

## Saved shapes for nested modes (note 5). Only `push()` writes here.
var _stack: Array[CursorShape] = []


func _ready() -> void:
	# Highest priority: get our arrow up before the player can see the system one.
	_set_ambient(CursorShape.ARROW)
	# The rest of the table cannot be reached without input, so it can wait a frame (note 3).
	_install_builtin_overrides.call_deferred()
	# Applying a video setting can recreate the native window, and the new one comes up with the
	# system cursor class - so every applied change has to reinstall ours. Wired from THIS side:
	# CursorManager sits after Settings in the autoload order and may depend on it; the reverse
	# would invert the contract. Looked up by node rather than by name so a project without the
	# Settings autoload still boots.
	var settings: Node = get_node_or_null(^"/root/Settings")
	if settings != null and settings.has_signal(&"applied"):
		settings.applied.connect(reapply)


## Draws `shape` as the ambient cursor, replacing whatever is there. Use this for a mode that owns the
## cursor outright; use `push()` when the mode can be entered on top of another one.
func apply(shape: CursorShape) -> void:
	_set_ambient(shape)


## Returns to the arrow and drops any saved shapes. This is the hard reset for "no mode is active" -
## a mode that only wants to undo itself should call `pop()` instead, or it will strip its callers.
func reset() -> void:
	_stack.clear()
	_set_ambient(CursorShape.ARROW)


## Enters a nested mode: remembers the current shape, then draws `shape`.
func push(shape: CursorShape) -> void:
	# Recorded before the swap and regardless of whether it succeeds, so `pop()` stays balanced with
	# `push()` even when the texture is missing and the swap was a no-op.
	_stack.push_back(_current)
	_set_ambient(shape)


## Leaves the innermost mode and restores the shape that was drawn when it was entered.
func pop() -> void:
	if _stack.is_empty():
		# Unbalanced pop - a caller popped a mode it never pushed. The arrow is the safe floor.
		_set_ambient(CursorShape.ARROW)
		return
	_set_ambient(_stack.pop_back())


## Reinstalls every cursor slot. Call after a resolution or window-mode change.
##
## This is not superstition: `Input.set_custom_mouse_cursor()` binds the image to the native window, and
## Windows and some X11/Wayland setups recreate that window when the mode changes (windowed <-> exclusive
## fullscreen in particular). The recreated window comes up with the system cursor class and the game
## silently reverts to the OS arrow until something sets it again. Textures come from the cache, so this
## is cheap enough to call on every `Settings.applied`.
func reapply() -> void:
	_set_ambient(_current)
	_install_builtin_overrides()


## The shape currently drawn, for callers that need to branch on it (debug overlays, tests).
func get_current_shape() -> CursorShape:
	return _current


## Fills every engine-substituted slot listed in `BUILTIN_SHAPE_MAP` (note 1).
func _install_builtin_overrides() -> void:
	for builtin: int in BUILTIN_SHAPE_MAP:
		_bind(BUILTIN_SHAPE_MAP[builtin], builtin)


## Draws `shape` as the ambient cursor by overwriting the arrow slot - the slot Godot falls back to
## whenever no control asks for something specific. `_current` only advances on success, so a failed
## load leaves both the screen and our idea of the screen on the previous shape.
func _set_ambient(shape: CursorShape) -> void:
	if _bind(shape, Input.CURSOR_ARROW):
		_current = shape


## Binds one shape's texture to one engine slot. Returns false when the texture is unavailable, having
## touched nothing - the cursor already on screen stays (note 4).
func _bind(shape: CursorShape, builtin: int) -> bool:
	var texture: Texture2D = _get_texture(shape)
	if texture == null:
		return false
	Input.set_custom_mouse_cursor(texture, builtin, _get_hotspot(shape, texture))
	return true


## Loads a shape's texture, cached. Returns null and warns once when the file is missing or is not a
## texture, which is a normal state while art is being reworked.
func _get_texture(shape: CursorShape) -> Texture2D:
	if _textures.has(shape):
		return _textures[shape]

	var file_name: String = SHAPE_FILES[shape] if SHAPE_FILES.has(shape) else ""
	var path: String = CURSOR_DIR + file_name
	var texture: Texture2D = null
	if not file_name.is_empty() and ResourceLoader.exists(path):
		texture = ResourceLoader.load(path) as Texture2D

	if texture == null:
		# Not cached: an import that completes later should still be picked up.
		if not _warned_shapes.has(shape):
			_warned_shapes[shape] = true
			push_warning("CursorManager: cursor texture unavailable for shape %d (%s); keeping the current cursor." % [shape, path])
		return null

	_textures[shape] = texture
	return texture


## Converts the normalized hotspot to pixels for this texture's actual size (note 2). Shapes with no
## entry default to the top-left, which is only correct for an arrow - but an unlisted shape is a bug
## in the table above, not a case worth inventing a centre for.
func _get_hotspot(shape: CursorShape, texture: Texture2D) -> Vector2:
	var normalized: Vector2 = SHAPE_HOTSPOTS.get(shape, Vector2.ZERO)
	return (normalized * texture.get_size()).round()
