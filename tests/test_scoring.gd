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
	failures += _check_playstyle_relics()
	failures += _check_hand_levels()
	failures += _check_wave2_keywords()
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

# Playstyle relics resolve in scoring (preview-safe): Devil x1.35 always, Empress +4 block,
# Sun +3 heal. Single 6 of Life: high card 5+6=11 chips.
func _check_playstyle_relics() -> int:
	var devil := ArcanumData.new()
	devil.effect = ArcanumData.Effect.PACT_MULT
	devil.effect_mult = 1.35
	devil.effect_value = 2
	var empress := ArcanumData.new()
	empress.effect = ArcanumData.Effect.BLOCK_ON_PLAY
	empress.effect_value = 4
	var sun := ArcanumData.new()
	sun.effect = ArcanumData.Effect.HEAL_ON_PLAY
	sun.effect_value = 3
	var r: Dictionary = Scoring.score([_c(6, Aspects.Id.LIFE)], [devil, empress, sun])
	return _expect("playstyle relics (x1.35, +4 block, +3 heal)",
		is_equal_approx(r["mult"], 1.35) and r["damage"] == 15 and r["block"] == 4 and r["heal"] == 3)

# Star levels: Pair at level 2 = base 10+2*15=40 chips, mult 2+2*1=4. Two 7s -> 54 x 4 = 216.
func _check_hand_levels() -> int:
	var r: Dictionary = Scoring.score([_c(7, Aspects.Id.DEATH), _c(7, Aspects.Id.DEATH)], [],
		{"hand_levels": {Poker.Hand.PAIR: 2}})
	return _expect("pair Lv3 216", r["chips"] == 54 and is_equal_approx(r["mult"], 4.0) and r["damage"] == 216)

# Wave 2: Symbioza (+5 per allied card: NATURE allies LIFE+CHAOS -> 2 allies = +10),
# Klatwa ctx (+50% on scored damage) and klatwa_add returned, Pijawka (20% leech), Wzrost (growth in chips).
func _check_wave2_keywords() -> int:
	var fails := 0
	# Symbioza: NATURE 6 + LIFE 4 + CHAOS 3 -> high card of... ranks differ: 6,4,3 = HIGH_CARD base 5.
	# chips = 5 + 6+4+3 + 10 = 28, mult 1 -> 28.
	var r1: Dictionary = Scoring.score([
		_c(6, Aspects.Id.NATURE, CardData.Keyword.SYMBIOZA, 5),
		_c(4, Aspects.Id.LIFE), _c(3, Aspects.Id.CHAOS),
	], [])
	fails += _expect("symbioza 28", r1["chips"] == 28 and r1["damage"] == 28)
	# Klatwa in ctx: single 6 -> 11 chips x1 = 11; +50% -> 17 (round 16.5). Card adds klatwa_add 8.
	var r2: Dictionary = Scoring.score([_c(6, Aspects.Id.DEATH, CardData.Keyword.KLATWA, 8)], [], {"klatwa": 50})
	fails += _expect("klatwa ctx 17/add8", r2["damage"] == 17 and r2["klatwa_add"] == 8)
	# Pijawka: single 10 -> 15 chips x1 = 15 dmg; 20% leech -> heal 3.
	var r3: Dictionary = Scoring.score([_c(10, Aspects.Id.DEATH, CardData.Keyword.PIJAWKA, 20)], [])
	fails += _expect("pijawka heal3", r3["heal"] == 3 and r3["damage"] == 15)
	# Wzrost: growth feeds chip_value: card rank 5 with growth 4 -> 5+4+5(base high) = 14 dmg.
	var g := _c(5, Aspects.Id.NATURE, CardData.Keyword.WZROST, 2)
	g.growth = 4
	var r4: Dictionary = Scoring.score([g], [])
	fails += _expect("wzrost chips 14", r4["damage"] == 14)
	return fails

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
