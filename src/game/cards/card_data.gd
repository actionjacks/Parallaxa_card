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
## Wave 3 (the exponential vector, appended): CHAOS Przeciazenie (x2 Mult glass card with a visible
## durability counter -- shatters at 0) / Lawina (card chips re-score once per Chaos card, max 3);
## MIND Kombinat (xMult grows per consecutive play of the same hand type).
## Wave C (appended): NATURE Korzenie -- block that ROOTS: +2 block for every turn the card
## waited in hand (run-local ramp, preview-exact; the block twin of Wzrost).
## Wave D -- POSITIONAL keywords (docs/todo.md par.1). These are the first keywords whose effect
## depends on WHERE in the play the card sits, which is what turns "which five cards" into a
## sentence you compose rather than a set you pick:
##   WROZBA (MIND)  played FIRST, it foretells: every card to its RIGHT scores +value chips.
##   OFIARA (DEATH) played LAST, it devours the card immediately to its LEFT -- that card is
##                  destroyed and its chips are absorbed for the rest of the fight.
enum Keyword { NONE, OSLONA, OPATRZNOSC, GNICIE, ZNIWO, FURIA, SPALENIE, ECHO, BUJNOSC, WZROST, SYMBIOZA, PIJAWKA, KLATWA, PRZECIAZENIE, LAWINA, KOMBINAT, KORZENIE, WROZBA, OFIARA }

## Shop editions (bought with Rtec): Foil +chips, Holo +mult, Polychrome xmult.
enum Edition { NONE, FOIL, HOLO, POLYCHROME }

## Offer rarity: shop/reward odds and frame colour. Default COMMON keeps every existing .tres valid.
enum Rarity { COMMON, RARE, LEGENDARY }

@export var rank: int = 2                  ## 1 = Ace, 2..10 pips, 11 Page, 12 Knight, 13 Queen, 14 King
@export var aspect: Aspects.Id = Aspects.Id.LIFE
@export var keyword: Keyword = Keyword.NONE
@export var keyword_value: int = 0         ## magnitude for Gnicie X / Oslona X; PRZECIAZENIE: max durability
@export var edition: Edition = Edition.NONE
@export var rarity: Rarity = Rarity.COMMON

## Runtime ramp from the WZROST keyword: accumulated bonus chips. Not exported on purpose --
## a run-local state that resets when the card is duplicated into a new run.
var growth: int = 0

## Runtime wear from the PRZECIAZENIE keyword: plays survived. Persisted in the RUN save (not the
## .tres) -- the glass cracks across fights within one run. durability left = keyword_value - wear.
@export var wear: int = 0

## Runtime ramp from the KORZENIE keyword: accumulated bonus BLOCK (separate from `growth`,
## which feeds chips -- roots must not double-dip into chip value). Transient like growth.
var bloom: int = 0

## THE SCAR (docs/PLAN_TODO.md T5): permanent chips a card earned by landing the killing blow on
## a boss. Its own field, NOT `growth` -- growth is deliberately transient (Wzrost resets every
## fight and is never written to the run save), so reusing it would both break Wzrost and lose
## the scar on the next load. Scars are saved with the run.
@export var scar: int = 0

## REVERSED (docs/PLAN_TODO.md T4): the card has been turned upside down in a shop. Its Aspect
## was CHANGED IN PLACE at that moment to its enemy on the pentagram, so nothing downstream has
## to know -- a reversed card simply IS the other colour, and flushes, Symbioza and the sigil all
## keep working unchanged. This flag only drives the payoff multiplier and the inverted art.
@export var inverted: bool = false

## CRACKED (docs/todo.md par.5, "Trauma po Wiezy"): a card the Tower shattered and you won back
## anyway. It lost a third of its chip base for good, but it survived something -- so any
## retrigger in the play (Lawina) fires TWICE on it. A scar that costs you and pays you.
@export var cracked: bool = false

## SPLASH (docs/todo.md "Karty Dwukolorowe"): a SECOND Aspect the card also counts as, carved in
## a shop. -1 = single-coloured. A splashed card belongs to BOTH colours at once, which is what
## makes a two-colour deck coherent instead of a compromise.
@export var splash: int = -1

## THE FEAST (docs/todo.md par.1, "wysysajac z niej Chipsy i Mult"): how many cards this Ofiara has
## devoured THIS FIGHT. Per-fight like `growth`, never exported -- the sacrifice is a thing that
## happens in a duel, not a property of the card in your deck.
var feast: int = 0

## Every Aspect this card counts as. One entry for a plain card, two for a splashed one --
## everything that asks about colour asks THIS, so a hybrid works everywhere at once.
func aspects() -> Array:
	return [int(aspect), splash] if splash >= 0 else [int(aspect)]

func has_aspect(a: int) -> bool:
	return int(aspect) == a or splash == a

## Chip material a card contributes: pips = face, Ace = 11, courts flat 10 (Balatro-like).
func chip_value() -> int:
	var base := rank
	if rank == 1:
		base = 11
	elif rank >= 11:
		base = 10
	# A cracked card carries a permanent third off its base -- rounded so a small card is not
	# reduced to nothing.
	if cracked:
		base = maxi(1, base - maxi(1, int(round(base / 3.0))))
	return base + growth + scar

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
		Keyword.PRZECIAZENIE: return "KW_PRZECIAZENIE"
		Keyword.LAWINA: return "KW_LAWINA"
		Keyword.KOMBINAT: return "KW_KOMBINAT"
		Keyword.KORZENIE: return "KW_KORZENIE"
		Keyword.WROZBA: return "KW_WROZBA"
		Keyword.OFIARA: return "KW_OFIARA"
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
		Keyword.PRZECIAZENIE: return "KWD_PRZECIAZENIE"
		Keyword.LAWINA: return "KWD_LAWINA"
		Keyword.KOMBINAT: return "KWD_KOMBINAT"
		Keyword.KORZENIE: return "KWD_KORZENIE"
		Keyword.WROZBA: return "KWD_WROZBA"
		Keyword.OFIARA: return "KWD_OFIARA"
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
		Keyword.PRZECIAZENIE, Keyword.LAWINA: return Aspects.Id.CHAOS
		Keyword.KOMBINAT: return Aspects.Id.MIND
		Keyword.KORZENIE: return Aspects.Id.NATURE
		Keyword.WROZBA: return Aspects.Id.MIND
		Keyword.OFIARA: return Aspects.Id.DEATH
	return Aspects.Id.LIFE
