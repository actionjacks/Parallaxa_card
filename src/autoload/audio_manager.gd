extends Node

## Global audio front-end: bus setup, a pooled SFX layer and a crossfading music layer.
##
## Design notes (why it looks like this):
##
## 1. The buses are created at runtime when missing. A fresh checkout has no
##    `default_bus_layout.tres`, and a manager that hard-fails on that would take every level down
##    with it. Creating the layout in code also keeps the bus names in one place instead of split
##    between a binary resource and the scripts that reference it.
## 2. SFX players are pooled and pre-allocated. Spawning an `AudioStreamPlayer` per shot means a node
##    allocation, a tree insertion and a deferred free on every single sound - measurable stutter in
##    combat. The pool recycles finished players and, when everything is busy, steals the
##    longest-running one so `play_sfx()` never returns null for a valid key.
## 3. Music uses two players instead of one. A single player cannot crossfade with itself; two let the
##    outgoing track fade down while the incoming one fades up, which is the only way to change tracks
##    without an audible hole.
## 4. All linear->dB conversion goes through `_to_db()`, which floors silence at `SILENCE_DB`.
##    `linear_to_db(0.0)` is -INF, and tweening a property to -INF produces NaN volumes that stick
##    permanently. The floor is the difference between "silent" and "broken".
## 5. Missing keys warn exactly once per key. A sound that is not authored yet is a normal state
##    during development; a warning every frame from a looping emitter is not.

## Bus names. `Master` is Godot's implicit bus 0; the other two are created if absent.
const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"

## Volume treated as full silence. Also the floor for every dB conversion (see header note 4).
const SILENCE_DB: float = -80.0

## Linear volumes below this are snapped to `SILENCE_DB` - below it the dB curve is inaudible anyway.
const SILENCE_LINEAR: float = 0.0001

## Pool sizes. 16 non-positional voices covers UI plus overlapping gameplay sounds; 3D emitters are
## rarer and heavier (each carries an attenuation model), so they get a smaller pool.
const SFX_POOL_SIZE: int = 16
const SFX_3D_POOL_SIZE: int = 12

## Settings section and keys this manager mirrors. Kept as constants so a typo cannot silently
## disconnect the settings menu from the mixer.
const SETTINGS_SECTION: String = "audio"
const SETTINGS_KEY_MASTER: String = "master"
const SETTINGS_KEY_MUSIC: String = "music"
const SETTINGS_KEY_SFX: String = "sfx"

## Fallback volumes, used only when Settings is unavailable. They match the defaults in
## docs/ARCHITECTURE.md so the mixer sounds the same with or without a settings file.
const DEFAULT_MASTER: float = 1.0
const DEFAULT_MUSIC: float = 0.8
const DEFAULT_SFX: float = 1.0

var _library: Dictionary[StringName, AudioStream] = {}
var _warned_keys: Dictionary[StringName, bool] = {}

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_3d_pool: Array[AudioStreamPlayer3D] = []

## Playback start timestamps (microseconds), parallel to the pools. Used to pick a victim when every
## voice is busy: the oldest sound is the one a player is least likely to still be listening for.
var _sfx_started_at: PackedInt64Array = PackedInt64Array()
var _sfx_3d_started_at: PackedInt64Array = PackedInt64Array()

var _music_players: Array[AudioStreamPlayer] = []
var _music_tweens: Array[Tween] = [null, null]
## Index into `_music_players` of the player owning the currently requested track.
var _music_active: int = 0
var _music_key: StringName = &""

var _settings: Node = null


func _ready() -> void:
	# Audio must keep running while the game is paused - the settings menu pauses the tree and still
	# needs its sliders to be audible.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_ensure_buses()
	_build_sfx_pools()
	_build_music_players()
	_connect_settings()
	_apply_volumes_from_settings()


# --- Public API -------------------------------------------------------------------------------


## Plays a registered sound on a pooled non-positional voice.
## Returns the player driving it, or null when the key is unknown (never crashes the caller's level).
func play_sfx(key: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	var stream: AudioStream = _resolve(key)
	if stream == null:
		return null

	var player: AudioStreamPlayer = _acquire_sfx()
	if player == null:
		return null

	player.stream = stream
	player.volume_db = volume_db
	# A non-positive pitch scale silences or reverses playback depending on the driver; clamp instead
	# of trusting caller arithmetic.
	player.pitch_scale = maxf(pitch, 0.01)
	player.play()
	return player


## Plays a registered sound at a world position on a pooled 3D voice.
## Returns null when the key is unknown.
func play_sfx_at(key: StringName, position: Vector3, volume_db: float = 0.0) -> AudioStreamPlayer3D:
	var stream: AudioStream = _resolve(key)
	if stream == null:
		return null

	var player: AudioStreamPlayer3D = _acquire_sfx_3d()
	if player == null:
		return null

	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0
	# The pool is parented to this autoload (a plain Node), so the players have no inherited
	# transform and local position is world position. Assigning global_position keeps that explicit.
	player.global_position = position
	player.play()
	return player


## Starts (or crossfades to) a registered music track.
## Re-requesting the track that is already playing is a no-op, so calling this from a level's
## `_ready()` does not restart the music on every scene reload.
func play_music(key: StringName, fade_in: float = 1.0) -> void:
	if _music_players.is_empty():
		return

	var stream: AudioStream = _resolve(key)
	if stream == null:
		return

	if key == _music_key and _music_players[_music_active].playing:
		return

	var incoming: int = 1 - _music_active
	var outgoing: int = _music_active
	_music_active = incoming
	_music_key = key

	_fade_music_out(outgoing, fade_in)

	var player: AudioStreamPlayer = _music_players[incoming]
	_kill_tween(incoming)
	player.stream = stream
	player.volume_db = SILENCE_DB
	player.play()

	if fade_in <= 0.0:
		player.volume_db = 0.0
		return

	var tween: Tween = create_tween()
	_music_tweens[incoming] = tween
	tween.tween_property(player, ^"volume_db", 0.0, fade_in)


## Fades the current music out and stops it. Safe to call when nothing is playing.
func stop_music(fade_out: float = 1.0) -> void:
	if _music_players.is_empty():
		return
	_music_key = &""
	_fade_music_out(_music_active, fade_out)


## Sets a bus volume from a linear 0..1 value. Unknown bus names warn once and no-op.
func set_bus_volume(bus: StringName, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx < 0:
		_warn_once(_bus_warn_key(bus), "AudioManager: unknown audio bus '%s', volume change ignored." % bus)
		return
	AudioServer.set_bus_volume_db(idx, _to_db(clampf(linear, 0.0, 1.0)))


## Returns a bus volume as linear 0..1. Unknown bus names return 0.0.
func get_bus_volume(bus: StringName) -> float:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx < 0:
		_warn_once(_bus_warn_key(bus), "AudioManager: unknown audio bus '%s', reporting volume 0." % bus)
		return 0.0
	return _to_linear(AudioServer.get_bus_volume_db(idx))


## Registers (or replaces) a stream under a key. Registering clears any "missing key" warning so a
## sound that arrives late in the boot sequence does not stay flagged for the rest of the session.
func register(key: StringName, stream: AudioStream) -> void:
	if key.is_empty():
		push_warning("AudioManager: register() called with an empty key, ignored.")
		return
	if stream == null:
		push_warning("AudioManager: register('%s') called with a null stream, ignored." % key)
		return
	_library[key] = stream
	_warned_keys.erase(key)


# --- Bus setup --------------------------------------------------------------------------------


func _ensure_buses() -> void:
	# Bus 0 always exists but a hand-edited layout may have renamed it; the sends below target it by
	# name, so normalise it first.
	if AudioServer.get_bus_index(BUS_MASTER) < 0:
		if AudioServer.bus_count == 0:
			AudioServer.add_bus(0)
		AudioServer.set_bus_name(0, BUS_MASTER)
		push_warning("AudioManager: no 'Master' bus found, renamed bus 0 to 'Master'.")

	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)


func _ensure_bus(bus: StringName) -> int:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx >= 0:
		return idx
	idx = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus)
	AudioServer.set_bus_send(idx, BUS_MASTER)
	return idx


# --- Pool construction ------------------------------------------------------------------------


func _build_sfx_pools() -> void:
	_sfx_started_at.resize(SFX_POOL_SIZE)
	for i: int in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		player.name = "SfxVoice%d" % i
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_sfx_pool.append(player)
		_sfx_started_at[i] = 0

	_sfx_3d_started_at.resize(SFX_3D_POOL_SIZE)
	for i: int in SFX_3D_POOL_SIZE:
		var player := AudioStreamPlayer3D.new()
		player.bus = BUS_SFX
		player.name = "Sfx3DVoice%d" % i
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_sfx_3d_pool.append(player)
		_sfx_3d_started_at[i] = 0


func _build_music_players() -> void:
	for i: int in 2:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_MUSIC
		player.name = "MusicVoice%d" % i
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.volume_db = SILENCE_DB
		add_child(player)
		_music_players.append(player)


# --- Voice acquisition ------------------------------------------------------------------------


func _acquire_sfx() -> AudioStreamPlayer:
	if _sfx_pool.is_empty():
		return null

	var oldest: int = 0
	for i: int in _sfx_pool.size():
		var player: AudioStreamPlayer = _sfx_pool[i]
		if not player.playing:
			_sfx_started_at[i] = Time.get_ticks_usec()
			return player
		if _sfx_started_at[i] < _sfx_started_at[oldest]:
			oldest = i

	# Everything is busy: steal the longest-running voice rather than dropping the new sound. A
	# clipped tail is far less noticeable than a missing hit or footstep.
	_sfx_started_at[oldest] = Time.get_ticks_usec()
	_sfx_pool[oldest].stop()
	return _sfx_pool[oldest]


func _acquire_sfx_3d() -> AudioStreamPlayer3D:
	if _sfx_3d_pool.is_empty():
		return null

	var oldest: int = 0
	for i: int in _sfx_3d_pool.size():
		var player: AudioStreamPlayer3D = _sfx_3d_pool[i]
		if not player.playing:
			_sfx_3d_started_at[i] = Time.get_ticks_usec()
			return player
		if _sfx_3d_started_at[i] < _sfx_3d_started_at[oldest]:
			oldest = i

	_sfx_3d_started_at[oldest] = Time.get_ticks_usec()
	_sfx_3d_pool[oldest].stop()
	return _sfx_3d_pool[oldest]


# --- Music helpers ----------------------------------------------------------------------------


func _fade_music_out(index: int, duration: float) -> void:
	if index < 0 or index >= _music_players.size():
		return
	var player: AudioStreamPlayer = _music_players[index]
	_kill_tween(index)
	if not player.playing:
		return

	if duration <= 0.0:
		player.stop()
		player.volume_db = SILENCE_DB
		return

	var tween: Tween = create_tween()
	_music_tweens[index] = tween
	tween.tween_property(player, ^"volume_db", SILENCE_DB, duration)
	# `stop()` is bound through the tween rather than a timer so that cancelling the fade (a new
	# `play_music()` reusing this player) also cancels the stop.
	tween.tween_callback(player.stop)


func _kill_tween(index: int) -> void:
	var tween: Tween = _music_tweens[index]
	if tween != null and tween.is_valid():
		tween.kill()
	_music_tweens[index] = null


# --- Settings integration ---------------------------------------------------------------------


func _connect_settings() -> void:
	# Resolved by path instead of the `Settings` global so that a project missing the autoload (or a
	# test scene running this script standalone) degrades to defaults instead of failing to parse.
	_settings = get_node_or_null(^"/root/Settings")
	if _settings == null:
		push_warning("AudioManager: Settings autoload not found, using default volumes.")
		return
	# Connected by name: `_settings` is typed as Node, and `changed` is not a Node member, so direct
	# signal access would not compile against the static type.
	if _settings.has_signal("changed"):
		_settings.connect("changed", _on_settings_changed)
	else:
		push_warning("AudioManager: Settings has no 'changed' signal, volume updates will not apply live.")


func _apply_volumes_from_settings() -> void:
	set_bus_volume(BUS_MASTER, _read_setting(SETTINGS_KEY_MASTER, DEFAULT_MASTER))
	set_bus_volume(BUS_MUSIC, _read_setting(SETTINGS_KEY_MUSIC, DEFAULT_MUSIC))
	set_bus_volume(BUS_SFX, _read_setting(SETTINGS_KEY_SFX, DEFAULT_SFX))


func _read_setting(key: String, fallback: float) -> float:
	if _settings == null or not _settings.has_method("get_value"):
		return fallback
	var value: Variant = _settings.call("get_value", SETTINGS_SECTION, key, fallback)
	# A hand-edited settings.cfg can hold anything; anything non-numeric falls back rather than
	# propagating a bogus volume into the mixer.
	if value is float or value is int:
		return clampf(float(value), 0.0, 1.0)
	return fallback


func _on_settings_changed(section: String, key: String, value: Variant) -> void:
	if section != SETTINGS_SECTION:
		return
	if not (value is float or value is int):
		return
	var linear: float = clampf(float(value), 0.0, 1.0)
	match key:
		SETTINGS_KEY_MASTER:
			set_bus_volume(BUS_MASTER, linear)
		SETTINGS_KEY_MUSIC:
			set_bus_volume(BUS_MUSIC, linear)
		SETTINGS_KEY_SFX:
			set_bus_volume(BUS_SFX, linear)


# --- Utilities --------------------------------------------------------------------------------


func _resolve(key: StringName) -> AudioStream:
	var stream: AudioStream = _library.get(key, null)
	if stream == null:
		_warn_once(key, "AudioManager: no stream registered for key '%s', playback skipped." % key)
		return null
	return stream


## Namespaces bus warnings so a bus named like a sound key cannot suppress the other's warning.
func _bus_warn_key(bus: StringName) -> StringName:
	return StringName("bus:" + String(bus))


func _warn_once(key: StringName, message: String) -> void:
	if _warned_keys.has(key):
		return
	_warned_keys[key] = true
	push_warning(message)


## Linear 0..1 -> dB, with silence floored at `SILENCE_DB` instead of -INF (see header note 4).
func _to_db(linear: float) -> float:
	if linear <= SILENCE_LINEAR:
		return SILENCE_DB
	return maxf(linear_to_db(linear), SILENCE_DB)


## Inverse of `_to_db()`: anything at or below the floor reports as exactly 0.0 linear.
func _to_linear(db: float) -> float:
	if db <= SILENCE_DB:
		return 0.0
	return clampf(db_to_linear(db), 0.0, 1.0)
