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
var _push := 0.0        ## momentary camera push-in on a landed blow

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

## The room takes the enemy's colour, so a biome reads before a single word is on screen.
func set_accent(accent: Color) -> void:
	_accent = accent
	if _key != null:
		_key.light_color = Color(1.0, 0.76, 0.48).lerp(accent, 0.35)

## A landed blow pushes the camera in a touch: the room reacts, so the hit has weight.
func punch(strength: float = 1.0) -> void:
	if Juice.reduce_motion():
		return
	_push = 0.30 * strength

func _process(delta: float) -> void:
	if _cam == null:
		return
	_t += delta
	_push = maxf(0.0, _push - delta * 1.6)
	if Juice.reduce_motion():
		_cam.position = Vector3(0, 0.55, 5.2)
		return
	# a breath of drift, so the room is never a still photograph
	_cam.position = Vector3(sin(_t * 0.21) * 0.10, 0.55 + sin(_t * 0.17) * 0.05, 5.2 - _push)
