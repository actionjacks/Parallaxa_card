extends Control
## Region flow controller: map -> fight -> reward -> fight -> shop -> boss -> claim -> complete.
## Owns the run via RunState, swaps screens in a stage, feeds combat and reacts to its result.
## Screens are built in code on the project theme (monogram font + cursors).

## The Fool's Journey: four regions, ending at The World. State carries across; full rest between.
const JOURNEY: Array[String] = [
	"res://data/regions/region_01.tres",
	"res://data/regions/region_02.tres",
	"res://data/regions/region_03.tres",
	"res://data/regions/region_04.tres",
]
const COMBAT_SCENE := "res://src/game/combat/combat.tscn"
const BUY_COST := 5
const THIN_COST := 3
const ENCHANT_COST := 5
const STAR_COST := 7
## Hands a Star can level (the reachable ones).
const STAR_HANDS: Array = [Poker.Hand.PAIR, Poker.Hand.TWO_PAIR, Poker.Hand.THREE,
	Poker.Hand.STRAIGHT, Poker.Hand.FLUSH, Poker.Hand.FULL_HOUSE, Poker.Hand.FOUR]

var _shop_offers: Array = []
var _shop_reroll_cost: int = 1
var _shop_star: int = -1          ## Poker.Hand this visit's Star levels; -1 = sold/none

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
var _last_interest: int = 0
var _last_thrift: int = 0
var _prev_hp: int = -1
var _prev_rtec: int = -1
var _prev_deck: int = -1
var _prev_relics: int = -1

func _ready() -> void:
	RunState.begin(load(JOURNEY[0]))
	RunState.changed.connect(_update_status)
	_build_shell()
	_start_run_flow()

## A run opens with the Arcanum draft (pick your starting power); map afterwards.
func _start_run_flow() -> void:
	if RunState.region != null and not RunState.region.starting_pool.is_empty():
		_show_arcanum_draft()
	else:
		_show_map()

# ---------------------------------------------------------------- shell / status

func _build_shell() -> void:
	add_child(Backdrop.build())

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)

	_statusbar = _panel(Color(0.06, 0.06, 0.1), Color(0.25, 0.25, 0.34))
	col.add_child(_statusbar)
	var sb := HBoxContainer.new()
	sb.add_theme_constant_override("separation", 24)
	_statusbar.add_child(sb)
	var fool := TextureRect.new()   # the run's identity: you are The Fool
	fool.texture = load("res://assets/cards/arcana/00_fool.jpg")
	fool.custom_minimum_size = Vector2(20, 34)
	fool.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fool.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fool.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	fool.tooltip_text = tr("FOOL_YOU")
	sb.add_child(fool)
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
	if _prev_hp != -1:   # pulse whatever changed (green up / red down) so the player sees why
		if RunState.player_hp != _prev_hp:
			_pulse_stat(_hp_label, RunState.player_hp > _prev_hp)
		if RunState.rtec != _prev_rtec:
			_pulse_stat(_rtec_label, RunState.rtec > _prev_rtec)
		if RunState.deck.size() != _prev_deck:
			_pulse_stat(_deck_label, RunState.deck.size() > _prev_deck)
		if RunState.relics.size() != _prev_relics:
			_pulse_stat(_relics_label, true)
	_prev_hp = RunState.player_hp
	_prev_rtec = RunState.rtec
	_prev_deck = RunState.deck.size()
	_prev_relics = RunState.relics.size()

func _pulse_stat(l: Label, good: bool) -> void:
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(1.35, 1.35)
	l.modulate = Color(0.6, 1.4, 0.7) if good else Color(1.5, 0.5, 0.5)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate", Color.WHITE, 0.30)

func _clear_stage() -> void:
	for ch in _stage.get_children():
		ch.queue_free()

func _mount(screen: Control) -> void:
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.modulate.a = 0.0
	_stage.add_child(screen)
	for ch in _stage.get_children():   # crossfade: fade out & free the outgoing screen(s)
		if ch == screen:
			continue
		var out := create_tween()
		out.tween_property(ch, "modulate:a", 0.0, 0.18)
		out.tween_callback(ch.queue_free)
	create_tween().tween_property(screen, "modulate:a", 1.0, 0.18)

# ---------------------------------------------------------------- MAP

func _show_map() -> void:
	_statusbar.visible = true
	_update_status()
	var root := _screen_column()
	root.add_child(_title(tr(RunState.region.name_key)))

	var ladder := HBoxContainer.new()
	ladder.alignment = BoxContainer.ALIGNMENT_CENTER
	ladder.add_theme_constant_override("separation", 16)
	var total := RunState.fights.size() + 1
	for i in total:
		var is_boss := i == RunState.fights.size()
		var label := tr("MAP_NODE_BOSS") if is_boss else (tr("MAP_NODE_FIGHT") % (i + 1))
		var mark := "✓ " if i < RunState.step else ""
		var enemy: EnemyData = RunState.region.boss if is_boss else RunState.fights[i]
		var chip := _node_chip(mark + label, tr(enemy.name_key), i == RunState.step, i < RunState.step, is_boss)
		ladder.add_child(chip)
	root.add_child(ladder)

	if RunState.relics.size() > 0:
		var rr := HBoxContainer.new()
		rr.alignment = BoxContainer.ALIGNMENT_CENTER
		rr.add_theme_constant_override("separation", 8)
		for a in RunState.relics:
			rr.add_child(_relic_chip(a))
		root.add_child(rr)

	if not _pending_omen.is_empty():
		var ow := CenterContainer.new()
		ow.add_child(_omen_block())
		root.add_child(ow)

	root.add_child(_hint(tr("MAP_HINT")))
	var ctrls := HBoxContainer.new()
	ctrls.alignment = BoxContainer.ALIGNMENT_CENTER
	ctrls.add_theme_constant_override("separation", 12)
	var go := _button(tr("MAP_GO"), _start_encounter)
	go.custom_minimum_size = Vector2(160, 40)
	ctrls.add_child(go)
	ctrls.add_child(_button(tr("VIEW_DECK"), _view_deck))
	root.add_child(ctrls)
	_mount(root)

func _relic_chip(a: ArcanumData) -> Control:
	var p := _panel(Color(0.11, 0.09, 0.14), Aspects.color(a.effect_aspect))
	p.tooltip_text = tr(a.name_key) + "\n" + a.describe()
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	if a.art != null:
		var t := TextureRect.new()
		t.texture = a.art
		t.custom_minimum_size = Vector2(22, 38)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(t)
	var l := _label(tr(a.name_key), 14, Color(0.85, 0.8, 0.92))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	return p

func _view_deck() -> void:
	_open_deck_picker(tr("VIEW_DECK_TITLE"), func(_card: CardData) -> void: pass)

func _edition_desc(ed: int) -> String:
	match ed:
		CardData.Edition.FOIL: return tr("ED_FOIL_DESC")
		CardData.Edition.HOLO: return tr("ED_HOLO_DESC")
		CardData.Edition.POLYCHROME: return tr("ED_POLYCHROME_DESC")
	return ""

func _node_chip(text: String, subtitle: String, current: bool, done: bool, is_boss: bool) -> PanelContainer:
	var border := Color(0.9, 0.5, 0.3) if is_boss else Color(0.3, 0.35, 0.45)
	if current:
		border = Color(0.98, 0.92, 0.6)
	var p := _panel(Color(0.1, 0.1, 0.14), border)
	p.custom_minimum_size = Vector2(164, 66)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(vb)
	var l := _label(text, 18, Color(0.6, 0.62, 0.7) if done else Color(0.92, 0.9, 0.85))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(l)
	var s := _label(subtitle, 12, Color(0.58, 0.54, 0.58) if done else Color(0.74, 0.68, 0.72))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(s)
	return p

# ---------------------------------------------------------------- COMBAT

func _current_enemy() -> EnemyData:
	if RunState.step < RunState.fights.size():
		return RunState.fights[RunState.step]
	return RunState.region.boss

func _start_encounter() -> void:
	_statusbar.visible = false
	var combat: Node = load(COMBAT_SCENE).instantiate()
	combat.setup(RunState.deck, _current_enemy(), RunState.relics,
		RunState.player_hp, RunState.player_max_hp, RunState.hand_levels)
	combat.finished.connect(_on_combat_finished)
	_mount(combat)   # crossfade into the fight

func _on_combat_finished(won: bool, remaining_hp: int, unused_discards: int) -> void:
	if not won:
		_show_defeat()
		return
	RunState.player_hp = remaining_hp
	RunState.rtec += _current_enemy().reward_rtec
	# Economy legs from the design: thrift (1 per unused discard) then interest (1 per 5 held, cap 5).
	_last_thrift = mini(unused_discards, 2)   # thrift capped: hoarding discards must not print money
	RunState.rtec += _last_thrift
	_last_interest = mini(RunState.rtec / 5, 5)
	RunState.rtec += _last_interest
	RunState.fights_won += 1
	if RunState.step >= RunState.fights.size():
		RunState.claim_relic(RunState.region.boss_arcanum)
		_show_complete()
		return
	_last_rest = RunState.rest()   # recover between fights so the run isn't a one-HP knife-edge
	_roll_omen()                   # the road reveals an omen; it waits on the map screen
	if RunState.step == 0:
		_show_reward()
	else:
		_shop_offers = RunState.pick_offers(DeckLibrary.reward_pool(), 3)
		_shop_star = RunState.pick_offers(STAR_HANDS, 1)[0]
		_shop_reroll_cost = 1
		_show_shop()

# ---------------------------------------------------------------- REWARD

func _show_reward() -> void:
	_statusbar.visible = true
	_update_status()
	_reward_panels.clear()
	_reward_cards.clear()
	_reward_pick = -1
	var offers: Array = RunState.pick_offers(DeckLibrary.reward_pool(), 3)
	var rested := _last_rest
	_last_rest = 0
	var root := _screen_column()
	root.add_child(_title(tr("REWARD_TITLE")))
	if rested > 0:
		root.add_child(_hint(tr("REST_HEALED") % rested))
	if _last_thrift > 0:
		root.add_child(_hint(tr("ECON_THRIFT") % _last_thrift))
		_last_thrift = 0
	if _last_interest > 0:
		root.add_child(_hint(tr("ECON_INTEREST") % _last_interest))
		_last_interest = 0
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	for card: CardData in offers:
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
	var ctrls := HBoxContainer.new()
	ctrls.alignment = BoxContainer.ALIGNMENT_CENTER
	ctrls.add_theme_constant_override("separation", 12)
	ctrls.add_child(_reward_take_btn)
	ctrls.add_child(_button(tr("REWARD_SKIP"), _skip_reward))   # decline the card (keep the deck lean)
	root.add_child(ctrls)
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
		Sfx.play(&"coin", -6.0)
	RunState.step += 1
	_show_map()

func _skip_reward() -> void:
	RunState.step += 1
	_show_map()

# ---------------------------------------------------------------- SHOP

func _show_shop() -> void:
	_statusbar.visible = true
	_update_status()
	var rested := _last_rest
	_last_rest = 0
	if _shop_offers.is_empty():
		_shop_offers = RunState.pick_offers(DeckLibrary.reward_pool(), 3)
	var root := _screen_column()
	root.add_child(_title(tr("SHOP_TITLE")))
	if rested > 0:
		root.add_child(_hint(tr("REST_HEALED") % rested))
	if _last_thrift > 0:
		root.add_child(_hint(tr("ECON_THRIFT") % _last_thrift))
		_last_thrift = 0
	if _last_interest > 0:
		root.add_child(_hint(tr("ECON_INTEREST") % _last_interest))
		_last_interest = 0

	# --- buy offers ---
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	for card: CardData in _shop_offers:
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
		eb.tooltip_text = _edition_desc(ed)
		eb.disabled = not can_ench
		ench.add_child(eb)
	root.add_child(ench)

	# --- Star: level a poker hand up for the rest of the run (the growth engine) ---
	if _shop_star >= 0:
		var lv := int(RunState.hand_levels.get(_shop_star, 0))
		var up: Array = Poker.LEVEL_UP[_shop_star]
		var srow := HBoxContainer.new()
		srow.alignment = BoxContainer.ALIGNMENT_CENTER
		srow.add_theme_constant_override("separation", 10)
		var slabel := _label(tr("SHOP_STAR") % [tr(Poker.name_key(_shop_star)), lv + 1, lv + 2], 15, Color(0.95, 0.9, 0.6))
		srow.add_child(slabel)
		var sdesc := _label("(+%d chips, +%d Mult)" % [int(up[0]), int(up[1])], 13, Color(0.7, 0.72, 0.6))
		srow.add_child(sdesc)
		var sbuy := _button(tr("SHOP_STAR_BUY") % STAR_COST, _buy_star)
		sbuy.disabled = RunState.rtec < STAR_COST
		srow.add_child(sbuy)
		root.add_child(srow)

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
		Sfx.play(&"coin", -4.0)
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

func _buy_star() -> void:
	if _shop_star >= 0 and RunState.spend(STAR_COST):
		RunState.level_up_hand(_shop_star)
		Sfx.play(&"coin", -4.0, 1.2)
		_shop_star = -1   # one Star per visit
		_show_shop()

func _reroll_shop() -> void:
	if RunState.spend(_shop_reroll_cost):
		_shop_offers = RunState.pick_offers(DeckLibrary.reward_pool(), 3)   # the slot-machine pull
		_shop_star = RunState.pick_offers(STAR_HANDS, 1)[0]
		_shop_reroll_cost += 1
		_show_shop()

func _open_deck_picker(title: String, on_pick: Callable) -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.modulate.a = 0.0
	add_child(overlay)
	create_tween().tween_property(overlay, "modulate:a", 1.0, 0.15)
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
	wrap.add_child(_button(tr("COMMON_CANCEL"), _close_overlay.bind(overlay)))
	col.add_child(wrap)

func _on_picker_input(ev: InputEvent, card: CardData, overlay: Control, on_pick: Callable) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_close_overlay(overlay, on_pick.bind(card))

func _close_overlay(overlay: Control, after := Callable()) -> void:
	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 0.0, 0.15)
	tw.tween_callback(overlay.queue_free)
	if after.is_valid():
		tw.tween_callback(after)

func _leave_shop() -> void:
	RunState.step += 1
	_show_map()

# ---------------------------------------------------------------- COMPLETE / DEFEAT

func _show_complete() -> void:
	_statusbar.visible = true
	_update_status()
	var final := RunState.region_index + 1 >= JOURNEY.size()
	var root := _screen_column()
	if final:
		root.add_child(_big(tr("VICTORY_TITLE"), Color(0.95, 0.85, 0.5)))
	else:
		root.add_child(_big(tr("COMPLETE_TITLE"), Color(0.65, 0.9, 0.55)))
	var relic := RunState.region.boss_arcanum
	if relic != null:
		if relic.art != null:
			# The claimed Arcanum is shown as the actual card -- you beat it, now you wear it.
			var t := TextureRect.new()
			t.texture = relic.art
			t.custom_minimum_size = Vector2(160, 277)
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			var wrap_art := CenterContainer.new()
			wrap_art.add_child(t)
			root.add_child(wrap_art)
		root.add_child(_label_center(tr("COMPLETE_RELIC") % tr(relic.name_key), 20, Color(0.75, 0.65, 0.9)))
	root.add_child(_hint(tr("RUN_SUMMARY") % RunState.fights_won))
	var wrap := CenterContainer.new()
	if not final:
		root.add_child(_hint(tr("COMPLETE_HINT")))
		wrap.add_child(_button(tr("COMPLETE_NEXT"), _continue_journey))
	else:
		# The World has fallen: the Journey is complete -- the run is WON.
		var rr := HBoxContainer.new()
		rr.alignment = BoxContainer.ALIGNMENT_CENTER
		rr.add_theme_constant_override("separation", 8)
		for a in RunState.relics:
			rr.add_child(_relic_chip(a))
		root.add_child(rr)
		Sfx.play(&"win", -2.0)
		wrap.add_child(_button(tr("COMPLETE_NEW"), _restart_run))
	root.add_child(wrap)
	_mount(root)

func _continue_journey() -> void:
	var idx := RunState.region_index + 1
	_pending_omen = {}
	RunState.enter_region(load(JOURNEY[idx]), idx)
	_show_map()

func _show_defeat() -> void:
	_statusbar.visible = true
	_update_status()
	var root := _screen_column()
	# Death XIII greets the fallen -- the card reads the outcome for you.
	var death_art := TextureRect.new()
	death_art.texture = load("res://assets/cards/arcana/13_death.jpg")
	death_art.custom_minimum_size = Vector2(150, 260)
	death_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	death_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	death_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var death_wrap := CenterContainer.new()
	death_wrap.add_child(death_art)
	root.add_child(death_wrap)
	root.add_child(_big(tr("DEFEAT_TITLE"), Color(0.9, 0.4, 0.4)))
	root.add_child(_hint(tr("RUN_SUMMARY") % RunState.fights_won))
	var wrap := CenterContainer.new()
	wrap.add_child(_button(tr("DEFEAT_NEW"), _restart_run))
	root.add_child(wrap)
	_mount(root)

func _restart_run() -> void:
	_pending_omen = {}
	RunState.begin(load(JOURNEY[0]))   # a new Journey always starts at the first region
	_start_run_flow()

# ---------------------------------------------------------------- ARCANUM DRAFT

var _arc_offers: Array = []
var _arc_panels: Array = []
var _arc_pick: int = -1
var _arc_btn: Button

# ---------------------------------------------------------------- OMENS
# Between fights the road can reveal an omen: a Major Arcana with a small, fully deterministic
# choice. Uses the reward-layer RNG only for WHICH omen appears; effects are exact.
# TODO(editor-first): move to .tres once the shape settles.

const OMENS: Array = [
	{"id": "star", "art": "res://assets/cards/arcana/17_star.jpg", "name": "OMEN_STAR", "desc": "OMEN_STAR_DESC"},
	{"id": "wheel", "art": "res://assets/cards/arcana/10_wheel_of_fortune.jpg", "name": "OMEN_WHEEL", "desc": "OMEN_WHEEL_DESC"},
	{"id": "hanged", "art": "res://assets/cards/arcana/12_hanged_man.jpg", "name": "OMEN_HANGED", "desc": "OMEN_HANGED_DESC"},
	{"id": "justice", "art": "res://assets/cards/arcana/11_justice.jpg", "name": "OMEN_JUSTICE", "desc": "OMEN_JUSTICE_DESC"},
	{"id": "temperance", "art": "res://assets/cards/arcana/14_temperance.jpg", "name": "OMEN_TEMPERANCE", "desc": "OMEN_TEMPERANCE_DESC"},
]

var _pending_omen: Dictionary = {}

func _roll_omen() -> void:
	_pending_omen = RunState.pick_offers(OMENS, 1)[0]

func _omen_block() -> Control:
	var p := _panel(Color(0.1, 0.09, 0.13), Color(0.7, 0.6, 0.85))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	p.add_child(row)
	var t := TextureRect.new()
	t.texture = load(_pending_omen["art"])
	t.custom_minimum_size = Vector2(64, 111)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	row.add_child(t)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 6)
	row.add_child(vb)
	vb.add_child(_label(tr("OMEN_TITLE") + ": " + tr(_pending_omen["name"]), 17, Color(0.9, 0.85, 0.95)))
	vb.add_child(_label(tr(_pending_omen["desc"]), 14, Color(0.72, 0.74, 0.82)))
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	var take := _button(tr("OMEN_TAKE"), _accept_omen)
	if _pending_omen["id"] == "hanged" and RunState.player_hp <= 5:
		take.disabled = true   # the trade would kill you; the card refuses
	btns.add_child(take)
	btns.add_child(_button(tr("OMEN_SKIP"), _skip_omen))
	vb.add_child(btns)
	return p

func _accept_omen() -> void:
	var id: String = _pending_omen["id"]
	_pending_omen = {}
	match id:
		"star":
			RunState.player_hp = mini(RunState.player_max_hp, RunState.player_hp + 10)
			Sfx.play(&"heal", -6.0)
		"wheel":
			RunState.rtec += 4
			Sfx.play(&"coin", -6.0)
		"hanged":
			RunState.player_hp -= 5
			RunState.rtec += 8
			Sfx.play(&"coin", -6.0)
		"temperance":
			RunState.player_hp = mini(RunState.player_max_hp, RunState.player_hp + 6)
			RunState.rtec += 2
			Sfx.play(&"heal", -6.0)
		"justice":
			Sfx.play(&"card_select", -8.0)
			var cb := func(card: CardData) -> void:
				RunState.remove_card(card)
				_show_map()
			_open_deck_picker(tr("PICK_REMOVE"), cb)
			return
	RunState.changed.emit()
	_show_map()

func _skip_omen() -> void:
	_pending_omen = {}
	_show_map()

func _show_arcanum_draft() -> void:
	_statusbar.visible = true
	_update_status()
	_arc_offers = RunState.pick_offers(RunState.region.starting_pool, 3)
	_arc_panels.clear()
	_arc_pick = -1
	var root := _screen_column()
	root.add_child(_title(tr("DRAFT_TITLE")))
	root.add_child(_hint(tr("DRAFT_HINT")))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	for i in _arc_offers.size():
		var panel := _arcanum_offer_panel(_arc_offers[i])
		panel.gui_input.connect(_on_arc_input.bind(i))
		_arc_panels.append(panel)
		row.add_child(panel)
	root.add_child(row)
	_arc_btn = _button(tr("DRAFT_TAKE"), _take_arcanum)
	_arc_btn.disabled = true
	var wrap := CenterContainer.new()
	wrap.add_child(_arc_btn)
	root.add_child(wrap)
	_mount(root)

func _arcanum_offer_panel(a: ArcanumData) -> PanelContainer:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.14)
	sb.set_border_width_all(2)
	sb.border_color = Aspects.color(a.effect_aspect)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_top = 10
	sb.content_margin_right = 10
	sb.content_margin_bottom = 10
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.set_meta("style", sb)
	p.set_meta("border", sb.border_color)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(vb)
	if a.art != null:
		var t := TextureRect.new()
		t.texture = a.art
		t.custom_minimum_size = Vector2(128, 222)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(t)
	var name_l := _label(tr(a.name_key), 16, Color(0.92, 0.88, 0.95))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(name_l)
	var desc_l := _label(a.describe(), 13, Aspects.color(a.effect_aspect))
	desc_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(desc_l)
	return p

func _on_arc_input(ev: InputEvent, index: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_arc_pick = index
		for i in _arc_panels.size():
			var sb: StyleBoxFlat = _arc_panels[i].get_meta("style")
			sb.border_color = Color.WHITE if i == index else _arc_panels[i].get_meta("border")
			sb.set_border_width_all(3 if i == index else 2)
		_arc_btn.disabled = false
		Sfx.play(&"card_select", -8.0)

func _take_arcanum() -> void:
	if _arc_pick >= 0:
		RunState.claim_relic(_arc_offers[_arc_pick])
		Sfx.play(&"coin", -6.0)
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
