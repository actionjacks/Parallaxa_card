extends Control
## Vertical slice: a playable 1v1 duel. Poker hand -> Chips x Mult -> damage, on the
## parallaxa_orange theme (monogram font + custom cursors via CursorManager autoload).
## UI is built in code for the slice; scene authoring can come later.

signal finished(won: bool, remaining_hp: int, unused_discards: int)

const DEF_ENEMY_PATH := "res://data/combat/enemy_a.tres"
const DEF_ARCANUM_PATH := "res://data/arcana/arcanum_death.tres"

var standalone: bool = true
var _start_hp: int = -1
var _max_hp: int = -1
var _levels: Dictionary = {}
var _veil: int = 0
var _depth: int = 0
var _debt: int = 0
var _law: int = 0                  ## RegionData.Law of the biome this duel is fought in
const SCAR_CHIPS := 5              ## permanent chips a card earns for felling a Major Arcana
var _prev_klatwa: int = 0
var _heartbeat: AudioStreamPlayer   ## enrage stem: owned here, never a stolen pool voice

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
var _next_intent_label: Label
var _heal_pool_label: Label
var _gnicie_label: Label
var _klatwa_label: Label
var _relic_row: HBoxContainer
var _arena: ArenaView              ## the 3D room the duel is fought in, under everything
var _portrait: EnemyPortrait       ## the opponent as a full-height plate BEHIND the arena
var _portrait_of: EnemyData        ## which enemy the plate currently shows (rebuild guard)
var _portrait_enraged := false     ## enrage ceremony fires once per fight, not once per render
var _hand_sort := 0                ## 0 dealt, 1 by rank, 2 by Aspect (DISPLAY order only)
var _sort_btn: Button
var _hint_label: Label             ## names the best hand sitting in the current hand
var _rule_label: Label
var _preview_label: Label
var _log_label: Label
var _player_hp_bar: ProgressBar
var _player_hp_label: Label
var _block_label: Label
var _turn_label: Label
var _hand_row: HandFan
var _drag_card: CardData = null
var _drag_panel: Control = null
var _drag_offset := Vector2.ZERO
var _drag_active := false
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
var _prophecy: Control = null      ## the diegetic lethal stamp (built when a kill is foretold)
var _prophecy_dmg: int = -1
var _cockpit_label: Label          ## the whole turn's math in one line (E2 cockpit)
var _enrage_label: Label           ## the visible enrage clock
var _paytable: PanelContainer      ## always-available hand chart (E3)
var _paytable_rows: Dictionary = {}   ## Poker.Hand -> Label
var _next_wrap: HBoxContainer      ## deterministic next-draws preview

func setup(deck: Array, enemy: EnemyData, p_relics: Array, start_hp: int, max_hp: int, p_levels: Dictionary = {}, p_veil: int = 0, p_depth: int = 0, p_debt: int = 0, p_law: int = 0) -> void:
	standalone = false
	_deck = deck
	_enemy = enemy
	_relics = p_relics
	_start_hp = start_hp
	_max_hp = max_hp
	_levels = p_levels
	_veil = p_veil
	_depth = p_depth
	_debt = p_debt
	_law = p_law

func _ready() -> void:
	if standalone:
		_enemy = load(DEF_ENEMY_PATH)
		_relics = [load(DEF_ARCANUM_PATH)]
		_deck = DeckLibrary.starter_deck()
	_build_ui()
	MusicLib.play(&"music_boss" if _enemy.is_boss else &"music_combat", 0.8)
	controller = CombatController.new()
	controller.state_changed.connect(_render)
	controller.message.connect(_on_message)
	controller.ended.connect(_on_ended)
	controller.awaiting_enemy.connect(_on_awaiting_enemy)
	controller.boss_turned.connect(_on_boss_turned)
	controller.start(_deck, _enemy, _relics, _start_hp, _max_hp, _levels, _veil, _depth, _debt, _law)
	if _enemy.is_boss:
		_boss_entrance()

# ---------------------------------------------------------------- UI construction

func _build_ui() -> void:
	var accent := Color(0, 0, 0, 0)
	if not standalone and RunState.region != null:
		accent = RunState.region.accent
	add_child(Backdrop.build(accent))
	# THE ROOM, in 3D, underneath everything: a floor to stand on, a wall lost in fog and one
	# warm light at the table's edge. Same SubViewport pattern as the tower, so it costs the
	# 720p budget nothing and the whole 2D HUD keeps working on top of it.
	_arena = ArenaView.new()
	_arena.set_accent(accent if accent.a > 0.0 else Color(0.55, 0.2, 0.24))
	add_child(_arena)
	# The opponent goes in BEHIND the arena, not inside its column: a portrait big enough to be
	# felt would otherwise push the hand past 720p (it has happened three times in this project).
	_portrait = EnemyPortrait.new()
	add_child(_portrait)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	# Deeper bottom margin than the sides: the action buttons live in a fixed strip down there,
	# and the taller hand cards would otherwise lie on top of them.
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
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
	_intent_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_intent_label.tooltip_text = tr("TIP_INTENT")
	erow.add_child(_intent_label)
	_next_intent_label = _label("", 14, Color(0.8, 0.5, 0.45))
	_next_intent_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_next_intent_label.tooltip_text = tr("TIP_NEXT_INTENT")
	erow.add_child(_next_intent_label)
	var ehp := HBoxContainer.new()
	ehp.add_theme_constant_override("separation", 8)
	ev.add_child(ehp)
	_enemy_hp_bar = _bar(Color(0.8, 0.25, 0.28))
	ehp.add_child(_enemy_hp_bar)
	_enemy_hp_label = _label("", 16, Color(0.9, 0.9, 0.92))
	_enemy_hp_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_enemy_hp_label.tooltip_text = tr("TIP_ENEMY_HP")
	ehp.add_child(_enemy_hp_label)
	_gnicie_label = _label("", 14, Aspects.color(Aspects.Id.DEATH))
	ev.add_child(_gnicie_label)
	_klatwa_label = _label("", 14, Color(0.85, 0.55, 0.95))
	ev.add_child(_klatwa_label)
	_rule_label = _label("", 15, Color(1.0, 0.7, 0.35))
	ev.add_child(_rule_label)
	_enrage_label = _label("", 13, Color(1.0, 0.45, 0.4))
	_enrage_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_enrage_label.tooltip_text = tr("TIP_ENRAGE")
	ev.add_child(_enrage_label)

	# --- middle: relics + enemy emblem + score readout ---
	var mid := VBoxContainer.new()
	# Breathing room: seven readouts at separation 6 read as one block of noise. The 3D room
	# behind them gives the space back, so spend it.
	mid.add_theme_constant_override("separation", 11)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(mid)
	_relic_row = HBoxContainer.new()
	_relic_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_relic_row.add_theme_constant_override("separation", 8)
	mid.add_child(_relic_row)
	# The middle column no longer carries the enemy art (it is the backdrop now) -- this spacer
	# keeps the score readout pinned low, over the portrait's chest rather than its face.
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(gap)
	_preview_label = _inked(_label("", 26, Color(0.98, 0.95, 0.8)))
	_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_preview_label)
	_preview_extra = _inked(_label("", 16, Color(0.7, 0.85, 0.95)))
	_preview_extra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_preview_extra)
	_cockpit_label = _inked(_label("", 16, Color(0.85, 0.87, 0.9)))
	_cockpit_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_cockpit_label.tooltip_text = tr("TIP_COCKPIT")
	_cockpit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_cockpit_label)
	_breakdown_label = _inked(_label("", 13, Color(0.66, 0.72, 0.62)))
	_breakdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_breakdown_label)
	_log_label = _inked(_label("", 13, Color(0.6, 0.6, 0.66)))
	# The log is history, and history is the first thing to fold away when the table gets crowded.
	# Remembered in Settings, like the paytable toggle, so a player who wants a bare arena keeps it.
	var st_log := get_node_or_null("/root/Settings")
	if st_log != null and st_log.has_method("get_value"):
		_log_label.visible = bool(st_log.call("get_value", "gameplay", "combat_log", true))
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
	_player_hp_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_player_hp_label.tooltip_text = tr("TIP_PLAYER_HP")
	prow.add_child(_player_hp_label)
	_block_label = _label("", 16, Color(0.6, 0.8, 1.0))
	_block_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_block_label.tooltip_text = tr("TIP_BLOCK")
	prow.add_child(_block_label)
	_heal_pool_label = _label("", 14, Color(0.55, 0.85, 0.6))
	_heal_pool_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_heal_pool_label.tooltip_text = tr("HEAL_POOL_TIP")
	prow.add_child(_heal_pool_label)
	_turn_label = _label("", 16, Color(0.8, 0.8, 0.85))
	_turn_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_turn_label.tooltip_text = tr("TIP_TURN")
	prow.add_child(_turn_label)
	_counters_label = _label("", 16, Color(0.62, 0.66, 0.74))
	_counters_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_counters_label.tooltip_text = tr("DECK_TIP")
	prow.add_child(_counters_label)
	# Determinism on the table: the EXACT next draws (the covenant's planning layer, visible).
	_next_wrap = HBoxContainer.new()
	_next_wrap.add_theme_constant_override("separation", 4)
	var nx := _label(tr("NEXT_DRAWS"), 13, Color(0.6, 0.64, 0.7))
	_next_wrap.add_child(nx)
	prow.add_child(_next_wrap)

	# --- hand: a Hearthstone-style fan (todo.md), not a flat row ---
	_hand_row = HandFan.new()
	_hand_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_hand_row)

	# --- controls ---
	# FIXED overlay, not part of the flow: the middle column keeps growing (boss art, breakdown,
	# Curse lines) and has TWICE pushed these buttons past 720p -- softlocking the fight. Anchored
	# to the bottom edge they can never be pushed off-screen again.
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 10)
	crow.anchor_top = 1.0
	crow.anchor_bottom = 1.0
	crow.offset_top = -34
	crow.offset_bottom = -6
	crow.offset_left = 24
	add_child(crow)
	_play_btn = Button.new()
	_play_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_play_btn.pressed.connect(_on_play)
	crow.add_child(_play_btn)
	_discard_btn = Button.new()
	_discard_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_discard_btn.pressed.connect(_on_discard)
	crow.add_child(_discard_btn)
	var st0 := get_node_or_null("/root/Settings")
	if st0 != null and st0.has_method("get_value"):
		_hand_sort = int(st0.call("get_value", "gameplay", "hand_sort", 0))
	_sort_btn = Button.new()
	_sort_btn.text = tr(["SORT_DEALT", "SORT_RANK", "SORT_ASPECT"][_hand_sort])
	_sort_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_sort_btn.tooltip_text = tr("SORT_TIP")
	_sort_btn.pressed.connect(_cycle_hand_sort)
	crow.add_child(_sort_btn)
	var log_btn := Button.new()
	log_btn.text = tr("LOG_TOGGLE")
	log_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	log_btn.tooltip_text = tr("LOG_TOGGLE_TIP")
	log_btn.pressed.connect(_toggle_log)
	crow.add_child(log_btn)
	var pt_btn := Button.new()
	pt_btn.text = tr("PAYTABLE_TOGGLE")
	pt_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pt_btn.pressed.connect(_toggle_paytable)
	crow.add_child(pt_btn)
	_hint_label = _label("", 14, Color(0.72, 0.68, 0.46))
	crow.add_child(_hint_label)
	_help_label = _label(tr("COMBAT_HELP"), 13, Color(0.5, 0.5, 0.58))
	crow.add_child(_help_label)
	_build_paytable()

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

	# Streamer Mode: the fate code stays on screen so every frame of a VOD carries the seed.
	if Juice.streamer_mode() and not standalone:
		var seed_l := _label("Fate " + RunState.seed_text(RunState.run_seed), 13, Color(0.55, 0.5, 0.65))
		seed_l.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		seed_l.offset_left = -170
		seed_l.offset_top = -26
		seed_l.offset_right = -10
		seed_l.offset_bottom = -8
		add_child(seed_l)

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
	var wrap_c := CenterContainer.new()
	wrap_c.add_child(restart)
	vb.add_child(wrap_c)

# ---------------------------------------------------------------- rendering

func _render() -> void:
	# Elites are REVERSED court cards: the name wears the reversal tag.
	_enemy_name.text = (tr("ELITE_NAME_FMT") % tr(_enemy.name_key)) if _enemy.is_elite else tr(_enemy.name_key)
	_enemy_hp_bar.max_value = controller.enemy_max_hp
	_set_bar(_enemy_hp_bar, controller.enemy_hp)
	_enemy_hp_label.text = tr("COMBAT_HP") % [controller.enemy_hp, controller.enemy_max_hp]
	# The intent as the player will FEEL it (pact + reversed-curse surcharges included) plus a
	# one-step lookahead -- planning depth: save the burst for the telegraphed rest turn.
	var intent := controller.intent_shown(controller.current_intent())
	_intent_label.text = tr("COMBAT_INTENT") % intent
	# Next-turn telegraph: a REST window is the game's tactical beat -- shout it, don't whisper.
	var raw_next := controller.next_intent()
	var nxt := controller.intent_shown(raw_next) if raw_next >= 0 else -1
	if raw_next < 0:
		# The Fool answers with YOUR blow: there is no next number to promise, so the telegraph
		# says so instead of printing a stale one from a table he never reads.
		_next_intent_label.text = tr("MIRROR_TELEGRAPH")
		_next_intent_label.add_theme_font_size_override("font_size", 15)
		_next_intent_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.8))
	elif raw_next == 0:
		_next_intent_label.text = tr("REST_TELEGRAPH")
		_next_intent_label.add_theme_font_size_override("font_size", 16)
		_next_intent_label.add_theme_color_override("font_color", Color(0.98, 0.85, 0.4))
	elif intent > 0 and nxt > int(intent * 1.4):
		_next_intent_label.text = tr("WINDUP_TELEGRAPH") % nxt
		_next_intent_label.add_theme_font_size_override("font_size", 15)
		_next_intent_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	else:
		_next_intent_label.text = tr("COMBAT_INTENT_NEXT") % nxt
		_next_intent_label.add_theme_font_size_override("font_size", 15)
		_next_intent_label.add_theme_color_override("font_color", Color(0.85, 0.58, 0.52))
	# The enrage clock, spoken: once the authored cycle ends, every turn feeds the fury.
	if controller.enrage_cycles() >= 1:
		_enrage_label.text = tr("ENRAGE_TAG") % controller.enrage_step_effective()
		if _portrait != null and not _portrait_enraged:
			_portrait_enraged = true
			_portrait.play_state("enrage")   # the plate itself turns furious, not just a label
		if not standalone and Profile.claim_once("covenant_enrage"):
			_covenant_line(tr("COVENANT_LINE_3"))
	else:
		_enrage_label.text = ""
	_enrage_label.visible = _enrage_label.text != ""
	if _prev_intent != -999 and intent != _prev_intent:
		_pulse(_intent_label)
	_prev_intent = intent
	# First-fight coaching, one line per moment, once per profile ever.
	if not standalone and controller.phase == "player":
		if controller.turn == 2 and Profile.claim_once("tip_discards"):
			_covenant_line(tr("TIP_DISCARDS"))
		elif controller.turn == 4 and Profile.claim_once("tip_deckorder"):
			_covenant_line(tr("TIP_DECK_ORDER"))
		# FIRST ENCOUNTER, ONE LINE. Every concept added since the rebuild explains itself the
		# first time the player actually meets it, rather than waiting in a glossary they have to
		# know to open. One line per concept, once per profile, forever.
		elif not standalone and RunState.region != null and RunState.region.law_key != "" \
				and Profile.claim_once("first_law"):
			_covenant_line(tr("FIRST_LAW"))
		elif _selected.size() > 1 and _veil < 4 and Profile.claim_once("first_keystone"):
			_covenant_line(tr("FIRST_KEYSTONE"))
		elif controller.banned_aspect() >= 0 and Profile.claim_once("first_ban"):
			_covenant_line(tr("FIRST_BAN"))
		elif _enemy.rule == EnemyData.Rule.INVERTED_TABLE and Profile.claim_once("first_inverted"):
			_covenant_line(tr("FIRST_INVERTED"))
		elif _enemy.rule == EnemyData.Rule.WIDE_HAND and Profile.claim_once("first_wide"):
			_covenant_line(tr("FIRST_WIDE"))
		elif not _enemy.is_boss and _enemy.rule != EnemyData.Rule.NONE \
				and Profile.claim_once("first_technique"):
			_covenant_line(tr("FIRST_TECHNIQUE"))
	_refresh_next_draws()
	if _hint_label != null:
		var ba := _best_available()
		_hint_label.text = (tr("HAND_BEST_AVAILABLE") % tr(Poker.name_key(ba))) if ba >= 0 else ""
	_refresh_cockpit(0, 0, false)
	var pool_left := controller.heal_cap - controller.heal_used
	_heal_pool_label.text = tr("COMBAT_HEAL_BUDGET") % [pool_left, controller.heal_cap]
	_heal_pool_label.add_theme_color_override("font_color",
		Color(0.5, 0.5, 0.55) if pool_left <= 0 else Color(0.55, 0.85, 0.6))
	_gnicie_label.text = (tr("COMBAT_GNICIE") % controller.enemy_gnicie) if controller.enemy_gnicie > 0 else ""
	_gnicie_label.visible = _gnicie_label.text != ""
	if controller.enemy_gnicie > _prev_gnicie:
		_pulse(_gnicie_label)
	_prev_gnicie = controller.enemy_gnicie
	_klatwa_label.text = (tr("COMBAT_KLATWA") % controller.enemy_klatwa) if controller.enemy_klatwa > 0 else ""
	_klatwa_label.visible = _klatwa_label.text != ""
	if controller.enemy_klatwa > _prev_klatwa:
		_pulse(_klatwa_label)
	_prev_klatwa = controller.enemy_klatwa
	for ch in _relic_row.get_children():
		ch.queue_free()
	for a in _relics:
		_relic_row.add_child(_relic_chip(a))
	var etint := Color(0.92, 0.5, 0.28) if _enemy.is_boss else Color(0.55, 0.7, 0.42)
	if _enemy.is_elite:
		etint = Color("b23a48")
	if _arena != null and _portrait_of != _enemy:
		# The opponent stands IN the room now. The 2D plate remains only for a foe that ships no
		# cut-out figure, so nothing ever renders as an empty frame.
		_arena.set_figure(_enemy.figure, _enemy.figure_frames)
	if _portrait != null and _portrait_of != _enemy:
		# A real tarot card LOOMS behind the arena (bosses are Major Arcana, regulars the Minor
		# courts -- the Fool's Journey). Elites hang REVERSED: the profaned card is the brand.
		_portrait.set_enemy(_enemy, etint)
		_portrait.visible = _enemy.figure == null
		_portrait_of = _enemy
	# THE LAW OF THE PLACE, stated where it is being applied. It changes chips, mult, block, hand
	# size and the heal pool in every duel of a biome, and until now it was named once, on the
	# road-choice screen, and never again -- so the player had no way to explain the numbers.
	var rule_txt: String = tr(_enemy.rule_key) if (_enemy.is_boss and _enemy.rule_key != "") else ""
	if not standalone and RunState.region != null and RunState.region.law_key != "":
		var law_txt: String = tr(RunState.region.law_key)
		rule_txt = law_txt if rule_txt == "" else law_txt + "   |   " + rule_txt
	var ban: int = controller.banned_aspect()
	if ban >= 0:
		rule_txt += "   |   " + tr("COMBAT_BANNED") % tr(Aspects.name_key(ban))
	_rule_label.text = rule_txt
	_rule_label.visible = _rule_label.text != ""
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
			panel.position = Vector2(_hand_row.size.x - 60.0, 30.0)   # dealt in from the deck side
			_widgets[card] = panel
			_animate_draw(panel)
	# DISPLAY order only -- controller.hand keeps its dealt order, so nothing about the draw,
	# the recycle or the seed contract shifts when the player rearranges what they are looking at.
	var shown: Array = _sorted_for_display(want)
	for i in shown.size():
		_hand_row.move_child(_widgets[shown[i]], i)
	for card in _selected.duplicate():
		if not want.has(card):
			_selected.erase(card)
	_refresh_card_styles()
	_hand_row.relayout()

## Sorting the hand is the difference between SEEING a flush and hunting for one. Balatro gives
## the same two orders for the same reason; here they cost nothing because the display order is
## decoupled from the deck order.
func _sorted_for_display(cards: Array) -> Array:
	var out: Array = cards.duplicate()
	match _hand_sort:
		1:  # by rank: pairs, trips and straights line up next to each other
			out.sort_custom(func(a: CardData, b: CardData) -> bool:
				if a.rank == b.rank:
					return a.aspect < b.aspect
				return a.rank > b.rank)
		2:  # by Aspect: a flush stops being a needle in a haystack
			out.sort_custom(func(a: CardData, b: CardData) -> bool:
				if a.aspect == b.aspect:
					return a.rank > b.rank
				return a.aspect < b.aspect)
	return out

func _cycle_hand_sort() -> void:
	_hand_sort = (_hand_sort + 1) % 3
	_sort_btn.text = tr(["SORT_DEALT", "SORT_RANK", "SORT_ASPECT"][_hand_sort])
	var st := get_node_or_null("/root/Settings")
	if st != null and st.has_method("set_value"):
		st.call("set_value", "gameplay", "hand_sort", _hand_sort)
	_reconcile_hand()

## The best hand SITTING in the current hand, named. It does not select anything and it does not
## say which cards -- the puzzle stays the player's -- but it turns "is there anything here?"
## from a blind 56-way search into a target worth digging for.
func _best_available() -> int:
	if controller == null or controller.hand.size() < 5:
		return -1
	var n: int = controller.hand.size()
	var best: int = Poker.Hand.HIGH_CARD
	for mask in range(1, 1 << n):
		var bits: int = 0
		var m: int = mask
		while m > 0:
			bits += m & 1
			m >>= 1
		if bits != 5:
			continue
		var cards: Array = []
		for i in n:
			if mask & (1 << i):
				cards.append(controller.hand[i])
		var h: int = Poker.evaluate(cards)
		# Compare by PAYOUT, not by enum order: the enum is legacy four-suit ranking, and in a
		# five-Aspect deck a Flush outranks a Four of a Kind.
		if Poker.value_of(h, int(_levels.get(h, 0))) > Poker.value_of(best, int(_levels.get(best, 0))):
			best = h
	return best

func _make_card(card: CardData) -> Control:
	var panel := CardWidget.build(card)
	panel.gui_input.connect(_on_card_input.bind(card))
	# No side-panel preview: hovering GROWS the card itself (HandFan.HOVER_SCALE), so a second
	# copy of the same card parked on the right was redundant furniture stealing arena space.
	# RMB still opens the full inspection overlay (CardWidget._route_rmb).
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

## Kept as a no-op seam: play/discard call it to dismiss any transient card visual.
func _hide_card_preview() -> void:
	if _preview_node != null and is_instance_valid(_preview_node):
		_preview_node.queue_free()
	_preview_node = null

# ---------------------------------------------------------------- cockpit / paytable / next draws

## The whole turn's survival math in ONE line. Without a selection: what the enemy will do to
## you as-is. With one: your blow AND the counter-blow, both exact (the covenant, condensed).
func _refresh_cockpit(eff_dmg: int, play_block: int, lethal: bool) -> void:
	if _cockpit_label == null or controller == null:
		return
	var taken := controller.predicted_taken(play_block, eff_dmg)
	# The play's OWN price (riposte / frail / blood tax) lands before the enemy turn, so the
	# cockpit has to spend it too -- otherwise the promised HP is one the game will not honour.
	var self_cost := controller.predicted_self_damage(eff_dmg, _selected)
	var hp_after: int = maxi(0, controller.player_hp - taken - self_cost)
	# The Fool's number is the staged blow reflected: show THAT, live, not the stale one.
	var shown_intent: int = controller.mirror_intent(eff_dmg) if (_enemy != null
		and _enemy.rule == EnemyData.Rule.FOOL_MIRROR and eff_dmg > 0) else controller.current_intent()
	var you := tr("COCKPIT_YOU") % [controller.intent_shown(shown_intent),
		controller.player_block + play_block, controller.player_hp, hp_after]
	if eff_dmg > 0:
		var ehp_after: int = maxi(0, controller.enemy_hp - eff_dmg)
		_cockpit_label.text = (tr("COCKPIT_ENEMY") % [controller.enemy_hp, ehp_after]) + "   |   " + you
	else:
		_cockpit_label.text = you
	var col := Color(0.85, 0.87, 0.9)
	if lethal:
		col = Color(0.98, 0.85, 0.4)
	elif hp_after < int(controller.player_max_hp * 0.4):
		col = Color(1.0, 0.55, 0.5)
	_cockpit_label.add_theme_color_override("font_color", col)

## The hand paytable: every scoreable hand with its LEVELED chips x mult -- always available,
## because nobody can scheme toward a Flush they cannot price. Toggle persists in Settings.
func _build_paytable() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.11, 0.88)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.35, 0.33, 0.45)
	sb.set_corner_radius_all(3)
	for side in ["left", "top", "right", "bottom"]:
		sb.set("content_margin_" + side, 8)
	_paytable = PanelContainer.new()
	_paytable.add_theme_stylebox_override("panel", sb)
	_paytable.position = Vector2(16, 150)
	_paytable.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paytable.add_child(vb)
	var title := _label(tr("PAYTABLE_TITLE"), 13, Color(0.8, 0.76, 0.88))
	vb.add_child(title)
	# Listed cheapest-first by PAYOUT, not by enum order -- with five Aspects the Flush
	# outranks a Four of a Kind, and a chart that lied about that would teach the wrong play.
	var _ordered: Array = Poker.BASE.keys()
	_ordered.sort_custom(func(a, b): return Poker.value_of(a) < Poker.value_of(b))
	for hand in _ordered:
		var row := _label("", 13, Color(0.66, 0.68, 0.76))
		vb.add_child(row)
		_paytable_rows[hand] = row
	add_child(_paytable)
	_refresh_paytable_values()
	var on := true
	var st := get_node_or_null("/root/Settings")
	if st != null and st.has_method("get_value"):
		on = bool(st.call("get_value", "gameplay", "paytable", true))
	_paytable.visible = on

func _refresh_paytable_values() -> void:
	for hand in _paytable_rows:
		var base: Array = Poker.leveled_base(hand, int(_levels.get(hand, 0)))
		var lv := int(_levels.get(hand, 0))
		var txt := "%s  %d x %s" % [tr(Poker.name_key(hand)), int(base[0]), String.num(float(base[1]), 1)]
		if lv > 0:
			txt += "  (Lv%d)" % (lv + 1)
		(_paytable_rows[hand] as Label).text = txt

func _highlight_paytable(hand: int) -> void:
	if _paytable == null:
		return
	_refresh_paytable_values()
	for h in _paytable_rows:
		(_paytable_rows[h] as Label).add_theme_color_override("font_color",
			Color(0.98, 0.85, 0.4) if h == hand else Color(0.66, 0.68, 0.76))

func _toggle_log() -> void:
	if _log_label == null:
		return
	_log_label.visible = not _log_label.visible
	var st := get_node_or_null("/root/Settings")
	if st != null and st.has_method("set_value"):
		st.call("set_value", "gameplay", "combat_log", _log_label.visible)

func _toggle_paytable() -> void:
	if _paytable == null:
		return
	_paytable.visible = not _paytable.visible
	var st := get_node_or_null("/root/Settings")
	if st != null and st.has_method("set_value"):
		st.call("set_value", "gameplay", "paytable", _paytable.visible)

## The next cards the deck WILL deal, in order -- determinism made visible and countable.
func _refresh_next_draws() -> void:
	if _next_wrap == null or controller == null:
		return
	# queue_free() alone leaves the node counted until end of frame -- a while-loop on
	# get_child_count() would spin forever and freeze the whole game (it did).
	for i in range(_next_wrap.get_child_count() - 1, 0, -1):
		var old := _next_wrap.get_child(i)
		_next_wrap.remove_child(old)
		old.queue_free()
	for c: CardData in controller.peek_draw(2):
		var mini_p := Panel.new()
		var msb := StyleBoxFlat.new()
		msb.bg_color = Color(0.09, 0.09, 0.13)
		msb.set_border_width_all(1)
		msb.border_color = Aspects.color(c.aspect)
		msb.set_corner_radius_all(2)
		mini_p.add_theme_stylebox_override("panel", msb)
		mini_p.custom_minimum_size = Vector2(20, 24)
		mini_p.mouse_filter = Control.MOUSE_FILTER_STOP
		mini_p.tooltip_text = "%s %s" % [c.rank_glyph(), tr(Aspects.name_key(c.aspect))] 			+ (("\n" + tr(CardData.keyword_name_key(c.keyword)) + " " + str(c.keyword_value)) if c.keyword != CardData.Keyword.NONE else "")
		var gl := _label(c.rank_glyph(), 13, Aspects.color(c.aspect))
		gl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mini_p.add_child(gl)
		_next_wrap.add_child(mini_p)

# ---------------------------------------------------------------- prophecy ceremony

## The PROPHECY STAMP: when the selection is lethal, the game does not hint -- it FORETELLS.
## A diegetic tarot-plate stamp over the arena carries the promised number, the hand, the
## overkill payout and the fate code (every screenshot self-captions with a replayable seed).
## The heartbeat starts BEFORE the click: the click is the punchline, not the reveal.
func _set_prophecy(lethal: bool, dmg: int, hand: int, bonus: int) -> void:
	if not lethal:
		if _prophecy != null:
			_prophecy.queue_free()
			_prophecy = null
			_prophecy_dmg = -1
			_calm_heartbeat()
		return
	if _prophecy != null and _prophecy_dmg == dmg:
		return
	if _prophecy != null:
		_prophecy.queue_free()
	_prophecy_dmg = dmg
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.05, 0.09, 0.94)
	sb.set_border_width_all(3)
	sb.border_color = Color(0.95, 0.8, 0.35)
	sb.set_corner_radius_all(4)
	for side in ["left", "top", "right", "bottom"]:
		sb.set("content_margin_" + side, 14)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(vb)
	var title := _label(tr("PROPHECY_TITLE"), 15, Color(0.8, 0.68, 0.9))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var num := _label(str(dmg), 54, Color(0.98, 0.85, 0.4))
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(num)
	var sub_text := tr(Poker.name_key(hand))
	if bonus > 0:
		sub_text += "   " + tr("PREVIEW_OVERKILL") % bonus
	var sub := _label(sub_text, 15, Color(0.9, 0.86, 0.8))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	if not standalone:
		var fate := _label("Fate " + RunState.seed_text(RunState.run_seed), 11, Color(0.55, 0.5, 0.65))
		fate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(fate)
	# One-shot covenant proof, spoken at the FIRST foretold death ever.
	if Profile.claim_once("covenant_lethal"):
		var vow := _label(tr("COVENANT_LINE_2"), 13, Color(0.75, 0.62, 0.85))
		vow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(vow)
	p.position = Vector2(640 - 170, 190)
	p.custom_minimum_size = Vector2(340, 0)
	p.pivot_offset = Vector2(170, 70)
	_fx.add_child(p)
	_prophecy = p
	if not Juice.reduce_motion():
		p.scale = Vector2(0.8, 0.8)
		p.modulate.a = 0.0
		var tw := create_tween().set_parallel()
		tw.tween_property(p, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 1.0, 0.14)
	Sfx.play(&"card_select", -6.0, 0.6)
	_tense_heartbeat()

## A short diegetic line floated over the arena (the covenant speaking, once).
## Sits in the quiet band between the breakdown and the player bar -- clear of the relic row.
func _covenant_line(text: String) -> void:
	var l := _label(text, 14, Color(0.8, 0.7, 0.9))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	l.offset_top = 505
	_fx.add_child(l)
	l.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.3)
	tw.tween_interval(3.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)

## Heartbeat under a foretold kill: audible tension before the click.
func _tense_heartbeat() -> void:
	var stream := MusicLib.heartbeat_stream()
	if stream == null:
		return
	if _heartbeat == null:
		_heartbeat = AudioStreamPlayer.new()
		_heartbeat.bus = &"Music"
		_heartbeat.stream = stream
		add_child(_heartbeat)
	if not _heartbeat.playing:
		_heartbeat.volume_db = -30.0
		_heartbeat.play()
	create_tween().tween_property(_heartbeat, "volume_db", -8.0, 0.4)

## Prophecy withdrawn: settle the heartbeat back to whatever the enrage clock demands.
func _calm_heartbeat() -> void:
	if _heartbeat == null or not _heartbeat.playing:
		return
	var c := controller.enrage_cycles() if controller != null else 0
	if c >= 1:
		create_tween().tween_property(_heartbeat, "volume_db", minf(0.0, -10.0 + 3.0 * (c - 1)), 0.4)
	else:
		var tw := create_tween()
		tw.tween_property(_heartbeat, "volume_db", -60.0, 0.4)
		tw.tween_callback(_heartbeat.stop)

## The fulfilled prophecy: the counter rolls to EXACTLY the foretold number, then the world
## flinches (hitstop + flash + shake). "As written."
func _fulfill_prophecy(promised: int) -> void:
	if _prophecy != null:
		_prophecy.queue_free()
		_prophecy = null
		_prophecy_dmg = -1
	var num := _label("0", 64, Color(0.98, 0.85, 0.4))
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.set_anchors_preset(Control.PRESET_TOP_WIDE)
	num.offset_top = 220
	_fx.add_child(num)
	if Juice.reduce_motion():
		num.text = str(promised)
		var done := _label(tr("PROPHECY_FULFILLED"), 15, Color(0.8, 0.7, 0.9))
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		done.set_anchors_preset(Control.PRESET_TOP_WIDE)
		done.offset_top = 300
		_fx.add_child(done)
		var tw0 := create_tween()
		tw0.tween_interval(1.2)
		tw0.tween_callback(num.queue_free)
		tw0.tween_callback(done.queue_free)
		return
	var steps := 16
	var tw := create_tween()
	for i in steps:
		var v := int(round(float(promised) * float(i + 1) / float(steps)))
		tw.tween_callback(func() -> void:
			num.text = str(v)
			Sfx.play(&"card_select", -14.0, 0.7 + 0.05 * i))
		tw.tween_interval(0.045)
	tw.tween_callback(func() -> void:
		Juice.hitstop(0.12)
		Juice.flash(_fx, Color(1, 0.95, 0.8, 0.4), 0.35)
		Juice.shake(self, 9.0)
		Sfx.play(&"hit", 0.0, 0.8)
		var done := _label(tr("PROPHECY_FULFILLED"), 16, Color(0.85, 0.75, 0.95))
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		done.set_anchors_preset(Control.PRESET_TOP_WIDE)
		done.offset_top = 300
		_fx.add_child(done)
		var out := create_tween()
		out.tween_interval(1.0)
		out.tween_property(num, "modulate:a", 0.0, 0.5)
		out.parallel().tween_property(done, "modulate:a", 0.0, 0.5)
		out.tween_callback(num.queue_free)
		out.tween_callback(done.queue_free))

## Glass pays its price on camera: shards + flash at the impact point.
func _shatter_fx(at: Vector2, count: int) -> void:
	Sfx.play(&"shatter", -4.0)
	if Juice.reduce_motion():
		return
	Juice.flash(_fx, Color(1, 1, 1, 0.25), 0.2)
	for i in 8 * count:
		var shard := ColorRect.new()
		shard.color = Color(0.95, 0.9, 1.0, 0.9)
		shard.size = Vector2(randf_range(3, 7), randf_range(3, 7))
		shard.position = at
		shard.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fx.add_child(shard)
		var dir := Vector2(randf_range(-90, 90), randf_range(-110, 30))
		var tw := create_tween().set_parallel()
		tw.tween_property(shard, "position", at + dir, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(shard, "modulate:a", 0.0, 0.5)
		tw.chain().tween_callback(shard.queue_free)

## The Great Work: a one-time reveal the first time MAGNUM OPUS is ever assembled.
func _magnum_reveal() -> void:
	if Profile.claim_once("magnum_reveal"):
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.55)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fx.add_child(dim)
		var big := _label(tr("HAND_MAGNUM_OPUS"), 64, Color(0.98, 0.85, 0.4))
		big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		big.set_anchors_preset(Control.PRESET_TOP_WIDE)
		big.offset_top = 250
		big.pivot_offset = Vector2(640, 40)
		_fx.add_child(big)
		var sub := _label(tr("MAGNUM_REVEAL_SUB"), 17, Color(0.85, 0.8, 0.9))
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
		sub.offset_top = 330
		_fx.add_child(sub)
		Sfx.play(&"win", -2.0, 1.3)
		Juice.flash(_fx, Color(1, 0.9, 0.5, 0.35), 0.5)
		if not Juice.reduce_motion():
			big.scale = Vector2(0.6, 0.6)
			create_tween().tween_property(big, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var tw := create_tween()
		tw.tween_interval(1.8)
		for n: Control in [dim, big, sub]:
			tw.parallel().tween_property(n, "modulate:a", 0.0, 0.5)
		tw.tween_callback(dim.queue_free)
		tw.tween_callback(big.queue_free)
		tw.tween_callback(sub.queue_free)
	else:
		_popup(tr("HAND_MAGNUM_OPUS"), Color(0.98, 0.85, 0.4), _enemy_fx_pos() + Vector2(-40, 40), 30)

# ---------------------------------------------------------------- interaction

## Click toggles selection; DRAGGING a card up onto the arena selects it (todo.md drag&drop),
## dropping it back into the hand cancels. The fan snaps everything home afterwards.
func _on_card_input(event: InputEvent, card: CardData) -> void:
	if controller.phase != "player":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_card = card
			_drag_panel = _widgets.get(card)
			_drag_active = false
			if _drag_panel != null:
				_drag_offset = _drag_panel.get_global_mouse_position() - _drag_panel.global_position
		else:
			var was_drag := _drag_active
			var dropped_on_arena := false
			if was_drag and _drag_panel != null:
				dropped_on_arena = _drag_panel.get_global_mouse_position().y < _hand_row.get_global_rect().position.y - 4.0
				_drag_panel.z_index = 0
			_drag_card = null
			_drag_panel = null
			_drag_active = false
			if was_drag:
				if dropped_on_arena and not _selected.has(card) and _selected.size() < 5:
					_selected.append(card)
					Sfx.play(&"card_select", -8.0)
				_refresh_card_styles()
				_update_selection_ui()
				return
			# plain click: toggle
			if _selected.has(card):
				_selected.erase(card)
				Sfx.play(&"card_select", -8.0, 0.85)
			elif _selected.size() < 5:
				_selected.append(card)
				Sfx.play(&"card_select", -8.0)
			_refresh_card_styles()
			_update_selection_ui()
	elif event is InputEventMouseMotion and _drag_card == card and _drag_panel != null:
		var mouse := _drag_panel.get_global_mouse_position()
		if not _drag_active and (mouse - (_drag_panel.global_position + _drag_offset)).length() > 14.0:
			_drag_active = true
			_drag_panel.z_index = 2
			_drag_panel.rotation_degrees = 0.0
		if _drag_active:
			_drag_panel.global_position = mouse - _drag_offset

func _refresh_card_styles() -> void:
	var any := not _selected.is_empty()
	for card in _widgets:
		var w: Control = _widgets[card]
		CardWidget.set_selected(w, _selected.has(card))
		# Selection order IS play order, so every staged card wears its position and the last one
		# wears the Keystone mark -- the doubled card has to be visible before the click, not after.
		var pos: int = _selected.find(card)
		# Veil IV switches the Keystone OFF (controller._ctx: "keystone": veil < 4). Painting the
		# gold badge anyway told the player a card would score double when it would not.
		var keystone_live: bool = _veil < 4
		CardWidget.set_order(w, pos, keystone_live and pos >= 0
			and pos == _selected.size() - 1 and _selected.size() > 1)
		# While a play is staged, the bench dims -- the chosen cards become countable at a glance.
		w.modulate.a = 1.0 if (not any or _selected.has(card)) else 0.82
	_hand_row.relayout()

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
	_play_btn.text = (tr("COMBAT_PLAY_N") % _selected.size()) if has_sel else tr("COMBAT_PLAY")
	_play_btn.disabled = not (is_player and has_sel)
	_discard_btn.text = tr("COMBAT_DISCARD") % controller.discards_left
	_discard_btn.disabled = not (is_player and has_sel and controller.discards_left > 0)
	if not has_sel:
		_preview_label.text = tr("COMBAT_SELECT_HINT")
		_preview_extra.text = ""
		_breakdown_label.text = ""
		_set_prophecy(false, 0, 0, 0)
		_refresh_cockpit(0, 0, false)
		_highlight_paytable(-1)
		return
	var r := controller.preview(_selected_indices())
	# One-shot diegetic covenant line: the FIRST preview ever asserts the promise out loud.
	if Profile.claim_once("covenant_preview"):
		_covenant_line(tr("COVENANT_LINE_1"))
	var hand_name := tr(Poker.name_key(int(r["hand"])))
	var lv := int(_levels.get(int(r["hand"]), 0))
	if lv > 0:
		hand_name += " Lv%d" % (lv + 1)   # shown as the human level (base = Lv1)
	# Boss rules may bend the scored damage (Strength's resist): the preview shows the number
	# that will actually LAND -- the covenant never lies through a rule.
	var eff := controller.effective_damage(int(r["damage"]), _selected.size())
	_preview_label.text = tr("COMBAT_PREVIEW") % [
		hand_name, int(r["chips"]), float(r["mult"]), eff,
	]
	var parts: Array = []
	if int(r["block"]) > 0:
		parts.append(tr("COMBAT_TAG_BLOCK") % int(r["block"]))
	if int(r["heal"]) > 0:
		parts.append(tr("COMBAT_TAG_HEAL") % int(r["heal"]))
	if int(r.get("heal_raw", 0)) > int(r["heal"]):
		parts.append(tr("COMBAT_TAG_HEAL_CAP"))
	if int(r["gnicie"]) > 0:
		parts.append(tr("COMBAT_TAG_GNICIE") % int(r["gnicie"]))
	# The covenant's showpiece: the preview ANNOUNCES the kill and its overkill payout --
	# rendered as the PROPHECY STAMP, not a text tag (this is the game's clip).
	var lethal_now := eff >= controller.enemy_hp
	@warning_ignore("integer_division")
	var bonus: int = clampi((eff - controller.enemy_hp) / 50, 0, 5) if lethal_now else 0
	if lethal_now:
		var lethal := tr("PREVIEW_LETHAL")
		if bonus > 0:
			lethal += "  " + tr("PREVIEW_OVERKILL") % bonus
		parts.append(lethal)
	if not lethal_now:
		var rip := controller.riposte_for(eff)
		if rip > 0:
			parts.append(tr("PREVIEW_RIPOSTE") % rip)
		var frail := controller.frail_tax(_selected)
		if frail > 0:
			parts.append(tr("PREVIEW_FRAIL") % frail)
	_set_prophecy(lethal_now, eff, int(r["hand"]), bonus)
	# Glass warning: a selected Overload card at durability 1 will SHATTER with this play.
	for card in _selected:
		if card.keyword == CardData.Keyword.PRZECIAZENIE and card.keyword_value - card.wear <= 1:
			parts.append(tr("PREVIEW_SHATTER"))
			break
	# SACRIFICE WARNING. The preview warned about glass and said nothing about the Ofiara, which
	# destroys its left-hand neighbour outright and erases it from the RUN deck after a win. The
	# information was already in hand -- Scoring returns "devoured" -- it simply was not shown.
	var eaten: int = int(r.get("devoured", -1))
	if eaten >= 0 and eaten < _selected.size():
		var victim: CardData = _selected[eaten]
		parts.append(tr("PREVIEW_OFIARA") % [victim.rank_glyph(), tr(Aspects.name_key(victim.aspect))])
	_preview_extra.text = "    ".join(parts)
	_breakdown_label.text = _mult_breakdown(int(r["hand"]))
	_refresh_cockpit(eff, int(r["block"]), lethal_now)
	_highlight_paytable(int(r["hand"]))

## Human-readable "why is the mult that value": leveled hand base + relic / Furia / Curse factors.
func _mult_breakdown(hand: int) -> String:
	var lv := int(_levels.get(hand, 0))
	var base_mult := float(Poker.leveled_base(hand, lv)[1])
	var mods: Array = ["%s x%s" % [tr(Poker.name_key(hand)), String.num(base_mult, 1)]]
	if controller.enemy_klatwa > 0:
		mods.append("%s +%d%%" % [tr("KW_KLATWA"), controller.enemy_klatwa])
	var aspects := {}
	var has_furia := false
	var polys := 0
	var glass := 0
	var card_block := 0
	var kombinat_mult := 1.0
	for c in _selected:
		aspects[c.aspect] = true
		if c.keyword == CardData.Keyword.FURIA:
			has_furia = true
		elif c.keyword == CardData.Keyword.OSLONA:
			card_block += c.keyword_value
		elif c.keyword == CardData.Keyword.PRZECIAZENIE:
			glass += 1
		elif c.keyword == CardData.Keyword.KOMBINAT:
			kombinat_mult *= 1.0 + (c.keyword_value / 100.0) * controller.kombinat_streak(hand)
		if c.edition == CardData.Edition.POLYCHROME:
			polys += 1
	# Furia's gate in Scoring runs BEFORE relic block is added -- mirror that here (card block
	# only), or the breakdown would omit a x1.5 that IS in the scored damage.
	if has_furia and card_block == 0:
		mods.append("%s x1.5" % tr("KW_FURIA"))
	if not is_equal_approx(kombinat_mult, 1.0):
		mods.append("%s x%s" % [tr("KW_KOMBINAT"), String.num(kombinat_mult, 2)])
	if glass > 0:
		mods.append("%s x%d" % [tr("KW_PRZECIAZENIE"), int(pow(2, glass))])
	# The Magician stretches other relics' xMult; show the EFFECTIVE factor, never a lie.
	var k := 1.0
	for relic in _relics:
		if relic.effect == ArcanumData.Effect.MAGNIFY:
			k = maxf(k, 3.0 if relic.is_reversed else 2.0)
	for relic in _relics:
		if relic.effect == ArcanumData.Effect.MULT_IF_ASPECT and aspects.has(relic.effect_aspect):
			mods.append("%s x%s" % [tr(relic.name_key), String.num(1.0 + (relic.effect_mult - 1.0) * k, 1)])
		elif relic.effect == ArcanumData.Effect.PACT_MULT:
			mods.append("%s x%s" % [tr(relic.name_key), String.num(1.0 + (relic.effect_mult - 1.0) * k, 2)])
		elif relic.effect == ArcanumData.Effect.MAGNIFY:
			mods.append("%s x%s" % [tr(relic.name_key), String.num(relic.effect_mult, 2)])
	if polys > 0:
		mods.append("%s x%s" % [tr("ED_POLYCHROME"), String.num(pow(1.3, polys), 1)])
	return "Mult:  " + "   ".join(mods)

func _on_play() -> void:
	if _selected.is_empty():
		return
	var idx := _selected_indices()
	# Read the fate BEFORE committing: if the preview foretells the kill, the resolution must
	# be the ceremony (counter rolling to the exact promised number), not a surprise.
	var pre := controller.preview(idx)
	var promised := controller.effective_damage(int(pre["damage"]), _selected.size())
	var foretold_kill := promised >= controller.enemy_hp
	var pre_destroyed := controller.destroyed_cards.size()
	_hide_card_preview()
	# THE RECKONING: score the hand card by card before the blow lands. Nothing here decides
	# anything -- Scoring.score already did, and the preview already said so -- but a play that
	# resolves in one silent tick reads as arithmetic. Card by card it reads as a hand coming in.
	var played_cards: Array = _selected.duplicate()
	await _reckoning(played_cards, int(pre["chips"]), float(pre["mult"]), promised)
	if controller == null or controller.phase != "player":
		return                       # the fight ended (or restarted) while the ceremony played
	for card in played_cards:
		if _widgets.has(card):
			_fly_card(_widgets[card], _enemy_fx_pos())
			_widgets.erase(card)
	_selected.clear()
	_fx_index = 0
	_emblem_hit()
	Sfx.play(&"card_play", -6.0)
	controller.play(idx)
	var shattered := controller.destroyed_cards.size() - pre_destroyed
	if shattered > 0:
		_shatter_fx(_enemy_fx_pos(), shattered)
	if int(controller.last_score.get("hand", -1)) == Poker.Hand.MAGNUM_OPUS:
		_magnum_reveal()
	if foretold_kill and controller.enemy_hp <= 0:
		_fulfill_prophecy(promised)

## The boss crosses half health: the plate flares, the screen shakes and the line is spoken.
## The clock is now a step hotter and the enrage label already says so.
func _on_boss_turned() -> void:
	if _portrait != null:
		_portrait.play_state("enrage")
	Juice.flash(_fx, Color(0.9, 0.2, 0.2, 0.34), 0.5)
	_shake(7.0)
	_covenant_line(tr("BOSS_TURNS_LINE"))

## THE ENTRANCE. A boss that rewrites the rules has to state them before the first card is
## played, or the fight is an ambush rather than a puzzle. Name, rule, and a beat of silence.
func _boss_entrance() -> void:
	var card := Control.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.03, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(dim)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)
	var name_l := _inked(_label(tr(_enemy.name_key), 46, Color(0.98, 0.9, 0.62)))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_l)
	if _enemy.rule_key != "":
		var rule_l := _inked(_label(tr(_enemy.rule_key), 17, Color(1.0, 0.72, 0.45)))
		rule_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rule_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rule_l.custom_minimum_size = Vector2(720, 0)
		col.add_child(rule_l)
	Sfx.play(&"lose", -8.0)
	var hold: float = 0.7 if Juice.fast_pace() else 1.9
	var tw := create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.25).from(0.0)
	tw.tween_interval(hold)
	tw.tween_property(card, "modulate:a", 0.0, 0.45)
	tw.tween_callback(card.queue_free)

## Card-by-card scoring ceremony (Balatro's "each card fires" beat, tarot-flavoured).
## PURELY presentational: the numbers shown are read off the same Scoring.score result the
## preview already promised, so the covenant holds -- the ceremony can never disagree with it.
func _reckoning(cards: Array, total_chips: int, mult: float, final_dmg: int) -> void:
	if cards.is_empty():
		return
	var quick := Juice.fast_pace() or Juice.reduce_motion()
	var beat: float = 0.055 if quick else 0.16
	# Base chips of the hand itself = total minus what the individual cards contributed.
	var card_chips := 0
	for c: CardData in cards:
		card_chips += c.chip_value()
	var running: int = maxi(0, total_chips - card_chips)
	_score_readout(running, mult)
	for c: CardData in cards:
		var panel: Control = _widgets.get(c)
		if panel != null and is_instance_valid(panel) and not Juice.reduce_motion():
			# the firing card jumps forward and flashes in its Aspect colour
			panel.z_index = 12
			var tw := create_tween()
			tw.tween_property(panel, "scale", Vector2(1.22, 1.22), beat * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(panel, "scale", Vector2.ONE, beat * 0.7).set_trans(Tween.TRANS_SINE)
			_popup("+%d" % c.chip_value(), Aspects.color(c.aspect),
				panel.global_position + Vector2(CardWidget.CARD_SIZE.x * 0.5 - 12.0, -18.0), 22)
		running += c.chip_value()
		_score_readout(running, mult)
		Sfx.play(&"card_play", -14.0, 0.9 + 0.06 * float(cards.find(c)))
		await get_tree().create_timer(beat).timeout
		if controller == null:
			return
	# the product lands: chips x mult, spoken as one number
	_score_readout(running, mult, final_dmg)
	if not quick:
		await get_tree().create_timer(beat * 1.6).timeout

## The two halves of the score, kept VISIBLY separate (chips on the left, mult on the right)
## so the player learns which lever a card actually pulls.
func _score_readout(chips: int, mult: float, product: int = -1) -> void:
	if _preview_label == null:
		return
	if product >= 0:
		_preview_label.text = tr("SCORE_PRODUCT") % [chips, String.num(mult, 1), product]
		_pulse(_preview_label)
	else:
		_preview_label.text = tr("SCORE_RUNNING") % [chips, String.num(mult, 1)]

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
			@warning_ignore("integer_division")
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
		"LOG_PACT":
			_popup("-" + str(int(args[0])), Color(1.0, 0.4, 0.6), _player_fx_pos(), 20)
			Sfx.play(&"rot", -6.0)
		"LOG_CLEANSE":
			_popup(tr("COMBAT_CLEANSED"), Color(0.75, 0.8, 1.0), _enemy_fx_pos(), 18)
		"LOG_MOON_MEND":
			_popup("+" + str(int(args[0])), Color(0.75, 0.8, 1.0), _enemy_fx_pos(), 20)
			Sfx.play(&"heal", -8.0, 0.7)
		"LOG_HEAL_CAPPED":
			_popup(tr("COMBAT_HEAL_CAPPED"), Color(0.6, 0.62, 0.58), _player_fx_pos(), 16)
		"LOG_RIPOSTE", "LOG_FRAIL":
			_popup("-" + str(int(args[0])), Color(1.0, 0.55, 0.4), _player_fx_pos(), 20)
			Sfx.play(&"player_hit", -8.0, 1.2)
		"LOG_STAR_REGEN":
			_popup("+" + str(int(args[0])), Color(0.85, 0.9, 1.0), _enemy_fx_pos(), 20)
			Sfx.play(&"heal", -9.0, 0.8)
		"LOG_ATTACK":
			if int(args[0]) > 0:
				_popup("-" + str(int(args[0])), Color(1.0, 0.5, 0.4), _player_fx_pos())
				_hit_flash()
				if _arena != null:
					_arena.recoil(1.0)   # the room flinches away when the blow lands on YOU
				Sfx.play(&"player_hit", -4.0)
			else:
				_popup(tr("COMBAT_BLOCKED"), Color(0.6, 0.8, 1.0), _player_fx_pos(), 20)
				Sfx.play(&"block", -4.0)

## After the player's play resolves and animates, pause a beat, then let the enemy act.
func _on_awaiting_enemy() -> void:
	_fx_index = 0
	# Fast pace (streamer/settings): the beat between turns shrinks, dead air dies.
	var beat := 0.12 if Juice.fast_pace() else 0.35
	var wind := 0.06 if Juice.fast_pace() else 0.12
	await get_tree().create_timer(beat).timeout
	if controller == null or controller.phase != "enemy":
		return
	# wind-up: the enemy tenses (scale + reddish flash) so its attack has a visible cause
	_enemy_panel.pivot_offset = _enemy_panel.size * 0.5
	if _portrait != null:
		_portrait.play_state("windup")   # the plate gathers itself before it swings
	var tw := create_tween()
	tw.tween_property(_enemy_panel, "scale", Vector2(1.03, 1.03), wind)
	tw.parallel().tween_property(_enemy_panel, "modulate", Color(1.5, 0.85, 0.85), wind)
	tw.tween_property(_enemy_panel, "scale", Vector2.ONE, wind)
	tw.parallel().tween_property(_enemy_panel, "modulate", Color.WHITE, wind)
	await tw.finished
	if controller != null and controller.phase == "enemy":
		if _portrait != null:
			_portrait.play_state("attack")
		controller.resolve_enemy_turn()
		_update_heartbeat()

## Enrage heartbeat stem: starts after the first full cycle, swells with each further cycle.
## Driven purely by the deterministic intent index -- the fight's clock is audible.
func _update_heartbeat() -> void:
	if controller == null:
		return
	var c := controller.enrage_cycles()
	if c < 1:
		return
	var target_db := minf(0.0, -10.0 + 3.0 * (c - 1))
	if _heartbeat == null:
		var stream := MusicLib.heartbeat_stream()
		if stream == null:
			return
		_heartbeat = AudioStreamPlayer.new()
		_heartbeat.bus = &"Music"
		_heartbeat.stream = stream
		add_child(_heartbeat)
	if not _heartbeat.playing:
		_heartbeat.volume_db = -40.0
		_heartbeat.play()
	create_tween().tween_property(_heartbeat, "volume_db", target_db, 0.5)

func _on_ended(won: bool) -> void:
	if won and _enemy.is_boss:
		# The boss sting waits one beat of silence -- the fall lands first, then the fanfare.
		MusicLib.stop(0.15)
		get_tree().create_timer(0.45).timeout.connect(func() -> void: Sfx.play(&"win", -2.0))
	else:
		Sfx.play(&"win" if won else &"lose", -4.0)
		MusicLib.stop(1.5 if won else 0.5)   # hard silence sells the death; the lose sfx stands alone
	if _heartbeat != null and _heartbeat.playing:
		var hb := create_tween()
		hb.tween_property(_heartbeat, "volume_db", -60.0, 0.3)
		hb.tween_callback(_heartbeat.stop)
	if won and _enemy.is_boss:
		# A Major Arcana falls: hitstop, white flash, the plate fades out of the arena, one beat
		# of silence before the sting -- the loop's dopamine peak gets its ceremony.
		Juice.hitstop(0.16)
		Juice.flash(_fx, Color(1, 1, 1, 0.5), 0.4)
	if won and _portrait != null:
		_portrait.play_state("die")
	await get_tree().create_timer(0.35 if Juice.fast_pace() else (1.0 if won and _enemy.is_boss else 0.6)).timeout   # death beat (bosses earn a longer one)
	if not standalone:
		# Feed the run: statistics, the overkill payout and the permanently shattered glass.
		if won and _enemy.is_boss:
			# The price of the Arcanum, kept so the claim screen can name it.
			RunState.boss_toll_hp = controller.damage_taken
			RunState.boss_toll_cards = controller.destroyed_cards.size()
			RunState.boss_toll_turns = controller.turn
		RunState.record_fight(won, _enemy.name_key, controller)
		# THE SCAR (PLAN_TODO T5): the card that struck the killing blow on a MAJOR ARCANA carries
		# it for the rest of the run. The trigger is deterministic -- the last card of the last
		# play, never a roll -- so the covenant holds and the player can aim for it on purpose.
		if won and _enemy.is_boss and not controller.killing_cards.is_empty():
			var killer: CardData = controller.killing_cards[controller.killing_cards.size() - 1]
			killer.scar += SCAR_CHIPS
			_popup(tr("SCAR_EARNED") % SCAR_CHIPS, Color(0.98, 0.82, 0.35), _enemy_fx_pos(), 24)
		RunState.pending_overkill = controller.overkill_rtec
		if won:
			for c in controller.destroyed_cards:
				RunState.deck.erase(c)   # identity erase: combat holds the run's own instances
			# TRAUMA OF THE TOWER (docs/todo.md par.5): if the field rule that ignores your block
			# took cards from you and you WON anyway, one survivor comes back CRACKED -- a third
			# off its base for good, but the avalanche runs over it twice. You paid for it, so it
			# is worth something no shop can sell you. The card is chosen deterministically (the
			# first uncracked card in the run deck), never rolled.
			if _enemy.rule == EnemyData.Rule.TOWER_IGNORES_BLOCK and not controller.destroyed_cards.is_empty():
				for c: CardData in RunState.deck:
					if not c.cracked:
						c.cracked = true
						_popup(tr("CRACKED_EARNED"), Color(0.75, 0.82, 0.95), _player_fx_pos(), 22)
						break
		finished.emit(won, controller.player_hp, controller.discards_left)
		return
	_overlay_label.text = tr("COMBAT_WON") if won else tr("COMBAT_LOST")
	_overlay_label.add_theme_color_override("font_color",
		Color(0.6, 0.9, 0.55) if won else Color(0.9, 0.4, 0.4))
	_overlay.modulate.a = 0.0
	_overlay.visible = true
	create_tween().tween_property(_overlay, "modulate:a", 1.0, 0.4)

# ---------------------------------------------------------------- helpers

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l

## Readouts that sit ON the enemy plate need their own contrast -- an ink outline keeps them
## legible over both a bright sky and a black robe, without a scrim boxing in the art.
func _inked(l: Label) -> Label:
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.92))
	l.add_theme_constant_override("outline_size", 5)
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
	p.tooltip_text = tr(a.name_key) + "\n" + a.describe()
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

## The enemy REACTS: the plate flinches on every landed blow (was a 116 px chip pulsing).
func _emblem_hit() -> void:
	if _portrait != null:
		_portrait.play_state("hurt")
	if _arena != null:
		_arena.punch(1.0)

func _pulse(node: Control) -> void:
	if node == null:
		return
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(1.3, 1.3)
	create_tween().tween_property(node, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _shake(strength: float) -> void:
	Juice.shake(self, strength)   # respects the reduce-motion toggle

func _hit_flash() -> void:
	Juice.flash(_fx, Color(0.85, 0.12, 0.12, 0.30), 0.35)   # respects the disable-flash toggle

func _popup(text: String, color: Color, at: Vector2, font_size: int = 26) -> void:
	var l := _label(text, font_size, color)
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
