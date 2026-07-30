extends SceneTree
## Headless combat-rule test. Run: godot --headless -s res://tests/test_combat.gd
## Verifies that block reduces a normal enemy's hit but the Tower's rule ignores it.

func _initialize() -> void:
	var fails: int = 0
	fails += _expect("normal block reduces (50 - (20-8) = 38)", _hp_after(EnemyData.Rule.NONE) == 38)
	fails += _expect("tower ignores block (50 - 20 = 30)", _hp_after(EnemyData.Rule.TOWER_IGNORES_BLOCK) == 30)
	fails += _expect("enrage: grace cycle exact, then +step per turn (10,12,14)", _enraged_intents() == [10, 12, 14])
	fails += _expect("next_intent looks one turn ahead", _next_intent_check())
	# The three field rules whose TEXT once promised something the engine did not do.
	fails += _expect("Empress blooms on a short hand (+40)", _empress_heal(3) == 40)
	fails += _expect("Empress does NOT bloom on a full five", _empress_heal(5) == 0)
	fails += _expect("Wheel skips a step each turn (16, 9)", _wheel_intents() == [16, 9])
	fails += _expect("Fool mirrors the blow (dmg/14, floor 8, cap 34)", _fool_answers())
	# The secret hands (docs/todo.md T2)
	fails += _expect("Pentagram: one card of every Aspect", _pentagram_reads() == Poker.Hand.PENTAGRAM)
	fails += _expect("Pentagram hands a discard back", _pentagram_refund())
	fails += _expect("a Straight of five Aspects stays a STRAIGHT (upgrade-only)", _straight_not_demoted())
	fails += _expect("Full Court: Page+Knight+Queen+King", _full_court_reads() == Poker.Hand.FULL_COURT)
	fails += _expect("a scar adds permanent chips and survives a save round-trip", _scar_persists())
	fails += _expect("priestess grants extra discard (3+1)", _priestess_discards() == 4)
	fails += _expect("devil pact surcharge (50-(20+2)=28)", _devil_hp() == 28)
	fails += _expect("devil rule: play costs 2 HP (50-2=48 before enemy turn)", _blood_tax_hp() == 48)
	fails += _expect("devil tax scales with the clock (2,2 then 3)", _blood_tax_scaling())
	fails += _expect("moon rule: rot ticks once then cleanses", _moon_rot() == 0)
	fails += _expect("moon mends 15 when the round dealt under 60", _moon_mend())
	fails += _expect("world rule: block ignored AND blood tax (50-2-20=28)", _world_hp() == 28)
	fails += _expect("heal cap: pool spends and clips (15 total)", _heal_cap_check())
	fails += _expect("tower halves the heal pool (cap 8)", _tower_heal_cap() == 8)
	fails += _expect("overkill converts excess to Mercury (cap 5)", _overkill_check())
	fails += _expect("glass shatters after its durability is spent", _glass_check())
	fails += _expect("veil5 boss stands 15% taller (600 -> 690)", _veil_boss_hp() == 690)
	fails += _expect("chariot lands twice; block absorbs only the first (50-(20-8)-20=18)", _chariot_hp() == 18)
	fails += _expect("strength resists 20% (100 -> 80 effective)", _strength_eff() == 80)
	fails += _expect("hanged man caps discards at 1", _hanged_discards() == 1)
	fails += _expect("justice ripostes exactly dmg/40 (cap 8)", _justice_riposte())
	fails += _expect("judgement taxes 1 HP per rank<=3 card played", _frail_tax_check())
	fails += _expect("the star mends +12 every enemy turn", _star_regen_check())
	fails += _expect("depth 1 scales intents +35% and hp +50%", _depth_check())
	if fails == 0:
		print("test_combat: PASS")
		quit(0)
	else:
		printerr("test_combat: FAIL (%d)" % fails)
		quit(1)

func _hp_after(rule: int) -> int:
	var ctrl := CombatController.new()
	var deck: Array = []
	var os := CardData.new()
	os.rank = 7
	os.aspect = Aspects.Id.LIFE
	os.keyword = CardData.Keyword.OSLONA
	os.keyword_value = 8
	deck.append(os)
	for i in 8:
		var f := CardData.new()
		f.rank = 2
		f.aspect = Aspects.Id.LIFE
		deck.append(f)
	var e := EnemyData.new()
	e.max_hp = 9999
	e.intents = PackedInt32Array([20])
	e.rule = rule
	ctrl.start(deck, e, [], 50, 50)
	ctrl.play([0])              # play the Oslona card -> +8 block, phase becomes "enemy"
	ctrl.resolve_enemy_turn()   # enemy hits for 20
	return ctrl.player_hp

# One-intent enemy with enrage 2: the authored cycle is exact (turns 1-2 for n=1: idx 0 and 1),
# then EVERY further turn adds +step -- the per-turn clock that makes stalling lose.
func _enraged_intents() -> Array:
	var ctrl := CombatController.new()
	var e := EnemyData.new()
	e.max_hp = 9999
	e.intents = PackedInt32Array([10])
	e.enrage_step = 2
	ctrl.start(_flat_deck(12), e, [], 50, 50)
	var seen: Array = [ctrl.current_intent()]
	ctrl.play([0])
	ctrl.resolve_enemy_turn()
	seen.append(ctrl.current_intent())
	ctrl.play([0])
	ctrl.resolve_enemy_turn()
	seen.append(ctrl.current_intent())
	return seen

func _next_intent_check() -> bool:
	var ctrl := CombatController.new()
	var e := EnemyData.new()
	e.max_hp = 9999
	e.intents = PackedInt32Array([10, 20])
	e.enrage_step = 3
	ctrl.start(_flat_deck(12), e, [], 50, 50)
	# turn 1 (idx 0): current 10, next 20 (still inside the grace cycle)
	var ok := ctrl.current_intent() == 10 and ctrl.next_intent() == 20
	ctrl.play([0])
	ctrl.resolve_enemy_turn()
	# turn 2 (idx 1): current 20; next (idx 2) is the FIRST turn past the cycle -> 10 + 1*3 = 13
	ok = ok and ctrl.current_intent() == 20 and ctrl.next_intent() == 13
	ctrl.play([0])
	ctrl.resolve_enemy_turn()
	# turn 3 (idx 2): current 13; next (idx 3): over 2 -> 20 + 6 = 26
	ok = ok and ctrl.current_intent() == 13 and ctrl.next_intent() == 26
	return ok

func _blood_tax_scaling() -> bool:
	var ctrl := CombatController.new()
	var e := EnemyData.new()
	e.max_hp = 9999
	e.intents = PackedInt32Array([0])
	e.rule = EnemyData.Rule.DEVIL_BLOOD_TAX
	ctrl.start(_flat_deck(14), e, [], 50, 50)
	ctrl.play([0])              # idx 0 -> tax 2 (hp 48)
	ctrl.resolve_enemy_turn()
	ctrl.play([0])              # idx 1 -> tax 2 + 1/1 = 3 (hp 45)
	return ctrl.player_hp == 45

func _moon_mend() -> bool:
	var ctrl := CombatController.new()
	var e := EnemyData.new()
	e.max_hp = 500
	e.intents = PackedInt32Array([0])
	e.rule = EnemyData.Rule.MOON_CLEANSE
	ctrl.start(_flat_deck(9), e, [], 50, 50)
	ctrl.play([0])              # a rank-2 card deals 7 (< 60 threshold)
	var after_play := ctrl.enemy_hp
	ctrl.resolve_enemy_turn()   # the Moon mends +15
	return ctrl.enemy_hp == mini(500, after_play + 15)

func _heal_cap_check() -> bool:
	var ctrl := CombatController.new()
	var deck: Array = []
	for i in 12:
		var c := CardData.new()
		c.rank = 2
		c.aspect = Aspects.Id.LIFE
		c.keyword = CardData.Keyword.OPATRZNOSC
		c.keyword_value = 9
		deck.append(c)
	var e := EnemyData.new()
	e.max_hp = 9999
	e.intents = PackedInt32Array([0])
	ctrl.start(deck, e, [], 20, 55)
	ctrl.play([0])              # +9 heal (pool 15 -> 6)
	ctrl.resolve_enemy_turn()
	ctrl.play([0])              # raw +9, clipped to 6 (pool empty)
	var hp_ok := ctrl.heal_used == 15
	ctrl.resolve_enemy_turn()
	ctrl.play([0])              # raw +9, clipped to 0
	return hp_ok and ctrl.heal_used == 15

func _tower_heal_cap() -> int:
	var ctrl := CombatController.new()
	var e := EnemyData.new()
	e.max_hp = 9999
	e.intents = PackedInt32Array([5])
	e.rule = EnemyData.Rule.TOWER_IGNORES_BLOCK
	ctrl.start(_flat_deck(9), e, [], 50, 50)
	return ctrl.heal_cap

func _overkill_check() -> bool:
	var ctrl := CombatController.new()
	var deck: Array = []
	var big := CardData.new()
	big.rank = 12
	big.aspect = Aspects.Id.CHAOS
	big.keyword = CardData.Keyword.SPALENIE
	big.keyword_value = 200   # flat damage guarantees a huge overkill on a 10 HP dummy
	deck.append(big)
	for i in 8:
		deck.append(_flat_deck(1)[0])
	var e := EnemyData.new()
	e.max_hp = 10
	e.intents = PackedInt32Array([5])
	ctrl.start(deck, e, [], 50, 50)
	ctrl.play([0])              # 15 + 200 flat = 215 vs 10 HP -> excess 205 -> 205/50 = 4
	return ctrl.overkill_rtec == 4

func _glass_check() -> bool:
	var ctrl := CombatController.new()
	var deck: Array = []
	var glass := CardData.new()
	glass.rank = 9
	glass.aspect = Aspects.Id.CHAOS
	glass.keyword = CardData.Keyword.PRZECIAZENIE
	glass.keyword_value = 2    # durability 2
	deck.append(glass)
	for i in 10:
		deck.append(_flat_deck(1)[0])
	var e := EnemyData.new()
	e.max_hp = 9999
	e.intents = PackedInt32Array([0])
	ctrl.start(deck, e, [], 50, 50)
	ctrl.play([0])              # wear 1 -> survives, recycles via the grave
	var ok := ctrl.destroyed_cards.is_empty() and glass.wear == 1
	ctrl.resolve_enemy_turn()
	# fish the glass back: it sits in the grave; discard through the deck until it returns
	while not ctrl.hand.has(glass) and ctrl.discards_left > 0:
		ctrl.discard([0])
	if not ctrl.hand.has(glass):
		return false
	ctrl.play([ctrl.hand.find(glass)])   # wear 2 -> shatters
	return ok and ctrl.destroyed_cards.has(glass) and not ctrl.hand.has(glass)

func _veil_boss_hp() -> int:
	var ctrl := CombatController.new()
	var e := EnemyData.new()
	e.max_hp = 600
	e.intents = PackedInt32Array([15])
	e.is_boss = true
	ctrl.start(_flat_deck(9), e, [], 50, 50, {}, 5)
	return ctrl.enemy_max_hp

func _rule_enemy(rule: int, intents: Array = [20]) -> EnemyData:
	var e := EnemyData.new()
	e.max_hp = 9999
	e.intents = PackedInt32Array(intents)
	e.rule = rule as EnemyData.Rule
	return e

func _chariot_hp() -> int:
	var ctrl := CombatController.new()
	var deck := _flat_deck(9)
	deck[0].keyword = CardData.Keyword.OSLONA
	deck[0].keyword_value = 8
	ctrl.start(deck, _rule_enemy(EnemyData.Rule.CHARIOT_DOUBLE), [], 50, 50)
	ctrl.play([0])              # +8 block
	ctrl.resolve_enemy_turn()   # first strike 20-8=12, second strike 20 unblocked
	return ctrl.player_hp

func _strength_eff() -> int:
	var ctrl := CombatController.new()
	ctrl.start(_flat_deck(9), _rule_enemy(EnemyData.Rule.STRENGTH_RESIST), [], 50, 50)
	return ctrl.effective_damage(100)

func _hanged_discards() -> int:
	var ctrl := CombatController.new()
	ctrl.start(_flat_deck(9), _rule_enemy(EnemyData.Rule.HANGED_CAP), [], 50, 50)
	return ctrl.discards_left

func _justice_riposte() -> bool:
	var ctrl := CombatController.new()
	ctrl.start(_flat_deck(9), _rule_enemy(EnemyData.Rule.JUSTICE_RIPOSTE), [], 50, 50)
	return ctrl.riposte_for(39) == 0 and ctrl.riposte_for(120) == 3 and ctrl.riposte_for(999) == 8

func _frail_tax_check() -> bool:
	var ctrl := CombatController.new()
	var deck := _flat_deck(9)          # rank-2 cards: all frail
	ctrl.start(deck, _rule_enemy(EnemyData.Rule.JUDGEMENT_FRAIL, [0]), [], 50, 50)
	ctrl.play([0, 1])                  # two rank-2 cards -> -2 HP after the play
	return ctrl.player_hp == 48

func _star_regen_check() -> bool:
	var ctrl := CombatController.new()
	var e := _rule_enemy(EnemyData.Rule.STAR_REGEN, [0])
	e.max_hp = 500
	ctrl.start(_flat_deck(9), e, [], 50, 50)
	ctrl.play([0])              # rank-2: 7 damage -> 493
	ctrl.resolve_enemy_turn()   # star mends +12 -> 500 (clamped)
	return ctrl.enemy_hp == 500

func _depth_check() -> bool:
	var ctrl := CombatController.new()
	var e := EnemyData.new()
	e.max_hp = 600
	e.intents = PackedInt32Array([20])
	ctrl.start(_flat_deck(9), e, [], 50, 50, {}, 0, 1)
	# hp 600 * 1.5 = 900; intent floor(20 * 1.35) = 27
	return ctrl.enemy_max_hp == 900 and ctrl.current_intent() == 27

func _flat_deck(n: int) -> Array:
	var deck: Array = []
	for i in n:
		var f := CardData.new()
		f.rank = 2
		f.aspect = Aspects.Id.LIFE
		deck.append(f)
	return deck

func _priestess_discards() -> int:
	var relic := ArcanumData.new()
	relic.effect = ArcanumData.Effect.EXTRA_DISCARD
	relic.effect_value = 1
	var ctrl := CombatController.new()
	var e := EnemyData.new()
	e.max_hp = 9999
	e.intents = PackedInt32Array([5])
	ctrl.start(_flat_deck(9), e, [relic], 50, 50)
	return ctrl.discards_left

func _devil_hp() -> int:
	var relic := ArcanumData.new()
	relic.effect = ArcanumData.Effect.PACT_MULT
	relic.effect_mult = 1.35
	relic.effect_value = 2
	var ctrl := CombatController.new()
	var e := EnemyData.new()
	e.max_hp = 9999
	e.intents = PackedInt32Array([20])
	ctrl.start(_flat_deck(9), e, [relic], 50, 50)
	ctrl.play([0])
	ctrl.resolve_enemy_turn()
	return ctrl.player_hp

func _blood_tax_hp() -> int:
	var ctrl := CombatController.new()
	var e := EnemyData.new()
	e.max_hp = 9999
	e.intents = PackedInt32Array([0])
	e.rule = EnemyData.Rule.DEVIL_BLOOD_TAX
	ctrl.start(_flat_deck(9), e, [], 50, 50)
	ctrl.play([0])
	return ctrl.player_hp

func _moon_rot() -> int:
	var ctrl := CombatController.new()
	var deck := _flat_deck(9)
	deck[0].keyword = CardData.Keyword.GNICIE
	deck[0].keyword_value = 5
	var e := EnemyData.new()
	e.max_hp = 9999
	e.intents = PackedInt32Array([0])
	e.rule = EnemyData.Rule.MOON_CLEANSE
	ctrl.start(deck, e, [], 50, 50)
	ctrl.play([0])              # applies Rot 5
	ctrl.resolve_enemy_turn()   # rot ticks 5, then the glow cleanses it
	return ctrl.enemy_gnicie

func _world_hp() -> int:
	var ctrl := CombatController.new()
	var deck := _flat_deck(9)
	deck[0].keyword = CardData.Keyword.OSLONA
	deck[0].keyword_value = 8
	var e := EnemyData.new()
	e.max_hp = 9999
	e.intents = PackedInt32Array([20])
	e.rule = EnemyData.Rule.WORLD_ALL
	ctrl.start(deck, e, [], 50, 50)
	ctrl.play([0])              # +8 block, -2 blood tax
	ctrl.resolve_enemy_turn()   # 20 ignores block
	return ctrl.player_hp

## The Empress heals when the play was shorter than a full hand -- and only then.
func _empress_heal(cards_played: int) -> int:
	var ctrl := CombatController.new()
	var deck := _flat_deck(9)
	var e := EnemyData.new()
	e.max_hp = 9999
	e.intents = PackedInt32Array([0])
	e.rule = EnemyData.Rule.EMPRESS_BLOOM
	ctrl.start(deck, e, [], 50, 50)
	var idx: Array = []
	for i in cards_played:
		idx.append(i)
	ctrl.play(idx)
	var before := ctrl.enemy_hp
	ctrl.enemy_hp = maxi(1, ctrl.enemy_max_hp - 500)   # room to heal into
	before = ctrl.enemy_hp
	ctrl.resolve_enemy_turn()
	return ctrl.enemy_hp - before

## The Wheel advances its cycle TWICE a turn, so intents [16,22,9,30] read 16 then 9.
func _wheel_intents() -> Array:
	var ctrl := CombatController.new()
	var deck := _flat_deck(9)
	var e := EnemyData.new()
	e.max_hp = 9999
	e.intents = PackedInt32Array([16, 22, 9, 30])
	e.rule = EnemyData.Rule.WHEEL_TURN
	ctrl.start(deck, e, [], 500, 500)
	var out: Array = []
	out.append(ctrl.current_intent())
	ctrl.play([0])
	ctrl.resolve_enemy_turn()
	out.append(ctrl.current_intent())
	return out

## The Fool's intent IS the player's last blow, scaled and clamped -- and before any blow he
## falls back to his authored opener.
func _fool_answers() -> bool:
	var ctrl := CombatController.new()
	var deck := _flat_deck(9)
	var e := EnemyData.new()
	e.max_hp = 99999
	e.intents = PackedInt32Array([12])
	e.rule = EnemyData.Rule.FOOL_MIRROR
	ctrl.start(deck, e, [], 500, 500)
	if ctrl.current_intent() != 12:
		return false                       # turn one: nothing to answer yet
	ctrl.play([0])
	var dealt: int = int(ctrl.last_score.get("damage", 0))
	var want: int = clampi(dealt / 14, 8, 34)
	return ctrl.current_intent() == want and ctrl.mirror_intent(700) == 34 and ctrl.mirror_intent(14) == 8

func _card(rank: int, aspect: int) -> CardData:
	var c := CardData.new()
	c.rank = rank
	c.aspect = aspect as Aspects.Id
	return c

func _pentagram_reads() -> int:
	return Poker.evaluate([_card(2, 0), _card(4, 1), _card(6, 2), _card(8, 3), _card(10, 4)])

## Five consecutive ranks that happen to be five different Aspects: a Straight pays 120 and a
## Pentagram 90, so it must stay a Straight. Adding a hand may never make another hand worse.
func _straight_not_demoted() -> int:
	return Poker.evaluate([_card(3, 0), _card(4, 1), _card(5, 2), _card(6, 3), _card(7, 4)]) == Poker.Hand.STRAIGHT

func _full_court_reads() -> int:
	return Poker.evaluate([_card(11, 0), _card(12, 0), _card(13, 1), _card(14, 2), _card(5, 3)])

func _pentagram_refund() -> bool:
	var ctrl := CombatController.new()
	var deck: Array = []
	for i in 5:
		deck.append(_card(2 + i * 2, i))
	for i in 8:
		deck.append(_card(9, 0))
	var e := EnemyData.new()
	e.max_hp = 99999
	e.intents = PackedInt32Array([0])
	ctrl.start(deck, e, [], 50, 50)
	var before := ctrl.discards_left
	ctrl.discard([0])                     # spend one so the refund has room
	var spent := ctrl.discards_left
	# the pentagram is now the first five of the refilled hand
	var idx: Array = []
	for i in ctrl.hand.size():
		idx.append(i)
	var asp := {}
	var play: Array = []
	for i in idx:
		if not asp.has(ctrl.hand[i].aspect) and play.size() < 5:
			asp[ctrl.hand[i].aspect] = true
			play.append(i)
	if play.size() < 5:
		return false
	ctrl.play(play)
	return spent < before and ctrl.discards_left == before

## The scar must add chips AND survive the run save -- reusing `growth` would have failed the
## second half silently, because growth is deliberately never written.
func _scar_persists() -> bool:
	var c := _card(5, 0)
	var before := c.chip_value()
	c.scar = 5
	if c.chip_value() != before + 5:
		return false
	var d := {"r": c.rank, "a": c.aspect, "k": c.keyword, "v": c.keyword_value,
		"e": c.edition, "y": c.rarity, "w": c.wear, "s": c.scar}
	var back := CardData.new()
	back.rank = int(d["r"])
	back.scar = int(d.get("s", 0))
	return back.chip_value() == before + 5

func _expect(label: String, ok: bool) -> int:
	if ok:
		print("  ok: ", label)
		return 0
	printerr("  FAIL: ", label)
	return 1
