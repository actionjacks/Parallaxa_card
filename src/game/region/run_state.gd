extends Node
## Autoload. Persistent state for one run: HP carried across fights, Rtec currency, the growing
## deck, claimed Arcana relics, the Veil (ascension tier), the run seed and the run statistics
## that feed the end-of-run tarot spread. Screens read/write this; combat is fed from it and
## reports results back via record_fight().

signal changed

const START_MAX_HP: int = 55
const REST_HEAL: int = 8        ## HP recovered after each non-boss fight (a "rest")
## Rungs drawn from EACH of the two enemy pools; the tower is 2*this + the boss at the summit.
const RUNGS_PER_POOL: int = 2

## Menu -> run handoff: the Veil tier chosen for the NEXT run (run.gd calls begin() itself).
static var next_veil: int = 0
## Menu -> run handoff: an ENTERED fate code (0 = roll fresh) and the Pure Reading flag.
static var next_seed: int = 0
static var next_pure: bool = false
static var next_daily: String = ""    ## Daily Fate date tag ("" = not a daily run)

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
## PURE READING: a shared fate must be identical for every player, so profile-injected content
## (bought arcana, achievement omens/decks, editions) stays OUT of the pools. Set for entered
## seeds and Daily Fates; a game titled on honesty cannot ship a lying seed.
var pure_reading: bool = false
var daily_tag: String = ""        ## Daily Fate date ("" = regular run)
var boss: EnemyData               ## this region's ROLLED boss (Fool's Journey rotation)
var depth: int = 0                ## Beyond-the-World loops completed (0 = first journey)
var run_won: bool = false         ## The World has fallen at least once (endless death stays a WIN)
## The Sealed Biome is a one-way terminus: once entered, the World Gate never returns.
var sealed_entered: bool = false
## Veil V removes one Aspect from the run entirely; -1 when no colour was taken.
var lost_aspect: int = -1
## Which biome roads this journey has already walked (paths). Drives the choice screen so a
## journey is a ROUTE through the pentagram, never the same colour twice.
var biomes_walked: Array = []
var run_deck_id: String = "classic"   ## starter used this run (deck-win achievements)
var elite_taken: bool = false     ## this region's elite fork already fought (one elite per region)

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
var stat_elites_slain: int = 0        ## elite forks won this run
var stat_death_foe: String = ""       ## who felled the player (EnemyData.name_key)
var stat_death_turn: int = 0          ## on which combat turn
var stat_death_cause: String = ""     ## "attack" | "pact" | "ashes"
var stat_bought: int = 0              ## shop purchases this run (first-blood: FIRST_SHOP)
var stat_flush_played: bool = false   ## any flush-family hand scored (FIRST_FLUSH)
var stat_star_used: bool = false      ## a Star hand-level bought (FIRST_STAR)
var stat_omen_taken: bool = false     ## any omen accepted (FIRST_OMEN)
var omen_debt: int = 0                ## Wheel's push-your-luck: +N to every intent NEXT fight

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
	pure_reading = next_pure
	daily_tag = next_daily
	region_index = 0
	region = p_region
	player_max_hp = 48 if veil >= 1 else START_MAX_HP   # Veil I: Thin Thread
	player_hp = player_max_hp
	rtec = 0
	pending_overkill = 0
	run_deck_id = "classic"
	if not pure_reading:
		var prof := get_node_or_null("/root/Profile")
		if prof != null and prof.available_decks().has(prof.selected_deck):
			run_deck_id = prof.selected_deck
	deck = DeckLibrary.starter_deck_pure() if pure_reading else DeckLibrary.starter_deck()
	# Veil V -- the Colourless Dawn: one Aspect is missing from the deck entirely. It attacks the
	# geometry rather than the numbers: whichever colour the player was going to build toward may
	# simply not be there, and the run has to be planned around the hole. Chosen from the run seed
	# BEFORE any other draw, so the same fate code always removes the same colour.
	if veil >= 5:
		var lost: int = int(rng.randi() % 5)
		var kept: Array = []
		for c in deck:
			if int(c.aspect) != lost:
				kept.append(c)
		deck = kept
		lost_aspect = lost
	# SEED CONTRACT: Fisher-Yates eats N-1 draws, so shuffling the deck on the MAIN rng made the
	# whole downstream stream depend on deck SIZE -- growing the starter from 16 to 40 cards would
	# silently invalidate every shared fate code. Run it on a sub-generator instead: exactly one
	# main-rng draw, whatever the deck's size, same shape as pick_offers.
	_shuffle_with(deck, _sub_rng())
	relics = []
	# Starting relic comes from the run-opening DRAFT (run.gd); legacy fallback only when the
	# region has no pool authored.
	if region != null and region.starting_pool.is_empty() and region.starting_arcanum != null:
		relics.append(region.starting_arcanum)
	step = 0
	fights_won = 0
	elite_taken = false
	depth = 0
	run_won = false
	sealed_entered = false
	lost_aspect = -1
	biomes_walked = []
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
	stat_elites_slain = 0
	stat_death_foe = ""
	stat_death_turn = 0
	stat_death_cause = ""
	stat_bought = 0
	stat_flush_played = false
	stat_star_used = false
	stat_omen_taken = false
	omen_debt = 0
	# Roll this run's opponents: one candidate per node pool (enemy variety is run variance too).
	_roll_tower()
	changed.emit()

## Re-roll the current region's ladder in place. Used when the FIRST biome is chosen after the
## run has already begun: begin() rolled a placeholder, the player's choice replaces it.
func reroll_ladder() -> void:
	_roll_tower()
	changed.emit()

## THE TOWER: a biome is climbed, not crossed. Four duels and the boss at the summit -- two
## opponents rolled from each pool so the climb varies run to run while the shape stays fixed.
## SEED CONTRACT: pool draws happen here, before _roll_boss, exactly as they always did.
func _roll_tower() -> void:
	fights = []
	if region == null:
		return
	for pool in [region.fight_pool_1, region.fight_pool_2]:
		if pool.is_empty():
			continue
		var picked: Array = pick_offers(pool, mini(RUNGS_PER_POOL, pool.size()))
		for f in picked:
			fights.append(f)
		# a pool smaller than the rungs it owes repeats its last foe rather than shortening
		# the tower -- the climb is always the same height.
		while picked.size() < RUNGS_PER_POOL and not picked.is_empty():
			fights.append(picked[picked.size() - 1])
			picked.append(picked[picked.size() - 1])
	if fights.is_empty():
		for f in region.fights:
			fights.append(f)
	_roll_boss()

## Boss ROTATION (Fool's Journey): each run climbs a different subset of the Arcana. Rolled
## AFTER the fight pools (rng append contract). Falls back to the authored fixed boss.
func _roll_boss() -> void:
	if region != null and not region.boss_pool.is_empty():
		boss = pick_offers(region.boss_pool, 1)[0]
	else:
		boss = region.boss if region != null else null

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
	elite_taken = false
	var missing := player_max_hp - player_hp
	var pct := 0.25 if veil >= 2 else 0.40
	var healed := clampi(maxi(5, int(floor(missing * pct))), 0, missing)
	player_hp += healed
	_roll_tower()
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
	if Poker.value_of(c.fight_best_hand) > Poker.value_of(stat_best_hand):
		stat_best_hand = c.fight_best_hand
	if c.flush_played:
		stat_flush_played = true
	if c.fight_best_hit > stat_best_hit:
		stat_best_hit = c.fight_best_hit
		stat_best_hit_hand = c.fight_best_hit_hand
		stat_best_hit_foe = foe_key
	if won:
		if c.damage_taken == 0:
			stat_untouched_fights += 1
		if c.kill_mono_death_flush:
			stat_death_flush_kill = true
	else:
		# The spread names the doom: who, which turn, by what (the death must be legible).
		stat_death_foe = foe_key
		stat_death_turn = c.turn
		stat_death_cause = c.death_cause

## Stylized seed code for the spread screen, e.g. "A3F2-09BC".
static func seed_text(s: int) -> String:
	var h := "%08X" % (s & 0xFFFFFFFF)
	return h.substr(0, 4) + "-" + h.substr(4, 4)

## N distinct random cards from a pool (the variable-reward layer: drafts and shop offers).
## SEED CONTRACT: consumes EXACTLY ONE draw of the main rng regardless of pool size or n -- the
## actual sampling runs on a sub-generator seeded by that draw. Achievement/purchase-driven pool
## growth therefore never shifts the rest of the run's random stream ("Repeat this fate" holds).
func pick_offers(pool: Array, n: int) -> Array:
	var sub := _sub_rng()
	var idx: Array = range(pool.size())
	_shuffle_with(idx, sub)
	var out: Array = []
	for i in mini(n, idx.size()):
		out.append(pool[idx[i]])
	return out

## Rarity-weighted card offers (rewards + shop). Odds per slot: 5% LEGENDARY / 25% RARE / 70%
## COMMON; an elite victory boosts the next offer to 12/43/45. Empty tiers fall back downward
## (LEGENDARY -> RARE -> COMMON); no duplicates within one offer set. One main-rng draw total.
func pick_tiered_offers(pool: Array, n: int, boosted: bool = false) -> Array:
	var sub := _sub_rng()
	var out: Array = []
	for _slot in n:
		var r := sub.randf()
		var tier: int
		if boosted:
			tier = CardData.Rarity.LEGENDARY if r < 0.12 else (CardData.Rarity.RARE if r < 0.55 else CardData.Rarity.COMMON)
		else:
			tier = CardData.Rarity.LEGENDARY if r < 0.05 else (CardData.Rarity.RARE if r < 0.30 else CardData.Rarity.COMMON)
		var pick := _pick_from_tier(pool, tier, out, sub)
		if pick != null:
			out.append(pick)
	return out

## Shuffle the run deck before a duel. The deck used to be ordered ONCE at run start and every
## fight then drew from that same fixed order -- with a 16-card deck it cycled two or three times
## per fight and the repetition hid, but the 40-card pentacle deck only gets ~13 cards deep in a
## short fight, so every duel opened with the SAME eight cards. A bot found one good opening and
## replayed it for an entire journey. Cards are shuffled between duels, never inside one: the
## preview still cannot lie, and peek_draw stays exact for the whole fight.
## SEED CONTRACT: exactly one main-rng draw per fight, same shape as pick_offers.
func shuffle_for_fight() -> void:
	_shuffle_with(deck, _sub_rng())

func _sub_rng() -> RandomNumberGenerator:
	var sub := RandomNumberGenerator.new()
	sub.seed = int(rng.randi())
	return sub

func _pick_from_tier(pool: Array, tier: int, taken: Array, sub: RandomNumberGenerator) -> CardData:
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
			return bucket[sub.randi_range(0, bucket.size() - 1)]
	return null

func _shuffle(arr: Array) -> void:
	_shuffle_with(arr, rng)

func _shuffle_with(arr: Array, r: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
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

## Bot/test isolation (mirrors Profile._path): automated runs never touch the player's save slot.
static func _save_path() -> String:
	var t := OS.get_environment("TEST_PROFILE")
	return ("user://run_save_%s.cfg" % t) if t != "" else RUN_SAVE

func has_run_save() -> bool:
	return FileAccess.file_exists(_save_path())

func delete_run_save() -> void:
	if has_run_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path()))

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
	cf.set_value("run", "elite_taken", elite_taken)
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
	cf.set_value("run", "st_elites", stat_elites_slain)
	cf.set_value("run", "st_bought", stat_bought)
	cf.set_value("run", "st_flushp", stat_flush_played)
	cf.set_value("run", "st_star", stat_star_used)
	cf.set_value("run", "st_omen", stat_omen_taken)
	cf.set_value("run", "omen_debt", omen_debt)
	cf.set_value("run", "pure", pure_reading)
	cf.set_value("run", "daily", daily_tag)
	cf.set_value("run", "boss", boss.resource_path if boss != null else "")
	cf.set_value("run", "depth", depth)
	cf.set_value("run", "run_won", run_won)
	cf.set_value("run", "sealed", sealed_entered)
	cf.set_value("run", "biomes", biomes_walked)
	cf.set_value("run", "lost_aspect", lost_aspect)
	cf.set_value("run", "deck_id", run_deck_id)
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
		cards.append({"r": c.rank, "a": c.aspect, "k": c.keyword, "v": c.keyword_value, "e": c.edition, "y": c.rarity, "w": c.wear, "s": c.scar, "i": c.inverted, "p": c.splash, "c": c.cracked})
	cf.set_value("run", "deck", cards)
	cf.save(_save_path())

## Restores the saved run. Returns the pending omen id ("" when none). Deck growth (WZROST ramp)
## is intentionally transient and resets on load; glass wear ("w") persists.
func load_run() -> String:
	var cf := ConfigFile.new()
	if cf.load(_save_path()) != OK:
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
	elite_taken = cf.get_value("run", "elite_taken", false)
	region = load(cf.get_value("run", "region_path", ""))
	region_index = cf.get_value("run", "region_index", 0)
	var boss_path: String = cf.get_value("run", "boss", "")
	boss = load(boss_path) if boss_path != "" else (region.boss if region != null else null)
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
	# Merge, never stomp: a pre-update save has no st_maxrtec, but the rtec setter above already
	# derived the provable high-water mark from the loaded Mercury.
	stat_max_rtec = maxi(stat_max_rtec, cf.get_value("run", "st_maxrtec", 0))
	stat_elites_slain = cf.get_value("run", "st_elites", 0)
	stat_bought = cf.get_value("run", "st_bought", 0)
	stat_flush_played = cf.get_value("run", "st_flushp", false)
	stat_star_used = cf.get_value("run", "st_star", false)
	stat_omen_taken = cf.get_value("run", "st_omen", false)
	omen_debt = cf.get_value("run", "omen_debt", 0)
	pure_reading = cf.get_value("run", "pure", false)
	daily_tag = cf.get_value("run", "daily", "")
	depth = cf.get_value("run", "depth", 0)
	run_won = cf.get_value("run", "run_won", false)
	sealed_entered = cf.get_value("run", "sealed", false)
	biomes_walked = cf.get_value("run", "biomes", [])
	lost_aspect = cf.get_value("run", "lost_aspect", -1)
	run_deck_id = cf.get_value("run", "deck_id", "classic")
	stat_death_foe = ""
	stat_death_turn = 0
	stat_death_cause = ""
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
		c.scar = int(d.get("s", 0))
		c.inverted = bool(d.get("i", false))
		c.splash = int(d.get("p", -1))
		c.cracked = bool(d.get("c", false))
		deck.append(c)
	changed.emit()
	return cf.get_value("run", "omen", "")

func spend(cost: int) -> bool:
	if rtec < cost:
		return false
	rtec -= cost
	changed.emit()
	return true
