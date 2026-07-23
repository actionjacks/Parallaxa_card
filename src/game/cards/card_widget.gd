class_name CardWidget
## Shared card visual: coloured by Aspect, big rank glyph, keyword tag. Used by the combat hand,
## the reward draft and the shop, so every card reads the same everywhere.

const BG := Color(0.09, 0.09, 0.13)
const BG_SEL := Color(0.18, 0.18, 0.26)
const CARD_SIZE := Vector2(80, 112)

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
	panel.tooltip_text = _tooltip(card)
	panel.set_meta("style", sb)
	panel.set_meta("aspect", card.aspect)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vb)
	vb.add_child(_lbl(card.rank_glyph(), 30, col))
	vb.add_child(_lbl(TranslationServer.translate(Aspects.name_key(card.aspect)), 12, Color(0.72, 0.72, 0.78)))
	if card.keyword != CardData.Keyword.NONE:
		var txt := TranslationServer.translate(CardData.keyword_name_key(card.keyword))
		if card.keyword_value > 0:
			txt += " " + str(card.keyword_value)
		vb.add_child(_lbl(txt, 11, col))
	if card.edition != CardData.Edition.NONE:
		vb.add_child(_lbl("+ " + TranslationServer.translate(CardData.edition_name_key(card.edition)), 10, _ed_color(card.edition)))
		sb.border_color = _ed_color(card.edition)   # editioned cards glow in their edition colour
	panel.set_meta("border", sb.border_color)
	return panel

static func _ed_color(e: int) -> Color:
	match e:
		CardData.Edition.FOIL: return Color(0.55, 0.85, 1.0)
		CardData.Edition.HOLO: return Color(1.0, 0.55, 0.85)
		CardData.Edition.POLYCHROME: return Color(0.95, 0.82, 0.4)
	return Color.WHITE

static func set_selected(panel: PanelContainer, on: bool) -> void:
	var sb: StyleBoxFlat = panel.get_meta("style")
	if on:
		sb.border_color = Color.WHITE
		sb.bg_color = BG_SEL
		sb.set_border_width_all(3)
	else:
		sb.border_color = panel.get_meta("border", Aspects.color(int(panel.get_meta("aspect"))))
		sb.bg_color = BG
		sb.set_border_width_all(2)

static func _tooltip(card: CardData) -> String:
	var t := TranslationServer.translate(Aspects.name_key(card.aspect))
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

static func _lbl(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
