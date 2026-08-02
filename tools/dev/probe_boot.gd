extends SceneTree
## Trzy linie: czy ukryty ekran w ogole uruchamia scene i wychodzi.
func _initialize() -> void:
	print("[boot] tree alive")
	quit(0)
