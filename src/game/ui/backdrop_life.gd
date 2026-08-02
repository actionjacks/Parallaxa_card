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
	var haze := get_node_or_null("Haze") as TextureRect
	if haze != null:
		# scrolls by moving the tile origin: no shader, no per-pixel work
		haze.position = Vector2(fmod(_t * 5.0, 320.0) - 320.0, fmod(_t * 2.0, 180.0) - 180.0)
		haze.size = size + Vector2(320, 180)
	var pulse := get_node_or_null("Pulse") as TextureRect
	if pulse != null:
		pulse.modulate.a = 0.75 + sin(_t * 0.42) * 0.25
