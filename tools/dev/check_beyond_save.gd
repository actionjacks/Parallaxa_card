extends SceneTree
## Headless sanity: a Beyond-depth run save round-trips (depth/run_won/boss/pure survive load).
func _initialize() -> void:
	if OS.get_environment("TEST_PROFILE") == "":
		OS.set_environment("TEST_PROFILE", "savechk")
	var rs = root.get_node("RunState")
	rs.begin(load("res://data/regions/region_01.tres"), 12345)
	rs.depth = 2
	rs.run_won = true
	rs.pure_reading = true
	rs.daily_tag = "2026-07-27"
	var boss_before: String = rs.boss.resource_path if rs.boss != null else ""
	rs.save_run("")
	rs.depth = 0
	rs.run_won = false
	rs.pure_reading = false
	rs.boss = null
	rs.load_run()
	var ok: bool = rs.depth == 2 and rs.run_won and rs.pure_reading and rs.daily_tag == "2026-07-27" \
		and rs.boss != null and rs.boss.resource_path == boss_before and rs.run_seed == 12345
	print("beyond_save_roundtrip: %s (depth=%d won=%s pure=%s boss=%s)" % [
		"PASS" if ok else "FAIL", rs.depth, str(rs.run_won), str(rs.pure_reading),
		rs.boss.resource_path.get_file() if rs.boss != null else "null"])
	rs.delete_run_save()
	quit(0 if ok else 1)
