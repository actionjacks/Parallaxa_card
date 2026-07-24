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
	# Starting pool: 5 DISTINCT playstyles, each wearing its real RWS card (Fool's Journey draft).
	# [name_key, effect, aspect, mult, value, art, file]
	var E := ArcanumData.Effect
	var pool_specs := [
		["ARCANUM_SMIERCI", E.MULT_IF_ASPECT, A.DEATH, 1.5, 0, "13_death", "arcanum_death"],
		["ARCANUM_SLONCA", E.HEAL_ON_PLAY, A.LIFE, 1.0, 3, "19_sun", "arcanum_sun"],
		["ARCANUM_KAPLANKI", E.EXTRA_DISCARD, A.MIND, 1.0, 1, "02_high_priestess", "arcanum_priestess"],
		["ARCANUM_DIABLA", E.PACT_MULT, A.CHAOS, 1.35, 2, "15_devil", "arcanum_devil"],
		["ARCANUM_CESARZOWEJ", E.BLOCK_ON_PLAY, A.NATURE, 1.0, 4, "03_empress", "arcanum_empress"],
	]
	var pool: Array[ArcanumData] = []
	for s in pool_specs:
		var arc := ArcanumData.new()
		arc.name_key = s[0]
		arc.effect = s[1]
		arc.effect_aspect = s[2]
		arc.effect_mult = s[3]
		arc.effect_value = s[4]
		arc.art = load("res://assets/cards/arcana/%s.jpg" % s[5])
		ResourceSaver.save(arc, ARCANA_DIR + "%s.tres" % s[6])
		pool.append(load(ARCANA_DIR + "%s.tres" % s[6]))
	var tower_arc := _arcanum("ARCANUM_WIEZA", A.CHAOS, 1.4)
	tower_arc.art = load("res://assets/cards/arcana/16_tower.jpg")
	ResourceSaver.save(tower_arc, ARCANA_DIR + "arcanum_tower.tres")

	# HP tuned so a strong opening play does not one-shot: fights last ~2-3 turns, the boss ~4-5,
	# so enemy intents, block, heal, DoT stacking and the Tower rule all actually come into play.
	# NOTE(balance): the starter deck front-loads one big Death flush (~440) then falls off to weak
	# singletons, and the Death Arcanum makes that flush dominant. HP is tuned so fights end in ~2 turns
	# (enemy survives the opener, so intents/attacks are seen) without a long grind. Real tuning is a
	# gameplay pass -- likely: reward sustained plays, tone down the flush, or add rest/heal between fights.
	# Node pools: each map slot rolls one of two enemies with a DIFFERENT attack rhythm, so the
	# fights themselves vary run to run (steady vs spiky vs burst-with-rest patterns).
	var a := _enemy("ENEMY_KULTYSTA", 340, [8, 10, 6], 5, false, EnemyData.Rule.NONE, "", 2)
	ResourceSaver.save(a, ENEMY_DIR + "enemy_a.tres")
	var a2 := _enemy("ENEMY_WIEDZMA", 310, [13, 3, 13], 5, false, EnemyData.Rule.NONE, "", 2)
	ResourceSaver.save(a2, ENEMY_DIR + "enemy_a2.tres")
	var b := _enemy("ENEMY_CIEN", 400, [9, 12, 7], 6, false, EnemyData.Rule.NONE, "", 2)
	ResourceSaver.save(b, ENEMY_DIR + "enemy_b.tres")
	var b2 := _enemy("ENEMY_GOLEM", 450, [16, 0, 12], 6, false, EnemyData.Rule.NONE, "", 3)
	ResourceSaver.save(b2, ENEMY_DIR + "enemy_b2.tres")
	var boss := _enemy("ENEMY_WIEZA", 470, [13, 17, 11], 12, true, EnemyData.Rule.TOWER_IGNORES_BLOCK, "RULE_TOWER", 3)
	boss.art = load("res://assets/cards/arcana/16_tower.jpg")
	ResourceSaver.save(boss, ENEMY_DIR + "boss_tower.tres")

	var region := RegionData.new()
	region.name_key = "REGION_01"
	var fights: Array[EnemyData] = []
	fights.append(load(ENEMY_DIR + "enemy_a.tres"))
	fights.append(load(ENEMY_DIR + "enemy_b.tres"))
	region.fights = fights
	var p1: Array[EnemyData] = []
	p1.append(load(ENEMY_DIR + "enemy_a.tres"))
	p1.append(load(ENEMY_DIR + "enemy_a2.tres"))
	region.fight_pool_1 = p1
	var p2: Array[EnemyData] = []
	p2.append(load(ENEMY_DIR + "enemy_b.tres"))
	p2.append(load(ENEMY_DIR + "enemy_b2.tres"))
	region.fight_pool_2 = p2
	region.boss = load(ENEMY_DIR + "boss_tower.tres")
	region.boss_arcanum = load(ARCANA_DIR + "arcanum_tower.tres")
	region.starting_pool = pool
	ResourceSaver.save(region, REGION_DIR + "region_01.tres")

func _arcanum(name_key: String, aspect: int, mult: float) -> ArcanumData:
	var arc := ArcanumData.new()
	arc.name_key = name_key
	arc.effect = ArcanumData.Effect.MULT_IF_ASPECT
	arc.effect_aspect = aspect
	arc.effect_mult = mult
	return arc

func _enemy(name_key: String, hp: int, intents: Array, reward: int, is_boss: bool, rule: int, rule_key: String, enrage: int = 0) -> EnemyData:
	var e := EnemyData.new()
	e.name_key = name_key
	e.max_hp = hp
	e.intents = PackedInt32Array(intents)
	e.reward_rtec = reward
	e.is_boss = is_boss
	e.rule = rule
	e.rule_key = rule_key
	e.enrage_step = enrage
	return e

# ---- specs ----

## Balanced starter (5 Death / 4 Chaos / 3 Life / 2 Mind / 2 Nature). Death still leans (theme +
## Death Arcanum), but no longer auto-flushes every hand -> the player picks pairs / trips / mixed
## hands, and drafts toward a colour. Four 7s (one per aspect) enable cross-colour sets.
func _starter() -> Array:
	return [
		[7, A.DEATH, KW.GNICIE, 3], [7, A.DEATH, KW.NONE, 0], [9, A.DEATH, KW.GNICIE, 4],
		[14, A.DEATH, KW.GNICIE, 5], [2, A.DEATH, KW.NONE, 0],
		[7, A.CHAOS, KW.NONE, 0], [5, A.CHAOS, KW.FURIA, 0], [9, A.CHAOS, KW.FURIA, 0],
		[12, A.CHAOS, KW.SPALENIE, 6],
		[7, A.LIFE, KW.OSLONA, 6], [14, A.LIFE, KW.OSLONA, 8], [6, A.LIFE, KW.OPATRZNOSC, 5],
		[7, A.MIND, KW.ECHO, 4], [10, A.MIND, KW.ECHO, 6],
		[8, A.NATURE, KW.BUJNOSC, 20], [6, A.NATURE, KW.NONE, 0],
	]

## 28-card reward/shop pool: every keyword across aspects and ranks (incl. courts) plus plain
## cards for pair/straight fishing -- wide enough that consecutive runs see different offers.
func _pool() -> Array:
	return [
		[10, A.DEATH, KW.ZNIWO, 1], [6, A.CHAOS, KW.SPALENIE, 8], [5, A.LIFE, KW.OSLONA, 7],
		[11, A.MIND, KW.ECHO, 6], [7, A.NATURE, KW.BUJNOSC, 25], [8, A.DEATH, KW.GNICIE, 4],
		[10, A.CHAOS, KW.FURIA, 0], [9, A.LIFE, KW.OPATRZNOSC, 6], [13, A.MIND, KW.ECHO, 8],
		[10, A.NATURE, KW.BUJNOSC, 30], [13, A.DEATH, KW.ZNIWO, 2], [6, A.CHAOS, KW.SPALENIE, 10],
		[11, A.DEATH, KW.GNICIE, 3], [13, A.CHAOS, KW.FURIA, 0], [12, A.LIFE, KW.OSLONA, 9],
		[8, A.MIND, KW.ECHO, 5], [13, A.NATURE, KW.BUJNOSC, 35], [12, A.DEATH, KW.GNICIE, 5],
		[8, A.CHAOS, KW.SPALENIE, 12], [10, A.LIFE, KW.OPATRZNOSC, 8], [14, A.MIND, KW.ECHO, 10],
		[14, A.NATURE, KW.BUJNOSC, 40], [5, A.DEATH, KW.NONE, 0], [3, A.CHAOS, KW.NONE, 0],
		[4, A.LIFE, KW.NONE, 0], [6, A.MIND, KW.NONE, 0], [9, A.NATURE, KW.NONE, 0],
		[4, A.DEATH, KW.ZNIWO, 1],
	]
