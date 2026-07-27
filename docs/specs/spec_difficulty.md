# P1 SPEC — Difficulty, Fail-Rate, Veils (Ascension), Turn-Planning Depth

Scope: exact numbers for the integrator. Files touched: `src/game/combat/combat_controller.gd`,
`src/game/combat/scoring.gd`, `src/game/combat/combat.gd` (HUD only), `src/game/region/run_state.gd`,
`src/game/region/run.gd`, `src/game/meta/profile.gd`, `src/game/menu/menu.gd`,
`tools/gen/gen_content.gd`, `data/locale/ui.csv`. Covenant holds: zero new RNG anywhere in this spec;
every rule below is computable from visible state, so sim-preview stays exact. No new `EnemyData.Rule`
enum values are added (append-only respected — new boss teeth reuse the existing rule ids).

---

## 1) Per-fight heal cap

**Value: 15 HP of healing per fight** (`CombatController.FIGHT_HEAL_CAP: int = 15`). Applies to ALL
in-combat healing from one shared budget: OPATRZNOSC keyword, Sun relic `HEAL_ON_PLAY`, and PIJAWKA
leech. Rest between fights (RunState.rest) is outside combat and NOT counted (it gets its own nerf in §2).

**Effective cap formula** (computed once in `start()`):

```
base_cap = 10 if veil >= 5 else 15                    # Veil V, see §4
effective_cap = ceili(base_cap / 2.0) if enemy.rule in {TOWER_IGNORES_BLOCK, WORLD_ALL} else base_cap
# -> 15 normal | 8 vs Tower/World | 10 at Veil V | 5 vs Tower/World at Veil V
```

**Budget accounting (deterministic, hp-independent so preview cannot lie):** budget consumed
`= min(raw_heal, budget_remaining)` — consumed BEFORE the clamp to `player_max_hp` (overhealing at
full HP still burns budget; this is intended, it taxes Sun spam).

**Controller state:** `var heal_used: int = 0` (reset in `start()`).

**Scoring change (preview honesty):** `_ctx()` gains key `"heal_budget"` = `effective_cap - heal_used`.
In `Scoring.score()`, after leech is added: `heal = mini(heal, int(ctx.get("heal_budget", 999999)))`
and also return `"heal_raw"` (pre-clamp value) so the HUD can show clipping. Default 999999 keeps old
tests/tools working. Order inside score(): OPATRZNOSC + relic heal first, leech added, THEN one final
clamp on the total.

**Apply in `play()`:** `var applied := int(result["heal"])` (already budget-clamped by scoring);
`heal_used += applied`; `player_hp = mini(player_max_hp, player_hp + applied)`.

**HUD (combat.gd, player row, next to HP — bottom-anchored zone, fits 1280x720):**
- Label text: `tr("COMBAT_HEAL_BUDGET") % [effective_cap - heal_used, effective_cap]`, font 14,
  color `Color(0.55, 0.85, 0.6)`; dims to `Color(0.5,0.5,0.55)` when remaining == 0.
- When a play's `heal_raw > heal`, emit message `LOG_HEAL_CAPPED` with `[heal, heal_raw]`.

**ui.csv rows (EN,PL):**
```
COMBAT_HEAL_BUDGET,Heal pool %d/%d,Zapas leczenia %d/%d
LOG_HEAL_CAPPED,Heal capped: +%d (of +%d),Limit leczenia: +%d (z +%d)
```

---

## 2) Between-fight and between-region healing

**REST node (after each non-boss fight):** `RunState.REST_HEAL: 12 -> 8`. New helper
`RunState.rest_amount() -> int: return 5 if veil >= 2 else 8`; `rest()` uses it. Existing
`REST_HEALED` locale key unchanged (parametric).

**Between regions — replace the full heal.** In `enter_region()` replace
`player_hp = player_max_hp` with:

```
var missing := player_max_hp - player_hp
var pct := 0.25 if veil >= 2 else 0.40
var healed := clampi(maxi(5, int(floor(missing * pct))), 0, missing)
player_hp += healed
```

`enter_region()` returns `healed` (int). `run.gd._continue_journey()` stores it in `_last_rest` so the
next map screen shows the existing `REST_HEALED` hint. Edge: at full HP, missing=0 → healed=0 (the
`maxi(5,...)` floor is clamped by `missing`).

---

## 3) Enemy pressure retune — intended fight length 5-6 plays, stalling loses

### 3a. Enrage: per-TURN after one authored cycle (the real clock)

Replace the per-cycle formula in `current_intent()`:

```
var n := enemy.intents.size()
var step := enemy.enrage_step + (1 if veil >= 3 else 0)     # Veil III, see §4
var over := maxi(0, _intent_index - n)                       # turns past the first full cycle
return enemy.intents[_intent_index % n] + over * step
```

First cycle (3 turns) is exactly as authored — readable opening. From enemy turn 4 onward EVERY turn
adds `+step`. With step 3 (Tower): turns 1-9 deal 15,20,13, 18,26,22, 27,35,31 — cumulative 114 by
turn 6. A 55-HP player with heal pool 8 (Tower halves it) cannot stall past ~6 turns. This is the
whole anti-stall mechanism for normal fights too; no new fields needed.

### 3b. Normal enemies — regenerate in `gen_content.gd` (HP ~x1.5, intents ~x1.25, enrage unchanged 2/3/4)

| Enemy | HP old→new | Intents old→new | enrage_step |
|---|---|---|---|
| ENEMY_KULTYSTA | 340→520 | [8,10,6]→[10,13,8] | 2 |
| ENEMY_WIEDZMA | 310→480 | [13,3,13]→[16,4,16] | 2 |
| ENEMY_CIEN | 400→600 | [9,12,7]→[12,15,9] | 2 |
| ENEMY_GOLEM | 450→660 | [16,0,12]→[20,0,15] | 3 |
| ENEMY_KAPLAN | 500→720 | [11,13,8]→[14,17,10] | 3 |
| ENEMY_UPIOR | 470→680 | [17,5,17]→[21,6,21] | 3 |
| ENEMY_RYCERZ | 580→840 | [13,13,13]→[16,16,16] | 3 |
| ENEMY_CHIMERA | 540→780 | [19,0,15]→[24,0,19] | 4 |
| ENEMY_STRAZNIK | 720→1040 | [16,18,12]→[20,23,15] | 4 |
| ENEMY_WIDMO | 690→990 | [22,8,22]→[27,10,27] | 4 |
| ENEMY_TYTAN | 800→1150 | [18,18,18]→[22,22,22] | 4 |
| ENEMY_HERALD | 760→1090 | [24,0,20]→[30,0,25] | 5 |

### 3c. Bosses — flatter HP, meaner RULES

HP ratio flattens from 1 : 1.32 : 1.83 : 3.19 to 1 : 1.30 : 1.63 : 2.17; the rules carry the scaling.

| Boss | HP old→new | Intents old→new | enrage_step old→new |
|---|---|---|---|
| Tower | 470→600 | [13,17,11]→[15,20,13] | 3→3 |
| Devil | 620→780 | [14,18,12]→[16,20,14] | 3→4 |
| Moon | 860→980 | [18,22,15]→[20,25,17] | 4→5 |
| World | 1500→1300 | [24,28,20]→[26,30,22] | 5→6 |

**New teeth per rule (controller logic; no enum changes):**

- **TOWER_IGNORES_BLOCK** — keeps block-ignore, ADDS: heal pool halved this fight
  (`effective_cap = ceili(base_cap/2.0)` → 8, or 5 at Veil V). "No shelter under the falling tower."
- **DEVIL_BLOOD_TAX** — tax scales with the fight clock. In `play()` replace the flat 2 with:
  `var tax := 2 + _intent_index / enemy.intents.size()` (integer division; turns 1-3 cost 2,
  4-6 cost 3, 7-9 cost 4...). Killing blow still wins first (existing order preserved).
  `LOG_PACT` stays parametric — emits the actual tax.
- **MOON_CLEANSE** — keeps rot-cleanse-after-one-tick, ADDS self-mend that punishes stalling:
  controller tracks `var _dmg_this_round: int = 0` (reset at end of each enemy turn; accumulates
  play `damage` + the gnicie tick applied at the start of the enemy turn). In
  `resolve_enemy_turn()`, AFTER the gnicie tick + cleanse and BEFORE the attack:
  `if _dmg_this_round < 60: enemy_hp = mini(enemy.max_hp_effective, enemy_hp + 15)` and emit
  `LOG_MOON_MEND [15]`. Constants: `MOON_MEND_HEAL = 15`, `MOON_MEND_THRESHOLD = 60`.
  Fully deterministic — the threshold is printed in the rule text.
- **WORLD_ALL** — inherits ALL of the above: block-ignore + halved heal pool + scaling blood tax +
  rot-cleanse + self-mend (same 60/15 constants) + enrage 6.

**ui.csv rule-text replacements (no format args — keep numbers in text; PL keeps diacritics):**
```
RULE_TOWER,"Tower: block does not protect, heal pool halved","Wieża: blok nie chroni, zapas leczenia o połowę mniejszy"
RULE_DEVIL,Devil: each play costs blood — 2 HP +1 per cycle,Diabeł: każde zagranie kosztuje krew — 2 HP +1 za cykl
RULE_MOON,"Moon: Rot washes away; deal under 60 a round and it mends 15","Księżyc: Gnicie się rozpływa; poniżej 60 obrażeń na rundę zasklepia 15"
RULE_WORLD,The World: every previous rule at once,Świat: wszystkie poprzednie reguły naraz
LOG_MOON_MEND,The Moon mends itself: +%d,Księżyc się zasklepia: +%d
```

Sanity math: R1 normals ~520 HP at ~110-140 dmg/play → 4-5 plays; bosses 600 at ~120-140 with
shop/star growth → 5-6 plays; enrage makes turn 8+ unsurvivable. The deliberately-weak bot must drop
to <=1/20 full-journey wins (verify with the M3 telemetry harness after implementing).

---

## 4) Veils ("Zaslony") — ascension tiers 1..5

**Stacking:** Veil N applies ALL modifiers 1..N. One modifier per tier:

| Tier | Name (EN / PL) | Modifier (exact) |
|---|---|---|
| 1 | Thin Thread / Cienka Nić | `START_MAX_HP` 55 → 48 |
| 2 | Hungry Road / Głodna Droga | rest heals 5 (not 8); between-region heal 25% of missing (not 40%) |
| 3 | Impatient Cards / Niecierpliwe Karty | every enemy's effective `enrage_step` +1 |
| 4 | Greedy Market / Chciwy Targ | shop BUY/THIN/ENCHANT/STAR cost +2 ☿ each (7/5/7/9); fight `reward_rtec` -1 (min 1); reroll unchanged |
| 5 | True Night / Prawdziwa Noc | boss `max_hp` x1.15 rounded to nearest 10 (`int(round(hp*1.15/10.0))*10` → Tower 690, Devil 900, Moon 1130, World 1500); `FIGHT_HEAL_CAP` 15 → 10 |

**Never mutate `.tres`:** all veil/boss modifiers are computed at `CombatController.start()`
(effective hp / enrage / cap) and in run.gd (prices/rewards). `start()` gains param `p_veil: int = 0`;
`combat.setup` passes `RunState.veil`.

**Storage — `profile.gd`:** `var veils_unlocked: int = 0` (highest selectable tier). Persist in
section `"meta"`, key `"veils_unlocked"` (save_profile/load_profile). Unlock rule, called by
`run.gd._show_complete()` final branch: `Profile.record_veil_win(RunState.veil)`:
`if veil >= veils_unlocked: veils_unlocked = mini(veil + 1, 5); save_profile(); changed.emit()`.
So the first veil-0 victory unlocks Veil 1; winning tier N unlocks N+1, cap 5.

**Selection on New Run — `menu.gd`:** `RunState` gains `var veil: int = 0`. `begin()` and
`_restart_run()` DO NOT reset it. `_new_run()`: if `Profile.veils_unlocked == 0` → set
`RunState.veil = 0`, start as today. Else show a picker overlay: one row of chips for tiers
0..5 — tiers `<= veils_unlocked` clickable (chip shows name + cumulative desc list), higher tiers
greyed with `VEIL_LOCKED % (tier-1)`; confirm button starts the run. Persist in run save:
`save_run` writes `cf.set_value("run","veil",veil)`; `load_run` reads it (default 0 — old saves fine).

**Run HUD:** when `veil > 0`, statusbar (run.gd shell) gets a chip after `_relics_label`:
`tr("VEIL_BADGE") % RunState.veil`, color `Color(0.72, 0.55, 0.9)`.

**ui.csv rows:**
```
VEIL_TITLE,Choose your Veil,Wybierz Zasłonę
VEIL_HINT,Each Veil adds its burden to all before it.,Każda Zasłona dokłada swój ciężar do poprzednich.
VEIL_0,No Veil — the plain road,Bez Zasłony — zwykła droga
VEIL_1,Veil I — Thin Thread,Zasłona I — Cienka Nić
VEIL_2,Veil II — Hungry Road,Zasłona II — Głodna Droga
VEIL_3,Veil III — Impatient Cards,Zasłona III — Niecierpliwe Karty
VEIL_4,Veil IV — Greedy Market,Zasłona IV — Chciwy Targ
VEIL_5,Veil V — True Night,Zasłona V — Prawdziwa Noc
VEIL_1_DESC,Max HP 55 -> 48,Maks. HP 55 -> 48
VEIL_2_DESC,"Rest heals 5, the road restores 25% of missing HP","Odpoczynek leczy 5, droga zwraca 25% brakującego HP"
VEIL_3_DESC,Enemies enrage faster (+1 per turn past the first cycle),Wrogowie szaleją szybciej (+1 na turę po pierwszym cyklu)
VEIL_4_DESC,"Shop prices +2, fight rewards -1","Ceny w sklepie +2, nagrody za walki -1"
VEIL_5_DESC,"Boss HP +15%, heal pool 10","HP bossów +15%, zapas leczenia 10"
VEIL_LOCKED,Win at Veil %d to unlock,Wygraj na Zasłonie %d aby odblokować
VEIL_START,Begin the Journey,Rozpocznij Podróż
VEIL_BADGE,Veil %d,Zasłona %d
```

---

## 5) Target winrates (tuning acceptance criteria)

- **First run (new player, Veil 0): 10-20%** (aim ~15% — death teaches, first win in ~4-7 runs).
- **Veteran, Veil 0: 60-70%.**
- **Veteran, Veil 5: 15-25%.**
- Proxy check without humans: the deliberately-weak bot wins **<= 1/20** journeys at Veil 0 and
  **0/20** at Veil 3+; a discard-fishing bot tuned to play well should reach ~50-60% at Veil 0.

---

## 6) Next-intent preview (turn-planning depth)

Controller (already deterministic — pure lookahead, no state change):

```
func next_intent() -> int:
    if enemy == null or enemy.intents.is_empty():
        return 0
    var n := enemy.intents.size()
    var step := enemy.enrage_step + (1 if veil >= 3 else 0)
    var idx := _intent_index + 1
    var over := maxi(0, idx - n)
    return enemy.intents[idx % n] + over * step
```

**HUD (combat.gd enemy row, top of screen):** directly under the existing `_intent_label`
(`COMBAT_INTENT`), add `_next_intent_label`: text `tr("COMBAT_INTENT_NEXT") % controller.next_intent()`,
font 14, color `Color(0.8, 0.5, 0.45)` (dimmer than the 20px current-intent label). Refresh alongside
`_intent_label` in the same state update. Always visible during `phase == "player"` and `"enemy"`.

Data shown: the exact damage of the FOLLOWING enemy turn, enrage included. This is the payoff loop:
Golem/Chimera/Herald show `Next: 0` → the player learns to tank now and go all-out into the rest
turn, or hold FURIA (no-block) plays for turns where next is low. No other future info is shown
(one-step lookahead keeps the decision sharp, and deeper telegraphing is P2+ territory).

**ui.csv row:**
```
COMBAT_INTENT_NEXT,Next: %d,Potem: %d
```

---

## 7) Defeat must pay — Sol formula

Replace `Profile.earn_run_reward` body; signature becomes
`earn_run_reward(victory: bool, fights_won: int, veil: int) -> int` (run.gd passes `RunState.veil`
at both call sites — complete screen and defeat screen):

```
var amount := (35 + 3 * fights_won + 5 * veil) if victory \
         else (5 + 3 * fights_won + 2 * veil)
```

Resulting values (full journey = 10 fights): victory Veil 0 = **65** (was 50), Veil 5 = 90.
Defeat on the very first fight = **5** (was 0 — every run now feeds the meta); defeat at the World
= 32-42. Two to three failed runs fund one 25-Sol unlock, so losing still progresses the Collection —
"zginalem na bossie" now pays for the next attempt. `META_EARNED` locale key already parametric;
no text change.

---

## Implementation order (one PR each)

1. §3a enrage formula + §6 next-intent (controller + HUD) — smallest, biggest feel change.
2. §1 heal cap (controller + scoring ctx + HUD) and §2 heal nerfs (run_state + run.gd).
3. §3b/3c stat retune + boss teeth (gen_content regen + controller rules + ui.csv rule texts).
4. §4 Veils (profile + menu picker + run_state.veil + save key) and §7 Sol formula.
5. Re-run bot telemetry x20; adjust ONLY normal-enemy HP (±10%) to hit §5 targets — keep boss
   rules and enrage as specced.


## CONFLICTS
- CombatController.PLAYER_MAX_HP = 50 conflicts with RunState.START_MAX_HP = 55; the constant is dead in the run flow (start_hp/max_hp are always passed) but standalone combat restarts would use 50 — set it to 55 or delete it when adding Veil I.
- Existing tests (14+5 green per PLAYTEST_FEEDBACK) assert the old per-cycle enrage in current_intent(); the per-turn-after-grace formula in section 3a changes returned values from enemy turn 4 onward — tests must be updated in the same commit.
- gen_content.gd comment block (lines ~104-110) documents 'fights ~2-3 turns, boss ~4-5' — outdated after the section 3 retune; update the comment when regenerating .tres.
- Profile.earn_run_reward signature gains a veil param — both call sites in run.gd (_show_complete ~line 550, _show_defeat ~line 592) must be updated together or the run-end screens crash.
- ANALIZA P2 (starter without a ready Five-of-a-Kind, one compounding mult vector) will shift the player damage curve that section 3's HP numbers are tuned against — re-run the x20 bot telemetry after P2 lands and re-tune ONLY normal-enemy HP.
- RULE_TOWER/RULE_DEVIL/RULE_MOON/RULE_WORLD rows in data/locale/ui.csv (lines 325-328) are replaced, not appended — mind the CSV comma-quoting trap and %-parity between EN and PL columns (both new RULE texts contain no format specifiers by design).
- Scoring.score gains ctx key 'heal_budget' with default 999999 — any tool/test calling score() without the new key keeps old behavior; combat.gd must rely on controller.preview() (which uses _ctx()) rather than calling Scoring directly, otherwise its preview would ignore the cap and lie.
- run.gd _restart_run() reuses the current RunState.veil — intended (retry same veil), but note the only way to change veil is via the main-menu picker; the defeat/victory screens' 'New Run' buttons do not offer veil selection.
