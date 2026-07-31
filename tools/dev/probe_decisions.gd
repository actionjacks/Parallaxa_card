extends SceneTree
## Decision-density probe: for consecutive turns of a real starter-deck fight, enumerate EVERY
## legal play (all 1-5 card subsets of the hand), score each, and count the meaningfully distinct
## options: Pareto-optimal profiles over (damage, block, heal, future value = gnicie+klatwa).
## Answers "czy gracz ma duzo decyzji i kombinowania" with numbers, not vibes.

func _initialize() -> void:
	if OS.get_environment("TEST_PROFILE") == "":
		OS.set_environment("TEST_PROFILE", "probe")
	var deck: Array = DeckLibrary.starter_deck_pure()
	# fixed shuffle for reproducibility
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = deck[i]
		deck[i] = deck[j]
		deck[j] = tmp
	var enemy: EnemyData = load("res://data/combat/enemy_a.tres")
	var relic: ArcanumData = load("res://data/arcana/arcanum_death.tres")
	var ctrl := CombatController.new()
	ctrl.start(deck, enemy, [relic], 55, 55)
	for turn in 5:
		if ctrl.phase != "player":
			break
		var n := ctrl.hand.size()
		var total := 0
		var profiles: Array = []   # [damage, block, heal, future, hand_type]
		var hand_types := {}
		for mask in range(1, 1 << n):
			var idx: Array = []
			for b in n:
				if mask & (1 << b):
					idx.append(b)
			if idx.size() > 5:
				continue
			total += 1
			var r: Dictionary = ctrl.preview(idx)
			var future: int = int(r["gnicie"]) + int(r.get("klatwa_add", 0))
			profiles.append([ctrl.effective_damage(int(r["damage"]), 5, int(r["hand"])), int(r["block"]), int(r["heal"]), future, int(r["hand"])])
			hand_types[int(r["hand"])] = true
		# Pareto over the 4 axes (strictly dominated = not optimal)
		var pareto := 0
		var best_dmg := 0
		var second_dmg := 0
		for p in profiles:
			if p[0] > best_dmg:
				second_dmg = best_dmg
				best_dmg = p[0]
			elif p[0] > second_dmg:
				second_dmg = p[0]
			var dominated := false
			for q in profiles:
				if q == p:
					continue
				if q[0] >= p[0] and q[1] >= p[1] and q[2] >= p[2] and q[3] >= p[3] \
					and (q[0] > p[0] or q[1] > p[1] or q[2] > p[2] or q[3] > p[3]):
					dominated = true
					break
			if not dominated:
				pareto += 1
		print("turn %d: hand=%d options=%d PARETO=%d hand_types=%d best=%d second=%d gap=%.0f%%  discards_left=%d" % [
			turn + 1, n, total, pareto, hand_types.size(), best_dmg, second_dmg,
			(100.0 * (best_dmg - second_dmg) / maxf(best_dmg, 1)), ctrl.discards_left])
		# play greedily (best damage) to advance the fight state
		var best_idx: Array = []
		var bd := -1
		for mask in range(1, 1 << n):
			var idx2: Array = []
			for b in n:
				if mask & (1 << b):
					idx2.append(b)
			if idx2.size() > 5:
				continue
			var r2: Dictionary = ctrl.preview(idx2)
			if int(r2["damage"]) > bd:
				bd = int(r2["damage"])
				best_idx = idx2
		ctrl.play(best_idx)
		if ctrl.phase == "enemy":
			ctrl.resolve_enemy_turn()
	print("probe: done (enemy hp left=%d)" % ctrl.enemy_hp)
	quit(0)
