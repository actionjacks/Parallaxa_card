class_name HandFan
extends Control
## Arena-style hand: children (CardWidget panels) overlap in a flat, gently tilted row at the
## bottom of the screen (MTG Arena look) -- the container NEVER fights the layout back (plain
## Control), so scale/hover animations stay safe. relayout() tweens every card to its slot, which
## also gives the "hand closes the gap" feel after a card is played (fly-outs are reparented away
## by combat, so the remaining cards glide together).
## Hovered cards straighten, rise and GROW (readable at a glance, neighbours stay put); selected
## cards (meta "sel" from CardWidget.set_selected) stay half-raised so the staged play reads.

const SPACING_MAX := 74.0        ## < card width: neighbours overlap like a held hand
const ARC_ROT_STEP := 1.8        ## degrees of tilt per slot away from the centre (subtle)
const ARC_DIP := 3.0             ## vertical dip per slot^1.5 towards the edges
## Hover does NOT lift the card: it GROWS from its bottom edge (pivot bottom-centre), so the
## point under the cursor never leaves the card -- the enter/exit flicker cannot happen. The
## visual "rise" comes from the scale alone (the top edge climbs ~50 px at 1.45x), Arena-style.
const RAISE_HOVER := 0.0
const RAISE_SELECTED := 26.0
const CARD_W := 80.0
const CARD_H := 112.0
const HOVER_SCALE := 1.45        ## the hovered card grows enough to read everything

var _tweens: Dictionary = {}     ## child -> its slot tween (killed on retarget)

func _ready() -> void:
	custom_minimum_size = Vector2(0, 148)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # cards themselves take the mouse
	# The first reconcile can run before the container layout assigns our width (size.x == 0),
	# which piles every card at the origin -- re-fan whenever the actual width arrives.
	resized.connect(relayout.bind(false))

func relayout(animated: bool = true) -> void:
	var cards: Array = []
	for ch in get_children():
		if ch is Control and ch.visible:
			cards.append(ch)
	var n := cards.size()
	if n == 0:
		return
	var spacing: float = minf(SPACING_MAX, (size.x - 160.0) / maxf(n - 1, 1.0))
	for i in n:
		var panel: Control = cards[i]
		if not panel.has_meta("fan_hooked"):
			panel.set_meta("fan_hooked", true)
			# Hand cards grow more on hover than grid cards, from the bottom-centre (upward),
			# so the enlarged face never dives under the screen edge.
			panel.set_meta("hover_scale", HOVER_SCALE)
			panel.pivot_offset = Vector2(CARD_W * 0.5, CARD_H)
			panel.mouse_entered.connect(_on_child_hover.bind(panel, true))
			panel.mouse_exited.connect(_on_child_hover.bind(panel, false))
		var c := float(i) - float(n - 1) / 2.0
		var hovered: bool = panel.get_meta("fan_hover", false)
		var selected: bool = panel.get_meta("sel", false)
		var x := size.x / 2.0 + c * spacing - CARD_W / 2.0
		var y := 24.0 + pow(absf(c), 1.5) * ARC_DIP
		if hovered:
			y -= RAISE_HOVER
		elif selected:
			y -= RAISE_SELECTED
		var rot := 0.0 if hovered else c * ARC_ROT_STEP
		_glide(panel, Vector2(x, y), rot, animated)

func _on_child_hover(panel: Control, entering: bool) -> void:
	panel.set_meta("fan_hover", entering)
	relayout()

func _glide(panel: Control, pos: Vector2, rot_deg: float, animated: bool) -> void:
	if _tweens.has(panel) and is_instance_valid(_tweens[panel]):
		_tweens[panel].kill()
	if not animated:
		panel.position = pos
		panel.rotation_degrees = rot_deg
		return
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "position", pos, 0.16)
	tw.tween_property(panel, "rotation_degrees", rot_deg, 0.16)
	_tweens[panel] = tw
