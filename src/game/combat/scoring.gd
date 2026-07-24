class_name Scoring
## Pure scoring: selected cards + relic + light combat context -> Chips x Mult and side effects.
## Deterministic, so the UI can show the exact outcome before the player commits.
## ctx keys (optional): "grave" (cards in the used pile), "plays" (plays already made this fight).

static func score(cards: Array, relics: Array, ctx: Dictionary = {}) -> Dictionary:
	var grave: int = int(ctx.get("grave", 0))
	var plays: int = int(ctx.get("plays", 0))

	var hand: int = Poker.evaluate(cards)
	var base: Array = Poker.BASE[hand]
	var chips: int = int(base[0])
	var mult: float = float(base[1])
	var block: int = 0
	var heal: int = 0
	var gnicie: int = 0
	var flat: int = 0
	var has_furia: bool = false
	var poly: float = 1.0

	var aspect_counts: Dictionary = {}
	for c in cards:
		aspect_counts[c.aspect] = int(aspect_counts.get(c.aspect, 0)) + 1

	for c in cards:
		chips += c.chip_value()
		match c.edition:
			CardData.Edition.FOIL:
				chips += 15
			CardData.Edition.HOLO:
				mult += 2.0
			CardData.Edition.POLYCHROME:
				poly *= 1.3
		match c.keyword:
			CardData.Keyword.OSLONA:
				block += c.keyword_value
			CardData.Keyword.OPATRZNOSC:
				heal += c.keyword_value
			CardData.Keyword.GNICIE:
				gnicie += c.keyword_value
			CardData.Keyword.SPALENIE:
				flat += c.keyword_value
			CardData.Keyword.ECHO:
				chips += c.keyword_value * plays
			CardData.Keyword.ZNIWO:
				mult += float(c.keyword_value * grave)
			CardData.Keyword.BUJNOSC:
				if int(aspect_counts[c.aspect]) >= 3:
					chips += c.keyword_value
			CardData.Keyword.FURIA:
				has_furia = true

	# Furia: x1.5 Mult when this play commits no block (aggression punishes playing defence).
	if has_furia and block == 0:
		mult *= 1.5

	# Relics stack; every per-play effect resolves HERE so the preview shows the exact outcome.
	for relic in relics:
		if relic == null:
			continue
		match relic.effect:
			ArcanumData.Effect.MULT_IF_ASPECT:
				for c in cards:
					if c.aspect == relic.effect_aspect:
						mult *= relic.effect_mult
						break
			ArcanumData.Effect.PACT_MULT:
				mult *= relic.effect_mult   # the Devil always pays out; the bill arrives on the enemy's turn
			ArcanumData.Effect.BLOCK_ON_PLAY:
				block += relic.effect_value
			ArcanumData.Effect.HEAL_ON_PLAY:
				heal += relic.effect_value

	mult *= poly

	return {
		"hand": hand,
		"chips": chips,
		"mult": mult,
		"damage": int(round(chips * mult)) + flat,
		"block": block,
		"heal": heal,
		"gnicie": gnicie,
		"flat": flat,
	}
