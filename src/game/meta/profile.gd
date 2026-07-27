extends Node
## Autoload "Profile": the between-runs meta layer (todo.md). Persists to user://profile.cfg.
##  * Sol (alchemical Salt) -- the meta currency earned at the end of every run,
##  * unlocked wave-2 cards -- Growth/Symbiosis/Leech/Curse cards start LOCKED and are bought
##    into the reward pool from the Collection,
##  * permanent starter editions -- upgrade a starter card's edition for good
##    (standard -> Foil -> Holo -> Polychrome: the visual evolution ladder).

signal changed

const PATH := "user://profile.cfg"
const UNLOCK_COST := 25
const EDITION_COST := { CardData.Edition.FOIL: 40, CardData.Edition.HOLO: 80, CardData.Edition.POLYCHROME: 120 }

var sol: int = 0
var unlocked: Array = []            ## keys of wave-2 pool cards bought into the pool
var starter_editions: Dictionary = {}   ## starter index -> CardData.Edition (permanent)

func _ready() -> void:
	load_profile()

static func card_key(c: CardData) -> String:
	return "%d_%d_%d_%d" % [c.rank, c.aspect, c.keyword, c.keyword_value]

## Wave-2 keywords are the meta-locked set.
static func is_meta_locked_keyword(kw: int) -> bool:
	return kw in [CardData.Keyword.WZROST, CardData.Keyword.SYMBIOZA, CardData.Keyword.PIJAWKA, CardData.Keyword.KLATWA]

func is_unlocked(c: CardData) -> bool:
	return not is_meta_locked_keyword(c.keyword) or unlocked.has(card_key(c))

func unlock(c: CardData) -> bool:
	if is_unlocked(c) or sol < UNLOCK_COST:
		return false
	sol -= UNLOCK_COST
	unlocked.append(card_key(c))
	save_profile()
	changed.emit()
	return true

## Next edition on the permanent ladder for a starter card, or NONE when maxed.
func next_starter_edition(index: int) -> int:
	var cur: int = starter_editions.get(index, CardData.Edition.NONE)
	match cur:
		CardData.Edition.NONE: return CardData.Edition.FOIL
		CardData.Edition.FOIL: return CardData.Edition.HOLO
		CardData.Edition.HOLO: return CardData.Edition.POLYCHROME
	return CardData.Edition.NONE

func upgrade_starter(index: int) -> bool:
	var nxt := next_starter_edition(index)
	if nxt == CardData.Edition.NONE:
		return false
	var cost: int = EDITION_COST[nxt]
	if sol < cost:
		return false
	sol -= cost
	starter_editions[index] = nxt
	save_profile()
	changed.emit()
	return true

## Called by the run's end screens: victory pays the Journey, defeat pays the fights.
func earn_run_reward(victory: bool, fights_won: int) -> int:
	var amount := (30 + 2 * fights_won) if victory else fights_won
	sol += amount
	save_profile()
	changed.emit()
	return amount

func save_profile() -> void:
	var cf := ConfigFile.new()
	cf.set_value("meta", "sol", sol)
	cf.set_value("meta", "unlocked", unlocked)
	cf.set_value("meta", "starter_editions", starter_editions)
	cf.save(PATH)

func load_profile() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	sol = cf.get_value("meta", "sol", 0)
	unlocked = cf.get_value("meta", "unlocked", [])
	starter_editions = cf.get_value("meta", "starter_editions", {})
