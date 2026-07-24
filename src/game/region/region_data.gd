@tool
class_name RegionData
extends Resource
## One region of the run: a linear ladder of fights, then a boss. Authorable in the editor.
## Beating the boss grants boss_arcanum (Fool's Journey). starting_arcanum is the run's opening boon.

@export var name_key: String = ""
@export var fights: Array[EnemyData] = []
@export var boss: EnemyData
@export var boss_arcanum: ArcanumData
@export var starting_arcanum: ArcanumData          ## legacy fallback when starting_pool is empty
@export var starting_pool: Array[ArcanumData] = [] ## run start: draft 1 of 3 random picks from here
