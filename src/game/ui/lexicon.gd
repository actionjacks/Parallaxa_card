class_name Lexicon
extends RefCounted
## THE GAME EXPLAINS ITSELF WHERE IT SPEAKS. The glossary answered "what is a Mult?" only if the
## player knew to leave the fight and open it -- which is the one moment they are least willing to.
## This marks every glossary term wherever it appears in on-screen prose, so the word itself is the
## button: click it and the definition opens over the fight, in place.
##
## Matching is DATA, not code. Polish inflects ("chipsy", "chipsow", "chipsom"), so each term owns a
## locale key `LEX_<TERM>` holding a `|`-separated list of forms per language. Adding a word never
## means touching this file.
##
## Rendering is BBCode `[url=TERM]`, which means the host has to be a RichTextLabel -- see
## `ink()`, which builds one already wired to open the panel.

## The vocabulary, mirroring Overlays.GLOSSARY_TERMS. Ordered longest-match-first at build time so
## "MULT" can never eat the "MULT" inside another marked word.
const TERMS := [
	"CHIPS", "MULT", "KEYSTONE", "DISCARD", "ASPECT", "LAW",
	"RTEC", "SOL", "ARCANUM", "EDITION", "SEAL", "VEIL", "DEPTH",
]

const INK := "9fd4ff"        ## the one colour that means "this word will explain itself"

static var _cache: Array = []      ## [[regex, term], ...]
static var _cache_locale: String = ""   ## which language _cache was built for

## Every [regex, term] pair, longest form first so a short term never splits a longer one.
static func _patterns() -> Array:
	# KEYED BY LOCALE. A plain "build once" cache is a trap here: the pattern table is first
	# touched while Godot is still on its default locale, so the English forms would be frozen in
	# for the whole process and no Polish word would ever highlight.
	var loc: String = TranslationServer.get_locale()
	if not _cache.is_empty() and _cache_locale == loc:
		return _cache
	_cache = []
	_cache_locale = loc
	var rows: Array = []
	for term in TERMS:
		var forms: String = TranslationServer.translate("LEX_" + term)
		if forms == "" or forms == "LEX_" + term:
			continue
		for f in forms.split("|", false):
			var w := String(f).strip_edges()
			if w != "":
				rows.append([w, term])
	# longest first: "Arkanum Sadu" must win over "Arkanum"
	rows.sort_custom(func(a, b): return String(a[0]).length() > String(b[0]).length())
	for r in rows:
		var rx := RegEx.new()
		# (?i) case-insensitive; the boundaries are explicit because \b does not understand
		# Polish diacritics under Godot's regex engine.
		rx.compile("(?i)(^|[^\\p{L}])(" + _escape(String(r[0])) + ")($|[^\\p{L}])")
		if rx.is_valid():
			_cache.append([rx, String(r[1])])
	return _cache

## Drop the cache when the language changes -- otherwise Polish forms would keep matching English.
static func invalidate() -> void:
	_cache = []
	_cache_locale = ""

static func _escape(s: String) -> String:
	var out := ""
	for ch in s:
		if "\\^$.|?*+()[]{}".contains(ch):
			out += "\\" + ch
		else:
			out += ch
	return out

## Plain text -> BBCode with every known term turned into a clickable, tinted link.
## Marks each term only ONCE per string: a paragraph with "chips" five times should read as prose,
## not as a wall of links.
static func mark(text: String) -> String:
	if text == "":
		return text
	var out := text
	var done: Dictionary = {}
	for pair in _patterns():
		var rx: RegEx = pair[0]
		var term: String = pair[1]
		if done.has(term):
			continue
		var m := rx.search(out)
		if m == null:
			continue
		done[term] = true
		out = out.substr(0, m.get_start(2)) \
			+ "[url=%s][color=#%s]%s[/color][/url]" % [term, INK, m.get_string(2)] \
			+ out.substr(m.get_end(2))
	return out

## A RichTextLabel that renders `text` with its terms marked and opens the panel when one is
## clicked. Use in place of a Label wherever the game talks to the player in sentences.
static func ink(text: String, size: int, col: Color, host: Node) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.autowrap_mode = TextServer.AUTOWRAP_OFF
	# STOP, not PASS. A link has to WIN the hit test: with PASS the label is picked but the click
	# keeps travelling, and anything laid over the bottom bar (the hand fan reaches down there)
	# takes it instead -- the terms were highlighted, hoverable and completely unclickable.
	rt.mouse_filter = Control.MOUSE_FILTER_STOP
	rt.selection_enabled = false
	rt.add_theme_font_size_override("normal_font_size", size)
	rt.add_theme_color_override("default_color", col)
	rt.meta_clicked.connect(func(meta): open_panel(String(meta), host))
	set_text(rt, text)
	return rt

## Re-set a marked label's text (the marking is re-done, so live values stay correct).
static func set_text(rt: RichTextLabel, text: String) -> void:
	if rt == null:
		return
	rt.text = mark(text)

## The definition, over whatever is on screen. Deliberately a full overlay rather than a tooltip:
## it has to survive a mouse that moves, and it must be dismissible with one click anywhere.
static func open_panel(term: String, host: Node) -> void:
	if host == null or not host.is_inside_tree():
		return
	var layer := host.get_tree().root
	var old := layer.get_node_or_null("LexPanel")
	if old != null:
		old.queue_free()
	var root := Control.new()
	root.name = "LexPanel"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.z_index = 200
	layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(centre)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.09, 0.99)
	sb.border_color = Color(0.62, 0.83, 1.0, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(520, 0)
	panel.add_child(col)
	var name_l := Label.new()
	name_l.text = TranslationServer.translate("HELP_" + term)
	name_l.add_theme_font_size_override("font_size", 20)
	name_l.add_theme_color_override("font_color", Color(0.95, 0.9, 0.72))
	col.add_child(name_l)
	var desc := Label.new()
	desc.text = TranslationServer.translate("HELP_" + term + "_D")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(520, 0)
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.78, 0.8, 0.86))
	col.add_child(desc)
	var close := Label.new()
	close.text = TranslationServer.translate("LEX_CLOSE")
	close.add_theme_font_size_override("font_size", 12)
	close.add_theme_color_override("font_color", Color(0.55, 0.55, 0.62))
	close.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(close)
	# one click anywhere closes it -- a panel you have to aim at to dismiss is worse than no panel
	root.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			root.queue_free())
