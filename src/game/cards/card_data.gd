@tool
class_name CardData
extends Resource
## A single Minor Arcana card: rank + aspect (colour) + optional keyword.
## Authorable in the editor as a .tres; the slice builds a deck in code for now.

## Keyword vocabulary spread across the five Aspects. NONE = plain fuel card.
## LIFE: Oslona (block), Opatrznosc (heal). MIND: Echo (chips per play this fight).
## DEATH: Gnicie (rot DoT), Zniwo (mult per card in grave). CHAOS: Furia (x1.5 mult if no block),
## Spalenie (flat direct damage). NATURE: Bujnosc (bonus chips if >=3 cards of one aspect).
## Wave 2 appended at the END (saved .tres store enum ints): NATURE Wzrost (grows each turn in hand)
## / Symbioza (chips per allied-colour card in the play); DEATH Pijawka (leech % of damage) /
## Klatwa (stacking +% damage debuff on the enemy).
enum Keyword { NONE, OSLONA, OPATRZNOSC, GNICIE, ZNIWO, FURIA, SPALENIE, ECHO, BUJNOSC, WZROST, SYMBIOZA, PIJAWKA, KLATWA }

## Shop editions (bought with Rtec): Foil +chips, Holo +mult, Polychrome xmult.
enum Edition { NONE, FOIL, HOLO, POLYCHROME }

@export var rank: int = 2                  ## 1 = Ace, 2..10 pips, 11 Page, 12 Knight, 13 Queen, 14 King
@export var aspect: Aspects.Id = Aspects.Id.LIFE
@export var keyword: Keyword = Keyword.NONE
@export var keyword_value: int = 0         ## magnitude for Gnicie X / Oslona X
@export var edition: Edition = Edition.NONE

## Runtime ramp from the WZROST keyword: accumulated bonus chips. Not exported on purpose --
## a run-local state that resets when the card is duplicated into a new run.
var growth: int = 0

## Chip material a card contributes: pips = face, Ace = 11, courts flat 10 (Balatro-like).
func chip_value() -> int:
	var base := rank
	if rank == 1:
		base = 11
	elif rank >= 11:
		base = 10
	return base + growth

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
		Keyword.WZROST: return "KW_WZROST"
		Keyword.SYMBIOZA: return "KW_SYMBIOZA"
		Keyword.PIJAWKA: return "KW_PIJAWKA"
		Keyword.KLATWA: return "KW_KLATWA"
	return ""

static func edition_name_key(e: int) -> String:
	match e:
		Edition.FOIL: return "ED_FOIL"
		Edition.HOLO: return "ED_HOLO"
		Edition.POLYCHROME: return "ED_POLYCHROME"
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
		Keyword.WZROST: return "KWD_WZROST"
		Keyword.SYMBIOZA: return "KWD_SYMBIOZA"
		Keyword.PIJAWKA: return "KWD_PIJAWKA"
		Keyword.KLATWA: return "KWD_KLATWA"
	return ""

## Aspect that a keyword thematically belongs to (for generated content / tinting).
static func keyword_aspect(kw: int) -> int:
	match kw:
		Keyword.OSLONA, Keyword.OPATRZNOSC: return Aspects.Id.LIFE
		Keyword.ECHO: return Aspects.Id.MIND
		Keyword.GNICIE, Keyword.ZNIWO: return Aspects.Id.DEATH
		Keyword.FURIA, Keyword.SPALENIE: return Aspects.Id.CHAOS
		Keyword.BUJNOSC, Keyword.WZROST, Keyword.SYMBIOZA: return Aspects.Id.NATURE
		Keyword.PIJAWKA, Keyword.KLATWA: return Aspects.Id.DEATH
	return Aspects.Id.LIFE
