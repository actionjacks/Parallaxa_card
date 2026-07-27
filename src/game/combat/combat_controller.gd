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
var heal_used: int = 0            ## per-fight heal pool spent (budget burns even at full HP)
var heal_cap: int = FIGHT_HEAL_CAP   ## effective cap this fight (veil + boss rule adjusted)
var overkill_rtec: int = 0        ## Mercury earned by the killing blow's excess damage
var destroyed_cards: Array = []   ## PRZECIAZENIE glass shattered this fight (leaves the run deck)

# --- fight statistics (read by RunState.record_fight) ---
var damage_taken: int = 0         ## HP lost to enemy hits + blood tax this fight
var fight_damage: int = 0         ## sum of play damage this fight
var fight_best_hit: int = 0
var fight_best_hit_hand: int = 0
var fight_best_hand: int = 0      ## highest Poker.Hand ordinal played this fight
var kill_mono_death_flush: bool = false

var _draw: Array = []
var _used: Array = []
var _intent_index: int = 0
var _plays: int = 0
var _hand_history: Array = []     ## Poker.Hand per play this fight (Kombinat streaks)
var _dmg_this_round: int = 0      ## damage dealt since the enemy last acted (Moon mend check)

func start(deck: Array, p_enemy: EnemyData, p_relics: Array, start_hp: int = -1, max_hp: int = -1, p_levels: Dictionary = {}, p_veil: int = 0) -> void:
	_draw = deck.duplicate()
	_used.clear()
	hand.clear()
	enemy = p_enemy
	relics = p_relics
	hand_levels = p_levels
	veil = p_veil
	enemy_klatwa = 0
	# Veil V bosses stand 15% taller (computed here -- .tres are never mutated).
	enemy_max_hp = enemy.max_hp
	if enemy.is_boss and veil >= 5:
		enemy_max_hp = int(round(enemy.max_hp * 1.15 / 10.0)) * 10
	enemy_hp = enemy_max_hp
	player_max_hp = max_hp if max_hp > 0 else PLAYER_MAX_HP
	player_hp = start_hp if start_hp > 0 else player_max_hp
	player_block = 0
	enemy_gnicie = 0
	discards_left = START_DISCARDS + _bonus_discards()
	turn = 1
	_intent_index = 0
	_plays = 0
	_hand_history.clear()
	_dmg_this_round = 0
	heal_used = 0
	var base_cap := 10 if veil >= 5 else FIGHT_HEAL_CAP
	# "No shelter under the falling tower": the Tower (and the World) halves the heal pool.
	heal_cap = ceili(base_cap / 2.0) if _rule_ignores_block() else base_cap
	overkill_rtec = 0
	destroyed_cards.clear()
	damage_taken = 0
	fight_damage = 0
	fight_best_hit = 0
	fight_best_hit_hand = 0
	fight_best_hand = 0
	kill_mono_death_flush = false
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
	var step := enemy.enrage_step + (1 if veil >= 3 else 0)
	var over := maxi(0, idx - n + 1)
	return enemy.intents[idx % n] + over * step

func current_intent() -> int:
	return _intent_at(_intent_index)

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
	var dmg := int(result["damage"])
	enemy_hp -= dmg
	fight_damage += dmg
	_dmg_this_round += dmg
	fight_best_hand = maxi(fight_best_hand, int(result["hand"]))
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
			_finish(false)
			return
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
	_move_to_used(selected)
	_refill()
	if enemy_hp <= 0:
		enemy_hp = 0
		_finish(true)
		return
	# Deck burnout: an all-glass deck can shatter itself to nothing. With no cards anywhere the
	# fight has no legal move left -- the deck burned out, the duel is lost (visible, not a hang).
	if hand.is_empty() and _draw.is_empty() and _used.is_empty():
		message.emit("LOG_DECK_ASHES", [])
		player_hp = 0
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
	var incoming: int = current_intent()
	# The Tower's field-rule ignores block, so defence can't save you against it.
	var taken: int = maxi(0, incoming - (0 if _rule_ignores_block() else player_block))
	if incoming > 0:
		taken += _pact_surcharge() + _curse_surcharge()   # the Devil's bill + reversed prices
	player_hp -= taken
	damage_taken += taken
	player_block = 0
	message.emit("LOG_ATTACK", [taken])
	_intent_index += 1
	_dmg_this_round = 0
	if player_hp <= 0:
		player_hp = 0
		_finish(false)
		return
	turn += 1
	discards_left = START_DISCARDS + _bonus_discards()
	for c in hand:   # WZROST ramps while the card waits in hand (run-local, preview-exact)
		if c.keyword == CardData.Keyword.WZROST:
			c.growth += c.keyword_value
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
		"grave": _used.size(),
		"plays": _plays,
		"hand_levels": hand_levels,
		"klatwa": enemy_klatwa,
		"hand_history": _hand_history,
		"heal_budget": heal_cap - heal_used,
	}

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

func _refill() -> void:
	while hand.size() < HAND_SIZE:
		if _draw.is_empty():
			if _used.is_empty():
				break
			_draw = _used.duplicate()  # deterministic recycle: order preserved, no shuffle
			_used.clear()
		hand.append(_draw.pop_front())
