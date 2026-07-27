# P2 SPEC — Exponential Power Vector, Starter Rework, Reversed Arcana (P4 reward side)

Target: Godot 4.7, Parallaxa_card. Combat stays 100% deterministic (preview computes everything below exactly). The only RNG used here is `RunState.rng` (tier rolls, offers). All enums are APPEND-ONLY. All player text via `data/locale/ui.csv` keys (appendix at bottom, EN+PL). Layout budget 1280x720, combat controls stay bottom-anchored.

Design goal in numbers: current damage ceiling ~500. After P2 a committed build reaches ~3,000–6,000 in Region 3 and ~15,000–40,000 vs the World with a full Glass/Combo/Magician stack (worked example in §1.5). Fights are not retuned here — P1 owns HP curves; this spec only builds the vector.

---

## 0. Scoring pipeline — canonical order of operations

`Scoring.score(cards, relics, ctx)` computes in THIS exact order (integrator: restructure the function to match; every step is pure and preview-exact):

```
1. hand   = Poker.evaluate(cards)                      # may now return MAGNUM_OPUS
2. chips, mult = Poker.leveled_base(hand, level)
3. per-card loop (existing): chips += chip_value(); editions (FOIL +15 chips,
   HOLO +2 mult, POLYCHROME poly *= 1.3); flat keywords (OSLONA/OPATRZNOSC/
   GNICIE/SPALENIE/ECHO/ZNIWO/BUJNOSC/SYMBIOZA) unchanged.
   While looping also accumulate:
     retrig_total += chip_value() + (15 if edition == FOIL else 0)
     chaos_count  += 1 if aspect == CHAOS
     has_lawina    = true if keyword == LAWINA
     glass_count  += 1 if keyword == PRZECIAZENIE
     kombinat_cards.append(c) if keyword == KOMBINAT
4. LAWINA:      if has_lawina: chips += retrig_total * mini(3, chaos_count)
5. FURIA:       if has_furia and block == 0: mult *= 1.5            (unchanged)
6. KOMBINAT:    streak = trailing count of ctx["hand_history"] entries == hand,
                capped at 4; for each kombinat card:
                mult *= 1.0 + (c.keyword_value / 100.0) * streak
7. PRZECIAZENIE: mult *= pow(2.0, glass_count)
8. relics loop (existing effects) with Magician amplification (§5):
                for mult-type effects use eff_mult = 1.0 + (effect_mult - 1.0) * K
9. mult *= poly                                                     (unchanged)
10. damage = int(round(chips * mult * (1.0 + klatwa / 100.0))) + flat  (unchanged)
```

New ctx key: `"hand_history": Array[int]` — the Poker.Hand of every play already made this fight, in order. `CombatController` appends `int(result["hand"])` after each `play()` (new field `var _hand_history: Array = []`, reset in `start()`, included in `_ctx()`). `ctx.get("hand_history", [])` defaults to empty (streak 0) so existing tests keep passing.

---

## 1. Three new keywords (append to `CardData.Keyword` AFTER `KLATWA` — never reorder)

```gdscript
enum Keyword { NONE, OSLONA, OPATRZNOSC, GNICIE, ZNIWO, FURIA, SPALENIE, ECHO,
    BUJNOSC, WZROST, SYMBIOZA, PIJAWKA, KLATWA, PRZECIAZENIE, LAWINA, KOMBINAT }
# PRZECIAZENIE = 13, LAWINA = 14, KOMBINAT = 15
```

`keyword_aspect()`: PRZECIAZENIE, LAWINA -> `Aspects.Id.CHAOS`; KOMBINAT -> `Aspects.Id.MIND` (matches DESIGN.md: Przeciazenie/Lawina are Chaos, Kombinat is Mind).
`keyword_name_key()` / `keyword_desc_key()`: add the three KW_/KWD_ keys (appendix).

### 1.1 PRZECIAZENIE (Overload) — glass xMult with a visible durability counter

- Effect: **x2.0 Mult per Overload card in the play** (fixed, not authorable; `keyword_value` is reserved for durability). Two glass cards in one hand = x4.0.
- Durability: `keyword_value` = max durability (authored 2 or 3). New run-local field on `CardData`:
  ```gdscript
  var wear: int = 0   # non-exported, like `growth`; plays survived
  ```
  `durability_left = keyword_value - wear`.
- Wear rule: every time the card is included in a **played** (scored) hand, `wear += 1` after the play resolves. Discarding does NOT wear it.
- At 0 (`wear >= keyword_value`): the card **shatters** — it is removed from the fight (it does NOT enter `_used`, so it never recycles) and removed from the run deck permanently.
  - `CombatController` gains `var destroyed_cards: Array = []` (cleared in `start()`). In `play()`, after `_move_to_used(selected)` runs, pull each shattered instance back out of `_used` into `destroyed_cards` (or better: partition before `_move_to_used` — spec: partition; shattered cards go straight to `destroyed_cards`, the rest to `_used`).
  - `ctx["grave"]` stays `_used.size()` (shattered cards are gone, not harvestable — Zniwo counts the grave, not the void; this keeps existing Zniwo balance and the preview trivial).
  - On fight WON: the fight-result path calls `RunState.deck.erase(c)` for every entry of `destroyed_cards` (identity erase works — combat is fed the same `CardData` instances that live in `RunState.deck`), then `RunState.changed.emit()`. On fight LOST: do nothing (run is over).
  - Shattering on the killing blow still shatters (payment is honest).
- Persistence: `wear` survives between fights within the run. `RunState.save_run` deck dicts gain `"w": c.wear` (default 0 on load — old saves migrate cleanly, see §6.4).
- VISIBLE counter (covenant: the player must never be surprised):
  - `card_widget.gd` draws a durability pip bottom-right of the card face: label text `"◆%d" % durability_left` ("◆3"), font 13, color `Color("e8e8f0")` when left >= 2, `Color("ff5a4d")` when left == 1.
  - Combat preview panel: when any selected Overload card has `durability_left == 1`, append line `PREVIEW_SHATTER` (red, `Color("ff5a4d")`) under the score line. Bottom-anchored controls unaffected (one 18px line inside the existing preview panel).

### 1.2 LAWINA (Avalanche) — retrigger

- Trigger: the played hand contains **at least one** LAWINA card.
- Effect: the play's card-chip total is re-scored once per Chaos-aspect card in the play:
  `chips += retrig_total * N`, where
  - `retrig_total` = sum over ALL played cards of `chip_value() + (15 if FOIL)` (includes WZROST growth; excludes keyword chips — Echo/Bujnosc/Symbioza fire once, no recursion),
  - `N = mini(3, chaos_count)`; `chaos_count` counts CHAOS-aspect cards in the play **including the Lawina card itself if it is Chaos** (it always is, in shipped content).
- Cap: N is capped at **3** and is GLOBAL per play — multiple Lawina cards do not stack N (a second Lawina card is still a Chaos body, so it raises `chaos_count` by 1 up to the cap).
- `keyword_value` unused; author as 0.

### 1.3 KOMBINAT (Combine) — escalating xMult off the play history

- Uses `ctx["hand_history"]` (§0). `streak` = number of consecutive trailing entries equal to the CURRENT hand type. Example: history `[PAIR, PAIR, FLUSH, FLUSH]`, current play FLUSH -> streak 2; current play PAIR -> streak 0.
- Effect per Kombinat card in the play: `mult *= 1.0 + (keyword_value / 100.0) * mini(streak, 4)`.
  - Authored values 50 and 75: at value 50, streaks give x1.0 / x1.5 / x2.0 / x2.5 / x3.0 (cap).
  - Two Kombinat cards multiply together (x2.0 * x2.0 = x4.0 at streak 2, value 50).
- Reset rule: implicit — playing a different hand type makes streak 0 for that play and truncates the trailing run for future plays (the history array itself is never cleared during a fight; it resets when a new fight `start()`s).
- First play of a fight: history empty -> streak 0 -> x1.0. The preview shows this exactly.

### 1.4 Preview

No special casing: all three resolve inside `Scoring.score` from `cards + ctx`, so `CombatController.preview()` is already exact. The only preview ADDITIONS are the shatter warning line (§1.1) and lethal/overkill line (§4).

### 1.5 Worked ceiling example (sanity, Region 3)

Flush of Chaos, hand level 2 (65 chips x 8 mult), cards ~45 chips, one Lawina retrigger x3 (+135 chips) -> 245 chips. Mult: 8 (base) x2 (one glass) x2.0 (Kombinat 50 @ streak 2) x [Tower reversed x2.0 amplified by Magician: 1+(1.0*2)=3.0] x1.3 poly = 8*2*2*3*1.3 = 124.8 -> **245 x 124.8 ≈ 30,576**. Without any P2 pieces the same deck scores ~600. Vector confirmed exponential, and every factor is a drafted choice.

---

## 2. Secret hand: MAGNUM OPUS (five of a kind, one Aspect)

- `Poker.Hand` enum append AFTER `FIVE` (append-only):
  ```gdscript
  enum Hand { HIGH_CARD, PAIR, TWO_PAIR, THREE, STRAIGHT, FLUSH, FULL_HOUSE,
      FOUR, STRAIGHT_FLUSH, FIVE, MAGNUM_OPUS }   # MAGNUM_OPUS = 10
  ```
- `BASE[Hand.MAGNUM_OPUS] = [160, 16]` (above FIVE's [120, 12]; Balatro Flush-Five calibration).
- `LEVEL_UP[Hand.MAGNUM_OPUS] = [50, 5]`.
- `NAME_KEYS[Hand.MAGNUM_OPUS] = "HAND_MAGNUM_OPUS"`.
- Detection in `Poker.evaluate` — insert immediately after `flush`/`straight` are computed, BEFORE the straight-flush branch:
  ```gdscript
  if top == 5 and flush:
      return Hand.MAGNUM_OPUS
  ```
  (`top == 5` implies one rank, so `_is_straight` is false — no interaction with STRAIGHT_FLUSH. `_is_flush` already requires exactly 5 cards.)
- NOT in `run.gd` `STAR_HANDS` (secret hands cannot be leveled by shop Stars in P2; `hand_levels` dict handles the new int key with default 0 regardless).
- Buildable, never dealt: requires five copies of one rank in one Aspect — only reachable by drafting duplicates from the pool across shop/reward visits. The starter (§3) caps at 3 of a rank, so the apex is always constructed.
- Locale: `HAND_MAGNUM_OPUS,Magnum Opus,Magnum Opus` (same in EN and PL — it is Latin, diegetic alchemy).

---

## 3. Starter rework — 16 cards, max 3 of any rank

Replace `_starter()` in `tools/gen/gen_content.gd` with EXACTLY (format `[rank, aspect, keyword, value]`):

```gdscript
func _starter() -> Array:
    return [
        # DEATH (5) — the thematic lean, flush-draftable
        [7,  A.DEATH,  KW.GNICIE, 3], [7, A.DEATH, KW.NONE, 0], [9, A.DEATH, KW.GNICIE, 4],
        [14, A.DEATH,  KW.GNICIE, 5], [2, A.DEATH, KW.NONE, 0],
        # CHAOS (4)
        [7,  A.CHAOS,  KW.NONE, 0],  [5, A.CHAOS, KW.FURIA, 0], [9, A.CHAOS, KW.FURIA, 0],
        [12, A.CHAOS,  KW.SPALENIE, 6],
        # LIFE (3)
        [3,  A.LIFE,   KW.OSLONA, 6], [14, A.LIFE, KW.OSLONA, 8], [6, A.LIFE, KW.OPATRZNOSC, 5],
        # MIND (2)
        [5,  A.MIND,   KW.ECHO, 4],  [10, A.MIND, KW.ECHO, 6],
        # NATURE (2)
        [8,  A.NATURE, KW.BUJNOSC, 20], [6, A.NATURE, KW.NONE, 0],
    ]
```

Diff vs current starter: exactly two substitutions — `[7, LIFE, OSLONA, 6]` -> `[3, LIFE, OSLONA, 6]` and `[7, MIND, ECHO, 4]` -> `[5, MIND, ECHO, 4]`. Everything else byte-identical (minimal churn; `Profile.starter_editions` indices stay meaningful — see conflicts).

Rank census: 7 x3 (D,D,C — AT cap), 9 x2, 14 x2, 5 x2, 6 x2, 2/3/8/10/12 x1. Max any rank = 3. **FIVE and MAGNUM_OPUS are unreachable from the dealt starter.**

Why it still teaches:
- Turn 1 (8-card hand from 16) almost always holds a 7-pair -> Pair is the on-ramp.
- Exactly three 7s across three Aspects -> Three-of-a-Kind is the first BUILT discovery (hold, discard, assemble) and teaches cross-colour sets.
- 2,3,5,6,7,8,9,10 -> a 5-9 or 6-10 Straight is assemblable with discards -> teaches sequencing.
- 5 Death cards -> a Death Flush exists in the deck but rarely in one dealt hand -> teaches discard-fishing and gives the draft its first goal ("more Death"), and Flush (35x4) is mid-table, not the apex.
- Apex ladder now reads: dealt Pair -> built Trips -> fished Flush -> drafted Kareta/FIVE -> engineered MAGNUM_OPUS. Every tier above the floor is earned.

---

## 4. Overkill pays (excess damage -> Rtec)

- Formula (integer math): on the event that drops `enemy_hp` to `<= 0` — a scored play OR a Gnicie tick — compute BEFORE clamping:
  ```
  excess     = -enemy_hp                # hp after subtraction, before clamp to 0
  bonus_rtec = clampi(excess / 50, 0, 5)   # integer division; cap 5 mirrors the interest cap
  ```
- `CombatController` gains `var overkill_rtec: int = 0` (reset in `start()`); set it inside the two kill sites in `play()` and `resolve_enemy_turn()` (there is exactly one killing event per fight).
- Transport: `RunState` gains `var pending_overkill: int = 0`. The combat scene writes `RunState.pending_overkill = controller.overkill_rtec` when `ended(true)` fires. In `run.gd`'s fight-won accrual block (where `reward_rtec`, thrift and interest are added): `RunState.rtec += RunState.pending_overkill`, remember it for the breakdown line, then `RunState.pending_overkill = 0`. Not saved to disk (it is consumed at the map arrival save point before `save_run` runs; if the integrator saves earlier, persist it as `"overkill"` int, default 0).
- Shown in TWO places:
  1. **Combat preview** (the covenant showpiece — the preview ANNOUNCES the jackpot): when previewed `damage >= enemy_hp`, the combat scene appends to the preview panel: `PREVIEW_LETHAL` ("LETHAL") in `Color("ffd75e")`, and if `bonus_rtec > 0`, ` +N ☿` via `PREVIEW_OVERKILL`. Computed scene-side as `clampi((preview_damage - enemy_hp) / 50, 0, 5)` — Scoring stays enemy-agnostic.
  2. **Reward breakdown** on the post-fight screen: line `REWARD_OVERKILL` ("Overkill: +%d ☿") listed alongside the existing reward/thrift/interest lines, only when > 0.
- Gnicie kills count (excess of the tick beyond remaining HP) — usually small; no special UI beyond the reward line.

---

## 5. Meta-relic: THE MAGICIAN (relics multiplying relics)

- `ArcanumData.Effect` enum append AFTER `PACT_MULT`:
  ```gdscript
  enum Effect { NONE, MULT_IF_ASPECT, EXTRA_DISCARD, BLOCK_ON_PLAY, HEAL_ON_PLAY,
      PACT_MULT, MAGNIFY }   # MAGNIFY = 6
  ```
- New resource `data/arcana/arcanum_magician.tres` (add to `gen_content._region()`):
  `name_key "ARCANUM_MAGA"`, `effect MAGNIFY`, `effect_mult 1.15`, `effect_value 0`, `art assets/cards/arcana/01_magician.jpg` (asset exists). Reversed fields (§6): `reversed_mult 1.25`, `price MAX_HP`, `price_value 12`.
- Effect, exact:
  1. The Magician itself grants `mult *= effect_mult` (x1.15 upright, x1.25 reversed) on EVERY play — never dead on draft day.
  2. Amplification constant `K`: `K = 1.0`; if any relic with `effect == MAGNIFY` is worn, `K = 3.0 if that relic.is_reversed else 2.0`. Multiple MAGNIFY relics: take the max K, never stack, and MAGNIFY never amplifies MAGNIFY.
  3. In the scoring relics loop, every OTHER relic's mult-type effect applies as `eff_mult = 1.0 + (relic.effect_mult - 1.0) * K` — this covers `MULT_IF_ASPECT` and `PACT_MULT` (and any future mult effect). Examples upright (K=2): x1.5 -> x2.0; x1.4 -> x1.8; x1.35 -> x1.7; reversed Tower x2.0 -> x3.0.
  4. Flat values are NOT amplified: `effect_value` (block, heal, discards, pact surcharge) unchanged. The Magician multiplies POWER, not bookkeeping.
- Delivery: append the Magician to `region_01.starting_pool` (the run-opening draft becomes 6 options, still pick 1). It is the scaling bet: weak on day one (x1.15), monstrous once boss Arcana accumulate. Not offered reversed at the opening draft (reversed lives only at boss rewards, §6) — its reversed numbers exist for future elite/ascension use.
- `describe()`: add `Effect.MAGNIFY` branch -> `tr("ARC_FX_MAGNIFY") % String.num(effect_mult, 2)`.

---

## 6. Reversed Arcana — all 9 existing + Magician

### 6.1 Data model (`ArcanumData` — new exports; defaults keep every existing .tres loading unchanged)

```gdscript
enum Price { NONE, MAX_HP, RTEC_TAX, SELF_CURSE }   # new enum, itself append-only from now on

@export var reversed_mult: float = 0.0    # 0.0 = reversed keeps upright effect_mult
@export var reversed_value: int = -1      # -1  = reversed keeps upright effect_value
@export var price: Price = Price.NONE     # the reversed card's cost
@export var price_value: int = 0

var is_reversed: bool = false             # runtime only (per-run instance)
var source_path: String = ""              # runtime only; original .tres path for saving
```

### 6.2 Exact numbers per Arcanum

| file (data/arcana/) | Upright (as-is) | Reversed effect | Reversed price |
|---|---|---|---|
| arcanum_death | x1.5 Mult on Death hands | **x2.2** on Death hands | MAX_HP 8 |
| arcanum_sun | +3 HP per play | **+7** HP per play | RTEC_TAX 2 |
| arcanum_priestess | +1 discard per turn | **+3** discards per turn | SELF_CURSE 2 |
| arcanum_devil | x1.35 every hand, hits +2 | **x1.75** every hand, hits **+5** | NONE (the pact IS the price; both sides deepen) |
| arcanum_empress | +4 block per play | **+9** block per play | MAX_HP 6 |
| arcanum_tower | x1.4 Mult on Chaos hands | **x2.0** on Chaos hands | SELF_CURSE 3 |
| arcanum_devil_boss | x1.25 every hand, hits +1 | **x1.6** every hand, hits **+3** | NONE |
| arcanum_moon | +1 discard per turn | **+2** discards per turn | RTEC_TAX 2 |
| arcanum_world | x1.15 every hand, no price | **x1.5** every hand, no surcharge | MAX_HP 10 |
| arcanum_magician (new) | K=2 amp, self x1.15 | **K=3** amp, self **x1.25** | MAX_HP 12 |

(Set `reversed_mult`/`reversed_value` in `gen_content.gd` per the table; devil entries: `reversed_value` 5 and 3; moon/priestess `reversed_value` 2 and 3; sun `reversed_value` 7; empress 9.)

### 6.3 Price mechanics (all deterministic, all visible)

- **MAX_HP**: applied ONCE at claim: `player_max_hp = maxi(20, player_max_hp - price_value)`, then `player_hp = mini(player_hp, player_max_hp)`. Never re-applied on load (max_hp is persisted). No refund path (relics are never removed).
- **RTEC_TAX**: in `run.gd`'s fight-won accrual (after reward + thrift + interest): `tax = sum(price_value over worn reversed relics with price == RTEC_TAX)`; `RunState.rtec = maxi(0, RunState.rtec - tax)`; breakdown line `REWARD_TAX` ("Reversed tax: -%d ☿") when tax > 0. Applies after EVERY won fight including bosses.
- **SELF_CURSE**: enemy hits hurt more. `CombatController` gains `func _curse_surcharge() -> int` = sum of `price_value` over `relics` where `is_reversed and price == SELF_CURSE`. In `resolve_enemy_turn()`: `taken += _pact_surcharge() + _curse_surcharge()` when `incoming > 0` (same slot as the existing pact bill). MANDATORY companion change: the intent label must display `current_intent() + _pact_surcharge() + _curse_surcharge()` so `COMBAT_INTENT` never understates the hit (see Conflicts — the pact surcharge is already missing from the label today).

### 6.4 Claim flow, storage, save migration

- `RunState.claim_relic` becomes `claim_relic(a: ArcanumData, reversed: bool = false)`:
  ```
  inst = _materialize(a.resource_path, reversed)
  if reversed and inst.price == Price.MAX_HP: apply §6.3 MAX_HP now
  relics.append(inst); changed.emit()
  ```
- `_materialize(path, reversed) -> ArcanumData`: `load(path).duplicate()`; `source_path = path`; if reversed: `is_reversed = true`; `if reversed_mult > 0.0: effect_mult = reversed_mult`; `if reversed_value >= 0: effect_value = reversed_value`. (Duplicating means scoring/controller code needs NO reversed branches for mult/value — only Price and MAGNIFY-K read `is_reversed`.)
- Save format: `save_run` writes `relics` as an Array of Dictionaries: `{"p": source_path (fallback resource_path), "r": is_reversed}`.
- **Migration** in `load_run`: for each entry — `if entry is String: relics.append(_materialize(entry, false))` (all pre-P2 saves were upright) `elif entry is Dictionary: relics.append(_materialize(entry["p"], bool(entry.get("r", false))))`. MAX_HP price is NOT re-applied on load. Deck dicts additionally read `"w"` with `int(d.get("w", 0))` (§1.1) — old saves default to 0 wear.
- Boss reward becomes **1-of-2** at every boss: replace the auto-claim in `run.gd` (`RunState.claim_relic(RunState.region.boss_arcanum)`) with a choice screen `_show_boss_reward()`:
  - Two card panels side by side, centered, each ~300x460 within 1280x720; buttons bottom-anchored like all combat/run controls.
  - LEFT = upright: normal art, `describe()`, `BOSSREW_UPRIGHT` caption.
  - RIGHT = reversed: same art with `TextureRect.rotation = PI` (the visual brand: profaned RWS), frame tint `Color("b23a48")`, reversed effect text, price line in `Color("ff5a4d")` (`ARC_PRICE_MAXHP` / `ARC_PRICE_TAX` / `ARC_PRICE_CURSE`), `BOSSREW_REVERSED` caption. Price == NONE (devils): price line shows the deepened surcharge via `ARC_FX_PACT` — the choice is still real.
  - Confirm claims `claim_relic(boss_arcanum, chosen_reversed)`; then continue to the existing complete/next-region flow. The World (final boss) also offers the choice (matters for endless later; costs nothing now).
  - The run-opening draft and any pool grants stay upright-only.
- `describe()` for reversed instances: prefix the effect line with `tr("ARC_REVERSED_TAG")` ("(Reversed) ") and append the price sentence. Relic strips/lists render reversed relics with art rotated PI and the red tint everywhere they appear.

---

## 7. Pool additions + rarity tiers

### 7.1 New pool cards (append to `_pool()` in gen_content — 6 cards, pool 36 -> 42)

| # | rank | aspect | keyword | value | meaning | rarity |
|---|---|---|---|---|---|---|
| p_36 | 9 | CHAOS | PRZECIAZENIE | 3 | x2 Mult, durability 3 | RARE |
| p_37 | 14 | CHAOS | PRZECIAZENIE | 2 | x2 Mult, durability 2 (King: 10 chips) | LEGENDARY |
| p_38 | 7 | CHAOS | LAWINA | 0 | retrigger engine, pairs with starter 7s | RARE |
| p_39 | 11 | CHAOS | LAWINA | 0 | Page-rank retrigger | RARE |
| p_40 | 8 | MIND | KOMBINAT | 50 | +50%/streak xMult | RARE |
| p_41 | 13 | MIND | KOMBINAT | 75 | +75%/streak xMult (Queen) | LEGENDARY |

These keywords are draftable from run 1: do **NOT** add PRZECIAZENIE/LAWINA/KOMBINAT to `Profile.is_meta_locked_keyword` (the exponential vector is the base game, not meta bait).

### 7.2 Rarity model

`CardData` additions (new enum + export; default COMMON keeps all existing .tres valid without regen):
```gdscript
enum Rarity { COMMON, RARE, LEGENDARY }
@export var rarity: Rarity = Rarity.COMMON
```
`gen_content._make` specs gain a 5th element (rarity), defaulting to COMMON when absent.

Assignment over the 42-card pool — **LEGENDARY (5)**: `[14 MIND ECHO 10]`, `[14 NATURE BUJNOSC 40]`, `[13 DEATH PIJAWKA 20]`, `[14 CHAOS PRZECIAZENIE 2]`, `[13 MIND KOMBINAT 75]`. **RARE (14)**: `[13 MIND ECHO 8]`, `[13 NATURE BUJNOSC 35]`, `[13 DEATH ZNIWO 2]`, `[13 CHAOS FURIA 0]`, `[12 LIFE OSLONA 9]`, `[8 CHAOS SPALENIE 12]`, `[10 LIFE OPATRZNOSC 8]`, `[12 NATURE WZROST 3]`, `[7 DEATH PIJAWKA 15]`, `[10 DEATH KLATWA 10]`, `[9 CHAOS PRZECIAZENIE 3]`, `[7 CHAOS LAWINA 0]`, `[11 CHAOS LAWINA 0]`, `[8 MIND KOMBINAT 50]`. **COMMON (23)**: everything else. Starter cards: all COMMON.

### 7.3 Offer odds (reward drafts AND shop card slots — one table)

New `RunState.pick_tiered_offers(pool: Array, n: int) -> Array`, used by `run.gd` wherever card offers are rolled (`_show_reward`, `_show_shop`, reroll). Per slot, using `RunState.rng` (the sanctioned source):
```
r = rng.randf()
tier = LEGENDARY if r < 0.05 else (RARE if r < 0.30 else COMMON)   # 5% / 25% / 70%
pick uniformly (rng.randi_range) among pool cards of that tier not already in this offer set
fallback if the tier bucket is empty (profile filter / exhausted): LEGENDARY->RARE->COMMON
```
No duplicates within one 3-slot offer; duplicates across visits allowed (that is the Magnum Opus path). Enemy picks, Arcanum draft and Star picks keep plain `pick_offers`.

### 7.4 Frame colors (`card_widget.gd`)

- COMMON: existing frame, unchanged.
- RARE: 2px border `Color("8fb8d8")` (steel-silver).
- LEGENDARY: 2px border `Color("f2c14e")` (gold) + slow glow: border modulate alpha oscillates 0.7..1.0 on a 1.2 s sine (cosmetic; no gameplay reads it).
- Rarity has no text label on the face; shop/reward tooltips may append `RARITY_RARE`/`RARITY_LEGENDARY` under the keyword description.

---

## Locale appendix — append to `data/locale/ui.csv` (keys,en,pl; keep `%` parity per column)

```
KW_PRZECIAZENIE,Overload,Przeciążenie
KWD_PRZECIAZENIE,x2 Mult. Cracks each time it is played; shatters and is lost at 0 (counter on the card).,x2 Mult. Pęka przy każdym zagraniu; przy 0 rozpada się i znika (licznik na karcie).
KW_LAWINA,Avalanche,Lawina
KWD_LAWINA,Card chips score again once per Chaos card in the play (max 3).,Chipsy kart liczone ponownie za każdą kartę Chaosu w zagraniu (maks. 3).
KW_KOMBINAT,Combine,Kombinat
KWD_KOMBINAT,xMult grows for each consecutive play of the same hand type (caps at 4).,xMult rośnie za każde kolejne zagranie tego samego układu (maks. 4).
HAND_MAGNUM_OPUS,Magnum Opus,Magnum Opus
PREVIEW_SHATTER,A card will shatter!,Karta się rozpadnie!
PREVIEW_LETHAL,LETHAL,ŚMIERTELNE
PREVIEW_OVERKILL,+%d ☿ overkill,+%d ☿ za nadmiar
REWARD_OVERKILL,Overkill: +%d ☿,Nadmiar obrażeń: +%d ☿
REWARD_TAX,Reversed tax: -%d ☿,Danina odwróconych: -%d ☿
ARCANUM_MAGA,The Magician,Mag
ARC_FX_MAGNIFY,x%s Mult; other Arcana's xMult bonuses are doubled,x%s Mult; premie xMult innych Arkanów są podwojone
ARC_FX_MAGNIFY_REV,x%s Mult; other Arcana's xMult bonuses are tripled,x%s Mult; premie xMult innych Arkanów są potrojone
ARC_REVERSED_TAG,(Reversed) ,(Odwrócone) 
ARC_PRICE_MAXHP,Price: -%d max HP,Cena: -%d maks. HP
ARC_PRICE_TAX,Price: -%d ☿ after every fight,Cena: -%d ☿ po każdej walce
ARC_PRICE_CURSE,Price: enemy hits hurt +%d more,Cena: ciosy wroga bolą o +%d mocniej
BOSSREW_TITLE,Claim the Arcanum,Weź Arkanum
BOSSREW_UPRIGHT,Upright,Proste
BOSSREW_REVERSED,Reversed,Odwrócone
RARITY_RARE,Rare,Rzadka
RARITY_LEGENDARY,Legendary,Legendarna
```

## Implementation order (dependency-safe)

1. Enums + `CardData.wear` + `ArcanumData` fields (pure data, nothing reads them yet).
2. Poker: MAGNUM_OPUS. 3. Scoring pipeline §0 (+ controller `hand_history`, `destroyed_cards`, overkill). 4. RunState: `_materialize`, claim/save/load migration, `pick_tiered_offers`, `pending_overkill`. 5. gen_content: starter, pool +6, rarity, Magician, reversed numbers -> regen .tres. 6. run.gd: boss 1-of-2, reward lines, tiered offers. 7. card_widget/combat UI: durability pip, shatter/lethal preview lines, frames, reversed rendering, intent-label surcharges.

## CONFLICTS
- run.gd:278 auto-claims RunState.region.boss_arcanum with no choice, and _show_complete() (run.gd:534) reads region.boss_arcanum directly for display — both must switch to the boss-reward choice flow and to the CLAIMED instance (upright vs reversed), or the complete screen will show the wrong orientation.
- Preview-covenant gap ALREADY in the code: the intent label uses current_intent() (combat.gd shows COMBAT_INTENT 'Hits for %d') but CombatController.resolve_enemy_turn adds _pact_surcharge() on top — the displayed intent understates the hit whenever a PACT_MULT relic is worn. The new SELF_CURSE price uses the same channel, so the label MUST become current_intent() + _pact_surcharge() + _curse_surcharge().
- DeckLibrary.reward_pool filters cards through Profile.is_unlocked, and Profile.is_meta_locked_keyword hard-lists wave-2 keywords. The three new keywords must NOT be added to that list, otherwise the P2 cards silently never appear for fresh profiles. (Broader meta reversal is P6, out of scope here.)
- Resource.duplicate() drops resource_path, so once claim_relic materializes per-run relic instances, the existing save code (relic_paths.append(a.resource_path)) would write empty strings and lose relics on load — the new source_path field + dict save format in §6.4 is mandatory, not optional.
- Profile.starter_editions is keyed by starter INDEX (0..15). The starter rework keeps 16 entries and only substitutes indices 9 (Life 7->3) and 12 (Mind 7->5), so saved editions stay valid but land on slightly different cards — acceptable, no migration; do not reorder the starter list beyond the spec.
- Re-running tools/gen/gen_content.gd overwrites any hand-tweaked .tres under data/ (cards, arcana, regions). All P2 numbers are specced into the generator for exactly this reason — never hand-edit generated .tres before regen.
- RunState.active_relic() returns only relics[0]; scoring correctly receives the full array, but any UI built on active_relic() will hide the Magician/reversed stack — audit its callers when adding the relic strip rendering.
- CombatController is fed the same CardData instances that live in RunState.deck (RunState.add_card duplicates on ADD, not on fight start) — the shatter-erase in §1.1 relies on this identity; if combat ever starts duplicating the deck, destroyed_cards must be matched back by index instead.
