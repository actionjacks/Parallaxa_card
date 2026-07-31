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
##  EMPRESS_BLOOM  - abundance: she heals 40 whenever you play FEWER than five cards
##  WHEEL_TURN      - the wheel turns: her intent cycle advances TWO steps a turn, not one
##  FOOL_MIRROR     - the Fool answers with your own blow: his intent IS your last play, scaled
## Wave E -- techniques for ORDINARY enemies. Until now all fourteen rules belonged to bosses and
## every regular fight was the same fight with different numbers: a health bar and an intent
## cycle. Each of these is deterministic AND computable by predicted_taken(), because a technique
## the cockpit cannot price would break the covenant the game is named after.
##  VAMPIRE_MEND  heals when your play was weak -- punishes chipping away
##  HAND_THIEF    every second turn it does not strike; it takes a card from your hand instead
##  GRAVE_GLUTTON its blow grows by one for every card in your grave -- the long fight is its plan
##  THIRD_BURST   every third turn its blow lands twice, announced from turn one
##  BARK_HIDE     takes 40% less from plays of fewer than five cards -- demands a full hand
##
## Wave F -- bosses that rewrite the RULES rather than the numbers. Each one takes something the
## player has spent the whole run learning and turns it over, and each is announced before the
## first turn so the fight is a puzzle rather than an ambush:
##  INVERTED_TABLE the hand chart is READ UPSIDE DOWN -- a pair outscores a flush
##  WIDE_HAND      no discards at all, but three more cards in hand
##  ASPECT_BAN     one colour is forbidden each cycle; its cards bring no chips
## Wave G -- the two spreads todo.md par.2 asked for. These do not modify a number, they change
## the GEOMETRY of a turn, which is why the original plan filed them as "a second game mode":
##  THREE_SPREAD  each turn falls into a seat -- Past (no damage, its Mult is kept for the whole
##                duel), Present (lands now), Future (lands in two turns). Honest because the deck
##                is deterministic: the cockpit prints the seat and the pending blow before you
##                commit, so a foretold future is a promise the engine keeps.
##  CELTIC_CROSS  four slots beside the hand. Freezing costs a discard and parks cards out of the
##                hand so it refills -- that is how you assemble one enormous play for the turn
##                the enemy telegraphs its worst blow.
enum Rule { NONE, TOWER_IGNORES_BLOCK, DEVIL_BLOOD_TAX, MOON_CLEANSE, WORLD_ALL, CHARIOT_DOUBLE, STRENGTH_RESIST, HANGED_CAP, JUSTICE_RIPOSTE, JUDGEMENT_FRAIL, STAR_REGEN, EMPRESS_BLOOM, WHEEL_TURN, FOOL_MIRROR, VAMPIRE_MEND, HAND_THIEF, GRAVE_GLUTTON, THIRD_BURST, BARK_HIDE, INVERTED_TABLE, WIDE_HAND, ASPECT_BAN, THREE_SPREAD, CELTIC_CROSS }

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
## THE FIGURE: the opponent cut OUT of its plate and animated, as a horizontal sprite sheet
## (tools/gen/gen_foe_figures.py). The arena shows this -- a cultist standing in the room --
## while `art` stays the card, still used for the map, the claim screen and the relic chips.
@export var figure: Texture2D
@export var figure_frames: int = 8
