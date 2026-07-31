class_name TowerView
extends SubViewportContainer
## THE TOWER, IN THREE DIMENSIONS. The biome map used to be a stack of flat chips; the biome is
## a climb, so it is now a real tower standing in the dark, one drum of stone per rung, and the
## player's eye travels up it.
##
## Built PROCEDURALLY (mesh primitives + one material each), not from an imported model: the
## project has no 3D art pipeline, and a hand-built tower stays editable from numbers -- rungs,
## radius and lighting are all constants here.
##
## Rendered into a SubViewport rather than replacing the screen, so the existing map UI (rung
## labels, omen block, buttons, tooltips) keeps working on top of it in crisp 2D.
##
## PERFORMANCE: the hidden test screen runs on lavapipe (software GL). No real-time shadows, no
## SDFGI, no volumetric fog -- the mood comes from one warm light, exponential depth fog and a
## black background, all of which are nearly free.

const RUNG_H := 1.55           ## height of one drum of stone
const RUNG_R := 1.30           ## radius at the base; the tower tapers as it rises
const TAPER := 0.055           ## radius lost per rung -- a tower, not a pipe
const DARK := Color(0.055, 0.05, 0.07)

var _world: SubViewport
var _pivot: Node3D             ## everything rotates around this, so the tower turns slowly
var _cam: Camera3D
var _rungs: Array = []         ## Node3D per rung, bottom-first
var _t := 0.0
var _accent := Color(0.8, 0.7, 0.5)
## build() is normally called by the map screen BEFORE this node enters the tree, so the request
## is remembered here and replayed once _ready() has made the world to put it in.
var _pending: Array = []

func _init(size_px: Vector2 = Vector2(520, 420)) -> void:
	custom_minimum_size = size_px
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # the 2D map above keeps every click

func _ready() -> void:
	_world = SubViewport.new()
	_world.transparent_bg = true
	# Its OWN 3D world: without this the tower's lights and environment would be placed into the
	# main viewport's world, which this game never renders in 3D -- the classic "everything is
	# black" symptom.
	_world.own_world_3d = true
	_world.msaa_3d = Viewport.MSAA_DISABLED       # lavapipe: MSAA is the first thing to cost us
	_world.size = Vector2i(custom_minimum_size)
	add_child(_world)
	_pivot = Node3D.new()
	_world.add_child(_pivot)
	_cam = Camera3D.new()
	_cam.fov = 46.0
	_cam.current = true          # never rely on implicit first-camera selection
	_world.add_child(_cam)
	_build_environment()
	set_process(true)
	if not _pending.is_empty():
		build(int(_pending[0]), int(_pending[1]), _pending[2],
			_pending[3] if _pending.size() > 3 else [])

## The dark: a black void with fog, lit by ONE warm source low on the tower, like a brazier at
## its foot. Everything above fades into the murk, which is what makes a climb feel tall.
func _build_environment() -> void:
	var env := Environment.new()
	# A STORM, NOT A VOID. Flat black gave the tower nothing to stand against: the silhouette had
	# no horizon, so it read as an object on a table rather than a building in weather. A sky
	# gradient plus a bank of haze does three things at once -- it separates the tower, it puts a
	# distance behind it, and it makes the warm light at the foot read as fire rather than as a
	# lamp in a studio.
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var pan := ProceduralSkyMaterial.new()
	pan.sky_top_color = Color(0.045, 0.040, 0.062)
	pan.sky_horizon_color = Color(0.30, 0.17, 0.13)
	pan.sky_curve = 0.16
	pan.ground_bottom_color = Color(0.055, 0.035, 0.035)
	pan.ground_horizon_color = Color(0.34, 0.18, 0.12)
	pan.ground_curve = 0.10
	pan.sun_angle_max = 30.0
	sky.sky_material = pan
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.42
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.26, 0.15, 0.13)
	env.fog_density = 0.055
	env.fog_depth_begin = 5.0
	env.fog_depth_end = 34.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.18
	var ce := CameraAttributesPractical.new()
	_cam.attributes = ce
	_cam.environment = env

	# the fire at the foot: warm, close, low, and the reason the lower stones read as stone
	var key := OmniLight3D.new()
	key.light_color = Color(1.0, 0.62, 0.30)
	key.light_energy = 2.6
	key.omni_range = 8.0
	key.position = Vector3(2.6, -0.4, 3.4)
	_pivot.add_child(key)
	# a second, colder source opposite it -- one light makes a diagram, two make a place
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.42, 0.50, 0.86)
	fill.light_energy = 1.1
	fill.omni_range = 9.0
	fill.position = Vector3(-3.4, 2.2, 2.0)
	_pivot.add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.72, 0.66, 0.92)
	rim.light_energy = 0.55
	rim.rotation_degrees = Vector3(-18, 152, 0)
	_pivot.add_child(rim)

static var _grain: NoiseTexture2D

## Masonry grain, generated once: without a texture the drums read as smooth plastic under any
## light. FastNoiseLite ships with the engine, so this costs no asset pipeline.
static func _stone_grain() -> NoiseTexture2D:
	if _grain == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_CELLULAR       # cellular reads as blockwork, not clouds
		n.frequency = 0.055
		n.fractal_octaves = 3
		_grain = NoiseTexture2D.new()
		_grain.noise = n
		_grain.width = 128
		_grain.height = 128
		_grain.seamless = true
	return _grain

func _stone_material(lit: float, accent: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _stone_grain()
	m.uv1_scale = Vector3(2.0, 1.4, 1.0)
	# The albedo TINT multiplies the texture; a near-black tint here would render as a black slab
	# under any light, which is the trap this project has hit before. Stone stays mid-grey and the
	# darkness comes from the LIGHTING, which is what makes it read as stone in the dark.
	m.albedo_color = Color(0.40, 0.38, 0.42).lerp(accent, 0.14 * lit)
	m.roughness = 0.95
	m.metallic = 0.0
	# Only the summit carries any glow of its own, and faintly: a rung that emits light looks like
	# lava, a rung LIT BY a lamp looks like a room with someone in it.
	if lit > 0.0:
		m.emission_enabled = true
		m.emission = accent
		m.emission_energy_multiplier = 0.10 * lit
	return m

## Build (or rebuild) the tower for a climb of `total` rungs, with `step` already cleared and the
## top rung being the boss.
## THE CLIMB, WITH ITS OCCUPANTS. A tower of empty stone told the player how far they had to go
## and nothing about WHO was up there. Every rung now shows the opponent standing in its lit
## opening -- the ladder you can read at a glance, which is the whole point of a tower screen.
## `foes` is the rolled ladder (Array[EnemyData]); the last entry is the boss on the summit.
func build(total: int, step: int, accent: Color, foes: Array = []) -> void:
	_accent = accent
	_pending = [total, step, accent, foes]
	if _pivot == null:
		return          # not in the tree yet; _ready() will replay this
	for r in _rungs:
		r.queue_free()
	_rungs.clear()
	for i in total:
		var is_summit := i == total - 1
		var cleared := i < step
		var current := i == step
		var drum := Node3D.new()
		drum.position = Vector3(0, RUNG_H * i, 0)
		_pivot.add_child(drum)
		# A PAGODA, NOT A PIPE. Round drums gave a silhouette with no storeys in it -- the eye read
		# one tapering tube. A tiered tower reads as a CLIMB because every level announces itself:
		# a square body, a wide eave over it casting the level below into shadow, and an alcove cut
		# into the front where its occupant waits. That is the shape the reference picture has and
		# the reason it reads at a glance.
		var half: float = (RUNG_R - TAPER * i) * 0.86
		var body := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(half * 2.0, RUNG_H * 0.96, half * 2.0)
		body.mesh = bx
		var lit: float = 0.0
		if current:
			lit = 1.0
		elif is_summit:
			lit = 0.55
		body.material_override = _stone_material(0.0 if cleared else lit,
			Color(1.0, 0.42, 0.3) if is_summit else accent)
		drum.add_child(body)
		# THE EAVE. Wider than the body it crowns, thin, and slightly proud at the corners -- this
		# single slab is what turns a stack of boxes into a tower with floors.
		var eave := MeshInstance3D.new()
		var eb := BoxMesh.new()
		eb.size = Vector3(half * 2.34, RUNG_H * 0.11, half * 2.34)
		eave.mesh = eb
		eave.position = Vector3(0, RUNG_H * 0.50, 0)
		eave.material_override = _stone_material(0.0, accent.lerp(Color(0.35, 0.22, 0.18), 0.5))
		drum.add_child(eave)
		# THE ALCOVE: a dark recess in the front face, so the occupant stands INSIDE the building
		# rather than glued to its wall. Unshaded black -- it is a hole, and a hole is not lit.
		var nook := MeshInstance3D.new()
		var nb := BoxMesh.new()
		nb.size = Vector3(half * 1.30, RUNG_H * 0.62, 0.05)
		nook.mesh = nb
		nook.position = Vector3(0, -RUNG_H * 0.02, half * 0.99)
		var nm := StandardMaterial3D.new()
		nm.albedo_color = Color(0.20, 0.09, 0.04) if current else Color(0.015, 0.012, 0.02)
		nm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if current:
			nm.emission_enabled = true
			nm.emission = Color(1.0, 0.52, 0.22)
			nm.emission_energy_multiplier = 1.6
		nook.material_override = nm
		drum.add_child(nook)
		# two slot windows flanking the alcove, on the side walls
		for w in 2:
			var slot := MeshInstance3D.new()
			var sb := BoxMesh.new()
			sb.size = Vector3(0.07, RUNG_H * 0.30, 0.10)
			slot.mesh = sb
			var wm := StandardMaterial3D.new()
			wm.albedo_color = Color(0.02, 0.02, 0.03)
			if current:
				wm.emission_enabled = true
				wm.emission = Color(1.0, 0.80, 0.48)
				wm.emission_energy_multiplier = 3.2
			elif is_summit:
				wm.emission_enabled = true
				wm.emission = Color(1.0, 0.34, 0.26)
				wm.emission_energy_multiplier = 2.4
			slot.material_override = wm
			slot.position = Vector3((half * 1.02) * (1.0 if w == 0 else -1.0), 0.02, 0.0)
			slot.rotation.y = TAU * 0.25
			drum.add_child(slot)
		# THE SUMMIT ENDS IN A POINT. A tower that merely stops is a column; a roof says "top".
		if is_summit:
			var roof := MeshInstance3D.new()
			var rc := CylinderMesh.new()
			rc.top_radius = 0.0
			rc.bottom_radius = half * 1.85
			rc.height = RUNG_H * 0.62
			rc.radial_segments = 4          # four-sided: a pagoda roof, and cheap
			roof.mesh = rc
			roof.position = Vector3(0, RUNG_H * 0.86, 0)
			roof.rotation.y = TAU * 0.125
			roof.material_override = _stone_material(0.30, Color(1.0, 0.42, 0.3))
			drum.add_child(roof)
		# the lit window of the storey you are standing on: the eye goes straight to it
		if current or is_summit:
			var win := OmniLight3D.new()
			win.light_color = Color(1.0, 0.55, 0.3) if is_summit else Color(1.0, 0.86, 0.6)
			win.light_energy = 1.3 if current else 0.9
			win.omni_range = 2.6
			win.position = Vector3(0, 0, half + 0.45)
			drum.add_child(win)
		# THE ACTIVE STOREY IS THE ONE THAT IS LIT. A floating "you are here" label was a caption
		# stuck on a picture that should not need one -- and it competed with the tower for the
		# eye. The storey you stand on now BURNS: a warm lamp inside its alcove, its stone lifted,
		# its occupant at full brightness. Everything else sits in the murk. That is the whole
		# read, and it needs no words.
		if current:
			var lamp := OmniLight3D.new()
			lamp.light_color = Color(1.0, 0.80, 0.46)
			lamp.light_energy = 5.5
			lamp.omni_range = 3.2
			lamp.position = Vector3(0, RUNG_H * 0.05, half * 0.55)
			drum.add_child(lamp)
			var halo := OmniLight3D.new()
			halo.light_color = Color(1.0, 0.66, 0.34)
			halo.light_energy = 2.4
			halo.omni_range = 5.0
			halo.position = Vector3(0, RUNG_H * 0.2, half * 1.9)
			drum.add_child(halo)
		# THE OCCUPANT. Billboarded so it faces the reader from every angle of the slow spin, and
		# pushed clear of the drum's face so it never sinks into the stone. A rung already cleared
		# shows its foe greyed and dim -- a trophy shelf, not a threat.
		if i < foes.size() and foes[i] != null and foes[i].figure != null:
			var fg := Sprite3D.new()
			var at := AtlasTexture.new()
			at.atlas = foes[i].figure
			var fw: float = float(foes[i].figure.get_width()) / float(maxi(1, foes[i].figure_frames))
			at.region = Rect2(0, 0, fw, foes[i].figure.get_height())
			fg.texture = at
			fg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			fg.shaded = false
			# NOT discard: shrunk to rung size the mipmapped alpha of an engraving falls under the
			# 0.5 threshold almost everywhere, and the occupant vanishes entirely -- the same trap
			# the arena's soft parallax planes fell into.
			fg.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
			fg.transparent = true
			fg.no_depth_test = true
			fg.pixel_size = (RUNG_H * 0.60) / float(foes[i].figure.get_height())
			# OUTSIDE the drum's face, not just inside it: at 0.98r the near wall of the cylinder
			# stood in front of the figure and hid it completely -- the first build drew all five
			# occupants and showed none of them.
			# inside the alcove mouth: the recess frames it, the eave above shades it
			fg.position = Vector3(0, RUNG_H * 0.02, half * 1.06)
			if cleared:
				fg.modulate = Color(0.46, 0.46, 0.52)
			elif current:
				fg.modulate = Color(1.0, 0.94, 0.80)
			elif is_summit:
				fg.modulate = accent.lerp(Color(1, 1, 1), 0.45)
			else:
				fg.modulate = Color(0.92, 0.90, 0.96)
			drum.add_child(fg)
		_rungs.append(drum)
	_frame_camera(total)

## Put the whole climb in frame, tilted slightly up: the summit should sit high in the shot so
## the tower reads as something still to be climbed.
func _frame_camera(total: int) -> void:
	var h: float = RUNG_H * total
	# A WORM'S EYE, BECAUSE THE PLAYER IS CLIMBING. Framed from half its own height the tower was a
	# diagram of five boxes seen side-on -- true, and completely flat. Standing the camera at the
	# FOOT of the tower and tilting it up does the one thing the picture has to do: it puts the
	# summit far away and above you. The eaves now stack toward a vanishing point, each storey
	# overhangs the one below, and the climb is legible before a single word is read.
	_cam.position = Vector3(0, RUNG_H * 0.05, h * 1.02 + 4.3)
	_cam.look_at(Vector3(0, h * 0.46, 0), Vector3.UP)

func _process(delta: float) -> void:
	if _pivot == null:
		return
	if Juice.reduce_motion():
		return
	# A slow turn, under two degrees a second: enough for the stonework to catch the brazier and
	# read as round, slow enough that nobody has to watch it move.
	_t += delta
	_pivot.rotation.y = sin(_t * 0.16) * 0.28
