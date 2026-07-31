extends Node
## Autoload "Profile": the between-runs meta layer, INVERTED (docs/specs/spec_meta.md): the base
## card pool ships whole from day 1; everything bought or earned WIDENS the possibility space
## instead of gating it. Persists to user://profile.cfg (version 2).
##  * Sol (alchemical Salt) -- earned at the end of every run (defeat included),
##  * alternate starter decks and extra Arcana -- Sol sinks that add variety,
##  * achievements -- unlock new omens / draft Arcana / a starter deck,
##  * Veils -- the ascension ladder; permanent starter editions gate behind beaten Veils so
##    power creep only arrives alongside the difficulty that absorbs it.

signal changed

const PATH := "user://profile.cfg"

## Bot/test isolation: TEST_PROFILE=<tag> redirects persistence so automated playthroughs never
## pollute the player's real meta (Sol, achievements, veils).
static func _path() -> String:
	var t := OS.get_environment("TEST_PROFILE")
	return ("user://profile_%s.cfg" % t) if t != "" else PATH
const VERSION := 2
const MAX_VEIL := 5
const DECK_COST := 60
const ARCANA_COST := 40
const EDITION_COST := { CardData.Edition.FOIL: 40, CardData.Edition.HOLO: 80, CardData.Edition.POLYCHROME: 120 }
## An edition is buyable only after WINNING at this Veil tier (best_veil >= gate).
const EDITION_VEIL_GATE := { CardData.Edition.FOIL: 1, CardData.Edition.HOLO: 3, CardData.Edition.POLYCHROME: 5 }

## Sol sinks: alternate starter decks and boss-pool Arcana (see gen_content / DeckLibrary).
const SHOP_DECKS := ["reaper", "gardener"]
const ACH_DECKS := { "oracle": "ACH_JOURNEY" }   ## deck id -> achievement that unlocks it
const SHOP_ARCANA := {
	"emperor": "res://data/arcana/arcanum_emperor.tres",
	"chariot": "res://data/arcana/arcanum_chariot.tres",
}
const ACH_ARCANA := {
	"strength": ["ACH_UNTOUCHED", "res://data/arcana/arcanum_strength.tres"],
	"hermit": ["ACH_OVERKILL", "res://data/arcana/arcanum_hermit.tres"],
}
const ACH_ORDER := ["ACH_FIRST_WIN", "ACH_FIRST_SHOP", "ACH_FIRST_FLUSH", "ACH_FIRST_STAR",
	"ACH_FIRST_OMEN",
	"ACH_DEATH_FLUSH", "ACH_UNTOUCHED", "ACH_OVERKILL", "ACH_MISER", "ACH_JOURNEY",
	"ACH_MAGNUM", "ACH_REVERSED", "ACH_ELITE", "ACH_TITAN", "ACH_DAILY", "ACH_BEYOND", "ACH_DEPTH2",
	"ACH_VEIL_1", "ACH_VEIL_2", "ACH_VEIL_3", "ACH_VEIL_4", "ACH_VEIL_5",
	"ACH_WIN_REAPER", "ACH_WIN_GARDENER", "ACH_WIN_ORACLE", "ACH_LEVEL10"]

## The TAROCISTA: the player's persistent reader-of-cards persona. Every won duel pays XP; levels
## grant a rank title and a small Sol stipend (prestige, not power -- difficulty stays honest).
const RANKS := ["TAROT_RANK_1", "TAROT_RANK_2", "TAROT_RANK_3", "TAROT_RANK_4",
	"TAROT_RANK_5", "TAROT_RANK_6", "TAROT_RANK_7", "TAROT_RANK_8"]
const RANK_LEVELS := [1, 3, 5, 8, 12, 17, 23, 30]   ## level at which each rank begins
const LEVELUP_SOL := 10

var sol: int = 0
var wins: int = 0
var best_veil: int = -1            ## highest Veil beaten; -1 = never won
var achievements: Array = []       ## String ids, append-only
var owned_decks: Array = []        ## SHOP_DECKS ids bought with Sol
var selected_deck: String = "classic"
var owned_arcana: Array = []       ## SHOP_ARCANA ids bought with Sol (join the boss offer pool)
var starter_editions: Dictionary = {}   ## "deckid:index" -> CardData.Edition (permanent)
var level: int = 1
var xp: int = 0                    ## progress INTO the current level
var life: Dictionary = {}          ## lifetime statistics ledger (see LIFE_KEYS)
var flags: Dictionary = {}         ## one-shot moments already shown (covenant lines, Magnum reveal)
## COLOUR SEALS: one per Aspect, earned permanently by beating that biome's boss. Five seals
## close the pentagram and open the hidden biome. This is the between-runs goal that gives a
## defeat a direction -- you come back for the colour you are MISSING, not for another shuffle.
var seals: Array = []              ## Aspects.Id ints, unique, order-insensitive

## THE ASTROLOGER'S BOOK (docs/PLAN_TODO.md T3): best score per Daily Fate, kept forever.
## This exists because the game is DETERMINISTIC -- a fixed seed has a theoretical perfect run,
## so a personal best on a given day is a real, improvable number rather than a lucky streak.
## Local only: there is no server, and pretending otherwise would be a lie on the tin.
## date tag -> {"score": int, "won": bool, "fights": int}
var astrologer: Dictionary = {}

## Lifetime stat keys, in display order (values are ints; missing = 0).
const LIFE_KEYS := ["runs", "wins", "deaths", "fights", "elites", "bosses",
	"damage", "best_hit", "turns", "sol_earned", "arcana", "reversed"]

func _ready() -> void:
	load_profile()

static func card_key(c: CardData) -> String:
	return "%d_%d_%d_%d" % [c.rank, c.aspect, c.keyword, c.keyword_value]

## Called by the run's end (spread) screen EXACTLY once per run: every run feeds the meta.
func earn_run_reward(victory: bool, fights_won: int, veil: int = 0) -> int:
	@warning_ignore("integer_division")
	var effort: int = mini(10, RunState.stat_damage_total / 150)
	var amount := (35 + 3 * fights_won + 5 * veil) if victory else (5 + 3 * fights_won + effort + 2 * veil)
	sol += amount
	save_profile()
	changed.emit()
	return amount

func record_victory(p_veil: int) -> void:
	wins += 1
	best_veil = maxi(best_veil, p_veil)
	save_profile()
	changed.emit()

## Highest Veil selectable on New Run: one above the best beaten tier.
func veil_selectable_max() -> int:
	return 0 if best_veil < 0 else mini(best_veil + 1, MAX_VEIL)

func has_achievement(id: String) -> bool:
	return achievements.has(id)

const ACH_SOL := 10   ## every fulfilled achievement pays a small Salt bounty (first runs POP)

func grant_achievement(id: String) -> bool:
	if achievements.has(id):
		return false
	achievements.append(id)
	sol += ACH_SOL
	save_profile()
	changed.emit()
	return true

## End-of-run achievement sweep (also called mid-run at map arrivals with victory=false).
## Returns the FRESHLY granted ids so the spread screen can celebrate them.
func check_run_achievements(victory: bool) -> Array:
	var fresh: Array = []
	# First blood: the pops that make runs 1-3 feel alive (each pays ACH_SOL like all of them).
	if RunState.fights_won >= 1 and grant_achievement("ACH_FIRST_WIN"):
		fresh.append("ACH_FIRST_WIN")
	if RunState.stat_bought >= 1 and grant_achievement("ACH_FIRST_SHOP"):
		fresh.append("ACH_FIRST_SHOP")
	if RunState.stat_flush_played and grant_achievement("ACH_FIRST_FLUSH"):
		fresh.append("ACH_FIRST_FLUSH")
	if RunState.stat_star_used and grant_achievement("ACH_FIRST_STAR"):
		fresh.append("ACH_FIRST_STAR")
	if RunState.stat_omen_taken and grant_achievement("ACH_FIRST_OMEN"):
		fresh.append("ACH_FIRST_OMEN")
	if RunState.stat_death_flush_kill and grant_achievement("ACH_DEATH_FLUSH"):
		fresh.append("ACH_DEATH_FLUSH")
	if RunState.stat_untouched_fights >= 1 and grant_achievement("ACH_UNTOUCHED"):
		fresh.append("ACH_UNTOUCHED")
	if RunState.stat_best_hit >= 300 and grant_achievement("ACH_OVERKILL"):
		fresh.append("ACH_OVERKILL")
	if RunState.stat_max_rtec >= 25 and grant_achievement("ACH_MISER"):
		fresh.append("ACH_MISER")
	if victory and grant_achievement("ACH_JOURNEY"):
		fresh.append("ACH_JOURNEY")
	# Wave C: the prestige ledger (no unlocks -- proof, not power).
	if RunState.stat_best_hand == Poker.Hand.MAGNUM_OPUS and grant_achievement("ACH_MAGNUM"):
		fresh.append("ACH_MAGNUM")
	var any_reversed := false
	for a: ArcanumData in RunState.relics:
		if a.is_reversed:
			any_reversed = true
	if any_reversed and grant_achievement("ACH_REVERSED"):
		fresh.append("ACH_REVERSED")
	if RunState.stat_elites_slain >= 1 and grant_achievement("ACH_ELITE"):
		fresh.append("ACH_ELITE")
	if RunState.stat_best_hit >= 1000 and grant_achievement("ACH_TITAN"):
		fresh.append("ACH_TITAN")
	if victory and RunState.daily_tag != "" and grant_achievement("ACH_DAILY"):
		fresh.append("ACH_DAILY")
	if RunState.depth >= 1 and grant_achievement("ACH_BEYOND"):
		fresh.append("ACH_BEYOND")
	if RunState.depth >= 2 and grant_achievement("ACH_DEPTH2"):
		fresh.append("ACH_DEPTH2")
	if victory:
		for t in range(1, mini(RunState.veil, 5) + 1):
			if grant_achievement("ACH_VEIL_%d" % t):
				fresh.append("ACH_VEIL_%d" % t)
		var deck_ach := {"reaper": "ACH_WIN_REAPER", "gardener": "ACH_WIN_GARDENER", "oracle": "ACH_WIN_ORACLE"}
		if deck_ach.has(RunState.run_deck_id) and grant_achievement(deck_ach[RunState.run_deck_id]):
			fresh.append(deck_ach[RunState.run_deck_id])
	if level >= 10 and grant_achievement("ACH_LEVEL10"):
		fresh.append("ACH_LEVEL10")
	return fresh

# ---------------------------------------------------------------- one-shot moments

## One-shot ceremony gate: returns true the FIRST time a key is claimed, false ever after.
## Used for the diegetic covenant lines and the Magnum Opus reveal -- moments that must land
## once with full weight and never nag again.
## THE SECRET HANDS (docs/todo.md par.4: "gracze beda odkrywac z wypiekami na twarzy"). Until a
## spread has been landed once, the paytable shows it as "? ? ?" and the best-available hint will
## not name it. Kept in the profile, not the run: a secret discovered stays discovered.
func hand_found(hand: int) -> bool:
	return bool(flags.get("hand_%d" % hand, false))

## Returns true the FIRST time this hand is landed (so the scene can announce the discovery).
func discover_hand(hand: int) -> bool:
	return claim_once("hand_%d" % hand)

func claim_once(key: String) -> bool:
	if flags.get(key, false):
		return false
	flags[key] = true
	save_profile()
	return true

## The nearest concrete Sol goal (shown on the defeat spread: a death must fund SOMETHING).
## Returns {"name_key": String, "cost": int} or {} when every sink is owned.
func nearest_goal() -> Dictionary:
	# Decks FIRST: a losing player can use a new starter immediately; boss-pool arcana only
	# matter to someone who reaches boss claims, so they come second.
	for id in SHOP_DECKS:
		if not owned_decks.has(id):
			return {"name_key": DeckLibrary.deck_name_key(id), "cost": DECK_COST}
	for id in SHOP_ARCANA:
		if not owned_arcana.has(id):
			var nk := "ARCANUM_CESARZA" if id == "emperor" else "ARCANUM_RYDWANU"
			return {"name_key": nk, "cost": ARCANA_COST}
	return {}

# ---------------------------------------------------------------- tarocista (XP / levels / life)

func life_stat(key: String) -> int:
	return int(life.get(key, 0))

func _life_add(key: String, amount: int) -> void:
	life[key] = life_stat(key) + amount

func _life_max(key: String, value: int) -> void:
	life[key] = maxi(life_stat(key), value)

## XP needed to finish the given level (a gentle ramp; no cap -- the reader keeps reading).
static func xp_to_next(lv: int) -> int:
	return 100 + (lv - 1) * 60

## XP one won duel pays: deeper regions pay more, elites double, bosses triple.
static func fight_xp(is_boss: bool, is_elite: bool, region_index: int) -> int:
	var base := 8 + 4 * region_index
	if is_boss:
		return base * 3
	if is_elite:
		return base * 2
	return base

## Grant XP; returns the number of levels gained (each pays LEVELUP_SOL Sol). Saved by callers
## via record_run_end/save_profile -- mid-run grants persist with the next profile write.
func add_xp(amount: int) -> int:
	xp += amount
	var gained := 0
	while xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		gained += 1
		sol += LEVELUP_SOL
	if gained > 0:
		changed.emit()
	# XP, levels and the level-up Sol were held only in memory: the profile is written by other
	# calls, so a player who closed the game after a won duel lost everything that duel paid.
	save_profile()
	return gained

## The tarocista's current rank title key.
func rank_key() -> String:
	var out: String = RANKS[0]
	for i in RANKS.size():
		if level >= RANK_LEVELS[i]:
			out = RANKS[i]
	return out

## End-of-run ledger: folds the run's statistics into the lifetime ledger and pays the run-end
## XP bonus. Called EXACTLY once per run end (the spread screen). Returns {"xp": int, "levels": int}.
func record_run_end(victory: bool) -> Dictionary:
	_life_add("runs", 1)
	_record_daily(victory)
	_life_add("wins", 1 if victory else 0)
	_life_add("deaths", 0 if victory else 1)
	_life_add("fights", RunState.fights_won)
	_life_add("elites", RunState.stat_elites_slain)
	_life_add("bosses", RunState.stat_regions_cleared)
	_life_add("damage", RunState.stat_damage_total)
	_life_max("best_hit", RunState.stat_best_hit)
	_life_add("turns", RunState.stat_turns_total)
	_life_add("sol_earned", RunState.stat_sol_earned)
	_life_add("arcana", RunState.relics.size())
	var reversed_count := 0
	for a: ArcanumData in RunState.relics:
		if a.is_reversed:
			reversed_count += 1
	_life_add("reversed", reversed_count)
	var bonus := (100 + 10 * RunState.veil) if victory else 15
	var levels := add_xp(bonus)
	save_profile()
	changed.emit()
	return {"xp": bonus, "levels": levels}

func buy_deck(id: String) -> bool:
	if owned_decks.has(id) or not SHOP_DECKS.has(id) or sol < DECK_COST:
		return false
	sol -= DECK_COST
	owned_decks.append(id)
	save_profile()
	changed.emit()
	return true

func buy_arcana(id: String) -> bool:
	if owned_arcana.has(id) or not SHOP_ARCANA.has(id) or sol < ARCANA_COST:
		return false
	sol -= ARCANA_COST
	owned_arcana.append(id)
	save_profile()
	changed.emit()
	return true

## Decks the player can start with: classic + bought + achievement-earned.
func available_decks() -> Array:
	var out: Array = ["classic"]
	for id in owned_decks:
		out.append(id)
	for id in ACH_DECKS:
		if has_achievement(ACH_DECKS[id]):
			out.append(id)
	return out

## Purchased Arcana join every boss reward as the third option (the widened pool).
func boss_pool_arcana() -> Array:
	var out: Array = []
	for id in owned_arcana:
		var a = load(SHOP_ARCANA[id])
		if a != null:
			out.append(a)
	return out

## Achievement Arcana join the run-opening draft pool.
func draft_extra_arcana() -> Array:
	var out: Array = []
	for id in ACH_ARCANA:
		if has_achievement(ACH_ARCANA[id][0]):
			var a = load(ACH_ARCANA[id][1])
			if a != null:
				out.append(a)
	return out

## An edition is available only once the Veil that absorbs it has been beaten.
func edition_allowed(ed: int) -> bool:
	return best_veil >= int(EDITION_VEIL_GATE.get(ed, 99))

## Next edition on the permanent ladder for a starter card, or NONE when maxed.
func next_starter_edition(deck_id: String, index: int) -> int:
	var cur: int = starter_editions.get("%s:%d" % [deck_id, index], CardData.Edition.NONE)
	match cur:
		CardData.Edition.NONE: return CardData.Edition.FOIL
		CardData.Edition.FOIL: return CardData.Edition.HOLO
		CardData.Edition.HOLO: return CardData.Edition.POLYCHROME
	return CardData.Edition.NONE

func upgrade_starter(deck_id: String, index: int) -> bool:
	var nxt := next_starter_edition(deck_id, index)
	if nxt == CardData.Edition.NONE or not edition_allowed(nxt):
		return false
	var cost: int = EDITION_COST[nxt]
	if sol < cost:
		return false
	sol -= cost
	starter_editions["%s:%d" % [deck_id, index]] = nxt
	save_profile()
	changed.emit()
	return true

func save_profile() -> void:
	var cf := ConfigFile.new()
	cf.set_value("meta", "version", VERSION)
	cf.set_value("meta", "sol", sol)
	cf.set_value("meta", "wins", wins)
	cf.set_value("meta", "best_veil", best_veil)
	cf.set_value("meta", "achievements", achievements)
	cf.set_value("meta", "owned_decks", owned_decks)
	cf.set_value("meta", "selected_deck", selected_deck)
	cf.set_value("meta", "owned_arcana", owned_arcana)
	cf.set_value("meta", "starter_editions", starter_editions)
	cf.set_value("meta", "level", level)
	cf.set_value("meta", "xp", xp)
	cf.set_value("meta", "life", life)
	cf.set_value("meta", "flags", flags)
	cf.set_value("meta", "seals", seals)
	cf.set_value("meta", "astrologer", astrologer)
	cf.save(_path())

func load_profile() -> void:
	var cf := ConfigFile.new()
	if cf.load(_path()) != OK:
		return
	var v: int = cf.get_value("meta", "version", 1)
	if v < 2:
		# v1 -> v2 migration: the wave-2 unlock gate is gone (full refund, 25 Sol each) and the
		# old int-keyed editions are refunded at cumulative ladder cost -- Veil gates re-price them.
		var old_unlocked: Array = cf.get_value("meta", "unlocked", [])
		sol = int(cf.get_value("meta", "sol", 0)) + 25 * old_unlocked.size()
		var old_eds: Dictionary = cf.get_value("meta", "starter_editions", {})
		for k in old_eds:
			match int(old_eds[k]):
				CardData.Edition.FOIL: sol += 40
				CardData.Edition.HOLO: sol += 120
				CardData.Edition.POLYCHROME: sol += 240
		starter_editions = {}
		save_profile()
		return
	sol = cf.get_value("meta", "sol", 0)
	wins = cf.get_value("meta", "wins", 0)
	best_veil = cf.get_value("meta", "best_veil", -1)
	achievements = cf.get_value("meta", "achievements", [])
	owned_decks = cf.get_value("meta", "owned_decks", [])
	selected_deck = cf.get_value("meta", "selected_deck", "classic")
	owned_arcana = cf.get_value("meta", "owned_arcana", [])
	starter_editions = cf.get_value("meta", "starter_editions", {})
	level = cf.get_value("meta", "level", 1)
	xp = cf.get_value("meta", "xp", 0)
	life = cf.get_value("meta", "life", {})
	flags = cf.get_value("meta", "flags", {})
	seals = cf.get_value("meta", "seals", [])
	astrologer = cf.get_value("meta", "astrologer", {})


## A Daily Fate keeps only the BEST attempt, so the entry is a record to beat rather than a log.
## Score is the run's total damage: the one number that rewards playing the seed well rather than
## merely surviving it.
func _record_daily(victory: bool) -> void:
	if RunState.daily_tag == "":
		return
	var score: int = RunState.stat_damage_total
	var prev: Dictionary = astrologer.get(RunState.daily_tag, {})
	# THE FIRST READING IS THE READING. Keeping the best of unlimited retries made the Book a
	# measure of patience rather than of play, and destroyed the one thing a shared daily seed is
	# for: comparing what people did with the SAME cards.
	if prev.is_empty():
		astrologer[RunState.daily_tag] = {
			"score": score, "won": victory, "fights": RunState.fights_won,
		}
		save_profile()

## The book, newest first -- what the menu prints.
func astrologer_entries(limit: int = 8) -> Array:
	var keys: Array = astrologer.keys()
	keys.sort()
	keys.reverse()
	var out: Array = []
	for k in keys.slice(0, limit):
		var e: Dictionary = astrologer[k]
		out.append({"tag": k, "score": int(e.get("score", 0)),
			"won": bool(e.get("won", false)), "fights": int(e.get("fights", 0))})
	return out

# ---------------------------------------------------------------- colour seals

## Grant the seal of one Aspect. Idempotent: a colour is sealed once, however many times you
## beat its biome. Returns true only on the FIRST time, so the ceremony fires once.
func grant_seal(aspect: int) -> bool:
	if aspect < 0 or seals.has(aspect):
		return false
	seals.append(aspect)
	save_profile()
	return true

func has_seal(aspect: int) -> bool:
	return seals.has(aspect)

## The pentagram is closed: every colour answered at least once.
func seals_complete() -> bool:
	return seals.size() >= 5

## Which colours are still missing -- the menu shows this as the standing invitation.
func seals_missing() -> Array:
	var out: Array = []
	for a in [Aspects.Id.LIFE, Aspects.Id.MIND, Aspects.Id.DEATH, Aspects.Id.CHAOS, Aspects.Id.NATURE]:
		if not seals.has(a):
			out.append(a)
	return out
