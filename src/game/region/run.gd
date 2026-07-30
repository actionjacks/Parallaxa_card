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
const MENU_SCENE := "res://src/game/menu/menu.tscn"
const BUY_COST := 5
const THIN_COST := 3
const ENCHANT_COST := 5
const STAR_COST := 8
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
var _last_overkill: int = 0       ## Mercury from the killing blow's excess (shown once)
var _last_tax: int = 0            ## reversed-Arcana tax paid after the fight (shown once)
var _last_xp: int = 0             ## tarocista XP from the last won duel (shown once)
var _last_levels: int = 0         ## levels gained by that XP (celebrated once)
var _fight_elite: bool = false    ## the CURRENT encounter is the region's elite (map fork)
var _elite_boost: bool = false    ## elite won -> the next card offers roll with boosted rarity
var _veil_label: Label
var _prev_hp: int = -1
var _prev_rtec: int = -1
var _prev_deck: int = -1
var _prev_relics: int = -1

func _ready() -> void:
	Overlays.run_active = true
	RunState.changed.connect(_update_status)
	if RunState.load_pending:
		RunState.load_pending = false
		var omen_id := RunState.load_run()
		_load_omens()
		for o in _omens:
			if o.id == omen_id:
				_pending_omen = o
		_build_shell()
		_show_map()
		return
	var entered := RunState.next_seed
	RunState.next_seed = 0
	RunState.begin(load(JOURNEY[0]), entered)
	_build_shell()
	_start_run_flow()

func _exit_tree() -> void:
	Overlays.run_active = false

## A run opens with the Arcanum draft (pick your starting power); map afterwards.
func _start_run_flow() -> void:
	MusicLib.play(&"music_menu", 1.5)
	_refresh_backdrop()   # a restarted/repeated run returns to region 1: drop the old accent
	if RunState.region != null and not RunState.region.starting_pool.is_empty():
		_show_arcanum_draft()
	else:
		_show_map()

func _refresh_backdrop() -> void:
	if _backdrop != null:
		_backdrop.queue_free()
	_backdrop = Backdrop.build(RunState.region.accent if RunState.region != null else Color(0, 0, 0, 0))
	add_child(_backdrop)
	move_child(_backdrop, 0)

# ---------------------------------------------------------------- shell / status

var _backdrop: Control

func _build_shell() -> void:
	_backdrop = Backdrop.build(RunState.region.accent if RunState.region != null else Color(0, 0, 0, 0))
	add_child(_backdrop)
	move_child(_backdrop, 0)

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
	_veil_label = _label("", 16, Color(0.72, 0.55, 0.9))
	_veil_label.mouse_filter = Control.MOUSE_FILTER_STOP
	for l in [_hp_label, _rtec_label, _deck_label, _relics_label, _veil_label]:
		sb.add_child(l)

	_stage = Control.new()
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_stage)

func _update_status() -> void:
	if _hp_label == null:
		return   # RunState.changed can fire (begin/load) before the shell is built
	_hp_label.text = tr("RUN_HP") % [RunState.player_hp, RunState.player_max_hp]
	_rtec_label.text = tr("RUN_RTEC_NAMED" if Profile.life_stat("runs") < 3 else "RUN_RTEC") % RunState.rtec
	_deck_label.text = tr("RUN_DECK") % RunState.deck.size()
	_relics_label.text = tr("RUN_RELICS") % RunState.relics.size()
	_veil_label.text = (tr("VEIL_BADGE") % RunState.veil) if RunState.veil > 0 else ""
	_veil_label.tooltip_text = tr("VEIL_%d_DESC" % RunState.veil) if RunState.veil > 0 else ""
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
	MusicLib.play(&"music_menu", 1.5)   # the table between deals
	Profile.check_run_achievements(false)   # mid-run pops: new omens/arcana apply from the next roll
	RunState.save_run(_pending_omen.id if _pending_omen != null else "")   # the map is the safe hub: always resumable
	var root := _screen_column()
	# The region header wears the region's accent (35% toward cream keeps 720p readability).
	root.add_child(_label_center(tr(RunState.region.name_key), 30,
		RunState.region.accent.lerp(Color(0.96, 0.92, 0.82), 0.35)))
	# The road's partial rest (region transition) is announced here -- the map is its only screen.
	if _last_rest > 0:
		root.add_child(_hint(tr("REST_HEALED") % _last_rest))
		_last_rest = 0

	var ladder := HBoxContainer.new()
	ladder.alignment = BoxContainer.ALIGNMENT_CENTER
	ladder.add_theme_constant_override("separation", 16)
	var total := RunState.fights.size() + 1
	for i in total:
		var is_boss := i == RunState.fights.size()
		var label := tr("MAP_NODE_BOSS") if is_boss else (tr("MAP_NODE_FIGHT") % (i + 1))
		var mark := "✓ " if i < RunState.step else ""
		var enemy: EnemyData = (RunState.boss if RunState.boss != null else RunState.region.boss) if is_boss else RunState.fights[i]
		var chip := _node_chip(mark + label, tr(enemy.name_key), i == RunState.step, i < RunState.step, is_boss)
		if is_boss:
			chip.tooltip_text = tr(enemy.rule_key) if enemy.rule_key != "" else ""
			var rl := _label(tr("MAP_STEP_BOSS"), 10, Color(1.0, 0.7, 0.35))
			rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.get_child(0).add_child(rl)
		else:
			var sl := _label(tr("MAP_STEP_LOOT"), 10, Color(0.6, 0.64, 0.58))
			sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.get_child(0).add_child(sl)
		ladder.add_child(chip)
	root.add_child(ladder)

	if RunState.relics.size() > 0:
		var rr := HBoxContainer.new()
		rr.alignment = BoxContainer.ALIGNMENT_CENTER
		rr.add_theme_constant_override("separation", 8)
		for a in RunState.relics:
			rr.add_child(_relic_chip(a))
		root.add_child(rr)

	if _pending_omen != null:
		var ow := CenterContainer.new()
		ow.add_child(_omen_block())
		root.add_child(ow)

	root.add_child(_hint(tr("MAP_HINT")))
	var ctrls := HBoxContainer.new()
	ctrls.alignment = BoxContainer.ALIGNMENT_CENTER
	ctrls.add_theme_constant_override("separation", 12)
	var go := _button(tr("MAP_GO"), _start_encounter.bind(false))
	go.custom_minimum_size = Vector2(160, 40)
	ctrls.add_child(go)
	# The fork: this region's ELITE -- a reversed court card guarding better loot. One per region,
	# only at non-boss rungs. Priced INLINE (HP, enrage, loot), and locked on the very first rung
	# of the journey -- a fork must be a live choice, not a newcomer trap.
	var elite_ok := RunState.region.elite != null and not RunState.elite_taken 		and RunState.step < RunState.fights.size() 		and (RunState.step >= 1 or RunState.region_index >= 1 or RunState.depth > 0)
	if elite_ok:
		var el := _button(tr("MAP_ELITE") % tr(RunState.region.elite.name_key), _start_encounter.bind(true))
		el.custom_minimum_size = Vector2(160, 40)
		el.tooltip_text = tr("MAP_ELITE_TIP")
		el.add_theme_color_override("font_color", Color(0.95, 0.55, 0.5))
		ctrls.add_child(el)
	ctrls.add_child(_button(tr("VIEW_DECK"), _view_deck))
	root.add_child(ctrls)
	if elite_ok:
		root.add_child(_hint(tr("ELITE_INLINE") % [RunState.region.elite.max_hp, RunState.region.elite.enrage_step]))
	_mount(root)

func _relic_chip(a: ArcanumData) -> Control:
	var p := _panel(Color(0.11, 0.09, 0.14), Color("b23a48") if a.is_reversed else Aspects.color(a.effect_aspect))
	p.tooltip_text = tr(a.name_key) + "\n" + a.describe()
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	if a.art != null:
		var t := TextureRect.new()
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		t.texture = a.art
		t.custom_minimum_size = Vector2(22, 38)
		if a.is_reversed:
			t.flip_h = true
			t.flip_v = true   # reversed relics hang upside down everywhere they appear
			t.modulate = Color(1.0, 0.82, 0.84)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(t)
	var l := _label(tr(a.name_key), 14, Color(0.95, 0.7, 0.72) if a.is_reversed else Color(0.85, 0.8, 0.92))
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

## Fights advertise their aftermath (card + shop) and the boss carries its field rule -- the
## map must show a dying player what the road ahead actually holds.
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
	if _fight_elite:
		return RunState.region.elite
	if RunState.step < RunState.fights.size():
		return RunState.fights[RunState.step]
	return RunState.boss if RunState.boss != null else RunState.region.boss

func _start_encounter(elite: bool = false) -> void:
	_fight_elite = elite
	_statusbar.visible = false
	var debt := RunState.omen_debt
	RunState.omen_debt = 0   # the Wheel's bill is due exactly once, on the very next duel
	RunState.shuffle_for_fight()   # a duel deals from a shuffled deck, not from last duel's order
	var combat: Node = load(COMBAT_SCENE).instantiate()
	combat.setup(RunState.deck, _current_enemy(), RunState.relics,
		RunState.player_hp, RunState.player_max_hp, RunState.hand_levels, RunState.veil, RunState.depth, debt)
	combat.finished.connect(_on_combat_finished)
	_mount(combat)   # crossfade into the fight

func _on_combat_finished(won: bool, remaining_hp: int, unused_discards: int) -> void:
	var was_elite := _fight_elite
	_fight_elite = false
	if not won:
		_show_spread(false)
		return
	RunState.player_hp = remaining_hp
	var reward := _current_enemy().reward_rtec if not was_elite else RunState.region.elite.reward_rtec
	if RunState.veil >= 4:
		reward = maxi(1, reward - 1)   # Veil IV: Greedy Market
	RunState.rtec += reward
	# Overkill pays: the killing blow's excess arrived from combat as pending Mercury.
	_last_overkill = RunState.pending_overkill
	RunState.rtec += _last_overkill
	RunState.pending_overkill = 0
	# Economy legs from the design: thrift (1 per unused discard) then interest (1 per 5 held, cap 5).
	_last_thrift = mini(unused_discards, 2)   # thrift capped: hoarding discards must not print money
	RunState.rtec += _last_thrift
	@warning_ignore("integer_division")
	_last_interest = mini(RunState.rtec / 5, 5)
	RunState.rtec += _last_interest
	# Reversed-Arcana tax: RTEC_TAX prices bill after every won fight (visible on the next screen).
	_last_tax = 0
	for a: ArcanumData in RunState.relics:
		if a.is_reversed and a.price == ArcanumData.Price.RTEC_TAX:
			_last_tax += a.price_value
	if _last_tax > 0:
		RunState.rtec = maxi(0, RunState.rtec - _last_tax)
	RunState.fights_won += 1
	# The tarocista reads on: every won duel pays XP (elites double, bosses triple, depth scales).
	var is_boss := RunState.step >= RunState.fights.size() and not was_elite
	_last_xp = Profile.fight_xp(is_boss, was_elite, RunState.region_index)
	_last_levels = Profile.add_xp(_last_xp)
	if was_elite:
		RunState.elite_taken = true
		RunState.stat_elites_slain += 1
		_elite_boost = true   # the elite's prize: this rung's card offers roll with boosted rarity
	if RunState.step >= RunState.fights.size():
		RunState.stat_regions_cleared += 1
		_show_boss_choice()
		return
	_last_rest = RunState.rest()   # recover between fights so the run isn't a one-HP knife-edge
	_roll_omen()                   # the road reveals an omen; it waits on the map screen
	# Balatro cadence: EVERY won fight pays out a card pick AND a shop visit -- the economy is
	# the decision layer, so it must never hide behind the region's hardest pre-boss check.
	_show_reward()

# ---------------------------------------------------------------- REWARD

func _show_reward() -> void:
	_statusbar.visible = true
	_update_status()
	_reward_panels.clear()
	_reward_cards.clear()
	_reward_pick = -1
	var offers: Array = RunState.pick_tiered_offers(DeckLibrary.reward_pool(), 3, _elite_boost)
	var boosted := _elite_boost
	_elite_boost = false
	var rested := _last_rest
	_last_rest = 0
	var root := _screen_column()
	root.add_child(_title(tr("REWARD_TITLE")))
	if boosted:
		root.add_child(_hint(tr("ELITE_LOOT")))
	if rested > 0:
		root.add_child(_hint(tr("REST_HEALED") % rested))
	_add_econ_hints(root)
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
	_enter_shop()

func _skip_reward() -> void:
	_enter_shop()

## Fresh shop stock for this rung (reward always flows here; leaving the shop advances the run).
func _enter_shop() -> void:
	_shop_offers = RunState.pick_tiered_offers(DeckLibrary.reward_pool(), 3)
	_shop_star = RunState.pick_offers(STAR_HANDS, 1)[0]
	_shop_reroll_cost = 1
	_show_shop()

## One-shot economy hints (overkill / thrift / interest / reversed tax) shown after a fight.
func _add_econ_hints(root: VBoxContainer) -> void:
	if _last_overkill > 0:
		root.add_child(_hint(tr("REWARD_OVERKILL") % _last_overkill))
		_last_overkill = 0
	if _last_thrift > 0:
		root.add_child(_hint(tr("ECON_THRIFT") % _last_thrift))
		_last_thrift = 0
	if _last_interest > 0:
		root.add_child(_hint(tr("ECON_INTEREST") % _last_interest))
		_last_interest = 0
	if _last_tax > 0:
		var t := _label_center(tr("REWARD_TAX") % _last_tax, 15, Color(0.9, 0.45, 0.45))
		root.add_child(t)
		_last_tax = 0
	if _last_xp > 0:
		root.add_child(_hint(tr("XP_GAINED") % _last_xp))
		_last_xp = 0
	if _last_levels > 0:
		root.add_child(_label_center(tr("XP_LEVEL_UP") % [Profile.level, tr(Profile.rank_key())],
			16, Color(0.95, 0.85, 0.5)))
		_last_levels = 0

## Veil IV (Greedy Market): every shop service costs +2.
func _cost(base: int) -> int:
	return base + (2 if RunState.veil >= 4 else 0)

# ---------------------------------------------------------------- SHOP

func _show_shop() -> void:
	_statusbar.visible = true
	_update_status()
	var rested := _last_rest
	_last_rest = 0
	if _shop_offers.is_empty():
		_shop_offers = RunState.pick_tiered_offers(DeckLibrary.reward_pool(), 3)
	var root := _screen_column()
	root.add_child(_title(tr("SHOP_TITLE")))
	if rested > 0:
		root.add_child(_hint(tr("REST_HEALED") % rested))
	_add_econ_hints(root)

	# --- buy offers ---
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	for card: CardData in _shop_offers:
		var item := VBoxContainer.new()
		item.alignment = BoxContainer.ALIGNMENT_CENTER
		item.add_theme_constant_override("separation", 6)
		item.add_child(CardWidget.build(card))
		var buy := _button(tr("SHOP_BUY") % _cost(BUY_COST), _buy.bind(card))
		buy.disabled = RunState.rtec < _cost(BUY_COST)
		var w := CenterContainer.new()
		w.add_child(buy)
		item.add_child(w)
		row.add_child(item)
	root.add_child(row)

	# --- enchant: apply an edition to a deck card ---
	var ench := HBoxContainer.new()
	ench.alignment = BoxContainer.ALIGNMENT_CENTER
	ench.add_theme_constant_override("separation", 10)
	ench.add_child(_label(tr("SHOP_ENCHANT") % _cost(ENCHANT_COST), 15, Color(0.72, 0.76, 0.86)))
	var can_ench := RunState.rtec >= _cost(ENCHANT_COST) and RunState.deck.size() > 0
	for ed: CardData.Edition in [CardData.Edition.FOIL, CardData.Edition.HOLO, CardData.Edition.POLYCHROME]:
		var eb := _button(tr(CardData.edition_name_key(ed)), _enchant.bind(ed))
		eb.tooltip_text = _edition_desc(ed)
		eb.disabled = not can_ench
		ench.add_child(eb)
	root.add_child(ench)
	root.add_child(_hint(tr("ED_SUMMARY")))

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
		var sbuy := _button(tr("SHOP_STAR_BUY") % _cost(STAR_COST), _buy_star)
		sbuy.disabled = RunState.rtec < _cost(STAR_COST)
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
	var thin := _button(tr("SHOP_THIN") % _cost(THIN_COST), _thin_deck)
	thin.disabled = RunState.rtec < _cost(THIN_COST) or RunState.deck.size() <= 5
	controls.add_child(thin)
	controls.add_child(_button(tr("SHOP_NEXT"), _leave_shop))
	root.add_child(controls)
	_mount(root)

func _buy(card: CardData) -> void:
	if RunState.spend(_cost(BUY_COST)):
		RunState.stat_bought += 1
		RunState.add_card(card)
		Sfx.play(&"coin", -4.0)
		_show_shop()  # refresh prices / affordability

func _thin_deck() -> void:
	if RunState.rtec < _cost(THIN_COST) or RunState.deck.size() <= 5:
		return
	var cb := func(card: CardData) -> void:
		RunState.spend(_cost(THIN_COST))
		RunState.stat_bought += 1
		RunState.remove_card(card)
		_show_shop()
	_open_deck_picker(tr("PICK_REMOVE"), cb)

func _enchant(edition: CardData.Edition) -> void:
	if RunState.rtec < _cost(ENCHANT_COST) or RunState.deck.is_empty():
		return
	var cb := func(card: CardData) -> void:
		card.edition = edition
		RunState.spend(_cost(ENCHANT_COST))
		RunState.stat_bought += 1
		RunState.changed.emit()
		_show_shop()
	_open_deck_picker(tr("PICK_ENCHANT"), cb)

func _buy_star() -> void:
	if _shop_star >= 0 and RunState.spend(_cost(STAR_COST)):
		RunState.stat_bought += 1
		RunState.stat_star_used = true
		RunState.level_up_hand(_shop_star)
		Sfx.play(&"coin", -4.0, 1.2)
		_shop_star = -1   # one Star per visit
		_show_shop()

func _reroll_shop() -> void:
	if RunState.spend(_shop_reroll_cost):
		_shop_offers = RunState.pick_tiered_offers(DeckLibrary.reward_pool(), 3)   # the slot-machine pull
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
	var wrap_c := CenterContainer.new()
	wrap_c.add_child(_button(tr("COMMON_CANCEL"), _close_overlay.bind(overlay)))
	col.add_child(wrap_c)

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

# ---------------------------------------------------------------- BOSS CLAIM (1-of-2/3)

var _claim_offers: Array = []      ## [{arcanum, reversed}]
var _claim_panels: Array = []
var _claim_pick: int = -1
var _claim_btn: Button

## The boss reward is a CHOICE: the Arcanum upright, the same card REVERSED (stronger + a visible
## price -- the profaned-card brand), and, when the player widened the pool with Sol, one purchased
## Arcanum as a third option.
func _show_boss_choice() -> void:
	_statusbar.visible = true
	_update_status()
	var slain: EnemyData = RunState.boss if RunState.boss != null else RunState.region.boss
	var boss_arc: ArcanumData = slain.arcanum if (slain != null and slain.arcanum != null) else RunState.region.boss_arcanum
	var owned_keys: Array = []
	for r: ArcanumData in RunState.relics:
		owned_keys.append(r.name_key)
	_claim_offers = []
	if boss_arc != null:
		# Already wearing this Arcanum (bought or claimed before): only the REVERSED deepening
		# is on the table -- the same relic never stacks twice upright.
		if not owned_keys.has(boss_arc.name_key):
			_claim_offers.append({"arc": boss_arc, "rev": false})
		_claim_offers.append({"arc": boss_arc, "rev": true})
	var alts: Array = []
	for a: ArcanumData in ([] if RunState.pure_reading else Profile.boss_pool_arcana()):
		if not owned_keys.has(a.name_key) and (boss_arc == null or a.name_key != boss_arc.name_key):
			alts.append(a)
	if not alts.is_empty():
		_claim_offers.append({"arc": RunState.pick_offers(alts, 1)[0], "rev": false})
	if _claim_offers.is_empty():
		_show_complete()   # legacy region without an authored boss arcanum: nothing to claim
		return
	_claim_panels.clear()
	_claim_pick = -1
	var root := _screen_column()
	root.add_child(_title(tr("BOSSREW_TITLE")))
	_add_econ_hints(root)   # boss wins earn overkill/thrift/interest/tax too -- show them here
	root.add_child(_hint(tr("BOSSREW_HINT")))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	for i in _claim_offers.size():
		var offer: Dictionary = _claim_offers[i]
		var panel := _claim_panel(offer["arc"], offer["rev"])
		panel.gui_input.connect(_on_claim_input.bind(i))
		_claim_panels.append(panel)
		row.add_child(panel)
	root.add_child(row)
	_claim_btn = _button(tr("CLAIM_TAKE"), _take_claim)
	_claim_btn.custom_minimum_size = Vector2(200, 40)
	_claim_btn.disabled = true
	var wrap_c := CenterContainer.new()
	wrap_c.add_child(_claim_btn)
	root.add_child(wrap_c)
	_mount(root)

func _claim_panel(a: ArcanumData, reversed: bool) -> PanelContainer:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.14)
	sb.set_border_width_all(2)
	sb.border_color = Color("b23a48") if reversed else Aspects.color(a.effect_aspect)
	sb.set_corner_radius_all(4)
	for side in ["left", "top", "right", "bottom"]:
		sb.set("content_margin_" + side, 10)
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
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		t.texture = a.art
		t.custom_minimum_size = Vector2(128, 222)
		if reversed:
			t.flip_h = true
			t.flip_v = true      # the profaned card hangs upside down
			t.modulate = Color(1.0, 0.82, 0.84)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(t)
	var cap := _label(tr("BOSSREW_REVERSED") if reversed else tr("BOSSREW_UPRIGHT"), 13,
		Color("ff5a4d") if reversed else Color(0.7, 0.74, 0.68))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(cap)
	var name_l := _label(tr(a.name_key), 16, Color(0.92, 0.88, 0.95))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(name_l)
	# Describe the variant the player would GET (materialize a throwaway preview instance).
	var preview: ArcanumData = a.duplicate()
	preview.source_path = a.source_path if a.source_path != "" else a.resource_path
	if reversed:
		preview.is_reversed = true
		if preview.reversed_mult > 0.0:
			preview.effect_mult = preview.reversed_mult
		if preview.reversed_value >= 0:
			preview.effect_value = preview.reversed_value
	var desc_l := _label(preview.describe(), 13,
		Color("ff9a8d") if reversed else Aspects.color(a.effect_aspect))
	desc_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_l.custom_minimum_size = Vector2(220, 0)
	vb.add_child(desc_l)
	return p

func _on_claim_input(ev: InputEvent, index: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_claim_pick = index
		for i in _claim_panels.size():
			var sb: StyleBoxFlat = _claim_panels[i].get_meta("style")
			sb.border_color = Color.WHITE if i == index else _claim_panels[i].get_meta("border")
			sb.set_border_width_all(3 if i == index else 2)
		_claim_btn.disabled = false
		Sfx.play(&"card_select", -8.0)

func _take_claim() -> void:
	if _claim_pick < 0:
		return
	var offer: Dictionary = _claim_offers[_claim_pick]
	RunState.claim_relic(offer["arc"], offer["rev"])
	Sfx.play(&"coin", -6.0)
	_show_complete(RunState.relics[RunState.relics.size() - 1])

# ---------------------------------------------------------------- COMPLETE / SPREAD

func _show_complete(claimed: ArcanumData = null) -> void:
	_statusbar.visible = true
	_update_status()
	var final := RunState.region_index + 1 >= JOURNEY.size()
	if final:
		# The World has fallen: the run is WON (recorded once, endless deaths stay wins) and the
		# gate opens -- end the reading, or walk BEYOND into a deeper world.
		if not RunState.run_won:
			RunState.run_won = true
			Profile.record_victory(RunState.veil)
		_show_world_gate(claimed)
		return
	var root := _screen_column()
	root.add_child(_big(tr("COMPLETE_TITLE"), Color(0.65, 0.9, 0.55)))
	var relic := claimed if claimed != null else RunState.region.boss_arcanum
	if relic != null:
		if relic.art != null:
			# The claimed Arcanum is shown as the actual card -- you beat it, now you wear it.
			var t := TextureRect.new()
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			t.texture = relic.art
			t.custom_minimum_size = Vector2(160, 277)
			if relic.is_reversed:
				t.flip_h = true
				t.flip_v = true
				t.modulate = Color(1.0, 0.82, 0.84)
			var wrap_art := CenterContainer.new()
			wrap_art.add_child(t)
			root.add_child(wrap_art)
		root.add_child(_label_center(tr("COMPLETE_RELIC") % tr(relic.name_key), 20, Color(0.75, 0.65, 0.9)))
	root.add_child(_hint(tr("RUN_SUMMARY") % RunState.fights_won))
	root.add_child(_hint(tr("COMPLETE_HINT")))
	var wrap_c := CenterContainer.new()
	wrap_c.add_child(_button(tr("COMPLETE_NEXT"), _continue_journey))
	root.add_child(wrap_c)
	_mount(root)

func _continue_journey() -> void:
	var idx := RunState.region_index + 1
	_pending_omen = null
	_last_rest = RunState.enter_region(load(JOURNEY[idx]), idx)
	_refresh_backdrop()   # the backdrop takes on the new region's accent
	_show_map()

## BEYOND THE WORLD: the victory gate. The exponential vector finally has something to spend
## itself on -- every depth loops the Journey with +50% HP / +35% intents / +1 enrage.
func _show_world_gate(claimed: ArcanumData = null) -> void:
	var root := _screen_column()
	root.add_child(_big(tr("GATE_TITLE"), Color(0.95, 0.85, 0.5)))
	if claimed != null and claimed.art != null:
		var t := TextureRect.new()
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		t.texture = claimed.art
		t.custom_minimum_size = Vector2(140, 242)
		if claimed.is_reversed:
			t.flip_h = true
			t.flip_v = true
			t.modulate = Color(1.0, 0.82, 0.84)
		var wrap_art := CenterContainer.new()
		wrap_art.add_child(t)
		root.add_child(wrap_art)
	root.add_child(_hint(tr("GATE_HINT") % (RunState.depth + 1)))
	var ctrls := HBoxContainer.new()
	ctrls.alignment = BoxContainer.ALIGNMENT_CENTER
	ctrls.add_theme_constant_override("separation", 16)
	var end_btn := _button(tr("GATE_END"), func() -> void: _show_spread(true))
	end_btn.custom_minimum_size = Vector2(200, 40)
	ctrls.add_child(end_btn)
	var go_btn := _button(tr("GATE_BEYOND") % (RunState.depth + 1), _go_beyond)
	go_btn.custom_minimum_size = Vector2(200, 40)
	go_btn.add_theme_color_override("font_color", Color(0.95, 0.55, 0.5))
	ctrls.add_child(go_btn)
	root.add_child(ctrls)
	_mount(root)

func _go_beyond() -> void:
	RunState.depth += 1
	_pending_omen = null
	_last_rest = RunState.enter_region(load(JOURNEY[0]), 0)
	_refresh_backdrop()
	_show_map()

## The run's ending -- win or death -- is a tarot SPREAD laid on the table (P5). Sol, victory
## recording and the achievement sweep all happen HERE, exactly once per run.
func _show_spread(victory: bool) -> void:
	_statusbar.visible = false
	RunState.delete_run_save()
	# A death BEYOND the World is still a won reading (the victory was recorded at the gate).
	var victory_eff := victory or RunState.run_won
	RunState.stat_sol_earned = Profile.earn_run_reward(victory_eff, RunState.fights_won, RunState.veil)
	var fresh: Array = Profile.check_run_achievements(victory_eff)
	var progress: Dictionary = Profile.record_run_end(victory_eff)   # lifetime ledger + run-end XP
	var s := SpreadScreen.build(victory_eff, fresh, progress)
	s.new_run.connect(_restart_run)
	s.repeat_run.connect(_repeat_fate)
	s.to_menu.connect(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))
	MusicLib.play(&"music_menu", 3.0)
	_mount(s)
	Sfx.play(&"win" if victory else &"lose", -2.0)

## Same seed, same Veil: the deterministic contract makes "one more try" a real rematch.
func _repeat_fate() -> void:
	_pending_omen = null
	RunState.next_veil = RunState.veil
	RunState.next_pure = RunState.pure_reading   # a repeated fate keeps its purity contract
	RunState.next_daily = RunState.daily_tag
	var s := RunState.run_seed
	RunState.begin(load(JOURNEY[0]), s)
	_start_run_flow()

func _restart_run() -> void:
	_pending_omen = null
	RunState.next_veil = RunState.veil   # fresh seed, same tier (the menu changes tiers)
	RunState.next_pure = false           # a NEW fate is the player's own again
	RunState.next_daily = ""
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

## Omens live as editor-authorable .tres (data/omens/); effects resolve here by id.
var _omens: Array = []
var _pending_omen: OmenData = null

func _load_omens() -> void:
	_omens.clear()
	var dir := DirAccess.open("res://data/omens")
	if dir == null:
		return
	var files := dir.get_files()
	files.sort()
	for f in files:
		if f.ends_with(".tres"):
			var o: OmenData = load("res://data/omens/" + f)
			# Achievement-gated omens join the road pool only once earned (meta widens);
			# Pure Reading sticks to the base pool so shared fates stay identical.
			if o.requires_achievement != "" and (RunState.pure_reading or not Profile.has_achievement(o.requires_achievement)):
				continue
			_omens.append(o)

func _roll_omen() -> void:
	# Reloaded EVERY roll: achievement-gated omens really do join "from the next roll", and a
	# save/continue mid-run sees the exact same pool as the uninterrupted session (seed contract).
	_load_omens()
	if not _omens.is_empty():
		_pending_omen = RunState.pick_offers(_omens, 1)[0]

func _omen_block() -> Control:
	var p := _panel(Color(0.1, 0.09, 0.13), Color(0.7, 0.6, 0.85))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	p.add_child(row)
	var t := TextureRect.new()
	t.texture = _pending_omen.art
	t.custom_minimum_size = Vector2(64, 111)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	row.add_child(t)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 6)
	row.add_child(vb)
	vb.add_child(_label(tr("OMEN_TITLE") + ": " + tr(_pending_omen.name_key), 17, Color(0.9, 0.85, 0.95)))
	vb.add_child(_label(tr(_pending_omen.desc_key), 14, Color(0.72, 0.74, 0.82)))
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	# Pure gifts drop the fake Accept/Leave grammar -- a choice with no difference trains the
	# player that on-screen choices are decorative. Real trades keep both buttons.
	if _pending_omen.id in ["star", "temperance", "sun"]:
		btns.add_child(_button(tr("OMEN_GIFT"), _accept_omen))
	else:
		var take := _button(tr("OMEN_TAKE"), _accept_omen)
		if _pending_omen.id == "hanged" and RunState.player_hp <= 5:
			take.disabled = true   # the trade would kill you; the card refuses
		btns.add_child(take)
		btns.add_child(_button(tr("OMEN_SKIP"), _skip_omen))
	vb.add_child(btns)
	return p

func _accept_omen() -> void:
	if _pending_omen == null:
		return   # stale click (picker was cancelled or the omen already resolved)
	var id: String = _pending_omen.id
	# Picker-based omens keep the omen PENDING until a card is actually picked -- cancelling the
	# picker returns to the map with the offer intact (no silent consumption, no null crash).
	if id == "justice":
		Sfx.play(&"card_select", -8.0)
		var cb := func(card: CardData) -> void:
			_pending_omen = null
			RunState.stat_omen_taken = true
			RunState.remove_card(card)
			_show_map()
		_open_deck_picker(tr("PICK_REMOVE"), cb)
		return
	if id == "lovers":
		Sfx.play(&"card_select", -8.0)
		var twin := func(card: CardData) -> void:
			_pending_omen = null
			RunState.stat_omen_taken = true
			RunState.add_card(card)
			_show_map()
		_open_deck_picker(tr("PICK_TWIN"), twin)
		return
	_pending_omen = null
	RunState.stat_omen_taken = true
	match id:
		"star":
			RunState.player_hp = mini(RunState.player_max_hp, RunState.player_hp + 10)
			Sfx.play(&"heal", -6.0)
		"wheel":
			# Push-your-luck: the Wheel pays NOW and bills the NEXT fight (+2 on every intent,
			# folded into the intent label -- the preview never lies about the price).
			RunState.rtec += 6
			RunState.omen_debt = 2
			Sfx.play(&"coin", -6.0)
		"hanged":
			RunState.player_hp -= 5
			RunState.rtec += 8
			Sfx.play(&"coin", -6.0)
		"temperance":
			RunState.player_hp = mini(RunState.player_max_hp, RunState.player_hp + 6)
			RunState.rtec += 2
			Sfx.play(&"heal", -6.0)
		"sun":
			RunState.player_hp = mini(RunState.player_max_hp, RunState.player_hp + 12)
			Sfx.play(&"heal", -6.0)
	RunState.changed.emit()
	_show_map()

func _skip_omen() -> void:
	_pending_omen = null
	_show_map()

func _show_arcanum_draft() -> void:
	_statusbar.visible = true
	_update_status()
	MusicLib.play(&"music_menu", 1.5)
	# Achievement Arcana widen the opening pool (meta adds options, never removes them) --
	# except in Pure Reading, where a shared fate must be identical for every player.
	var pool: Array = RunState.region.starting_pool.duplicate()
	if not RunState.pure_reading:
		pool.append_array(Profile.draft_extra_arcana())
	_arc_offers = RunState.pick_offers(pool, 3)
	_arc_panels.clear()
	_arc_pick = -1
	var root := _screen_column()
	root.add_child(_title(tr("DRAFT_TITLE")))
	root.add_child(_hint(tr("DRAFT_CONTEXT")))
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
	var wrap_c := CenterContainer.new()
	wrap_c.add_child(_arc_btn)
	root.add_child(wrap_c)
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
	# Playstyle blurb (first-60s context): what it plays like, before the exact numbers.
	var bk := a.blurb_key()
	if tr(bk) != bk:
		var blurb := _label(tr(bk), 12, Color(0.62, 0.64, 0.72))
		blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(blurb)
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

func _label_center(text: String, font_size: int, color: Color) -> Label:
	var l := _label(text, font_size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
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
