class_name ArenaView
extends SubViewportContainer
## THE ROOM THE DUEL HAPPENS IN. The arena was a flat colour with a cut-out figure pasted on it;
## this puts a floor under the fight and darkness behind it, so the opponent stands somewhere
## instead of floating.
##
## Same pattern as TowerView, for the same reason: rendered into a SubViewport BEHIND the HUD, so
## it costs the 720p layout budget nothing and every existing 2D element keeps working on top.
## The middle column of this scene has overflowed three times in this project's history; a 3D
## arena built as a flow child would have made it four.
##
## Depth is carried by a floor plane, a back wall lost in fog and one warm light near the table
## edge -- not by geometry. Under software GL (the hidden test screen) that is the difference
## between a scene that renders and one that crawls.

const FLOOR_Y := -1.15
## Framing is a budget, not a preference: the top bar owns 0..100 px and the hand owns 500..720, so
## the opponent has to live inside the band between them. At this size and this camera the figure
## spans roughly 205..570 px -- its feet pass behind the fan, which is what the depth is for.
const PIXEL_SIZE := 0.0072
const FIG_Z := -1.5
## The opponent does not stand on the table -- it looms over it. Lifting the figure is what buys
## the band under it back for the score readout; dropping the camera instead only tips the room.
const FIG_LIFT := 1.50
const CAM_Y := 0.55
const CAM_Z := 5.6
var _world: SubViewport
var _cam: Camera3D
var _key: OmniLight3D
var _back_glow: OmniLight3D     ## the wash behind the opponent, tinted by its colour
var _accent := Color(0.55, 0.2, 0.24)
var _t := 0.0
## THE OPPONENT IN THREE PLANES. One cut-out, however good, reads as a picture lifted off a card;
## what sells volume is PARALLAX -- material at different distances sliding past each other as the
## view drifts. tools/gen/gen_foe_layers.py derives the three (mass behind, plate, engraved relief
## in front) and they hang at different Z, each with its own sway. The camera already breathes, so
## the depth is real geometry rather than a shader -- which also means it survives software GL.
var _layers: Array = []        ## [Sprite3D] back -> fore
var _base_px: Array = []       ## each plane's resting pixel_size, so the breath has a baseline
var _atlases: Array = []       ## matching AtlasTexture per layer, stepped together
var _fig: Sprite3D             ## the mid plane, kept as the framing reference
var _blob: MeshInstance3D       ## contact shadow under the figure
var _frames := 0
var _cell := Vector2.ZERO
var _ft := 0.0
var _fi := 0
var _push := 0.0        ## momentary camera dolly: + leans in on your blow, - flinches back on theirs

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stretch = true

func _ready() -> void:
	_world = SubViewport.new()
	_world.transparent_bg = true
	_world.own_world_3d = true          # never inherit the main (2D) world -- that renders black
	_world.msaa_3d = Viewport.MSAA_DISABLED
	_world.size = Vector2i(1280, 720)
	add_child(_world)
	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 52.0
	_cam.position = Vector3(0, CAM_Y, CAM_Z)
	_world.add_child(_cam)
	_build()
	set_process(true)

func _mat(col: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	# mid-grey base: the albedo tint MULTIPLIES, so darkness has to come from the lighting or the
	# surface renders as a black slab under every lamp
	m.albedo_color = col
	m.roughness = rough
	m.metallic = 0.0
	return m

func _build() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.028, 0.042)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.20, 0.30)
	env.ambient_light_energy = 0.16
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.05, 0.045, 0.07)
	env.fog_density = 0.085
	env.fog_depth_begin = 4.0
	env.fog_depth_end = 22.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_cam.environment = env
	_cam.attributes = CameraAttributesPractical.new()

	# the table the cards are read on: a plane the figure can stand behind
	var floor_m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(26, 26)
	floor_m.mesh = pm
	floor_m.position = Vector3(0, FLOOR_Y, -2.0)
	floor_m.material_override = _mat(Color(0.19, 0.17, 0.21), 0.96)
	_world.add_child(floor_m)

	# a far wall, mostly swallowed by fog: it stops the void reading as a hole
	var wall := MeshInstance3D.new()
	var wm := PlaneMesh.new()
	wm.size = Vector2(30, 14)
	wall.mesh = wm
	wall.rotation_degrees = Vector3(90, 0, 0)
	wall.position = Vector3(0, 4.0, -11.0)
	wall.material_override = _mat(Color(0.15, 0.13, 0.18), 0.98)
	_world.add_child(wall)

	# one warm source at the table's near edge -- the candle the reading is done by
	_key = OmniLight3D.new()
	_key.light_color = Color(1.0, 0.76, 0.48)
	_key.light_energy = 4.6
	_key.omni_range = 11.0
	_key.position = Vector3(-1.4, 1.2, 2.6)
	_world.add_child(_key)
	# DEPTH NEEDS SOMETHING TO BE DEEP INTO. Two pillars flanking the table and a far glow behind
	# the figure: the fog then has objects to swallow at different distances instead of an empty
	# gradient, and the camera drift has something to slide the opponent against.
	for side in [-1.0, 1.0]:
		var col := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.30
		cm.bottom_radius = 0.38
		cm.height = 6.0
		cm.radial_segments = 12          # software GL: cheap round, not smooth round
		col.mesh = cm
		col.position = Vector3(side * 4.6, FLOOR_Y + 3.0, -6.0)
		col.material_override = _mat(Color(0.17, 0.155, 0.20), 0.95)
		_world.add_child(col)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.42, 0.36, 0.62)
	glow.light_energy = 2.2
	glow.omni_range = 9.0
	glow.position = Vector3(0.0, 1.4, -7.2)
	_world.add_child(glow)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.62, 0.70, 1.0)
	rim.light_energy = 0.85
	rim.rotation_degrees = Vector3(-24, 158, 0)
	_world.add_child(rim)
	# The stage light: a broad wash on the back wall, in the enemy's colour. A figure with nothing
	# lit behind it reads as a cut-out; one standing against a glow reads as standing THERE.
	_back_glow = OmniLight3D.new()
	_back_glow.light_color = Color(0.55, 0.28, 0.62)
	_back_glow.light_energy = 3.2
	_back_glow.omni_range = 11.0
	_back_glow.position = Vector3(0.0, 1.6, -6.4)
	_world.add_child(_back_glow)

## THE OPPONENT, STANDING IN THE ROOM. Until now the figure was a 2D layer floating ABOVE the
## 3D room, so the floor and the character were two unrelated worlds. As a Sprite3D it stands on
## that floor, catches the same candle, and drops a shadow -- which is the whole reason to have
## built a room at all.
func set_figure(tex: Texture2D, frames: int) -> void:
	for l in _layers:
		if is_instance_valid(l):
			l.queue_free()
	_layers.clear()
	_base_px.clear()
	_atlases.clear()
	_fig = null
	if _blob != null:
		_blob.queue_free()
		_blob = null
	if tex == null or _world == null:
		return
	_frames = maxi(1, frames)
	_cell = Vector2(float(tex.get_width()) / float(_frames), float(tex.get_height()))
	# name, z offset, tint, scale. The back plane is a touch larger so its edge shows past the
	# shoulders; the fore plane a touch smaller so the relief sits INSIDE the body.
	# name, z, tint, scale, hard_cut. Only the MID plane wants a hard silhouette: DISCARD on a
	# soft mask (the dilated mass, the contrast relief) shreds it into speckle instead of reading
	# as depth -- which is exactly what it did on the first pass.
	var specs: Array = [
		["_back", -0.70, Color(0.70, 0.66, 0.80, 0.85), 1.04, false],
		# the engravings are ink-heavy; the plate needs lifting or the demon reads as a silhouette
		["_mid", 0.0, Color(1.62, 1.55, 1.44), 1.0, true],
		["_fore", 0.55, Color(1.25, 1.20, 1.10, 0.62), 0.99, false],
	]
	var base_path: String = tex.resource_path
	for spec in specs:
		var t: Texture2D = tex
		if base_path != "":
			var lp: String = base_path.get_base_dir() + "/layers/" \
				+ base_path.get_file().get_basename() + String(spec[0]) + ".png"
			if ResourceLoader.exists(lp):
				t = load(lp)
			elif String(spec[0]) != "_mid":
				continue          # no derived layer on disk: fall back to the single plate
		var at := AtlasTexture.new()
		at.atlas = t
		at.region = Rect2(0, 0, _cell.x, _cell.y)
		var sp := Sprite3D.new()
		sp.texture = at
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.shaded = true
		sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD if bool(spec[4]) else SpriteBase3D.ALPHA_CUT_DISABLED
		sp.transparent = true
		sp.no_depth_test = not bool(spec[4])   # soft planes never fight the plate for depth
		sp.pixel_size = PIXEL_SIZE * float(spec[3])
		sp.modulate = spec[2]
		sp.position = Vector3(0.0, FLOOR_Y + FIG_LIFT + _cell.y * sp.pixel_size * 0.5, FIG_Z + float(spec[1]))
		_world.add_child(sp)
		_layers.append(sp)
		_base_px.append(sp.pixel_size)
		_atlases.append(at)
		if String(spec[0]) == "_mid":
			_fig = sp
	# a soft blob under it -- a real shadow would need a shadow-casting light, which software GL
	# cannot afford; a dark ellipse on the floor sells the contact just as well.
	_blob = MeshInstance3D.new()
	var bm := PlaneMesh.new()
	bm.size = Vector2(1.5, 0.8)
	_blob.mesh = bm
	_blob.position = Vector3(0.0, FLOOR_Y + 0.012, FIG_Z + 0.05)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.0, 0.0, 0.0, 0.38)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_blob.material_override = bmat
	_world.add_child(_blob)

## The room takes the enemy's colour, so a biome reads before a single word is on screen.
func set_accent(accent: Color) -> void:
	_accent = accent
	if _key != null:
		_key.light_color = Color(1.0, 0.76, 0.48).lerp(accent, 0.35)
	if _back_glow != null:
		_back_glow.light_color = accent.lerp(Color(0.30, 0.16, 0.38), 0.45)

## A landed blow pushes the camera IN: the room leans toward the enemy, so the hit has weight.
func punch(strength: float = 1.0) -> void:
	if Juice.reduce_motion():
		return
	_push = 0.30 * strength

## The enemy's blow pushes the camera BACK -- the room flinches away from you. Opposite sign to
## punch(), so the two beats of a turn read as two different things instead of one wobble.
func recoil(strength: float = 1.0) -> void:
	if Juice.reduce_motion():
		return
	_push = -0.42 * strength

func _process(delta: float) -> void:
	if _cam == null:
		return
	_t += delta
	# move_toward, not maxf: the recoil is NEGATIVE, and clamping at zero would have swallowed it
	# whole -- the pull-back would never have appeared on screen.
	_push = move_toward(_push, 0.0, delta * 1.6)
	if Juice.reduce_motion():
		_cam.position = Vector3(0, CAM_Y, CAM_Z)
		for sp: Sprite3D in _layers:
			if is_instance_valid(sp):
				sp.position.x = 0.0
				sp.position.y = FLOOR_Y + FIG_LIFT + _cell.y * sp.pixel_size * 0.5
		return
	# a breath of drift, so the room is never a still photograph
	_cam.position = Vector3(sin(_t * 0.21) * 0.10, CAM_Y + sin(_t * 0.17) * 0.05, CAM_Z - _push)
	# the engraving steps between carved poses, same 10 fps as the plate it replaces
	if _frames > 1 and not _atlases.is_empty():
		_ft += delta * 10.0
		if _ft >= 1.0:
			_ft -= 1.0
			_fi = (_fi + 1) % _frames
			for at: AtlasTexture in _atlases:
				at.region = Rect2(float(_fi) * _cell.x, 0.0, _cell.x, _cell.y)
	# THE PARALLAX ITSELF. Each plane drifts a little more than the one behind it, so the relief
	# leads and the mass trails. Tiny amplitudes on purpose: this must be felt as volume, never
	# noticed as movement.
	for i in _layers.size():
		var sp: Sprite3D = _layers[i]
		if not is_instance_valid(sp):
			continue
		var k: float = float(i) - 1.0            # -1 back, 0 mid, +1 fore
		# Amplitudes an order up from the first pass: "felt, never noticed" turned out to be
		# neither. The planes now visibly slide across each other, which is the whole effect --
		# and because they sit at different Z, the camera's own drift multiplies it.
		sp.position.x = sin(_t * 0.63 + k * 0.9) * 0.105 * k
		sp.position.y = FLOOR_Y + FIG_LIFT + _cell.y * sp.pixel_size * 0.5 \
			+ sin(_t * 0.47 + k * 1.4) * 0.055 * absf(k)
		sp.rotation.z = sin(_t * 0.31 + k * 0.7) * 0.022 * k
		var breath: float = 1.0 + sin(_t * 0.9 + k * 0.5) * 0.022
		sp.pixel_size = _base_px[i] * breath
