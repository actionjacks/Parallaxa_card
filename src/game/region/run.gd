extends Control
## Region flow controller: map -> fight -> reward -> fight -> shop -> boss -> claim -> complete.
## Owns the run via RunState, swaps screens in a stage, feeds combat and reacts to its result.
## Screens are built in code on the project theme (monogram font + cursors).

const REGION_PATH := "res://data/regions/region_01.tres"
const COMBAT_SCENE := "res://src/game/combat/combat.tscn"
const BUY_COST := 4
const THIN_COST := 3
const ENCHANT_COST := 5

var _shop_offset: int = 5
var _shop_reroll_cost: int = 1

var _stage: Control
var _statusbar: PanelContainer
var _hp_label: Label
var _rtec_label: Label
var _deck_label: Label
var _relics_label: Label

var _reward_panels: Array = []
var _reward_cards: Array = []
var _reward_pick: int = -1
var _reward_take_btn: Button
var _last_rest: int = 0

func _ready() -> void:
	RunState.begin(load(REGION_PATH))
	RunState.changed.connect(_update_status)
	_build_shell()
	_show_map()

# ---------------------------------------------------------------- shell / status

func _build_shell() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.023, 0.04)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)

	_statusbar = _panel(Color(0.06, 0.06, 0.1), Color(0.25, 0.25, 0.34))
	col.add_child(_statusbar)
	var sb := HBoxContainer.new()
	sb.add_theme_constant_override("separation", 24)
	_statusbar.add_child(sb)
	_hp_label = _label("", 16, Color(0.6, 0.9, 0.55))
	_rtec_label = _label("", 16, Color(0.85, 0.8, 0.55))
	_deck_label = _label("", 16, Color(0.75, 0.78, 0.85))
	_relics_label = _label("", 16, Color(0.72, 0.62, 0.85))
	for l in [_hp_label, _rtec_label, _deck_label, _relics_label]:
		sb.add_child(l)

	_stage = Control.new()
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_stage)

func _update_status() -> void:
	_hp_label.text = tr("RUN_HP") % [RunState.player_hp, RunState.player_max_hp]
	_rtec_label.text = tr("RUN_RTEC") % RunState.rtec
	_deck_label.text = tr("RUN_DECK") % RunState.deck.size()
	_relics_label.text = tr("RUN_RELICS") % RunState.relics.size()

func _clear_stage() -> void:
	for ch in _stage.get_children():
		ch.queue_free()

func _mount(screen: Control) -> void:
	_clear_stage()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(screen)

# ---------------------------------------------------------------- MAP

func _show_map() -> void:
	_statusbar.visible = true
	_update_status()
	var root := _screen_column()
	root.add_child(_title(tr(RunState.region.name_key)))

	var ladder := HBoxContainer.new()
	ladder.alignment = BoxContainer.ALIGNMENT_CENTER
	ladder.add_theme_constant_override("separation", 16)
	var total := RunState.region.fights.size() + 1
	for i in total:
		var is_boss := i == RunState.region.fights.size()
		var label := tr("MAP_NODE_BOSS") if is_boss else (tr("MAP_NODE_FIGHT") % (i + 1))
		var mark := "✓ " if i < RunState.step else ("> " if i == RunState.step else "  ")
		var chip := _node_chip(mark + label, i == RunState.step, i < RunState.step, is_boss)
		ladder.add_child(chip)
	root.add_child(ladder)

	root.add_child(_hint(tr("MAP_HINT")))
	var go := _button(tr("MAP_GO"), _start_encounter)
	go.custom_minimum_size = Vector2(180, 40)
	var wrap := CenterContainer.new()
	wrap.add_child(go)
	root.add_child(wrap)
	_mount(root)

func _node_chip(text: String, current: bool, done: bool, is_boss: bool) -> PanelContainer:
	var border := Color(0.9, 0.5, 0.3) if is_boss else Color(0.3, 0.35, 0.45)
	if current:
		border = Color(0.98, 0.92, 0.6)
	var p := _panel(Color(0.1, 0.1, 0.14), border)
	p.custom_minimum_size = Vector2(150, 60)
	var l := _label(text, 18, Color(0.6, 0.62, 0.7) if done else Color(0.92, 0.9, 0.85))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p

# ---------------------------------------------------------------- COMBAT

func _current_enemy() -> EnemyData:
	if RunState.step < RunState.region.fights.size():
		return RunState.region.fights[RunState.step]
	return RunState.region.boss

func _start_encounter() -> void:
	_statusbar.visible = false
	var combat: Node = load(COMBAT_SCENE).instantiate()
	combat.setup(RunState.deck, _current_enemy(), RunState.relics,
		RunState.player_hp, RunState.player_max_hp)
	combat.finished.connect(_on_combat_finished)
	_clear_stage()
	combat.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(combat)

func _on_combat_finished(won: bool, remaining_hp: int) -> void:
	if not won:
		_show_defeat()
		return
	RunState.player_hp = remaining_hp
	RunState.rtec += _current_enemy().reward_rtec
	if RunState.step >= RunState.region.fights.size():
		RunState.claim_relic(RunState.region.boss_arcanum)
		_show_complete()
		return
	_last_rest = RunState.rest()   # recover between fights so the run isn't a one-HP knife-edge
	if RunState.step == 0:
		_show_reward()
	else:
		_shop_offset = 5
		_shop_reroll_cost = 1
		_show_shop()

# ---------------------------------------------------------------- REWARD

func _show_reward() -> void:
	_statusbar.visible = true
	_update_status()
	_reward_panels.clear()
	_reward_cards.clear()
	_reward_pick = -1
	var pool := DeckLibrary.reward_pool()
	var offset: int = (RunState.step * 3) % maxi(1, pool.size() - 2)
	var rested := _last_rest
	_last_rest = 0
	var root := _screen_column()
	root.add_child(_title(tr("REWARD_TITLE")))
	if rested > 0:
		root.add_child(_hint(tr("REST_HEALED") % rested))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	for i in 3:
		var card: CardData = pool[(offset + i) % pool.size()]
		var panel := CardWidget.build(card)
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.gui_input.connect(_on_reward_input.bind(_reward_cards.size()))
		_reward_cards.append(card)
		_reward_panels.append(panel)
		row.add_child(panel)
	root.add_child(row)
	root.add_child(_hint(tr("REWARD_HINT")))
	_reward_take_btn = _button(tr("REWARD_TAKE"), _take_reward)
	_reward_take_btn.disabled = true
	var wrap := CenterContainer.new()
	wrap.add_child(_reward_take_btn)
	root.add_child(wrap)
	_mount(root)

func _on_reward_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_reward_pick = index
		for i in _reward_panels.size():
			CardWidget.set_selected(_reward_panels[i], i == index)
		_reward_take_btn.disabled = false

func _take_reward() -> void:
	if _reward_pick >= 0:
		RunState.add_card(_reward_cards[_reward_pick])
	RunState.step += 1
	_show_map()

# ---------------------------------------------------------------- SHOP

func _show_shop() -> void:
	_statusbar.visible = true
	_update_status()
	var rested := _last_rest
	_last_rest = 0
	var pool := DeckLibrary.reward_pool()
	var root := _screen_column()
	root.add_child(_title(tr("SHOP_TITLE")))
	if rested > 0:
		root.add_child(_hint(tr("REST_HEALED") % rested))

	# --- buy offers ---
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	for i in 3:
		var card: CardData = pool[(_shop_offset + i) % pool.size()]
		var item := VBoxContainer.new()
		item.alignment = BoxContainer.ALIGNMENT_CENTER
		item.add_theme_constant_override("separation", 6)
		item.add_child(CardWidget.build(card))
		var buy := _button(tr("SHOP_BUY") % BUY_COST, _buy.bind(card))
		buy.disabled = RunState.rtec < BUY_COST
		var w := CenterContainer.new()
		w.add_child(buy)
		item.add_child(w)
		row.add_child(item)
	root.add_child(row)

	# --- enchant: apply an edition to a deck card ---
	var ench := HBoxContainer.new()
	ench.alignment = BoxContainer.ALIGNMENT_CENTER
	ench.add_theme_constant_override("separation", 10)
	ench.add_child(_label(tr("SHOP_ENCHANT") % ENCHANT_COST, 15, Color(0.72, 0.76, 0.86)))
	var can_ench := RunState.rtec >= ENCHANT_COST and RunState.deck.size() > 0
	for ed in [CardData.Edition.FOIL, CardData.Edition.HOLO, CardData.Edition.POLYCHROME]:
		var eb := _button(tr(CardData.edition_name_key(ed)), _enchant.bind(ed))
		eb.disabled = not can_ench
		ench.add_child(eb)
	root.add_child(ench)

	root.add_child(_hint(tr("SHOP_HINT")))

	# --- controls ---
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 12)
	var reroll := _button(tr("SHOP_REROLL") % _shop_reroll_cost, _reroll_shop)
	reroll.disabled = RunState.rtec < _shop_reroll_cost
	controls.add_child(reroll)
	var thin := _button(tr("SHOP_THIN") % THIN_COST, _thin_deck)
	thin.disabled = RunState.rtec < THIN_COST or RunState.deck.size() <= 5
	controls.add_child(thin)
	controls.add_child(_button(tr("SHOP_NEXT"), _leave_shop))
	root.add_child(controls)
	_mount(root)

func _buy(card: CardData) -> void:
	if RunState.spend(BUY_COST):
		RunState.add_card(card)
		_show_shop()  # refresh prices / affordability

func _thin_deck() -> void:
	if RunState.rtec < THIN_COST or RunState.deck.size() <= 5:
		return
	var cb := func(card: CardData) -> void:
		RunState.spend(THIN_COST)
		RunState.remove_card(card)
		_show_shop()
	_open_deck_picker(tr("PICK_REMOVE"), cb)

func _enchant(edition: int) -> void:
	if RunState.rtec < ENCHANT_COST or RunState.deck.is_empty():
		return
	var cb := func(card: CardData) -> void:
		card.edition = edition
		RunState.spend(ENCHANT_COST)
		RunState.changed.emit()
		_show_shop()
	_open_deck_picker(tr("PICK_ENCHANT"), cb)

func _reroll_shop() -> void:
	if RunState.spend(_shop_reroll_cost):
		_shop_offset += 3
		_shop_reroll_cost += 1
		_show_shop()

func _open_deck_picker(title: String, on_pick: Callable) -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	overlay.add_child(col)
	col.add_child(_title(title))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1120, 250)
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(scroll)
	var grid := HFlowContainer.new()
	grid.custom_minimum_size = Vector2(1120, 0)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for card in RunState.deck:
		var panel := CardWidget.build(card)
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.gui_input.connect(_on_picker_input.bind(card, overlay, on_pick))
		grid.add_child(panel)
	var wrap := CenterContainer.new()
	wrap.add_child(_button(tr("COMMON_CANCEL"), overlay.queue_free))
	col.add_child(wrap)

func _on_picker_input(ev: InputEvent, card: CardData, overlay: Control, on_pick: Callable) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		overlay.queue_free()
		on_pick.call(card)

func _leave_shop() -> void:
	RunState.step += 1
	_show_map()

# ---------------------------------------------------------------- COMPLETE / DEFEAT

func _show_complete() -> void:
	_statusbar.visible = true
	_update_status()
	var root := _screen_column()
	root.add_child(_big(tr("COMPLETE_TITLE"), Color(0.65, 0.9, 0.55)))
	var relic := RunState.region.boss_arcanum
	if relic != null:
		root.add_child(_label_center(tr("COMPLETE_RELIC") % tr(relic.name_key), 20, Color(0.75, 0.65, 0.9)))
	root.add_child(_hint(tr("COMPLETE_HINT")))
	var wrap := CenterContainer.new()
	wrap.add_child(_button(tr("COMPLETE_NEW"), _restart_run))
	root.add_child(wrap)
	_mount(root)

func _show_defeat() -> void:
	_statusbar.visible = true
	_update_status()
	var root := _screen_column()
	root.add_child(_big(tr("DEFEAT_TITLE"), Color(0.9, 0.4, 0.4)))
	var wrap := CenterContainer.new()
	wrap.add_child(_button(tr("DEFEAT_NEW"), _restart_run))
	root.add_child(wrap)
	_mount(root)

func _restart_run() -> void:
	RunState.begin(RunState.region)
	_show_map()

# ---------------------------------------------------------------- helpers

func _screen_column() -> VBoxContainer:
	var c := VBoxContainer.new()
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_theme_constant_override("separation", 24)
	return c

func _title(text: String) -> Label:
	return _label_center(text, 30, Color(0.96, 0.92, 0.82))

func _big(text: String, color: Color) -> Label:
	return _label_center(text, 48, color)

func _hint(text: String) -> Label:
	return _label_center(text, 15, Color(0.6, 0.6, 0.68))

func _label_center(text: String, size: int, color: Color) -> Label:
	var l := _label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(cb)
	return b

func _panel(bg: Color, border: Color) -> PanelContainer:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 12
	sb.content_margin_top = 8
	sb.content_margin_right = 12
	sb.content_margin_bottom = 8
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb)
	return p
