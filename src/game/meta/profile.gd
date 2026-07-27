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
const ACH_ORDER := ["ACH_DEATH_FLUSH", "ACH_UNTOUCHED", "ACH_OVERKILL", "ACH_MISER", "ACH_JOURNEY"]

var sol: int = 0
var wins: int = 0
var best_veil: int = -1            ## highest Veil beaten; -1 = never won
var achievements: Array = []       ## String ids, append-only
var owned_decks: Array = []        ## SHOP_DECKS ids bought with Sol
var selected_deck: String = "classic"
var owned_arcana: Array = []       ## SHOP_ARCANA ids bought with Sol (join the boss offer pool)
var starter_editions: Dictionary = {}   ## "deckid:index" -> CardData.Edition (permanent)

func _ready() -> void:
	load_profile()

static func card_key(c: CardData) -> String:
	return "%d_%d_%d_%d" % [c.rank, c.aspect, c.keyword, c.keyword_value]

## Called by the run's end (spread) screen EXACTLY once per run: every run feeds the meta.
func earn_run_reward(victory: bool, fights_won: int, veil: int = 0) -> int:
	var amount := (35 + 3 * fights_won + 5 * veil) if victory else (5 + 3 * fights_won + 2 * veil)
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

func grant_achievement(id: String) -> bool:
	if achievements.has(id):
		return false
	achievements.append(id)
	save_profile()
	changed.emit()
	return true

## End-of-run achievement sweep (also called mid-run at map arrivals with victory=false).
## Returns the FRESHLY granted ids so the spread screen can celebrate them.
func check_run_achievements(victory: bool) -> Array:
	var fresh: Array = []
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
	return fresh

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
