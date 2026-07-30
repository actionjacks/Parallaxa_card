extends SceneTree
## Content generator: writes authorable .tres for cards, decks, enemies, arcana and the regions.
## Run (headless): godot --headless -s res://tools/gen/gen_content.gd
## Re-run to regenerate; outputs are editor-first resources you can then tweak by hand.
## NOTE: regenerating OVERWRITES hand-tweaks -- all balance numbers live HERE (specs in docs/specs/).

const A := Aspects.Id
const KW := CardData.Keyword
const R := CardData.Rarity
const CARD_DIR := "res://data/cards/"
const DECK_DIR := "res://data/decks/"
const ENEMY_DIR := "res://data/combat/"
const ARCANA_DIR := "res://data/arcana/"
const REGION_DIR := "res://data/regions/"
const OMEN_DIR := "res://data/omens/"
const MINOR := "res://assets/cards/minor/"
const MAJOR := "res://assets/cards/arcana/"

func _initialize() -> void:
	for d in [CARD_DIR, DECK_DIR, ENEMY_DIR, ARCANA_DIR, REGION_DIR, OMEN_DIR]:
		if not DirAccess.dir_exists_absolute(d):
			DirAccess.make_dir_recursive_absolute(d)
	var starter := _make(_starter(), "s")
	var pool := _make(_pool(), "p")
	_deck("starter", "DECK_STARTER", starter)
	_deck("reward_pool", "DECK_REWARD_POOL", pool)
	_deck("starter_reaper", "DECK_REAPER", _make(_reaper(), "r"))
	_deck("starter_gardener", "DECK_GARDENER", _make(_gardener(), "g"))
	_deck("starter_oracle", "DECK_ORACLE", _make(_oracle(), "o"))
	_region()
	_biomes()
	_omens()
	print("gen_content: %d starter + %d pool cards, 3 alt decks, enemies + arcana + 4 regions written"
		% [starter.size(), pool.size()])
	quit(0)

# ---- cards / decks ----

func _make(specs: Array, prefix: String) -> Array:
	var out: Array = []
	for i in specs.size():
		var s: Array = specs[i]
		var c := CardData.new()
		c.rank = s[0]
		c.aspect = s[1] as Aspects.Id
		c.keyword = s[2] as CardData.Keyword
		c.keyword_value = s[3]
		c.rarity = (s[4] if s.size() > 4 else R.COMMON) as CardData.Rarity
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

# ---- enemies / arcana / regions ----

var _opening_pool: Array[ArcanumData] = []   ## the run-opening draft pool, shared by every road

func _region() -> void:
	# Starting pool: 6 DISTINCT playstyles, each wearing its real RWS card (Fool's Journey draft).
	# [name_key, effect, aspect, mult, value, art, file]  + reversed numbers applied after.
	var E := ArcanumData.Effect
	var P := ArcanumData.Price
	var pool_specs := [
		["ARCANUM_SMIERCI", E.MULT_IF_ASPECT, A.DEATH, 1.5, 0, "13_death", "arcanum_death"],
		["ARCANUM_SLONCA", E.HEAL_ON_PLAY, A.LIFE, 1.0, 3, "19_sun", "arcanum_sun"],
		["ARCANUM_KAPLANKI", E.EXTRA_DISCARD, A.MIND, 1.0, 1, "02_high_priestess", "arcanum_priestess"],
		["ARCANUM_DIABLA", E.PACT_MULT, A.CHAOS, 1.35, 2, "15_devil", "arcanum_devil"],
		["ARCANUM_CESARZOWEJ", E.BLOCK_ON_PLAY, A.NATURE, 1.0, 4, "03_empress", "arcanum_empress"],
		# The Magician: the scaling bet -- weak alone, monstrous once boss Arcana accumulate.
		["ARCANUM_MAGA", E.MAGNIFY, A.MIND, 1.15, 0, "01_magician", "arcanum_magician"],
	]
	# Reversed variants (stronger + a visible price): [file, rev_mult, rev_value, price, price_value]
	var reversed_specs := {
		"arcanum_death": [2.2, -1, P.MAX_HP, 8],
		"arcanum_sun": [0.0, 7, P.RTEC_TAX, 2],
		"arcanum_priestess": [0.0, 3, P.SELF_CURSE, 2],
		"arcanum_devil": [1.75, 5, P.NONE, 0],
		"arcanum_empress": [0.0, 9, P.MAX_HP, 6],
		"arcanum_magician": [1.25, -1, P.MAX_HP, 12],
		"arcanum_tower": [2.0, -1, P.SELF_CURSE, 3],
		"arcanum_devil_boss": [1.6, 3, P.NONE, 0],
		"arcanum_moon": [0.0, 2, P.RTEC_TAX, 2],
		"arcanum_world": [1.5, -1, P.MAX_HP, 10],
	}
	var pool: Array[ArcanumData] = []
	for s in pool_specs:
		var arc := ArcanumData.new()
		arc.name_key = s[0]
		arc.effect = s[1] as ArcanumData.Effect
		arc.effect_aspect = s[2] as Aspects.Id
		arc.effect_mult = s[3]
		arc.effect_value = s[4]
		arc.art = load("%s%s.jpg" % [MAJOR, s[5]])
		_apply_reversed(arc, reversed_specs.get(s[6], null))
		ResourceSaver.save(arc, ARCANA_DIR + "%s.tres" % s[6])
		pool.append(load(ARCANA_DIR + "%s.tres" % s[6]))
	_opening_pool = pool
	# Boss-claimed relics (Fool's Journey: beat the card, wear the card).
	var tower_arc := _arcanum("ARCANUM_WIEZA", A.CHAOS, 1.4)
	tower_arc.art = load(MAJOR + "16_tower.jpg")
	_apply_reversed(tower_arc, reversed_specs["arcanum_tower"])
	ResourceSaver.save(tower_arc, ARCANA_DIR + "arcanum_tower.tres")
	var devil_boss := ArcanumData.new()
	devil_boss.name_key = "ARCANUM_DIABLA_BOSS"
	devil_boss.effect = E.PACT_MULT
	devil_boss.effect_mult = 1.25
	devil_boss.effect_value = 1
	devil_boss.art = load(MAJOR + "15_devil.jpg")
	_apply_reversed(devil_boss, reversed_specs["arcanum_devil_boss"])
	ResourceSaver.save(devil_boss, ARCANA_DIR + "arcanum_devil_boss.tres")
	var moon_arc := ArcanumData.new()
	moon_arc.name_key = "ARCANUM_KSIEZYCA"
	moon_arc.effect = E.EXTRA_DISCARD
	moon_arc.effect_value = 1
	moon_arc.art = load(MAJOR + "18_moon.jpg")
	_apply_reversed(moon_arc, reversed_specs["arcanum_moon"])
	ResourceSaver.save(moon_arc, ARCANA_DIR + "arcanum_moon.tres")
	var world_arc := ArcanumData.new()
	world_arc.name_key = "ARCANUM_SWIATA"
	world_arc.effect = E.PACT_MULT
	world_arc.effect_mult = 1.15
	world_arc.effect_value = 0   # the completed circle: pure power, no price
	world_arc.art = load(MAJOR + "21_world.jpg")
	_apply_reversed(world_arc, reversed_specs["arcanum_world"])
	ResourceSaver.save(world_arc, ARCANA_DIR + "arcanum_world.tres")
	# Meta-widening arcana: bought with Sol into the boss offer pool / unlocked by achievements
	# into the opening draft (profile.gd wires them; existing Effect values only).
	_save_arcanum_simple("arcanum_emperor", "ARCANUM_CESARZA", E.BLOCK_ON_PLAY, A.LIFE, 1.0, 6, "04_emperor",
		[0.0, 12, P.MAX_HP, 6])
	_save_arcanum_simple("arcanum_chariot", "ARCANUM_RYDWANU", E.MULT_IF_ASPECT, A.MIND, 1.4, 0, "07_chariot",
		[2.0, -1, P.SELF_CURSE, 2])
	_save_arcanum_simple("arcanum_strength", "ARCANUM_SILY", E.MULT_IF_ASPECT, A.LIFE, 1.5, 0, "08_strength",
		[2.2, -1, P.MAX_HP, 8])
	_save_arcanum_simple("arcanum_hermit", "ARCANUM_PUSTELNIKA", E.EXTRA_DISCARD, A.MIND, 1.0, 2, "09_hermit",
		[0.0, 3, P.SELF_CURSE, 2])
	# Boss-rotation relics (Fool's Journey wave C -- beat the card, wear the card).
	_save_arcanum_simple("arcanum_hanged", "ARCANUM_WISIELCA", E.EXTRA_DISCARD, A.MIND, 1.0, 2, "12_hanged_man",
		[0.0, 3, P.SELF_CURSE, 2])
	_save_arcanum_simple("arcanum_justice", "ARCANUM_SPRAWIEDLIWOSCI", E.BLOCK_ON_PLAY, A.LIFE, 1.0, 5, "11_justice",
		[0.0, 10, P.MAX_HP, 6])
	_save_arcanum_simple("arcanum_judgement", "ARCANUM_SADU", E.PACT_MULT, A.CHAOS, 1.3, 2, "20_judgement",
		[1.6, 3, P.NONE, 0])
	_save_arcanum_simple("arcanum_star", "ARCANUM_GWIAZDY", E.HEAL_ON_PLAY, A.LIFE, 1.0, 4, "17_star",
		[0.0, 8, P.RTEC_TAX, 2])

	# Enemy pressure (docs/specs/spec_difficulty.md par.3): intended fight length 5-6 plays; the
	# per-turn enrage past the first cycle is the anti-stall clock. Every regular enemy IS a Minor
	# Arcana court card (suit law: cups=LIFE swords=MIND wands=CHAOS pents=DEATH; NATURE wears the
	# suit's Ten). Region rank ladder: Pages -> Knights -> Queens/Kings.
	var a := _enemy("ENEMY_KULTYSTA", 520, [10, 13, 8], 5, false, EnemyData.Rule.NONE, "", 2)
	a.art = load(MINOR + "pents_11.jpg")
	a.figure = _figure_for(MINOR + "pents_11.jpg")
	ResourceSaver.save(a, ENEMY_DIR + "enemy_a.tres")
	var a2 := _enemy("ENEMY_WIEDZMA", 480, [16, 4, 16], 5, false, EnemyData.Rule.NONE, "", 2)
	a2.art = load(MINOR + "wands_11.jpg")
	a2.figure = _figure_for(MINOR + "wands_11.jpg")
	ResourceSaver.save(a2, ENEMY_DIR + "enemy_a2.tres")
	var b := _enemy("ENEMY_CIEN", 460, [12, 15, 9], 6, false, EnemyData.Rule.NONE, "", 2)
	b.art = load(MINOR + "swords_11.jpg")
	b.figure = _figure_for(MINOR + "swords_11.jpg")
	ResourceSaver.save(b, ENEMY_DIR + "enemy_b.tres")
	var b2 := _enemy("ENEMY_GOLEM", 500, [20, 0, 15], 6, false, EnemyData.Rule.NONE, "", 3)
	b2.art = load(MINOR + "pents_10.jpg")
	b2.figure = _figure_for(MINOR + "pents_10.jpg")
	ResourceSaver.save(b2, ENEMY_DIR + "enemy_b2.tres")
	# Pool wideners (runs 1-3 must not clone their foe lineups): a third candidate per node.
	var a3 := _enemy("ENEMY_NOWICJUSZ", 500, [9, 14, 9], 5, false, EnemyData.Rule.NONE, "", 2)
	a3.art = load(MINOR + "cups_11.jpg")
	a3.figure = _figure_for(MINOR + "cups_11.jpg")
	ResourceSaver.save(a3, ENEMY_DIR + "enemy_a3.tres")
	var b3 := _enemy("ENEMY_PRZEBITY", 480, [18, 2, 12], 6, false, EnemyData.Rule.NONE, "", 3)
	b3.art = load(MINOR + "swords_10.jpg")
	b3.figure = _figure_for(MINOR + "swords_10.jpg")
	ResourceSaver.save(b3, ENEMY_DIR + "enemy_b3.tres")
	var boss := _enemy("ENEMY_WIEZA", 600, [15, 20, 13], 12, true, EnemyData.Rule.TOWER_IGNORES_BLOCK, "RULE_TOWER", 3)
	boss.art = load(MAJOR + "16_tower.jpg")
	boss.figure = _figure_for(MAJOR + "16_tower.jpg")
	boss.arcanum = load(ARCANA_DIR + "arcanum_tower.tres")
	ResourceSaver.save(boss, ENEMY_DIR + "boss_tower.tres")
	_save_boss("boss_chariot", "ENEMY_RYDWAN", 560, [9, 12, 7], 12,
		EnemyData.Rule.CHARIOT_DOUBLE, "RULE_CHARIOT", 3, "07_chariot", "arcanum_chariot")
	_save_boss("boss_strength", "ENEMY_SILA", 780, [12, 15, 10], 12,
		EnemyData.Rule.STRENGTH_RESIST, "RULE_STRENGTH", 3, "08_strength", "arcanum_strength")
	_save_elite("enemy_elite_r1", "ENEMY_ELITE_R1", 680, [22, 0, 16], 12, 5, "pents_13")

	var region := RegionData.new()
	region.name_key = "REGION_01"
	var fights: Array[EnemyData] = []
	fights.append(load(ENEMY_DIR + "enemy_a.tres"))
	fights.append(load(ENEMY_DIR + "enemy_b.tres"))
	region.fights = fights
	var p1: Array[EnemyData] = []
	for f1 in ["enemy_a", "enemy_a2", "enemy_a3"]:
		p1.append(load(ENEMY_DIR + f1 + ".tres"))
	region.fight_pool_1 = p1
	var p2: Array[EnemyData] = []
	for f2 in ["enemy_b", "enemy_b2", "enemy_b3"]:
		p2.append(load(ENEMY_DIR + f2 + ".tres"))
	region.fight_pool_2 = p2
	region.boss = load(ENEMY_DIR + "boss_tower.tres")
	region.boss_arcanum = load(ARCANA_DIR + "arcanum_tower.tres")
	var bp1: Array[EnemyData] = []
	for bf in ["boss_tower", "boss_chariot", "boss_strength"]:
		bp1.append(load(ENEMY_DIR + bf + ".tres"))
	region.boss_pool = bp1
	region.starting_pool = pool
	region.accent = Color(0.604, 0.561, 0.518)   # ash
	region.elite = load(ENEMY_DIR + "enemy_elite_r1.tres")
	ResourceSaver.save(region, REGION_DIR + "region_01.tres")

	# ---- Region II "Zgliszcza": Knights, boss DEVIL (blood-tax rule) ----
	_save_enemy("enemy_r2a", "ENEMY_KAPLAN", 720, [14, 17, 10], 7, 3, "cups_12")
	_save_enemy("enemy_r2a2", "ENEMY_UPIOR", 680, [21, 6, 21], 7, 3, "swords_12")
	_save_enemy("enemy_r2b", "ENEMY_RYCERZ", 840, [16, 16, 16], 7, 3, "pents_12")
	_save_enemy("enemy_r2b2", "ENEMY_CHIMERA", 780, [24, 0, 19], 7, 4, "wands_10")
	var devil := _enemy("ENEMY_DIABEL", 780, [16, 20, 14], 14, true, EnemyData.Rule.DEVIL_BLOOD_TAX, "RULE_DEVIL", 4)
	devil.art = load(MAJOR + "15_devil.jpg")
	devil.figure = _figure_for(MAJOR + "15_devil.jpg")
	devil.arcanum = load(ARCANA_DIR + "arcanum_devil_boss.tres")
	ResourceSaver.save(devil, ENEMY_DIR + "boss_devil.tres")
	_save_boss("boss_hanged", "ENEMY_WISIELEC", 760, [17, 21, 14], 14,
		EnemyData.Rule.HANGED_CAP, "RULE_HANGED", 4, "12_hanged_man", "arcanum_hanged")
	_save_boss("boss_justice", "ENEMY_SPRAWIEDLIWOSC", 740, [15, 19, 12], 14,
		EnemyData.Rule.JUSTICE_RIPOSTE, "RULE_JUSTICE", 4, "11_justice", "arcanum_justice")
	_save_elite("enemy_elite_r2", "ENEMY_ELITE_R2", 870, [18, 18, 18], 14, 5, "wands_13")
	_save_region("region_02", "REGION_02", ["enemy_r2a", "enemy_r2a2"], ["enemy_r2b", "enemy_r2b2"],
		"boss_devil", "arcanum_devil_boss", Color(0.851, 0.373, 0.231), "enemy_elite_r2",
		["boss_devil", "boss_hanged", "boss_justice"])

	# ---- Region III "Szczyt": Queens and Kings, boss MOON (cleanse + self-mend) ----
	_save_enemy("enemy_r3a", "ENEMY_STRAZNIK", 1040, [20, 23, 15], 9, 4, "cups_13")
	_save_enemy("enemy_r3a2", "ENEMY_WIDMO", 990, [27, 10, 27], 9, 4, "swords_13")
	_save_enemy("enemy_r3b", "ENEMY_TYTAN", 1150, [22, 22, 22], 9, 4, "pents_14")
	_save_enemy("enemy_r3b2", "ENEMY_HERALD", 1090, [30, 0, 25], 9, 5, "wands_14")
	var moon := _enemy("ENEMY_KSIEZYC", 980, [20, 25, 17], 16, true, EnemyData.Rule.MOON_CLEANSE, "RULE_MOON", 5)
	moon.art = load(MAJOR + "18_moon.jpg")
	moon.figure = _figure_for(MAJOR + "18_moon.jpg")
	moon.arcanum = load(ARCANA_DIR + "arcanum_moon.tres")
	ResourceSaver.save(moon, ENEMY_DIR + "boss_moon.tres")
	_save_boss("boss_judgement", "ENEMY_SAD", 950, [21, 26, 17], 16,
		EnemyData.Rule.JUDGEMENT_FRAIL, "RULE_JUDGEMENT", 5, "20_judgement", "arcanum_judgement")
	_save_boss("boss_star", "ENEMY_GWIAZDA", 1000, [19, 24, 16], 16,
		EnemyData.Rule.STAR_REGEN, "RULE_STAR", 5, "17_star", "arcanum_star")
	_save_elite("enemy_elite_r3", "ENEMY_ELITE_R3", 1200, [25, 25, 25], 18, 6, "swords_14")
	_save_region("region_03", "REGION_03", ["enemy_r3a", "enemy_r3a2"], ["enemy_r3b", "enemy_r3b2"],
		"boss_moon", "arcanum_moon", Color(0.498, 0.706, 0.831), "enemy_elite_r3",
		["boss_moon", "boss_judgement", "boss_star"])

	# ---- Region IV "Swiat": the finale -- a single duel against THE WORLD (all rules at once) ----
	var world := _enemy("ENEMY_SWIAT", 1300, [26, 30, 22], 20, true, EnemyData.Rule.WORLD_ALL, "RULE_WORLD", 6)
	world.art = load(MAJOR + "21_world.jpg")
	world.figure = _figure_for(MAJOR + "21_world.jpg")
	world.arcanum = load(ARCANA_DIR + "arcanum_world.tres")
	ResourceSaver.save(world, ENEMY_DIR + "boss_world.tres")
	_save_region("region_04", "REGION_04", [], [], "boss_world", "arcanum_world",
		Color(0.910, 0.761, 0.408), "", ["boss_world"])

func _apply_reversed(arc: ArcanumData, spec) -> void:
	if spec == null:
		return
	arc.reversed_mult = spec[0]
	arc.reversed_value = spec[1]
	arc.price = spec[2] as ArcanumData.Price
	arc.price_value = spec[3]

func _save_arcanum_simple(file: String, name_key: String, effect: ArcanumData.Effect, aspect: Aspects.Id, mult: float, value: int, art: String, rev = null) -> void:
	var arc := ArcanumData.new()
	arc.name_key = name_key
	arc.effect = effect
	arc.effect_aspect = aspect
	arc.effect_mult = mult
	arc.effect_value = value
	arc.art = load("%s%s.jpg" % [MAJOR, art])
	_apply_reversed(arc, rev)
	ResourceSaver.save(arc, ARCANA_DIR + file + ".tres")

func _save_enemy(file: String, name_key: String, hp: int, intents: Array, reward: int, enrage: int, art: String = "") -> void:
	var e := _enemy(name_key, hp, intents, reward, false, EnemyData.Rule.NONE, "", enrage)
	if art != "":
		e.art = load(MINOR + art + ".jpg")
		e.figure = _figure_for(MINOR + art + ".jpg")
	ResourceSaver.save(e, ENEMY_DIR + file + ".tres")

## A rotation boss: a Major Arcana with a field rule and its claimable relic.
func _save_boss(file: String, name_key: String, hp: int, intents: Array, reward: int, rule: EnemyData.Rule, rule_key: String, enrage: int, art: String, arc_file: String) -> void:
	var e := _enemy(name_key, hp, intents, reward, true, rule, rule_key, enrage)
	e.art = load("%s%s.jpg" % [MAJOR, art])
	e.figure = _figure_for("%s%s.jpg" % [MAJOR, art])
	e.arcanum = load(ARCANA_DIR + arc_file + ".tres")
	ResourceSaver.save(e, ENEMY_DIR + file + ".tres")

## Elite: a REVERSED court card guarding better loot (map fork). Art renders flipped in combat.
func _save_elite(file: String, name_key: String, hp: int, intents: Array, reward: int, enrage: int, art: String) -> void:
	var e := _enemy(name_key, hp, intents, reward, false, EnemyData.Rule.NONE, "", enrage)
	e.is_elite = true
	e.art = load(MINOR + art + ".jpg")
	e.figure = _figure_for(MINOR + art + ".jpg")
	ResourceSaver.save(e, ENEMY_DIR + file + ".tres")

# ---- BIOMES: five colours, five laws, five seals (+ the hidden sixth) ----

## Each Aspect owns a biome, and each biome owns a LAW that changes how every duel inside it
## scores. The colour is not a tint on the map: it is what the place DOES to your hand, which is
## why beating one is worth a permanent seal. Enemies are the court of that colour's suit
## (cups=LIFE swords=MIND wands=CHAOS pents=DEATH; NATURE has no historical suit and wears the
## Tens), the elite is its reversed Nine, and the bosses are the Major Arcana of that philosophy.
func _biomes() -> void:
	var L := RegionData.Law
	# [aspect, id, name_key, suit, accent, law, law_key, base_hp, intents, bosses, boss_arc, elite_art]
	var specs := [
		[A.LIFE, "biome_life", "BIOME_LIFE", "cups", Color(0.82, 0.74, 0.50),
			L.LIFE_TITHE, "LAW_LIFE", 430, [[9, 9, 9], [11, 8, 11], [10, 10, 10], [12, 12, 6]],
			["boss_strength", "boss_star"], "arcanum_strength"],
		[A.MIND, "biome_mind", "BIOME_MIND", "swords", Color(0.43, 0.62, 0.80),
			L.MIND_ARCHIVE, "LAW_MIND", 360, [[17, 3, 17], [19, 0, 19], [16, 6, 16], [21, 2, 21]],
			["boss_hanged", "boss_justice"], "arcanum_hanged"],
		[A.DEATH, "biome_death", "BIOME_DEATH", "pents", Color(0.52, 0.40, 0.68),
			L.DEATH_HARVEST, "LAW_DEATH", 415, [[12, 13, 11], [13, 13, 13], [14, 12, 12], [15, 14, 13]],
			["boss_moon", "boss_judgement"], "arcanum_moon"],
		[A.CHAOS, "biome_chaos", "BIOME_CHAOS", "wands", Color(0.80, 0.38, 0.30),
			L.CHAOS_KINDLING, "LAW_CHAOS", 375, [[20, 0, 14], [22, 0, 15], [24, 0, 16], [26, 0, 18]],
			["boss_tower", "boss_devil", "boss_chariot"], "arcanum_tower"],
		[A.NATURE, "biome_nature", "BIOME_NATURE", "nature", Color(0.42, 0.66, 0.40),
			L.NATURE_OVERGROWTH, "LAW_NATURE", 410, [[8, 11, 14], [7, 12, 15], [9, 12, 16], [10, 13, 16]],
			["boss_empress", "boss_wheel"], "arcanum_empress"],
	]
	# The Empress and the Wheel had no boss card yet -- Nature's philosophy needed its own Arcana.
	_save_arcanum_simple("arcanum_wheel", "ARCANUM_KOLA", ArcanumData.Effect.MULT_IF_ASPECT,
		A.NATURE, 1.45, 0, "10_wheel_of_fortune", [2.1, -1, ArcanumData.Price.SELF_CURSE, 2])
	_save_boss("boss_empress", "ENEMY_CESARZOWA", 820, [14, 18, 11], 13,
		EnemyData.Rule.NONE, "RULE_EMPRESS", 4, "03_empress", "arcanum_empress")
	_save_boss("boss_wheel", "ENEMY_KOLO", 800, [16, 16, 16], 13,
		EnemyData.Rule.NONE, "RULE_WHEEL", 5, "10_wheel_of_fortune", "arcanum_wheel")

	for spec in specs:
		var aspect: int = spec[0]
		var id: String = spec[1]
		var suit: String = spec[3]
		var hp: int = spec[7]
		var intents: Array = spec[8]
		# four regulars = the suit's court (Page, Knight, Queen, King), rising
		var ranks := [11, 12, 13, 14] if suit != "nature" else [10, 10, 10, 10]
		var arts := ["cups", "swords", "wands", "pents"] if suit == "nature" else [suit, suit, suit, suit]
		var files: Array = []
		for i in 4:
			var e := _enemy("%s_%d" % [spec[2], i + 1], hp + i * 60, intents[i], 5 + i / 2,
				false, EnemyData.Rule.NONE, "", 2 + i / 2)
			e.art = load("%s%s_%02d.jpg" % [MINOR, arts[i], ranks[i]])
			e.figure = _figure_for("%s%s_%02d.jpg" % [MINOR, arts[i], ranks[i]])
			var f: String = "%s_%d" % [id, i + 1]
			ResourceSaver.save(e, ENEMY_DIR + f + ".tres")
			files.append(f)
		# the elite: the colour's reversed Nine (is_elite already renders it upside down)
		var el := _enemy("%s_E" % spec[2], hp + 140, intents[3], 12, false, EnemyData.Rule.NONE, "", 4)
		el.art = load("%s%s_09.jpg" % [MINOR, suit if suit != "nature" else "nature"])
		el.figure = _figure_for("%s%s_09.jpg" % [MINOR, suit if suit != "nature" else "nature"])
		el.is_elite = true
		ResourceSaver.save(el, ENEMY_DIR + id + "_elite.tres")
		_save_region(id, spec[2], [files[0], files[1]], [files[2], files[3]],
			spec[9][0], spec[10], spec[4], id + "_elite", spec[9],
			int(spec[5]), spec[6], aspect)
		# The run-opening draft belongs to every road, not just the legacy region_01, or a run
		# that starts in a biome would open with no Arcanum at all.
		var br: RegionData = load(REGION_DIR + id + ".tres")
		br.starting_pool = _opening_pool
		ResourceSaver.save(br, REGION_DIR + id + ".tres")

	# ---- THE SEALED BIOME: what answers when all five colours have been answered ----
	# Its enemies are the four Aces (the hand from the cloud: pure, uncoloured force) and its
	# boss is THE FOOL -- the card the player has been told they ARE since the first status bar.
	# Its law inverts the whole journey: after a run spent chasing ONE colour, it pays for all five.
	_save_arcanum_simple("arcanum_fool", "ARCANUM_GLUPCA", ArcanumData.Effect.MAGNIFY,
		A.MIND, 1.4, 0, "00_fool", null)
	var ace_specs := [["cups", 640, [10, 10, 10]], ["swords", 600, [13, 3, 13]],
		["wands", 580, [15, 0, 11]], ["pents", 620, [11, 11, 11]]]
	var ace_files: Array = []
	for i in ace_specs.size():
		var sp: Array = ace_specs[i]
		var ace := _enemy("ENEMY_ACE_%d" % (i + 1), sp[1], sp[2], 10, false, EnemyData.Rule.NONE, "", 1)
		ace.art = load("%s%s_01.jpg" % [MINOR, sp[0]])
		ace.figure = _figure_for("%s%s_01.jpg" % [MINOR, sp[0]])
		var af: String = "enemy_seal_%d" % (i + 1)
		ResourceSaver.save(ace, ENEMY_DIR + af + ".tres")
		ace_files.append(af)
	_save_boss("boss_fool", "ENEMY_GLUPIEC", 1300, [12, 12, 12], 40,
		EnemyData.Rule.NONE, "RULE_FOOL", 6, "00_fool", "arcanum_fool")
	_save_region("region_sealed", "BIOME_SEALED", [ace_files[0], ace_files[1]],
		[ace_files[2], ace_files[3]], "boss_fool", "arcanum_fool",
		Color(0.88, 0.88, 0.92), "", ["boss_fool"],
		int(L.SEAL_FIVE), "LAW_SEAL", -1, true)

func _save_region(file: String, name_key: String, pool1: Array, pool2: Array, boss_file: String, arc_file: String, accent: Color, elite_file: String, boss_pool_files: Array = [], law: int = 0, law_key: String = "", seal_aspect: int = -1, hidden: bool = false) -> void:
	var r := RegionData.new()
	r.name_key = name_key
	r.law = law as RegionData.Law
	r.law_key = law_key
	r.seal_aspect = seal_aspect
	r.hidden = hidden
	var p1: Array[EnemyData] = []
	for f in pool1:
		p1.append(load(ENEMY_DIR + f + ".tres"))
	r.fight_pool_1 = p1
	var p2: Array[EnemyData] = []
	for f in pool2:
		p2.append(load(ENEMY_DIR + f + ".tres"))
	r.fight_pool_2 = p2
	r.boss = load(ENEMY_DIR + boss_file + ".tres")
	r.boss_arcanum = load(ARCANA_DIR + arc_file + ".tres")
	r.accent = accent
	if elite_file != "":
		r.elite = load(ENEMY_DIR + elite_file + ".tres")
	var bp: Array[EnemyData] = []
	for bf in boss_pool_files:
		bp.append(load(ENEMY_DIR + bf + ".tres"))
	r.boss_pool = bp
	ResourceSaver.save(r, REGION_DIR + file + ".tres")

func _arcanum(name_key: String, aspect: Aspects.Id, mult: float) -> ArcanumData:
	var arc := ArcanumData.new()
	arc.name_key = name_key
	arc.effect = ArcanumData.Effect.MULT_IF_ASPECT
	arc.effect_aspect = aspect
	arc.effect_mult = mult
	return arc

## Every enemy's HP is stated at the OLD damage scale and scaled here, so one constant re-tunes
## the whole game when the deck's damage curve moves. The pentacle deck lifted the median play
## from 174 to 220 (measured, tools/dev/probe_deckmath.gd) and fights had shrunk to ~3 plays
## against a spec that wants 5-6, so HP is lifted by both factors at once.
const HP_SCALE := 1.65

## Attach the animated cut-out that belongs to a plate. Named after the plate, so an enemy
## wearing "pents_11.jpg" automatically fields the pents_11 figure.
func _figure_for(art_path: String) -> Texture2D:
	var base := art_path.get_file().get_basename()
	var p := "res://assets/foes/%s.png" % base
	return load(p) if ResourceLoader.exists(p) else null

func _enemy(name_key: String, hp: int, intents: Array, reward: int, is_boss: bool, rule: EnemyData.Rule, rule_key: String, enrage: int = 0) -> EnemyData:
	var e := EnemyData.new()
	e.name_key = name_key
	e.max_hp = int(round(hp * HP_SCALE))
	e.intents = PackedInt32Array(intents)
	e.reward_rtec = reward
	e.is_boss = is_boss
	e.rule = rule
	e.rule_key = rule_key
	e.enrage_step = enrage
	return e

## Road omens as editor-authorable resources (effects resolve in run.gd by id).
## The last two are achievement rewards (meta widens: new omens join the road pool).
func _omens() -> void:
	var specs := [
		["star", "OMEN_STAR", "OMEN_STAR_DESC", "17_star", ""],
		["wheel", "OMEN_WHEEL", "OMEN_WHEEL_DESC", "10_wheel_of_fortune", ""],
		["hanged", "OMEN_HANGED", "OMEN_HANGED_DESC", "12_hanged_man", ""],
		["justice", "OMEN_JUSTICE", "OMEN_JUSTICE_DESC", "11_justice", ""],
		["temperance", "OMEN_TEMPERANCE", "OMEN_TEMPERANCE_DESC", "14_temperance", ""],
		["lovers", "OMEN_LOVERS", "OMEN_LOVERS_DESC", "06_lovers", "ACH_DEATH_FLUSH"],
		["sun", "OMEN_SUN", "OMEN_SUN_DESC", "19_sun", "ACH_MISER"],
	]
	for s in specs:
		var o := OmenData.new()
		o.id = s[0]
		o.name_key = s[1]
		o.desc_key = s[2]
		o.art = load("%s%s.jpg" % [MAJOR, s[3]])
		o.requires_achievement = s[4]
		ResourceSaver.save(o, OMEN_DIR + "omen_%s.tres" % s[0])

# ---- specs ----

## THE PENTACLE DECK: five Aspects x ranks 1..8 = 40 cards, every rank present in every colour.
##
## The 16-card deck this replaces could not produce the game it was printed on. Measured on the
## real engine (tools/dev/probe_deckmath.gd, 9000 plays): two pair was played 48% of the time and
## FOUR OF A KIND, STRAIGHT FLUSH, FIVE and MAGNUM OPUS came up 0.00% -- four of the eleven rungs
## of the hand ladder were unreachable content. Damage sat between 120 and 426 no matter what the
## player did, so no choice in the turn could change the outcome by much. Playtest verdict, exactly:
## "at best I could make pairs".
##
## The grid fixes the geometry: with a card of every rank in every colour, sets and straights are
## build-able and the ladder is climbable (measured: 2 pair 37%, full house 32%, four 4.8%, and a
## damage ceiling of 1920 instead of 474). Rank multiplicity is 5, not 4, which is deliberate:
## five of a kind is one card of EACH Aspect at the same rank -- the pentagram itself -- so the
## rarest set in the game is also the game's own symbol.
##
## MAGNUM OPUS stays impossible to be dealt (five of one rank AND one Aspect cannot exist in a
## grid where each rank appears once per colour), so the apex is still something you BUILD.
## Court cards (Page/Knight/Queen/King) are deliberately absent: they arrive only from rewards
## and shops, which is what makes a card reward matter against a 40-card deck.
func _starter() -> Array:
	var out: Array = []
	# Keyword seats: two per Aspect, on ranks chosen so no colour hoards the high pips. Everything
	# else is a clean pip -- the starter has to teach the poker layer before the keyword layer.
	var seats: Dictionary = {
		# NO ZNIWO in a starter deck: its mult scales with the GRAVE (Scoring: mult += value*grave),
		# so at 40 cards it reaches +30 mult on its own. Grave-scaling belongs in the reward pool
		# as a rare build payoff you choose, never as a card everyone opens with.
		A.DEATH: {3: [KW.GNICIE, 3], 7: [KW.GNICIE, 4]},
		A.CHAOS: {4: [KW.FURIA, 0], 8: [KW.SPALENIE, 8]},
		A.LIFE: {2: [KW.OSLONA, 6], 6: [KW.OPATRZNOSC, 5]},
		A.MIND: {5: [KW.ECHO, 4], 8: [KW.ECHO, 6]},
		A.NATURE: {4: [KW.BUJNOSC, 20], 7: [KW.WZROST, 2]},
	}
	for aspect in [A.LIFE, A.MIND, A.DEATH, A.CHAOS, A.NATURE]:
		for rank in range(1, 9):
			var kw: Array = seats[aspect].get(rank, [KW.NONE, 0])
			out.append([rank, aspect, kw[0], kw[1]])
	return out

## 42-card reward/shop pool: every keyword across aspects and ranks plus plain cards for
## pair/straight fishing. Wave 3 (glass / avalanche / combine) is the exponential vector -- base
## game, never meta-locked. Rarity: 5 LEGENDARY / 14 RARE / 23 COMMON (specs/spec_power.md par.7).
func _pool() -> Array:
	return [
		[10, A.DEATH, KW.ZNIWO, 1, R.RARE], [6, A.CHAOS, KW.SPALENIE, 8], [5, A.LIFE, KW.OSLONA, 7],
		[11, A.MIND, KW.ECHO, 6], [7, A.NATURE, KW.BUJNOSC, 25], [8, A.DEATH, KW.GNICIE, 4],
		[10, A.CHAOS, KW.FURIA, 0], [9, A.LIFE, KW.OPATRZNOSC, 6], [13, A.MIND, KW.ECHO, 8, R.RARE],
		[10, A.NATURE, KW.BUJNOSC, 30], [13, A.DEATH, KW.ZNIWO, 2, R.RARE], [6, A.CHAOS, KW.SPALENIE, 10],
		[11, A.DEATH, KW.GNICIE, 3], [13, A.CHAOS, KW.FURIA, 0, R.RARE], [12, A.LIFE, KW.OSLONA, 9, R.RARE],
		[8, A.MIND, KW.ECHO, 5], [13, A.NATURE, KW.BUJNOSC, 35, R.RARE], [12, A.DEATH, KW.GNICIE, 5],
		[8, A.CHAOS, KW.SPALENIE, 12, R.RARE], [10, A.LIFE, KW.OPATRZNOSC, 8, R.RARE], [14, A.MIND, KW.ECHO, 10, R.LEGENDARY],
		[14, A.NATURE, KW.BUJNOSC, 40, R.LEGENDARY], [5, A.DEATH, KW.NONE, 0], [3, A.CHAOS, KW.NONE, 0],
		[4, A.LIFE, KW.NONE, 0], [6, A.MIND, KW.NONE, 0], [9, A.NATURE, KW.NONE, 0],
		[4, A.DEATH, KW.ZNIWO, 1, R.RARE],
		# wave 2: ramp / ally-synergy / leech / curse archetypes
		[6, A.NATURE, KW.WZROST, 2], [12, A.NATURE, KW.WZROST, 3, R.RARE], [9, A.NATURE, KW.SYMBIOZA, 5],
		[5, A.NATURE, KW.SYMBIOZA, 4], [7, A.DEATH, KW.PIJAWKA, 15, R.RARE], [13, A.DEATH, KW.PIJAWKA, 20, R.LEGENDARY],
		[10, A.DEATH, KW.KLATWA, 10, R.RARE], [6, A.DEATH, KW.KLATWA, 8],
		# wave 3: the exponential vector (glass xMult / retrigger / streak xMult)
		[9, A.CHAOS, KW.PRZECIAZENIE, 3, R.RARE], [14, A.CHAOS, KW.PRZECIAZENIE, 2, R.LEGENDARY],
		[7, A.CHAOS, KW.LAWINA, 0, R.RARE], [11, A.CHAOS, KW.LAWINA, 0, R.RARE],
		[8, A.MIND, KW.KOMBINAT, 50, R.RARE], [13, A.MIND, KW.KOMBINAT, 75, R.LEGENDARY],
		# wave C: rooting block (the defensive twin of Wzrost)
		[5, A.NATURE, KW.KORZENIE, 4, R.RARE], [9, A.NATURE, KW.KORZENIE, 6, R.RARE],
	]

## The alt starters are the SAME grid bent toward a philosophy: their two colours run the full
## rank 1..8 (eight cards each -- enough that a Flush is a build target rather than a rumour),
## the other three run 1..5. 34 cards, so a drafted card still moves the deck.
func _lean(major: Array, seats: Dictionary) -> Array:
	var out: Array = []
	for aspect in [A.LIFE, A.MIND, A.DEATH, A.CHAOS, A.NATURE]:
		var top: int = 8 if major.has(aspect) else 5
		for rank in range(1, top + 1):
			var kw: Array = seats.get(aspect, {}).get(rank, [KW.NONE, 0])
			out.append([rank, aspect, kw[0], kw[1]])
	return out

## Alt starter "Reaper's Deal" (Sol unlock): Death/Chaos -- rot, harvest and burst.
func _reaper() -> Array:
	return _lean([A.DEATH, A.CHAOS], {
		A.DEATH: {3: [KW.GNICIE, 3], 5: [KW.ZNIWO, 1], 8: [KW.PIJAWKA, 15]},
		A.CHAOS: {4: [KW.FURIA, 0], 6: [KW.SPALENIE, 8], 8: [KW.FURIA, 0]},
		A.MIND: {5: [KW.ECHO, 4]},
		A.LIFE: {4: [KW.OPATRZNOSC, 4]},
	})

## Alt starter "Gardener's Path" (Sol unlock): Nature/Life -- growth, block and sustain.
func _gardener() -> Array:
	return _lean([A.NATURE, A.LIFE], {
		A.NATURE: {3: [KW.WZROST, 2], 5: [KW.SYMBIOZA, 4], 7: [KW.BUJNOSC, 25]},
		A.LIFE: {2: [KW.OSLONA, 5], 5: [KW.OPATRZNOSC, 4], 8: [KW.OSLONA, 7]},
		A.MIND: {4: [KW.ECHO, 5]},
	})

## Alt starter "Oracle's Gambit" (achievement unlock): Mind/Chaos -- Echo scaling and fury.
func _oracle() -> Array:
	return _lean([A.MIND, A.CHAOS], {
		A.MIND: {3: [KW.ECHO, 4], 5: [KW.ECHO, 6], 8: [KW.KOMBINAT, 50]},
		A.CHAOS: {4: [KW.FURIA, 0], 6: [KW.LAWINA, 0], 8: [KW.SPALENIE, 8]},
		A.DEATH: {5: [KW.GNICIE, 3]},
		A.NATURE: {4: [KW.BUJNOSC, 20]},
	})
