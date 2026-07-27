class_name MusicLib
## Procedural music front-end, mirroring the Sfx static-registration pattern. Tracks are offline-
## generated WAVs (tools/gen/gen_music.py -> assets/audio/music/). Looping is forced at runtime:
## Godot imports .wav non-looping by default, and relying on .import edits is fragile.
## Headless-safe: play() no-ops without the AudioManager autoload or when a file is missing.

const TRACKS := {
	&"music_menu": "res://assets/audio/music/menu_drone.wav",
	&"music_combat": "res://assets/audio/music/combat_loop.wav",
	&"music_boss": "res://assets/audio/music/boss_loop.wav",
	&"music_heartbeat": "res://assets/audio/music/heartbeat_loop.wav",
}
static var _registered := false

static func play(key: StringName, fade: float = 1.0) -> void:
	var am := _audio_manager()
	if am == null:
		return
	_register_all(am)
	am.play_music(key, fade)

static func stop(fade: float = 1.0) -> void:
	var am := _audio_manager()
	if am != null:
		am.stop_music(fade)

## The raw heartbeat stem (enrage layer) -- the combat scene owns its dedicated player, because
## a loop must never be stolen by the pooled SFX voices.
static func heartbeat_stream() -> AudioStreamWAV:
	return _looped(TRACKS[&"music_heartbeat"])

static func _register_all(am: Node) -> void:
	if _registered:
		return
	_registered = true
	for key: StringName in TRACKS:
		var s := _looped(TRACKS[key])
		if s != null:
			am.register(key, s)

static func _looped(path: String) -> AudioStreamWAV:
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStreamWAV = load(path)
	if s == null:
		return null
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	@warning_ignore("integer_division")
	s.loop_end = s.data.size() / 2   # 16-bit mono: 2 bytes per frame
	return s

static func _audio_manager() -> Node:
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		return (ml as SceneTree).root.get_node_or_null("AudioManager")
	return null
