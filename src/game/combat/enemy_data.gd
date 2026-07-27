@tool
class_name EnemyData
extends Resource
## A duel opponent: HP + a telegraphed, cycling intent. Bosses carry a field-rule that warps the engine.

## Boss field-rules (the card's meaning warps the engine). WORLD_ALL combines the base three.
## Wave C (appended; from DESIGN.md's 22-Arcana table, made deterministic):
##  CHARIOT_DOUBLE  - momentum: his attack lands TWICE; block absorbs only the first strike
##  STRENGTH_RESIST - suppresses burst: takes 20% less from every play (preview shows effective)
##  HANGED_CAP      - suspension: your discards are capped at 1 per turn
##  JUSTICE_RIPOSTE - reflection: a play of 40+ damage draws an exact riposte (dmg/40, max 8)
##  JUDGEMENT_FRAIL - the deck is judged: each played card of rank <= 3 costs 1 HP
##  STAR_REGEN      - hope: heals a flat +12 at the start of every enemy turn
enum Rule { NONE, TOWER_IGNORES_BLOCK, DEVIL_BLOOD_TAX, MOON_CLEANSE, WORLD_ALL, CHARIOT_DOUBLE, STRENGTH_RESIST, HANGED_CAP, JUSTICE_RIPOSTE, JUDGEMENT_FRAIL, STAR_REGEN }

@export var name_key: String = ""
@export var max_hp: int = 150
@export var intents: PackedInt32Array = PackedInt32Array([12, 18, 8])  ## cycled each enemy turn
@export var enrage_step: int = 0          ## added to every intent per full cycle: long fights escalate
@export var reward_rtec: int = 6          ## Rtec (currency) granted on defeat
@export var is_boss: bool = false
@export var rule: Rule = Rule.NONE
@export var rule_key: String = ""         ## localization key describing the field-rule (bosses only)
@export var art: Texture2D                ## arena portrait; bosses use their Major Arcana card
@export var is_elite: bool = false        ## map-fork elite (reversed court card: art renders flipped)
@export var arcanum: ArcanumData          ## the relic this boss yields (beat the card, wear the card)
