class_name Poker
## Pure poker-hand evaluation over a set of CardData (1..5 cards). Deterministic.
## Colours (aspects) act as suits: a flush is five cards of one aspect.

## MAGNUM_OPUS (appended, enum append-only): the secret apex -- five of a kind, all one Aspect.
## Never dealt from the starter (max 3 of a rank there); only ENGINEERED via drafted duplicates.
## PENTAGRAM and FULL_COURT are the SECRET hands (docs/todo.md): appended, never inserted.
##  PENTAGRAM  five cards, one of EACH Aspect -- the pentagram itself
##  FULL_COURT Page, Knight, Queen and King together -- the whole court of the Minor Arcana
enum Hand { HIGH_CARD, PAIR, TWO_PAIR, THREE, STRAIGHT, FLUSH, FULL_HOUSE, FOUR, STRAIGHT_FLUSH, FIVE, MAGNUM_OPUS, PENTAGRAM, FULL_COURT }

## Base [chips, mult] per hand — payouts follow this deck's TRUE rarity, not inherited 4-suit lore.
##
## THE FLUSH CORRECTION: standard poker ranks hands for a FOUR-suit deck. This deck has FIVE
## Aspects, which re-orders everything that depends on suits. Counted exhaustively over all
## C(40,5) hands of the pentacle deck (tools/dev/probe_deckmath.gd, and the exact combinatorics):
##   full house 1 in 118   four of a kind 1 in 470   FLUSH 1 in 2531
## The flush is the third-hardest hand in the game -- five cards drawn from a fifth of the deck --
## yet it used to pay sixth (35x4=140, below a full house). It is now priced where its rarity puts
## it: above four of a kind, below a straight flush. This is also the mechanical spine of the
## colour journey: gathering ONE Aspect is the game's central metaphor, so it has to pay like it.
const BASE: Dictionary = {
	Hand.HIGH_CARD: [5, 1],
	Hand.PAIR: [10, 2],
	Hand.TWO_PAIR: [20, 2],
	Hand.THREE: [30, 3],
	Hand.STRAIGHT: [30, 4],
	Hand.FLUSH: [70, 8],
	Hand.FULL_HOUSE: [40, 4],
	Hand.FOUR: [60, 7],
	Hand.STRAIGHT_FLUSH: [100, 10],
	Hand.FIVE: [120, 12],
	Hand.MAGNUM_OPUS: [160, 16],
	# MEASURED on the live deck (probe_deckmath): a Pentagram is available in 40.2% of hands.
	# Paying it like a Flush would make it the DEFAULT play and kill the Flush we just repaired,
	# so its power is TEMPO, not damage: modest chips and a discard handed back (Scoring returns
	# "refund_discard"). Pentagram versus Full House then costs the player something either way.
	Hand.PENTAGRAM: [30, 3],
	# The full court cannot be dealt from a starter deck at all (0.00% measured -- courts arrive
	# only from rewards and shops), so it is pure engineering and paid like it.
	Hand.FULL_COURT: [110, 9],
}

## Payout value of a hand at a given level -- the ONLY correct way to compare two hands in this
## game, because the enum order is legacy 4-suit ranking and no longer tracks what pays more.
static func value_of(hand: int, level: int = 0) -> float:
	var b: Array = leveled_base(hand, level)
	return float(b[0]) * float(b[1])

const NAME_KEYS: Dictionary = {
	Hand.HIGH_CARD: "HAND_HIGH_CARD",
	Hand.PAIR: "HAND_PAIR",
	Hand.TWO_PAIR: "HAND_TWO_PAIR",
	Hand.THREE: "HAND_THREE",
	Hand.STRAIGHT: "HAND_STRAIGHT",
	Hand.FLUSH: "HAND_FLUSH",
	Hand.FULL_HOUSE: "HAND_FULL_HOUSE",
	Hand.FOUR: "HAND_FOUR",
	Hand.STRAIGHT_FLUSH: "HAND_STRAIGHT_FLUSH",
	Hand.FIVE: "HAND_FIVE",
	Hand.MAGNUM_OPUS: "HAND_MAGNUM_OPUS",
	Hand.PENTAGRAM: "HAND_PENTAGRAM",
	Hand.FULL_COURT: "HAND_FULL_COURT",
}

## Per-level base gains for each hand ("Star" consumables level hands up, Balatro-Planet style).
const LEVEL_UP: Dictionary = {
	Hand.HIGH_CARD: [10, 1],
	Hand.PAIR: [15, 1],
	Hand.TWO_PAIR: [20, 1],
	Hand.THREE: [20, 2],
	Hand.STRAIGHT: [30, 3],
	Hand.FLUSH: [25, 3],
	Hand.FULL_HOUSE: [25, 2],
	Hand.FOUR: [30, 3],
	Hand.STRAIGHT_FLUSH: [40, 4],
	Hand.FIVE: [50, 3],
	Hand.MAGNUM_OPUS: [50, 5],
	Hand.PENTAGRAM: [20, 2],
	Hand.FULL_COURT: [35, 4],
}

## Base [chips, mult] for a hand at the given level (level 0 = the BASE table).
static func leveled_base(hand: int, level: int) -> Array:
	var base: Array = BASE[hand]
	var up: Array = LEVEL_UP[hand]
	return [int(base[0]) + level * int(up[0]), float(base[1]) + level * float(up[1])]

## THE CHART READ UPSIDE DOWN (INVERTED_TABLE boss). Hands swap places with their mirror in the
## payout order: the cheapest pays what the dearest used to, and a pair outscores a flush. The
## whole run's instinct becomes the wrong instinct, which is the point -- and it stays exact,
## because it is a permutation of the same table the paytable prints.
static func mirrored(hand: int) -> int:
	var order: Array = BASE.keys()
	order.sort_custom(func(a, b): return value_of(a) < value_of(b))
	var i: int = order.find(hand)
	if i < 0:
		return hand
	return int(order[order.size() - 1 - i])

static func name_key(hand: int) -> String:
	return NAME_KEYS.get(hand, "")

## THE SECRET HANDS never DEMOTE a hand. A straight of five different Aspects is both a Straight
## and a Pentagram; a Pentagram pays 90 and a Straight 120, so it stays a Straight. The rule is
## simply "take whichever pays more", which also means adding a secret hand can never quietly
## make an existing hand worse.
static func evaluate(cards: Array) -> int:
	var plain := _evaluate_plain(cards)
	# FOUR cards can already be a secret hand: the whole court IS four cards, and demanding a
	# fifth meant the exact act todo.md describes -- laying down Page, Knight, Queen and King --
	# scored as a high card. PENTAGRAM still needs five (one seat per Aspect); _secret_hand checks.
	if cards.size() < 4 or cards.size() > 5:
		return plain
	var secret := _secret_hand(cards)
	if secret < 0:
		return plain
	return secret if value_of(secret) > value_of(plain) else plain

## FULL_COURT (Page+Knight+Queen+King) or PENTAGRAM (one card of every Aspect), else -1.
static func _secret_hand(cards: Array) -> int:
	var court := {}
	for c in cards:
		if c.rank >= 11:
			court[c.rank] = true
	if court.size() == 4:
		return Hand.FULL_COURT
	# Splashed cards make this a MATCHING problem, not a count: a hybrid can fill whichever
	# colour seat is still empty, so the question is whether five different Aspects can be
	# assigned one per card.
	if cards.size() == 5 and _covers_five(cards):
		return Hand.PENTAGRAM
	return -1

static func _evaluate_plain(cards: Array) -> int:
	if cards.is_empty():
		return Hand.HIGH_CARD
	var counts: Dictionary = {}
	for c in cards:
		counts[c.rank] = int(counts.get(c.rank, 0)) + 1
	var freq: Array = counts.values()
	freq.sort()
	freq.reverse()  # descending
	var top: int = freq[0]
	var flush := _is_flush(cards)
	var straight := _is_straight(cards, counts)
	# One rank AND one Aspect: the Great Work. top==5 implies no straight, so no clash below.
	if top == 5 and flush:
		return Hand.MAGNUM_OPUS
	if flush and straight:
		return Hand.STRAIGHT_FLUSH
	if top == 5:
		return Hand.FIVE
	if top == 4:
		return Hand.FOUR
	if top == 3 and freq.size() >= 2 and int(freq[1]) == 2:
		return Hand.FULL_HOUSE
	if flush:
		return Hand.FLUSH
	if straight:
		return Hand.STRAIGHT
	if top == 3:
		return Hand.THREE
	if top == 2 and freq.size() >= 2 and int(freq[1]) == 2:
		return Hand.TWO_PAIR
	if top == 2:
		return Hand.PAIR
	return Hand.HIGH_CARD

## A flush is five cards sharing ONE colour. A splashed card counts as either of its two, so the
## question is no longer "are all aspects equal" but "does some colour appear on every card".
## Can these five cards be assigned five DIFFERENT Aspects, one each? With splashed cards this
## is a matching problem, not a count -- five cards over five colours is small enough to solve by
## exhaustive assignment, and it stays deterministic.
static func _covers_five(cards: Array) -> bool:
	return _assign(cards, 0, {})

static func _assign(cards: Array, i: int, used: Dictionary) -> bool:
	if i >= cards.size():
		return used.size() == 5
	for a in cards[i].aspects():
		if used.has(int(a)):
			continue
		used[int(a)] = true
		if _assign(cards, i + 1, used):
			return true
		used.erase(int(a))
	return false

static func _is_flush(cards: Array) -> bool:
	if cards.size() != 5:
		return false
	for a in cards[0].aspects():
		var all := true
		for c in cards:
			if not c.has_aspect(int(a)):
				all = false
				break
		if all:
			return true
	return false

static func _is_straight(cards: Array, counts: Dictionary) -> bool:
	if cards.size() != 5 or counts.size() != 5:
		return false
	var ranks: Array = counts.keys()
	ranks.sort()
	return int(ranks[4]) - int(ranks[0]) == 4  # Ace low only (rank 1)
