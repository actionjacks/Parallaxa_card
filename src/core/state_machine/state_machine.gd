@tool
class_name StateMachine
extends Node

## Reusable finite state machine component.
##
## [b]It never assumes it is attached to the player.[/b] The entity it drives is resolved at runtime
## ([member host_path], else the parent) and typed as a plain [Node], so the very same component drives
## a [CharacterBody3D] player, an NPC, a turret, a door or a UI panel. Anything player-specific belongs
## in the states, not here.
##
## States are child nodes (see [State]) rather than resources or an enum, because level design in this
## project is editor-first: the behaviour of an entity has to be readable and re-orderable in the scene
## dock by someone who never opens a script.
##
## Robustness rules this file implements, and why:
## [br]- [method travel] to an unknown state warns and does nothing. A typo in a state name must never
## soft-lock an entity mid-level; a warning in the log is recoverable, a frozen NPC is not.
## [br]- Transitions are [b]queued, not nested[/b]. Calling [method travel] from inside
## [method State.enter] is a normal pattern ("enter Stagger, immediately bounce to Dead if hp <= 0"),
## and nesting it would run [method State.exit] of a state that has not finished entering, leaving
## [member current] inconsistent. The queue makes the outer transition finish first.
## [br]- A machine with no [State] children warns once and disables itself instead of erroring every
## frame. Half-built scenes are normal during development and must stay playable.

## Emitted after the new state's [method State.enter] has run, so listeners observe a settled machine.
## [param from] is [code]&""[/code] for the very first transition.
signal state_changed(from: StringName, to: StringName)

## Guard against a pathological [code]enter() -> travel() -> enter() -> ...[/code] chain.
## Reaching this count means the state graph oscillates; we stop and report instead of hanging the game.
const MAX_CHAINED_TRANSITIONS := 32

## State entered on ready. If left empty the first [State] child is used, so a quick prototype scene
## still runs; the editor shows a configuration warning suggesting an explicit choice.
@export var initial_state: State

## Entity driven by this machine. Empty means [method Node.get_parent], which covers the common case
## of the machine being a direct child of the entity.
@export var host_path: NodePath

## The entity this machine drives. Valid from [method _ready] onwards.
var host: Node

## Currently active state, or [code]null[/code] before the first transition / when disabled.
var current: State

## State active before [member current]. Kept so states can implement "return to whatever ran before"
## (interaction -> back to Idle or Move) without every state hardcoding its caller.
var previous_state: State

# name -> State, filled from the children. Rebuilt when children are added or removed at runtime.
var _states: Dictionary[StringName, State] = {}

# Pending travel requests. Non-empty only while a transition chain is being drained.
var _queue: Array[Dictionary] = []

# True while the queue is being drained; makes re-entrant travel() calls queue instead of nest.
var _transitioning := false

# Set when no usable state exists, so the warning is emitted once instead of every frame.
var _disabled := false


func _ready() -> void:
	# Child add/remove is tracked in the editor too, so configuration warnings stay live while the
	# designer builds the state tree.
	child_entered_tree.connect(_on_child_tree_changed)
	child_exiting_tree.connect(_on_child_tree_changed)

	if Engine.is_editor_hint():
		# @tool exists only for the configuration warnings; nothing should tick in the editor.
		set_process(false)
		set_physics_process(false)
		set_process_unhandled_input(false)
		return

	_resolve_host()
	_collect_states()

	if _states.is_empty():
		_disable("StateMachine '%s' has no State children - disabling it." % _describe())
		return

	var first: State = initial_state
	if first == null or not _states.values().has(first):
		if first != null:
			push_warning("StateMachine '%s': initial_state '%s' is not one of its State children; falling back to the first child." % [_describe(), first.name])
		first = _states.values()[0]

	set_process(true)
	set_physics_process(true)
	set_process_unhandled_input(true)
	travel(first.name)


func _process(delta: float) -> void:
	if current != null:
		current.update(delta)


func _physics_process(delta: float) -> void:
	if current != null:
		current.physics_update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if current != null:
		current.handle_input(event)


## Request a transition to the state named [param to] (the child node's name).
## [param msg] is handed to [method State.enter] of the target state.
## Unknown names warn and no-op; calls made from inside [method State.enter] or [method State.exit]
## are queued and run after the current transition completes.
func travel(to: StringName, msg: Dictionary = {}) -> void:
	if _disabled:
		return
	if not _states.has(to):
		push_warning("StateMachine '%s': unknown state '%s'. Known states: %s. Ignoring travel()." % [_describe(), to, ", ".join(_state_names_as_text())])
		return

	_queue.append({"to": to, "msg": msg})
	if _transitioning:
		return

	_transitioning = true
	var applied := 0
	while not _queue.is_empty():
		applied += 1
		if applied > MAX_CHAINED_TRANSITIONS:
			push_warning("StateMachine '%s': more than %d chained transitions in one frame - the state graph is oscillating. Dropping %d pending request(s)." % [_describe(), MAX_CHAINED_TRANSITIONS, _queue.size()])
			_queue.clear()
			break
		var request: Dictionary = _queue.pop_front()
		_apply(request["to"], request["msg"])
	_transitioning = false


## Whether a child state with this name exists.
func has_state(name: StringName) -> bool:
	return _states.has(name)


## The state node registered under [param name], or [code]null[/code].
func get_state(name: StringName) -> State:
	if not _states.has(name):
		return null
	return _states[name]


## Whether [param name] is the active state. Safe before the first transition.
func is_in(name: StringName) -> bool:
	return current != null and current.name == name


## Name of the state active before the current one, or [code]&""[/code] if there is none.
## Convenience for the common "go back" transition; kept as a name so callers stay symmetrical
## with [method travel].
func get_previous_state_name() -> StringName:
	return previous_state.name if previous_state != null else &""


## Return to the state that ran before the current one. No-op (with no warning) when there is none,
## which is the normal situation on the very first state.
func travel_back(msg: Dictionary = {}) -> void:
	if previous_state != null:
		travel(previous_state.name, msg)


func _apply(to: StringName, msg: Dictionary) -> void:
	var next: State = get_state(to)
	if next == null:
		# The node could have been freed between queueing and draining.
		push_warning("StateMachine '%s': state '%s' disappeared before the transition ran." % [_describe(), to])
		return

	var from_name: StringName = current.name if current != null else &""
	if current != null:
		previous_state = current
		current.exit()

	current = next
	next.enter(msg)
	state_changed.emit(from_name, to)


func _resolve_host() -> void:
	if not host_path.is_empty():
		host = get_node_or_null(host_path)
		if host == null:
			push_warning("StateMachine '%s': host_path '%s' does not resolve; falling back to the parent." % [_describe(), host_path])
	if host == null:
		host = get_parent()
	if host == null:
		push_warning("StateMachine '%s' has no host (no parent and no host_path). States will see host == null." % _describe())


func _collect_states() -> void:
	_states.clear()
	for child in get_children():
		var state := child as State
		if state == null:
			continue
		if _states.has(state.name):
			# Godot enforces unique sibling names, so this only happens through exotic runtime reparenting.
			push_warning("StateMachine '%s': duplicate state name '%s' - keeping the first one." % [_describe(), state.name])
			continue
		state.machine = self
		state.host = host
		_states[state.name] = state


func _on_child_tree_changed(node: Node) -> void:
	if Engine.is_editor_hint():
		update_configuration_warnings()
		return
	if node is not State:
		return
	# Deferred: during child_exiting_tree the node is still a child, so rebuilding now would keep it.
	_refresh_states.call_deferred()


func _refresh_states() -> void:
	if not is_inside_tree():
		return
	_collect_states()
	if current != null and not _states.values().has(current):
		# The active state was removed under us. Dropping current is safer than keeping a dangling
		# reference; the owner can travel() somewhere valid.
		push_warning("StateMachine '%s': active state '%s' left the tree; the machine is now idle." % [_describe(), current.name])
		current = null
	if previous_state != null and not _states.values().has(previous_state):
		previous_state = null


func _disable(reason: String) -> void:
	_disabled = true
	current = null
	set_process(false)
	set_physics_process(false)
	set_process_unhandled_input(false)
	push_warning(reason)


func _state_names_as_text() -> PackedStringArray:
	var names := PackedStringArray()
	for key in _states.keys():
		names.append(String(key))
	return names


func _describe() -> String:
	return String(get_path()) if is_inside_tree() else String(name)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	var found: Array[State] = []
	for child in get_children():
		var state := child as State
		if state != null:
			found.append(state)

	if found.is_empty():
		warnings.append("No State children. Add nodes with a script extending State - the machine disables itself otherwise.")
	elif initial_state == null:
		warnings.append("initial_state is not set. '%s' (the first State child) will be used." % found[0].name)
	elif not found.has(initial_state):
		warnings.append("initial_state ('%s') is not a child of this machine. Only direct State children can be entered." % initial_state.name)

	if not host_path.is_empty() and get_node_or_null(host_path) == null:
		warnings.append("host_path does not resolve to a node. The machine will fall back to its parent.")
	elif host_path.is_empty() and get_parent() == null:
		warnings.append("No parent and no host_path: states would receive host == null.")

	return warnings
