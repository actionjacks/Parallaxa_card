extends SceneTree
func _initialize() -> void:
	print("USERDIR=", OS.get_user_data_dir())
	print("PROFILE_EXISTS=", FileAccess.file_exists("user://profile.cfg"))
	quit(0)
