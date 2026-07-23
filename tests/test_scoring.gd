extends SceneTree
## Headless scoring test. Run: godot --headless -s res://tests/test_scoring.gd
## Exit 0 = all pass, 1 = any failure. Verifies the deterministic Chips x Mult engine.

func _initialize() -> void:
	var failures: int = 0
	failures += _check_pair_death()
	failures += _check_four_of_a_kind()
	failures += _check_flush_detect()
	failures += _check_straight_detect()
	failures += _check_furia_blocked_by_oslona()
	if failures == 0:
		print("test_scoring: PASS")
		quit(0)
	else:
		printerr("test_scoring: FAIL (%d)" % failures)
		quit(1)

func _c(rank: int, aspect: int, kw: int = CardData.Keyword.NONE, val: int = 0) -> CardData:
	var c := CardData.new()
	c.rank = rank
	c.aspect = aspect
	c.keyword = kw
	c.keyword_value = val
	return c

func _death_arcanum() -> ArcanumData:
	var a := ArcanumData.new()
	a.effect = ArcanumData.Effect.MULT_IF_ASPECT
	a.effect_aspect = Aspects.Id.DEATH
	a.effect_mult = 1.5
	return a

func _expect(label: String, ok: bool) -> int:
	if ok:
		print("  ok: ", label)
		return 0
	printerr("  FAIL: ", label)
	return 1

# Pair of Death 7s (one with Gnicie 3) + Death Arcanum: 10+14=24 chips, mult 2*1.5=3 -> 72 dmg.
func _check_pair_death() -> int:
	var r: Dictionary = Scoring.score([
		_c(7, Aspects.Id.DEATH, CardData.Keyword.GNICIE, 3),
		_c(7, Aspects.Id.DEATH),
	], _death_arcanum())
	return _expect("pair-death 72/gnicie3", r["hand"] == Poker.Hand.PAIR and r["chips"] == 24 \
		and is_equal_approx(r["mult"], 3.0) and r["damage"] == 72 and r["gnicie"] == 3)

# Four 7s incl. a Death card + Oslona 6: FOUR 60+28=88 chips, mult 7*1.5=10.5 -> 924 dmg, block 6.
func _check_four_of_a_kind() -> int:
	var r: Dictionary = Scoring.score([
		_c(7, Aspects.Id.DEATH, CardData.Keyword.GNICIE, 3),
		_c(7, Aspects.Id.DEATH),
		_c(7, Aspects.Id.CHAOS),
		_c(7, Aspects.Id.LIFE, CardData.Keyword.OSLONA, 6),
	], _death_arcanum())
	return _expect("four-7s 924/block6", r["hand"] == Poker.Hand.FOUR and r["chips"] == 88 \
		and is_equal_approx(r["mult"], 10.5) and r["damage"] == 924 and r["block"] == 6)

# Five Death cards, non-consecutive -> FLUSH (not straight).
func _check_flush_detect() -> int:
	var r: Dictionary = Scoring.score([
		_c(2, Aspects.Id.DEATH), _c(4, Aspects.Id.DEATH), _c(6, Aspects.Id.DEATH),
		_c(9, Aspects.Id.DEATH), _c(10, Aspects.Id.DEATH),
	], null)
	return _expect("death-flush", r["hand"] == Poker.Hand.FLUSH)

# Five consecutive mixed colours -> STRAIGHT (not flush).
func _check_straight_detect() -> int:
	var r: Dictionary = Scoring.score([
		_c(3, Aspects.Id.DEATH), _c(4, Aspects.Id.CHAOS), _c(5, Aspects.Id.LIFE),
		_c(6, Aspects.Id.MIND), _c(7, Aspects.Id.NATURE),
	], null)
	return _expect("straight", r["hand"] == Poker.Hand.STRAIGHT)

# Furia present but Oslona also played -> block > 0 cancels Furia's x1.5.
func _check_furia_blocked_by_oslona() -> int:
	var r: Dictionary = Scoring.score([
		_c(5, Aspects.Id.CHAOS, CardData.Keyword.FURIA),
		_c(5, Aspects.Id.LIFE, CardData.Keyword.OSLONA, 6),
	], null)
	# Pair (both rank 5): base 10 + 10 chips = 20, mult stays 2.0 (no Furia because block=6).
	return _expect("furia-cancelled", r["hand"] == Poker.Hand.PAIR and is_equal_approx(r["mult"], 2.0) \
		and r["block"] == 6)
