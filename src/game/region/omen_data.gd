@tool
class_name OmenData
extends Resource
## A road omen (map event): a Major Arcana card offering a small deterministic choice.
## Editor-authorable (.tres in data/omens/); the effect RESOLUTION stays in run.gd matched by id
## (effects touch run/screen flow -- documented trade-off until an effect-graph is worth it).

@export var id: String = ""
@export var name_key: String = ""
@export var desc_key: String = ""
@export var art: Texture2D
@export var requires_achievement: String = ""   ## Profile achievement id gating this omen ("" = always)
