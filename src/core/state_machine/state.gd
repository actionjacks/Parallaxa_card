@tool
class_name State
extends Node

## Base class for a single state driven by a [StateMachine].
##
## A state is a child [b]node[/b] of the machine (not a Resource, not an inner class) so a level
## designer can see the whole behaviour tree of an entity in the scene dock, reorder it, and attach
## per-state exported tuning values without touching code.
##
## Why the machine calls [method update] / [method physics_update] instead of letting each state use
## its own [code]_process[/code]: with N states parented to the machine, Godot would tick every one of
## them every frame, including the N-1 that are inactive. Routing through the machine gives exactly one
## active clock and makes "who is running right now" answerable by reading a single variable.
## Consequently this class turns the node's own per-frame callbacks off in [method _ready]; override
## [method update] and friends, not [code]_process[/code].

## The machine that owns this state. Assigned by the machine before [method enter] is ever called,
## so it is safe to use from [method enter] onwards, but NOT from [method _ready].
var machine: StateMachine

## The entity the machine drives (mirror of [member StateMachine.host]).
## Kept as a plain [Node] on purpose: this component must work for a player, an NPC, a door or a
## camera rig without any of them sharing a base class.
var host: Node


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# The machine is the single clock for states - see the class comment.
	set_process(false)
	set_physics_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)


## Called once when the machine enters this state.
## [param msg] carries hand-off data from the caller of [method StateMachine.travel]
## (for example [code]{"direction": Vector3.FORWARD}[/code]). Never assume a key exists - use
## [code]msg.get("key", default)[/code].
func enter(_msg: Dictionary = {}) -> void:
	pass


## Called once when the machine leaves this state. Undo here whatever [method enter] set up
## (timers, animations, physics flags) - the machine gives no other cleanup hook.
func exit() -> void:
	pass


## Per-frame update, forwarded from the machine's [code]_process[/code].
func update(_delta: float) -> void:
	pass


## Fixed-step update, forwarded from the machine's [code]_physics_process[/code].
## Movement and anything touching physics belongs here.
func physics_update(_delta: float) -> void:
	pass


## Unhandled input, forwarded from the machine's [code]_unhandled_input[/code].
## Only the active state receives it, so two states can bind the same key without fighting.
func handle_input(_event: InputEvent) -> void:
	pass
