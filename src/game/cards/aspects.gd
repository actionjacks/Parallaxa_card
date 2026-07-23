class_name Aspects
## The five colour identities (Aspects). Colours = MTG-style philosophies, not elements.
## Presentation helpers only; mechanics live in Scoring / keywords.

enum Id { LIFE, MIND, DEATH, CHAOS, NATURE }

const COLORS: Dictionary = {
	Id.LIFE: Color("f4e2a1"),   # warm gold — order / life
	Id.MIND: Color("6ec6ff"),   # blue — mind
	Id.DEATH: Color("9a6bd6"),  # violet — death
	Id.CHAOS: Color("ff6b57"),  # red — chaos / will
	Id.NATURE: Color("74c46b"), # green — nature / growth
}

const NAME_KEYS: Dictionary = {
	Id.LIFE: "ASPECT_LIFE",
	Id.MIND: "ASPECT_MIND",
	Id.DEATH: "ASPECT_DEATH",
	Id.CHAOS: "ASPECT_CHAOS",
	Id.NATURE: "ASPECT_NATURE",
}

static func color(id: int) -> Color:
	return COLORS.get(id, Color.WHITE)

static func name_key(id: int) -> String:
	return NAME_KEYS.get(id, "")
