class_name CombatController
extends RefCounted
## Deterministic 1v1 duel state machine. No hidden info, no RNG in combat: the deck order is
## fixed and recycled in order, so a preview can never lie. UI reads state and calls play/discard.

signal state_changed
signal message(text_key: String, args: Array)
signal ended(won: bool)
signal awaiting_enemy      ## player's play resolved; the scene pauses, then calls resolve_enemy_turn()

const HAND_SIZE: int = 8
const START_DISCARDS: int = 3
const PLAYER_MAX_HP: int = 55
const FIGHT_HEAL_CAP: int = 15       ## shared per-fight heal pool (Opatrznosc + relic heal + leech)
const MOON_MEND_HEAL: int = 15       ## the Moon self-mends when a round deals too little...
const MOON_MEND_THRESHOLD: int = 60  ## ...i.e. under this much damage between its turns
const EMPRESS_BLOOM_HEAL: int = 40   ## the Empress feeds on any play shorter than five cards

var relics: Array = []          ## Array[ArcanumData] applied to every play
var hand_levels: Dictionary = {}   ## Poker.Hand -> level (Star consumables)
var enemy_klatwa: int = 0          ## stacked Curse: +% damage the enemy takes from scored plays
var enemy: EnemyData
var hand: Array = []              ## Array[CardData] currently in hand
var player_hp: int = PLAYER_MAX_HP
var player_max_hp: int = PLAYER_MAX_HP
var player_block: int = 0
var enemy_hp: int = 0
var enemy_max_hp: int = 0         ## effective max (veil scaling); HUD bars and Moon mend clamp to it
var enemy_gnicie: int = 0         ## stacking DoT applied at the start of each enemy turn
var discards_left: int = START_DISCARDS
var turn: int = 1
var phase: String = "player"      ## "player", "enemy", "ended"
var last_score: Dictionary = {}
var veil: int = 0                 ## ascension tier (P1): pressure knobs, all preview-visible
var depth: int = 0                ## Beyond-the-World loop count: +50% HP, +35% intents per depth
var heal_used: int = 0            ## per-fight heal pool spent (budget burns even at full HP)
var heal_cap: int = FIGHT_HEAL_CAP   ## effective cap this fight (veil + boss rule adjusted)
var overkill_rtec: int = 0        ## Mercury earned by the killing blow's excess damage
var destroyed_cards: Array = []   ## PRZECIAZENIE glass shattered this fight (leaves the run deck)

# --- fight statistics (read by RunState.record_fight) ---
var damage_taken: int = 0         ## HP lost to enemy hits + blood tax this fight
var death_cause: String = ""      ## "attack" | "pact" | "ashes" -- set when the player falls
var fight_damage: int = 0         ## sum of play damage this fight
var fight_best_hit: int = 0
var fight_best_hit_hand: int = 0
var fight_best_hand: int = 0      ## highest Poker.Hand ordinal played this fight
var kill_mono_death_flush: bool = false
var flush_played: bool = false    ## any flush-family hand scored this fight (first-blood ach)
var intent_debt: int = 0          ## Wheel omen's price: flat +N on every intent this fight
var law: int = 0                  ## RegionData.Law of the biome this duel is fought in
var _last_play_size: int = 0      ## cards in the player's most recent play (the Empress reads it)
var _last_play_damage: int = 0    ## damage of that play (the Fool answers with it)
## The cards of the blow that ENDED the fight, in play order. The last of them is the one that
## struck the killing blow, and against a boss it earns a permanent scar (PLAN_TODO T5).
var killing_cards: Array = []
## The Judgement answers ONCE per duel; a grave that refills forever is not a resource.
var _raised: bool = false

var _draw: Array = []
var _used: Array = []
var _intent_index: int = 0
var _plays: int = 0
var _hand_history: Array = []     ## Poker.Hand per play this fight (Kombinat streaks)
var _dmg_this_round: int = 0      ## damage dealt since the enemy last acted (Moon mend check)

func start(deck: Array, p_enemy: EnemyData, p_relics: Array, start_hp: int = -1, max_hp: int = -1, p_levels: Dictionary = {}, p_veil: int = 0, p_depth: int = 0, p_debt: int = 0, p_law: int = 0) -> void:
	law = p_law
	_draw = deck.duplicate()
	_used.clear()
	hand.clear()
	enemy = p_enemy
	relics = p_relics
	hand_levels = p_levels
	veil = p_veil
	depth = p_depth
	intent_debt = p_debt
	enemy_klatwa = 0
	# Veil V bosses stand 15% taller; every Beyond depth adds +50% HP (computed here -- .tres
	# are never mutated).
	enemy_max_hp = enemy.max_hp
	if enemy.is_boss and veil >= 5:
		enemy_max_hp = int(round(enemy.max_hp * 1.15 / 10.0)) * 10
	if depth > 0:
		enemy_max_hp = int(round(enemy_max_hp * (1.0 + 0.5 * depth) / 10.0)) * 10
	enemy_hp = enemy_max_hp
	player_max_hp = max_hp if max_hp > 0 else PLAYER_MAX_HP
	player_hp = start_hp if start_hp > 0 else player_max_hp
	player_block = 0
	enemy_gnicie = 0
	discards_left = START_DISCARDS + _bonus_discards()
	if enemy.rule == EnemyData.Rule.HANGED_CAP:
		discards_left = mini(discards_left, 1)   # the Hanged Man: suspension
	turn = 1
	_intent_index = 0
	_plays = 0
	_hand_history.clear()
	_dmg_this_round = 0
	heal_used = 0
	var base_cap := 10 if veil >= 5 else FIGHT_HEAL_CAP
	# "No shelter under the falling tower": the Tower (and the World) halves the heal pool.
	heal_cap = ceili(base_cap / 2.0) if _rule_ignores_block() else base_cap
	if law == 1:
		heal_cap += 8   # the Orchard (LIFE law): the biome you are meant to survive in
	overkill_rtec = 0
	destroyed_cards.clear()
	damage_taken = 0
	death_cause = ""
	fight_damage = 0
	fight_best_hit = 0
	fight_best_hit_hand = 0
	fight_best_hand = 0
	kill_mono_death_flush = false
	flush_played = false
	_last_play_size = 0
	_last_play_damage = 0
	killing_cards = []
	_raised = false
	phase = "player"
	last_score = {}
	_refill()
	state_changed.emit()

## The enrage clock: the first authored cycle is exact, then EVERY further turn adds +step,
## starting IMMEDIATELY on the first turn past the cycle (spec_difficulty par.3a prose).
## Deterministic and always shown by the intent label -- the preview never lies about the hit.
func _intent_at(idx: int) -> int:
	if enemy == null or enemy.intents.is_empty():
		return 0
	var n := enemy.intents.size()
	var step := enemy.enrage_step + (1 if veil >= 3 else 0) + depth
	var over := maxi(0, idx - n + 1)
	var base := int(floor(enemy.intents[idx % n] * (1.0 + 0.35 * depth)))
	if base > 0:
		base += intent_debt   # the Wheel's price rides every real hit, preview-visible
	return base + over * step

func current_intent() -> int:
	# The Fool answers with your own blow. His clock is the player, not a table, so he ignores
	# the authored intents entirely once a play has landed. Still exact: the HUD feeds the live
	# preview damage into mirror_intent() while cards are being picked, so the number moves with
	# the selection and never lies about what is coming.
	if enemy != null and enemy.rule == EnemyData.Rule.FOOL_MIRROR:
		return mirror_intent(_last_play_damage)
	return _intent_at(_intent_index)

## What the Fool will answer with, given a blow of `play_damage`. Public so the combat HUD can
## show it updating live while the player is still choosing.
func mirror_intent(play_damage: int) -> int:
	if play_damage <= 0:
		return _intent_at(0)          # turn one: he has nothing to answer yet
	@warning_ignore("integer_division")
	return clampi(play_damage / 14, 8, 34)

## One-step lookahead (turn planning): the exact damage of the FOLLOWING enemy turn.
func next_intent() -> int:
	return _intent_at(_intent_index + 1)

## Intent as the player will FEEL it: pact + reversed-curse surcharges included (a non-attack
## turn stays 0 -- surcharges only ride real hits).
func intent_shown(intent: int) -> int:
	return intent + (_pact_surcharge() + _curse_surcharge() if intent > 0 else 0)

## Completed intent cycles -- drives the enrage heartbeat stem in the combat scene.
func enrage_cycles() -> int:
	if enemy == null or enemy.intents.is_empty():
		return 0
	@warning_ignore("integer_division")
	var cycles: int = _intent_index / enemy.intents.size()
	return cycles

func preview(selected: Array) -> Dictionary:
	return Scoring.score(_cards_from(selected), relics, _ctx())

## Boss-side damage modifier -- the ONLY place a rule may touch scored damage. The combat scene
## displays effective_damage() everywhere (preview, lethal, prophecy), so the covenant holds.
func effective_damage(raw: int) -> int:
	if enemy != null and enemy.rule == EnemyData.Rule.STRENGTH_RESIST:
		return ceili(raw * 0.8)
	return raw

## Justice's exact riposte for a play of the given EFFECTIVE damage (0 = none). Preview-visible.
func riposte_for(dmg: int) -> int:
	if enemy == null or enemy.rule != EnemyData.Rule.JUSTICE_RIPOSTE or dmg < 40:
		return 0
	@warning_ignore("integer_division")
	var r: int = mini(8, dmg / 40)
	return r

## Judgement's deck-tax for a set of cards about to be played (1 HP per rank <= 3). Preview-visible.
func frail_tax(cards: Array) -> int:
	if enemy == null or enemy.rule != EnemyData.Rule.JUDGEMENT_FRAIL:
		return 0
	var n := 0
	for c in cards:
		if c.rank <= 3:
			n += 1
	return n

## Trailing streak of the given hand type in this fight's play history (Kombinat display).
func kombinat_streak(hand_type: int) -> int:
	var streak := 0
	for i in range(_hand_history.size() - 1, -1, -1):
		if int(_hand_history[i]) == hand_type:
			streak += 1
		else:
			break
	return mini(streak, 4)

func play(selected: Array) -> void:
	if phase != "player" or selected.is_empty():
		return
	var cards := _cards_from(selected)
	var result: Dictionary = Scoring.score(cards, relics, _ctx())
	last_score = result
	player_block += int(result["block"])
	enemy_gnicie += int(result["gnicie"])
	enemy_klatwa += int(result.get("klatwa_add", 0))   # this play's Curse cards debuff FUTURE plays
	var dmg := effective_damage(int(result["damage"]))
	enemy_hp -= dmg
	fight_damage += dmg
	_dmg_this_round += dmg
	# By PAYOUT, not by enum position: the enum is append-only, so a hand added at the end would
	# otherwise outrank Magnum Opus purely by being newer.
	if Poker.value_of(int(result["hand"])) > Poker.value_of(fight_best_hand):
		fight_best_hand = int(result["hand"])
	if int(result["hand"]) in [Poker.Hand.FLUSH, Poker.Hand.STRAIGHT_FLUSH, Poker.Hand.MAGNUM_OPUS]:
		flush_played = true
	if dmg > fight_best_hit:
		fight_best_hit = dmg
		fight_best_hit_hand = int(result["hand"])
	if enemy_hp <= 0:
		# Overkill pays: the excess of the killing blow converts to Mercury (cap mirrors interest).
		@warning_ignore("integer_division")
		var bonus: int = clampi(-enemy_hp / 50, 0, 5)
		overkill_rtec = bonus
		var mono_death := cards.size() == 5
		for c in cards:
			if c.aspect != Aspects.Id.DEATH:
				mono_death = false
		kill_mono_death_flush = mono_death and int(result["hand"]) in [
			Poker.Hand.FLUSH, Poker.Hand.STRAIGHT_FLUSH, Poker.Hand.FIVE, Poker.Hand.MAGNUM_OPUS]
	var healed := int(result["heal"])   # already clamped by the budget inside scoring
	heal_used += healed
	if healed > 0:
		player_hp = mini(player_max_hp, player_hp + healed)
	if int(result.get("heal_raw", healed)) > healed:
		message.emit("LOG_HEAL_CAPPED", [healed, int(result.get("heal_raw", healed))])
	_plays += 1
	_hand_history.append(int(result["hand"]))
	# Justice reflects, Judgement judges the deck -- both AFTER the kill check (a killing blow
	# still wins first), both exact and pre-announced by the combat scene's preview.
	if enemy_hp > 0:
		var rip := riposte_for(dmg)
		if rip > 0:
			player_hp -= rip
			damage_taken += rip
			message.emit("LOG_RIPOSTE", [rip])
		var frail := frail_tax(cards)
		if frail > 0:
			player_hp -= frail
			damage_taken += frail
			message.emit("LOG_FRAIL", [frail])
		if player_hp <= 0:
			player_hp = 0
			death_cause = "attack"
			_finish(false)
			return
	# The Devil's field-rule: every play costs blood, and the bill grows with the fight clock.
	# A killing blow still wins first (enemy_hp already has this play's damage subtracted above).
	if enemy_hp > 0 and _rule_blood_tax():
		@warning_ignore("integer_division")
		var tax: int = 2 + _intent_index / enemy.intents.size()
		player_hp -= tax
		damage_taken += tax
		message.emit("LOG_PACT", [tax])
		if player_hp <= 0:
			player_hp = 0
			death_cause = "pact"
			_finish(false)
			return
	# Remembered for the field rules that answer the PLAYER rather than a table: the Empress
	# feeds on a short hand, the Fool strikes back with the blow he just took.
	_last_play_size = cards.size()
	_last_play_damage = dmg
	# The Pentagram returns a discard (Scoring flags it) -- capped so it can never bank more
	# discards than a turn starts with.
	if bool(result.get("refund_discard", false)):
		discards_left = mini(discards_left + 1, START_DISCARDS + _bonus_discards())
		message.emit("LOG_PENTAGRAM", [])
	message.emit("LOG_PLAY", [tr(Poker.name_key(int(result["hand"]))), dmg])
	if int(result["block"]) > 0:
		message.emit("LOG_BLOCK", [int(result["block"])])
	if healed > 0:
		message.emit("LOG_HEAL", [healed])
	# Glass wears with every SCORED play; at 0 it shatters into the void: it skips the grave
	# (never recycles) and run.gd erases it from the run deck after a won fight.
	for c in cards:
		if c.keyword == CardData.Keyword.PRZECIAZENIE:
			c.wear += 1
			if c.wear >= c.keyword_value:
				destroyed_cards.append(c)
	# THE SACRIFICE (docs/todo.md par.1): an Ofiara played last devours its left-hand neighbour.
	# The victim leaves the fight for good, exactly like shattered glass, and the run deck loses
	# it after a won fight -- so the geometry of a play can permanently reshape the deck.
	var eaten: int = int(result.get("devoured", -1))
	if eaten >= 0 and eaten < cards.size():
		var victim: CardData = cards[eaten]
		if not destroyed_cards.has(victim):
			destroyed_cards.append(victim)
		message.emit("LOG_OFIARA", [victim.chip_value()])
	_move_to_used(selected)
	_refill()
	if enemy_hp <= 0:
		enemy_hp = 0
		killing_cards = cards.duplicate()
		_finish(true)
		return
	# Deck burnout: an all-glass deck can shatter itself to nothing. With no cards anywhere the
	# fight has no legal move left -- the deck burned out, the duel is lost (visible, not a hang).
	if hand.is_empty() and _draw.is_empty() and _used.is_empty():
		message.emit("LOG_DECK_ASHES", [])
		player_hp = 0
		death_cause = "ashes"
		_finish(false)
		return
	phase = "enemy"
	state_changed.emit()
	awaiting_enemy.emit()   # the scene pauses for a beat, then calls resolve_enemy_turn()

func discard(selected: Array) -> void:
	if phase != "player" or selected.is_empty() or discards_left <= 0:
		return
	discards_left -= 1
	_move_to_used(selected)
	_refill()
	state_changed.emit()

func resolve_enemy_turn() -> void:
	if phase != "enemy":
		return
	if enemy_gnicie > 0:
		enemy_hp -= enemy_gnicie
		_dmg_this_round += enemy_gnicie
		message.emit("LOG_GNICIE", [enemy_gnicie])
		if enemy_hp <= 0:
			@warning_ignore("integer_division")
			var bonus: int = clampi(-enemy_hp / 50, 0, 5)
			overkill_rtec = bonus
			enemy_hp = 0
			_finish(true)
			return
		if _rule_cleanses_rot():
			enemy_gnicie = 0   # the Moon's glow dissolves the rot: it ticks once, then washes away
			message.emit("LOG_CLEANSE", [])
	# The Moon self-mends when the round hurt it too little -- stalling literally undoes itself.
	if _rule_moon_mends() and _dmg_this_round < MOON_MEND_THRESHOLD:
		enemy_hp = mini(enemy_max_hp, enemy_hp + MOON_MEND_HEAL)
		message.emit("LOG_MOON_MEND", [MOON_MEND_HEAL])
	# The Star's hope: a flat self-heal every turn -- outdamage it or watch the fight undo itself.
	if enemy.rule == EnemyData.Rule.STAR_REGEN:
		enemy_hp = mini(enemy_max_hp, enemy_hp + 12)
		message.emit("LOG_STAR_REGEN", [12])
	# The Empress blooms on a half-hearted hand: anything short of five cards feeds her.
	# Deterministic and stated up front -- the player knows the price of nibbling before paying it.
	if enemy.rule == EnemyData.Rule.EMPRESS_BLOOM and _last_play_size in range(1, 5):
		enemy_hp = mini(enemy_max_hp, enemy_hp + EMPRESS_BLOOM_HEAL)
		message.emit("LOG_EMPRESS_BLOOM", [EMPRESS_BLOOM_HEAL])
	var incoming: int = current_intent()
	# The Tower's field-rule ignores block, so defence can't save you against it.
	var taken: int = maxi(0, incoming - (0 if _rule_ignores_block() else player_block))
	# The Chariot's momentum: the attack lands TWICE and block absorbs only the first strike.
	if enemy.rule == EnemyData.Rule.CHARIOT_DOUBLE and incoming > 0:
		taken += incoming
	if incoming > 0:
		taken += _pact_surcharge() + _curse_surcharge()   # the Devil's bill + reversed prices
	player_hp -= taken
	damage_taken += taken
	player_block = 0
	message.emit("LOG_ATTACK", [taken])
	_intent_index += 1
	# The Wheel turns: its cycle skips a step every turn, so the pattern cannot be memorised --
	# the player has to read the number the game is showing them, which it always shows honestly.
	if enemy.rule == EnemyData.Rule.WHEEL_TURN:
		_intent_index += 1
	_dmg_this_round = 0
	if player_hp <= 0:
		player_hp = 0
		death_cause = "attack"
		_finish(false)
		return
	turn += 1
	discards_left = START_DISCARDS + _bonus_discards()
	if enemy.rule == EnemyData.Rule.HANGED_CAP:
		discards_left = mini(discards_left, 1)
	for c in hand:   # WZROST/KORZENIE ramp while the card waits in hand (run-local, preview-exact)
		if c.keyword == CardData.Keyword.WZROST:
			c.growth += c.keyword_value
		elif c.keyword == CardData.Keyword.KORZENIE:
			c.bloom += 2
		# The Overgrowth (NATURE law): EVERY card left in hand fattens, not just the growers.
		# The only biome where not playing is a plan -- and chip_value() already counts growth,
		# so the preview shows the fattened number the moment it happens.
		if law == 5:
			c.growth += 3
	phase = "player"
	state_changed.emit()

# Field-rule queries; WORLD_ALL is the finale that stacks every previous boss rule.
func _rule_ignores_block() -> bool:
	return enemy != null and (enemy.rule == EnemyData.Rule.TOWER_IGNORES_BLOCK or enemy.rule == EnemyData.Rule.WORLD_ALL)

func _rule_blood_tax() -> bool:
	return enemy != null and (enemy.rule == EnemyData.Rule.DEVIL_BLOOD_TAX or enemy.rule == EnemyData.Rule.WORLD_ALL)

func _rule_cleanses_rot() -> bool:
	return enemy != null and (enemy.rule == EnemyData.Rule.MOON_CLEANSE or enemy.rule == EnemyData.Rule.WORLD_ALL)

func _rule_moon_mends() -> bool:
	return _rule_cleanses_rot()   # the mend is the Moon's second tooth (World inherits it too)

func _bonus_discards() -> int:
	var n := 0
	for r in relics:
		if r != null and r.effect == ArcanumData.Effect.EXTRA_DISCARD:
			n += r.effect_value
	return n

func _pact_surcharge() -> int:
	var n := 0
	for r in relics:
		if r != null and r.effect == ArcanumData.Effect.PACT_MULT:
			n += r.effect_value
	return n

## Reversed-claim price: SELF_CURSE relics make every enemy hit hurt more.
func _curse_surcharge() -> int:
	var n := 0
	for r in relics:
		if r != null and r.is_reversed and r.price == ArcanumData.Price.SELF_CURSE:
			n += r.price_value
	return n

func _finish(won: bool) -> void:
	phase = "ended"
	# Won fights permanently shatter the spent glass: the cards leave the run deck (run.gd erases
	# them from RunState.deck by identity -- combat is fed the very same CardData instances).
	state_changed.emit()
	ended.emit(won)

func _ctx() -> Dictionary:
	return {
		"law": law,
		# Veil IV -- the Cracked Mirror: the Keystone stops working, so the ordering game the
		# player has learned is taken away and they have to score on the hand alone.
		"keystone": veil < 4,
		"grave": _used.size(),
		"plays": _plays,
		"hand_levels": hand_levels,
		"klatwa": enemy_klatwa,
		"hand_history": _hand_history,
		"heal_budget": heal_cap - heal_used,
	}

## The next N cards the deck WILL deal, in exact order (deterministic recycle included).
## Powers the on-screen next-draws preview -- the covenant's planning layer made visible.
func peek_draw(n: int) -> Array:
	var out: Array = []
	for c in _draw:
		if out.size() >= n:
			break
		out.append(c)
	if out.size() < n:
		for c in _used:
			if out.size() >= n:
				break
			out.append(c)
	return out

## EXACT damage the player will take on the coming enemy turn if the pending play adds
## `extra_block` (cockpit line; mirrors resolve_enemy_turn's math to the point).
func predicted_taken(extra_block: int = 0, staged_damage: int = -1) -> int:
	# Against the Fool the counter-blow is the blow you are ABOUT to throw, so the cockpit has to
	# ask about the staged play rather than the last one -- otherwise the preview under-reports
	# exactly the hit the player is choosing to take.
	var incoming := (mirror_intent(staged_damage) if (enemy != null
		and enemy.rule == EnemyData.Rule.FOOL_MIRROR and staged_damage > 0) else current_intent())
	if incoming <= 0:
		return 0
	var blk := 0 if _rule_ignores_block() else player_block + extra_block
	var taken: int = maxi(0, incoming - blk)
	if enemy != null and enemy.rule == EnemyData.Rule.CHARIOT_DOUBLE:
		taken += incoming
	taken += _pact_surcharge() + _curse_surcharge()
	return taken

## Effective enrage step (base + Veil III + depth) -- the visible clock label.
func enrage_step_effective() -> int:
	if enemy == null:
		return 0
	return enemy.enrage_step + (1 if veil >= 3 else 0) + depth

func draw_count() -> int:
	return _draw.size()

func grave_count() -> int:
	return _used.size()

func _cards_from(selected: Array) -> Array:
	var out: Array = []
	for i in selected:
		if i >= 0 and i < hand.size():
			out.append(hand[i])
	return out

func _move_to_used(selected: Array) -> void:
	var idx: Array = selected.duplicate()
	idx.sort()
	idx.reverse()
	for i in idx:
		if i >= 0 and i < hand.size():
			var c: CardData = hand[i]
			hand.remove_at(i)
			if destroyed_cards.has(c):
				continue   # shattered glass skips the grave -- gone from the fight for good
			_used.append(c)

## The Library (MIND law) deals one card more -- the biome where a straight finally assembles.
func hand_size() -> int:
	return HAND_SIZE + (1 if law == 2 else 0)

## THE JUDGEMENT (docs/todo.md): once per fight, the Arcanum of Judgement calls the grave back
## the moment the deck runs dry -- announced, and on a KNOWN condition rather than a roll, so the
## player can plan around it. It is the effect that makes a thin deck a virtue instead of a risk.
func _raise_dead_available() -> bool:
	if _raised:
		return false
	for a: ArcanumData in relics:
		if a.effect == ArcanumData.Effect.RAISE_DEAD:
			return true
	return false

func _refill() -> void:
	while hand.size() < hand_size():
		if _draw.is_empty():
			if _raise_dead_available() and not _used.is_empty():
				_raised = true
				_draw = _used.duplicate()
				_used.clear()
				message.emit("LOG_RAISE_DEAD", [_draw.size()])
				continue
			if _used.is_empty():
				break
			_draw = _used.duplicate()  # deterministic recycle: order preserved, no shuffle
			_used.clear()
		hand.append(_draw.pop_front())
