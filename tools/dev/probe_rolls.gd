extends SceneTree
## Headless probe: roll RunState.begin() several times and print the seed plus the
## resulting fight lineup, to verify that lineups actually vary with the seed.

func _initialize() -> void:
	OS.set_environment("TEST_PROFILE", "bot")

func _process(_delta: float) -> bool:
	var rs = root.get_node_or_null("RunState")
	if rs == null:
		return false
	var region = load("res://data/regions/region_01.tres")
	for i in 5:
		rs.begin(region)
		var names: Array = []
		for f in rs.fights:
			names.append(f.name_key)
		print("[probe] seed=%d fights=%s boss=%s" % [rs.run_seed, ",".join(names), rs.region.boss.name_key])
	for s in [111, 222, 111]:
		rs.begin(region, s)
		var names2: Array = []
		for f in rs.fights:
			names2.append(f.name_key)
		print("[probe] fixed seed=%d fights=%s" % [rs.run_seed, ",".join(names2)])
	quit()
	return true
