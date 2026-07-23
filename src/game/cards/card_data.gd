@tool
class_name CardData
extends Resource
## A single Minor Arcana card: rank + aspect (colour) + optional keyword.
## Authorable in the editor as a .tres; the slice builds a deck in code for now.

## Slice keyword subset. NONE = plain fuel card.
enum Keyword { NONE, GNICIE, FURIA, OSLONA }

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
		Keyword.GNICIE: return "KW_GNICIE"
		Keyword.FURIA: return "KW_FURIA"
		Keyword.OSLONA: return "KW_OSLONA"
	return ""
