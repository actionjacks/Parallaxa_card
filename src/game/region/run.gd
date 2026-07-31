extends Control
## Region flow controller: map -> fight -> reward -> fight -> shop -> boss -> claim -> complete.
## Owns the run via RunState, swaps screens in a stage, feeds combat and reacts to its result.
## Screens are built in code on the project theme (monogram font + cursors).

## The Fool's Journey: four regions, ending at The World. State carries across; full rest between.
## THE JOURNEY: ONE biome tower, chosen from the five colours, then The World. The five roads
## are offered up front; the tower is five rungs; the summit yields that colour's seal.
const BIOMES: Array[String] = [
	"res://data/regions/biome_life.tres",
	"res://data/regions/biome_mind.tres",
	"res://data/regions/biome_death.tres",
	"res://data/regions/biome_chaos.tres",
	"res://data/regions/biome_nature.tres",
]
const WORLD_REGION := "res://data/regions/region_04.tres"
## ONE tower per journey. A five-rung climb plus The World is six encounters -- a run you can
## finish in a sitting, and a run that yields exactly ONE colour seal, so closing the pentagram
## takes five successful journeys and each one is spent hunting the colour you still lack.
const JOURNEY_BIOMES := 1        ## towers climbed before The World
## data/regions/region_01..03.tres are RETIRED: the journey climbs biome towers now. The files
## stay on disk so old run saves can still resolve their region_path, but nothing routes to them.
const COMBAT_SCENE := "res://src/game/combat/combat.tscn"
const MENU_SCENE := "res://src/game/menu/menu.tscn"
const BUY_COST := 5
const THIN_COST := 3
## Turning a card upside down: it pays x1.45 Mult and BECOMES its enemy colour. Priced above
## thinning because it is the only tool that reshapes the deck's colour identity.
const INVERT_COST := 6
## Carving a SECOND colour into a card: the dearest shop action, because a hybrid counts for
## both colours everywhere at once and is how a two-colour deck stops being a compromise.
const SPLASH_COST := 9

## Veil III -- the Sealed Market: one fewer card on the counter. The economy stops being a
## shopping list and becomes a choice between two compromises.
func SHOP_SLOTS() -> int:
	return 2 if RunState.veil >= 3 else 3
const ENCHANT_COST := 5
const STAR_COST := 8
## Hands a Star can level (the reachable ones).
## PENTAGRAM and FULL_COURT are here because Poker.LEVEL_UP already prices them: leaving them out
## made those two table entries dead code the player could never buy into.
const STAR_HANDS: Array = [Poker.Hand.PAIR, Poker.Hand.TWO_PAIR, Poker.Hand.THREE,
	Poker.Hand.STRAIGHT, Poker.Hand.FLUSH, Poker.Hand.FULL_HOUSE, Poker.Hand.FOUR,
	Poker.Hand.PENTAGRAM, Poker.Hand.FULL_COURT]

var _shop_offers: Array = []
var _shop_reroll_cost: int = 1
var _shop_star: int = -1          ## Poker.Hand this visit's Star levels; -1 = sold/none
var _pending_first_line: String = ""   ## one-shot explanation queued for the next screen
var _star_sold: bool = false      ## a Star was already bought this VISIT (rerolls must not restock)

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
	RunState.begin(load(BIOMES[0]), entered)
	_build_shell()
	_start_run_flow()

func _exit_tree() -> void:
	Overlays.run_active = false

## A run opens with the Arcanum draft (pick your starting power); map afterwards.
func _start_run_flow() -> void:
	MusicLib.play(&"music_menu", 1.5)
	_refresh_backdrop()   # a restarted/repeated run returns to region 1: drop the old accent
	# The opening draft is a property of the RUN, not of whichever biome happens to be loaded
	# as the placeholder -- it runs first, then the player chooses which colour to walk into.
	if RunState.region != null and not RunState.region.starting_pool.is_empty():
		_show_arcanum_draft()
	else:
		_show_biome_choice()

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
	# Veil V takes a whole Aspect out of the deck and used to keep the answer to itself.
	if RunState.lost_aspect >= 0:
		_veil_label.text += "  " + tr("VEIL_LOST") % tr(Aspects.name_key(RunState.lost_aspect))
		_veil_label.tooltip_text += "\n" + tr("VEIL_LOST") % tr(Aspects.name_key(RunState.lost_aspect))
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
	if screen is VBoxContainer:
		screen = _scrollable(screen)
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

	# THE TOWER, in 3D: a real stack of stone standing in the dark behind the rung labels. The
	# labels stay 2D on top of it -- crisp text, and every existing tooltip and click still works.
	var tower_row := HBoxContainer.new()
	tower_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tower_row.add_theme_constant_override("separation", 18)
	# The tower shrinks when an omen is waiting: the omen block is ~150 px tall and the action bar
	# is pinned to the bottom, so without this the two overlap.
	var tower := TowerView.new(Vector2(320, 300) if _pending_omen != null else Vector2(360, 390))
	tower.build(RunState.fights.size() + 1, RunState.step, RunState.region.accent)
	tower_row.add_child(tower)
	var ladder := VBoxContainer.new()
	ladder.alignment = BoxContainer.ALIGNMENT_CENTER
	ladder.add_theme_constant_override("separation", 6)
	var total := RunState.fights.size() + 1
	var order: Array[int] = []
	for i in total:
		order.append(total - 1 - i)      # summit first
	for i: int in order:
		var is_boss: bool = i == RunState.fights.size()
		var label := tr("TOWER_SUMMIT") if is_boss else (tr("TOWER_RUNG") % (i + 1))
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
		var rung := HBoxContainer.new()
		rung.alignment = BoxContainer.ALIGNMENT_CENTER
		rung.add_theme_constant_override("separation", 10)
		rung.add_child(chip)
		ladder.add_child(rung)
	tower_row.add_child(ladder)
	root.add_child(tower_row)

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
	if elite_ok:
		var eh := _hint(tr("ELITE_INLINE") % [RunState.region.elite.max_hp, RunState.region.elite.enrage_step])
		eh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(eh)
	# THE ACTION BAR LIVES OUTSIDE THE COLUMN, pinned to the bottom edge. Inside it, a pending
	# omen (~150 px of extra content) pushed "Set out" below 720p -- the same failure that has
	# softlocked the arena three times. Anchored here it cannot be pushed anywhere.
	_mount(root)
	var bar := CenterContainer.new()
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.anchor_right = 1.0
	bar.offset_top = -58
	bar.offset_bottom = -10
	bar.add_child(ctrls)
	_stage.add_child(bar)

## The toll, in the player's own terms.
func _epilogue_block() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var took := _hint(tr("BOSS_TOOK") % [RunState.boss_toll_hp, RunState.boss_toll_turns])
	took.add_theme_color_override("font_color", Color(0.92, 0.6, 0.55))
	box.add_child(took)
	if RunState.boss_toll_cards > 0:
		var burned := _hint(tr("BOSS_BURNED") % RunState.boss_toll_cards)
		burned.add_theme_color_override("font_color", Color(0.85, 0.7, 0.5))
		box.add_child(burned)
	var left := _hint(tr("BOSS_LEFT"))
	left.add_theme_color_override("font_color", Color(0.7, 0.88, 0.68))
	box.add_child(left)
	return box

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
	var law: int = RunState.region.law if RunState.region != null else 0
	combat.setup(RunState.deck, _current_enemy(), RunState.relics,
		RunState.player_hp, RunState.player_max_hp, RunState.hand_levels, RunState.veil, RunState.depth, debt, law)
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
	# THE RUNG IS CLIMBED THE MOMENT THE DUEL IS WON, not when the shop is left. It used to
	# advance only in _leave_shop, so once "Save & exit" started saving the run (batch 1) a player
	# could win a duel, bank the reward, the overkill, the interest and the XP, quit from the
	# reward screen, continue -- and find the SAME rung waiting, farmable without limit.
	RunState.step += 1
	_last_rest = RunState.rest()   # recover between fights so the run isn't a one-HP knife-edge
	_roll_omen()                   # the road reveals an omen; it waits on the map screen
	# Balatro cadence: EVERY won fight pays out a card pick AND a shop visit -- the economy is
	# the decision layer, so it must never hide behind the region's hardest pre-boss check.
	_show_reward()

# ---------------------------------------------------------------- REWARD

func _show_reward() -> void:
	# The reward screen is now a save point: the rung is already climbed, so a player who quits
	# here resumes AFTER the duel they won rather than in front of it.
	RunState.save_run(_pending_omen.id if _pending_omen != null else "")
	_statusbar.visible = true
	_update_status()
	_reward_panels.clear()
	_reward_cards.clear()
	_reward_pick = -1
	var offers: Array = RunState.pick_tiered_offers(RunState.filter_lost(DeckLibrary.reward_pool()), 3, _elite_boost)
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
	_shop_offers = RunState.pick_tiered_offers(RunState.filter_lost(DeckLibrary.reward_pool()), SHOP_SLOTS())
	_shop_star = RunState.pick_offers(STAR_HANDS, 1)[0]
	_star_sold = false
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
		_shop_offers = RunState.pick_tiered_offers(RunState.filter_lost(DeckLibrary.reward_pool()), SHOP_SLOTS())
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
	var reroll := _button(tr("SHOP_REROLL") % _cost(_shop_reroll_cost), _reroll_shop)
	reroll.disabled = RunState.rtec < _cost(_shop_reroll_cost)
	controls.add_child(reroll)
	var thin := _button(tr("SHOP_THIN") % _cost(THIN_COST), _thin_deck)
	thin.disabled = RunState.rtec < _cost(THIN_COST) or RunState.deck.size() <= 5
	var invert := _button(tr("SHOP_INVERT") % _cost(INVERT_COST), _invert_card)
	invert.disabled = RunState.rtec < _cost(INVERT_COST) or RunState.deck.is_empty()
	invert.tooltip_text = tr("SHOP_INVERT_TIP")
	var splash := _button(tr("SHOP_SPLASH") % _cost(SPLASH_COST), _splash_card)
	splash.disabled = RunState.rtec < _cost(SPLASH_COST) or RunState.deck.is_empty()
	splash.tooltip_text = tr("SHOP_SPLASH_TIP")
	controls.add_child(thin)
	controls.add_child(invert)
	controls.add_child(splash)
	controls.add_child(_button(tr("SHOP_NEXT"), _leave_shop))
	root.add_child(controls)
	_mount(root)

func _buy(card: CardData) -> void:
	if RunState.spend(_cost(BUY_COST)):
		RunState.stat_bought += 1
		RunState.add_card(card)
		# The card LEAVES the counter. Without this it stayed on offer and could be bought again
		# for as long as the Mercury lasted -- eight copies of the same King for 40 -- which makes
		# nonsense of the rarity roll that took such care not to repeat a card within one offer.
		_shop_offers.erase(card)
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

## THE REVERSAL (PLAN_TODO T4): outside combat only, and written into the card. Reversing on
## draw would be randomness inside a fight, where the preview must never be able to lie.
## Measured before shipping: reversing cards does NOT starve the Flush -- it CONCENTRATES the
## deck (P(flush in hand) 1.86% at zero reversals, 4.83% at twelve), so this is the colour-
## shaping tool a mono-colour build was missing.
func _invert_card() -> void:
	if RunState.rtec < _cost(INVERT_COST) or RunState.deck.is_empty():
		return
	var cb := func(card: CardData) -> void:
		if card.inverted:
			return                       # a card turns over ONCE; a second fee bought nothing
		var foes: Array = Aspects.foes(card.aspect)
		if foes.is_empty():
			return
		# Deterministic pick: the FIRST enemy on the wheel, so the player can predict the colour
		# they are buying before they spend.
		card.aspect = foes[0] as Aspects.Id
		card.inverted = true
		# A carved second colour must FOLLOW the reversal. Left alone it stayed allied to the OLD
		# aspect, which after the flip is an ENEMY of the new one -- and a hybrid of two opposed
		# colours is exactly what _splash_card refuses to sell, because one such card closes a
		# Flush in either of them. Neither shop action is wrong alone; the bug lived only in
		# buying both on the same card.
		if card.splash >= 0:
			var new_pals: Array = Aspects.allies(card.aspect)
			if not new_pals.has(card.splash):
				card.splash = int(new_pals[0])
		RunState.spend(_cost(INVERT_COST))
		RunState.stat_bought += 1
		RunState.changed.emit()
		_show_shop()
	_open_deck_picker(tr("PICK_INVERT"), cb)

## THE SPLASH (docs/todo.md "Karty Dwukolorowe"): carve an ALLIED colour into a card, so it
## counts for both. Allied, not enemy -- the Lovers join what already belongs together, and a
## hybrid of two opposed colours would let one card serve any flush at all.
func _splash_card() -> void:
	if RunState.rtec < _cost(SPLASH_COST) or RunState.deck.is_empty():
		return
	var cb := func(card: CardData) -> void:
		if card.splash >= 0:
			return                       # a card carries at most two colours
		var pals: Array = Aspects.allies(card.aspect)
		if pals.is_empty():
			return
		card.splash = int(pals[0])
		RunState.spend(_cost(SPLASH_COST))
		RunState.stat_bought += 1
		RunState.changed.emit()
		_show_shop()
	_open_deck_picker(tr("PICK_SPLASH"), cb)

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
		_shop_star = -1
		_star_sold = true   # one Star per VISIT -- a reroll must not restock it
		_show_shop()

func _reroll_shop() -> void:
	if RunState.spend(_cost(_shop_reroll_cost)):
		_shop_offers = RunState.pick_tiered_offers(RunState.filter_lost(DeckLibrary.reward_pool()), SHOP_SLOTS())   # the slot-machine pull
		_shop_star = -1 if _star_sold else RunState.pick_offers(STAR_HANDS, 1)[0]
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
	# THE SEAL: this colour has now been answered, permanently. Granted on the boss's fall, not
	# at the end of the run -- dying at the World must not cost you the colours you already took.
	var sealed_now := false
	if RunState.region != null and RunState.region.seal_aspect >= 0:
		sealed_now = Profile.grant_seal(RunState.region.seal_aspect)
	# The journey is the tower plus The World -- not the legacy four-region array, which would
	# have sent the player back through The World again and again.
	# THE SEALED BIOME IS A TERMINUS. Its own text promises "the Journey ends there", and the
	# World Gate used to come back afterwards with "THE WORLD HAS FALLEN" over the Fool's corpse.
	if RunState.sealed_entered:
		_show_spread(true)
		return
	# The seal ceremony must fire BEFORE the final-leg return, or a colour won on the last rung of
	# a journey is banked in silence -- effect counted, never shown, which is the family of bug
	# this whole audit started from.
	if sealed_now:
		Sfx.play(&"coin", -3.0)
		if Profile.claim_once("first_seal"):
			_pending_first_line = tr("FIRST_SEAL")
	var final: bool = RunState.region_index + 1 >= JOURNEY_BIOMES + 1
	if final:
		# The World has fallen: the run is WON (recorded once, endless deaths stay wins) and the
		# gate opens -- end the reading, or walk BEYOND into a deeper world.
		if not RunState.run_won:
			RunState.run_won = true
			Profile.record_victory(RunState.veil)
		_show_world_gate(claimed, sealed_now)
		return
	var root := _screen_column()
	root.add_child(_big(tr("COMPLETE_TITLE"), Color(0.65, 0.9, 0.55)))
	if sealed_now:
		var seal_l := _hint(tr("SEAL_TAKEN") % tr(Aspects.name_key(RunState.region.seal_aspect)))
		seal_l.add_theme_color_override("font_color", Aspects.color(RunState.region.seal_aspect))
		root.add_child(seal_l)
		root.add_child(_hint(tr("SEAL_PROGRESS") % [Profile.seals.size(), 5]))
		if _pending_first_line != "":
			var fl := _hint(_pending_first_line)
			fl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.72))
			fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			fl.custom_minimum_size = Vector2(700, 0)
			root.add_child(fl)
			_pending_first_line = ""
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
	# THE EPILOGUE (PLAN_NASTEPNY N4.4): what that Arcanum TOOK and what it LEFT. A boss that
	# rewrote the rules for six turns deserves more than a card sliding into your relic row --
	# the player should be able to say afterwards what the fight actually cost them.
	root.add_child(_epilogue_block())
	root.add_child(_hint(tr("RUN_SUMMARY") % RunState.fights_won))
	root.add_child(_hint(tr("COMPLETE_HINT")))
	var wrap_c := CenterContainer.new()
	wrap_c.add_child(_button(tr("COMPLETE_NEXT"), _continue_journey))
	root.add_child(wrap_c)
	_mount(root)

func _continue_journey() -> void:
	var idx := RunState.region_index + 1
	_pending_omen = null
	if idx >= JOURNEY_BIOMES:
		# the tower is climbed: The World is the fixed terminus of every journey, at EVERY depth
		_last_rest = RunState.enter_region(load(WORLD_REGION), idx)
		_refresh_backdrop()
		_show_map()
		return
	_show_biome_choice(idx)

## THE CHOICE OF ROAD: which colour you walk into next. The first step is free among all five;
## later steps offer two of what is left, so a journey is a route through the pentagram rather
## than a fixed corridor. Offers are rolled from RunState.rng (one draw, the standard contract).
## `leg` is which stop of the journey the chosen road becomes: 0 for the tower, 1 for The World.
## It used to be INFERRED from fights_won, which is why a Beyond loop -- where fights_won is
## already high but the journey restarts -- computed leg 1, walked a tower into The World's slot
## and made boss_world unreachable from Depth 1 onward.
func _show_biome_choice(leg: int = 0) -> void:
	_statusbar.visible = true
	_update_status()
	var idx: int = leg
	var taken: Array = RunState.biomes_walked
	var left: Array = []
	for path in BIOMES:
		if not taken.has(path):
			left.append(path)
	if left.is_empty():
		left = BIOMES.duplicate()
	# first step: the whole pentagram is open. Later: two roads, so the choice keeps costing you
	# something you wanted.
	var offers: Array = left if taken.is_empty() else RunState.pick_offers(left, mini(2, left.size()))
	var root := _screen_column()
	root.add_child(_big(tr("BIOME_CHOICE_TITLE"), Color(0.92, 0.88, 0.7)))
	root.add_child(_hint(tr("BIOME_CHOICE_HINT")))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for path in offers:
		var biome: RegionData = load(path)
		row.add_child(_biome_card(biome, path, idx))
	root.add_child(row)
	_mount(root)

## One road on the choice screen: the colour, its law, and whether its seal is already yours.
func _biome_card(biome: RegionData, path: String, idx: int) -> Control:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	sb.set_border_width_all(2)
	sb.border_color = biome.accent
	sb.set_corner_radius_all(4)
	for side in ["left", "top", "right", "bottom"]:
		sb.set("content_margin_" + side, 10)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(196, 0)
	p.add_child(col)
	var title := _label_center(tr(biome.name_key), 17, biome.accent)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	var sig := AspectSigil.new(biome.seal_aspect, biome.accent, true)
	sig.custom_minimum_size = Vector2(48, 48)
	var sig_wrap := CenterContainer.new()
	sig_wrap.add_child(sig)
	col.add_child(sig_wrap)
	var law_l := _hint(tr(biome.law_key))
	law_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	law_l.custom_minimum_size = Vector2(190, 0)
	col.add_child(law_l)
	if biome.seal_aspect >= 0:
		var owned := Profile.has_seal(biome.seal_aspect)
		var mark := _hint(tr("BIOME_SEAL_OWNED") if owned else tr("BIOME_SEAL_OPEN"))
		mark.add_theme_color_override("font_color",
			Color(0.5, 0.5, 0.56) if owned else Color(0.95, 0.85, 0.5))
		col.add_child(mark)
	var go := _button(tr("BIOME_WALK"), func() -> void: _walk_biome(path, idx))
	var gw := CenterContainer.new()
	gw.add_child(go)
	col.add_child(gw)
	return p

func _walk_biome(path: String, idx: int) -> void:
	RunState.biomes_walked.append(path)
	_pending_omen = null
	if idx == 0:
		RunState.region = load(path)
		RunState.region_index = 0
		RunState.reroll_ladder()
	else:
		_last_rest = RunState.enter_region(load(path), idx)
	_refresh_backdrop()
	_show_map()

## BEYOND THE WORLD: the victory gate. The exponential vector finally has something to spend
## itself on -- every depth loops the Journey with +50% HP / +35% intents / +1 enrage.
func _show_world_gate(claimed: ArcanumData = null, sealed_now: bool = false) -> void:
	var root := _screen_column()
	root.add_child(_big(tr("GATE_TITLE"), Color(0.95, 0.85, 0.5)))
	# A colour won on the LAST rung of a journey lands here, not on the region-clear screen, so
	# the ceremony has to be repeated or the seal is banked in silence.
	if sealed_now and RunState.region != null and RunState.region.seal_aspect >= 0:
		var sl := _hint(tr("SEAL_TAKEN") % tr(Aspects.name_key(RunState.region.seal_aspect)))
		sl.add_theme_color_override("font_color", Aspects.color(RunState.region.seal_aspect))
		root.add_child(sl)
		root.add_child(_hint(tr("SEAL_PROGRESS") % [Profile.seals.size(), 5]))
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
	# THE THIRD DOOR: five colours answered opens the Sealed Biome. Only on a first, undeepened
	# journey -- the Fool answers a closed circle, not a grind. Beyond is the horizontal axis
	# (repeat the world, harder); the Seal is the vertical one (a terminus that ends the run).
	if Profile.seals_complete() and RunState.depth == 0 and not RunState.sealed_entered:
		var seal_btn := _button(tr("GATE_SEAL"), _enter_sealed)
		seal_btn.custom_minimum_size = Vector2(220, 40)
		seal_btn.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
		ctrls.add_child(seal_btn)
	root.add_child(ctrls)
	if Profile.seals_complete() and RunState.depth == 0 and not RunState.sealed_entered:
		root.add_child(_hint(tr("GATE_SEAL_HINT")))
	_mount(root)

## Break the seal: the pentagram is closed, so the Fool answers. A one-way door -- the run ends
## in the Sealed Biome, and the World Gate does not come back.
func _enter_sealed() -> void:
	RunState.sealed_entered = true
	_pending_omen = null
	_last_rest = RunState.enter_region(load("res://data/regions/region_sealed.tres"), RunState.region_index)
	_refresh_backdrop()
	_show_map()

func _go_beyond() -> void:
	RunState.depth += 1
	_pending_omen = null
	# A deeper loop climbs ANOTHER tower: the roads reopen (including colours already walked,
	# because at depth the point is the scaling, not the seal) and the choice screen decides.
	RunState.biomes_walked = []
	RunState.region_index = 0
	_show_biome_choice(0)

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
	RunState.begin(load(BIOMES[0]), s)
	_start_run_flow()

func _restart_run() -> void:
	_pending_omen = null
	RunState.next_veil = RunState.veil   # fresh seed, same tier (the menu changes tiers)
	RunState.next_pure = false           # a NEW fate is the player's own again
	RunState.next_daily = ""
	RunState.begin(load(BIOMES[0]))   # placeholder road; the choice screen sets the real one
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
	# Boon first, then the road: the drafted Arcanum is exactly what should inform which
	# colour you choose to walk into.
	if RunState.biomes_walked.is_empty():
		_show_biome_choice()
	else:
		_show_map()

# ---------------------------------------------------------------- helpers

## Every run screen is built into this column. It is a plain VBox at PRESET_FULL_RECT, so a tall
## screen (the map with a pending omen is ~150 px taller) pushed its own action buttons past
## 720p -- the fourth softlock of that family in this project. The column now scrolls: content
## can grow without ever taking the buttons off screen.
func _screen_column() -> VBoxContainer:
	var c := VBoxContainer.new()
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_theme_constant_override("separation", 24)
	return c

## Wrap a built screen so it can never be taller than the window.
func _scrollable(col: Control) -> Control:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = true
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(col)
	return sc

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
