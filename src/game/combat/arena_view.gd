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
var _world: SubViewport
var _cam: Camera3D
var _key: OmniLight3D
var _accent := Color(0.55, 0.2, 0.24)
var _t := 0.0
var _fig: Sprite3D              ## the opponent, standing on the floor rather than floating over it
var _blob: MeshInstance3D       ## contact shadow under the figure
var _atlas: AtlasTexture
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
	_cam.position = Vector3(0, 0.55, 5.2)
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
	_key.light_energy = 3.0
	_key.omni_range = 11.0
	_key.position = Vector3(-1.4, 1.2, 2.6)
	_world.add_child(_key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.5, 0.58, 0.92)
	rim.light_energy = 0.30
	rim.rotation_degrees = Vector3(-24, 158, 0)
	_world.add_child(rim)

## THE OPPONENT, STANDING IN THE ROOM. Until now the figure was a 2D layer floating ABOVE the
## 3D room, so the floor and the character were two unrelated worlds. As a Sprite3D it stands on
## that floor, catches the same candle, and drops a shadow -- which is the whole reason to have
## built a room at all.
func set_figure(tex: Texture2D, frames: int) -> void:
	if _fig != null:
		_fig.queue_free()
		_fig = null
	if _blob != null:
		_blob.queue_free()
		_blob = null
	if tex == null or _world == null:
		return
	_frames = maxi(1, frames)
	_cell = Vector2(float(tex.get_width()) / float(_frames), float(tex.get_height()))
	_atlas = AtlasTexture.new()
	_atlas.atlas = tex
	_atlas.region = Rect2(0, 0, _cell.x, _cell.y)
	_fig = Sprite3D.new()
	_fig.texture = _atlas
	_fig.billboard = BaseMaterial3D.BILLBOARD_ENABLED     # always faces the reader
	_fig.shaded = true                                    # the candle actually falls on it
	_fig.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD       # cut-out edges, no sorting halo
	_fig.pixel_size = 0.0125
	# feet on the floor: half the sprite's world height above FLOOR_Y
	_fig.position = Vector3(0.0, FLOOR_Y + _cell.y * 0.0125 * 0.5, -1.4)
	_world.add_child(_fig)
	# a soft blob under it -- a real shadow would need a shadow-casting light, which software GL
	# cannot afford; a dark ellipse on the floor sells the contact just as well.
	_blob = MeshInstance3D.new()
	var bm := PlaneMesh.new()
	bm.size = Vector2(2.1, 1.15)
	_blob.mesh = bm
	_blob.position = Vector3(0.0, FLOOR_Y + 0.012, -1.35)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.0, 0.0, 0.0, 0.55)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_blob.material_override = bmat
	_world.add_child(_blob)

## The room takes the enemy's colour, so a biome reads before a single word is on screen.
func set_accent(accent: Color) -> void:
	_accent = accent
	if _key != null:
		_key.light_color = Color(1.0, 0.76, 0.48).lerp(accent, 0.35)

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
		_cam.position = Vector3(0, 0.55, 5.2)
		return
	# a breath of drift, so the room is never a still photograph
	_cam.position = Vector3(sin(_t * 0.21) * 0.10, 0.55 + sin(_t * 0.17) * 0.05, 5.2 - _push)
	# the engraving steps between carved poses, same 10 fps as the plate it replaces
	if _frames > 1 and _atlas != null:
		_ft += delta * 10.0
		if _ft >= 1.0:
			_ft -= 1.0
			_fi = (_fi + 1) % _frames
			_atlas.region = Rect2(float(_fi) * _cell.x, 0.0, _cell.x, _cell.y)
