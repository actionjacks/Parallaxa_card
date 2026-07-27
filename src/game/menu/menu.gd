extends Control
## Main menu / title screen (todo.md): tarot-and-mysticism themed. New Journey / Continue (enabled
## when a run save exists) / Collection (browse every card + Arcana, RMB inspects) / Options / Quit.

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

var _collection: Control

func _ready() -> void:
	Overlays.run_active = false
	add_child(Backdrop.build())

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

	var title := _lbl("PARALLAXA", 64, Color(0.95, 0.9, 0.75))
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
	col.add_child(_menu_btn(tr("MENU_COLLECTION"), _open_collection))
	col.add_child(_menu_btn(tr("MENU_OPTIONS"), _open_options))
	col.add_child(_menu_btn(tr("MENU_QUIT"), func() -> void: get_tree().quit()))

func _new_run() -> void:
	RunState.load_pending = false
	RunState.delete_run_save()
	get_tree().change_scene_to_file(RUN_SCENE)

func _continue_run() -> void:
	RunState.load_pending = true
	get_tree().change_scene_to_file(RUN_SCENE)

func _open_options() -> void:
	var s: Control = load(SETTINGS_SCENE).instantiate()
	add_child(s)
	if s.has_signal("closed"):
		s.closed.connect(s.queue_free)
	if s.has_method("open"):
		s.open()

## Collection: every playable card (starter + reward pool) and every Arcanum. RMB inspects cards.
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
	v.add_child(_lbl(tr("MENU_COLLECTION"), 26, Color(0.93, 0.89, 0.8)))
	v.add_child(_lbl(tr("COLLECTION_HINT"), 13, Color(0.6, 0.6, 0.68)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)

	inner.add_child(_lbl(tr("COLLECTION_CARDS"), 18, Color(0.85, 0.82, 0.9)))
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(grid)
	var seen := {}
	for card in DeckLibrary.starter_deck() + DeckLibrary.reward_pool():
		var key := "%d_%d_%d_%d" % [card.rank, card.aspect, card.keyword, card.keyword_value]
		if seen.has(key):
			continue
		seen[key] = true
		grid.add_child(CardWidget.build(card))

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
		agrid.add_child(box)

	var close := _menu_btn(tr("COMMON_CLOSE"), func() -> void:
		_collection.queue_free()
		_collection = null)
	var wrap_c := CenterContainer.new()
	wrap_c.add_child(close)
	v.add_child(wrap_c)
	add_child(_collection)

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

func _lbl(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
