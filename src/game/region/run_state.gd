extends Node
## Autoload. Persistent state for one run: HP carried across fights, Rtec currency, the growing
## deck, claimed Arcana relics, the Veil (ascension tier), the run seed and the run statistics
## that feed the end-of-run tarot spread. Screens read/write this; combat is fed from it and
## reports results back via record_fight().

signal changed

const START_MAX_HP: int = 55
const REST_HEAL: int = 8        ## HP recovered after each non-boss fight (a "rest")

## Menu -> run handoff: the Veil tier chosen for the NEXT run (run.gd calls begin() itself).
static var next_veil: int = 0

var player_hp: int = START_MAX_HP
var player_max_hp: int = START_MAX_HP
## Mercury. The setter tracks the run's high-water mark (ACH_MISER) so no call site can miss it.
var rtec: int = 0:
	set(v):
		rtec = v
		stat_max_rtec = maxi(stat_max_rtec, v)
var deck: Array = []              ## Array[CardData]
var relics: Array = []            ## Array[ArcanumData] (per-run instances; may be reversed)
var region: RegionData
var region_index: int = 0         ## position on the journey (0-based)
var step: int = 0                 ## index into the region ladder (0..fights, last = boss)
var fights_won: int = 0
var fights: Array = []            ## this run's rolled ladder (Array[EnemyData])
var hand_levels: Dictionary = {}  ## Poker.Hand -> level, raised by Star consumables (run-scoped)
var veil: int = 0                 ## this run's Veil tier (0 = plain road)
var run_seed: int = 0             ## 32-bit seed of this run; 0 = not yet assigned
var pending_overkill: int = 0     ## Mercury from the killing blow's excess (consumed by run.gd)

# --- run statistics (reset in begin(); saved in save_run; the spread screen reads them) ---
var stat_damage_total: int = 0        ## sum of all scored play damage
var stat_best_hit: int = 0            ## single biggest play damage
var stat_best_hit_foe: String = ""    ## EnemyData.name_key of that play's victim
var stat_best_hit_hand: int = 0       ## Poker.Hand of that play
var stat_best_hand: int = 0           ## highest Poker.Hand ordinal played this run
var stat_turns_total: int = 0         ## sum of combat turns across fights
var stat_regions_cleared: int = 0     ## bosses beaten this run (0..4)
var stat_untouched_fights: int = 0    ## fights WON with zero damage taken (incl. blood tax)
var stat_death_flush_kill: bool = false  ## killing blow was a 5-card mono-Death flush-family hand
var stat_max_rtec: int = 0            ## highest Mercury ever held this run
var stat_sol_earned: int = 0          ## set exactly once by the spread screen

## The run's ONE sanctioned randomness source (design: combat deterministic, REWARDS variable).
## Seeded per run so "Repeat this fate" replays the exact same offers under the same choices.
## DETERMINISM CONTRACT: any NEW consumer of this rng must be appended AFTER existing call sites
## in flow order, never inserted before -- otherwise same-seed replays silently diverge.
var rng := RandomNumberGenerator.new()

func begin(p_region: RegionData, p_seed: int = 0) -> void:
	if p_seed != 0:
		run_seed = p_seed & 0xFFFFFFFF
	else:
		rng.randomize()
		run_seed = int(rng.randi()) & 0xFFFFFFFF
	if run_seed == 0:
		run_seed = 1          # 0 is the "unassigned" sentinel
	rng.seed = run_seed       # deterministic sequence from here on
	veil = next_veil
	region_index = 0
	region = p_region
	player_max_hp = 48 if veil >= 1 else START_MAX_HP   # Veil I: Thin Thread
	player_hp = player_max_hp
	rtec = 0
	pending_overkill = 0
	deck = DeckLibrary.starter_deck()
	_shuffle(deck)   # run-start order varies with the seed; within the run draws stay deterministic
	relics = []
	# Starting relic comes from the run-opening DRAFT (run.gd); legacy fallback only when the
	# region has no pool authored.
	if region != null and region.starting_pool.is_empty() and region.starting_arcanum != null:
		relics.append(region.starting_arcanum)
	step = 0
	fights_won = 0
	hand_levels = {}
	stat_damage_total = 0
	stat_best_hit = 0
	stat_best_hit_foe = ""
	stat_best_hit_hand = 0
	stat_best_hand = 0
	stat_turns_total = 0
	stat_regions_cleared = 0
	stat_untouched_fights = 0
	stat_death_flush_kill = false
	stat_max_rtec = 0
	stat_sol_earned = 0
	# Roll this run's opponents: one candidate per node pool (enemy variety is run variance too).
	fights = []
	if region != null:
		if not region.fight_pool_1.is_empty():
			fights.append(pick_offers(region.fight_pool_1, 1)[0])
		if not region.fight_pool_2.is_empty():
			fights.append(pick_offers(region.fight_pool_2, 1)[0])
		if fights.is_empty():
			for f in region.fights:
				fights.append(f)
	changed.emit()

## The relic whose effect combat applies (slice: the first claimed Arcanum).
func active_relic() -> ArcanumData:
	return relics[0] if relics.size() > 0 else null

func add_card(card: CardData) -> void:
	if card != null:
		deck.append(card.duplicate())  # run-local copy (independent editions)
		changed.emit()

func remove_card(card: CardData) -> void:
	deck.erase(card)
	changed.emit()

## Claim an Arcanum, upright or REVERSED (stronger + a visible price, chosen at boss rewards).
func claim_relic(a: ArcanumData, reversed: bool = false) -> void:
	if a == null:
		return
	var path := a.source_path if a.source_path != "" else a.resource_path
	var inst := _materialize(path, reversed)
	if inst == null:
		return
	if reversed and inst.price == ArcanumData.Price.MAX_HP:
		# The MAX_HP price is paid ONCE at claim time; max_hp persists, so loads never re-charge it.
		player_max_hp = maxi(20, player_max_hp - inst.price_value)
		player_hp = mini(player_hp, player_max_hp)
	relics.append(inst)
	changed.emit()

## Per-run relic instance: duplicate the .tres, remember its origin, apply the reversed numbers.
func _materialize(path: String, reversed: bool) -> ArcanumData:
	var src = load(path)
	if src == null:
		return null
	var inst: ArcanumData = src.duplicate()
	inst.source_path = path
	if reversed:
		inst.is_reversed = true
		if inst.reversed_mult > 0.0:
			inst.effect_mult = inst.reversed_mult
		if inst.reversed_value >= 0:
			inst.effect_value = inst.reversed_value
	return inst

## Step into the NEXT region of the journey: run state (deck, relics, Mercury) carries over,
## the ladder resets and new opponents are rolled. The road only PARTIALLY restores the traveller
## (40% of missing HP; 25% under Veil II) -- the full-heal era is over. Returns the amount healed.
func enter_region(p_region: RegionData, index: int) -> int:
	region = p_region
	region_index = index
	step = 0
	var missing := player_max_hp - player_hp
	var pct := 0.25 if veil >= 2 else 0.40
	var healed := clampi(maxi(5, int(floor(missing * pct))), 0, missing)
	player_hp += healed
	fights = []
	if not region.fight_pool_1.is_empty():
		fights.append(pick_offers(region.fight_pool_1, 1)[0])
	if not region.fight_pool_2.is_empty():
		fights.append(pick_offers(region.fight_pool_2, 1)[0])
	if fights.is_empty():
		for f in region.fights:
			fights.append(f)
	changed.emit()
	return healed

## Rest heal after a fight, Veil-adjusted (Veil II: Hungry Road).
func rest_amount() -> int:
	return 5 if veil >= 2 else REST_HEAL

## Rest after a fight: heal up to max. Returns the amount actually healed.
func rest() -> int:
	var before := player_hp
	player_hp = mini(player_max_hp, player_hp + rest_amount())
	changed.emit()
	return player_hp - before

## Fight results feed the run statistics (called by combat.gd right before `finished` fires).
func record_fight(won: bool, foe_key: String, c: CombatController) -> void:
	stat_damage_total += c.fight_damage
	stat_turns_total += c.turn
	stat_best_hand = maxi(stat_best_hand, c.fight_best_hand)
	if c.fight_best_hit > stat_best_hit:
		stat_best_hit = c.fight_best_hit
		stat_best_hit_hand = c.fight_best_hit_hand
		stat_best_hit_foe = foe_key
	if won:
		if c.damage_taken == 0:
			stat_untouched_fights += 1
		if c.kill_mono_death_flush:
			stat_death_flush_kill = true

## Stylized seed code for the spread screen, e.g. "A3F2-09BC".
static func seed_text(s: int) -> String:
	var h := "%08X" % (s & 0xFFFFFFFF)
	return h.substr(0, 4) + "-" + h.substr(4, 4)

## N distinct random cards from a pool (the variable-reward layer: drafts and shop offers).
func pick_offers(pool: Array, n: int) -> Array:
	var idx: Array = range(pool.size())
	_shuffle(idx)
	var out: Array = []
	for i in mini(n, idx.size()):
		out.append(pool[idx[i]])
	return out

## Rarity-weighted card offers (rewards + shop). Odds per slot: 5% LEGENDARY / 25% RARE / 70%
## COMMON; an elite victory boosts the next offer to 12/43/45. Empty tiers fall back downward
## (LEGENDARY -> RARE -> COMMON); no duplicates within one offer set.
func pick_tiered_offers(pool: Array, n: int, boosted: bool = false) -> Array:
	var out: Array = []
	for _slot in n:
		var r := rng.randf()
		var tier: int
		if boosted:
			tier = CardData.Rarity.LEGENDARY if r < 0.12 else (CardData.Rarity.RARE if r < 0.55 else CardData.Rarity.COMMON)
		else:
			tier = CardData.Rarity.LEGENDARY if r < 0.05 else (CardData.Rarity.RARE if r < 0.30 else CardData.Rarity.COMMON)
		var pick := _pick_from_tier(pool, tier, out)
		if pick != null:
			out.append(pick)
	return out

func _pick_from_tier(pool: Array, tier: int, taken: Array) -> CardData:
	var order: Array = [tier]
	for fallback in [CardData.Rarity.RARE, CardData.Rarity.COMMON, CardData.Rarity.LEGENDARY]:
		if not order.has(fallback):
			order.append(fallback)
	for t in order:
		var bucket: Array = []
		for c in pool:
			if c.rarity == t and not taken.has(c):
				bucket.append(c)
		if not bucket.is_empty():
			return bucket[rng.randi_range(0, bucket.size() - 1)]
	return null

func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func level_up_hand(hand: int) -> void:
	hand_levels[hand] = int(hand_levels.get(hand, 0)) + 1
	changed.emit()

# ---------------------------------------------------------------- run save / continue
## One-slot run persistence (user://run_save.cfg). Saved at every map arrival (the safe hub point);
## deleted when the run ends. `load_pending` is set by the main menu's Continue button.

const RUN_SAVE := "user://run_save.cfg"
static var load_pending: bool = false

func has_run_save() -> bool:
	return FileAccess.file_exists(RUN_SAVE)

func delete_run_save() -> void:
	if has_run_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_SAVE))

func save_run(pending_omen_id: String = "") -> void:
	var cf := ConfigFile.new()
	cf.set_value("run", "region_path", region.resource_path if region != null else "")
	cf.set_value("run", "region_index", region_index)
	cf.set_value("run", "step", step)
	cf.set_value("run", "hp", player_hp)
	cf.set_value("run", "max_hp", player_max_hp)
	cf.set_value("run", "rtec", rtec)
	cf.set_value("run", "fights_won", fights_won)
	cf.set_value("run", "hand_levels", hand_levels)
	cf.set_value("run", "omen", pending_omen_id)
	cf.set_value("run", "veil", veil)
	cf.set_value("run", "seed", run_seed)
	cf.set_value("run", "rng_state", rng.state)
	cf.set_value("run", "st_dmg", stat_damage_total)
	cf.set_value("run", "st_hit", stat_best_hit)
	cf.set_value("run", "st_hit_foe", stat_best_hit_foe)
	cf.set_value("run", "st_hit_hand", stat_best_hit_hand)
	cf.set_value("run", "st_hand", stat_best_hand)
	cf.set_value("run", "st_turns", stat_turns_total)
	cf.set_value("run", "st_regions", stat_regions_cleared)
	cf.set_value("run", "st_untouched", stat_untouched_fights)
	cf.set_value("run", "st_flush", stat_death_flush_kill)
	cf.set_value("run", "st_maxrtec", stat_max_rtec)
	var relic_entries: Array = []
	for a in relics:
		relic_entries.append({"p": a.source_path if a.source_path != "" else a.resource_path, "r": a.is_reversed})
	cf.set_value("run", "relics", relic_entries)
	var fight_paths: Array = []
	for f in fights:
		fight_paths.append(f.resource_path)
	cf.set_value("run", "fights", fight_paths)
	var cards: Array = []
	for c in deck:
		cards.append({"r": c.rank, "a": c.aspect, "k": c.keyword, "v": c.keyword_value, "e": c.edition, "y": c.rarity, "w": c.wear})
	cf.set_value("run", "deck", cards)
	cf.save(RUN_SAVE)

## Restores the saved run. Returns the pending omen id ("" when none). Deck growth (WZROST ramp)
## is intentionally transient and resets on load; glass wear ("w") persists.
func load_run() -> String:
	var cf := ConfigFile.new()
	if cf.load(RUN_SAVE) != OK:
		return ""
	run_seed = cf.get_value("run", "seed", 0)
	if run_seed == 0:                # pre-seed save: assign one so the spread can show it
		rng.randomize()
		run_seed = int(rng.randi()) & 0xFFFFFFFF
		if run_seed == 0:
			run_seed = 1
		rng.seed = run_seed
	else:
		rng.seed = run_seed
		rng.state = cf.get_value("run", "rng_state", rng.state)
	veil = cf.get_value("run", "veil", 0)
	region = load(cf.get_value("run", "region_path", ""))
	region_index = cf.get_value("run", "region_index", 0)
	step = cf.get_value("run", "step", 0)
	player_max_hp = cf.get_value("run", "max_hp", START_MAX_HP)
	player_hp = cf.get_value("run", "hp", player_max_hp)
	rtec = cf.get_value("run", "rtec", 0)
	fights_won = cf.get_value("run", "fights_won", 0)
	hand_levels = cf.get_value("run", "hand_levels", {})
	pending_overkill = 0
	stat_damage_total = cf.get_value("run", "st_dmg", 0)
	stat_best_hit = cf.get_value("run", "st_hit", 0)
	stat_best_hit_foe = cf.get_value("run", "st_hit_foe", "")
	stat_best_hit_hand = cf.get_value("run", "st_hit_hand", 0)
	stat_best_hand = cf.get_value("run", "st_hand", 0)
	stat_turns_total = cf.get_value("run", "st_turns", 0)
	stat_regions_cleared = cf.get_value("run", "st_regions", 0)
	stat_untouched_fights = cf.get_value("run", "st_untouched", 0)
	stat_death_flush_kill = cf.get_value("run", "st_flush", false)
	stat_max_rtec = cf.get_value("run", "st_maxrtec", 0)
	stat_sol_earned = 0
	relics = []
	for entry in cf.get_value("run", "relics", []):
		if entry is String:   # legacy save: plain paths, always upright
			var a := _materialize(entry, false)
			if a != null:
				relics.append(a)
		elif entry is Dictionary:
			var a2 := _materialize(entry.get("p", ""), bool(entry.get("r", false)))
			if a2 != null:
				relics.append(a2)
	fights = []
	for p in cf.get_value("run", "fights", []):
		var f = load(p)
		if f != null:
			fights.append(f)
	deck = []
	for d in cf.get_value("run", "deck", []):
		var c := CardData.new()
		c.rank = d["r"]
		c.aspect = d["a"] as Aspects.Id
		c.keyword = d["k"] as CardData.Keyword
		c.keyword_value = d["v"]
		c.edition = d["e"] as CardData.Edition
		c.rarity = int(d.get("y", CardData.Rarity.COMMON)) as CardData.Rarity
		c.wear = int(d.get("w", 0))
		deck.append(c)
	changed.emit()
	return cf.get_value("run", "omen", "")

func spend(cost: int) -> bool:
	if rtec < cost:
		return false
	rtec -= cost
	changed.emit()
	return true
