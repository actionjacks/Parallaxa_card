extends Node
## Autoload. Persistent state for one run (slice: one region): HP carried across fights, Rtec
## currency, the growing deck, and claimed Arcana relics. Screens read/write this; combat is fed
## from it and reports results back.

signal changed

const START_MAX_HP: int = 55
const REST_HEAL: int = 18       ## HP recovered after each non-boss fight (a "rest")

var player_hp: int = START_MAX_HP
var player_max_hp: int = START_MAX_HP
var rtec: int = 0                 ## alchemical currency (Mercury)
var deck: Array = []              ## Array[CardData]
var relics: Array = []            ## Array[ArcanumData]
var region: RegionData
var step: int = 0                 ## index into the region ladder (0..fights, last = boss)

func begin(p_region: RegionData) -> void:
	region = p_region
	player_max_hp = START_MAX_HP
	player_hp = player_max_hp
	rtec = 0
	deck = DeckLibrary.starter_deck()
	relics = []
	if region != null and region.starting_arcanum != null:
		relics.append(region.starting_arcanum)
	step = 0
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

func claim_relic(a: ArcanumData) -> void:
	if a != null:
		relics.append(a)
		changed.emit()

## Rest after a fight: heal REST_HEAL up to max. Returns the amount actually healed.
func rest() -> int:
	var before := player_hp
	player_hp = mini(player_max_hp, player_hp + REST_HEAL)
	changed.emit()
	return player_hp - before

func spend(cost: int) -> bool:
	if rtec < cost:
		return false
	rtec -= cost
	changed.emit()
	return true
