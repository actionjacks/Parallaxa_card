class_name CardWidget
## Shared card visual: coloured by Aspect, big rank glyph, keyword + edition tags. Used by the combat
## hand, reward, shop and deck-picker so every card reads the same. Includes hover feedback (scale +
## raise) and a large readable preview (build_preview) so the player can actually read what a card does.

const BG := Color(0.09, 0.09, 0.13)
const BG_SEL := Color(0.18, 0.18, 0.26)
const CARD_SIZE := Vector2(80, 112)

## RWS 1909 Minor Arcana illustrations for the hover preview. Four Aspects map onto the historical
## suits (design: Life=Cups, Mind=Swords, Chaos=Wands, Death=Pentacles); Nature has no historical
## suit and shows no illustration. Ranks map 1:1 (Ace=01..10, Page 11, Knight 12, Queen 13, King 14).
const MINOR_SUIT := {
	Aspects.Id.LIFE: "cups",
	Aspects.Id.MIND: "swords",
	Aspects.Id.CHAOS: "wands",
	Aspects.Id.DEATH: "pents",
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
	if card.edition != CardData.Edition.NONE:
		sb.border_color = _ed_color(card.edition)   # editioned cards glow in their edition colour
	panel.set_meta("border", sb.border_color)
	panel.mouse_entered.connect(_on_hover.bind(panel, true))
	panel.mouse_exited.connect(_on_hover.bind(panel, false))
	return panel

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
	# rank badge, top-left
	var badge := ColorRect.new()
	badge.color = Color(0.05, 0.05, 0.08, 0.85)
	badge.position = Vector2(0, 0)
	badge.size = Vector2(22, 22)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layers.add_child(badge)
	var rank := _lbl(card.rank_glyph(), 16, col)
	rank.position = Vector2(0, 2)
	rank.size = Vector2(22, 18)
	rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layers.add_child(rank)
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
	var scrim_h := 6 + 14 * lines.size()
	var scrim := ColorRect.new()
	scrim.color = Color(0.03, 0.03, 0.05, 0.78)
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

## Plain face (no historical suit art -- e.g. Nature): the readable text layout.
static func _build_plain_face(panel: PanelContainer, card: CardData, col: Color) -> void:
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vb)
	vb.add_child(_lbl(card.rank_glyph(), 30, col))
	vb.add_child(_lbl(TranslationServer.translate(Aspects.name_key(card.aspect)), 12, Color(0.72, 0.72, 0.78)))
	if card.keyword != CardData.Keyword.NONE:
		var txt := TranslationServer.translate(CardData.keyword_name_key(card.keyword))
		if card.keyword_value > 0:
			txt += " " + str(card.keyword_value)
		vb.add_child(_lbl(txt, 12, col))
	if card.edition != CardData.Edition.NONE:
		vb.add_child(_lbl("+ " + TranslationServer.translate(CardData.edition_name_key(card.edition)), 11, _ed_color(card.edition)))

static func _on_hover(panel: PanelContainer, entering: bool) -> void:
	# Draw above neighbours WITHOUT reordering the container. move_to_front() would move the card
	# to the end of the HBox, so it jumps out from under the cursor -> exit -> back -> flicker.
	panel.z_index = 1 if entering else 0
	var target: Vector2 = panel.get_meta("base_scale") * (1.15 if entering else 1.0)
	var t := panel.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(panel, "scale", target, 0.10)

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
	panel.set_meta("base_scale", Vector2(1.1, 1.1) if on else Vector2.ONE)
	var t := panel.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(panel, "scale", panel.get_meta("base_scale"), 0.10)

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
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
