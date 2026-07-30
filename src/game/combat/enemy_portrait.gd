class_name EnemyPortrait
extends Control
## The opponent, LOOMING. A full-height plate behind the arena instead of the old 116x201 chip,
## so the player fights a presence rather than a stat block.
##
## Why a BACKGROUND LAYER and not a child of the arena column: the middle column already grew
## past 720p three times in this project's history. A portrait big enough to matter would have
## pushed the hand off-screen again. As a backdrop it costs the layout ZERO vertical budget --
## the hand and buttons draw on top of it, and the enemy reads as standing behind the table.
##
## Animation is pure node transform + modulate (no shader): the hidden test screen runs on
## lavapipe software GL, where a per-pixel portrait shader would crawl.
##
## States: idle | windup | attack | hurt | enrage | die

const BREATH_PERIOD := 3.4       ## seconds per full inhale/exhale
const BREATH_AMPL := 0.012       ## scale swing -- alive, never seasick
const SWAY_PX := 5.0             ## horizontal drift, slower than the breath

var _plate: Control              ## the animated group: frame + art + wash
var _art: TextureRect
var _tint: ColorRect             ## state colour wash over the plate
var _vignette: ColorRect
var _frame: Panel
var _glyph: Label                ## fallback when an enemy ships no art
var _base_pos: Vector2
var _base_scale := Vector2.ONE
var _t := 0.0
var _state := "idle"
var _enrage := false
var _accent := Color(0.55, 0.2, 0.24)
var _react: Tween
var _atlas: AtlasTexture       ## the figure sheet's current cell
var _frames: int = 0           ## cells in the sheet (0 = no figure, fall back to the plate)
var _cell: Vector2 = Vector2.ZERO
var _frame_t := 0.0
var _frame_i := 0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _ready() -> void:
	_build()
	set_process(true)

func _build() -> void:
	# The plate: sized to dominate the frame while leaving the hand's strip readable. Anchored to
	# the top-centre so a taller screen grows the empty space, never the portrait's overlap.
	var plate := Control.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.size = Vector2(372, 644)
	plate.position = Vector2(640 - 186, 26)
	plate.pivot_offset = Vector2(186, 560)   # pivot low: breathing lifts the head, feet stay planted
	add_child(plate)
	_base_pos = plate.position
	_frame = Panel.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0.04, 0.03, 0.05, 0.55)
	fsb.set_border_width_all(2)
	fsb.border_color = Color(_accent, 0.75)
	fsb.set_corner_radius_all(4)
	_frame.add_theme_stylebox_override("panel", fsb)
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.set_meta("style", fsb)
	plate.add_child(_frame)
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE     # BEFORE size (EXPAND_KEEP_SIZE trap)
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.offset_left = 3
	_art.offset_top = 3
	_art.offset_right = -3
	_art.offset_bottom = -3
	# Dimmed and cooled on purpose: at full brightness a 372x644 scan out-shouts the hand and the
	# readouts printed over it. The opponent should loom out of the dark, not light the room.
	_art.modulate = Color(0.58, 0.54, 0.60, 0.72)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(_art)
	_glyph = Label.new()
	_glyph.add_theme_font_size_override("font_size", 128)
	_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph.visible = false
	plate.add_child(_glyph)
	# State wash: one ColorRect doing the work a shader would, at a fraction of the fill cost.
	_tint = ColorRect.new()
	_tint.color = Color(1, 0, 0, 0)
	_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(_tint)
	# Vignette sits OUTSIDE the plate: it darkens the arena's edges so the portrait reads as lit
	# from the table, and keeps the HUD legible over the art.
	_vignette = ColorRect.new()
	_vignette.color = Color(0.02, 0.02, 0.04, 0.42)
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)
	move_child(_vignette, 0)
	_plate = plate

func set_enemy(enemy: EnemyData, accent: Color = Color(0.55, 0.2, 0.24)) -> void:
	if _art == null:
		_build()
	_accent = accent
	var fsb: StyleBoxFlat = _frame.get_meta("style")
	fsb.border_color = Color(_accent, 0.75)
	_frames = 0
	_atlas = null
	if enemy != null and enemy.figure != null:
		# THE OPPONENT, not their card: the figure was cut out of the plate and animated
		# (tools/gen/gen_foe_figures.py). It keeps its own aspect ratio and stands in the room.
		_frames = maxi(1, enemy.figure_frames)
		var tex: Texture2D = enemy.figure
		_cell = Vector2(float(tex.get_width()) / float(_frames), float(tex.get_height()))
		_atlas = AtlasTexture.new()
		_atlas.atlas = tex
		_atlas.region = Rect2(0, 0, _cell.x, _cell.y)
		_art.texture = _atlas
		_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_art.flip_v = false
		_art.modulate = Color(0.86, 0.83, 0.88, 0.97)   # a figure needs far less dimming than a full plate
		_art.visible = true
		_glyph.visible = false
		_frame_i = 0
		_frame_t = 0.0
		# A frame frames a CARD. Once the opponent is a cut-out figure standing in the room,
		# the plate border reads as two stray rules floating either side of them.
		_frame.visible = false
	elif enemy != null and enemy.art != null:
		_frame.visible = true
		_art.texture = enemy.art
		_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_art.modulate = Color(0.58, 0.54, 0.60, 0.72)
		# Elites are REVERSED cards: the portrait hangs upside down, same as their card does.
		_art.flip_v = enemy.is_elite
		_art.visible = true
		_glyph.visible = false
	else:
		_art.visible = false
		_glyph.visible = true
		_glyph.text = "?"
	_state = "idle"
	_enrage = false
	_tint.color = Color(1, 0, 0, 0)
	if _plate != null:
		_plate.modulate = Color.WHITE

func set_enraged(on: bool) -> void:
	_enrage = on

## One call per dramatic beat. Reactions are short and never block the turn.
func play_state(state: String) -> void:
	if _plate == null:
		return
	_state = state
	if _react != null and _react.is_valid():
		_react.kill()
	match state:
		"windup":
			# the enemy gathers: leans back and dims, so the coming blow is FELT before it lands
			_react = create_tween().set_parallel()
			_react.tween_property(_plate, "scale", _base_scale * 0.965, 0.34).set_trans(Tween.TRANS_SINE)
			_react.tween_property(_tint, "color", Color(0.9, 0.55, 0.2, 0.14), 0.34)
		"attack":
			_react = create_tween()
			_react.tween_property(_plate, "scale", _base_scale * 1.075, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_react.parallel().tween_property(_tint, "color", Color(1.0, 0.35, 0.25, 0.28), 0.09)
			_react.tween_property(_plate, "scale", _base_scale, 0.26).set_trans(Tween.TRANS_SINE)
			_react.parallel().tween_property(_tint, "color", Color(1, 0, 0, 0), 0.26)
		"hurt":
			_react = create_tween()
			_react.tween_property(_tint, "color", Color(1.0, 0.95, 0.9, 0.42), 0.05)
			_react.tween_property(_tint, "color", Color(1, 0, 0, 0), 0.22)
			_shake(9.0)
		"enrage":
			_enrage = true
			_react = create_tween()
			_react.tween_property(_tint, "color", Color(1.0, 0.15, 0.12, 0.34), 0.16)
			_react.tween_property(_tint, "color", Color(1.0, 0.15, 0.12, 0.10), 0.44)
			_shake(6.0)
		"die":
			_react = create_tween().set_parallel()
			_react.tween_property(_plate, "modulate:a", 0.0, 0.75).set_trans(Tween.TRANS_SINE)
			_react.tween_property(_plate, "scale", _base_scale * 0.90, 0.75).set_trans(Tween.TRANS_SINE)
			_react.tween_property(_tint, "color", Color(0.1, 0.0, 0.15, 0.55), 0.75)
		_:
			_react = create_tween().set_parallel()
			_react.tween_property(_plate, "scale", _base_scale, 0.25)
			_react.tween_property(_tint, "color", Color(1, 0, 0, 0), 0.25)

func _shake(px: float) -> void:
	if Juice.reduce_motion():
		return
	var tw := create_tween()
	for i in 4:
		var d: float = px * (1.0 - float(i) / 4.0)
		tw.tween_property(_plate, "position", _base_pos + Vector2(d if i % 2 == 0 else -d, 0.0), 0.045)
	tw.tween_property(_plate, "position", _base_pos, 0.05)

func _process(delta: float) -> void:
	if _plate == null or _state == "die":
		return
	if Juice.reduce_motion():
		return
	_t += delta
	# Breath: the portrait is never perfectly still, which is the whole difference between a
	# picture of a monster and a monster. Enrage breathes faster and harder.
	var period: float = BREATH_PERIOD * (0.55 if _enrage else 1.0)
	var ampl: float = BREATH_AMPL * (1.9 if _enrage else 1.0)
	var b: float = sin(_t * TAU / period)
	if _react == null or not _react.is_valid():
		_plate.scale = _base_scale * (1.0 + b * ampl)
		_plate.position = _base_pos + Vector2(sin(_t * TAU / (period * 2.3)) * SWAY_PX, -b * 3.0)
	if _enrage:
		_tint.color = Color(1.0, 0.15, 0.12, 0.06 + 0.05 * (0.5 + 0.5 * b))
	# THE ENGRAVING FRAMERATE: the figure steps between carved poses instead of tweening
	# smoothly. Smooth motion reads as a photo with a filter; 10 steps a second reads as a
	# woodcut that has been persuaded to move. Enrage quickens the breath.
	if _frames > 1 and _atlas != null:
		_frame_t += delta * (16.0 if _enrage else 10.0)
		if _frame_t >= 1.0:
			_frame_t -= 1.0
			_frame_i = (_frame_i + 1) % _frames
			_atlas.region = Rect2(float(_frame_i) * _cell.x, 0.0, _cell.x, _cell.y)
