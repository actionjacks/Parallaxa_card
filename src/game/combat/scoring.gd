class_name Scoring
## Pure scoring: selected cards + relic -> Chips x Mult and side effects. Deterministic,
## so the UI can show the exact outcome before the player commits ("the cards don't lie").

## Returns a dictionary: hand, chips (int), mult (float), damage (int), block (int), gnicie (int).
static func score(cards: Array, arcanum: ArcanumData) -> Dictionary:
	var hand: int = Poker.evaluate(cards)
	var base: Array = Poker.BASE[hand]
	var chips: int = int(base[0])
	var mult: float = float(base[1])
	var block: int = 0
	var gnicie: int = 0
	var has_furia: bool = false

	for c in cards:
		chips += c.chip_value()
		match c.keyword:
			CardData.Keyword.OSLONA:
				block += c.keyword_value
			CardData.Keyword.GNICIE:
				gnicie += c.keyword_value
			CardData.Keyword.FURIA:
				has_furia = true

	# Furia: x1.5 Mult when this play commits no block (aggression punishes playing defence).
	if has_furia and block == 0:
		mult *= 1.5

	# Arcanum relic: xMult when the played hand contains its aspect.
	if arcanum != null and arcanum.effect == ArcanumData.Effect.MULT_IF_ASPECT:
		for c in cards:
			if c.aspect == arcanum.effect_aspect:
				mult *= arcanum.effect_mult
				break

	return {
		"hand": hand,
		"chips": chips,
		"mult": mult,
		"damage": int(round(chips * mult)),
		"block": block,
		"gnicie": gnicie,
	}
