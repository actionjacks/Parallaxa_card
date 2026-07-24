@tool
class_name ArcanumData
extends Resource
## A Major Arcanum kept as a passive relic. In the full game an Arcanum is also the boss you beat
## to claim it (Fool's Journey). Effects are DISTINCT playstyles, not one formula:
##  MULT_IF_ASPECT  - xMult when the played hand contains effect_aspect (scoring)
##  EXTRA_DISCARD   - +effect_value discards every turn (consistency)
##  BLOCK_ON_PLAY   - +effect_value block with every play (defence)
##  HEAL_ON_PLAY    - +effect_value HP with every play (sustain)
##  PACT_MULT       - xeffect_mult on EVERY hand, but enemy hits hurt +effect_value more (the Devil's deal)
## All deterministic; per-play effects resolve in scoring so the preview never lies.

enum Effect { NONE, MULT_IF_ASPECT, EXTRA_DISCARD, BLOCK_ON_PLAY, HEAL_ON_PLAY, PACT_MULT }

@export var name_key: String = ""
@export var effect: Effect = Effect.NONE
@export var effect_aspect: Aspects.Id = Aspects.Id.DEATH
@export var effect_mult: float = 1.5
@export var effect_value: int = 0
@export var art: Texture2D            ## RWS 1909 card scan (assets/cards/arcana/, public domain)

## Player-facing one-liner of what this relic does.
func describe() -> String:
	match effect:
		Effect.MULT_IF_ASPECT:
			return tr("ARC_FX_MULT") % [String.num(effect_mult, 1), tr(Aspects.name_key(effect_aspect))]
		Effect.EXTRA_DISCARD:
			return tr("ARC_FX_DISCARD") % effect_value
		Effect.BLOCK_ON_PLAY:
			return tr("ARC_FX_BLOCK") % effect_value
		Effect.HEAL_ON_PLAY:
			return tr("ARC_FX_HEAL") % effect_value
		Effect.PACT_MULT:
			return tr("ARC_FX_PACT") % [String.num(effect_mult, 2), effect_value]
	return ""
