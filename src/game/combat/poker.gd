class_name Poker
## Pure poker-hand evaluation over a set of CardData (1..5 cards). Deterministic.
## Colours (aspects) act as suits: a flush is five cards of one aspect.

enum Hand { HIGH_CARD, PAIR, TWO_PAIR, THREE, STRAIGHT, FLUSH, FULL_HOUSE, FOUR, STRAIGHT_FLUSH, FIVE }

## Base [chips, mult] per hand — calibrated to Balatro level-1 values.
const BASE: Dictionary = {
	Hand.HIGH_CARD: [5, 1],
	Hand.PAIR: [10, 2],
	Hand.TWO_PAIR: [20, 2],
	Hand.THREE: [30, 3],
	Hand.STRAIGHT: [30, 4],
	Hand.FLUSH: [35, 4],
	Hand.FULL_HOUSE: [40, 4],
	Hand.FOUR: [60, 7],
	Hand.STRAIGHT_FLUSH: [100, 8],
	Hand.FIVE: [120, 12],
}

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
}

static func name_key(hand: int) -> String:
	return NAME_KEYS.get(hand, "")

static func evaluate(cards: Array) -> int:
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

static func _is_flush(cards: Array) -> bool:
	if cards.size() != 5:
		return false
	var a: int = cards[0].aspect
	for c in cards:
		if c.aspect != a:
			return false
	return true

static func _is_straight(cards: Array, counts: Dictionary) -> bool:
	if cards.size() != 5 or counts.size() != 5:
		return false
	var ranks: Array = counts.keys()
	ranks.sort()
	return int(ranks[4]) - int(ranks[0]) == 4  # Ace low only (rank 1)
