class_name Scoring
## Pure scoring: selected cards + relics + light combat context -> Chips x Mult and side effects.
## Deterministic, so the UI can show the exact outcome before the player commits.
## ctx keys (optional): "law" (RegionData.Law of the biome), "grave" (cards in the used pile),
##   "plays" (plays already made this fight),
## "hand_levels", "klatwa", "hand_history" (Poker.Hand per play so far -- Kombinat streaks),
## "heal_budget" (remaining per-fight heal pool; default huge keeps old callers/tests exact).
##
## Canonical pipeline order (docs/specs/spec_power.md par.0) -- every step pure and preview-exact:
##  1. hand -> leveled base chips/mult
##  2. per-card: chip material, editions, flat keywords
##  3. LAWINA retrigger  4. FURIA  5. KOMBINAT streak xMult  6. PRZECIAZENIE glass xMult
##  7. relics (with the Magician's MAGNIFY amplification)  8. Polychrome  9. Klatwa + flat
##  10. leech -> heal, then the heal-budget clamp

static func score(cards: Array, relics: Array, ctx: Dictionary = {}) -> Dictionary:
	var grave: int = int(ctx.get("grave", 0))
	var plays: int = int(ctx.get("plays", 0))
	var levels: Dictionary = ctx.get("hand_levels", {})
	var klatwa: int = int(ctx.get("klatwa", 0))   # stacked Curse on the enemy: +% damage taken
	var history: Array = ctx.get("hand_history", [])

	var hand: int = Poker.evaluate(cards)
	var base: Array = Poker.leveled_base(hand, int(levels.get(hand, 0)))
	var chips: int = int(base[0])
	var mult: float = float(base[1])
	var block: int = 0
	var heal: int = 0
	var gnicie: int = 0
	var flat: int = 0
	var has_furia: bool = false
	var poly: float = 1.0
	var retrig_total: int = 0     # chip material that LAWINA re-scores (card chips + Foil bonus)
	var chaos_count: int = 0
	var has_lawina: bool = false
	var glass_count: int = 0
	var kombinat_cards: Array = []

	var aspect_counts: Dictionary = {}
	for c in cards:
		aspect_counts[c.aspect] = int(aspect_counts.get(c.aspect, 0)) + 1

	# THE KEYSTONE (docs/PLAN_TODO.md T1): the LAST card in the play order carries double weight.
	# This is what turns "which five cards" -- one right answer -- into "which five, and which
	# last" -- five. It doubles chip material and the FLAT keyword values only; the multiplying
	# keywords (Furia, Przeciazenie, Kombinat, Lawina, Zniwo) are untouched, because doubling a
	# x2 on glass would hand out x8 for a click. Off by default (ctx has no "keystone"), so every
	# existing test asserts the same numbers it always did.
	var keystone: int = (cards.size() - 1) if bool(ctx.get("keystone", false)) and cards.size() > 1 else -1
	for ci in cards.size():
		var c = cards[ci]
		var key: int = 2 if ci == keystone else 1
		chips += c.chip_value() * key
		retrig_total += c.chip_value() * key
		if c.aspect == Aspects.Id.CHAOS:
			chaos_count += 1
		# A reversed card pays for the colour it gave up. Multiplicative, and deliberately smaller
		# than it looks: five of them is already x6.4, and the real cost is that the card now
		# fights for a different Aspect than the deck was built around.
		if c.inverted:
			mult *= 1.45
		match c.edition:
			CardData.Edition.FOIL:
				chips += 15
				retrig_total += 15
			CardData.Edition.HOLO:
				mult += 2.0
			CardData.Edition.POLYCHROME:
				poly *= 1.3
		match c.keyword:
			CardData.Keyword.OSLONA:
				block += c.keyword_value * key
			CardData.Keyword.KORZENIE:
				block += (c.keyword_value + c.bloom) * key   # roots deepen every turn the card waits
			CardData.Keyword.OPATRZNOSC:
				heal += c.keyword_value * key
			CardData.Keyword.GNICIE:
				gnicie += c.keyword_value * key
			CardData.Keyword.SPALENIE:
				flat += c.keyword_value * key
			CardData.Keyword.ECHO:
				chips += c.keyword_value * plays * key
			CardData.Keyword.ZNIWO:
				mult += float(c.keyword_value * grave)   # MULTIPLYING: never keystoned
			CardData.Keyword.BUJNOSC:
				if int(aspect_counts[c.aspect]) >= 3:
					chips += c.keyword_value * key
			CardData.Keyword.SYMBIOZA:
				# +value chips per allied-colour card played alongside (pentagram neighbours)
				var pals: Array = Aspects.allies(c.aspect)
				for other in cards:
					if other != c and pals.has(other.aspect):
						chips += c.keyword_value * key
			CardData.Keyword.FURIA:
				has_furia = true
			CardData.Keyword.PRZECIAZENIE:
				glass_count += 1
			CardData.Keyword.LAWINA:
				has_lawina = true
			CardData.Keyword.KOMBINAT:
				kombinat_cards.append(c)

	# Lawina: the play's card-chip material scores again once per Chaos card in the play (cap 3).
	if has_lawina:
		chips += retrig_total * mini(3, chaos_count)

	# Furia: x1.5 Mult when this play commits no block (aggression punishes playing defence).
	if has_furia and block == 0:
		mult *= 1.5

	# Kombinat: xMult per card, scaled by the trailing streak of the SAME hand type (cap 4).
	if not kombinat_cards.is_empty():
		var streak := 0
		for i in range(history.size() - 1, -1, -1):
			if int(history[i]) == hand:
				streak += 1
			else:
				break
		streak = mini(streak, 4)
		for c in kombinat_cards:
			mult *= 1.0 + (c.keyword_value / 100.0) * streak

	# Przeciazenie: x2 Mult per glass card in the play (the card pays with its durability).
	if glass_count > 0:
		mult *= pow(2.0, glass_count)

	# The Magician's amplification: other relics' xMult bonuses are stretched by K (never itself).
	var magnify_k := 1.0
	for relic in relics:
		if relic != null and relic.effect == ArcanumData.Effect.MAGNIFY:
			magnify_k = maxf(magnify_k, 3.0 if relic.is_reversed else 2.0)

	# Relics stack; every per-play effect resolves HERE so the preview shows the exact outcome.
	for relic in relics:
		if relic == null:
			continue
		match relic.effect:
			ArcanumData.Effect.MULT_IF_ASPECT:
				for c in cards:
					if c.aspect == relic.effect_aspect:
						mult *= 1.0 + (relic.effect_mult - 1.0) * magnify_k
						break
			ArcanumData.Effect.PACT_MULT:
				# the Devil always pays out; the bill arrives on the enemy's turn
				mult *= 1.0 + (relic.effect_mult - 1.0) * magnify_k
			ArcanumData.Effect.MAGNIFY:
				mult *= relic.effect_mult   # its own bonus is never amplified
			ArcanumData.Effect.BLOCK_ON_PLAY:
				block += relic.effect_value
			ArcanumData.Effect.HEAL_ON_PLAY:
				heal += relic.effect_value

	mult *= poly

	# --- BIOME LAW: the field itself scores, one deterministic rule per biome (RegionData.Law).
	# Applied AFTER cards and relics but BEFORE the Curse multiplier, so the law reads as a
	# property of the place rather than of any card, and the preview stays exact.
	match int(ctx.get("law", 0)):
		1:  # LIFE_TITHE -- the Orchard pays a tithe of shelter for every card committed
			block += 2 * cards.size()
		3:  # DEATH_HARVEST -- the Catacombs pay for what is already spent
			chips += 2 * grave
		4:  # CHAOS_KINDLING -- the Burnt Field rewards a whole hand and punishes a nibble
			if cards.size() >= 5:
				mult *= 1.5
			elif cards.size() <= 2:
				mult *= 0.75
		6:  # SEAL_FIVE -- the Sealed Biome inverts the journey: it pays for EVERY colour at once
			mult += float(aspect_counts.size())

	# Curse multiplies the SCORED damage (Spalenie stays flat, outside the engine); this play's
	# own Klatwa cards stack the debuff for FUTURE plays (returned, applied by the controller).
	var damage: int = int(round(chips * mult * (1.0 + klatwa / 100.0))) + flat
	var klatwa_add: int = 0
	var leech: int = 0
	for c in cards:
		if c.keyword == CardData.Keyword.KLATWA:
			klatwa_add += c.keyword_value
		elif c.keyword == CardData.Keyword.PIJAWKA:
			leech += c.keyword_value
	if leech > 0:
		heal += int(damage * leech / 100.0)

	# Per-fight heal pool: healing beyond the remaining budget is clipped -- and the preview shows
	# the clip, so the cap can never surprise. heal_raw keeps the pre-clamp value for the HUD.
	var heal_raw := heal
	heal = mini(heal, int(ctx.get("heal_budget", 999999)))

	return {
		# The Pentagram's real payout is TEMPO: closing the circle hands a discard back, which is
		# why it can sit at 30x3 without becoming the default play in the 40% of hands that hold one.
		"refund_discard": hand == Poker.Hand.PENTAGRAM,
		"hand": hand,
		"chips": chips,
		"mult": mult,
		"damage": damage,
		"block": block,
		"heal": heal,
		"heal_raw": heal_raw,
		"gnicie": gnicie,
		"flat": flat,
		"klatwa_add": klatwa_add,
	}
