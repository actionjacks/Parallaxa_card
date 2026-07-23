class_name CombatController
extends RefCounted
## Deterministic 1v1 duel state machine. No hidden info, no RNG in combat: the deck order is
## fixed and recycled in order, so a preview can never lie. UI reads state and calls play/discard.

signal state_changed
signal message(text_key: String, args: Array)
signal ended(won: bool)

const HAND_SIZE: int = 8
const START_DISCARDS: int = 3
const PLAYER_MAX_HP: int = 50

var arcanum: ArcanumData
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

func start(deck: Array, p_enemy: EnemyData, p_arcanum: ArcanumData, start_hp: int = -1, max_hp: int = -1) -> void:
	_draw = deck.duplicate()
	_used.clear()
	hand.clear()
	enemy = p_enemy
	arcanum = p_arcanum
	enemy_hp = enemy.max_hp
	player_max_hp = max_hp if max_hp > 0 else PLAYER_MAX_HP
	player_hp = start_hp if start_hp > 0 else player_max_hp
	player_block = 0
	enemy_gnicie = 0
	discards_left = START_DISCARDS
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
	return enemy.intents[_intent_index % enemy.intents.size()]

func preview(selected: Array) -> Dictionary:
	return Scoring.score(_cards_from(selected), arcanum, _ctx())

func play(selected: Array) -> void:
	if phase != "player" or selected.is_empty():
		return
	var result: Dictionary = Scoring.score(_cards_from(selected), arcanum, _ctx())
	last_score = result
	player_block += int(result["block"])
	enemy_gnicie += int(result["gnicie"])
	enemy_hp -= int(result["damage"])
	if int(result["heal"]) > 0:
		player_hp = mini(player_max_hp, player_hp + int(result["heal"]))
	_plays += 1
	message.emit("LOG_PLAY", [tr(Poker.name_key(int(result["hand"]))), int(result["damage"])])
	_move_to_used(selected)
	_refill()
	if enemy_hp <= 0:
		enemy_hp = 0
		_finish(true)
		return
	_enemy_turn()

func discard(selected: Array) -> void:
	if phase != "player" or selected.is_empty() or discards_left <= 0:
		return
	discards_left -= 1
	_move_to_used(selected)
	_refill()
	state_changed.emit()

func _enemy_turn() -> void:
	phase = "enemy"
	state_changed.emit()
	if enemy_gnicie > 0:
		enemy_hp -= enemy_gnicie
		message.emit("LOG_GNICIE", [enemy_gnicie])
		if enemy_hp <= 0:
			enemy_hp = 0
			_finish(true)
			return
	var incoming: int = current_intent()
	var taken: int = maxi(0, incoming - player_block)
	player_hp -= taken
	player_block = 0
	message.emit("LOG_ATTACK", [taken])
	_intent_index += 1
	if player_hp <= 0:
		player_hp = 0
		_finish(false)
		return
	turn += 1
	discards_left = START_DISCARDS
	phase = "player"
	state_changed.emit()

func _finish(won: bool) -> void:
	phase = "ended"
	state_changed.emit()
	ended.emit(won)

func _ctx() -> Dictionary:
	return {"grave": _used.size(), "plays": _plays}

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
