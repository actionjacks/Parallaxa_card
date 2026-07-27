class_name HandFan
extends Control
## Hearthstone-style hand: children (CardWidget panels) are laid out on an arc -- rotated by their
## distance from the centre, dipped towards the edges. The container NEVER fights the layout back
## (plain Control), so scale/hover animations stay safe. relayout() tweens every card to its slot,
## which also gives the "hand closes the gap" feel after a card is played (fly-outs are reparented
## away by combat, so the remaining cards glide together).
## Hovered cards straighten and rise; selected cards (meta "sel" from CardWidget.set_selected)
## stay half-raised so the staged play reads at a glance.

const SPACING_MAX := 88.0
const ARC_ROT_STEP := 3.5        ## degrees of tilt per slot away from the centre
const ARC_DIP := 5.0             ## vertical dip per slot^1.5 towards the edges
const RAISE_HOVER := 30.0
const RAISE_SELECTED := 18.0
const CARD_W := 80.0

var _tweens: Dictionary = {}     ## child -> its slot tween (killed on retarget)

func _ready() -> void:
	custom_minimum_size = Vector2(0, 156)
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
