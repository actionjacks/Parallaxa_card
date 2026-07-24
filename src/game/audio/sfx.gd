class_name Sfx
## Procedurally synthesized SFX: tiny 16-bit mono WAV clips built in code (no asset files),
## registered into the AudioManager autoload on first use. Every meaningful action gets a sound
## (select, play, hit, block, heal, rot, coin, win, lose) so the game is audible until real
## sounds exist. play() is safe headless: it no-ops when the autoload is missing.

const RATE := 22050
static var _registered := false

static func play(key: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var am := _audio_manager()
	if am == null:
		return
	_register_all(am)
	am.play_sfx(key, volume_db, pitch)

static func _audio_manager() -> Node:
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		return (ml as SceneTree).root.get_node_or_null("AudioManager")
	return null

static func _register_all(am: Node) -> void:
	if _registered:
		return
	_registered = true
	am.register(&"card_select", _wav(_tone(700, 0.05, 0.20, 1000)))
	am.register(&"card_play", _wav(_noise(0.12, 0.16, true)))
	am.register(&"hit", _wav(_mix(_noise(0.16, 0.26), _tone(95, 0.16, 0.34, 58))))
	am.register(&"player_hit", _wav(_mix(_noise(0.20, 0.30), _tone(70, 0.20, 0.38, 45))))
	am.register(&"block", _wav(_tone(230, 0.08, 0.28, 175)))
	am.register(&"heal", _wav(_tone(520, 0.16, 0.18, 940)))
	am.register(&"rot", _wav(_mix(_noise(0.14, 0.14), _tone(140, 0.14, 0.20, 88))))
	am.register(&"coin", _wav(_seq([_tone(980, 0.05, 0.18), _tone(1320, 0.08, 0.18)])))
	am.register(&"win", _wav(_seq([_tone(523, 0.09, 0.2), _tone(659, 0.09, 0.2), _tone(784, 0.17, 0.22)])))
	am.register(&"lose", _wav(_tone(260, 0.5, 0.26, 105)))

# ---- synthesis: helpers return float samples in [-1, 1] ----

static func _tone(freq: float, dur: float, amp: float, freq_end: float = -1.0) -> PackedFloat32Array:
	if freq_end < 0.0:
		freq_end = freq
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(freq, freq_end, t)
		phase += TAU * f / RATE
		out[i] = sin(phase) * amp * exp(-3.5 * t)   # exponential decay envelope
	return out

static func _noise(dur: float, amp: float, fade_in: bool = false) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337   # fixed seed: the clip is identical every build
	var prev := 0.0
	for i in n:
		var t := float(i) / n
		var env := (t * 3.0 if fade_in and t < 0.33 else 1.0) * exp(-4.0 * t)
		prev = prev * 0.55 + rng.randf_range(-1.0, 1.0) * 0.45   # crude low-pass: thud, not hiss
		out[i] = prev * amp * env
	return out

static func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var n := maxi(a.size(), b.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var s := 0.0
		if i < a.size():
			s += a[i]
		if i < b.size():
			s += b[i]
		out[i] = clampf(s, -1.0, 1.0)
	return out

static func _seq(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p: PackedFloat32Array in parts:
		out.append_array(p)
	return out

static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav
