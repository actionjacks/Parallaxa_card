extends Node
## Parallaxa_card boot scene.
##
## Empty entry point for the clean infrastructure base copied from parallaxa_orange.
## All autoloads (Settings, Localization, SaveManager, AudioManager, InputManager,
## SceneTransition, ScreenEffects, CursorManager) plus PhantomCamera and the Dialogue
## Manager come up around this node. The card game is built on top of this scene.

func _ready() -> void:
	print("[Parallaxa_card] boot scene ready")
