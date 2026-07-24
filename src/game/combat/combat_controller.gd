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
const PLAYER_MAX_HP: int = 50

var relics: Array = []          ## Array[ArcanumData] applied to every play
var hand_levels: Dictionary = {}   ## Poker.Hand -> level (Star consumables)
var enemy_klatwa: int = 0          ## stacked Curse: +% damage the enemy takes from scored plays
var enemy: EnemyData
var hand: Array = []              ## Array[CardData] currently in hand
var player_hp: int = PLAYER_MAX_HP
var player_max_hp: int = PLAYER_MAX_HP
var player_block: int = 0
var enemy_hp: int = 0
var enemy_gnicie: int = 0         ## stacking DoT applied at the start of each enemy turn
var discards_left: int = START_DISCARDS
var turn: int = 1
var phase: String = "player"      ## "player", "enemy", "ended"
var last_score: Dictionary = {}

var _draw: Array = []
var _used: Array = []
var _intent_index: int = 0
var _plays: int = 0

func start(deck: Array, p_enemy: EnemyData, p_relics: Array, start_hp: int = -1, max_hp: int = -1, p_levels: Dictionary = {}) -> void:
	_draw = deck.duplicate()
	_used.clear()
	hand.clear()
	enemy = p_enemy
	relics = p_relics
	hand_levels = p_levels
	enemy_klatwa = 0
	enemy_hp = enemy.max_hp
	player_max_hp = max_hp if max_hp > 0 else PLAYER_MAX_HP
	player_hp = start_hp if start_hp > 0 else player_max_hp
	player_block = 0
	enemy_gnicie = 0
	discards_left = START_DISCARDS + _bonus_discards()
	turn = 1
	_intent_index = 0
	_plays = 0
	phase = "player"
	last_score = {}
	_refill()
	state_changed.emit()

func current_intent() -> int:
	if enemy == null or enemy.intents.is_empty():
		return 0
	# Enrage: each completed intent cycle raises the base, so stalling gets punished. Deterministic
	# and always shown by the intent label -- the preview never lies about the incoming hit.
	var cycle: int = _intent_index / enemy.intents.size()
	return enemy.intents[_intent_index % enemy.intents.size()] + cycle * enemy.enrage_step

func preview(selected: Array) -> Dictionary:
	return Scoring.score(_cards_from(selected), relics, _ctx())

func play(selected: Array) -> void:
	if phase != "player" or selected.is_empty():
		return
	var result: Dictionary = Scoring.score(_cards_from(selected), relics, _ctx())
	last_score = result
	player_block += int(result["block"])
	enemy_gnicie += int(result["gnicie"])
	enemy_klatwa += int(result.get("klatwa_add", 0))   # this play's Curse cards debuff FUTURE plays
	enemy_hp -= int(result["damage"])
	if int(result["heal"]) > 0:
		player_hp = mini(player_max_hp, player_hp + int(result["heal"]))
	_plays += 1
	# The Devil's field-rule: every play costs blood. A killing blow still wins first
	# (enemy_hp already has this play's damage subtracted above).
	if enemy_hp > 0 and _rule_blood_tax():
		player_hp -= 2
		message.emit("LOG_PACT", [2])
		if player_hp <= 0:
			player_hp = 0
			_finish(false)
			return
	message.emit("LOG_PLAY", [tr(Poker.name_key(int(result["hand"]))), int(result["damage"])])
	if int(result["block"]) > 0:
		message.emit("LOG_BLOCK", [int(result["block"])])
	if int(result["heal"]) > 0:
		message.emit("LOG_HEAL", [int(result["heal"])])
	_move_to_used(selected)
	_refill()
	if enemy_hp <= 0:
		enemy_hp = 0
		_finish(true)
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
		message.emit("LOG_GNICIE", [enemy_gnicie])
		if enemy_hp <= 0:
			enemy_hp = 0
			_finish(true)
			return
		if _rule_cleanses_rot():
			enemy_gnicie = 0   # the Moon's glow dissolves the rot: it ticks once, then washes away
			message.emit("LOG_CLEANSE", [])
	var incoming: int = current_intent()
	# The Tower's field-rule ignores block, so defence can't save you against it.
	var taken: int = maxi(0, incoming - (0 if _rule_ignores_block() else player_block))
	if incoming > 0:
		taken += _pact_surcharge()   # the Devil's bill: every enemy hit hurts more
	player_hp -= taken
	player_block = 0
	message.emit("LOG_ATTACK", [taken])
	_intent_index += 1
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

func _finish(won: bool) -> void:
	phase = "ended"
	state_changed.emit()
	ended.emit(won)

func _ctx() -> Dictionary:
	return {"grave": _used.size(), "plays": _plays, "hand_levels": hand_levels, "klatwa": enemy_klatwa}

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
			_used.append(hand[i])
			hand.remove_at(i)

func _refill() -> void:
	while hand.size() < HAND_SIZE:
		if _draw.is_empty():
			if _used.is_empty():
				break
			_draw = _used.duplicate()  # deterministic recycle: order preserved, no shuffle
			_used.clear()
		hand.append(_draw.pop_front())
