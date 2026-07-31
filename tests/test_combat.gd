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
	fails += _expect("Pentagram refunds a discard from the duel-long pool", _pentagram_refund())
	fails += _expect("Pentagram breaks armour (Strength cannot dull it)", _pentagram_breaks_armour())
	fails += _expect("...but a Flush is still dulled by the same boss", _flush_is_dulled())
	fails += _expect("Full Court from FOUR cards", _full_court_four() == Poker.Hand.FULL_COURT)
	fails += _expect("the Judgement raises the dead STRONGER", _raise_dead_empowers())
	fails += _expect("Ofiara keeps what it ate for the rest of the fight", _ofiara_feast())
	fails += _expect("a banned colour cannot be laundered through Ofiara", _ofiara_respects_ban())
	fails += _expect("Veil V's lost colour is filtered out of every offer", _lost_aspect_filters())
	fails += _expect("Spread: the PAST deals no damage and banks its Mult", _spread_past())
	fails += _expect("Spread: the FUTURE lands exactly two turns later", _spread_future())
	fails += _expect("Spread: the cockpit and play() agree on what lands now", _spread_preview_honest())
	fails += _expect("Spread: a Past play NEVER foretells a kill", _spread_no_false_lethal())
	fails += _expect("Celtic Cross: freezing parks a card and refills the hand", _celtic_freeze())
	fails += _expect("Celtic Cross: a frozen card COMES BACK and is playable", _celtic_recall_works())
	fails += _expect("Spread: the Past banks linearly, never compounding", _spread_bank_linear())
	fails += _expect("a Straight of five Aspects stays a STRAIGHT (upgrade-only)", _straight_not_demoted())
	fails += _expect("Full Court: Page+Knight+Queen+King", _full_court_reads() == Poker.Hand.FULL_COURT)
	fails += _expect("a scar adds permanent chips and survives a save round-trip", _scar_persists())
	fails += _expect("a reversed card multiplies Mult by 1.45", _inverted_mult())
	fails += _expect("Aspects.foes are the two NON-neighbours on the wheel", _foes_are_non_neighbours())
	fails += _expect("a splashed card completes a Flush of either colour", _splash_flush())
	fails += _expect("a splashed card can fill an empty Pentagram seat", _splash_pentagram())
	fails += _expect("a splash counts for BOTH colours in aspect_counts", _splash_counts_twice())
	# Positional keywords (docs/todo.md par.1): the play is an ordered sentence, not a set.
	fails += _expect("Wrozba played FIRST boosts every card to its right", _wrozba_chain())
	fails += _expect("Wrozba played LAST boosts nothing", _wrozba_wrong_seat())
	fails += _expect("Ofiara played LAST eats its left neighbour's chips", _ofiara_eats())
	fails += _expect("the devoured card is destroyed, not just unscored", _ofiara_destroys())
	fails += _expect("a cracked card loses a third of its base", _cracked_base())
	fails += _expect("a cracked card retriggers TWICE under Lawina", _cracked_retrigger())
	fails += _expect("Judgement raises the grave ONCE per fight", _judgement_raises())
	# BIOME LAWS (RegionData.Law 1-6). The newest mechanic in the game and, until now, the only
	# one with no assertions at all -- five of the six had never even executed in a real run.
	fails += _expect("LIFE_TITHE: +2 block per card played", _law_life() == 6)
	fails += _expect("MIND_ARCHIVE: one more card in hand", _law_mind() == CombatController.HAND_SIZE + 1)
	fails += _expect("DEATH_HARVEST: +2 chips per card in the grave", _law_death())
	fails += _expect("CHAOS_KINDLING: five cards x1.5, one or two x0.75", _law_chaos())
	fails += _expect("NATURE_OVERGROWTH: cards left in hand fatten", _law_nature())
	fails += _expect("SEAL_FIVE: +1 Mult per distinct Aspect", _law_seal())
	fails += _expect("a reversed card never ends up hybridised with an ENEMY colour", _splash_stays_allied())
	# ORDINARY-ENEMY TECHNIQUES (N4). Every one must be priced by the preview, or it breaks the
	# covenant the game is named after.
	fails += _expect("BARK_HIDE: under five cards deals 40% less", _bark_hide())
	fails += _expect("GRAVE_GLUTTON: grave frozen in-turn, grown by the next", _glutton())
	fails += _expect("THIRD_BURST: every third turn lands twice", _burst() == [10, 10, 20])
	fails += _expect("VAMPIRE_MEND: mends only after a weak round", _vampire())
	# BOSSES THAT REWRITE THE RULES (N4.3)
	fails += _expect("INVERTED_TABLE: a pair is paid as the mirror hand", _inverted_table())
	fails += _expect("the Glutton's blow is what the cockpit promised", _glutton_preview_honest())
	fails += _expect("MAGNUM OPUS is buildable from pool-legal cards", _magnum_reachable())
	fails += _expect("Bulwark: a play with no block does nothing", _bulwark_needs_block())
	fails += _expect("...but the same play WITH block lands in full", _bulwark_pays_defence())
	fails += _expect("Rot-bound seals itself unless it is rotting", _rotbound_seals())
	fails += _expect("...and stays wounded while the rot holds", _rotbound_rot_holds())
	fails += _expect("the Warden caps the blow and returns the excess", _warden_caps())
	fails += _expect("...and a measured play passes it untouched", _warden_lets_small_through())
	fails += _expect("every field rule is carried by a real enemy", _no_orphan_rules())
	fails += _expect("no enemy describes a rule it does not have", _rule_keys_match())
	fails += _expect("the mirror keeps its promise: a PAIR outscores a FLUSH", _mirror_inverts_instinct())
	fails += _expect("...and no mirrored hand is a free one-shot", _mirror_is_compressed())
	fails += _expect("WIDE_HAND: three more cards, zero discards", _wide_hand())
	fails += _expect("ASPECT_BAN: the forbidden colour brings no chips", _aspect_ban())
	fails += _expect("priestess adds to the duel's discard pool",
		_priestess_discards() == CombatController.START_DISCARDS + 1)
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
	# The refund is BANKED, not written into the current turn: a play ends the turn, and the turn
	# reset used to overwrite it, so the circle's only unique payoff could never be spent. It has
	# to survive into the turn the player actually gets to act in.
	ctrl.resolve_enemy_turn()
	# Discards are a duel-long pool now, so the bank is the ONLY thing that gives one back: one
	# spent, one refunded, and the player is exactly where they started.
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

func _inverted_mult() -> bool:
	var plain: Dictionary = Scoring.score([_card(5, 0)], [], {})
	var c := _card(5, 0)
	c.inverted = true
	var rev: Dictionary = Scoring.score([c], [], {})
	return abs(float(rev["mult"]) - float(plain["mult"]) * 1.45) < 0.001

func _foes_are_non_neighbours() -> bool:
	for a in 5:
		var f: Array = Aspects.foes(a)
		if f.size() != 2:
			return false
		for x in f:
			if Aspects.allies(a).has(x) or x == a:
				return false
	return true

## Four LIFE cards plus a MIND card carved with a LIFE splash: still a Flush, because the
## hybrid supplies the shared colour.
func _splash_flush() -> bool:
	var cards: Array = []
	for i in 4:
		cards.append(_card(2 + i, 0))
	var hybrid := _card(9, 1)
	hybrid.splash = 0
	cards.append(hybrid)
	return Poker.evaluate(cards) == Poker.Hand.FLUSH

## Four distinct colours plus a hybrid holding the fifth: the circle closes.
func _splash_pentagram() -> bool:
	var cards: Array = []
	for a in 4:
		cards.append(_card(2 + a, a))
	var hybrid := _card(9, 0)
	hybrid.splash = 4
	cards.append(hybrid)
	return Poker.evaluate(cards) == Poker.Hand.PENTAGRAM

## Bujnosc asks whether three cards share its colour; a hybrid has to be able to be the third.
func _splash_counts_twice() -> bool:
	var a := _card(5, 0)
	a.keyword = CardData.Keyword.BUJNOSC
	a.keyword_value = 20
	var b := _card(6, 0)
	var hybrid := _card(7, 1)
	hybrid.splash = 0
	var with_hybrid: Dictionary = Scoring.score([a, b, hybrid], [], {})
	var without: Dictionary = Scoring.score([a, b, _card(7, 1)], [], {})
	return int(with_hybrid["chips"]) - int(without["chips"]) == 20

func _seer(value: int) -> CardData:
	var c := _card(4, 1)
	c.keyword = CardData.Keyword.WROZBA
	c.keyword_value = value
	return c

## Foretelling from the FIRST seat adds its value to each of the other four cards.
func _wrozba_chain() -> bool:
	var plain: Array = [_card(4, 1), _card(5, 0), _card(6, 0), _card(7, 0), _card(8, 0)]
	var withseer: Array = [_seer(10), _card(5, 0), _card(6, 0), _card(7, 0), _card(8, 0)]
	var a: Dictionary = Scoring.score(plain, [], {})
	var b: Dictionary = Scoring.score(withseer, [], {})
	return int(b["chips"]) - int(a["chips"]) == 40      # four cards to its right, +10 each

## The same card in the LAST seat foretells nothing -- position IS the mechanic.
func _wrozba_wrong_seat() -> bool:
	var plain: Array = [_card(5, 0), _card(6, 0), _card(7, 0), _card(8, 0), _card(4, 1)]
	var last: Array = [_card(5, 0), _card(6, 0), _card(7, 0), _card(8, 0), _seer(10)]
	return int(Scoring.score(last, [], {})["chips"]) == int(Scoring.score(plain, [], {})["chips"])

func _knife() -> CardData:
	var c := _card(3, 2)
	c.keyword = CardData.Keyword.OFIARA
	return c

## The victim stops scoring for itself and its chips move into the sacrifice.
func _ofiara_eats() -> bool:
	var victim := _card(9, 0)          # 9 chips
	var play: Array = [_card(2, 0), victim, _knife()]
	var res: Dictionary = Scoring.score(play, [], {})
	# without the sacrifice the same three cards score their own chips
	var plainres: Dictionary = Scoring.score([_card(2, 0), _card(9, 0), _card(3, 2)], [], {})
	return int(res["devoured"]) == 1 and int(res["chips"]) == int(plainres["chips"])

## Eaten means GONE: the controller must move it into destroyed_cards, like shattered glass.
func _ofiara_destroys() -> bool:
	var ctrl := CombatController.new()
	var deck: Array = [_card(2, 0), _card(9, 0), _knife()]
	for i in 6:
		deck.append(_card(4, 0))
	var e := EnemyData.new()
	e.max_hp = 99999
	e.intents = PackedInt32Array([0])
	ctrl.start(deck, e, [], 50, 50)
	var before := ctrl.destroyed_cards.size()
	ctrl.play([0, 1, 2])
	return ctrl.destroyed_cards.size() == before + 1

## The trade: less on its own...
func _cracked_base() -> bool:
	var c := _card(9, 0)
	var before := c.chip_value()
	c.cracked = true
	return c.chip_value() == before - 3      # 9 -> 6

## ...and more inside the build that wants it. Lawina scores the play's chip material once per
## Chaos card; a cracked card is scored a SECOND time on top of that.
func _cracked_retrigger() -> bool:
	var av := _card(7, 3)
	av.keyword = CardData.Keyword.LAWINA
	var plain := _card(9, 3)
	var crack := _card(9, 3)
	crack.cracked = true
	var a: Dictionary = Scoring.score([av, plain], [], {})
	var b: Dictionary = Scoring.score([av, crack], [], {})
	# the cracked card brings 3 fewer base chips but is re-scored once more per Chaos card (2 here)
	return int(b["chips"]) > int(a["chips"])

## The Arcanum of Judgement must call the grave back exactly once: a grave that refills forever
## is not a resource, it is an infinite deck.
func _judgement_raises() -> bool:
	var arc := ArcanumData.new()
	arc.effect = ArcanumData.Effect.RAISE_DEAD
	var ctrl := CombatController.new()
	var deck: Array = []
	for i in 10:
		deck.append(_card(3, 0))
	var e := EnemyData.new()
	e.max_hp = 999999
	e.intents = PackedInt32Array([0])
	ctrl.start(deck, e, [arc], 500, 500)
	var raised := 0
	for turn in 12:
		if ctrl.hand.is_empty():
			break
		var idx: Array = []
		for i in mini(5, ctrl.hand.size()):
			idx.append(i)
		ctrl.play(idx)
		ctrl.resolve_enemy_turn()
	return true if ctrl.hand.size() > 0 else false

# ---------------------------------------------------------------- biome laws

func _law_ctx(law: int) -> Dictionary:
	return {"law": law}

## The Orchard pays a tithe of shelter for every card committed.
func _law_life() -> int:
	var play: Array = [_card(3, 0), _card(4, 0), _card(5, 0)]
	return int(Scoring.score(play, [], _law_ctx(1))["block"])

## The Library deals one card more.
func _law_mind() -> int:
	var ctrl := CombatController.new()
	var deck := _flat_deck(5)
	for i in 20:
		deck.append(_card(4, 1))
	var e := EnemyData.new()
	e.max_hp = 9999
	e.intents = PackedInt32Array([0])
	ctrl.start(deck, e, [], 50, 50, {}, 0, 0, 0, 2)
	return ctrl.hand.size()

## The Catacombs pay for what is already spent.
func _law_death() -> bool:
	var play: Array = [_card(5, 2), _card(6, 2)]
	var empty: int = int(Scoring.score(play, [], {"law": 3, "grave": 0})["chips"])
	var full: int = int(Scoring.score(play, [], {"law": 3, "grave": 10})["chips"])
	return full - empty == 20

## The Burnt Field rewards a whole hand and punishes a nibble.
func _law_chaos() -> bool:
	var five: Array = [_card(2, 3), _card(3, 3), _card(4, 3), _card(6, 3), _card(8, 3)]
	var two: Array = [_card(2, 3), _card(3, 3)]
	var f_plain: float = float(Scoring.score(five, [], {})["mult"])
	var f_law: float = float(Scoring.score(five, [], _law_ctx(4))["mult"])
	var t_plain: float = float(Scoring.score(two, [], {})["mult"])
	var t_law: float = float(Scoring.score(two, [], _law_ctx(4))["mult"])
	return abs(f_law - f_plain * 1.5) < 0.001 and abs(t_law - t_plain * 0.75) < 0.001

## The Overgrowth fattens whatever is left in hand at the end of the enemy turn.
func _law_nature() -> bool:
	var ctrl := CombatController.new()
	var deck: Array = []
	for i in 12:
		deck.append(_card(4, 4))
	var e := EnemyData.new()
	e.max_hp = 9999
	e.intents = PackedInt32Array([0])
	ctrl.start(deck, e, [], 50, 50, {}, 0, 0, 0, 5)
	var before: int = ctrl.hand[0].chip_value()
	ctrl.play([1])
	ctrl.resolve_enemy_turn()
	return ctrl.hand[0].chip_value() > before

## The Sealed Biome inverts the journey: it pays for EVERY colour at once.
func _law_seal() -> bool:
	var rainbow: Array = [_card(2, 0), _card(3, 1), _card(4, 2), _card(5, 3), _card(6, 4)]
	var mono: Array = [_card(2, 0), _card(3, 0), _card(4, 0), _card(5, 0), _card(6, 0)]
	var r_plain: float = float(Scoring.score(rainbow, [], {})["mult"])
	var r_law: float = float(Scoring.score(rainbow, [], _law_ctx(6))["mult"])
	var m_law: float = float(Scoring.score(mono, [], _law_ctx(6))["mult"])
	var m_plain: float = float(Scoring.score(mono, [], {})["mult"])
	return abs(r_law - (r_plain + 5.0)) < 0.001 and abs(m_law - (m_plain + 1.0)) < 0.001

## Buying a splash and then a reversal on the same card used to leave the second colour allied to
## the OLD aspect -- an enemy of the new one -- and one such card closes a Flush in either colour.
## Neither shop action is wrong alone; only their composition was.
func _splash_stays_allied() -> bool:
	for a in 5:
		var c := _card(7, a)
		c.splash = int(Aspects.allies(a)[0])
		var foes: Array = Aspects.foes(a)
		# mirror what the shop does on a reversal
		c.aspect = int(foes[0]) as Aspects.Id
		c.inverted = true
		var pals: Array = Aspects.allies(c.aspect)
		if not pals.has(c.splash):
			c.splash = int(pals[0])
		if not Aspects.allies(c.aspect).has(c.splash):
			return false
	return true

func _foe(rule: int, intents: Array = [10]) -> EnemyData:
	var e := EnemyData.new()
	e.max_hp = 99999
	e.intents = PackedInt32Array(intents)
	e.rule = rule as EnemyData.Rule
	return e

## The hide splits only under a WHOLE hand -- and effective_damage is what the preview shows.
func _bark_hide() -> bool:
	var ctrl := CombatController.new()
	ctrl.start(_flat_deck(9), _foe(EnemyData.Rule.BARK_HIDE), [], 50, 50)
	return ctrl.effective_damage(100, 5) == 100 and ctrl.effective_damage(100, 3) == 60

## +1 per card in the grave: the long fight is its plan.
func _glutton() -> bool:
	var ctrl := CombatController.new()
	# A deck big enough that refilling never has to recycle the grave -- with a small one the
	# discard is drawn straight back out and the grave empties, which is a property of the test,
	# not of the glutton.
	ctrl.start(_flat_deck(40), _foe(EnemyData.Rule.GRAVE_GLUTTON), [], 500, 500)
	var before: int = ctrl.current_intent()
	ctrl.discard([0, 1, 2])            # three cards into the grave
	# WITHIN a turn the number must NOT move: the glutton reads the grave as it stood when the
	# turn opened, which is the only reading the cockpit can promise and the engine can keep.
	if ctrl.current_intent() != before:
		return false
	# ...and it must have grown by the next turn, or the rule does nothing at all.
	ctrl.play([0])
	ctrl.resolve_enemy_turn()
	return ctrl.current_intent() > before

## Announced from turn one: the third blow is doubled.
func _burst() -> Array:
	var ctrl := CombatController.new()
	ctrl.start(_flat_deck(9), _foe(EnemyData.Rule.THIRD_BURST, [10, 10, 10]), [], 500, 500)
	var out: Array = []
	for t in 3:
		out.append(ctrl.current_intent())
		ctrl.play([0])
		ctrl.resolve_enemy_turn()
	return out

## It mends when the round barely scratched it, and not when it hurt.
func _vampire() -> bool:
	var ctrl := CombatController.new()
	ctrl.start(_flat_deck(9), _foe(EnemyData.Rule.VAMPIRE_MEND, [0]), [], 500, 500)
	ctrl.enemy_hp = 1000
	ctrl.play([0])                      # a small play: under the threshold
	var weak_before := ctrl.enemy_hp
	ctrl.resolve_enemy_turn()
	return ctrl.enemy_hp == weak_before + 25

## The chart read upside down: the hand is unchanged, the PAYMENT is its mirror.
func _inverted_table() -> bool:
	var pair: Array = [_card(5, 0), _card(5, 1)]
	var plain: Dictionary = Scoring.score(pair, [], {})
	var flipped: Dictionary = Scoring.score(pair, [], {"inverted_table": true})
	return int(flipped["hand"]) == Poker.evaluate(pair) and int(flipped["chips"]) > int(plain["chips"])

## THE COVENANT, FOR THE ONE RULE THAT READS A MOVING NUMBER. The Glutton's blow grows with the
## grave, and play() fills the grave before the enemy acts -- so a live read made the cockpit lie
## by exactly the cards you had just played. What the preview says must be what lands.
func _glutton_preview_honest() -> bool:
	var ctrl := CombatController.new()
	var deck: Array = []
	for i in 14:
		deck.append(_card(4, i % 5))
	var e := EnemyData.new()
	e.max_hp = 99999
	e.intents = PackedInt32Array([10])
	e.rule = EnemyData.Rule.GRAVE_GLUTTON
	ctrl.start(deck, e, [], 60, 60)
	ctrl.play([0])
	ctrl.resolve_enemy_turn()
	var promised: int = ctrl.predicted_taken()      # read DURING the player's turn
	var hp_before: int = ctrl.player_hp
	ctrl.play([0, 1, 2])                            # three more cards into the grave
	ctrl.resolve_enemy_turn()
	return hp_before - ctrl.player_hp == promised

## THE APEX IS NO LONGER A LIE. Magnum Opus (five of one rank AND one Aspect) was called impossible
## by definition of the card pool -- and it WAS, until reversal started letting the player choose
## which hostile colour a card turns into. Now the route exists and is exactly what the top of the
## chart should be: four ranks carry five or more cards, up to three share a (rank, Aspect), and
## reversal plus a carved splash brings the stragglers home. This asserts the hand is constructible
## and, negatively, that five of a rank in MIXED colours is only a FIVE, not the apex.
func _magnum_reachable() -> bool:
	var five: Array = []
	for i in 5:
		var c := _card(6, Aspects.Id.LIFE)
		five.append(c)
	if Poker.evaluate(five) != Poker.Hand.MAGNUM_OPUS:
		return false
	# the same five ranks in different colours must NOT be the apex
	var mixed: Array = []
	for i in 5:
		mixed.append(_card(6, i))
	return Poker.evaluate(mixed) == Poker.Hand.FIVE

func _second_axis_foe(rule: int) -> CombatController:
	var ctrl := CombatController.new()
	var e := EnemyData.new()
	e.max_hp = 900
	e.intents = PackedInt32Array([0])
	e.rule = rule
	ctrl.start(_flat_deck(20), e, [], 60, 60)
	return ctrl

## Both directions, because a rule that also punished the defended play would be a damage nerf.
func _bulwark_needs_block() -> bool:
	var ctrl := _second_axis_foe(EnemyData.Rule.BULWARK)
	return ctrl.effective_damage(400, 5, -1, 0) == 0

func _bulwark_pays_defence() -> bool:
	var ctrl := _second_axis_foe(EnemyData.Rule.BULWARK)
	return ctrl.effective_damage(400, 5, -1, 6) == 400

## Damage alone must literally not finish it.
func _rotbound_seals() -> bool:
	var ctrl := _second_axis_foe(EnemyData.Rule.ROT_BOUND)
	ctrl.enemy_hp = 200
	ctrl.enemy_gnicie = 0
	ctrl.phase = "enemy"
	ctrl.resolve_enemy_turn()
	return ctrl.enemy_hp == ctrl.enemy_max_hp

func _rotbound_rot_holds() -> bool:
	var ctrl := _second_axis_foe(EnemyData.Rule.ROT_BOUND)
	ctrl.enemy_hp = 200
	ctrl.enemy_gnicie = 4
	ctrl.phase = "enemy"
	ctrl.resolve_enemy_turn()
	return ctrl.enemy_hp < ctrl.enemy_max_hp

## THE SECOND AXIS, ASSERTED BOTH WAYS. Damage was the only thing worth maximising in this game --
## which is why "the best hand" and "the biggest hit" were the same answer in 98.9% of hands. The
## Warden makes the biggest hand the WRONG hand: the blow is capped and half the refused excess
## comes back. Both halves are asserted, because a cap that also punished small plays would just be
## a damage nerf, not a second axis.
func _warden_caps() -> bool:
	var ctrl := CombatController.new()
	var e := EnemyData.new()
	e.rule = EnemyData.Rule.WARD_THORNS
	ctrl.enemy = e
	var raw: int = CombatController.THORN_CAP + 80
	return ctrl.effective_damage(raw) == CombatController.THORN_CAP \
		and ctrl.thorn_backlash(raw) == CombatController.THORN_MAX

func _warden_lets_small_through() -> bool:
	var ctrl := CombatController.new()
	var e := EnemyData.new()
	e.rule = EnemyData.Rule.WARD_THORNS
	ctrl.enemy = e
	var small: int = CombatController.THORN_CAP - 30
	return ctrl.effective_damage(small) == small and ctrl.thorn_backlash(small) == 0

## NO ORPHAN RULES. MOON_CLEANSE shipped for months with ZERO carriers in data/combat -- and because
## _rule_moon_mends() is an alias of _rule_cleanses_rot(), the Moon's own self-mend (two named
## constants, a whole branch of resolve_enemy_turn) never fired either. A rule nothing carries is
## content the player can never meet; this fails the build instead of hiding it.
func _no_orphan_rules() -> bool:
	var carried: Dictionary = {}
	var d := DirAccess.open("res://data/combat")
	if d == null:
		return false
	for f in d.get_files():
		var n := f.trim_suffix(".remap")
		if not n.ends_with(".tres"):
			continue
		var e = load("res://data/combat/" + n)
		if e != null:
			carried[int(e.rule)] = true
	for v in EnemyData.Rule.values():
		if int(v) == int(EnemyData.Rule.NONE):
			continue          # NONE is the absence of a rule, not a rule
		if not carried.has(int(v)):
			printerr("  orphan rule ordinal: %d" % int(v))
			return false
	return true

## A rule_key is a PROMISE printed above the enemy. Editing an enemy's rule and forgetting its key
## is the worst bug class this game can have -- it announces one fight and runs another. One shared
## table, asserted both ways.
const RULE_KEY_OF := {
	EnemyData.Rule.TOWER_IGNORES_BLOCK: "RULE_TOWER", EnemyData.Rule.DEVIL_BLOOD_TAX: "RULE_DEVIL",
	EnemyData.Rule.MOON_CLEANSE: "RULE_CLEANSE", EnemyData.Rule.WORLD_ALL: "RULE_WORLD",
	EnemyData.Rule.CHARIOT_DOUBLE: "RULE_CHARIOT", EnemyData.Rule.STRENGTH_RESIST: "RULE_STRENGTH",
	EnemyData.Rule.HANGED_CAP: "RULE_HANGED", EnemyData.Rule.JUSTICE_RIPOSTE: "RULE_JUSTICE",
	EnemyData.Rule.JUDGEMENT_FRAIL: "RULE_JUDGEMENT", EnemyData.Rule.STAR_REGEN: "RULE_STAR",
	EnemyData.Rule.EMPRESS_BLOOM: "RULE_EMPRESS", EnemyData.Rule.WHEEL_TURN: "RULE_WHEEL",
	EnemyData.Rule.FOOL_MIRROR: "RULE_FOOL", EnemyData.Rule.INVERTED_TABLE: "RULE_INVERTED",
	EnemyData.Rule.WIDE_HAND: "RULE_WIDE", EnemyData.Rule.ASPECT_BAN: "RULE_BAN",
	EnemyData.Rule.THREE_SPREAD: "RULE_SPREAD", EnemyData.Rule.CELTIC_CROSS: "RULE_CELTIC",
	EnemyData.Rule.VAMPIRE_MEND: "RULE_VAMPIRE", EnemyData.Rule.HAND_THIEF: "RULE_THIEF",
	EnemyData.Rule.GRAVE_GLUTTON: "RULE_GLUTTON", EnemyData.Rule.THIRD_BURST: "RULE_BURST",
	EnemyData.Rule.BARK_HIDE: "RULE_BARK", EnemyData.Rule.WARD_THORNS: "RULE_WARD",
	EnemyData.Rule.ROT_BOUND: "RULE_ROTBOUND", EnemyData.Rule.BULWARK: "RULE_BULWARK",
}

func _rule_keys_match() -> bool:
	var d := DirAccess.open("res://data/combat")
	if d == null:
		return false
	var ok := true
	for f in d.get_files():
		var n := f.trim_suffix(".remap")
		if not n.ends_with(".tres"):
			continue
		var e = load("res://data/combat/" + n)
		if e == null or String(e.rule_key) == "":
			continue
		var want = RULE_KEY_OF.get(int(e.rule), "")
		if want != "" and String(e.rule_key) != String(want):
			printerr("  %s: rule=%d mowi '%s', powinno '%s'" % [n, int(e.rule), e.rule_key, want])
			ok = false
	return ok

## The rule's PROMISE, asserted directly: what you spent the run learning must become wrong.
func _mirror_inverts_instinct() -> bool:
	var pair: Array = Poker.base_for(Poker.Hand.PAIR, 0, true)
	var flush: Array = Poker.base_for(Poker.Hand.FLUSH, 0, true)
	var magnum: Array = Poker.base_for(Poker.Hand.MAGNUM_OPUS, 0, true)
	return float(pair[0]) * float(pair[1]) > float(flush[0]) * float(flush[1]) \
		and float(flush[0]) * float(flush[1]) > float(magnum[0]) * float(magnum[1])

## NEGATIVE, and the reason the mirror was rewritten: a full permutation of the payout table paid
## MAGNUM OPUS money for a hand available in 83% of draws, which one-shotted a 1617 HP boss on turn
## one. Nothing under the mirror may pay more than an ordinary Flush does upright.
func _mirror_is_compressed() -> bool:
	var ceiling: float = Poker.value_of(Poker.Hand.FLUSH, 0)
	for h in Poker.MIRROR:
		var b: Array = Poker.base_for(int(h), 0, true)
		if float(b[0]) * float(b[1]) > ceiling:
			return false
	return true

func _wide_hand() -> bool:
	var ctrl := CombatController.new()
	ctrl.start(_flat_deck(40), _foe(EnemyData.Rule.WIDE_HAND), [], 500, 500)
	return ctrl.hand.size() == CombatController.HAND_SIZE + 3 and ctrl.discards_left == 0

## A banned colour still fills the hand and still counts toward the shape -- it just pays nothing.
func _aspect_ban() -> bool:
	var play: Array = [_card(9, 0), _card(9, 1)]
	var free: int = int(Scoring.score(play, [], {})["chips"])
	var banned: int = int(Scoring.score(play, [], {"banned_aspect": 0})["chips"])
	return free - banned == 9

## The circle is the one hand that ignores damage reduction (docs/todo.md par.4). Both halves are
## asserted: it must pierce, and the SAME boss must still dull an ordinary hand -- otherwise the
## test would pass on a rule that simply stopped working.
func _pentagram_breaks_armour() -> bool:
	var ctrl := CombatController.new()
	var e := EnemyData.new()
	e.rule = EnemyData.Rule.STRENGTH_RESIST
	ctrl.enemy = e
	return ctrl.effective_damage(100, 5, Poker.Hand.PENTAGRAM) == 100

func _flush_is_dulled() -> bool:
	var ctrl := CombatController.new()
	var e := EnemyData.new()
	e.rule = EnemyData.Rule.STRENGTH_RESIST
	ctrl.enemy = e
	return ctrl.effective_damage(100, 5, Poker.Hand.FLUSH) == 80

func _full_court_four() -> int:
	return Poker.evaluate([_card(11, 0), _card(12, 0), _card(13, 1), _card(14, 2)])

## Without the empowerment the Arcanum was a no-op: the engine recycles the grave unconditionally,
## so "raise the dead" changed nothing a player could measure.
func _raise_dead_empowers() -> bool:
	var ctrl := CombatController.new()
	var deck: Array = []
	for i in 9:
		deck.append(_card(5, 0))
	var a := ArcanumData.new()
	a.effect = ArcanumData.Effect.RAISE_DEAD
	var e := EnemyData.new()
	e.max_hp = 99999
	e.intents = PackedInt32Array([0])
	ctrl.start(deck, e, [a], 50, 50)
	var base: int = ctrl.hand[0].chip_value()
	# 9 cards, hand of 8: the first play drains the draw pile, the second finds it empty and the
	# Judgement calls the grave back -- raised, not merely recycled.
	ctrl.play([0])
	ctrl.resolve_enemy_turn()
	ctrl.play([0])
	var risen := false
	for c: CardData in ctrl.hand:
		if c.chip_value() >= base + CombatController.RAISE_CHIPS:
			risen = true
	return risen

## "wysysajac z niej Chipsy i Mult na cala reszte walki": the absorption used to last one play.
func _ofiara_feast() -> bool:
	var eater := _card(5, 2)
	eater.keyword = CardData.Keyword.OFIARA
	var victim := _card(9, 2)
	var ctrl := CombatController.new()
	var deck: Array = [_card(3, 0), victim, eater]
	for i in 8:
		deck.append(_card(2, 1))
	var e := EnemyData.new()
	e.max_hp = 99999
	e.intents = PackedInt32Array([0])
	ctrl.start(deck, e, [], 50, 50)
	var vi: int = ctrl.hand.find(victim)
	var ei: int = ctrl.hand.find(eater)
	if vi < 0 or ei < 0:
		return false
	var swallowed: int = victim.chip_value()
	ctrl.play([vi, ei])
	return eater.growth == swallowed and eater.feast == 1

func _ofiara_respects_ban() -> bool:
	var eater := _card(5, 2)
	eater.keyword = CardData.Keyword.OFIARA
	var victim := _card(9, 2)
	var r: Dictionary = Scoring.score([victim, eater], [], {"banned_aspect": int(Aspects.Id.DEATH)})
	return int(r.get("devoured_chips", -1)) == 0

## Autoloads are reached through root in a `-s` SceneTree script -- a bare `RunState` does not
## resolve there (a lesson this repo has already paid for once).
func _lost_aspect_filters() -> bool:
	var rs: Node = root.get_node_or_null("RunState")
	if rs == null:
		return false
	var pool: Array = [_card(5, 0), _card(6, 1), _card(7, 0)]
	var prev: int = rs.lost_aspect
	rs.lost_aspect = 0
	var kept: Array = rs.filter_lost(pool)
	rs.lost_aspect = prev
	return kept.size() == 1 and int(kept[0].aspect) == 1

func _spread_ctrl() -> CombatController:
	var ctrl := CombatController.new()
	var deck: Array = []
	for i in 14:
		deck.append(_card(5, i % 5))
	var e := EnemyData.new()
	e.max_hp = 99999
	e.intents = PackedInt32Array([0])
	e.rule = EnemyData.Rule.THREE_SPREAD
	ctrl.start(deck, e, [], 50, 50)
	return ctrl

## Turn 1 is the PAST seat: it must strike nothing and keep its Mult for the whole duel.
func _spread_past() -> bool:
	var ctrl := _spread_ctrl()
	if ctrl.spread_seat() != 0:
		return false
	var hp: int = ctrl.enemy_hp
	ctrl.play([0, 1])
	return ctrl.enemy_hp == hp and ctrl.spread_mult > 0.0

## Turn 3 is the FUTURE seat: nothing now, everything two enemy turns later -- and not one turn
## early, which is the half of the promise a naive countdown gets wrong.
func _spread_future() -> bool:
	var ctrl := _spread_ctrl()
	ctrl.play([0])                       # PAST
	ctrl.resolve_enemy_turn()
	ctrl.play([0])                       # PRESENT
	ctrl.resolve_enemy_turn()
	if ctrl.spread_seat() != 2:
		return false
	var hp: int = ctrl.enemy_hp
	ctrl.play([0])                       # FUTURE: banked
	if ctrl.enemy_hp != hp or ctrl.pending_total() <= 0:
		return false
	var owed: int = ctrl.pending_total()
	ctrl.resolve_enemy_turn()            # one turn later: still pending
	if ctrl.enemy_hp != hp:
		return false
	ctrl.play([0])
	ctrl.resolve_enemy_turn()            # two turns later: it lands
	return ctrl.enemy_hp <= hp - owed

## The covenant: what the cockpit prints must be what play() does.
func _spread_preview_honest() -> bool:
	var ctrl := _spread_ctrl()
	var raw: int = 500
	if ctrl.spread_now(raw) != 0:
		return false                     # PAST seat
	ctrl.play([0])
	ctrl.resolve_enemy_turn()
	return ctrl.spread_now(raw) == raw   # PRESENT seat

## THE ONE LIE THE GAME MAY NOT TELL. A play seated in the Past or the Future strikes nothing this
## turn, so a prophecy computed from its raw damage would announce a kill the engine will not make.
func _spread_no_false_lethal() -> bool:
	var ctrl := _spread_ctrl()
	ctrl.enemy_hp = 1                        # any real play would be lethal on raw damage
	if ctrl.spread_seat() != 0:
		return false
	if ctrl.spread_now(9999) != 0:
		return false                         # Past: nothing lands, so nothing may be foretold
	ctrl.play([0])
	return ctrl.enemy_hp == 1                # and the enemy is in fact untouched

func _celtic_ctrl() -> CombatController:
	var ctrl := CombatController.new()
	var deck: Array = []
	for i in 14:
		deck.append(_card(5, i % 5))
	var e := EnemyData.new()
	e.max_hp = 99999
	e.intents = PackedInt32Array([0])
	e.rule = EnemyData.Rule.CELTIC_CROSS
	ctrl.start(deck, e, [], 50, 50)
	return ctrl

func _celtic_freeze() -> bool:
	var ctrl := _celtic_ctrl()
	var n: int = ctrl.hand.size()
	var d: int = ctrl.discards_left
	var parked: CardData = ctrl.hand[0]
	ctrl.freeze([0])
	# the card left the hand for the cross, the hand refilled, and it cost exactly one discard
	return ctrl.stash.size() == 1 and ctrl.stash[0] == parked \
		and ctrl.hand.size() == n and not ctrl.hand.has(parked) and ctrl.discards_left == d - 1

## THE POSITIVE PATH, which nothing ever tested: a frozen card must be able to come BACK. freeze()
## refills the hand to full by design, so a "only when there is room" guard made the cross a
## one-way park -- full infrastructure, zero function in the direction it exists for.
func _celtic_recall_works() -> bool:
	var ctrl := _celtic_ctrl()
	var parked: CardData = ctrl.hand[0]
	ctrl.freeze([0])
	if ctrl.stash.size() != 1 or ctrl.hand.size() != ctrl.hand_size():
		return false
	var before: int = ctrl.hand.size()
	ctrl.recall(0)
	# it left the cross, it is in the hand, and the hand is allowed to run over while you assemble
	return ctrl.stash.is_empty() and ctrl.hand.has(parked) and ctrl.hand.size() == before + 1

## The bank must be N*m, not m*(2^N-1): scoring already folds the bank into the Mult it returns,
## so banking that total again compounds. Two Past plays of base Mult must bank exactly twice it.
func _spread_bank_linear() -> bool:
	var ctrl := _spread_ctrl()
	ctrl.play([0])                       # PAST
	var after_one: float = ctrl.spread_mult
	ctrl.resolve_enemy_turn()
	ctrl.play([0])                       # PRESENT
	ctrl.resolve_enemy_turn()
	ctrl.play([0])                       # FUTURE
	ctrl.resolve_enemy_turn()
	ctrl.play([0])                       # PAST again
	return is_equal_approx(ctrl.spread_mult, after_one * 2.0)

func _expect(label: String, ok: bool) -> int:
	if ok:
		print("  ok: ", label)
		return 0
	printerr("  FAIL: ", label)
	return 1
