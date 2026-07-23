extends Node
## Autoload: SaveManager — slot-based persistence to `user://save_<slot>.json`.
##
## Why JSON and not a binary/ConfigFile store: saves must stay inspectable and diffable. A designer
## or bug reporter can open a slot in a text editor and see exactly what the game recorded, and a
## broken save can be repaired by hand instead of thrown away.
##
## Why the "persistent" group instead of a central registry: entities come and go with levels, so a
## registry would need bookkeeping on every spawn/free. Walking the group at save time is O(nodes to
## save) and cannot go stale — a freed node is simply not in the group anymore.
##
## Why nodes are keyed by their path relative to the current scene root, and not by instance id,
## node name, or absolute path:
##   - instance ids are per-run and meaningless across sessions;
##   - bare node names are not unique (two "Chest" nodes in different rooms collide);
##   - absolute paths embed "/root/<SceneRootName>", which changes if the scene root is renamed.
## The scene-relative path ("Entities/Chest3") is stable as long as the level's node layout is
## stable, which is exactly the guarantee a level designer can reason about in the editor. Nodes
## that live outside the current scene (e.g. an autoload joining the group) fall back to their
## absolute path, which is stable for autoloads.
##
## Why an atomic write: a crash or power loss halfway through `store_string()` on the real save file
## would leave a truncated JSON — the player loses the run they were saving AND the run they had.
## We write a temp file, fsync it by closing, keep the previous save as a `.bak` until the swap
## succeeded, and only then drop the backup.
##
## Why a sidecar `.meta.json`: the slot-select UI asks every slot for its header on open. Parsing a
## full save (potentially thousands of node entries) three times just to draw three rows is waste,
## so the header is mirrored into a tiny companion file. The sidecar is a cache, never the truth:
## if it is missing or unreadable the header is recovered from the save itself and rewritten.

signal game_saved(slot: int)
signal game_loaded(slot: int)
signal save_failed(slot: int, reason: String)

const SLOT_COUNT := 3
const SAVE_VERSION := 1

## Group whose members take part in persistence.
const PERSISTENT_GROUP := &"persistent"

## Top-level keys of the save file. Kept as constants so a typo cannot silently produce a save that
## reads back as an empty header.
const KEY_VERSION := "version"
const KEY_TIMESTAMP := "timestamp"
const KEY_LEVEL := "level"
const KEY_PLAYTIME := "playtime"
const KEY_NODES := "nodes"

## Failure reasons emitted with `save_failed`. These are identifiers, not user-facing text — the UI
## maps them to translation keys.
const REASON_INVALID_SLOT := "invalid_slot"
const REASON_NO_SAVE := "no_save"
const REASON_WRITE_FAILED := "write_failed"
const REASON_READ_FAILED := "read_failed"
const REASON_CORRUPT := "corrupt"
const REASON_VERSION_TOO_NEW := "version_too_new"
const REASON_MISSING_LEVEL := "missing_level"
const REASON_DELETE_FAILED := "delete_failed"

## Accumulated play time of the current session in seconds, restored from the save on load.
var _playtime: float = 0.0

## Header cache keyed by slot index, so repeated `get_slot_info()` calls do not re-hit the disk.
## Invalidated on save and delete; a missing entry means "not read yet", not "no save".
var _slot_info_cache: Dictionary = {}

## Payload waiting for its level to finish loading, and the slot it came from. `_pending_slot` is -1
## when nothing is pending.
var _pending_nodes: Dictionary = {}
var _pending_slot: int = -1


func _ready() -> void:
	# The tree stops processing INHERIT nodes while paused, so this alone almost covers the
	# "playtime must not tick while paused" rule. The explicit check in `_process` covers the case
	# where a future change sets this autoload to PROCESS_MODE_ALWAYS for some other reason.
	process_mode = Node.PROCESS_MODE_INHERIT
	set_process(true)


func _process(delta: float) -> void:
	var tree := get_tree()
	if tree == null or tree.paused:
		return
	_playtime += delta


# --- Public API -------------------------------------------------------------------------------


## Collects every node in the "persistent" group and writes a slot. Returns false and emits
## `save_failed` on any problem; the previous contents of the slot are left intact in that case.
func save_game(slot: int) -> bool:
	if not _is_valid_slot(slot):
		push_warning("SaveManager: save_game called with invalid slot %d" % slot)
		save_failed.emit(slot, REASON_INVALID_SLOT)
		return false

	var payload := {
		KEY_VERSION: SAVE_VERSION,
		KEY_TIMESTAMP: int(Time.get_unix_time_from_system()),
		KEY_LEVEL: _get_current_level_path(),
		KEY_PLAYTIME: _playtime,
		KEY_NODES: _collect_persistent_data(),
	}

	var text := JSON.stringify(payload, "\t")
	if not _write_atomic(_save_path(slot), text):
		save_failed.emit(slot, REASON_WRITE_FAILED)
		return false

	# The sidecar is a cache: a failed write costs a slower `get_slot_info()`, not the save itself.
	var header := _header_from_payload(payload)
	if not _write_atomic(_meta_path(slot), JSON.stringify(header, "\t")):
		push_warning("SaveManager: could not write slot %d header cache" % slot)

	_slot_info_cache[slot] = _slot_info_from_header(header, true)
	game_saved.emit(slot)
	return true


## Reads a slot and applies it. If the save points at a different level than the one currently
## running, the level is loaded first and the data is applied once it is in the tree — so the return
## value means "the save was accepted", not "the data is already applied". `game_loaded` always
## fires after the data has actually been pushed into the nodes.
func load_game(slot: int) -> bool:
	if not _is_valid_slot(slot):
		push_warning("SaveManager: load_game called with invalid slot %d" % slot)
		save_failed.emit(slot, REASON_INVALID_SLOT)
		return false

	var payload := _read_save(slot)
	if payload.is_empty():
		return false

	var raw_nodes: Variant = payload.get(KEY_NODES)
	var nodes: Dictionary = {}
	if raw_nodes is Dictionary:
		nodes = raw_nodes
	else:
		# A header-only save is legal (nothing was in the group); anything else is a shape problem
		# worth reporting, but not worth refusing the level change over.
		push_warning("SaveManager: slot %d has no '%s' object" % [slot, KEY_NODES])
	_playtime = float(payload.get(KEY_PLAYTIME, 0.0))

	var level: String = str(payload.get(KEY_LEVEL, ""))
	if level.is_empty() or level == _get_current_level_path():
		_apply_persistent_data(nodes)
		game_loaded.emit(slot)
		return true

	if not ResourceLoader.exists(level):
		push_warning("SaveManager: slot %d references missing level '%s'" % [slot, level])
		save_failed.emit(slot, REASON_MISSING_LEVEL)
		return false

	_pending_nodes = nodes
	_pending_slot = slot
	if not _request_level_change(level):
		_pending_nodes = {}
		_pending_slot = -1
		save_failed.emit(slot, REASON_MISSING_LEVEL)
		return false
	return true


func has_save(slot: int) -> bool:
	if not _is_valid_slot(slot):
		return false
	return FileAccess.file_exists(_save_path(slot))


## Removes the save and its header cache. Returns false only when the save exists and could not be
## removed — deleting an empty slot is not an error worth an `save_failed` for the caller to handle,
## but it still reports false so a UI can tell "nothing happened" from "done".
func delete_save(slot: int) -> bool:
	if not _is_valid_slot(slot):
		push_warning("SaveManager: delete_save called with invalid slot %d" % slot)
		save_failed.emit(slot, REASON_INVALID_SLOT)
		return false

	_slot_info_cache.erase(slot)

	if not FileAccess.file_exists(_save_path(slot)):
		_remove_if_exists(_meta_path(slot))
		return false

	var err := DirAccess.remove_absolute(_save_path(slot))
	if err != OK:
		push_warning("SaveManager: failed to delete slot %d (error %d)" % [slot, err])
		save_failed.emit(slot, REASON_DELETE_FAILED)
		return false

	_remove_if_exists(_meta_path(slot))
	return true


## Header of a slot without parsing the whole save: served from the in-memory cache, then from the
## sidecar, and only as a last resort by reading the save itself (which then refills both caches).
func get_slot_info(slot: int) -> Dictionary:
	if not _is_valid_slot(slot):
		push_warning("SaveManager: get_slot_info called with invalid slot %d" % slot)
		return _empty_slot_info()

	if not FileAccess.file_exists(_save_path(slot)):
		# A sidecar without its save is stale — drop it so it cannot resurrect a deleted slot.
		_remove_if_exists(_meta_path(slot))
		_slot_info_cache.erase(slot)
		return _empty_slot_info()

	if _slot_info_cache.has(slot):
		return (_slot_info_cache[slot] as Dictionary).duplicate()

	var header := _read_json_dict(_meta_path(slot))
	if header.is_empty():
		# No usable sidecar: fall back to the full save and rebuild the cache for next time.
		var payload := _read_json_dict(_save_path(slot))
		if payload.is_empty():
			return _empty_slot_info()
		header = _header_from_payload(payload)
		if not _write_atomic(_meta_path(slot), JSON.stringify(header, "\t")):
			push_warning("SaveManager: could not rebuild slot %d header cache" % slot)

	var info := _slot_info_from_header(header, true)
	_slot_info_cache[slot] = info
	return info.duplicate()


## Seconds of play time accumulated in this session. Additive helper — the contract stores playtime
## in the save header but does not say who owns the counter, and a new game needs to reset it.
func get_playtime() -> float:
	return _playtime


func reset_playtime() -> void:
	_playtime = 0.0


# --- Persistence protocol ---------------------------------------------------------------------


func _collect_persistent_data() -> Dictionary:
	var result: Dictionary = {}
	var tree := get_tree()
	if tree == null:
		return result

	for node in tree.get_nodes_in_group(PERSISTENT_GROUP):
		if not is_instance_valid(node):
			continue
		if not node.has_method("save_data"):
			push_warning("SaveManager: node '%s' is in group '%s' but has no save_data()" % [node.name, PERSISTENT_GROUP])
			continue

		var key := _node_key(node)
		if key.is_empty():
			continue
		if result.has(key):
			# Two nodes resolving to the same key means one of them would be silently dropped on
			# load, which is far worse to debug later than a warning now.
			push_warning("SaveManager: duplicate persistent key '%s', skipping node '%s'" % [key, node.name])
			continue

		var data: Variant = node.call("save_data")
		if data is Dictionary:
			result[key] = data
		else:
			push_warning("SaveManager: save_data() of '%s' returned %s, expected Dictionary" % [key, type_string(typeof(data))])

	return result


func _apply_persistent_data(nodes: Dictionary) -> void:
	var tree := get_tree()
	if tree == null:
		return

	var seen: Dictionary = {}
	for node in tree.get_nodes_in_group(PERSISTENT_GROUP):
		if not is_instance_valid(node):
			continue
		if not node.has_method("load_data"):
			push_warning("SaveManager: node '%s' is in group '%s' but has no load_data()" % [node.name, PERSISTENT_GROUP])
			continue

		var key := _node_key(node)
		if key.is_empty():
			continue
		seen[key] = true
		if not nodes.has(key):
			# Not fatal: the node may have been added to the level after this save was written.
			continue

		var data: Variant = nodes[key]
		if data is Dictionary:
			node.call("load_data", data)
		else:
			push_warning("SaveManager: entry '%s' is %s, expected Dictionary" % [key, type_string(typeof(data))])

	for key in nodes.keys():
		if not seen.has(key):
			# The save knows about a node the level no longer has — the level changed since the
			# save was written. Warn, keep going: a missing chest must not block loading.
			push_warning("SaveManager: saved node '%s' not found in the current scene" % key)


## Path used as the persistence key. See the file header for why it is scene-relative.
func _node_key(node: Node) -> String:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return ""
	var root := _get_current_scene()
	if root != null and (node == root or root.is_ancestor_of(node)):
		return String(root.get_path_to(node))
	return String(node.get_path())


# --- Level handling ---------------------------------------------------------------------------


func _get_current_scene() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.current_scene


func _get_current_level_path() -> String:
	var scene := _get_current_scene()
	if scene == null:
		return ""
	return scene.scene_file_path


## Asks SceneTransition to load the level, falling back to a direct scene change when it is absent.
## The autoload is looked up by path at call time rather than referenced directly, because
## SaveManager is autoload #5 and SceneTransition is #8 — a hard reference would invert the
## dependency order declared in the architecture contract.
func _request_level_change(level: String) -> bool:
	var tree := get_tree()
	if tree == null:
		return false

	var transition := get_node_or_null(^"/root/SceneTransition")
	if transition != null and transition.has_method("change_scene") and transition.has_signal("transition_finished"):
		if not transition.transition_finished.is_connected(_on_transition_finished):
			transition.transition_finished.connect(_on_transition_finished, CONNECT_ONE_SHOT)
		transition.call("change_scene", level)
		return true

	var err := tree.change_scene_to_file(level)
	if err != OK:
		push_warning("SaveManager: change_scene_to_file('%s') failed (error %d)" % [level, err])
		return false
	# The new scene is swapped in at the end of the frame, so the payload cannot be applied yet.
	_apply_pending_deferred.call_deferred()
	return true


func _on_transition_finished(_path: String) -> void:
	_apply_pending_deferred.call_deferred()


func _apply_pending_deferred() -> void:
	if _pending_slot < 0:
		return
	var slot := _pending_slot
	var nodes := _pending_nodes
	_pending_slot = -1
	_pending_nodes = {}
	_apply_persistent_data(nodes)
	game_loaded.emit(slot)


# --- File I/O ---------------------------------------------------------------------------------


func _save_path(slot: int) -> String:
	return "user://save_%d.json" % slot


func _meta_path(slot: int) -> String:
	return "user://save_%d.meta.json" % slot


func _is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < SLOT_COUNT


## Reads and validates a full save. Returns an empty Dictionary and emits `save_failed` on any
## problem, so callers only have to check `is_empty()`.
func _read_save(slot: int) -> Dictionary:
	if not FileAccess.file_exists(_save_path(slot)):
		save_failed.emit(slot, REASON_NO_SAVE)
		return {}

	var file := FileAccess.open(_save_path(slot), FileAccess.READ)
	if file == null:
		push_warning("SaveManager: cannot open slot %d (error %d)" % [slot, FileAccess.get_open_error()])
		save_failed.emit(slot, REASON_READ_FAILED)
		return {}
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("SaveManager: slot %d is not valid JSON object" % slot)
		save_failed.emit(slot, REASON_CORRUPT)
		return {}

	var payload: Dictionary = parsed
	var version := int(payload.get(KEY_VERSION, 0))
	if version > SAVE_VERSION:
		# Refusing is the point: a newer file may encode fields this build would drop on the next
		# save, quietly destroying the player's progress. Better to say no than to half-read it.
		push_warning("SaveManager: slot %d has version %d, this build supports up to %d" % [slot, version, SAVE_VERSION])
		save_failed.emit(slot, REASON_VERSION_TOO_NEW)
		return {}
	if version <= 0:
		push_warning("SaveManager: slot %d has no usable version field" % slot)
		save_failed.emit(slot, REASON_CORRUPT)
		return {}

	return payload


## Parses a JSON file into a Dictionary, returning {} for every failure mode (missing, unreadable,
## malformed, or a non-object top level). Used where a failure is recoverable and must stay quiet.
func _read_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


## Writes `text` to `path` without ever leaving `path` truncated.
##
## Sequence: write `<path>.tmp`, move any existing `path` to `<path>.bak`, move the temp into place,
## drop the backup. If the final move fails, the backup is restored — so an interrupted or failed
## write leaves the previous save readable rather than destroyed.
func _write_atomic(path: String, text: String) -> bool:
	var tmp_path := path + ".tmp"
	var bak_path := path + ".bak"

	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: cannot open '%s' for writing (error %d)" % [tmp_path, FileAccess.get_open_error()])
		return false
	file.store_string(text)
	var store_error := file.get_error()
	# close() flushes; only after it returns is the temp file complete on disk.
	file.close()
	if store_error != OK:
		push_warning("SaveManager: write to '%s' failed (error %d)" % [tmp_path, store_error])
		_remove_if_exists(tmp_path)
		return false

	var had_previous := FileAccess.file_exists(path)
	if had_previous:
		_remove_if_exists(bak_path)
		var backup_error := DirAccess.rename_absolute(path, bak_path)
		if backup_error != OK:
			push_warning("SaveManager: cannot back up '%s' (error %d)" % [path, backup_error])
			_remove_if_exists(tmp_path)
			return false

	var swap_error := DirAccess.rename_absolute(tmp_path, path)
	if swap_error != OK:
		push_warning("SaveManager: cannot move '%s' into place (error %d)" % [tmp_path, swap_error])
		_remove_if_exists(tmp_path)
		if had_previous:
			# Put the old file back; losing the new save is acceptable, losing both is not.
			var restore_error := DirAccess.rename_absolute(bak_path, path)
			if restore_error != OK:
				push_warning("SaveManager: could not restore backup '%s' (error %d)" % [bak_path, restore_error])
		return false

	if had_previous:
		_remove_if_exists(bak_path)
	return true


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


# --- Header helpers ---------------------------------------------------------------------------


func _header_from_payload(payload: Dictionary) -> Dictionary:
	return {
		KEY_VERSION: int(payload.get(KEY_VERSION, 0)),
		KEY_TIMESTAMP: int(payload.get(KEY_TIMESTAMP, 0)),
		KEY_LEVEL: str(payload.get(KEY_LEVEL, "")),
		KEY_PLAYTIME: float(payload.get(KEY_PLAYTIME, 0.0)),
	}


func _slot_info_from_header(header: Dictionary, exists: bool) -> Dictionary:
	return {
		"exists": exists,
		"version": int(header.get(KEY_VERSION, 0)),
		"timestamp": int(header.get(KEY_TIMESTAMP, 0)),
		"level": str(header.get(KEY_LEVEL, "")),
		"playtime": float(header.get(KEY_PLAYTIME, 0.0)),
	}


func _empty_slot_info() -> Dictionary:
	return {
		"exists": false,
		"version": 0,
		"timestamp": 0,
		"level": "",
		"playtime": 0.0,
	}
