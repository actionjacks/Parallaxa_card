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
		build(int(_pending[0]), int(_pending[1]), _pending[2])

## The dark: a black void with fog, lit by ONE warm source low on the tower, like a brazier at
## its foot. Everything above fades into the murk, which is what makes a climb feel tall.
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = DARK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.20, 0.19, 0.28)
	env.ambient_light_energy = 0.10
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.04, 0.035, 0.06)
	env.fog_density = 0.10
	env.fog_depth_begin = 3.0
	env.fog_depth_end = 26.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var ce := CameraAttributesPractical.new()
	_cam.attributes = ce
	_cam.environment = env

	# the brazier at the foot: warm, close, and the reason the lower stones read as stone
	var key := OmniLight3D.new()
	key.light_color = Color(1.0, 0.72, 0.42)
	key.light_energy = 1.5
	key.omni_range = 6.5
	key.position = Vector3(2.9, 0.35, 3.1)
	_pivot.add_child(key)
	# a cold rim from behind, so the silhouette separates from the void
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.55, 0.62, 0.95)
	rim.light_energy = 0.35
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
func build(total: int, step: int, accent: Color) -> void:
	_accent = accent
	_pending = [total, step, accent]
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
		var mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = RUNG_R - TAPER * (i + 1)
		cyl.bottom_radius = RUNG_R - TAPER * i
		cyl.height = RUNG_H * 0.92
		cyl.radial_segments = 14      # low on purpose: software GL renders this scene every frame
		mesh.mesh = cyl
		# A cleared rung is cold stone, the current one burns, the summit wears the boss's colour.
		var lit: float = 0.0
		if current:
			lit = 1.0
		elif is_summit:
			lit = 0.55
		mesh.material_override = _stone_material(0.0 if cleared else lit,
			Color(1.0, 0.42, 0.3) if is_summit else accent)
		drum.add_child(mesh)
		# a band of brick between drums, so the rungs read as separate storeys
		var band := MeshInstance3D.new()
		var ring := CylinderMesh.new()
		ring.top_radius = cyl.top_radius * 1.09
		ring.bottom_radius = cyl.top_radius * 1.09
		ring.height = RUNG_H * 0.08
		ring.radial_segments = 14
		band.mesh = ring
		band.position = Vector3(0, RUNG_H * 0.5, 0)
		band.material_override = _stone_material(0.0, accent)
		drum.add_child(band)
		# WINDOWS: a narrow slot on every storey, three around the drum. Cold and empty on a
		# cleared rung, warm on the one you stand on -- a lit window is the cheapest way to say
		# "someone is in there" and the reason the silhouette reads as a building at all.
		for w in 3:
			var slot := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.13, RUNG_H * 0.34, 0.10)
			slot.mesh = bm
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
			var ang: float = TAU * float(w) / 3.0 + 0.4
			var rr: float = cyl.bottom_radius * 0.97
			slot.position = Vector3(sin(ang) * rr, 0.05, cos(ang) * rr)
			slot.rotation.y = ang
			drum.add_child(slot)
		# CRENELLATIONS crown the summit: the tower has to END, not just stop.
		if is_summit:
			for k in 10:
				var merlon := MeshInstance3D.new()
				var mb := BoxMesh.new()
				mb.size = Vector3(0.19, 0.30, 0.19)
				merlon.mesh = mb
				merlon.material_override = _stone_material(0.0, accent)
				var a2: float = TAU * float(k) / 10.0
				var r2: float = cyl.top_radius * 0.92
				merlon.position = Vector3(sin(a2) * r2, RUNG_H * 0.55, cos(a2) * r2)
				merlon.rotation.y = a2
				drum.add_child(merlon)
		# the lit window of the storey you are standing on: the eye goes straight to it
		if current or is_summit:
			var win := OmniLight3D.new()
			win.light_color = Color(1.0, 0.55, 0.3) if is_summit else Color(1.0, 0.86, 0.6)
			win.light_energy = 1.3 if current else 0.9
			win.omni_range = 2.6
			win.position = Vector3(0, 0, cyl.bottom_radius + 0.35)
			drum.add_child(win)
		_rungs.append(drum)
	_frame_camera(total)

## Put the whole climb in frame, tilted slightly up: the summit should sit high in the shot so
## the tower reads as something still to be climbed.
func _frame_camera(total: int) -> void:
	var h: float = RUNG_H * total
	_cam.position = Vector3(0, h * 0.46, h * 0.92 + 3.4)
	_cam.look_at(Vector3(0, h * 0.42, 0), Vector3.UP)

func _process(delta: float) -> void:
	if _pivot == null:
		return
	if Juice.reduce_motion():
		return
	# A slow turn, under two degrees a second: enough for the stonework to catch the brazier and
	# read as round, slow enough that nobody has to watch it move.
	_t += delta
	_pivot.rotation.y = sin(_t * 0.16) * 0.28
