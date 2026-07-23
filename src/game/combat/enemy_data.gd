@tool
class_name EnemyData
extends Resource
## A duel opponent: HP and a deterministic, telegraphed intent cycle (attack values).

@export var name_key: String = ""
@export var max_hp: int = 150
@export var intents: PackedInt32Array = PackedInt32Array([12, 18, 8])  ## cycled each enemy turn
