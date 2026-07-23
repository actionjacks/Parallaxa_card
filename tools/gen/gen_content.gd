extends SceneTree
## Content generator: writes authorable .tres for cards, decks, enemies, arcana and the region.
## Run (headless): godot --headless -s res://tools/gen/gen_content.gd
## Re-run to regenerate; outputs are editor-first resources you can then tweak by hand.

const A := Aspects.Id
const KW := CardData.Keyword
const CARD_DIR := "res://data/cards/"
const DECK_DIR := "res://data/decks/"
const ENEMY_DIR := "res://data/combat/"
const ARCANA_DIR := "res://data/arcana/"
const REGION_DIR := "res://data/regions/"

func _initialize() -> void:
	for d in [CARD_DIR, DECK_DIR, ENEMY_DIR, ARCANA_DIR, REGION_DIR]:
		if not DirAccess.dir_exists_absolute(d):
			DirAccess.make_dir_recursive_absolute(d)
	var starter := _make(_starter(), "s")
	var pool := _make(_pool(), "p")
	_deck("starter", "DECK_STARTER", starter)
	_deck("reward_pool", "DECK_REWARD_POOL", pool)
	_region()
	print("gen_content: %d starter + %d pool cards, enemies + arcana + region_01 written"
		% [starter.size(), pool.size()])
	quit(0)

# ---- cards / decks ----

func _make(specs: Array, prefix: String) -> Array:
	var out: Array = []
	for i in specs.size():
		var s: Array = specs[i]
		var c := CardData.new()
		c.rank = s[0]
		c.aspect = s[1]
		c.keyword = s[2]
		c.keyword_value = s[3]
		var path := "%s%s_%02d.tres" % [CARD_DIR, prefix, i]
		ResourceSaver.save(c, path)
		out.append(load(path))
	return out

func _deck(id: String, name_key: String, cards: Array) -> void:
	var d := DeckData.new()
	d.name_key = name_key
	var typed: Array[CardData] = []
	for c in cards:
		typed.append(c)
	d.cards = typed
	ResourceSaver.save(d, "%s%s.tres" % [DECK_DIR, id])

# ---- enemies / arcana / region ----

func _region() -> void:
	var death := _arcanum("ARCANUM_SMIERCI", A.DEATH, 1.4)
	ResourceSaver.save(death, ARCANA_DIR + "arcanum_death.tres")
	var tower_arc := _arcanum("ARCANUM_WIEZA", A.CHAOS, 1.4)
	ResourceSaver.save(tower_arc, ARCANA_DIR + "arcanum_tower.tres")

	# HP tuned so a strong opening play does not one-shot: fights last ~2-3 turns, the boss ~4-5,
	# so enemy intents, block, heal, DoT stacking and the Tower rule all actually come into play.
	# NOTE(balance): the starter deck front-loads one big Death flush (~440) then falls off to weak
	# singletons, and the Death Arcanum makes that flush dominant. HP is tuned so fights end in ~2 turns
	# (enemy survives the opener, so intents/attacks are seen) without a long grind. Real tuning is a
	# gameplay pass -- likely: reward sustained plays, tone down the flush, or add rest/heal between fights.
	var a := _enemy("ENEMY_KULTYSTA", 460, [8, 10, 6], 5, false, EnemyData.Rule.NONE, "")
	ResourceSaver.save(a, ENEMY_DIR + "enemy_a.tres")
	var b := _enemy("ENEMY_CIEN", 500, [9, 12, 7], 6, false, EnemyData.Rule.NONE, "")
	ResourceSaver.save(b, ENEMY_DIR + "enemy_b.tres")
	var boss := _enemy("ENEMY_WIEZA", 560, [11, 14, 9], 12, true, EnemyData.Rule.TOWER_IGNORES_BLOCK, "RULE_TOWER")
	ResourceSaver.save(boss, ENEMY_DIR + "boss_tower.tres")

	var region := RegionData.new()
	region.name_key = "REGION_01"
	var fights: Array[EnemyData] = []
	fights.append(load(ENEMY_DIR + "enemy_a.tres"))
	fights.append(load(ENEMY_DIR + "enemy_b.tres"))
	region.fights = fights
	region.boss = load(ENEMY_DIR + "boss_tower.tres")
	region.boss_arcanum = load(ARCANA_DIR + "arcanum_tower.tres")
	region.starting_arcanum = load(ARCANA_DIR + "arcanum_death.tres")
	ResourceSaver.save(region, REGION_DIR + "region_01.tres")

func _arcanum(name_key: String, aspect: int, mult: float) -> ArcanumData:
	var arc := ArcanumData.new()
	arc.name_key = name_key
	arc.effect = ArcanumData.Effect.MULT_IF_ASPECT
	arc.effect_aspect = aspect
	arc.effect_mult = mult
	return arc

func _enemy(name_key: String, hp: int, intents: Array, reward: int, is_boss: bool, rule: int, rule_key: String) -> EnemyData:
	var e := EnemyData.new()
	e.name_key = name_key
	e.max_hp = hp
	e.intents = PackedInt32Array(intents)
	e.reward_rtec = reward
	e.is_boss = is_boss
	e.rule = rule
	e.rule_key = rule_key
	return e

# ---- specs ----

func _starter() -> Array:
	return [
		[7, A.DEATH, KW.GNICIE, 3], [7, A.DEATH, KW.NONE, 0], [9, A.DEATH, KW.GNICIE, 4],
		[4, A.DEATH, KW.NONE, 0], [14, A.DEATH, KW.GNICIE, 5], [2, A.DEATH, KW.NONE, 0],
		[7, A.CHAOS, KW.NONE, 0], [5, A.CHAOS, KW.FURIA, 0], [9, A.CHAOS, KW.FURIA, 0],
		[12, A.CHAOS, KW.SPALENIE, 6],
		[7, A.LIFE, KW.OSLONA, 6], [3, A.LIFE, KW.NONE, 0], [14, A.LIFE, KW.OSLONA, 8],
		[6, A.LIFE, KW.OPATRZNOSC, 5],
		[7, A.MIND, KW.ECHO, 4], [8, A.NATURE, KW.BUJNOSC, 20],
	]

func _pool() -> Array:
	# Interleaved by Aspect so any 3 consecutive offers show variety, not three of one colour.
	return [
		[10, A.DEATH, KW.ZNIWO, 1], [6, A.CHAOS, KW.SPALENIE, 8], [5, A.LIFE, KW.OSLONA, 7],
		[11, A.MIND, KW.ECHO, 6], [7, A.NATURE, KW.BUJNOSC, 25], [8, A.DEATH, KW.GNICIE, 4],
		[10, A.CHAOS, KW.FURIA, 0], [9, A.LIFE, KW.OPATRZNOSC, 6], [13, A.MIND, KW.ECHO, 8],
		[10, A.NATURE, KW.BUJNOSC, 30], [13, A.DEATH, KW.ZNIWO, 2], [6, A.CHAOS, KW.SPALENIE, 10],
	]
