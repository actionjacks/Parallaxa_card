extends Control
## Vertical slice: a playable 1v1 duel. Poker hand -> Chips x Mult -> damage, on the
## parallaxa_orange theme (monogram font + custom cursors via CursorManager autoload).
## UI is built in code for the slice; scene authoring can come later.

signal finished(won: bool, remaining_hp: int)

const DEF_ENEMY_PATH := "res://data/combat/enemy_a.tres"
const DEF_ARCANUM_PATH := "res://data/arcana/arcanum_death.tres"

var standalone: bool = true
var _start_hp: int = -1
var _max_hp: int = -1

var controller: CombatController
var _deck: Array = []
var _enemy: EnemyData
var _relics: Array = []
var _selected: Array = []          ## selected CardData instances (not indices)

var _widgets: Dictionary = {}      ## CardData -> its card panel in the hand
var _log_lines: Array[String] = []

# Node refs
var _enemy_name: Label
var _enemy_hp_bar: ProgressBar
var _enemy_hp_label: Label
var _intent_label: Label
var _gnicie_label: Label
var _relic_row: HBoxContainer
var _enemy_emblem: Panel
var _emblem_glyph: Label
var _emblem_art: TextureRect
var _emblem_idle: Tween
var _rule_label: Label
var _preview_label: Label
var _log_label: Label
var _player_hp_bar: ProgressBar
var _player_hp_label: Label
var _block_label: Label
var _turn_label: Label
var _hand_row: HBoxContainer
var _play_btn: Button
var _discard_btn: Button
var _overlay: Control
var _overlay_label: Label
var _preview_extra: Label
var _breakdown_label: Label
var _counters_label: Label
var _help_label: Label
var _enemy_panel: PanelContainer
var _fx: Control
var _fx_index: int = 0
var _preview_node: Control = null
var _prev_intent: int = -999
var _prev_gnicie: int = 0

func setup(deck: Array, enemy: EnemyData, p_relics: Array, start_hp: int, max_hp: int) -> void:
	standalone = false
	_deck = deck
	_enemy = enemy
	_relics = p_relics
	_start_hp = start_hp
	_max_hp = max_hp

func _ready() -> void:
	if standalone:
		_enemy = load(DEF_ENEMY_PATH)
		_relics = [load(DEF_ARCANUM_PATH)]
		_deck = DeckLibrary.starter_deck()
	_build_ui()
	_start_emblem_idle()
	controller = CombatController.new()
	controller.state_changed.connect(_render)
	controller.message.connect(_on_message)
	controller.ended.connect(_on_ended)
	controller.awaiting_enemy.connect(_on_awaiting_enemy)
	controller.start(_deck, _enemy, _relics, _start_hp, _max_hp)

# ---------------------------------------------------------------- UI construction

func _build_ui() -> void:
	add_child(Backdrop.build())

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	# --- enemy panel ---
	_enemy_panel = _panel(Color(0.11, 0.07, 0.09), Color(0.5, 0.2, 0.24))
	var enemy_panel := _enemy_panel
	root.add_child(enemy_panel)
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 4)
	enemy_panel.add_child(ev)
	var erow := HBoxContainer.new()
	ev.add_child(erow)
	_enemy_name = _label("", 20, Color(0.95, 0.85, 0.85))
	_enemy_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	erow.add_child(_enemy_name)
	_intent_label = _label("", 20, Color(1.0, 0.55, 0.45))
	erow.add_child(_intent_label)
	var ehp := HBoxContainer.new()
	ehp.add_theme_constant_override("separation", 8)
	ev.add_child(ehp)
	_enemy_hp_bar = _bar(Color(0.8, 0.25, 0.28))
	ehp.add_child(_enemy_hp_bar)
	_enemy_hp_label = _label("", 16, Color(0.9, 0.9, 0.92))
	ehp.add_child(_enemy_hp_label)
	_gnicie_label = _label("", 14, Aspects.color(Aspects.Id.DEATH))
	ev.add_child(_gnicie_label)
	_rule_label = _label("", 15, Color(1.0, 0.7, 0.35))
	ev.add_child(_rule_label)

	# --- middle: relics + enemy emblem + score readout ---
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 8)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(mid)
	_relic_row = HBoxContainer.new()
	_relic_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_relic_row.add_theme_constant_override("separation", 8)
	mid.add_child(_relic_row)
	var emblem_wrap := CenterContainer.new()
	emblem_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(emblem_wrap)
	_enemy_emblem = _make_emblem()
	emblem_wrap.add_child(_enemy_emblem)
	_preview_label = _label("", 24, Color(0.98, 0.95, 0.8))
	_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_preview_label)
	_preview_extra = _label("", 16, Color(0.7, 0.85, 0.95))
	_preview_extra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_preview_extra)
	_breakdown_label = _label("", 13, Color(0.66, 0.72, 0.62))
	_breakdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_breakdown_label)
	_log_label = _label("", 13, Color(0.6, 0.6, 0.66))
	_log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_log_label)

	# --- player row ---
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 12)
	root.add_child(prow)
	_player_hp_bar = _bar(Color(0.35, 0.75, 0.45))
	_player_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prow.add_child(_player_hp_bar)
	_player_hp_label = _label("", 16, Color(0.9, 0.95, 0.9))
	prow.add_child(_player_hp_label)
	_block_label = _label("", 16, Color(0.6, 0.8, 1.0))
	prow.add_child(_block_label)
	_turn_label = _label("", 16, Color(0.8, 0.8, 0.85))
	prow.add_child(_turn_label)
	_counters_label = _label("", 16, Color(0.62, 0.66, 0.74))
	prow.add_child(_counters_label)

	# --- hand ---
	_hand_row = HBoxContainer.new()
	_hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_row.add_theme_constant_override("separation", 8)
	root.add_child(_hand_row)

	# --- controls ---
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 10)
	root.add_child(crow)
	_play_btn = Button.new()
	_play_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_play_btn.pressed.connect(_on_play)
	crow.add_child(_play_btn)
	_discard_btn = Button.new()
	_discard_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_discard_btn.pressed.connect(_on_discard)
	crow.add_child(_discard_btn)
	_help_label = _label(tr("COMBAT_HELP"), 13, Color(0.5, 0.5, 0.58))
	crow.add_child(_help_label)

	# The Fool stands on the player's side of the arena -- you ARE the card (Fool's Journey).
	var fool := TextureRect.new()
	# expand_mode BEFORE size: with the default EXPAND_KEEP_SIZE the texture inflates min size to
	# 296x512 the moment it is assigned, and a later .size set gets clamped to it.
	fool.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fool.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fool.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	fool.texture = load("res://assets/cards/arcana/00_fool.jpg")
	fool.position = Vector2(64, 330)
	fool.size = Vector2(82, 142)
	fool.tooltip_text = tr("FOOL_YOU")
	add_child(fool)

	_fx = Control.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)

	_build_overlay()

func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	_overlay.add_child(vb)
	_overlay_label = _label("", 48, Color(0.98, 0.95, 0.8))
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_overlay_label)
	var restart := Button.new()
	restart.text = tr("COMBAT_RESTART")
	restart.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	restart.pressed.connect(_on_restart)
	var wrap := CenterContainer.new()
	wrap.add_child(restart)
	vb.add_child(wrap)

# ---------------------------------------------------------------- rendering

func _render() -> void:
	_enemy_name.text = tr(_enemy.name_key)
	_enemy_hp_bar.max_value = _enemy.max_hp
	_set_bar(_enemy_hp_bar, controller.enemy_hp)
	_enemy_hp_label.text = tr("COMBAT_HP") % [controller.enemy_hp, _enemy.max_hp]
	var intent := controller.current_intent()
	_intent_label.text = tr("COMBAT_INTENT") % intent
	if _prev_intent != -999 and intent != _prev_intent:
		_pulse(_intent_label)
	_prev_intent = intent
	_gnicie_label.text = (tr("COMBAT_GNICIE") % controller.enemy_gnicie) if controller.enemy_gnicie > 0 else ""
	if controller.enemy_gnicie > _prev_gnicie:
		_pulse(_gnicie_label)
	_prev_gnicie = controller.enemy_gnicie
	for ch in _relic_row.get_children():
		ch.queue_free()
	for a in _relics:
		_relic_row.add_child(_relic_chip(a))
	var etint := Color(0.92, 0.5, 0.28) if _enemy.is_boss else Color(0.55, 0.7, 0.42)
	var esb: StyleBoxFlat = _enemy_emblem.get_meta("style")
	esb.border_color = etint
	if _enemy.art != null:
		# A real Major Arcana card stands in the arena (bosses ARE the card -- Fool's Journey).
		_emblem_art.texture = _enemy.art
		_emblem_art.visible = true
		_emblem_glyph.visible = false
		# Sized to fit the 720p layout budget -- taller art pushed the hand/buttons off-screen.
		_enemy_emblem.custom_minimum_size = Vector2(128, 222)
		_enemy_emblem.pivot_offset = Vector2(64, 111)
	else:
		_emblem_glyph.add_theme_color_override("font_color", etint)
		var en := tr(_enemy.name_key)
		_emblem_glyph.text = en.substr(0, 1) if en.length() > 0 else "?"
	_rule_label.text = tr(_enemy.rule_key) if (_enemy.is_boss and _enemy.rule_key != "") else ""
	_player_hp_bar.max_value = controller.player_max_hp
	_set_bar(_player_hp_bar, controller.player_hp)
	_player_hp_label.text = tr("COMBAT_HP") % [controller.player_hp, controller.player_max_hp]
	_block_label.text = tr("COMBAT_BLOCK") % controller.player_block
	_turn_label.text = tr("COMBAT_TURN") % controller.turn
	_counters_label.text = tr("COMBAT_PILES") % [controller.draw_count(), controller.grave_count()]
	_reconcile_hand()
	_update_selection_ui()

## Reconcile the hand instead of nuking it: keep existing widgets (keyed by the CardData instance),
## deal in freshly drawn cards, and reorder to match. Played/discarded widgets are flown out
## separately (see _on_play/_on_discard) so they animate away instead of vanishing.
func _reconcile_hand() -> void:
	var want: Array = controller.hand
	for card in _widgets.keys():
		if not want.has(card):
			_widgets.erase(card)   # already flying (played/discarded)
	for card in want:
		if not _widgets.has(card):
			var panel := _make_card(card)
			_hand_row.add_child(panel)
			_widgets[card] = panel
			_animate_draw(panel)
	for i in want.size():
		_hand_row.move_child(_widgets[want[i]], i)
	for card in _selected.duplicate():
		if not want.has(card):
			_selected.erase(card)
	_refresh_card_styles()

func _make_card(card: CardData) -> Control:
	var panel := CardWidget.build(card)
	panel.gui_input.connect(_on_card_input.bind(card))
	panel.mouse_entered.connect(_show_card_preview.bind(card))
	panel.mouse_exited.connect(_hide_card_preview)
	return panel

func _animate_draw(panel: Control) -> void:
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.82, 0.82)
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.20)
	tw.parallel().tween_property(panel, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _reset_hand() -> void:
	for ch in _hand_row.get_children():
		ch.queue_free()
	_widgets.clear()
	_selected.clear()

func _show_card_preview(card: CardData) -> void:
	_hide_card_preview()
	var p := CardWidget.build_preview(card)
	p.position = Vector2(1016, 118)
	_fx.add_child(p)
	_preview_node = p

func _hide_card_preview() -> void:
	if _preview_node != null and is_instance_valid(_preview_node):
		_preview_node.queue_free()
	_preview_node = null

# ---------------------------------------------------------------- interaction

func _on_card_input(event: InputEvent, card: CardData) -> void:
	if controller.phase != "player":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _selected.has(card):
			_selected.erase(card)
			Sfx.play(&"card_select", -8.0, 0.85)
		elif _selected.size() < 5:
			_selected.append(card)
			Sfx.play(&"card_select", -8.0)
		_refresh_card_styles()
		_update_selection_ui()

func _refresh_card_styles() -> void:
	for card in _widgets:
		CardWidget.set_selected(_widgets[card], _selected.has(card))

func _selected_indices() -> Array:
	var out: Array = []
	for card in _selected:
		var i: int = controller.hand.find(card)
		if i >= 0:
			out.append(i)
	return out

func _update_selection_ui() -> void:
	var is_player := controller.phase == "player"
	var has_sel := not _selected.is_empty()
	_play_btn.text = tr("COMBAT_PLAY")
	_play_btn.disabled = not (is_player and has_sel)
	_discard_btn.text = tr("COMBAT_DISCARD") % controller.discards_left
	_discard_btn.disabled = not (is_player and has_sel and controller.discards_left > 0)
	if not has_sel:
		_preview_label.text = tr("COMBAT_SELECT_HINT")
		_preview_extra.text = ""
		_breakdown_label.text = ""
		return
	var r := controller.preview(_selected_indices())
	_preview_label.text = tr("COMBAT_PREVIEW") % [
		tr(Poker.name_key(int(r["hand"]))), int(r["chips"]), float(r["mult"]), int(r["damage"]),
	]
	var parts: Array = []
	if int(r["block"]) > 0:
		parts.append(tr("COMBAT_TAG_BLOCK") % int(r["block"]))
	if int(r["heal"]) > 0:
		parts.append(tr("COMBAT_TAG_HEAL") % int(r["heal"]))
	if int(r["gnicie"]) > 0:
		parts.append(tr("COMBAT_TAG_GNICIE") % int(r["gnicie"]))
	_preview_extra.text = "    ".join(parts)
	_breakdown_label.text = _mult_breakdown(int(r["hand"]), int(r["block"]))

## Human-readable "why is the mult that value": base hand x + each relic / Furia / Polychrome factor.
func _mult_breakdown(hand: int, block: int) -> String:
	var mods: Array = ["%s x%d" % [tr(Poker.name_key(hand)), int(Poker.BASE[hand][1])]]
	var aspects := {}
	var has_furia := false
	var polys := 0
	for c in _selected:
		aspects[c.aspect] = true
		if c.keyword == CardData.Keyword.FURIA:
			has_furia = true
		if c.edition == CardData.Edition.POLYCHROME:
			polys += 1
	if has_furia and block == 0:
		mods.append("%s x1.5" % tr("KW_FURIA"))
	for relic in _relics:
		if relic.effect == ArcanumData.Effect.MULT_IF_ASPECT and aspects.has(relic.effect_aspect):
			mods.append("%s x%s" % [tr(relic.name_key), String.num(relic.effect_mult, 1)])
	if polys > 0:
		mods.append("%s x%s" % [tr("ED_POLYCHROME"), String.num(pow(1.3, polys), 1)])
	return "Mult:  " + "   ".join(mods)

func _on_play() -> void:
	if _selected.is_empty():
		return
	var idx := _selected_indices()
	_hide_card_preview()
	for card in _selected:
		if _widgets.has(card):
			_fly_card(_widgets[card], _enemy_fx_pos())
			_widgets.erase(card)
	_selected.clear()
	_fx_index = 0
	_emblem_hit()
	Sfx.play(&"card_play", -6.0)
	controller.play(idx)

func _on_discard() -> void:
	if _selected.is_empty():
		return
	var idx := _selected_indices()
	_hide_card_preview()
	for card in _selected:
		if _widgets.has(card):
			_fly_card(_widgets[card], _grave_fx_pos())
			_widgets.erase(card)
	_selected.clear()
	controller.discard(idx)

## Fly a played/discarded card out of the hand toward a target, then free it.
func _fly_card(panel: Control, target: Vector2) -> void:
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.reparent(_fx, true)   # keep global position; leave the hand container
	var tw := create_tween()
	tw.tween_property(panel, "global_position", target, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(panel, "scale", Vector2(0.35, 0.35), 0.32)
	tw.parallel().tween_property(panel, "modulate:a", 0.0, 0.32)
	tw.tween_callback(panel.queue_free)

func _on_restart() -> void:
	_log_lines.clear()
	_log_label.text = ""
	_overlay.visible = false
	_reset_hand()
	controller.start(_deck, _enemy, _relics)

func _on_message(text_key: String, args: Array) -> void:
	_log_lines.append(tr(text_key) % args)
	while _log_lines.size() > 4:
		_log_lines.pop_front()
	_log_label.text = "\n".join(_log_lines)
	match text_key:
		"LOG_PLAY":
			# The number grows with the hit and big hits shake the arena -- a 400 flush must FEEL
			# bigger than a 30 pair, not just read bigger.
			var dmg := int(args[1])
			_popup("-" + str(dmg), Color(1.0, 0.5, 0.4), _enemy_fx_pos(), 26 + clampi(dmg / 12, 0, 22))
			Sfx.play(&"hit", minf(0.0, -6.0 + dmg / 60.0), clampf(1.15 - dmg / 500.0, 0.7, 1.15))
			if dmg >= 150:
				_shake(4.0 + minf(dmg / 60.0, 8.0))
		"LOG_GNICIE":
			_popup("-" + str(int(args[0])), Aspects.color(Aspects.Id.DEATH), _enemy_fx_pos())
			Sfx.play(&"rot", -8.0)
		"LOG_BLOCK":
			_popup("+" + str(int(args[0])), Color(0.6, 0.8, 1.0), _block_fx_pos())
			_pulse(_block_label)
			Sfx.play(&"block", -6.0)
		"LOG_HEAL":
			_popup("+" + str(int(args[0])), Color(0.6, 0.9, 0.55), _player_fx_pos())
			Sfx.play(&"heal", -6.0)
		"LOG_ATTACK":
			if int(args[0]) > 0:
				_popup("-" + str(int(args[0])), Color(1.0, 0.5, 0.4), _player_fx_pos())
				_hit_flash()
				Sfx.play(&"player_hit", -4.0)
			else:
				_popup(tr("COMBAT_BLOCKED"), Color(0.6, 0.8, 1.0), _player_fx_pos(), 20)
				Sfx.play(&"block", -4.0)

## After the player's play resolves and animates, pause a beat, then let the enemy act.
func _on_awaiting_enemy() -> void:
	_fx_index = 0
	await get_tree().create_timer(0.35).timeout
	if controller == null or controller.phase != "enemy":
		return
	# wind-up: the enemy tenses (scale + reddish flash) so its attack has a visible cause
	_enemy_panel.pivot_offset = _enemy_panel.size * 0.5
	var tw := create_tween()
	tw.tween_property(_enemy_panel, "scale", Vector2(1.03, 1.03), 0.12)
	tw.parallel().tween_property(_enemy_panel, "modulate", Color(1.5, 0.85, 0.85), 0.12)
	tw.tween_property(_enemy_panel, "scale", Vector2.ONE, 0.12)
	tw.parallel().tween_property(_enemy_panel, "modulate", Color.WHITE, 0.12)
	await tw.finished
	if controller != null and controller.phase == "enemy":
		controller.resolve_enemy_turn()

func _on_ended(won: bool) -> void:
	Sfx.play(&"win" if won else &"lose", -4.0)
	if _emblem_idle != null:
		_emblem_idle.kill()
	if won:
		var tw := create_tween()
		tw.tween_property(_enemy_emblem, "modulate", Color(0.4, 0.12, 0.12, 0.12), 0.5)
		tw.parallel().tween_property(_enemy_emblem, "rotation", 0.3, 0.5)
	await get_tree().create_timer(0.6).timeout   # let the HP bar finish draining + a death beat
	if not standalone:
		finished.emit(won, controller.player_hp)
		return
	_overlay_label.text = tr("COMBAT_WON") if won else tr("COMBAT_LOST")
	_overlay_label.add_theme_color_override("font_color",
		Color(0.6, 0.9, 0.55) if won else Color(0.9, 0.4, 0.4))
	_overlay.modulate.a = 0.0
	_overlay.visible = true
	create_tween().tween_property(_overlay, "modulate:a", 1.0, 0.4)

# ---------------------------------------------------------------- helpers

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _set_bar(bar: ProgressBar, value: float) -> void:
	var tw := create_tween()
	tw.tween_property(bar, "value", value, 0.35).set_trans(Tween.TRANS_QUAD)

func _flash(node: Control) -> void:
	if node == null:
		return
	node.modulate = Color(1.6, 1.6, 1.6)
	create_tween().tween_property(node, "modulate", Color.WHITE, 0.35)

func _enemy_fx_pos() -> Vector2:
	return _enemy_hp_label.global_position + Vector2(70, -6)

func _player_fx_pos() -> Vector2:
	return _player_hp_label.global_position + Vector2(20, -34)

func _grave_fx_pos() -> Vector2:
	return _counters_label.global_position + Vector2(30, 0)

func _block_fx_pos() -> Vector2:
	return _block_label.global_position + Vector2(0, -28)

func _make_emblem() -> Panel:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.08, 0.09, 0.92)
	sb.set_border_width_all(3)
	sb.border_color = Color(0.6, 0.25, 0.28)
	sb.set_corner_radius_all(16)
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(168, 168)
	p.pivot_offset = Vector2(84, 84)
	p.set_meta("style", sb)
	_emblem_glyph = _label("", 92, Color(0.9, 0.5, 0.5))
	_emblem_glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_emblem_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_emblem_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(_emblem_glyph)
	_emblem_art = TextureRect.new()
	_emblem_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_emblem_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_emblem_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_emblem_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # scans, not pixel art
	_emblem_art.visible = false
	p.add_child(_emblem_art)
	return p

func _relic_chip(a: ArcanumData) -> Control:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.09, 0.14)
	sb.set_border_width_all(1)
	sb.border_color = Aspects.color(a.effect_aspect)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb)
	p.tooltip_text = tr(a.name_key)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	p.add_child(row)
	if a.art != null:
		var t := TextureRect.new()
		t.texture = a.art
		t.custom_minimum_size = Vector2(20, 34)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		row.add_child(t)
	row.add_child(_label(tr(a.name_key), 13, Color(0.85, 0.8, 0.92)))
	return p

func _start_emblem_idle() -> void:
	_emblem_idle = create_tween().set_loops()
	_emblem_idle.tween_property(_enemy_emblem, "modulate:a", 0.82, 1.3).set_trans(Tween.TRANS_SINE)
	_emblem_idle.tween_property(_enemy_emblem, "modulate:a", 1.0, 1.3).set_trans(Tween.TRANS_SINE)

func _emblem_hit() -> void:
	if _enemy_emblem == null:
		return
	_enemy_emblem.scale = Vector2(1.12, 1.12)
	create_tween().tween_property(_enemy_emblem, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _pulse(node: Control) -> void:
	if node == null:
		return
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(1.3, 1.3)
	create_tween().tween_property(node, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _shake(strength: float) -> void:
	var tw := create_tween()
	for i in 4:
		var off := Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		tw.tween_property(self, "position", off, 0.04)
	tw.tween_property(self, "position", Vector2.ZERO, 0.05)

func _hit_flash() -> void:
	var r := ColorRect.new()
	r.color = Color(0.85, 0.12, 0.12, 0.30)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "modulate:a", 0.0, 0.35)
	tw.tween_callback(r.queue_free)

func _popup(text: String, color: Color, at: Vector2, size: int = 26) -> void:
	var l := _label(text, size, color)
	l.position = at
	_fx.add_child(l)
	var delay: float = _fx_index * 0.16
	_fx_index += 1
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(l, "position:y", at.y - 46.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.7)
	tw.tween_callback(l.queue_free)

func _panel(bg: Color, border: Color) -> PanelContainer:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.set_corner_radius_all(3)
	for side in ["left", "top", "right", "bottom"]:
		sb.set("content_margin_" + side, 10)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb)
	return p

func _bar(fill: Color) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(240, 22)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.06, 0.09)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(3)
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fg)
	return pb
