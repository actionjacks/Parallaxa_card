@tool
class_name EnemyData
extends Resource
## A duel opponent: HP + a telegraphed, cycling intent. Bosses carry a field-rule that warps the engine.

## Boss field-rules (the card's meaning warps the engine). WORLD_ALL combines all three finals.
enum Rule { NONE, TOWER_IGNORES_BLOCK, DEVIL_BLOOD_TAX, MOON_CLEANSE, WORLD_ALL }

@export var name_key: String = ""
@export var max_hp: int = 150
@export var intents: PackedInt32Array = PackedInt32Array([12, 18, 8])  ## cycled each enemy turn
@export var enrage_step: int = 0          ## added to every intent per full cycle: long fights escalate
@export var reward_rtec: int = 6          ## Rtec (currency) granted on defeat
@export var is_boss: bool = false
@export var rule: Rule = Rule.NONE
@export var rule_key: String = ""         ## localization key describing the field-rule (bosses only)
@export var art: Texture2D                ## arena portrait; bosses use their Major Arcana card
