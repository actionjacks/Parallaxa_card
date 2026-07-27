class_name SpreadScreen
extends Control
## The run's ending as a TAROT SPREAD laid on the table (docs/specs/spec_meta.md par.3): the Arcana
## you wore, your greatest blow rendered AS a card, the run's numbers and its seed -- a screen built
## to be screenshotted. One screen for both outcomes; run.gd mounts it and wires the signals.

signal new_run
signal repeat_run
signal to_menu

const CARD_W := 124.0
const CARD_H := 215.0

static func build(victory: bool, fresh_achievements: Array, progress: Dictionary = {}) -> SpreadScreen:
	var s := SpreadScreen.new()
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	s._build(victory, fresh_achievements, progress)
	return s

func _build(victory: bool, fresh: Array, progress: Dictionary = {}) -> void:
	var title := _lbl(tr("SPREAD_WIN") if victory else tr("SPREAD_LOSS"), 42,
		Color(0.95, 0.85, 0.5) if victory else Color(0.9, 0.4, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 18
	add_child(title)

	var sub_text := tr(RunState.region.name_key) if RunState.region != null else ""
	if RunState.veil > 0:
		sub_text += "  ·  " + tr("VEIL_BADGE") % RunState.veil
	if RunState.daily_tag != "":
		sub_text += "  ·  " + tr("DAILY_BADGE") % RunState.daily_tag
	elif RunState.pure_reading:
		sub_text += "  ·  " + tr("PURE_BADGE")
	var sub := _lbl(sub_text, 15, Color(0.6, 0.6, 0.68))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 68
	add_child(sub)

	# --- the Arcana you carried, physically fanned on the table ---
	var arc_label := _lbl(tr("SPREAD_ARCANA"), 16, Color(0.75, 0.65, 0.9))
	arc_label.position = Vector2(90, 104)
	add_child(arc_label)
	var relics: Array = RunState.relics
	var step := 92.0 if relics.size() <= 5 else 80.0
	var shown := 0
	for a: ArcanumData in relics:
		if shown >= 6:
			break
		var t := _card_tex(a.art, Vector2(CARD_W, CARD_H))
		t.position = Vector2(90 + shown * step, 138)
		t.rotation_degrees = -6.0 + shown * 3.0
		t.pivot_offset = Vector2(CARD_W * 0.5, CARD_H)
		if a.is_reversed:
			t.flip_h = true
			t.flip_v = true
			t.modulate = Color(1.0, 0.82, 0.84)
		t.tooltip_text = tr(a.name_key) + "\n" + a.describe()
		t.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(t)
		_enter_anim(t, shown)
		shown += 1
	if shown == 0:
		var fool := _card_tex(load("res://assets/cards/arcana/00_fool.jpg"), Vector2(CARD_W, CARD_H))
		fool.position = Vector2(90, 138)
		fool.modulate = Color(1, 1, 1, 0.4)
		add_child(fool)

	# On thin spreads (0-1 relics) the table closes ranks so the left half is not dead air.
	var xshift := -140.0 if shown <= 1 else 0.0

	# --- the greatest blow, rendered as its own card ---
	if RunState.stat_best_hit > 0:
		var hit := _panel(Color(0.1, 0.08, 0.12, 0.98), Color(0.9, 0.5, 0.3), 3, 6)
		hit.position = Vector2(668 + xshift, 126)
		hit.size = Vector2(200, 340)
		hit.rotation_degrees = 3.0
		hit.pivot_offset = Vector2(100, 170)
		var hv := VBoxContainer.new()
		hv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hv.alignment = BoxContainer.ALIGNMENT_CENTER
		hv.add_theme_constant_override("separation", 6)
		hit.add_child(hv)
		hv.add_child(_lbl_c(tr("SPREAD_HIT_TITLE"), 14, Color(0.7, 0.7, 0.78)))
		hv.add_child(_lbl_c(str(RunState.stat_best_hit), 68, Color(0.98, 0.8, 0.35)))
		hv.add_child(_lbl_c(tr(Poker.name_key(RunState.stat_best_hit_hand)), 16, Color(0.95, 0.9, 0.8)))
		var foe := _lbl_c(tr("SPREAD_HIT_FOE") % tr(RunState.stat_best_hit_foe), 14, Color(0.85, 0.6, 0.55))
		foe.autowrap_mode = TextServer.AUTOWRAP_WORD
		foe.custom_minimum_size = Vector2(168, 0)
		hv.add_child(foe)
		add_child(hit)
		_enter_anim(hit, 3)

	# --- the numbers ---
	var stats := _panel(Color(0.08, 0.08, 0.12, 0.9), Color(0.3, 0.3, 0.4), 1, 4)
	stats.position = Vector2(912 + xshift, 126)
	stats.size = Vector2(340, 340)
	var sv := VBoxContainer.new()
	sv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sv.add_theme_constant_override("separation", 8)
	stats.add_child(sv)
	# A death must be LEGIBLE (whose blow, which turn, by what) and must FUND something
	# concrete -- the two lines that turn a loss screen into "one more run".
	if not victory and RunState.stat_death_foe != "":
		var cause_key := "SPREAD_CAUSE_" + RunState.stat_death_cause.to_upper() if RunState.stat_death_cause != "" else "SPREAD_CAUSE_ATTACK"
		var doom := _lbl(tr("SPREAD_DEATH") % [tr(RunState.stat_death_foe), RunState.stat_death_turn, tr(cause_key)],
			14, Color(0.9, 0.5, 0.5))
		doom.autowrap_mode = TextServer.AUTOWRAP_WORD
		doom.custom_minimum_size = Vector2(300, 0)
		sv.add_child(doom)
	if not victory:
		var goal: Dictionary = Profile.nearest_goal()
		if not goal.is_empty():
			sv.add_child(_lbl(tr("SPREAD_GOAL") % [tr(goal["name_key"]), Profile.sol, int(goal["cost"])],
				14, Color(0.9, 0.85, 0.6)))
	var lv := int(RunState.hand_levels.get(RunState.stat_best_hand, 0)) + 1
	for line: String in [
		tr("SPREAD_BEST_HAND") % [tr(Poker.name_key(RunState.stat_best_hand)), lv],
		tr("SPREAD_REGIONS") % [RunState.stat_regions_cleared, 4],
		tr("SPREAD_FIGHTS") % RunState.fights_won,
		tr("SPREAD_DAMAGE") % RunState.stat_damage_total,
		tr("SPREAD_TURNS") % RunState.stat_turns_total,
		tr("SPREAD_SALT") % RunState.stat_sol_earned,
	]:
		sv.add_child(_lbl(line, 15, Color(0.78, 0.78, 0.85)))
	if RunState.depth > 0:
		sv.add_child(_lbl(tr("SPREAD_DEPTH") % RunState.depth, 15, Color(0.95, 0.6, 0.5)))
	# The tarocista's progress: run-end XP, and the fanfare line when a level fell.
	if int(progress.get("xp", 0)) > 0:
		sv.add_child(_lbl(tr("XP_GAINED") % int(progress["xp"]), 14, Color(0.72, 0.62, 0.85)))
	if int(progress.get("levels", 0)) > 0:
		sv.add_child(_lbl(tr("XP_LEVEL_UP") % [Profile.level, tr(Profile.rank_key())], 15, Color(0.95, 0.85, 0.5)))
	for id: String in fresh:
		sv.add_child(_lbl(tr("ACH_UNLOCKED") % tr(id), 14, Color(0.95, 0.85, 0.5)))
	add_child(stats)

	# --- the seed: click to copy, "the fate has a name" ---
	var seed_wrap := CenterContainer.new()
	seed_wrap.set_anchors_preset(Control.PRESET_TOP_WIDE)
	seed_wrap.offset_top = 540
	seed_wrap.custom_minimum_size = Vector2(0, 40)
	var seed_btn := Button.new()
	seed_btn.flat = true
	seed_btn.add_theme_font_size_override("font_size", 16)
	var seed_code := RunState.seed_text(RunState.run_seed)
	seed_btn.text = "* " + tr("SPREAD_SEED") % seed_code + "  ·  " + tr("SPREAD_SEED_HINT")
	seed_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	seed_btn.pressed.connect(func() -> void:
		# The share string markets the game by name wherever it gets pasted.
		DisplayServer.clipboard_set(tr("SHARE_FATE") % [seed_code, RunState.veil])
		seed_btn.text = tr("SPREAD_SEED_COPIED")
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			if is_instance_valid(seed_btn):
				seed_btn.text = "* " + tr("SPREAD_SEED") % seed_code + "  ·  " + tr("SPREAD_SEED_HINT")))
	seed_wrap.add_child(seed_btn)
	add_child(seed_wrap)

	# --- bottom-anchored controls: can never be pushed off 720p ---
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_top = -64
	row.offset_bottom = -20
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.add_child(_btn(tr("SPREAD_NEW"), func() -> void: new_run.emit()))
	row.add_child(_btn(tr("SPREAD_REPEAT"), func() -> void: repeat_run.emit()))
	row.add_child(_btn(tr("SPREAD_MENU"), func() -> void: to_menu.emit()))
	add_child(row)

func _enter_anim(node: Control, index: int) -> void:
	var target_a := node.modulate.a
	var target_y := node.position.y
	node.modulate.a = 0.0
	node.position.y = target_y + 20.0
	var tw := create_tween()
	if index > 0:
		tw.tween_interval(index * 0.06)
	tw.tween_property(node, "modulate:a", target_a, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(node, "position:y", target_y, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _card_tex(tex: Texture2D, size_v: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # BEFORE size (EXPAND_KEEP_SIZE trap)
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	t.texture = tex
	t.size = size_v
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func _panel(bg: Color, border: Color, bw: int, radius: int) -> Panel:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(bw)
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	for side in ["left", "top", "right", "bottom"]:
		sb.set("content_margin_" + side, 14)
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", sb)
	return p

func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(190, 40)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(cb)
	return b

func _lbl_c(text: String, font_size: int, color: Color) -> Label:
	var l := _lbl(text, font_size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _lbl(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
