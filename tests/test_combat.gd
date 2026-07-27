extends SceneTree
## Headless combat-rule test. Run: godot --headless -s res://tests/test_combat.gd
## Verifies that block reduces a normal enemy's hit but the Tower's rule ignores it.

func _initialize() -> void:
	var fails: int = 0
	fails += _expect("normal block reduces (50 - (20-8) = 38)", _hp_after(EnemyData.Rule.NONE) == 38)
	fails += _expect("tower ignores block (50 - 20 = 30)", _hp_after(EnemyData.Rule.TOWER_IGNORES_BLOCK) == 30)
	fails += _expect("enrage: grace cycle exact, then +step per turn (10,10,12)", _enraged_intents() == [10, 10, 12])
	fails += _expect("next_intent looks one turn ahead", _next_intent_check())
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
	# turn 1: current 10, next 20 (still inside the grace cycle)
	var ok := ctrl.current_intent() == 10 and ctrl.next_intent() == 20
	ctrl.play([0])
	ctrl.resolve_enemy_turn()
	# turn 2: current 20 (idx 1), next = intents[0] + 0*3? idx 2, over = 0 -> 10... n=2: over=max(0,2-2)=0 -> 10
	ok = ok and ctrl.current_intent() == 20 and ctrl.next_intent() == 10
	ctrl.play([0])
	ctrl.resolve_enemy_turn()
	# turn 3 (idx 2): over 0 -> 10; next (idx 3): over 1 -> 20+3 = 23
	ok = ok and ctrl.current_intent() == 10 and ctrl.next_intent() == 23
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

func _expect(label: String, ok: bool) -> int:
	if ok:
		print("  ok: ", label)
		return 0
	printerr("  FAIL: ", label)
	return 1
