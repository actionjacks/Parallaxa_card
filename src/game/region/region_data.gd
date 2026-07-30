@tool
class_name RegionData
extends Resource
## One region of the run: a linear ladder of fights, then a boss. Authorable in the editor.
## Beating the boss grants boss_arcanum (Fool's Journey). starting_arcanum is the run's opening boon.

@export var name_key: String = ""
@export var fights: Array[EnemyData] = []          ## legacy fixed ladder (fallback)
@export var fight_pool_1: Array[EnemyData] = []    ## node 1 candidates -- one is rolled per run
@export var fight_pool_2: Array[EnemyData] = []    ## node 2 candidates -- one is rolled per run
@export var boss: EnemyData
@export var boss_arcanum: ArcanumData
@export var starting_arcanum: ArcanumData          ## legacy fallback when starting_pool is empty
@export var starting_pool: Array[ArcanumData] = [] ## run start: draft 1 of 3 random picks from here
@export var accent: Color = Color(0.6, 0.6, 0.65)  ## region identity tint: map header + backdrop
@export var elite: EnemyData                       ## the region's elite (map fork: risk for loot)
@export var boss_pool: Array[EnemyData] = []       ## boss ROTATION: one is rolled per run (Fool's
                                                   ## Journey: different runs climb different Arcana)

## --- BIOMES (append-only: saved .tres store these by name, never reorder the Law enum) ---

## The FIELD LAW of every duel fought in this biome. Bosses stack their own rule on top of it.
## Every law is deterministic and visible, so the combat preview stays exact.
##  LIFE_TITHE       +2 block per card played, and a deeper heal pool -- the biome you survive
##  MIND_ARCHIVE     one more card in hand -- the biome where a straight finally assembles
##  DEATH_HARVEST    +2 chips per card in the grave -- the biome that pays for a long fight
##  CHAOS_KINDLING   five-card plays x1.5 mult, one/two-card plays x0.75 -- the biome that
##                   teaches you to play a whole hand
##  NATURE_OVERGROWTH  cards left in hand fatten every turn -- the biome where holding back pays
##  SEAL_FIVE        +1 mult per DISTINCT Aspect in the play -- the hidden biome inverts the
##                   whole game: after a journey spent chasing one colour, it pays for all five
enum Law { NONE, LIFE_TITHE, MIND_ARCHIVE, DEATH_HARVEST, CHAOS_KINDLING, NATURE_OVERGROWTH, SEAL_FIVE }

@export var law: Law = Law.NONE
@export var law_key: String = ""                   ## locale key describing the law on the map
## Which colour's SEAL this biome grants when its boss falls. -1 = grants none (the World, and
## the hidden biome, which is the seals' reward rather than one of them).
@export var seal_aspect: int = -1
@export var hidden: bool = false                   ## never offered as a normal biome choice
