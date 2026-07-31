extends CanvasLayer
## Autoload "Overlays": the three global in-run layers from the UX brief (todo.md):
##  * ESC  -> pause menu (resume / options via the base settings_menu / abandon run / quit),
##  * TAB  -> run overview (decklist, relics with effects, hand levels, journey progress, stats),
##  * RMB on any card (CardWidget routes here) -> centered inspection with a keyword explainer.
## The layer pauses the tree while open; enabled only when a run scene registers itself.

const SETTINGS_SCENE := "res://src/ui/settings/settings_menu.tscn"
const MENU_SCENE := "res://src/game/menu/menu.tscn"

var run_active: bool = false      ## set by run.gd on ready/exit; gates ESC/TAB
var _pause_root: Control
var _glossary: Control          ## the "what the words mean" screen
var _overview_root: Control
var _inspect_root: Control
var _settings: Control

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if not run_active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			if _inspect_root != null:
				close_inspect()
			elif _overview_root != null:
				_close_overview()
			elif _pause_root != null:
				_resume()
			else:
				_open_pause()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_TAB and _pause_root == null:
			if _overview_root != null:
				_close_overview()
			else:
				_open_overview()
			get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- PAUSE (ESC)

func _open_pause() -> void:
	get_tree().paused = true
	_pause_root = _dim_layer()
	var panel := _panel_box()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	vb.add_child(_title(tr("PAUSE_TITLE")))
	vb.add_child(_menu_btn(tr("PAUSE_RESUME"), _resume))
	vb.add_child(_menu_btn(tr("PAUSE_OPTIONS"), _open_options))
	vb.add_child(_menu_btn(tr("GLOSSARY_TITLE"), _open_glossary))
	vb.add_child(_menu_btn(tr("PAUSE_ABANDON"), _abandon))
	vb.add_child(_menu_btn(tr("PAUSE_QUIT"), func() -> void: get_tree().quit()))
	var wrap_c := CenterContainer.new()
	wrap_c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap_c.add_child(panel)
	_pause_root.add_child(wrap_c)
	add_child(_pause_root)

func _resume() -> void:
	if _pause_root != null:
		_pause_root.queue_free()
		_pause_root = null
	get_tree().paused = false

func _open_options() -> void:
	if _settings != null:
		return
	_settings = load(SETTINGS_SCENE).instantiate()
	_settings.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_root.add_child(_settings)
	if _settings.has_signal("closed"):
		_settings.closed.connect(func() -> void:
			if _settings != null:
				_settings.queue_free()
				_settings = null)
	if _settings.has_method("open"):
		_settings.open()

## Save happens at every map arrival (run.gd), so abandoning keeps the run resumable from the menu.
## The button says "Save & exit" and used to save NOTHING: the run was only ever written on the
## map screen, so leaving from a shop or mid-fight silently threw the run away.
func _abandon() -> void:
	_resume()
	var rs := get_node_or_null("/root/RunState")
	if run_active and rs != null and rs.region != null:
		rs.save_run("")
	var prof := get_node_or_null("/root/Profile")
	# A Daily walked away from is still today's reading. Without this the player could restart the
	# same fate until it went well and only THEN let it be recorded -- exactly the farming the
	# first-attempt rule exists to stop (death was recorded, quitting was not).
	if prof != null and rs != null and run_active and String(rs.daily_tag) != "" \
			and prof.has_method("record_daily_abandon"):
		prof.call("record_daily_abandon")
	if prof != null and prof.has_method("save_profile"):
		prof.call("save_profile")
	run_active = false
	get_tree().change_scene_to_file(MENU_SCENE)

# ---------------------------------------------------------------- OVERVIEW (TAB)

func _open_overview() -> void:
	get_tree().paused = true
	_overview_root = _dim_layer()
	var panel := _panel_box()
	panel.custom_minimum_size = Vector2(1100, 600)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	margin.add_child(cols)

	# left: the decklist as card minis
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	left.add_child(_title(tr("OVERVIEW_DECK") % RunState.deck.size()))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(640, 0)
	left.add_child(scroll)
	var grid := HFlowContainer.new()
	grid.custom_minimum_size = Vector2(640, 0)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	for card in RunState.deck:
		grid.add_child(CardWidget.build(card))

	# right: relics, hand levels, journey, stats
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.custom_minimum_size = Vector2(380, 0)
	cols.add_child(right)
	right.add_child(_title(tr("OVERVIEW_RELICS")))
	if RunState.relics.is_empty():
		right.add_child(_lbl(tr("COMMON_NONE"), 14, Color(0.6, 0.6, 0.68)))
	for a in RunState.relics:
		right.add_child(_lbl("* %s — %s" % [tr(a.name_key), a.describe()], 13, Color(0.82, 0.76, 0.9)))
	right.add_child(_title(tr("PAYTABLE_TITLE")))
	# Listed cheapest-first by PAYOUT, not by enum order -- with five Aspects the Flush
	# outranks a Four of a Kind, and a chart that lied about that would teach the wrong play.
	var _ordered: Array = Poker.BASE.keys()
	_ordered.sort_custom(func(a, b): return Poker.value_of(a) < Poker.value_of(b))
	for hand in _ordered:
		var lv := int(RunState.hand_levels.get(hand, 0))
		var base: Array = Poker.leveled_base(hand, lv)
		# Same secrecy as the in-combat chart: naming a secret spread here was a full leak of it.
		var secret: bool = hand == Poker.Hand.PENTAGRAM or hand == Poker.Hand.FULL_COURT
		var nm: String = tr("HAND_UNDISCOVERED") if (secret and not Profile.hand_found(hand)) \
			else tr(Poker.name_key(hand))
		var row := "%s  %d x %s" % [nm, int(base[0]), String.num(float(base[1]), 1)]
		if lv > 0:
			row += "  (Lv%d)" % (lv + 1)
		right.add_child(_lbl(row, 13, Color(0.95, 0.9, 0.6) if lv > 0 else Color(0.72, 0.74, 0.82)))
	right.add_child(_title(tr("OVERVIEW_JOURNEY")))
	var region_name := tr(RunState.region.name_key) if RunState.region != null else "?"
	right.add_child(_lbl(tr("OVERVIEW_REGION") % [RunState.region_index + 1, RunState.journey_legs(), region_name], 13, Color(0.8, 0.8, 0.86)))
	right.add_child(_lbl(tr("OVERVIEW_NODE") % [mini(RunState.step + 1, RunState.fights.size() + 1), RunState.fights.size() + 1], 13, Color(0.8, 0.8, 0.86)))
	right.add_child(_lbl(tr("RUN_SUMMARY") % RunState.fights_won, 13, Color(0.8, 0.8, 0.86)))
	right.add_child(_title(tr("OVERVIEW_STATS")))
	right.add_child(_lbl(tr("RUN_HP") % [RunState.player_hp, RunState.player_max_hp], 13, Color(0.6, 0.9, 0.55)))
	right.add_child(_lbl(tr("RUN_RTEC") % RunState.rtec, 13, Color(0.85, 0.8, 0.55)))
	right.add_child(_lbl(tr("OVERVIEW_HINT"), 12, Color(0.55, 0.55, 0.62)))

	var wrap_c := CenterContainer.new()
	wrap_c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap_c.add_child(panel)
	_overview_root.add_child(wrap_c)
	add_child(_overview_root)

func _close_overview() -> void:
	if _overview_root != null:
		_overview_root.queue_free()
		_overview_root = null
	if _pause_root == null:
		get_tree().paused = false

# ---------------------------------------------------------------- INSPECT (RMB)

## Centered card inspection with a keyword/mechanics explainer (opened by CardWidget on RMB).
func inspect(card: CardData) -> void:
	if _pause_root != null:
		return
	close_inspect()
	get_tree().paused = true
	_inspect_root = _dim_layer()
	_inspect_root.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			close_inspect())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var art := CardWidget.minor_art(card)
	if art != null:
		var t := TextureRect.new()
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		t.texture = art
		t.custom_minimum_size = Vector2(300, 519)
		row.add_child(t)
	else:
		var big := CardWidget.build(card)
		big.scale = Vector2(2.6, 2.6)
		big.pivot_offset = Vector2.ZERO
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(208, 292)
		holder.add_child(big)
		row.add_child(holder)

	var info := _panel_box()
	info.custom_minimum_size = Vector2(360, 0)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 10)
	info.add_child(iv)
	iv.add_child(_lbl("%s %s" % [card.rank_glyph(), tr(Aspects.name_key(card.aspect))], 26, Aspects.color(card.aspect)))
	iv.add_child(_lbl(tr("INSPECT_CHIPS") % card.chip_value(), 14, Color(0.8, 0.82, 0.88)))
	if card.keyword != CardData.Keyword.NONE:
		var kw := tr(CardData.keyword_name_key(card.keyword))
		if card.keyword_value > 0:
			kw += " " + str(card.keyword_value)
		iv.add_child(_lbl(kw, 18, Aspects.color(card.aspect)))
		var d := _lbl(tr(CardData.keyword_desc_key(card.keyword)), 14, Color(0.78, 0.8, 0.86))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD
		d.custom_minimum_size = Vector2(330, 0)
		iv.add_child(d)
		if card.keyword == CardData.Keyword.SYMBIOZA:
			var pals: Array = Aspects.allies(card.aspect)
			iv.add_child(_lbl(tr("INSPECT_ALLIES") % [tr(Aspects.name_key(pals[0])), tr(Aspects.name_key(pals[1]))],
				13, Color(0.7, 0.85, 0.68)))
	if card.edition != CardData.Edition.NONE:
		iv.add_child(_lbl("+ " + tr(CardData.edition_name_key(card.edition)), 16, Color(0.95, 0.85, 0.6)))
		iv.add_child(_lbl(_edition_desc(card.edition), 13, Color(0.75, 0.75, 0.8)))
	if card.growth > 0:
		iv.add_child(_lbl(tr("INSPECT_GROWTH") % card.growth, 13, Color(0.6, 0.85, 0.55)))
	iv.add_child(_lbl(tr("INSPECT_CLOSE"), 12, Color(0.55, 0.55, 0.62)))
	row.add_child(info)

	var wrap_c := CenterContainer.new()
	wrap_c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap_c.add_child(row)
	_inspect_root.add_child(wrap_c)
	add_child(_inspect_root)

func close_inspect() -> void:
	if _inspect_root != null:
		_inspect_root.queue_free()
		_inspect_root = null
	if _pause_root == null and _overview_root == null:
		get_tree().paused = false

func _edition_desc(ed: int) -> String:
	match ed:
		CardData.Edition.FOIL: return tr("ED_FOIL_DESC")
		CardData.Edition.HOLO: return tr("ED_HOLO_DESC")
		CardData.Edition.POLYCHROME: return tr("ED_POLYCHROME_DESC")
	return ""

# ---------------------------------------------------------------- helpers

func _dim_layer() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(dim)
	return c

func _panel_box() -> PanelContainer:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.085, 0.12)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.45, 0.4, 0.55)
	sb.set_corner_radius_all(4)
	for side in ["left", "top", "right", "bottom"]:
		sb.set("content_margin_" + side, 18)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb)
	return p

func _title(text: String) -> Label:
	return _lbl(text, 18, Color(0.93, 0.89, 0.8))

func _lbl(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l

## THE GLOSSARY. The game explained its CARDS -- every keyword has a description -- and never its
## own vocabulary: what Chips are as opposed to Mult, what Mercury is as opposed to Salt, what a
## law or a seal or the Keystone is. A player told us they felt they did not understand most of
## it, and an audit put a number on it: twenty tooltips in the whole game and no definition of a
## single core term.
const GLOSSARY_TERMS := [
	"CHIPS", "MULT", "KEYSTONE", "DISCARD", "ASPECT", "LAW",
	"RTEC", "SOL", "ARCANUM", "EDITION", "SEAL", "VEIL", "DEPTH",
]

func _open_glossary() -> void:
	if _glossary != null and is_instance_valid(_glossary):
		_glossary.queue_free()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.985)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 8)
	root.add_child(col)
	var head := MarginContainer.new()
	for side in ["left", "top", "right"]:
		head.add_theme_constant_override("margin_" + side, 18)
	col.add_child(head)
	var head_col := VBoxContainer.new()
	head_col.add_theme_constant_override("separation", 4)
	head.add_child(head_col)
	var title_l := _title(tr("GLOSSARY_TITLE"))
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head_col.add_child(title_l)
	var hint := _lbl(tr("GLOSSARY_HINT"), 13, Color(0.66, 0.64, 0.72))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head_col.add_child(hint)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(sc)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	for term in GLOSSARY_TERMS:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)
		row.custom_minimum_size = Vector2(880, 0)
		var name_l := _lbl(tr("HELP_" + term), 16, Color(0.95, 0.9, 0.72))
		row.add_child(name_l)
		var desc := _lbl(tr("HELP_" + term + "_D"), 13, Color(0.76, 0.78, 0.84))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(880, 0)
		row.add_child(desc)
		var wrap := CenterContainer.new()
		wrap.add_child(row)
		body.add_child(wrap)
	var close := _menu_btn(tr("COMMON_CLOSE"), func() -> void:
		if _glossary != null and is_instance_valid(_glossary):
			_glossary.queue_free()
		_glossary = null)
	var cw := CenterContainer.new()
	cw.add_child(close)
	col.add_child(cw)
	_glossary = root
	add_child(root)

func _menu_btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 36)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(cb)
	return b
