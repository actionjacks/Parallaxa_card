class_name AspectSigil
extends Control
## The five Aspect suit-marks, drawn procedurally so one shape scales from a 14 px corner pip
## to a 200 px plate without a single texture. Colour alone is not identity: a player who cannot
## tell violet from red must still read the suit, so every Aspect owns a distinct SILHOUETTE.
##
##  LIFE   chalice   (Cups)      MIND  sword    (Swords)   DEATH pentacle (Pentacles)
##  CHAOS  flame     (Wands)     NATURE leaf    (the fifth suit RWS never drew)

@export var aspect: int = Aspects.Id.LIFE
@export var ink: Color = Color.WHITE
@export var filled: bool = true

func _init(p_aspect: int = Aspects.Id.LIFE, p_ink: Color = Color.WHITE, p_filled: bool = true) -> void:
	aspect = p_aspect
	ink = p_ink
	filled = p_filled
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_aspect(p_aspect: int, p_ink: Color) -> void:
	aspect = p_aspect
	ink = p_ink
	queue_redraw()

func _draw() -> void:
	var s: float = minf(size.x, size.y)
	if s <= 0.0:
		return
	var c := size * 0.5
	match aspect:
		Aspects.Id.LIFE: _chalice(c, s)
		Aspects.Id.MIND: _sword(c, s)
		Aspects.Id.DEATH: _pentacle(c, s)
		Aspects.Id.CHAOS: _flame(c, s)
		Aspects.Id.NATURE: _leaf(c, s)

func _stroke() -> float:
	return maxf(1.0, minf(size.x, size.y) * 0.09)

func _shape(pts: PackedVector2Array) -> void:
	if filled:
		draw_colored_polygon(pts, ink)
	else:
		var loop := pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, ink, _stroke())

## Cups: a bowl on a stem -- the vessel that holds.
func _chalice(c: Vector2, s: float) -> void:
	var w: float = s * 0.42
	var top: float = c.y - s * 0.34
	var bowl := PackedVector2Array([
		Vector2(c.x - w, top),
		Vector2(c.x + w, top),
		Vector2(c.x + w * 0.62, top + s * 0.30),
		Vector2(c.x, top + s * 0.40),
		Vector2(c.x - w * 0.62, top + s * 0.30),
	])
	_shape(bowl)
	draw_line(Vector2(c.x, top + s * 0.38), Vector2(c.x, c.y + s * 0.28), ink, _stroke())
	draw_line(Vector2(c.x - w * 0.72, c.y + s * 0.32), Vector2(c.x + w * 0.72, c.y + s * 0.32),
		ink, _stroke())

## Swords: blade, crossguard, grip -- the cut that divides.
func _sword(c: Vector2, s: float) -> void:
	var st := _stroke()
	var tip: float = c.y - s * 0.42
	var blade := PackedVector2Array([
		Vector2(c.x, tip),
		Vector2(c.x + s * 0.13, tip + s * 0.20),
		Vector2(c.x + s * 0.07, c.y + s * 0.18),
		Vector2(c.x - s * 0.07, c.y + s * 0.18),
		Vector2(c.x - s * 0.13, tip + s * 0.20),
	])
	_shape(blade)
	draw_line(Vector2(c.x - s * 0.26, c.y + s * 0.20), Vector2(c.x + s * 0.26, c.y + s * 0.20), ink, st)
	draw_line(Vector2(c.x, c.y + s * 0.20), Vector2(c.x, c.y + s * 0.42), ink, st)

## Pentacles: the five-pointed star in its ring -- the coin of the material world.
func _pentacle(c: Vector2, s: float) -> void:
	var r: float = s * 0.42
	var pts := PackedVector2Array()
	for i in 5:
		var a: float = -PI / 2.0 + float(i) * TAU * 2.0 / 5.0   # step by 2/5 -> pentagram
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, ink, _stroke())
	draw_arc(c, r * 1.12, 0.0, TAU, 24, ink, maxf(1.0, _stroke() * 0.8))

## Wands: a flame -- will, fire, the thing that will not sit still. The tip LEANS and the base
## is NOTCHED: at 14 px a symmetric blob would read as the Nature leaf, so the silhouette has to
## be asymmetric on purpose.
func _flame(c: Vector2, s: float) -> void:
	var pts := PackedVector2Array([
		Vector2(c.x + s * 0.16, c.y - s * 0.46),   # tip, leaning right
		Vector2(c.x + s * 0.30, c.y - s * 0.02),
		Vector2(c.x + s * 0.26, c.y + s * 0.26),
		Vector2(c.x + s * 0.06, c.y + s * 0.44),
		Vector2(c.x, c.y + s * 0.18),              # notch cut into the base
		Vector2(c.x - s * 0.10, c.y + s * 0.42),
		Vector2(c.x - s * 0.30, c.y + s * 0.18),
		Vector2(c.x - s * 0.24, c.y - s * 0.14),
		Vector2(c.x - s * 0.04, c.y - s * 0.06),
	])
	_shape(pts)

## The fifth suit: a leaf with a midrib -- growth, the only Aspect with no historical plate.
func _leaf(c: Vector2, s: float) -> void:
	var pts := PackedVector2Array()
	var steps := 14
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var w: float = sin(PI * t) * s * 0.26
		pts.append(Vector2(c.x - w, c.y - s * 0.42 + s * 0.84 * t))
	for i in range(steps + 1):
		var t: float = 1.0 - float(i) / float(steps)
		var w: float = sin(PI * t) * s * 0.26
		pts.append(Vector2(c.x + w, c.y - s * 0.42 + s * 0.84 * t))
	_shape(pts)
	draw_line(Vector2(c.x, c.y - s * 0.40), Vector2(c.x, c.y + s * 0.40),
		Color(0, 0, 0, 0.45) if filled else ink, maxf(1.0, _stroke() * 0.7))
