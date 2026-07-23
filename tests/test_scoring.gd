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
	failures += _check_spalenie()
	failures += _check_echo()
	failures += _check_zniwo()
	failures += _check_bujnosc()
	failures += _check_opatrznosc()
	failures += _check_editions()
	failures += _check_two_relics()
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

func _tower_arcanum() -> ArcanumData:
	var a := ArcanumData.new()
	a.effect = ArcanumData.Effect.MULT_IF_ASPECT
	a.effect_aspect = Aspects.Id.CHAOS
	a.effect_mult = 1.4
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
	], [_death_arcanum()])
	return _expect("pair-death 72/gnicie3", r["hand"] == Poker.Hand.PAIR and r["chips"] == 24 \
		and is_equal_approx(r["mult"], 3.0) and r["damage"] == 72 and r["gnicie"] == 3)

# Four 7s incl. a Death card + Oslona 6: FOUR 60+28=88 chips, mult 7*1.5=10.5 -> 924 dmg, block 6.
func _check_four_of_a_kind() -> int:
	var r: Dictionary = Scoring.score([
		_c(7, Aspects.Id.DEATH, CardData.Keyword.GNICIE, 3),
		_c(7, Aspects.Id.DEATH),
		_c(7, Aspects.Id.CHAOS),
		_c(7, Aspects.Id.LIFE, CardData.Keyword.OSLONA, 6),
	], [_death_arcanum()])
	return _expect("four-7s 924/block6", r["hand"] == Poker.Hand.FOUR and r["chips"] == 88 \
		and is_equal_approx(r["mult"], 10.5) and r["damage"] == 924 and r["block"] == 6)

# Five Death cards, non-consecutive -> FLUSH (not straight).
func _check_flush_detect() -> int:
	var r: Dictionary = Scoring.score([
		_c(2, Aspects.Id.DEATH), _c(4, Aspects.Id.DEATH), _c(6, Aspects.Id.DEATH),
		_c(9, Aspects.Id.DEATH), _c(10, Aspects.Id.DEATH),
	], [])
	return _expect("death-flush", r["hand"] == Poker.Hand.FLUSH)

# Five consecutive mixed colours -> STRAIGHT (not flush).
func _check_straight_detect() -> int:
	var r: Dictionary = Scoring.score([
		_c(3, Aspects.Id.DEATH), _c(4, Aspects.Id.CHAOS), _c(5, Aspects.Id.LIFE),
		_c(6, Aspects.Id.MIND), _c(7, Aspects.Id.NATURE),
	], [])
	return _expect("straight", r["hand"] == Poker.Hand.STRAIGHT)

# Furia present but Oslona also played -> block > 0 cancels Furia's x1.5.
func _check_furia_blocked_by_oslona() -> int:
	var r: Dictionary = Scoring.score([
		_c(5, Aspects.Id.CHAOS, CardData.Keyword.FURIA),
		_c(5, Aspects.Id.LIFE, CardData.Keyword.OSLONA, 6),
	], [])
	# Pair (both rank 5): base 10 + 10 chips = 20, mult stays 2.0 (no Furia because block=6).
	return _expect("furia-cancelled", r["hand"] == Poker.Hand.PAIR and is_equal_approx(r["mult"], 2.0) \
		and r["block"] == 6)

# Spalenie: high card 5 + 10 (court) = 15 chips x1, plus 6 flat -> 21 damage.
func _check_spalenie() -> int:
	var r: Dictionary = Scoring.score([_c(12, Aspects.Id.CHAOS, CardData.Keyword.SPALENIE, 6)], [])
	return _expect("spalenie 21", r["hand"] == Poker.Hand.HIGH_CARD and r["chips"] == 15 \
		and r["flat"] == 6 and r["damage"] == 21)

# Echo: +value per prior play. 5 + 7 + 4*3 = 24 chips.
func _check_echo() -> int:
	var r: Dictionary = Scoring.score([_c(7, Aspects.Id.MIND, CardData.Keyword.ECHO, 4)], [], {"plays": 3})
	return _expect("echo 24", r["chips"] == 24 and r["damage"] == 24)

# Zniwo: +value*grave to Mult. high-card mult 1 + 1*5 = 6; chips 15 -> 90 damage.
func _check_zniwo() -> int:
	var r: Dictionary = Scoring.score([_c(10, Aspects.Id.DEATH, CardData.Keyword.ZNIWO, 1)], [], {"grave": 5})
	return _expect("zniwo mult6", is_equal_approx(r["mult"], 6.0) and r["chips"] == 15 and r["damage"] == 90)

# Bujnosc: 3 cards share Nature -> +20 chips. 5 + (8+5+3) + 20 = 41.
func _check_bujnosc() -> int:
	var r: Dictionary = Scoring.score([
		_c(8, Aspects.Id.NATURE, CardData.Keyword.BUJNOSC, 20),
		_c(5, Aspects.Id.NATURE), _c(3, Aspects.Id.NATURE),
	], [])
	return _expect("bujnosc 41", r["chips"] == 41 and r["damage"] == 41)

# Opatrznosc: returns heal.
func _check_opatrznosc() -> int:
	var r: Dictionary = Scoring.score([_c(6, Aspects.Id.LIFE, CardData.Keyword.OPATRZNOSC, 5)], [])
	return _expect("opatrznosc heal5", r["heal"] == 5)

# Two relics stack: Death x1.5 and Chaos x1.4 both apply to a hand holding both aspects.
# Three 6s (two Death, one Chaos): base 30x3; chips 30+18=48; mult 3*1.5*1.4=6.3 -> round(302.4)=302.
func _check_two_relics() -> int:
	var r: Dictionary = Scoring.score([
		_c(6, Aspects.Id.DEATH), _c(6, Aspects.Id.DEATH), _c(6, Aspects.Id.CHAOS),
	], [_death_arcanum(), _tower_arcanum()])
	return _expect("two-relics stack", r["hand"] == Poker.Hand.THREE and r["chips"] == 48 \
		and is_equal_approx(r["mult"], 6.3) and r["damage"] == 302)

# Editions: Foil +15 chips, Holo +2 mult, Polychrome x1.3 mult. High card of a 5 = 10 chips base.
func _check_editions() -> int:
	var foil := _c(5, Aspects.Id.LIFE)
	foil.edition = CardData.Edition.FOIL
	var r1: Dictionary = Scoring.score([foil], [])     # 5+5+15 = 25 chips, mult 1 -> 25
	var holo := _c(5, Aspects.Id.LIFE)
	holo.edition = CardData.Edition.HOLO
	var r2: Dictionary = Scoring.score([holo], [])     # 10 chips, mult 1+2 = 3 -> 30
	var poly := _c(5, Aspects.Id.LIFE)
	poly.edition = CardData.Edition.POLYCHROME
	var r3: Dictionary = Scoring.score([poly], [])     # 10 chips, mult 1*1.3 -> 13
	return _expect("editions", r1["chips"] == 25 and r1["damage"] == 25 \
		and is_equal_approx(r2["mult"], 3.0) and r2["damage"] == 30 \
		and is_equal_approx(r3["mult"], 1.3) and r3["damage"] == 13)
