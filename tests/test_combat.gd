extends SceneTree
## Headless combat-rule test. Run: godot --headless -s res://tests/test_combat.gd
## Verifies that block reduces a normal enemy's hit but the Tower's rule ignores it.

func _initialize() -> void:
	var fails: int = 0
	fails += _expect("normal block reduces (50 - (20-8) = 38)", _hp_after(EnemyData.Rule.NONE) == 38)
	fails += _expect("tower ignores block (50 - 20 = 30)", _hp_after(EnemyData.Rule.TOWER_IGNORES_BLOCK) == 30)
	fails += _expect("enrage raises intent per cycle (10 -> 12)", _enraged_intent() == 12)
	fails += _expect("priestess grants extra discard (3+1)", _priestess_discards() == 4)
	fails += _expect("devil pact surcharge (50-(20+2)=28)", _devil_hp() == 28)
	fails += _expect("devil rule: play costs 2 HP (50-2=48 before enemy turn)", _blood_tax_hp() == 48)
	fails += _expect("moon rule: rot ticks once then cleanses", _moon_rot() == 0)
	fails += _expect("world rule: block ignored AND blood tax (50-2-20=28)", _world_hp() == 28)
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

# One-intent enemy with enrage 2: after one full cycle the telegraphed hit is base + 2.
func _enraged_intent() -> int:
	var ctrl := CombatController.new()
	var deck: Array = []
	for i in 9:
		var f := CardData.new()
		f.rank = 2
		f.aspect = Aspects.Id.LIFE
		deck.append(f)
	var e := EnemyData.new()
	e.max_hp = 9999
	e.intents = PackedInt32Array([10])
	e.enrage_step = 2
	ctrl.start(deck, e, [], 50, 50)
	ctrl.play([0])
	ctrl.resolve_enemy_turn()   # cycle completes -> next intent enraged
	return ctrl.current_intent()

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
