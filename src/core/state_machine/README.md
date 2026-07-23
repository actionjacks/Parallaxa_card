# StateMachine

A small, gameplay-agnostic finite state machine. It drives **any entity** — player, NPC, prop,
camera rig — because the entity it controls is just a `Node` reference (`host`), never a specific
class.

- `state_machine.gd` — `class_name StateMachine extends Node`
- `state.gd` — `class_name State extends Node`

See `docs/ARCHITECTURE.md` for the authoritative API listing.

## How it is wired

States are **child nodes** of the machine, so the whole behaviour of an entity is visible and
re-orderable in the scene dock:

```
Player (CharacterBody3D)
  StateMachine          initial_state -> Idle
    Idle                (script extends State)
    Move                (script extends State)
```

The machine resolves its `host` from `host_path` if set, otherwise from `get_parent()`, and mirrors
it onto every state as `state.host`. Point `host_path` somewhere else when the machine is not a
direct child of the entity (for example a machine grouped under a `Behaviour` node).

States are registered by their **node name**, so `travel(&"Move")` targets the child called `Move`.

## State callbacks

Override only what you need:

```gdscript
func enter(msg: Dictionary = {}) -> void
func exit() -> void
func update(delta: float) -> void            # from _process
func physics_update(delta: float) -> void    # from _physics_process
func handle_input(event: InputEvent) -> void # from _unhandled_input
```

The machine is the only clock: a `State` node has its own `_process` / `_physics_process` /
`_unhandled_input` disabled in `_ready`, so inactive states cost nothing. Put per-frame work in
`update()` / `physics_update()`, not in `_process`.

`machine` and `host` are assigned before the first `enter()`, but **not** before `_ready()` — do not
touch them from a state's `_ready`.

## Example: player

`src/entities/player/states/idle.gd`

```gdscript
extends State

@export var move_threshold := 0.1

var _body: CharacterBody3D


func enter(_msg: Dictionary = {}) -> void:
	_body = host as CharacterBody3D
	if _body == null:
		push_warning("Idle expects a CharacterBody3D host.")
		return
	_body.velocity = Vector3.ZERO


func physics_update(_delta: float) -> void:
	if _body == null:
		return
	_body.move_and_slide()
	if InputManager.get_move_vector().length() > move_threshold:
		machine.travel(&"Move")
```

`src/entities/player/states/move.gd`

```gdscript
extends State

@export var speed := 4.0


func physics_update(_delta: float) -> void:
	var body := host as CharacterBody3D
	if body == null:
		return
	var input := InputManager.get_move_vector()
	if input.is_zero_approx():
		machine.travel(&"Idle")
		return
	# Movement is camera-relative; see the InputManager section of docs/ARCHITECTURE.md.
	var yaw := body.get_viewport().get_camera_3d().global_rotation.y
	var direction := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, yaw)
	body.velocity = direction * speed
	body.move_and_slide()
```

## Example: enemy

The same component, a different host and different states — nothing in the machine changes:

```
Enemy (CharacterBody3D)
  StateMachine          initial_state -> Patrol
    Patrol
    Chase
    Attack
```

```gdscript
# patrol.gd
extends State

@export var sight_range := 8.0


func physics_update(_delta: float) -> void:
	var target := _find_player()
	if target != null and host.global_position.distance_to(target.global_position) < sight_range:
		# Hand-off data goes through msg, so Chase does not have to search for the target again.
		machine.travel(&"Chase", {"target": target})


func _find_player() -> Node3D:
	return get_tree().get_first_node_in_group(&"player") as Node3D
```

```gdscript
# chase.gd
extends State

@export var speed := 3.0

var _target: Node3D


func enter(msg: Dictionary = {}) -> void:
	_target = msg.get("target", null) as Node3D
	if _target == null:
		# Never trust msg: fall back instead of running with a null target.
		machine.travel(&"Patrol")


func exit() -> void:
	_target = null
```

Calling `travel()` from inside `enter()` (as above) is safe: transitions are **queued**, not nested,
so the machine finishes entering `Chase` before it leaves for `Patrol`.

## Reacting to transitions

```gdscript
func _ready() -> void:
	$StateMachine.state_changed.connect(_on_state_changed)


func _on_state_changed(from: StringName, to: StringName) -> void:
	# `from` is &"" for the first transition.
	$AnimationPlayer.play(String(to).to_lower())
```

The signal fires **after** the new state's `enter()`, so listeners always see a settled machine.

## Returning to the previous state

`previous_state` holds the state that ran before `current`, which is what temporary states
(interact, stagger, menu) need in order to hand control back without hardcoding a caller:

```gdscript
func exit_interaction() -> void:
	machine.travel_back()          # equivalent to travel(machine.get_previous_state_name())
```

## Failure behaviour

The machine is built to keep a half-finished scene playable:

| Situation | Result |
|---|---|
| `travel()` to an unknown name | `push_warning` + no-op — a typo must never soft-lock an entity |
| No `State` children | warns once and disables itself, does not error every frame |
| `initial_state` empty | uses the first `State` child, editor warning suggests setting it |
| `initial_state` not a child | warns and falls back to the first `State` child |
| `host_path` does not resolve | warns and falls back to `get_parent()` |
| Active state removed at runtime | warns, machine goes idle instead of holding a freed node |
| `enter()` chain that oscillates | stops after `MAX_CHAINED_TRANSITIONS` (32) and warns |

Both scripts are `@tool` purely so `_get_configuration_warnings()` reports missing states and a bad
`initial_state` directly in the scene dock. Nothing ticks in the editor.
