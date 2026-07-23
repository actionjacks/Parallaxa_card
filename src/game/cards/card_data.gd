@tool
class_name CardData
extends Resource
## A single Minor Arcana card: rank + aspect (colour) + optional keyword.
## Authorable in the editor as a .tres; the slice builds a deck in code for now.

## Keyword vocabulary spread across the five Aspects. NONE = plain fuel card.
## LIFE: Oslona (block), Opatrznosc (heal). MIND: Echo (chips per play this fight).
## DEATH: Gnicie (rot DoT), Zniwo (mult per card in grave). CHAOS: Furia (x1.5 mult if no block),
## Spalenie (flat direct damage). NATURE: Bujnosc (bonus chips if >=3 cards of one aspect).
enum Keyword { NONE, OSLONA, OPATRZNOSC, GNICIE, ZNIWO, FURIA, SPALENIE, ECHO, BUJNOSC }

@export var rank: int = 2                  ## 1 = Ace, 2..10 pips, 11 Page, 12 Knight, 13 Queen, 14 King
@export var aspect: Aspects.Id = Aspects.Id.LIFE
@export var keyword: Keyword = Keyword.NONE
@export var keyword_value: int = 0         ## magnitude for Gnicie X / Oslona X

## Chip material a card contributes: pips = face, Ace = 11, courts flat 10 (Balatro-like).
func chip_value() -> int:
	if rank == 1:
		return 11
	if rank >= 11:
		return 10
	return rank

## Short rank glyph for the card face (language-neutral card notation).
func rank_glyph() -> String:
	match rank:
		1: return "A"
		11: return "P"   # Page / Paz
		12: return "R"   # Knight / Rycerz
		13: return "Q"   # Queen / Krolowa
		14: return "K"   # King / Krol
	return str(rank)

static func keyword_name_key(kw: int) -> String:
	match kw:
		Keyword.OSLONA: return "KW_OSLONA"
		Keyword.OPATRZNOSC: return "KW_OPATRZNOSC"
		Keyword.GNICIE: return "KW_GNICIE"
		Keyword.ZNIWO: return "KW_ZNIWO"
		Keyword.FURIA: return "KW_FURIA"
		Keyword.SPALENIE: return "KW_SPALENIE"
		Keyword.ECHO: return "KW_ECHO"
		Keyword.BUJNOSC: return "KW_BUJNOSC"
	return ""

static func keyword_desc_key(kw: int) -> String:
	match kw:
		Keyword.OSLONA: return "KWD_OSLONA"
		Keyword.OPATRZNOSC: return "KWD_OPATRZNOSC"
		Keyword.GNICIE: return "KWD_GNICIE"
		Keyword.ZNIWO: return "KWD_ZNIWO"
		Keyword.FURIA: return "KWD_FURIA"
		Keyword.SPALENIE: return "KWD_SPALENIE"
		Keyword.ECHO: return "KWD_ECHO"
		Keyword.BUJNOSC: return "KWD_BUJNOSC"
	return ""

## Aspect that a keyword thematically belongs to (for generated content / tinting).
static func keyword_aspect(kw: int) -> int:
	match kw:
		Keyword.OSLONA, Keyword.OPATRZNOSC: return Aspects.Id.LIFE
		Keyword.ECHO: return Aspects.Id.MIND
		Keyword.GNICIE, Keyword.ZNIWO: return Aspects.Id.DEATH
		Keyword.FURIA, Keyword.SPALENIE: return Aspects.Id.CHAOS
		Keyword.BUJNOSC: return Aspects.Id.NATURE
	return Aspects.Id.LIFE
