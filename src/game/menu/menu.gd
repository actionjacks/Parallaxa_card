extends Control
## Main menu / title screen: tarot-and-mysticism themed. The game's display title is the thesis
## ("The Cards Do Not Lie"); PARALLAXA stays as the small series tag. New Journey opens the run
## setup (starter deck + Veil) once there is anything to choose; Collection browses every card,
## deck, Arcanum and achievement. RMB inspects cards anywhere.

const RUN_SCENE := "res://src/game/region/run.tscn"
const SETTINGS_SCENE := "res://src/ui/settings/settings_menu.tscn"
## A fan of Major Arcana behind the title -- the deck is the world.
const TITLE_CARDS: Array[String] = [
	"res://assets/cards/arcana/00_fool.jpg",
	"res://assets/cards/arcana/13_death.jpg",
	"res://assets/cards/arcana/16_tower.jpg",
	"res://assets/cards/arcana/18_moon.jpg",
	"res://assets/cards/arcana/21_world.jpg",
]
const DECK_ORDER: Array[String] = ["classic", "reaper", "gardener", "oracle"]

var _collection: Control
var _setup: Control
var _setup_deck: String = "classic"
var _setup_veil: int = 0
var _seed_edit: LineEdit

func _ready() -> void:
	Overlays.run_active = false
	add_child(Backdrop.build())
	MusicLib.play(&"music_menu", 2.0)

	# title card fan: slightly rotated arcana behind the title, like a spread being dealt
	var fan := Control.new()
	fan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fan)
	for i in TITLE_CARDS.size():
		var t := TextureRect.new()
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		t.texture = load(TITLE_CARDS[i])
		t.size = Vector2(150, 260)
		t.pivot_offset = Vector2(75, 260)
		t.position = Vector2(400 + i * 110, 60)
		t.rotation_degrees = -12.0 + i * 6.0
		t.modulate = Color(1, 1, 1, 0.34)
		fan.add_child(t)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	add_child(col)

	var series := _lbl("PARALLAXA", 15, Color(0.5, 0.47, 0.58))   # series tag, literal (brand)
	series.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(series)
	var title := _lbl(tr("MENU_TITLE"), 54, Color(0.95, 0.9, 0.75))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := _lbl(tr("MENU_TAGLINE"), 16, Color(0.65, 0.6, 0.72))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	col.add_child(_spacer(18))

	col.add_child(_menu_btn(tr("MENU_NEW"), _new_run))
	var cont := _menu_btn(tr("MENU_CONTINUE"), _continue_run)
	cont.disabled = not RunState.has_run_save()
	col.add_child(cont)
	# Daily Fate: one date-hashed seed for EVERYONE, played as a Pure Reading -- the shared
	# puzzle culture needs no server when the game is deterministic.
	var daily := _menu_btn(tr("MENU_DAILY") % _daily_date(), _start_daily)
	daily.tooltip_text = tr("MENU_DAILY_TIP")
	col.add_child(daily)
	col.add_child(_menu_btn(tr("MENU_COLLECTION"), _open_collection))
	col.add_child(_menu_btn(tr("MENU_CHARACTER"), _open_character))
	col.add_child(_menu_btn(tr("MENU_OPTIONS"), _open_options))
	col.add_child(_menu_btn(tr("MENU_QUIT"), func() -> void: get_tree().quit()))

# ---------------------------------------------------------------- new run setup

func _new_run() -> void:
	# Fresh profile with nothing to choose: zero-friction direct start.
	if Profile.wins == 0 and Profile.available_decks().size() == 1:
		RunState.next_veil = 0
		RunState.next_seed = 0
		RunState.next_pure = false
		RunState.next_daily = ""
		_begin_run()
		return
	_open_setup()

## Today's date tag (UTC) -- the whole world shares one fate per day.
func _daily_date() -> String:
	return Time.get_date_string_from_system(true)

## Deterministic 32-bit seed from the date tag (djb2). Everyone hashes the same fate.
static func _daily_seed(tag: String) -> int:
	var h := 5381
	for i in tag.length():
		h = ((h * 33) + tag.unicode_at(i)) & 0xFFFFFFFF
	return h if h != 0 else 1

func _start_daily() -> void:
	var tag := _daily_date()
	RunState.next_veil = 0
	RunState.next_seed = _daily_seed(tag)
	RunState.next_pure = true    # shared fates are Pure Readings: identical for every player
	RunState.next_daily = tag
	_begin_run()

func _begin_run() -> void:
	RunState.load_pending = false
	RunState.delete_run_save()
	get_tree().change_scene_to_file(RUN_SCENE)

## Parse a pasted fate code ("A3F2-09BC", dash optional, case-insensitive) -> seed int or 0.
static func _parse_fate(text: String) -> int:
	var t := text.strip_edges().replace("-", "").replace(" ", "").to_upper()
	if t.is_empty() or t.length() > 8 or not t.is_valid_hex_number():
		return 0
	var v := ("0x" + t).hex_to_int() & 0xFFFFFFFF
	return v if v != 0 else 1

func _continue_run() -> void:
	RunState.load_pending = true
	get_tree().change_scene_to_file(RUN_SCENE)

## Run setup overlay: pick the starter deck and the Veil (ascension tier).
func _open_setup() -> void:
	if _setup != null:
		return
	_setup_deck = Profile.selected_deck if Profile.available_decks().has(Profile.selected_deck) else "classic"
	_setup_veil = 0
	_setup = Control.new()
	_setup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_setup.add_child(dim)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	_setup.add_child(v)
	v.add_child(_center_lbl(tr("NEWRUN_TITLE"), 26, Color(0.93, 0.89, 0.8)))

	v.add_child(_center_lbl(tr("NEWRUN_DECK"), 16, Color(0.75, 0.72, 0.82)))
	var drow := HBoxContainer.new()
	drow.alignment = BoxContainer.ALIGNMENT_CENTER
	drow.add_theme_constant_override("separation", 10)
	var avail: Array = Profile.available_decks()
	for id in DECK_ORDER:
		if not avail.has(id):
			continue
		var p := _toggle_panel(tr(DeckLibrary.deck_name_key(id)), tr(DeckLibrary.deck_desc_key(id)))
		p.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_setup_deck = id
				_refresh_setup_toggles(drow, null))
		p.set_meta("id", id)
		drow.add_child(p)
	v.add_child(drow)

	var vrow := HBoxContainer.new()
	if Profile.wins > 0:
		v.add_child(_center_lbl(tr("NEWRUN_VEIL"), 16, Color(0.72, 0.55, 0.9)))
		vrow.alignment = BoxContainer.ALIGNMENT_CENTER
		vrow.add_theme_constant_override("separation", 8)
		for tier in Profile.veil_selectable_max() + 1:
			var chip := _toggle_panel(str(tier), "")
			chip.custom_minimum_size = Vector2(44, 36)
			chip.tooltip_text = tr("VEIL_%d" % tier) + ("\n" + tr("VEIL_%d_DESC" % tier) if tier > 0 else "")
			chip.gui_input.connect(func(ev: InputEvent) -> void:
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					_setup_veil = tier
					_refresh_setup_toggles(null, vrow))
			chip.set_meta("id", str(tier))
			vrow.add_child(chip)
		v.add_child(vrow)
		v.add_child(_center_lbl(tr("NEWRUN_VEIL_HINT"), 13, Color(0.6, 0.6, 0.68)))

	# Entered fate: play someone else's seed -- always as a Pure Reading, so the shared code
	# provably reproduces the same run for everyone.
	v.add_child(_center_lbl(tr("NEWRUN_SEED"), 16, Color(0.62, 0.6, 0.7)))
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "A3F2-09BC"
	_seed_edit.custom_minimum_size = Vector2(200, 34)
	_seed_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seed_edit.max_length = 9
	var seed_wrap := CenterContainer.new()
	seed_wrap.add_child(_seed_edit)
	v.add_child(seed_wrap)
	v.add_child(_center_lbl(tr("NEWRUN_SEED_HINT"), 12, Color(0.55, 0.55, 0.62)))

	var begin := _menu_btn(tr("NEWRUN_BEGIN"), func() -> void:
		Profile.selected_deck = _setup_deck
		Profile.save_profile()
		RunState.next_veil = _setup_veil
		var fate := _parse_fate(_seed_edit.text)
		RunState.next_seed = fate
		RunState.next_pure = fate != 0
		RunState.next_daily = ""
		_begin_run())
	begin.custom_minimum_size = Vector2(240, 44)
	v.add_child(begin)
	var cancel := _menu_btn(tr("COMMON_CANCEL"), func() -> void:
		_setup.queue_free()
		_setup = null)
	v.add_child(cancel)
	add_child(_setup)
	_refresh_setup_toggles(drow, vrow)

func _refresh_setup_toggles(drow: Control, vrow: Control) -> void:
	if drow != null:
		for ch in drow.get_children():
			_set_toggled(ch, ch.get_meta("id") == _setup_deck)
	if vrow != null:
		for ch in vrow.get_children():
			_set_toggled(ch, ch.get_meta("id") == str(_setup_veil))

func _toggle_panel(title: String, desc: String) -> PanelContainer:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.14)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.35, 0.35, 0.45)
	sb.set_corner_radius_all(4)
	for side in ["left", "top", "right", "bottom"]:
		sb.set("content_margin_" + side, 8)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(170, 56)
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.set_meta("style", sb)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(vb)
	var t := _lbl(title, 15, Color(0.92, 0.88, 0.95))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	if desc != "":
		var d := _lbl(desc, 11, Color(0.62, 0.64, 0.72))
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(d)
	return p

func _set_toggled(p: Control, on: bool) -> void:
	var sb: StyleBoxFlat = p.get_meta("style")
	sb.border_color = Color.WHITE if on else Color(0.35, 0.35, 0.45)
	sb.set_border_width_all(3 if on else 2)

func _open_options() -> void:
	var s: Control = load(SETTINGS_SCENE).instantiate()
	add_child(s)
	if s.has_signal("closed"):
		s.closed.connect(s.queue_free)
	if s.has_method("open"):
		s.open()

# ---------------------------------------------------------------- character (the TAROCISTA)

var _character: Control

## The tarocista's sheet: portrait (the Hierophant -- the reader of mysteries), rank + level,
## an XP bar, and the lifetime ledger of everything the cards have witnessed.
func _open_character() -> void:
	if _character != null:
		return
	_character = Control.new()
	_character.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_character.add_child(dim)
	var wrap := CenterContainer.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_character.add_child(wrap)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 36)
	wrap.add_child(row)

	# --- left: the persona ---
	var left := VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)
	var portrait := TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.texture = load("res://assets/cards/arcana/05_hierophant.jpg")
	portrait.custom_minimum_size = Vector2(220, 381)
	left.add_child(portrait)
	var name_l := _lbl(tr("CHAR_TITLE"), 24, Color(0.95, 0.9, 0.75))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(name_l)
	var rank_l := _lbl(tr(Profile.rank_key()), 17, Color(0.72, 0.62, 0.85))
	rank_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(rank_l)
	var lv_l := _lbl(tr("CHAR_LEVEL") % Profile.level, 15, Color(0.8, 0.8, 0.86))
	lv_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(lv_l)
	# XP bar toward the next level
	var need := Profile.xp_to_next(Profile.level)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(220, 16)
	bar.max_value = need
	bar.value = Profile.xp
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.06, 0.09)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(0.72, 0.62, 0.85)
	fg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	left.add_child(bar)
	var xp_l := _lbl(tr("CHAR_XP") % [Profile.xp, need], 13, Color(0.6, 0.6, 0.68))
	xp_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(xp_l)
	left.add_child(_seal_plaque())

	# --- right: the lifetime ledger ---
	var sbx := StyleBoxFlat.new()
	sbx.bg_color = Color(0.09, 0.085, 0.12)
	sbx.set_border_width_all(2)
	sbx.border_color = Color(0.45, 0.4, 0.55)
	sbx.set_corner_radius_all(4)
	for side in ["left", "top", "right", "bottom"]:
		sbx.set("content_margin_" + side, 18)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", sbx)
	panel.custom_minimum_size = Vector2(420, 0)
	row.add_child(panel)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 7)
	panel.add_child(sv)
	sv.add_child(_lbl(tr("CHAR_STATS"), 20, Color(0.93, 0.89, 0.8)))
	for key: String in Profile.LIFE_KEYS:
		var line := HBoxContainer.new()
		sv.add_child(line)
		var kl := _lbl(tr("LIFE_" + key.to_upper()), 14, Color(0.72, 0.74, 0.82))
		kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(kl)
		line.add_child(_lbl(str(Profile.life_stat(key)), 14, Color(0.92, 0.88, 0.8)))
	sv.add_child(_lbl(tr("VEIL_BEST") % maxi(Profile.best_veil, 0), 13, Color(0.72, 0.55, 0.9)))
	sv.add_child(_lbl(tr("META_SOL") % Profile.sol, 13, Color(0.9, 0.85, 0.6)))
	var close := _menu_btn(tr("COMMON_CLOSE"), func() -> void:
		_character.queue_free()
		_character = null)
	sv.add_child(close)
	add_child(_character)

# ---------------------------------------------------------------- collection

## Collection: starter decks (with permanent edition upgrades, Veil-gated), the full card pool,
## every Arcanum (with Sol sinks that WIDEN the boss pool) and the achievement ledger.
func _open_collection() -> void:
	if _collection != null:
		return
	_collection = Control.new()
	_collection.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_collection.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	_collection.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	v.add_child(head)
	head.add_child(_lbl(tr("MENU_COLLECTION"), 26, Color(0.93, 0.89, 0.8)))
	head.add_child(_lbl(tr("META_SOL") % Profile.sol, 20, Color(0.9, 0.85, 0.6)))
	if Profile.best_veil >= 0:
		head.add_child(_lbl(tr("VEIL_BEST") % Profile.best_veil, 16, Color(0.72, 0.55, 0.9)))
	v.add_child(_lbl(tr("COLLECTION_HINT"), 13, Color(0.6, 0.6, 0.68)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)

	# --- starter decks: sidegrades + the permanent edition ladder (Veil-gated) ---
	inner.add_child(_lbl(tr("COLLECTION_DECKS"), 18, Color(0.85, 0.82, 0.9)))
	var avail: Array = Profile.available_decks()
	for id in DECK_ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		inner.add_child(row)
		row.add_child(_lbl(tr(DeckLibrary.deck_name_key(id)), 16, Color(0.92, 0.88, 0.95)))
		var dk := tr(DeckLibrary.deck_desc_key(id))
		if dk != DeckLibrary.deck_desc_key(id):
			row.add_child(_lbl(dk, 12, Color(0.62, 0.64, 0.72)))
		if avail.has(id):
			if id != "classic":
				row.add_child(_lbl(tr("COLLECTION_DECK_OWNED"), 12, Color(0.6, 0.85, 0.6)))
		elif Profile.ACH_DECKS.has(id):
			row.add_child(_lbl(tr("COLLECTION_ARC_ACH") % tr(Profile.ACH_DECKS[id]), 12, Color(0.75, 0.7, 0.82)))
		else:
			var bb := _lbl_btn(tr("COLLECTION_DECK_BUY") % Profile.DECK_COST, _buy_deck.bind(id))
			bb.disabled = Profile.sol < Profile.DECK_COST
			row.add_child(bb)
		var sgrid := HFlowContainer.new()
		sgrid.add_theme_constant_override("h_separation", 8)
		sgrid.add_theme_constant_override("v_separation", 8)
		sgrid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.add_child(sgrid)
		var cards := DeckLibrary.starter_deck_by_id(id)
		for i in cards.size():
			var box := VBoxContainer.new()
			box.alignment = BoxContainer.ALIGNMENT_CENTER
			box.add_theme_constant_override("separation", 4)
			var w := CardWidget.build(cards[i])
			if not avail.has(id):
				w.modulate = Color(0.45, 0.45, 0.5)
			box.add_child(w)
			if avail.has(id):
				var nxt := Profile.next_starter_edition(id, i)
				if nxt == CardData.Edition.NONE:
					box.add_child(_lbl(tr("COLLECTION_MAXED"), 10, Color(0.6, 0.62, 0.55)))
				elif not Profile.edition_allowed(nxt):
					box.add_child(_lbl(tr("COLLECTION_ED_GATE") % int(Profile.EDITION_VEIL_GATE[nxt]), 10, Color(0.6, 0.55, 0.62)))
				else:
					var cost: int = Profile.EDITION_COST[nxt]
					var up := _lbl_btn(tr("COLLECTION_UPGRADE") % [tr(CardData.edition_name_key(nxt)), cost],
						_upgrade_starter.bind(id, i))
					up.disabled = Profile.sol < cost
					box.add_child(up)
					# the buyer sees WHAT the edition does before spending (was tooltip-only)
					box.add_child(_lbl(tr("ED_" + CardData.edition_name_key(nxt).trim_prefix("ED_") + "_DESC"), 9, Color(0.6, 0.64, 0.7)))
			sgrid.add_child(box)

	# --- reward pool: everything, day one (the meta never subtracts) ---
	inner.add_child(_lbl(tr("COLLECTION_CARDS"), 18, Color(0.85, 0.82, 0.9)))
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(grid)
	var seen := {}
	for card in DeckLibrary.full_reward_pool():
		var key := Profile.card_key(card)
		if seen.has(key):
			continue
		seen[key] = true
		grid.add_child(CardWidget.build(card))

	# --- Arcana: the worn powers; Sol buys new ones INTO the boss pool ---
	inner.add_child(_lbl(tr("COLLECTION_ARCANA"), 18, Color(0.85, 0.82, 0.9)))
	var agrid := HFlowContainer.new()
	agrid.add_theme_constant_override("h_separation", 10)
	agrid.add_theme_constant_override("v_separation", 10)
	inner.add_child(agrid)
	for path in _arcana_paths():
		var a: ArcanumData = load(path)
		if a == null:
			continue
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		var t := TextureRect.new()
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		t.texture = a.art
		t.custom_minimum_size = Vector2(90, 156)
		t.tooltip_text = tr(a.name_key) + "\n" + a.describe()
		box.add_child(t)
		box.add_child(_lbl(tr(a.name_key), 11, Color(0.8, 0.75, 0.88)))
		var shop_id := _shop_arcana_id(path)
		var ach_id := _ach_arcana_id(path)
		if shop_id != "":
			if Profile.owned_arcana.has(shop_id):
				box.add_child(_lbl(tr("COLLECTION_ARC_OWNED"), 11, Color(0.6, 0.85, 0.6)))
			else:
				t.modulate = Color(0.45, 0.45, 0.5)
				var ab := _lbl_btn(tr("COLLECTION_ARC_BUY") % Profile.ARCANA_COST, _buy_arcana.bind(shop_id))
				ab.disabled = Profile.sol < Profile.ARCANA_COST
				box.add_child(ab)
		elif ach_id != "":
			if not Profile.has_achievement(Profile.ACH_ARCANA[ach_id][0]):
				t.modulate = Color(0.45, 0.45, 0.5)
				box.add_child(_lbl(tr("COLLECTION_ARC_ACH") % tr(Profile.ACH_ARCANA[ach_id][0]), 10, Color(0.75, 0.7, 0.82)))
		agrid.add_child(box)

	# --- achievements: the ledger of proofs ---
	inner.add_child(_lbl(tr("COLLECTION_ACH"), 18, Color(0.85, 0.82, 0.9)))
	inner.add_child(_lbl(tr("COLLECTION_ACH_HINT"), 12, Color(0.72, 0.68, 0.5)))
	for ach in Profile.ACH_ORDER:
		var done: bool = Profile.has_achievement(ach)
		var arow := VBoxContainer.new()
		arow.add_theme_constant_override("separation", 2)
		inner.add_child(arow)
		var hl := HBoxContainer.new()
		hl.add_theme_constant_override("separation", 12)
		arow.add_child(hl)
		hl.add_child(_lbl(tr(ach), 15, Color(0.95, 0.85, 0.5) if done else Color(0.55, 0.55, 0.62)))
		hl.add_child(_lbl(tr("ACH_DONE") if done else tr("ACH_UNDONE"), 12,
			Color(0.6, 0.85, 0.6) if done else Color(0.55, 0.55, 0.62)))
		arow.add_child(_lbl(tr(ach + "_DESC"), 12, Color(0.68, 0.7, 0.78)))
		# Prestige achievements have no reward line (proof, not power).
		if tr(ach + "_REWARD") != ach + "_REWARD":
			arow.add_child(_lbl(tr("ACH_REWARD") % tr(ach + "_REWARD"), 12, Color(0.72, 0.62, 0.85)))

	var close := _menu_btn(tr("COMMON_CLOSE"), func() -> void:
		_collection.queue_free()
		_collection = null)
	var wrap_c := CenterContainer.new()
	wrap_c.add_child(close)
	v.add_child(wrap_c)
	add_child(_collection)

func _shop_arcana_id(path: String) -> String:
	for id in Profile.SHOP_ARCANA:
		if Profile.SHOP_ARCANA[id] == path:
			return id
	return ""

func _ach_arcana_id(path: String) -> String:
	for id in Profile.ACH_ARCANA:
		if Profile.ACH_ARCANA[id][1] == path:
			return id
	return ""

func _buy_deck(id: String) -> void:
	if Profile.buy_deck(id):
		Sfx.play(&"coin", -4.0)
		_reopen_collection()

func _buy_arcana(id: String) -> void:
	if Profile.buy_arcana(id):
		Sfx.play(&"coin", -4.0)
		_reopen_collection()

func _upgrade_starter(deck_id: String, index: int) -> void:
	if Profile.upgrade_starter(deck_id, index):
		Sfx.play(&"coin", -4.0, 1.2)
		_reopen_collection()

func _reopen_collection() -> void:
	if _collection != null:
		_collection.queue_free()
		_collection = null
	_open_collection()

func _lbl_btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 11)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(cb)
	return b

func _arcana_paths() -> Array:
	var out: Array = []
	var dir := DirAccess.open("res://data/arcana")
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".tres"):
			out.append("res://data/arcana/" + f)
	out.sort()
	return out

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _menu_btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 40)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(cb)
	return b

func _center_lbl(text: String, font_size: int, color: Color) -> Label:
	var l := _lbl(text, font_size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

## THE FIVE SEALS: which colours have answered you, and which have not. This is the meta-goal
## made visible -- a run yields exactly one seal, so the player has to come back for the colour
## they are MISSING, and a goal you cannot see is not a goal.
func _seal_plaque() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var title := _lbl(tr("SEAL_PLAQUE"), 13, Color(0.72, 0.68, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for a in [Aspects.Id.LIFE, Aspects.Id.MIND, Aspects.Id.DEATH, Aspects.Id.CHAOS, Aspects.Id.NATURE]:
		var held: bool = Profile.has_seal(a)
		# Held colours are FILLED, missing ones are hollow: the shape reads the state even for a
		# player who cannot tell violet from red.
		var sig := AspectSigil.new(a, Aspects.color(a) if held else Color(0.34, 0.34, 0.40), held)
		sig.custom_minimum_size = Vector2(30, 30)
		sig.tooltip_text = tr(Aspects.name_key(a)) + "\n" + tr("BIOME_SEAL_OWNED" if held else "BIOME_SEAL_OPEN")
		sig.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_child(sig)
	box.add_child(row)
	var line: Label
	if Profile.seals_complete():
		line = _lbl(tr("SEAL_PLAQUE_FULL"), 12, Color(0.95, 0.9, 0.75))
	else:
		var missing: Array = []
		for a in Profile.seals_missing():
			missing.append(tr(Aspects.name_key(a)))
		line = _lbl(tr("SEAL_MISSING") % ", ".join(missing), 12, Color(0.62, 0.6, 0.68))
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(220, 0)
	box.add_child(line)
	return box

func _lbl(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
