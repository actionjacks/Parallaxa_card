@tool
class_name ArcanumData
extends Resource
## A Major Arcanum kept as a passive relic. In the full game an Arcanum is also the boss you beat
## to claim it (Fool's Journey). Effects are DISTINCT playstyles, not one formula:
##  MULT_IF_ASPECT  - xMult when the played hand contains effect_aspect (scoring)
##  EXTRA_DISCARD   - +effect_value discards every turn (consistency)
##  BLOCK_ON_PLAY   - +effect_value block with every play (defence)
##  HEAL_ON_PLAY    - +effect_value HP with every play (sustain)
##  PACT_MULT       - xeffect_mult on EVERY hand, but enemy hits hurt +effect_value more (the Devil's deal)
##  MAGNIFY         - xeffect_mult itself, AND other relics' xMult bonuses are amplified (the Magician)
## All deterministic; per-play effects resolve in scoring so the preview never lies.

enum Effect { NONE, MULT_IF_ASPECT, EXTRA_DISCARD, BLOCK_ON_PLAY, HEAL_ON_PLAY, PACT_MULT, MAGNIFY }

## What a REVERSED claim costs (chosen at the boss reward: upright vs reversed). Append-only.
enum Price { NONE, MAX_HP, RTEC_TAX, SELF_CURSE }

@export var name_key: String = ""
@export var effect: Effect = Effect.NONE
@export var effect_aspect: Aspects.Id = Aspects.Id.DEATH
@export var effect_mult: float = 1.5
@export var effect_value: int = 0
@export var art: Texture2D            ## RWS 1909 card scan (assets/cards/arcana/, public domain)

## Reversed variant (the profaned card: stronger effect, visible price). 0.0 / -1 = keep upright.
@export var reversed_mult: float = 0.0
@export var reversed_value: int = -1
@export var price: Price = Price.NONE
@export var price_value: int = 0

## Runtime-only (per-run instance made by RunState._materialize; never saved into the .tres).
var is_reversed: bool = false
var source_path: String = ""          ## original .tres path (duplicate() drops resource_path)

## Player-facing one-liner of what this relic does. Reversed instances carry their tag + price.
func describe() -> String:
	var text := ""
	match effect:
		Effect.MULT_IF_ASPECT:
			text = tr("ARC_FX_MULT") % [String.num(effect_mult, 1), tr(Aspects.name_key(effect_aspect))]
		Effect.EXTRA_DISCARD:
			text = tr("ARC_FX_DISCARD") % effect_value
		Effect.BLOCK_ON_PLAY:
			text = tr("ARC_FX_BLOCK") % effect_value
		Effect.HEAL_ON_PLAY:
			text = tr("ARC_FX_HEAL") % effect_value
		Effect.PACT_MULT:
			text = tr("ARC_FX_PACT") % [String.num(effect_mult, 2), effect_value]
		Effect.MAGNIFY:
			text = tr("ARC_FX_MAGNIFY_REV" if is_reversed else "ARC_FX_MAGNIFY") % String.num(effect_mult, 2)
	if is_reversed:
		text = tr("ARC_REVERSED_TAG") + text
		var pl := price_line()
		if pl != "":
			text += "\n" + pl
	return text

## The price sentence a reversed claim shows (empty for Price.NONE -- the deepened pact IS the price).
func price_line() -> String:
	match price:
		Price.MAX_HP:
			return tr("ARC_PRICE_MAXHP") % price_value
		Price.RTEC_TAX:
			return tr("ARC_PRICE_TAX") % price_value
		Price.SELF_CURSE:
			return tr("ARC_PRICE_CURSE") % price_value
	return ""

## Locale key of the one-line playstyle blurb shown at the opening draft (first-60s context).
func blurb_key() -> String:
	return name_key + "_BLURB"
