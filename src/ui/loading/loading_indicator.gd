class_name LoadingIndicator
extends Control

# Subtle bottom-right loading indicator built around the symbolism of the number 3:
# three arcs spaced 120 degrees apart, three vertex dots lit in sequence, and a closed
# triangular ring once progress reaches 1.0.
#
# Design decisions worth explaining:
#
# * Everything is vector-drawn in `_draw()` with antialiased arcs. No textures, no shaders,
#   no child nodes for geometry. The project renders at a low internal resolution and scales up;
#   a texture-based spinner would either alias or force us to ship several sizes. Arcs stay crisp
#   at any scale and cost a handful of draw calls.
#
# * Arc motion is a global spin plus a per-arc angular OFFSET that is integrated and wrapped into
#   (-PI, PI]. Wrapping is invisible because a full turn added to an angle draws identically, and it
#   keeps the offsets bounded no matter how long a load takes. Convergence then damps those offsets
#   toward zero with `move_toward` (shortest path, since the wrapped value is already the short
#   representation) while arc spans widen to exactly 120 degrees. At progress 1.0 the three arcs meet
#   precisely at the three dots. The naive alternative — scaling an ever-growing free-running phase by
#   (1 - progress) — makes the ring snap violently whenever progress jumps, because the residual term
#   grows without bound with elapsed time.
#
# * The appear/disappear animation is integrated by hand instead of using a Tween. The node lives on
#   SceneTransition's CanvasLayer and must animate while the tree is paused (PROCESS_MODE_ALWAYS), and
#   show/hide can be re-requested mid-animation; hand-rolled easing has no tween lifetime to babysit
#   and reverses cleanly. The rise offset is applied inside `_draw()` rather than to `position`, so it
#   never fights the anchor-based layout.
#
# * `_process` disables itself once the loader is fully hidden, and `queue_redraw()` is only called
#   while something is actually on screen. An idle loader costs nothing.
#
# * The caption is optional and defensive: it is drawn only if a `Localization` autoload exists, has a
#   `t()` method, and returns something other than the raw key. A missing translation layer must never
#   put "LOADING_LABEL" on the player's screen.

# --- Public tuning (exposed so UI work does not require touching this script) -------------------

## Leading colour of the indicator. Project signature orange.
@export var accent_color: Color = Color("ff8a2b")

## Ring radius as a fraction of the control's shorter side.
@export_range(0.1, 0.5, 0.01) var radius_ratio: float = 0.30

## Stroke width of the three arcs, in pixels.
@export_range(1.0, 8.0, 0.1) var arc_width: float = 3.0

## Seconds to wait before anything becomes visible. Fast loads must never flash a spinner.
@export_range(0.0, 2.0, 0.05) var show_delay: float = 0.25

## Translation key for the caption under the ring. Empty disables the caption entirely.
@export var label_key: String = "LOADING_LABEL"

# --- Constants ---------------------------------------------------------------------------------

const FADE_IN_TIME := 0.30
const FADE_OUT_TIME := 0.22
const RISE_PIXELS := 8.0

const ARC_COUNT := 3
const ARC_BASE_SPAN := 0.66  # ~38 degrees, the open/indeterminate span of a single arc
const ARC_FULL_SPAN := TAU / 3.0  # kept literal: const expressions may not call float()
const ARC_SPAN_BREATH := 0.16  # relative span pulse while indeterminate

# Distinct angular drift per arc, in rad/s. The negative middle value makes one arc counter-rotate,
# which is what stops the motion from reading as a plain three-segment spinner.
const ARC_DRIFT: PackedFloat32Array = [0.85, -0.52, 1.28]
const ARC_BREATH_RATE: PackedFloat32Array = [0.77, 1.13, 0.53]

const SPIN_RATE_OPEN := 0.55   # rad/s of the whole ring while loading is early/indeterminate
const SPIN_RATE_CLOSED := 0.22 # rad/s once the triangle has closed
const CONVERGE_DAMP := 3.4     # rad/s at which per-arc offsets are pulled back to their home angle
const CONVERGE_START := 0.15   # progress below which no convergence happens at all

const PROGRESS_SMOOTHING := 7.0
const PROGRESS_SNAP := 0.002

const DOT_CYCLE := 1.35        # seconds for the lit dot to travel around all three vertices
const DOT_BASE_INTENSITY := 0.30
const DOT_RADIUS_MIN := 1.8
const DOT_RADIUS_MAX := 3.1

const GLOW_WIDTH_SCALE := 3.4
const GLOW_ALPHA := 0.12
const TRACK_ALPHA := 0.06
const PROGRESS_RING_RATIO := 0.60

const CAPTION_FONT_SIZE := 10
const CAPTION_GAP := 16.0

# --- State -------------------------------------------------------------------------------------

var _want_visible := false
var _delay_remaining := 0.0
var _appear := 0.0            # raw 0..1 appearance amount, eased at draw time

var _time := 0.0
var _spin := 0.0
var _arc_offset := PackedFloat32Array()

var _indeterminate := true
var _progress_target := 0.0
var _progress_shown := 0.0

var _caption := ""
var _localization: Node = null


func _ready() -> void:
	# The loader is owned by SceneTransition's CanvasLayer and has to keep animating while the
	# gameplay tree is paused during a load.
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE

	_arc_offset.resize(ARC_COUNT)
	for i: int in ARC_COUNT:
		# Seed each arc at a different point of its drift so the ring never starts perfectly closed.
		_arc_offset[i] = float(i) * 0.4 - 0.4

	_bind_localization()
	_refresh_caption()

	visible = false
	set_process(false)


func _exit_tree() -> void:
	_unbind_localization()


# --- Public API --------------------------------------------------------------------------------

## Request the loader on screen. When `animated` it waits `show_delay` seconds, then fades and
## rises into place; otherwise it appears instantly.
func show_loader(animated: bool = true) -> void:
	var was_hidden := not _want_visible and _appear <= 0.0
	_want_visible = true

	if was_hidden:
		# A fresh run must not inherit the closed ring left over from the previous load.
		_progress_shown = _progress_target

	if animated:
		# Only a cold start pays the delay; re-showing mid fade-out picks up where it is.
		_delay_remaining = show_delay if was_hidden else 0.0
	else:
		_delay_remaining = 0.0
		_appear = 1.0
		visible = true

	set_process(true)


## Request the loader off screen. When `animated` it fades out, otherwise it vanishes immediately.
func hide_loader(animated: bool = true) -> void:
	_want_visible = false
	_delay_remaining = 0.0

	if animated:
		set_process(true)
	else:
		_appear = 0.0
		visible = false
		set_process(false)


## Set load progress. `ratio` in 0..1 closes the triangle proportionally; a negative value
## (-1.0 by convention) switches to indeterminate mode: continuous rotation, no progress ring.
func set_progress(ratio: float) -> void:
	if is_nan(ratio) or ratio < 0.0:
		_indeterminate = true
		_progress_target = 0.0
		return

	_indeterminate = false
	_progress_target = clampf(ratio, 0.0, 1.0)


# --- Frame loop --------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_advance_appearance(delta)

	if _appear <= 0.0 and not _want_visible:
		# Fully hidden and nothing pending: stop burning CPU until someone asks for us again.
		visible = false
		set_process(false)
		return

	if _appear <= 0.0:
		# Still inside the show delay. Deliberately draws nothing at all.
		return

	visible = true
	_advance_motion(delta)
	queue_redraw()


func _advance_appearance(delta: float) -> void:
	if _want_visible:
		if _delay_remaining > 0.0:
			_delay_remaining -= delta
			return
		_appear = minf(1.0, _appear + delta / maxf(FADE_IN_TIME, 0.0001))
	else:
		_appear = maxf(0.0, _appear - delta / maxf(FADE_OUT_TIME, 0.0001))


func _advance_motion(delta: float) -> void:
	_time += delta

	if absf(_progress_shown - _progress_target) <= PROGRESS_SNAP:
		_progress_shown = _progress_target
	else:
		_progress_shown = lerpf(
			_progress_shown, _progress_target, 1.0 - exp(-PROGRESS_SMOOTHING * delta)
		)

	var converge := _convergence()

	_spin = wrapf(_spin + delta * lerpf(SPIN_RATE_OPEN, SPIN_RATE_CLOSED, converge), 0.0, TAU)

	for i: int in ARC_COUNT:
		var drift: float = ARC_DRIFT[i] * (1.0 - converge)
		# Wrapping keeps the offset bounded forever; a whole extra turn is visually identical.
		var offset := wrapf(_arc_offset[i] + delta * drift, -PI, PI)
		if converge > 0.0:
			offset = move_toward(offset, 0.0, delta * CONVERGE_DAMP * converge)
		_arc_offset[i] = offset


## 0 while the ring spins freely, 1 when the three arcs must form a closed triangle.
func _convergence() -> float:
	if _indeterminate:
		return 0.0
	return smoothstep(CONVERGE_START, 1.0, _progress_shown)


# --- Drawing -----------------------------------------------------------------------------------

func _draw() -> void:
	var alpha := _eased_appear()
	if alpha <= 0.0:
		return

	var radius := minf(size.x, size.y) * radius_ratio
	if radius <= 1.0:
		return

	var has_caption := not _caption.is_empty()
	var center := size * 0.5
	if has_caption:
		# Lift the ring so the caption has room without drifting off the control.
		center.y -= CAPTION_GAP * 0.5
	center.y += (1.0 - alpha) * RISE_PIXELS  # slide up into place as it fades in

	var converge := _convergence()

	_draw_track(center, radius, alpha)
	_draw_progress_ring(center, radius, alpha)
	_draw_arcs(center, radius, alpha, converge)
	_draw_dots(center, radius, alpha)

	if has_caption:
		_draw_caption(center, radius, alpha)


func _draw_track(center: Vector2, radius: float, alpha: float) -> void:
	# A barely-there full ring gives the arcs a path to travel along; without it the gaps read as
	# missing rather than as gaps.
	draw_arc(center, radius, 0.0, TAU, 72, _tint(TRACK_ALPHA * alpha), 1.0, true)


func _draw_progress_ring(center: Vector2, radius: float, alpha: float) -> void:
	if _indeterminate or _progress_shown <= 0.001:
		return

	var inner := radius * PROGRESS_RING_RATIO
	var sweep := _progress_shown * TAU
	var points := maxi(10, int(sweep / TAU * 64.0))
	draw_arc(center, inner, -PI * 0.5, -PI * 0.5 + sweep, points, _tint(0.32 * alpha), 1.6, true)


func _draw_arcs(center: Vector2, radius: float, alpha: float, converge: float) -> void:
	for i: int in ARC_COUNT:
		var home := _arc_home_angle(i)
		var mid: float = home + _spin + _arc_offset[i]

		var span := lerpf(ARC_BASE_SPAN, ARC_FULL_SPAN, converge)
		if converge < 1.0:
			var breath: float = sin(_time * ARC_BREATH_RATE[i] + float(i) * 2.1)
			span *= 1.0 + ARC_SPAN_BREATH * breath * (1.0 - converge)
		span = clampf(span, 0.05, ARC_FULL_SPAN)

		var from := mid - span * 0.5
		var to := mid + span * 0.5
		var points := maxi(8, int(span / TAU * 96.0))

		# Wide, faint arc underneath fakes a bloom without touching the environment glow settings,
		# which the pixel-art post chain would otherwise crush.
		draw_arc(
			center, radius, from, to, points,
			_tint(GLOW_ALPHA * alpha), arc_width * GLOW_WIDTH_SCALE, true
		)
		draw_arc(center, radius, from, to, points, _tint(alpha), arc_width, true)


func _draw_dots(center: Vector2, radius: float, alpha: float) -> void:
	for i: int in ARC_COUNT:
		var angle := _vertex_angle(i) + _spin
		var pos := center + Vector2(cos(angle), sin(angle)) * radius
		var intensity := _dot_intensity(i)

		var dot_radius := lerpf(DOT_RADIUS_MIN, DOT_RADIUS_MAX, intensity)
		draw_circle(pos, dot_radius * 2.6, _tint(0.10 * intensity * alpha), true, -1.0, true)
		draw_circle(pos, dot_radius, _tint(alpha * (0.45 + 0.55 * intensity)), true, -1.0, true)


func _draw_caption(center: Vector2, radius: float, alpha: float) -> void:
	var font := _caption_font()
	if font == null:
		return

	var baseline := Vector2(0.0, center.y + radius + CAPTION_GAP + float(CAPTION_FONT_SIZE) * 0.5)
	draw_string(
		font, baseline, _caption, HORIZONTAL_ALIGNMENT_CENTER, size.x,
		CAPTION_FONT_SIZE, _tint(0.55 * alpha)
	)


## Sequential pulse travelling across the three vertices, floored by how much progress is done so
## that a determinate load also reads as "one third / two thirds / complete".
func _dot_intensity(index: int) -> float:
	var phase := wrapf(_time / DOT_CYCLE - float(index) / float(ARC_COUNT), 0.0, 1.0)
	var pulse := pow(clampf(1.0 - phase * 2.2, 0.0, 1.0), 1.8)
	var lit := DOT_BASE_INTENSITY + pulse * 0.70

	if not _indeterminate:
		lit = maxf(lit, clampf(_progress_shown * float(ARC_COUNT) - float(index), 0.0, 1.0))

	return clampf(lit, 0.0, 1.0)


## Centre angle each arc returns to when the triangle closes: the arc spans vertex i to vertex i+1.
func _arc_home_angle(index: int) -> float:
	return _vertex_angle(index) + ARC_FULL_SPAN * 0.5


## Triangle vertices, first one pointing straight up.
func _vertex_angle(index: int) -> float:
	return -PI * 0.5 + ARC_FULL_SPAN * float(index)


func _eased_appear() -> float:
	# Ease-out cubic: quick to register, gentle to settle.
	var t := clampf(_appear, 0.0, 1.0)
	var inv := 1.0 - t
	return 1.0 - inv * inv * inv


func _tint(alpha: float) -> Color:
	return Color(accent_color.r, accent_color.g, accent_color.b, clampf(alpha, 0.0, 1.0))


func _caption_font() -> Font:
	if has_theme_font(&"font", &"Label"):
		return get_theme_font(&"font", &"Label")
	return ThemeDB.fallback_font


# --- Localization (optional dependency) --------------------------------------------------------

func _bind_localization() -> void:
	# Looked up by path, not by a hard reference: the loader has to work in an isolated test scene
	# and in a project where the Localization autoload has not been added yet.
	_localization = get_node_or_null(^"/root/Localization")
	if _localization == null:
		return

	if not _localization.has_signal(&"language_changed"):
		push_warning("LoadingIndicator: Localization has no 'language_changed' signal; the caption will not follow language changes.")
		return

	if not _localization.is_connected(&"language_changed", _on_language_changed):
		_localization.connect(&"language_changed", _on_language_changed)


func _unbind_localization() -> void:
	if is_instance_valid(_localization) and _localization.has_signal(&"language_changed"):
		if _localization.is_connected(&"language_changed", _on_language_changed):
			_localization.disconnect(&"language_changed", _on_language_changed)
	_localization = null


func _on_language_changed(_code: String) -> void:
	_refresh_caption()
	if visible:
		queue_redraw()


func _refresh_caption() -> void:
	_caption = ""

	if label_key.is_empty():
		return
	if not is_instance_valid(_localization) or not _localization.has_method(&"t"):
		return

	var translated: Variant = _localization.call(&"t", label_key)
	if typeof(translated) != TYPE_STRING:
		return

	var text: String = translated
	# An untranslated key comes back as the key itself. Showing "LOADING_LABEL" to a player is
	# worse than showing no caption at all.
	if text.is_empty() or text == label_key:
		return

	_caption = text
