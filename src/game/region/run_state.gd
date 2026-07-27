extends Node
## Autoload. Persistent state for one run (slice: one region): HP carried across fights, Rtec
## currency, the growing deck, and claimed Arcana relics. Screens read/write this; combat is fed
## from it and reports results back.

signal changed

const START_MAX_HP: int = 55
const REST_HEAL: int = 12       ## HP recovered after each non-boss fight (a "rest")

var player_hp: int = START_MAX_HP
var player_max_hp: int = START_MAX_HP
var rtec: int = 0                 ## alchemical currency (Mercury)
var deck: Array = []              ## Array[CardData]
var relics: Array = []            ## Array[ArcanumData]
var region: RegionData
var region_index: int = 0         ## position on the journey (0-based)
var step: int = 0                 ## index into the region ladder (0..fights, last = boss)
var fights_won: int = 0
var fights: Array = []            ## this run's rolled ladder (Array[EnemyData])
var hand_levels: Dictionary = {}  ## Poker.Hand -> level, raised by Star consumables (run-scoped)

## The run's ONE sanctioned randomness source (design: combat deterministic, REWARDS variable).
## Seeded fresh per run: reward drafts, shop offers and the run-start deck order differ run to run,
## while everything inside a fight stays exact and preview-safe.
var rng := RandomNumberGenerator.new()

func begin(p_region: RegionData) -> void:
	rng.randomize()
	region_index = 0
	region = p_region
	player_max_hp = START_MAX_HP
	player_hp = player_max_hp
	rtec = 0
	deck = DeckLibrary.starter_deck()
	_shuffle(deck)   # run-start order varies; within the run draws stay deterministic
	relics = []
	# Starting relic comes from the run-opening DRAFT (run.gd); legacy fallback only when the
	# region has no pool authored.
	if region != null and region.starting_pool.is_empty() and region.starting_arcanum != null:
		relics.append(region.starting_arcanum)
	step = 0
	fights_won = 0
	hand_levels = {}
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

func claim_relic(a: ArcanumData) -> void:
	if a != null:
		relics.append(a)
		changed.emit()

## Step into the NEXT region of the journey: run state (deck, relics, Mercury) carries over,
## the ladder resets, new opponents are rolled, and the traveller gets a full night's rest.
func enter_region(p_region: RegionData, index: int) -> void:
	region = p_region
	region_index = index
	step = 0
	player_hp = player_max_hp   # full heal between regions
	fights = []
	if not region.fight_pool_1.is_empty():
		fights.append(pick_offers(region.fight_pool_1, 1)[0])
	if not region.fight_pool_2.is_empty():
		fights.append(pick_offers(region.fight_pool_2, 1)[0])
	if fights.is_empty():
		for f in region.fights:
			fights.append(f)
	changed.emit()

## Rest after a fight: heal REST_HEAL up to max. Returns the amount actually healed.
func rest() -> int:
	var before := player_hp
	player_hp = mini(player_max_hp, player_hp + REST_HEAL)
	changed.emit()
	return player_hp - before

## N distinct random cards from a pool (the variable-reward layer: drafts and shop offers).
func pick_offers(pool: Array, n: int) -> Array:
	var idx: Array = range(pool.size())
	_shuffle(idx)
	var out: Array = []
	for i in mini(n, idx.size()):
		out.append(pool[idx[i]])
	return out

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
	var relic_paths: Array = []
	for a in relics:
		relic_paths.append(a.resource_path)
	cf.set_value("run", "relics", relic_paths)
	var fight_paths: Array = []
	for f in fights:
		fight_paths.append(f.resource_path)
	cf.set_value("run", "fights", fight_paths)
	var cards: Array = []
	for c in deck:
		cards.append({"r": c.rank, "a": c.aspect, "k": c.keyword, "v": c.keyword_value, "e": c.edition})
	cf.set_value("run", "deck", cards)
	cf.save(RUN_SAVE)

## Restores the saved run. Returns the pending omen id ("" when none). Deck growth (WZROST ramp)
## is intentionally transient and resets on load.
func load_run() -> String:
	var cf := ConfigFile.new()
	if cf.load(RUN_SAVE) != OK:
		return ""
	rng.randomize()
	region = load(cf.get_value("run", "region_path", ""))
	region_index = cf.get_value("run", "region_index", 0)
	step = cf.get_value("run", "step", 0)
	player_max_hp = cf.get_value("run", "max_hp", START_MAX_HP)
	player_hp = cf.get_value("run", "hp", player_max_hp)
	rtec = cf.get_value("run", "rtec", 0)
	fights_won = cf.get_value("run", "fights_won", 0)
	hand_levels = cf.get_value("run", "hand_levels", {})
	relics = []
	for p in cf.get_value("run", "relics", []):
		var a = load(p)
		if a != null:
			relics.append(a)
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
		deck.append(c)
	changed.emit()
	return cf.get_value("run", "omen", "")

func spend(cost: int) -> bool:
	if rtec < cost:
		return false
	rtec -= cost
	changed.emit()
	return true
