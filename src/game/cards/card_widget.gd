class_name CardWidget
## Shared card visual: coloured by Aspect, big rank glyph, keyword + edition tags. Used by the combat
## hand, reward, shop and deck-picker so every card reads the same. Includes hover feedback (scale +
## raise) and a large readable preview (build_preview) so the player can actually read what a card does.

const BG := Color(0.09, 0.09, 0.13)
const BG_SEL := Color(0.18, 0.18, 0.26)
## Hand cards are read at a glance while the player counts a poker hand -- 80x112 was too small
## to tell rank and suit apart without hovering, which turned every turn into a hover-hunt.
const CARD_SIZE := Vector2(108, 151)
const SPINE_W := 7.0             ## width of the Aspect colour bar down the card's left edge

## RWS 1909 Minor Arcana illustrations. Four Aspects map onto the historical suits
## (Life=Cups, Mind=Swords, Chaos=Wands, Death=Pentacles). RWS never drew a fifth suit, so
## NATURE is derived from the public-domain plates by tools/gen/gen_nature_suit.py.
## Ranks map 1:1 (Ace=01..10, Page 11, Knight 12, Queen 13, King 14).
const MINOR_SUIT := {
	Aspects.Id.LIFE: "cups",
	Aspects.Id.MIND: "swords",
	Aspects.Id.CHAOS: "wands",
	Aspects.Id.DEATH: "pents",
	Aspects.Id.NATURE: "nature",
}
static var _minor_cache: Dictionary = {}

static func minor_art(card: CardData) -> Texture2D:
	if not MINOR_SUIT.has(card.aspect):
		return null
	var key: String = "%s_%02d" % [MINOR_SUIT[card.aspect], card.rank]
	if not _minor_cache.has(key):
		var path := "res://assets/cards/minor/%s.jpg" % key
		_minor_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _minor_cache[key]

static func build(card: CardData) -> PanelContainer:
	var col := Aspects.color(card.aspect)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_border_width_all(2)
	sb.border_color = col
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 6
	sb.content_margin_top = 6
	sb.content_margin_right = 6
	sb.content_margin_bottom = 6
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = CARD_SIZE
	panel.pivot_offset = CARD_SIZE * 0.5
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.tooltip_text = _tooltip(card)
	panel.set_meta("style", sb)
	panel.set_meta("aspect", card.aspect)
	panel.set_meta("base_scale", Vector2.ONE)
	panel.set_meta("card", card)
	var art := minor_art(card)
	if art != null:
		_build_art_face(panel, card, art, col)
	else:
		_build_plain_face(panel, card, col)
	# Frame priority: edition colour > rarity colour > aspect colour.
	if card.edition != CardData.Edition.NONE:
		sb.border_color = _ed_color(card.edition)   # editioned cards glow in their edition colour
	elif card.rarity != CardData.Rarity.COMMON:
		sb.border_color = rarity_color(card.rarity)
	if card.rarity == CardData.Rarity.LEGENDARY:
		_start_legend_glow(panel, sb)
	if card.keyword == CardData.Keyword.PRZECIAZENIE:
		_add_durability_pip(panel, card)
	if card.scar > 0:
		_add_scar_mark(panel, card)
	panel.set_meta("border", sb.border_color)
	panel.mouse_entered.connect(_on_hover.bind(panel, true))
	panel.mouse_exited.connect(_on_hover.bind(panel, false))
	panel.gui_input.connect(_route_rmb.bind(card))
	return panel

static func rarity_color(r: int) -> Color:
	match r:
		CardData.Rarity.RARE: return Color("8fb8d8")
		CardData.Rarity.LEGENDARY: return Color("f2c14e")
	return Color.WHITE

## Legendary frames breathe: a slow border-alpha sine, purely cosmetic.
static func _start_legend_glow(panel: PanelContainer, sb: StyleBoxFlat) -> void:
	var tw := panel.create_tween().set_loops()
	tw.tween_method(func(a: float) -> void:
		sb.border_color = Color(sb.border_color, a), 1.0, 0.7, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(a: float) -> void:
		sb.border_color = Color(sb.border_color, a), 0.7, 1.0, 0.6).set_trans(Tween.TRANS_SINE)

## Glass (Przeciazenie) wears a VISIBLE durability counter -- the covenant forbids surprises.
## (PanelContainer forces children to the full rect, so the pip anchors inside a raw overlay.)
static func _add_durability_pip(panel: PanelContainer, card: CardData) -> void:
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(overlay)
	var left := maxi(0, card.keyword_value - card.wear)
	var pip := _lbl("*%d" % left, 13, Color("ff5a4d") if left <= 1 else Color("e8e8f0"))
	pip.anchor_left = 1.0
	pip.anchor_right = 1.0
	pip.anchor_top = 1.0
	pip.anchor_bottom = 1.0
	pip.offset_left = -26
	pip.offset_right = -2
	pip.offset_top = -20
	pip.offset_bottom = -2
	pip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	overlay.add_child(pip)

## A card that felled a Major Arcana wears the mark for the rest of the run -- the player has to
## be able to FIND their veteran in the hand, otherwise the attachment the scar exists to create
## never happens.
static func _add_scar_mark(panel: PanelContainer, card: CardData) -> void:
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(overlay)
	var mark := _lbl("+%d" % card.scar, 13, Color(0.98, 0.82, 0.35))
	mark.anchor_left = 0.0
	mark.anchor_top = 1.0
	mark.anchor_bottom = 1.0
	mark.offset_left = SPINE_W + 3
	mark.offset_right = SPINE_W + 40
	mark.offset_top = -36
	mark.offset_bottom = -20
	overlay.add_child(mark)

## RMB on ANY card, anywhere, opens the centered inspection overlay (todo.md UX brief).
static func _route_rmb(ev: InputEvent, card: CardData) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		var ml := Engine.get_main_loop()
		if ml is SceneTree:
			var ov := (ml as SceneTree).root.get_node_or_null("Overlays")
			if ov != null:
				ov.inspect(card)

## Illustrated face: the RWS art fills the card, a dark scrim keeps the keyword/edition readable,
## and the rank sits in a corner badge -- like a real TCG frame.
static func _build_art_face(panel: PanelContainer, card: CardData, art: Texture2D, col: Color) -> void:
	var layers := Control.new()
	layers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(layers)
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # BEFORE size (EXPAND_KEEP_SIZE trap)
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	t.texture = art
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layers.add_child(t)
	# COLOUR SPINE: a full-height bar of the Aspect colour down the left edge. A 2 px frame is
	# invisible once eight cards overlap in a fan -- the spine is the part that stays on screen
	# when a card is half-covered, so suit is countable without fanning the hand out.
	var spine := ColorRect.new()
	spine.color = Color(col, 0.95)
	spine.anchor_bottom = 1.0
	spine.offset_right = SPINE_W
	spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layers.add_child(spine)
	# rank badge + suit sigil, top-left: rank and SUIT together, so a hand can be counted by eye
	var badge_h: float = CARD_SIZE.y * 0.20
	var badge := ColorRect.new()
	badge.color = Color(0.05, 0.05, 0.08, 0.86)
	badge.position = Vector2(SPINE_W, 0)
	badge.size = Vector2(badge_h * 1.62, badge_h)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layers.add_child(badge)
	var rank := _lbl(card.rank_glyph(), int(badge_h * 0.62), col)
	rank.position = Vector2(SPINE_W + 1, badge_h * 0.08)
	rank.size = Vector2(badge_h * 0.78, badge_h * 0.82)
	rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layers.add_child(rank)
	var sig := AspectSigil.new(card.aspect, col, true)
	sig.position = Vector2(SPINE_W + badge_h * 0.80, badge_h * 0.16)
	sig.size = Vector2(badge_h * 0.68, badge_h * 0.68)
	layers.add_child(sig)
	# bottom scrim with keyword / edition lines
	var lines: Array = []
	if card.keyword != CardData.Keyword.NONE:
		var txt := TranslationServer.translate(CardData.keyword_name_key(card.keyword))
		if card.keyword_value > 0:
			txt += " " + str(card.keyword_value)
		lines.append([txt, col])
	if card.edition != CardData.Edition.NONE:
		lines.append(["+ " + TranslationServer.translate(CardData.edition_name_key(card.edition)), _ed_color(card.edition)])
	if lines.is_empty():
		return
	var row_h := 16
	var scrim_h := 6 + row_h * lines.size()
	var scrim := ColorRect.new()
	scrim.color = Color(0.03, 0.03, 0.05, 0.78)
	scrim.anchor_top = 1.0
	scrim.anchor_bottom = 1.0
	scrim.anchor_right = 1.0
	scrim.offset_top = -scrim_h
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layers.add_child(scrim)
	for i in lines.size():
		var l := _lbl(lines[i][0], 12, lines[i][1])
		l.anchor_top = 1.0
		l.anchor_bottom = 1.0
		l.anchor_right = 1.0
		l.offset_left = SPINE_W
		l.offset_top = -scrim_h + 3 + i * row_h
		l.offset_bottom = -scrim_h + 3 + row_h + i * row_h
		layers.add_child(l)

## NATURE face: the fifth Aspect has no historical RWS suit, so it wears a DELIBERATE style
## of its own (verdant gradient, double frame, diamond ornament) -- never an empty panel that
## reads as a missing asset. Layout language matches the art faces (keyword on a bottom scrim).
static func _build_plain_face(panel: PanelContainer, card: CardData, col: Color) -> void:
	var layers := Control.new()
	layers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(layers)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.10, 0.17, 0.10))
	grad.set_color(1, Color(0.05, 0.09, 0.05))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	var bg := TextureRect.new()
	bg.texture = gt
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layers.add_child(bg)
	# inner frame + rotated diamond ornament (primitives: intentional, not placeholder)
	var inner := Panel.new()
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color(0, 0, 0, 0)
	isb.set_border_width_all(1)
	isb.border_color = Color(col, 0.55)
	inner.add_theme_stylebox_override("panel", isb)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 4
	inner.offset_top = 4
	inner.offset_right = -4
	inner.offset_bottom = -4
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layers.add_child(inner)
	for i in 2:
		var dia := Panel.new()
		var dsb := StyleBoxFlat.new()
		dsb.bg_color = Color(0, 0, 0, 0)
		dsb.set_border_width_all(1)
		dsb.border_color = Color(col, 0.5 - i * 0.2)
		dia.add_theme_stylebox_override("panel", dsb)
		dia.size = Vector2(34 + i * 14, 34 + i * 14)
		dia.position = Vector2(40 - dia.size.x / 2.0, 52 - dia.size.y / 2.0)
		dia.pivot_offset = dia.size * 0.5
		dia.rotation_degrees = 45
		dia.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layers.add_child(dia)
	var rank := _lbl(card.rank_glyph(), 30, col)
	rank.position = Vector2(0, 34)
	rank.size = Vector2(80, 36)
	rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layers.add_child(rank)
	var asp := _lbl(TranslationServer.translate(Aspects.name_key(card.aspect)), 11, Color(0.62, 0.74, 0.6))
	asp.position = Vector2(0, 8)
	asp.size = Vector2(80, 14)
	asp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layers.add_child(asp)
	# bottom scrim with keyword/edition -- same grammar as the illustrated faces
	var lines: Array = []
	if card.keyword != CardData.Keyword.NONE:
		var txt := TranslationServer.translate(CardData.keyword_name_key(card.keyword))
		if card.keyword_value > 0:
			txt += " " + str(card.keyword_value)
		lines.append([txt, col])
	if card.edition != CardData.Edition.NONE:
		lines.append(["+ " + TranslationServer.translate(CardData.edition_name_key(card.edition)), _ed_color(card.edition)])
	if lines.is_empty():
		return
	var scrim_h := 6 + 14 * lines.size()
	var scrim := ColorRect.new()
	scrim.color = Color(0.03, 0.05, 0.03, 0.78)
	scrim.anchor_top = 1.0
	scrim.anchor_bottom = 1.0
	scrim.anchor_right = 1.0
	scrim.offset_top = -scrim_h
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layers.add_child(scrim)
	for i in lines.size():
		var l := _lbl(lines[i][0], 11, lines[i][1])
		l.anchor_top = 1.0
		l.anchor_bottom = 1.0
		l.anchor_right = 1.0
		l.offset_top = -scrim_h + 3 + i * 14
		l.offset_bottom = -scrim_h + 17 + i * 14
		layers.add_child(l)

static func _on_hover(panel: PanelContainer, entering: bool) -> void:
	# Draw above neighbours WITHOUT reordering the container. move_to_front() would move the card
	# to the end of the HBox, so it jumps out from under the cursor -> exit -> back -> flicker.
	panel.z_index = 2 if entering else 0
	# Hand cards opt into a bigger, readable grow (HandFan sets "hover_scale"); grids stay subtle.
	var grow: float = panel.get_meta("hover_scale", 1.15)
	var target: Vector2 = panel.get_meta("base_scale") * (grow if entering else 1.0)
	var t := panel.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(panel, "scale", target, 0.10)

static func set_selected(panel: PanelContainer, on: bool) -> void:
	var sb: StyleBoxFlat = panel.get_meta("style")
	if on:
		# GOLD, not white: white sinks into the pale edges of the 1909 scans -- the staged play
		# must be countable at a glance.
		sb.border_color = Color(0.98, 0.82, 0.35)
		sb.bg_color = BG_SEL
		sb.set_border_width_all(3)
	else:
		sb.border_color = panel.get_meta("border", Aspects.color(int(panel.get_meta("aspect"))))
		sb.bg_color = BG
		sb.set_border_width_all(2)
	panel.set_meta("base_scale", Vector2(1.1, 1.1) if on else Vector2.ONE)
	panel.set_meta("sel", on)   # HandFan half-raises selected cards (the staged play)
	var t := panel.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(panel, "scale", panel.get_meta("base_scale"), 0.10)

## THE ORDER PIP: a selected card wears the position it will fire in, and the LAST one wears
## the Keystone mark. Without this the play order is invisible, and an invisible mechanic is
## not a decision. Selection order IS play order, so the player sets it by the order they click.
static func set_order(panel: PanelContainer, index: int, keystone: bool) -> void:
	var pip: Control = panel.get_node_or_null("OrderPip")
	if index < 0:
		if pip != null:
			pip.queue_free()
		return
	if pip == null:
		var holder := Control.new()
		holder.name = "OrderPip"
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(holder)
		var badge := ColorRect.new()
		badge.name = "Badge"
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(badge)
		var num := _lbl("", 15, Color(0.06, 0.05, 0.04))
		num.name = "Num"
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(num)
		pip = holder
	var badge2: ColorRect = pip.get_node("Badge")
	var num2: Label = pip.get_node("Num")
	var sz := 24.0
	badge2.position = Vector2(CARD_SIZE.x - sz - 3.0, 3.0)
	badge2.size = Vector2(sz, sz)
	badge2.color = Color(0.98, 0.82, 0.35) if keystone else Color(0.86, 0.86, 0.92)
	num2.position = badge2.position
	num2.size = badge2.size
	num2.text = str(index + 1)
	num2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

## A large, readable card face: big rank, aspect name, keyword + its full effect text, edition.
static func build_preview(card: CardData) -> PanelContainer:
	var col := Aspects.color(card.aspect)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.15, 0.98)
	sb.set_border_width_all(3)
	sb.border_color = _border_for(card)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 16
	sb.content_margin_top = 14
	sb.content_margin_right = 16
	sb.content_margin_bottom = 14
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(240, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var art := minor_art(card)
	if art != null:
		var t := TextureRect.new()
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # BEFORE size (EXPAND_KEEP_SIZE trap)
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		t.texture = art
		t.custom_minimum_size = Vector2(0, 180)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(t)
	vb.add_child(_lbl(card.rank_glyph(), 54, col))
	vb.add_child(_lbl(TranslationServer.translate(Aspects.name_key(card.aspect)), 20, col))
	if card.keyword != CardData.Keyword.NONE:
		var kh := TranslationServer.translate(CardData.keyword_name_key(card.keyword))
		if card.keyword_value > 0:
			kh += " " + str(card.keyword_value)
		vb.add_child(_lbl(kh, 18, Color(0.95, 0.9, 0.8)))
		var desc_key := CardData.keyword_desc_key(card.keyword)
		var desc := TranslationServer.translate(desc_key)
		if desc != "" and desc != desc_key:
			var d := _lbl(desc, 15, Color(0.75, 0.78, 0.85))
			d.autowrap_mode = TextServer.AUTOWRAP_WORD
			d.custom_minimum_size = Vector2(208, 0)
			vb.add_child(d)
	if card.edition != CardData.Edition.NONE:
		vb.add_child(_lbl("+ " + TranslationServer.translate(CardData.edition_name_key(card.edition)), 16, _ed_color(card.edition)))
	return panel

static func _border_for(card: CardData) -> Color:
	return _ed_color(card.edition) if card.edition != CardData.Edition.NONE else Aspects.color(card.aspect)

static func _ed_color(e: int) -> Color:
	match e:
		CardData.Edition.FOIL: return Color(0.55, 0.85, 1.0)
		CardData.Edition.HOLO: return Color(1.0, 0.55, 0.85)
		CardData.Edition.POLYCHROME: return Color(0.95, 0.82, 0.4)
	return Color.WHITE

static func _tooltip(card: CardData) -> String:
	var t := TranslationServer.translate(Aspects.name_key(card.aspect))
	if card.rank >= 11:
		t += "  (" + TranslationServer.translate("COURT_LEGEND") + ")"
	if card.keyword != CardData.Keyword.NONE:
		var kw_key := CardData.keyword_name_key(card.keyword)
		t += " - " + TranslationServer.translate(kw_key)
		var desc_key := CardData.keyword_desc_key(card.keyword)
		var desc := TranslationServer.translate(desc_key)
		if desc != "" and desc != desc_key:
			t += "\n" + desc
	if card.edition != CardData.Edition.NONE:
		t += "\n+ " + TranslationServer.translate(CardData.edition_name_key(card.edition))
	return t

static func _lbl(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
