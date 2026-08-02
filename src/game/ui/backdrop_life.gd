extends Control
## The heartbeat of the shared backdrop. Everything it animates was BUILT by Backdrop.build(); this
## script only moves it, so a screen costs one texture scroll and one alpha tween per frame no
## matter how many screens use it.
##
## Deliberately tiny amplitudes and long periods: a background that announces itself competes with
## the content in front of it. This should be felt when the eye rests, and never noticed when it
## does not.

var _t := 0.0

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	if Juice.reduce_motion():
		return
	_t += delta
	# THE HAZE NO LONGER MOVES. Scrolling it meant setting position and size on a FULL_RECT child
	# every frame, and the anchors fought that assignment right back -- the layout never settled and
	# the whole game hung. It stays as a static layer of air; the motes and the pulse carry the
	# motion, and neither of them touches layout.
	var pulse := get_node_or_null("Pulse") as TextureRect
	if pulse != null:
		pulse.modulate.a = 0.75 + sin(_t * 0.42) * 0.25
