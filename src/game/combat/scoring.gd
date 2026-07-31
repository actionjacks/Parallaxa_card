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

## Flat chips a reversed card carries on top of its x1.45. Measured trade-off: todo.md asks for a
## "powerful bonus (e.g. x3 Mult)", but x3 per card compounds to x243 across five and would end the
## game. Flat chips make one reversal felt without the stack detonating.
const INVERT_CHIPS: int = 20

static func score(cards: Array, relics: Array, ctx: Dictionary = {}) -> Dictionary:
	var grave: int = int(ctx.get("grave", 0))
	var plays: int = int(ctx.get("plays", 0))
	var levels: Dictionary = ctx.get("hand_levels", {})
	var klatwa: int = int(ctx.get("klatwa", 0))   # stacked Curse on the enemy: +% damage taken
	var history: Array = ctx.get("hand_history", [])

	var hand: int = Poker.evaluate(cards)
	# The boss who reads the chart upside down: the hand you MADE is still the hand you made (the
	# paytable, the hint and the statistics all keep saying so), but it is PAID as its mirror.
	var upside_down: bool = bool(ctx.get("inverted_table", false))
	var base: Array = Poker.base_for(hand, int(levels.get(hand, 0)), upside_down)
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

	# A splashed card counts under BOTH of its colours, which is the whole point of carving one:
	# it makes a two-colour deck coherent instead of a compromise. Bujnosc, Symbioza, the Seal
	# law and the relics all read this table, so they learn about hybrids for free.
	var aspect_counts: Dictionary = {}
	for c in cards:
		for a in c.aspects():
			aspect_counts[int(a)] = int(aspect_counts.get(int(a), 0)) + 1

	# THE KEYSTONE (docs/PLAN_TODO.md T1): the LAST card in the play order carries double weight.
	# This is what turns "which five cards" -- one right answer -- into "which five, and which
	# last" -- five. It doubles chip material and the FLAT keyword values only; the multiplying
	# keywords (Furia, Przeciazenie, Kombinat, Lawina, Zniwo) are untouched, because doubling a
	# x2 on glass would hand out x8 for a click. Off by default (ctx has no "keystone"), so every
	# existing test asserts the same numbers it always did.
	var keystone: int = (cards.size() - 1) if bool(ctx.get("keystone", false)) and cards.size() > 1 else -1

	# --- POSITIONAL PASS (docs/todo.md par.1). Resolved BEFORE anything scores, because both of
	# these change WHAT is in the play rather than how much it is worth.
	# WROZBA: if the FIRST card foretells, every card to its right gains chips.
	var foretold: int = 0
	if cards.size() > 1 and cards[0].keyword == CardData.Keyword.WROZBA:
		foretold = cards[0].keyword_value
	# OFIARA: if the LAST card is a sacrifice, it devours its left-hand neighbour. The victim is
	# REPORTED, not mutated here -- Scoring stays a pure function and the controller does the
	# destroying, exactly as glass (PRZECIAZENIE) already works.
	var devoured: int = -1
	var devoured_chips: int = 0
	if cards.size() > 1 and cards[cards.size() - 1].keyword == CardData.Keyword.OFIARA:
		devoured = cards.size() - 2
		devoured_chips = cards[devoured].chip_value()
		# A banned colour brings nothing -- including through a mouth. Eating a forbidden card used
		# to launder its chips into the Ofiara, which was a hole straight through the Judgement's
		# announced rule.
		var ban: int = int(ctx.get("banned_aspect", -1))
		if ban >= 0 and cards[devoured].has_aspect(ban):
			devoured_chips = 0
	for ci in cards.size():
		var c = cards[ci]
		var key: int = 2 if ci == keystone else 1
		if ci == devoured:
			continue          # eaten by the Ofiara to its right: it scores nothing itself
		# A banned colour is dead weight this cycle: it still fills the hand and still counts
		# toward the poker shape, but it brings nothing. Announced a turn ahead by the HUD.
		if int(ctx.get("banned_aspect", -1)) >= 0 and c.has_aspect(int(ctx.get("banned_aspect", -1))):
			continue
		chips += c.chip_value() * key
		retrig_total += c.chip_value() * key
		if foretold > 0 and ci > 0:
			chips += foretold * key      # everything to the right of the Wrozba
		if ci == devoured + 1 and devoured >= 0:
			chips += devoured_chips * key   # the sacrifice swallows its neighbour whole
		if c.has_aspect(Aspects.Id.CHAOS):
			chaos_count += 1
		# A reversed card pays for the colour it gave up. Multiplicative, and deliberately smaller
		# than it looks: five of them is already x6.4, and the real cost is that the card now
		# fights for a different Aspect than the deck was built around.
		if c.inverted:
			mult *= 1.45
			# A reversal is now worth taking on ONE card, not only in a stack of five: the flat
			# chips make a single reversed card felt, while the multiplier stays small enough that
			# five of them is x6.4 rather than an explosion.
			chips += INVERT_CHIPS * key
		# What this card has already devoured this fight rides with it (docs/todo.md par.1).
		if c.feast > 0:
			mult += float(c.feast)
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
				if int(aspect_counts.get(int(c.aspect), 0)) >= 3:
					chips += c.keyword_value * key
			CardData.Keyword.SYMBIOZA:
				# +value chips per allied-colour card played alongside (pentagram neighbours)
				var pals: Array = Aspects.allies(c.aspect)
				for other in cards:
					var allied := false
					for oa in other.aspects():
						if pals.has(int(oa)):
							allied = true
					if other != c and allied:
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
		# Cracked cards survived the Tower, and the avalanche runs over them TWICE: the card is
		# worth less on its own and more in the build that wants it, which is the whole trade.
		var cracked_chips: int = 0
		for c in cards:
			if c.cracked:
				cracked_chips += c.chip_value()
		if cracked_chips > 0:
			chips += cracked_chips * mini(3, chaos_count)

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
					if c.has_aspect(relic.effect_aspect):
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
	# The Past seat's bank (THREE_SPREAD) is added LAST, after Polychrome and the biome law, so it
	# is never re-multiplied by them -- and mult_own is what THIS play earned on its own, which is
	# the only honest thing to bank (banking the total compounded: two plays of 1.0 gave 3.0).
	var mult_own: float = mult
	mult += float(ctx.get("spread_mult", 0.0))

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
		# index WITHIN the played set of the card the Ofiara devoured (-1 = none). The controller
		# destroys it; Scoring never mutates the cards it is asked about.
		"devoured": devoured,
		# what the mouth actually swallowed (0 when the victim's colour was banned)
		"devoured_chips": devoured_chips,
		"hand": hand,
		"chips": chips,
		"mult": mult,
		"mult_own": mult_own,
		"damage": damage,
		"block": block,
		"heal": heal,
		"heal_raw": heal_raw,
		"gnicie": gnicie,
		"flat": flat,
		"klatwa_add": klatwa_add,
	}
