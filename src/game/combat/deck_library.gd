class_name DeckLibrary
## TEMPORARY code-authored starter content for the vertical slice.
## TODO(editor-first): migrate the deck to authorable .tres cards + a DeckData resource.
## The enemy and the Arcanum already live as .tres in data/combat/ (see combat.gd).

const A := Aspects.Id
const KW := CardData.Keyword

## A deterministic ~16-card deck skewed to Death + Chaos, with a few Life defenders.
## Many 7s across colours so pairs / three / four-of-a-kind and a Death flush are reachable.
static func starter_deck() -> Array:
	var d: Array = []
	# Death (violet) — Gnicie DoT
	d.append(_c(7, A.DEATH, KW.GNICIE, 3))
	d.append(_c(7, A.DEATH))
	d.append(_c(9, A.DEATH, KW.GNICIE, 4))
	d.append(_c(4, A.DEATH))
	d.append(_c(14, A.DEATH, KW.GNICIE, 5))   # King of Death (court innate)
	d.append(_c(2, A.DEATH))
	# Chaos (red) — Furia burst
	d.append(_c(7, A.CHAOS))
	d.append(_c(5, A.CHAOS, KW.FURIA))
	d.append(_c(9, A.CHAOS, KW.FURIA))
	d.append(_c(12, A.CHAOS))                 # Knight of Chaos
	# Life (gold) — Oslona block
	d.append(_c(7, A.LIFE, KW.OSLONA, 6))
	d.append(_c(3, A.LIFE))
	d.append(_c(14, A.LIFE, KW.OSLONA, 8))    # King of Life
	d.append(_c(6, A.LIFE))
	# splash
	d.append(_c(7, A.MIND))
	d.append(_c(8, A.NATURE))
	return d

static func _c(rank: int, aspect: int, kw: int = CardData.Keyword.NONE, val: int = 0) -> CardData:
	var c := CardData.new()
	c.rank = rank
	c.aspect = aspect
	c.keyword = kw
	c.keyword_value = val
	return c
