@tool
class_name DeckData
extends Resource
## An ordered list of cards, authorable in the editor. Used for the starter deck and reward pools.

@export var name_key: String = ""
@export var cards: Array[CardData] = []
