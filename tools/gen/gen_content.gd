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
	_save_arcanum_simple("arcanum_emperor", "ARCANUM_CESARZA", E.BLOCK_ON_PLAY, A.LIFE, 1.0, 6, "04_emperor")
	_save_arcanum_simple("arcanum_chariot", "ARCANUM_RYDWANU", E.MULT_IF_ASPECT, A.MIND, 1.4, 0, "07_chariot")
	_save_arcanum_simple("arcanum_strength", "ARCANUM_SILY", E.MULT_IF_ASPECT, A.LIFE, 1.5, 0, "08_strength")
	_save_arcanum_simple("arcanum_hermit", "ARCANUM_PUSTELNIKA", E.EXTRA_DISCARD, A.MIND, 1.0, 2, "09_hermit")

	# Enemy pressure (docs/specs/spec_difficulty.md par.3): intended fight length 5-6 plays; the
	# per-turn enrage past the first cycle is the anti-stall clock. Every regular enemy IS a Minor
	# Arcana court card (suit law: cups=LIFE swords=MIND wands=CHAOS pents=DEATH; NATURE wears the
	# suit's Ten). Region rank ladder: Pages -> Knights -> Queens/Kings.
	var a := _enemy("ENEMY_KULTYSTA", 520, [10, 13, 8], 5, false, EnemyData.Rule.NONE, "", 2)
	a.art = load(MINOR + "pents_11.jpg")
	ResourceSaver.save(a, ENEMY_DIR + "enemy_a.tres")
	var a2 := _enemy("ENEMY_WIEDZMA", 480, [16, 4, 16], 5, false, EnemyData.Rule.NONE, "", 2)
	a2.art = load(MINOR + "wands_11.jpg")
	ResourceSaver.save(a2, ENEMY_DIR + "enemy_a2.tres")
	var b := _enemy("ENEMY_CIEN", 600, [12, 15, 9], 6, false, EnemyData.Rule.NONE, "", 2)
	b.art = load(MINOR + "swords_11.jpg")
	ResourceSaver.save(b, ENEMY_DIR + "enemy_b.tres")
	var b2 := _enemy("ENEMY_GOLEM", 660, [20, 0, 15], 6, false, EnemyData.Rule.NONE, "", 3)
	b2.art = load(MINOR + "pents_10.jpg")
	ResourceSaver.save(b2, ENEMY_DIR + "enemy_b2.tres")
	var boss := _enemy("ENEMY_WIEZA", 600, [15, 20, 13], 12, true, EnemyData.Rule.TOWER_IGNORES_BLOCK, "RULE_TOWER", 3)
	boss.art = load(MAJOR + "16_tower.jpg")
	ResourceSaver.save(boss, ENEMY_DIR + "boss_tower.tres")
	_save_elite("enemy_elite_r1", "ENEMY_ELITE_R1", 680, [22, 0, 16], 12, 5, "pents_13")

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
	ResourceSaver.save(devil, ENEMY_DIR + "boss_devil.tres")
	_save_elite("enemy_elite_r2", "ENEMY_ELITE_R2", 870, [18, 18, 18], 14, 5, "wands_13")
	_save_region("region_02", "REGION_02", ["enemy_r2a", "enemy_r2a2"], ["enemy_r2b", "enemy_r2b2"],
		"boss_devil", "arcanum_devil_boss", Color(0.851, 0.373, 0.231), "enemy_elite_r2")

	# ---- Region III "Szczyt": Queens and Kings, boss MOON (cleanse + self-mend) ----
	_save_enemy("enemy_r3a", "ENEMY_STRAZNIK", 1040, [20, 23, 15], 9, 4, "cups_13")
	_save_enemy("enemy_r3a2", "ENEMY_WIDMO", 990, [27, 10, 27], 9, 4, "swords_13")
	_save_enemy("enemy_r3b", "ENEMY_TYTAN", 1150, [22, 22, 22], 9, 4, "pents_14")
	_save_enemy("enemy_r3b2", "ENEMY_HERALD", 1090, [30, 0, 25], 9, 5, "wands_14")
	var moon := _enemy("ENEMY_KSIEZYC", 980, [20, 25, 17], 16, true, EnemyData.Rule.MOON_CLEANSE, "RULE_MOON", 5)
	moon.art = load(MAJOR + "18_moon.jpg")
	ResourceSaver.save(moon, ENEMY_DIR + "boss_moon.tres")
	_save_elite("enemy_elite_r3", "ENEMY_ELITE_R3", 1200, [25, 25, 25], 18, 6, "swords_14")
	_save_region("region_03", "REGION_03", ["enemy_r3a", "enemy_r3a2"], ["enemy_r3b", "enemy_r3b2"],
		"boss_moon", "arcanum_moon", Color(0.498, 0.706, 0.831), "enemy_elite_r3")

	# ---- Region IV "Swiat": the finale -- a single duel against THE WORLD (all rules at once) ----
	var world := _enemy("ENEMY_SWIAT", 1300, [26, 30, 22], 20, true, EnemyData.Rule.WORLD_ALL, "RULE_WORLD", 6)
	world.art = load(MAJOR + "21_world.jpg")
	ResourceSaver.save(world, ENEMY_DIR + "boss_world.tres")
	_save_region("region_04", "REGION_04", [], [], "boss_world", "arcanum_world",
		Color(0.910, 0.761, 0.408), "")

func _apply_reversed(arc: ArcanumData, spec) -> void:
	if spec == null:
		return
	arc.reversed_mult = spec[0]
	arc.reversed_value = spec[1]
	arc.price = spec[2] as ArcanumData.Price
	arc.price_value = spec[3]

func _save_arcanum_simple(file: String, name_key: String, effect: ArcanumData.Effect, aspect: Aspects.Id, mult: float, value: int, art: String) -> void:
	var arc := ArcanumData.new()
	arc.name_key = name_key
	arc.effect = effect
	arc.effect_aspect = aspect
	arc.effect_mult = mult
	arc.effect_value = value
	arc.art = load("%s%s.jpg" % [MAJOR, art])
	ResourceSaver.save(arc, ARCANA_DIR + file + ".tres")

func _save_enemy(file: String, name_key: String, hp: int, intents: Array, reward: int, enrage: int, art: String = "") -> void:
	var e := _enemy(name_key, hp, intents, reward, false, EnemyData.Rule.NONE, "", enrage)
	if art != "":
		e.art = load(MINOR + art + ".jpg")
	ResourceSaver.save(e, ENEMY_DIR + file + ".tres")

## Elite: a REVERSED court card guarding better loot (map fork). Art renders flipped in combat.
func _save_elite(file: String, name_key: String, hp: int, intents: Array, reward: int, enrage: int, art: String) -> void:
	var e := _enemy(name_key, hp, intents, reward, false, EnemyData.Rule.NONE, "", enrage)
	e.is_elite = true
	e.art = load(MINOR + art + ".jpg")
	ResourceSaver.save(e, ENEMY_DIR + file + ".tres")

func _save_region(file: String, name_key: String, pool1: Array, pool2: Array, boss_file: String, arc_file: String, accent: Color, elite_file: String) -> void:
	var r := RegionData.new()
	r.name_key = name_key
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
	ResourceSaver.save(r, REGION_DIR + file + ".tres")

func _arcanum(name_key: String, aspect: Aspects.Id, mult: float) -> ArcanumData:
	var arc := ArcanumData.new()
	arc.name_key = name_key
	arc.effect = ArcanumData.Effect.MULT_IF_ASPECT
	arc.effect_aspect = aspect
	arc.effect_mult = mult
	return arc

func _enemy(name_key: String, hp: int, intents: Array, reward: int, is_boss: bool, rule: EnemyData.Rule, rule_key: String, enrage: int = 0) -> EnemyData:
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

## Balanced starter (5 Death / 4 Chaos / 3 Life / 2 Mind / 2 Nature), MAX 3 OF ANY RANK: the apex
## hands (Five / Magnum Opus) must be BUILT via drafted duplicates, never dealt. Three 7s across
## three Aspects teach cross-colour sets; 5 Death cards give the draft its first goal.
func _starter() -> Array:
	return [
		[7, A.DEATH, KW.GNICIE, 3], [7, A.DEATH, KW.NONE, 0], [9, A.DEATH, KW.GNICIE, 4],
		[14, A.DEATH, KW.GNICIE, 5], [2, A.DEATH, KW.NONE, 0],
		[7, A.CHAOS, KW.NONE, 0], [5, A.CHAOS, KW.FURIA, 0], [9, A.CHAOS, KW.FURIA, 0],
		[12, A.CHAOS, KW.SPALENIE, 6],
		[3, A.LIFE, KW.OSLONA, 6], [14, A.LIFE, KW.OSLONA, 8], [6, A.LIFE, KW.OPATRZNOSC, 5],
		[5, A.MIND, KW.ECHO, 4], [10, A.MIND, KW.ECHO, 6],
		[8, A.NATURE, KW.BUJNOSC, 20], [6, A.NATURE, KW.NONE, 0],
	]

## 42-card reward/shop pool: every keyword across aspects and ranks plus plain cards for
## pair/straight fishing. Wave 3 (glass / avalanche / combine) is the exponential vector -- base
## game, never meta-locked. Rarity: 5 LEGENDARY / 14 RARE / 23 COMMON (specs/spec_power.md par.7).
func _pool() -> Array:
	return [
		[10, A.DEATH, KW.ZNIWO, 1], [6, A.CHAOS, KW.SPALENIE, 8], [5, A.LIFE, KW.OSLONA, 7],
		[11, A.MIND, KW.ECHO, 6], [7, A.NATURE, KW.BUJNOSC, 25], [8, A.DEATH, KW.GNICIE, 4],
		[10, A.CHAOS, KW.FURIA, 0], [9, A.LIFE, KW.OPATRZNOSC, 6], [13, A.MIND, KW.ECHO, 8, R.RARE],
		[10, A.NATURE, KW.BUJNOSC, 30], [13, A.DEATH, KW.ZNIWO, 2, R.RARE], [6, A.CHAOS, KW.SPALENIE, 10],
		[11, A.DEATH, KW.GNICIE, 3], [13, A.CHAOS, KW.FURIA, 0, R.RARE], [12, A.LIFE, KW.OSLONA, 9, R.RARE],
		[8, A.MIND, KW.ECHO, 5], [13, A.NATURE, KW.BUJNOSC, 35, R.RARE], [12, A.DEATH, KW.GNICIE, 5],
		[8, A.CHAOS, KW.SPALENIE, 12, R.RARE], [10, A.LIFE, KW.OPATRZNOSC, 8, R.RARE], [14, A.MIND, KW.ECHO, 10, R.LEGENDARY],
		[14, A.NATURE, KW.BUJNOSC, 40, R.LEGENDARY], [5, A.DEATH, KW.NONE, 0], [3, A.CHAOS, KW.NONE, 0],
		[4, A.LIFE, KW.NONE, 0], [6, A.MIND, KW.NONE, 0], [9, A.NATURE, KW.NONE, 0],
		[4, A.DEATH, KW.ZNIWO, 1],
		# wave 2: ramp / ally-synergy / leech / curse archetypes
		[6, A.NATURE, KW.WZROST, 2], [12, A.NATURE, KW.WZROST, 3, R.RARE], [9, A.NATURE, KW.SYMBIOZA, 5],
		[5, A.NATURE, KW.SYMBIOZA, 4], [7, A.DEATH, KW.PIJAWKA, 15, R.RARE], [13, A.DEATH, KW.PIJAWKA, 20, R.LEGENDARY],
		[10, A.DEATH, KW.KLATWA, 10, R.RARE], [6, A.DEATH, KW.KLATWA, 8],
		# wave 3: the exponential vector (glass xMult / retrigger / streak xMult)
		[9, A.CHAOS, KW.PRZECIAZENIE, 3, R.RARE], [14, A.CHAOS, KW.PRZECIAZENIE, 2, R.LEGENDARY],
		[7, A.CHAOS, KW.LAWINA, 0, R.RARE], [11, A.CHAOS, KW.LAWINA, 0, R.RARE],
		[8, A.MIND, KW.KOMBINAT, 50, R.RARE], [13, A.MIND, KW.KOMBINAT, 75, R.LEGENDARY],
	]

## Alt starter "Reaper's Deal" (Sol unlock): Death/Chaos -- rot, harvest and burst.
func _reaper() -> Array:
	return [
		[4, A.DEATH, KW.GNICIE, 3], [4, A.DEATH, KW.ZNIWO, 1], [6, A.DEATH, KW.GNICIE, 4],
		[8, A.DEATH, KW.ZNIWO, 2], [8, A.DEATH, KW.PIJAWKA, 15], [10, A.DEATH, KW.KLATWA, 10],
		[13, A.DEATH, KW.GNICIE, 5],
		[6, A.CHAOS, KW.FURIA, 0], [8, A.CHAOS, KW.SPALENIE, 8], [10, A.CHAOS, KW.FURIA, 0],
		[12, A.CHAOS, KW.SPALENIE, 10], [3, A.CHAOS, KW.SPALENIE, 6],
		[5, A.MIND, KW.ECHO, 4], [9, A.MIND, KW.ECHO, 6],
		[5, A.LIFE, KW.OPATRZNOSC, 4], [11, A.LIFE, KW.OSLONA, 6],
	]

## Alt starter "Gardener's Path" (Sol unlock): Nature/Life -- growth, block and sustain.
func _gardener() -> Array:
	return [
		[3, A.NATURE, KW.WZROST, 2], [5, A.NATURE, KW.WZROST, 3], [7, A.NATURE, KW.SYMBIOZA, 4],
		[9, A.NATURE, KW.SYMBIOZA, 5], [9, A.NATURE, KW.BUJNOSC, 25], [13, A.NATURE, KW.WZROST, 4],
		[2, A.LIFE, KW.OSLONA, 5], [5, A.LIFE, KW.OPATRZNOSC, 4], [7, A.LIFE, KW.OSLONA, 7],
		[9, A.LIFE, KW.OPATRZNOSC, 6], [14, A.LIFE, KW.OSLONA, 9],
		[7, A.MIND, KW.ECHO, 5], [12, A.MIND, KW.ECHO, 7],
		[5, A.DEATH, KW.GNICIE, 3], [8, A.CHAOS, KW.SPALENIE, 7], [11, A.CHAOS, KW.FURIA, 0],
	]

## Alt starter "Oracle's Gambit" (achievement unlock): Mind/Chaos -- Echo scaling and fury.
func _oracle() -> Array:
	return [
		[2, A.MIND, KW.ECHO, 3], [5, A.MIND, KW.ECHO, 4], [8, A.MIND, KW.ECHO, 6],
		[11, A.MIND, KW.ECHO, 7], [13, A.MIND, KW.ECHO, 8],
		[3, A.CHAOS, KW.SPALENIE, 5], [6, A.CHAOS, KW.SPALENIE, 7], [9, A.CHAOS, KW.FURIA, 0],
		[12, A.CHAOS, KW.SPALENIE, 9], [14, A.CHAOS, KW.FURIA, 0],
		[4, A.DEATH, KW.KLATWA, 8], [9, A.DEATH, KW.PIJAWKA, 12],
		[6, A.LIFE, KW.OSLONA, 5], [10, A.LIFE, KW.OPATRZNOSC, 5],
		[4, A.NATURE, KW.WZROST, 2], [10, A.NATURE, KW.SYMBIOZA, 4],
	]
