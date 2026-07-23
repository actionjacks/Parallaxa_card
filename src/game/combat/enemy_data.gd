@tool
class_name EnemyData
extends Resource
## A duel opponent: HP + a telegraphed, cycling intent. Bosses carry a field-rule that warps the engine.

enum Rule { NONE, TOWER_IGNORES_BLOCK }

@export var name_key: String = ""
@export var max_hp: int = 150
@export var intents: PackedInt32Array = PackedInt32Array([12, 18, 8])  ## cycled each enemy turn
@export var reward_rtec: int = 6          ## Rtec (currency) granted on defeat
@export var is_boss: bool = false
@export var rule: Rule = Rule.NONE
@export var rule_key: String = ""         ## localization key describing the field-rule (bosses only)
