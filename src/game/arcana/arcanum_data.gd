@tool
class_name ArcanumData
extends Resource
## A Major Arcanum kept as a passive relic. Slice: one effect type (xMult when an aspect is present).
## In the full game an Arcanum is also the boss you beat to claim it (Fool's Journey).

enum Effect { NONE, MULT_IF_ASPECT }

@export var name_key: String = ""
@export var effect: Effect = Effect.NONE
@export var effect_aspect: Aspects.Id = Aspects.Id.DEATH
@export var effect_mult: float = 1.5
