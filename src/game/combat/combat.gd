extends Control
## Vertical slice: a playable 1v1 duel. Poker hand -> Chips x Mult -> damage, on the
## parallaxa_orange theme (monogram font + custom cursors via CursorManager autoload).
## UI is built in code for the slice; scene authoring can come later.

const ENEMY_PATH := "res://data/combat/enemy_kultysta.tres"
const ARCANUM_PATH := "res://data/combat/arcanum_smierci.tres"

const CARD_BG := Color(0.09, 0.09, 0.13)
const CARD_BG_SEL := Color(0.18, 0.18, 0.26)

var controller: CombatController
var _deck: Array = []
var _enemy: EnemyData
var _arcanum: ArcanumData
var _selected: Array[int] = []

var _card_panels: Array = []
var _card_styles: Array = []
var _log_lines: Array[String] = []

# Node refs
var _enemy_name: Label
var _enemy_hp_bar: ProgressBar
var _enemy_hp_label: Label
var _intent_label: Label
var _gnicie_label: Label
var _relic_label: Label
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

func _ready() -> void:
	_enemy = load(ENEMY_PATH)
	_arcanum = load(ARCANUM_PATH)
	_deck = DeckLibrary.starter_deck()
	_build_ui()
	controller = CombatController.new()
	controller.state_changed.connect(_render)
	controller.message.connect(_on_message)
	controller.ended.connect(_on_ended)
	controller.start(_deck, _enemy, _arcanum)

# ---------------------------------------------------------------- UI construction

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.023, 0.04)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	# --- enemy panel ---
	var enemy_panel := _panel(Color(0.11, 0.07, 0.09), Color(0.5, 0.2, 0.24))
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

	# --- middle: relic + preview + log ---
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 6)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(mid)
	_relic_label = _label("", 14, Color(0.7, 0.62, 0.85))
	mid.add_child(_relic_label)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(spacer)
	_preview_label = _label("", 24, Color(0.98, 0.95, 0.8))
	_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_preview_label)
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
	_enemy_hp_bar.value = controller.enemy_hp
	_enemy_hp_label.text = tr("COMBAT_HP") % [controller.enemy_hp, _enemy.max_hp]
	_intent_label.text = tr("COMBAT_INTENT") % controller.current_intent()
	_gnicie_label.text = (tr("COMBAT_GNICIE") % controller.enemy_gnicie) if controller.enemy_gnicie > 0 else ""
	_relic_label.text = "* " + tr(_arcanum.name_key)
	_player_hp_bar.max_value = controller.player_max_hp
	_player_hp_bar.value = controller.player_hp
	_player_hp_label.text = tr("COMBAT_HP") % [controller.player_hp, controller.player_max_hp]
	_block_label.text = tr("COMBAT_BLOCK") % controller.player_block
	_turn_label.text = tr("COMBAT_TURN") % controller.turn
	_build_hand()
	_update_selection_ui()

func _build_hand() -> void:
	for ch in _hand_row.get_children():
		ch.queue_free()
	_card_panels.clear()
	_card_styles.clear()
	_selected.clear()
	for i in controller.hand.size():
		_hand_row.add_child(_make_card(controller.hand[i], i))

func _make_card(card: CardData, index: int) -> Control:
	var col := Aspects.color(card.aspect)
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD_BG
	sb.set_border_width_all(2)
	sb.border_color = col
	sb.set_corner_radius_all(3)
	for side in ["left", "top", "right", "bottom"]:
		sb.set("content_margin_" + side, 6)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(80, 112)
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(_on_card_input.bind(index))
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vb)
	var rank := _label(card.rank_glyph(), 30, col)
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(rank)
	var asp := _label(tr(Aspects.name_key(card.aspect)), 12, Color(0.72, 0.72, 0.78))
	asp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(asp)
	if card.keyword != CardData.Keyword.NONE:
		var txt := tr(CardData.keyword_name_key(card.keyword))
		if card.keyword_value > 0:
			txt += " " + str(card.keyword_value)
		var kw := _label(txt, 11, col)
		kw.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kw.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(kw)
	_card_panels.append(panel)
	_card_styles.append(sb)
	return panel

# ---------------------------------------------------------------- interaction

func _on_card_input(event: InputEvent, index: int) -> void:
	if controller.phase != "player":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _selected.has(index):
			_selected.erase(index)
		elif _selected.size() < 5:
			_selected.append(index)
		_refresh_card_styles()
		_update_selection_ui()

func _refresh_card_styles() -> void:
	for i in _card_panels.size():
		var sb: StyleBoxFlat = _card_styles[i]
		if _selected.has(i):
			sb.border_color = Color.WHITE
			sb.bg_color = CARD_BG_SEL
			sb.set_border_width_all(3)
		else:
			sb.border_color = Aspects.color(controller.hand[i].aspect)
			sb.bg_color = CARD_BG
			sb.set_border_width_all(2)

func _update_selection_ui() -> void:
	var is_player := controller.phase == "player"
	var has_sel := not _selected.is_empty()
	_play_btn.text = tr("COMBAT_PLAY")
	_play_btn.disabled = not (is_player and has_sel)
	_discard_btn.text = tr("COMBAT_DISCARD") % controller.discards_left
	_discard_btn.disabled = not (is_player and has_sel and controller.discards_left > 0)
	if not has_sel:
		_preview_label.text = tr("COMBAT_SELECT_HINT")
		return
	var r := controller.preview(_selected)
	_preview_label.text = tr("COMBAT_PREVIEW") % [
		tr(Poker.name_key(int(r["hand"]))), int(r["chips"]), float(r["mult"]), int(r["damage"]),
	]

func _on_play() -> void:
	if _selected.is_empty():
		return
	controller.play(_selected.duplicate())

func _on_discard() -> void:
	if _selected.is_empty():
		return
	controller.discard(_selected.duplicate())

func _on_restart() -> void:
	_log_lines.clear()
	_log_label.text = ""
	_overlay.visible = false
	controller.start(_deck, _enemy, _arcanum)

func _on_message(text_key: String, args: Array) -> void:
	_log_lines.append(tr(text_key) % args)
	while _log_lines.size() > 4:
		_log_lines.pop_front()
	_log_label.text = "\n".join(_log_lines)

func _on_ended(won: bool) -> void:
	_overlay_label.text = tr("COMBAT_WON") if won else tr("COMBAT_LOST")
	_overlay_label.add_theme_color_override("font_color",
		Color(0.6, 0.9, 0.55) if won else Color(0.9, 0.4, 0.4))
	_overlay.visible = true

# ---------------------------------------------------------------- helpers

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

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
