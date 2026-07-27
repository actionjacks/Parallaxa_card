# SPEC P5+P6+P7 — Run-end Tarot Spread, Seed/Replay, Meta Inversion, Achievements, Title

Scope: `RunState`, `CombatController`, `combat.gd`, `run.gd`, `profile.gd`, `deck_library.gd`, `menu.gd`, `omen_data.gd`, `project.godot`, `data/` content, `data/locale/ui.csv`. Combat math is untouched; the only RNG remains `RunState.rng` (now seeded). All numbers below are final.

---

## 1. RunState — run statistics and seed

### 1.1 New fields (append to `src/game/region/run_state.gd`)

```gdscript
## Menu -> run handoff: the Veil tier chosen for the NEXT run (run.gd calls begin() itself).
static var next_veil: int = 0

var run_seed: int = 0            ## 32-bit seed of this run; 0 = not yet assigned
var veil: int = 0                ## difficulty tier of this run (P1 consumes it; stored here)

# --- run statistics (all reset in begin(); all saved in save_run) ---
var stat_damage_total: int = 0        ## sum of all scored play damage
var stat_best_hit: int = 0            ## single biggest play damage
var stat_best_hit_foe: String = ""    ## EnemyData.name_key of that play's victim
var stat_best_hit_hand: int = 0       ## Poker.Hand of that play
var stat_best_hand: int = 0           ## highest Poker.Hand ordinal played this run
var stat_turns_total: int = 0         ## sum of combat turns across fights
var stat_regions_cleared: int = 0     ## bosses beaten this run (0..4)
var stat_untouched_fights: int = 0    ## fights WON with zero damage taken (incl. blood tax)
var stat_death_flush_kill: bool = false  ## killing blow was a 5-card mono-Death FLUSH/STRAIGHT_FLUSH/FIVE
var stat_max_rtec: int = 0            ## highest Mercury ever held this run
var stat_sol_earned: int = 0          ## set exactly once by the spread screen
```

`rtec` becomes a property so `stat_max_rtec` can never be missed (external code does `RunState.rtec += x`):

```gdscript
var rtec: int = 0:
	set(v):
		rtec = v
		stat_max_rtec = maxi(stat_max_rtec, v)
```
(Assigning inside the setter writes the backing field directly in Godot 4 — no recursion.)

### 1.2 Seeding (`begin`)

New signature — additive, existing call sites unchanged:

```gdscript
func begin(p_region: RegionData, p_seed: int = 0) -> void:
	if p_seed != 0:
		run_seed = p_seed & 0xFFFFFFFF
	else:
		rng.randomize()
		run_seed = int(rng.randi())
	if run_seed == 0:
		run_seed = 1          # 0 is the "unassigned" sentinel
	rng.seed = run_seed       # deterministic sequence from here on
	veil = next_veil
	# ... existing body (region reset, deck, shuffle, fights roll) ...
	# reset ALL stat_* fields to the defaults listed above
```

`next_veil` is NOT reset in `begin()` (so `_restart_run` keeps the tier); the menu sets it before every scene change.

Determinism contract: same seed + same player choices = same run (Balatro-style). Any NEW consumer of `RunState.rng` must be appended AFTER existing call sites in flow order, never inserted before — otherwise "Repeat this fate" diverges. Document this comment above `rng`.

### 1.3 Seed display format

```gdscript
static func seed_text(s: int) -> String:
	var h := "%08X" % (s & 0xFFFFFFFF)
	return h.substr(0, 4) + "-" + h.substr(4, 4)   # e.g. "A3F2-09BC"
```

### 1.4 Fight result intake

New method, called by `combat.gd` (see 2.2):

```gdscript
func record_fight(won: bool, foe_key: String, c: CombatController) -> void:
	stat_damage_total += c.fight_damage
	stat_turns_total += c.turn
	stat_best_hand = maxi(stat_best_hand, c.fight_best_hand)
	if c.fight_best_hit > stat_best_hit:
		stat_best_hit = c.fight_best_hit
		stat_best_hit_hand = c.fight_best_hit_hand
		stat_best_hit_foe = foe_key
	if won:
		if c.damage_taken == 0:
			stat_untouched_fights += 1
		if c.kill_mono_death_flush:
			stat_death_flush_kill = true
```

### 1.5 Save/load compat (`save_run` / `load_run`)

Append to `save_run` (section `"run"`, append-only keys):

```
seed = run_seed          rng_state = rng.state      veil = veil
st_dmg, st_hit, st_hit_foe, st_hit_hand, st_hand, st_turns, st_regions,
st_untouched, st_flush (bool), st_maxrtec
```

In `load_run` REPLACE the current `rng.randomize()` with:

```gdscript
run_seed = cf.get_value("run", "seed", 0)
if run_seed == 0:                # old save: no seed recorded
	rng.randomize()
	run_seed = int(rng.randi())
	if run_seed == 0: run_seed = 1
	rng.seed = run_seed
else:
	rng.seed = run_seed
	rng.state = cf.get_value("run", "rng_state", rng.state)
veil = cf.get_value("run", "veil", 0)
# each stat_* loaded with its default (0 / "" / false)
```

Old saves load cleanly (all `get_value` defaults). New saves loaded by old builds ignore extra keys — no version bump needed.

---

## 2. CombatController — fight-local stats

### 2.1 New fields (reset in `start()`)

```gdscript
var damage_taken: int = 0        ## HP lost to enemy hits + blood tax this fight
var fight_damage: int = 0        ## sum of play damage this fight
var fight_best_hit: int = 0
var fight_best_hit_hand: int = 0
var fight_best_hand: int = 0     ## highest Poker.Hand ordinal played this fight
var kill_mono_death_flush: bool = false
```

### 2.2 Increments (exact locations)

- `play()` — right after `enemy_hp -= int(result["damage"])`:
  ```gdscript
  var dmg := int(result["damage"])
  fight_damage += dmg
  fight_best_hand = maxi(fight_best_hand, int(result["hand"]))
  if dmg > fight_best_hit:
      fight_best_hit = dmg
      fight_best_hit_hand = int(result["hand"])
  if enemy_hp <= 0:
      var cards := _cards_from(selected)
      var mono_death := cards.size() == 5
      for c in cards:
          if c.aspect != Aspects.Id.DEATH:
              mono_death = false
      kill_mono_death_flush = mono_death and int(result["hand"]) in \
          [Poker.Hand.FLUSH, Poker.Hand.STRAIGHT_FLUSH, Poker.Hand.FIVE]
  ```
  (Compute BEFORE `_move_to_used`, which is already the case at that point.)
- `play()` blood-tax branch (`player_hp -= 2`): `damage_taken += 2`.
- `resolve_enemy_turn()` after `player_hp -= taken`: `damage_taken += taken`.

### 2.3 combat.gd hookup

In `_on_ended(won)`, immediately before `finished.emit(...)` (inside the `if not standalone:` branch):

```gdscript
RunState.record_fight(won, _enemy.name_key, controller)
```

Standalone `combat.tscn` runs record nothing. The `finished` signal signature is UNCHANGED.

### 2.4 run.gd increments

- `_on_combat_finished`, boss branch (`step >= fights.size()`): add `RunState.stat_regions_cleared += 1` before the claim flow.

---

## 3. Run-end TAROT SPREAD screen (P5)

One screen for BOTH outcomes. New file `src/game/region/spread_screen.gd` (`class_name SpreadScreen extends Control`), built in code on the project theme, mounted by run.gd via `_mount()`. Public API: `static func build(victory: bool, fresh_achievements: Array) -> SpreadScreen` + signals `new_run`, `repeat_run`, `to_menu`.

### 3.1 Flow changes in run.gd

- `_show_defeat()` → body replaced by `_show_spread(false)`.
- `_show_complete()` final branch (`region_index + 1 >= JOURNEY.size()`) → `_show_spread(true)`; the non-final "REGION CLEARED" screen stays as is (minus 3.4's claim change).
- `_show_spread(victory)`:
  ```gdscript
  _statusbar.visible = false
  RunState.delete_run_save()
  RunState.stat_sol_earned = Profile.earn_run_reward(victory, RunState.fights_won)
  if victory:
      Profile.record_victory(RunState.veil)
  var fresh: Array = Profile.check_run_achievements(victory)
  var s := SpreadScreen.build(victory, fresh)
  s.new_run.connect(_restart_run)
  s.repeat_run.connect(_repeat_fate)
  s.to_menu.connect(func(): get_tree().change_scene_to_file("res://src/game/menu/menu.tscn"))
  _mount(s)
  Sfx.play(&"win" if victory else &"lose", -2.0)
  ```
  Remove the `Profile.earn_run_reward` + `Sfx` + relic-row code from the old final/defeat paths — `earn_run_reward` must run EXACTLY once per run end.
- `_repeat_fate()`:
  ```gdscript
  _pending_omen = null
  RunState.next_veil = RunState.veil
  var s := RunState.run_seed
  RunState.begin(load(JOURNEY[0]), s)
  _start_run_flow()
  ```
- `_restart_run()` gains one line before `begin`: `RunState.next_veil = RunState.veil` (fresh seed, same tier).

### 3.2 Layout — 1280x720, absolute positions inside a full-rect Control

| Element | Pos / size | Details |
|---|---|---|
| Title | full-width label, `offset_top 18`, font 42, centered | victory: `tr("SPREAD_WIN")`, `Color(0.95,0.85,0.5)`; defeat: `tr("SPREAD_LOSS")`, `Color(0.9,0.4,0.4)` |
| Subtitle | full-width, `offset_top 68`, font 15, centered, `Color(0.6,0.6,0.68)` | `tr(RunState.region.name_key)` + (` " · " + tr("NEWRUN_VEIL_LEVEL") % RunState.veil` when `veil > 0`) |
| Arcana label | pos `(90,104)`, font 16, `Color(0.75,0.65,0.9)` | `tr("SPREAD_ARCANA")` |
| Arcana fan | card i at `position (90 + i*92, 138)`, size `124x215`, `rotation_degrees = -6.0 + i*3.0`, `pivot_offset (62,215)` | one `TextureRect` per `RunState.relics` entry (`a.art`, EXPAND_IGNORE_SIZE / KEEP_ASPECT_CENTERED / LINEAR), tooltip `tr(a.name_key) + "\n" + a.describe()`. Display cap 6 (step drops to 80 when `relics.size() > 5`). Empty relics: single `00_fool.jpg` at slot 0, `modulate Color(1,1,1,0.4)` |
| Biggest-hit card | pos `(668,126)`, size `200x340`, `rotation_degrees 3.0`, `pivot_offset (100,170)` | PanelContainer: bg `Color(0.1,0.08,0.12,0.98)`, border 3px `Color(0.9,0.5,0.3)`, corner radius 6, content margins 14. VBox sep 6, centered: `tr("SPREAD_HIT_TITLE")` font 14 `Color(0.7,0.7,0.78)`; `str(stat_best_hit)` font 68 `Color(0.98,0.8,0.35)`; `tr(Poker.name_key(stat_best_hit_hand))` font 16 `Color(0.95,0.9,0.8)`; `tr("SPREAD_HIT_FOE") % tr(stat_best_hit_foe)` font 14 `Color(0.85,0.6,0.55)`, autowrap. Hidden entirely when `stat_best_hit == 0` |
| Stats panel | pos `(912,126)`, size `340x340` | PanelContainer bg `Color(0.08,0.08,0.12,0.9)`, border 1px `Color(0.3,0.3,0.4)`, VBox sep 8, font 15, `Color(0.78,0.78,0.85)`. Lines in order: `SPREAD_BEST_HAND % [tr(Poker.name_key(stat_best_hand)), int(hand_levels.get(stat_best_hand,0)) + 1]`; `SPREAD_REGIONS % [stat_regions_cleared, 4]`; `SPREAD_FIGHTS % fights_won`; `SPREAD_DAMAGE % stat_damage_total`; `SPREAD_TURNS % stat_turns_total`; `SPREAD_SALT % stat_sol_earned`. Then one line per fresh achievement id: `tr("ACH_UNLOCKED") % tr(id)` font 14 `Color(0.95,0.85,0.5)` (id doubles as its locale key, see §6) |
| Seed button | CenterContainer full-width at `offset_top 540`, height 40 | flat Button, font 16: `"✦ " + tr("SPREAD_SEED") % RunState.seed_text(RunState.run_seed) + "  ·  " + tr("SPREAD_SEED_HINT")`. Pressed: `DisplayServer.clipboard_set(RunState.seed_text(RunState.run_seed))`, text → `tr("SPREAD_SEED_COPIED")`, revert after 1.2 s (`get_tree().create_timer`) |
| Buttons | HBox, `anchor_top = anchor_bottom = 1.0`, `offset_top -64`, `offset_bottom -20`, full width, alignment CENTER, sep 16 | each `custom_minimum_size (190,40)`: `SPREAD_NEW` → `new_run`; `SPREAD_REPEAT` → `repeat_run`; `SPREAD_MENU` → `to_menu`. Bottom-anchored: can never be pushed off 720p |

Entry animation (screenshot lands after it): each arcana card and the hit card start `modulate.a = 0`, `position.y += 20`; tween both back over 0.25 s with stagger `i * 0.06` s, TRANS_QUAD/EASE_OUT.

---

## 4. Meta inversion (P6)

### 4.1 Base pool fully unlocked

- `deck_library.gd`: `reward_pool()` returns `_cards(REWARD_POOL_PATH)` unfiltered (delete the Profile filtering). `full_reward_pool()` stays.
- `profile.gd`: DELETE `UNLOCK_COST`, `is_meta_locked_keyword`, `is_unlocked`, `unlock`, and the `unlocked` field. Keep `card_key` (menu dedupe uses it).
- `menu.gd`: delete the entire locked-cards block (`COLLECTION_LOCKED` section, `_unlock_card`). Orphaned csv keys stay in ui.csv (harmless; csv is append-friendly).

### 4.2 Profile v2 — fields, constants, migration

```gdscript
const VERSION := 2
const MAX_VEIL := 5
const DECK_COST := 60
const ARCANA_COST := 40
const EDITION_COST := { CardData.Edition.FOIL: 40, CardData.Edition.HOLO: 80, CardData.Edition.POLYCHROME: 120 }
const EDITION_VEIL_GATE := { CardData.Edition.FOIL: 1, CardData.Edition.HOLO: 3, CardData.Edition.POLYCHROME: 5 }
const SHOP_DECKS := { "reaper": "res://data/decks/starter_reaper.tres",
                      "gardener": "res://data/decks/starter_gardener.tres" }
const ACH_DECKS := { "oracle": "res://data/decks/starter_oracle.tres" }     # ACH_JOURNEY
const SHOP_ARCANA := { "magician": "res://data/arcana/arcanum_magician.tres",
                       "emperor": "res://data/arcana/arcanum_emperor.tres" }
const ACH_ARCANA := { "strength": "res://data/arcana/arcanum_strength.tres",   # ACH_UNTOUCHED
                      "hermit": "res://data/arcana/arcanum_hermit.tres" }      # ACH_OVERKILL

var sol: int = 0
var wins: int = 0
var best_veil: int = -1            ## highest Veil beaten; -1 = never won
var achievements: Array = []       ## String ids, append-only
var owned_decks: Array = []        ## keys of SHOP_DECKS bought with Sol
var selected_deck: String = "classic"
var owned_arcana: Array = []       ## keys of SHOP_ARCANA bought with Sol
var starter_editions: Dictionary = {}   ## "deckid:index" (String) -> CardData.Edition
```

API:

```gdscript
func record_victory(p_veil: int) -> void:            # wins += 1; best_veil = maxi(best_veil, p_veil); save; changed
func veil_selectable_max() -> int:                   # mini(best_veil + 1, MAX_VEIL); 0 when best_veil < 0
func buy_deck(id: String) -> bool                    # sol >= DECK_COST, not owned -> pay, append, save
func buy_arcana(id: String) -> bool                  # sol >= ARCANA_COST, not owned -> pay, append, save
func has_achievement(id: String) -> bool
func grant_achievement(id: String) -> bool           # false if already granted; append, save, changed
func available_decks() -> Array                      # ["classic"] + owned_decks + ACH_DECKS keys whose ach granted
func edition_allowed(ed: int) -> bool                # best_veil >= EDITION_VEIL_GATE[ed]
func boss_pool_arcana() -> Array                     # loaded ArcanumData for each owned_arcana id
func draft_extra_arcana() -> Array                   # loaded ArcanumData for ACH_ARCANA ids whose ach granted
func next_starter_edition(deck_id: String, index: int) -> int   # reads starter_editions["%s:%d"]
func upgrade_starter(deck_id: String, index: int) -> bool       # + edition_allowed(nxt) gate
```

`save_profile` writes `version, sol, wins, best_veil, achievements, owned_decks, selected_deck, owned_arcana, starter_editions`.

Migration in `load_profile` — day-1 full pool with full refund:

```gdscript
var v: int = cf.get_value("meta", "version", 1)
if v < 2:
	var old_unlocked: Array = cf.get_value("meta", "unlocked", [])
	sol = cf.get_value("meta", "sol", 0) + 25 * old_unlocked.size()
	var old_eds: Dictionary = cf.get_value("meta", "starter_editions", {})
	for k in old_eds:                       # cumulative ladder refund
		match int(old_eds[k]):
			CardData.Edition.FOIL: sol += 40
			CardData.Edition.HOLO: sol += 120
			CardData.Edition.POLYCHROME: sol += 240
	starter_editions = {}                   # editions now Veil-gated, re-buyable
	save_profile()                          # writes version 2; old keys simply unread
	return
```

### 4.3 Sol sinks (all WIDEN, nothing locks the base game)

| Sink | Cost | Effect |
|---|---|---|
| Starter deck "Reaper's Deal" (`reaper`) | 60 Sol | selectable in New Run |
| Starter deck "Gardener's Path" (`gardener`) | 60 Sol | selectable in New Run |
| Arcanum of the Magician (`magician`) | 40 Sol | joins the boss 1-of-2 offer pool |
| Arcanum of the Emperor (`emperor`) | 40 Sol | joins the boss 1-of-2 offer pool |
| Starter editions (per card, per deck) | 40/80/120 Sol | UNCHANGED costs, now gated: Foil needs `best_veil >= 1`, Holo `>= 3`, Polychrome `>= 5` — power arrives only alongside the difficulty that absorbs it |

### 4.4 Boss claim becomes 1-of-2 (when the player widened the pool)

In `_on_combat_finished` boss branch, REPLACE `RunState.claim_relic(RunState.region.boss_arcanum); _show_complete()` with:

```gdscript
RunState.stat_regions_cleared += 1
var owned_keys: Array = []
for r in RunState.relics: owned_keys.append(r.name_key)
var alts: Array = Profile.boss_pool_arcana().filter(func(a): return not owned_keys.has(a.name_key))
if alts.is_empty():
	RunState.claim_relic(RunState.region.boss_arcanum)
	_show_complete(RunState.region.boss_arcanum)
else:
	var alt: ArcanumData = RunState.pick_offers(alts, 1)[0]
	_show_boss_choice(RunState.region.boss_arcanum, alt)
```

`_show_boss_choice(a, b)`: `_screen_column()` with `_title(tr("CLAIM_TITLE"))`, HBox sep 40 centered containing `_arcanum_offer_panel(a)` and `_arcanum_offer_panel(b)` (reuse the draft panel + `_on_arc_input`-style selection), `CLAIM_TAKE` button (200x40, disabled until pick). On take: `RunState.claim_relic(chosen); _show_complete(chosen)`.

`_show_complete` gains a parameter `func _show_complete(claimed: ArcanumData = null)`; `var relic := claimed if claimed != null else RunState.region.boss_arcanum` replaces the current local. Final region: after the claim resolves, `_show_complete` routes to `_show_spread(true)` (§3.1).

### 4.5 Alternate starter decks (16 cards each, sidegrades — max 3 copies of any rank, no free Five-of-a-Kind)

Enum names below map to ints: Aspect LIFE=0 MIND=1 DEATH=2 CHAOS=3 NATURE=4; Keyword OSLONA=1 OPATRZNOSC=2 GNICIE=3 ZNIWO=4 FURIA=5 SPALENIE=6 ECHO=7 BUJNOSC=8 WZROST=9 SYMBIOZA=10 PIJAWKA=11 KLATWA=12.

**`data/decks/starter_reaper.tres`** (`name_key = "DECK_REAPER"`), cards `data/cards/r_00..r_15.tres` as (rank, aspect, keyword, keyword_value):

```
r_00 (4,  DEATH, GNICIE, 3)    r_08 (8,  CHAOS, SPALENIE, 8)
r_01 (4,  DEATH, ZNIWO, 1)     r_09 (10, CHAOS, FURIA, 0)
r_02 (6,  DEATH, GNICIE, 4)    r_10 (12, CHAOS, SPALENIE, 10)
r_03 (8,  DEATH, ZNIWO, 2)     r_11 (3,  CHAOS, SPALENIE, 6)
r_04 (8,  DEATH, PIJAWKA, 15)  r_12 (5,  MIND, ECHO, 4)
r_05 (10, DEATH, KLATWA, 10)   r_13 (9,  MIND, ECHO, 6)
r_06 (13, DEATH, GNICIE, 5)    r_14 (5,  LIFE, OPATRZNOSC, 4)
r_07 (6,  CHAOS, FURIA, 0)     r_15 (11, LIFE, OSLONA, 6)
```

**`data/decks/starter_gardener.tres`** (`name_key = "DECK_GARDENER"`), cards `g_00..g_15`:

```
g_00 (3,  NATURE, WZROST, 2)    g_08 (7,  LIFE, OSLONA, 7)
g_01 (5,  NATURE, WZROST, 3)    g_09 (9,  LIFE, OPATRZNOSC, 6)
g_02 (7,  NATURE, SYMBIOZA, 4)  g_10 (14, LIFE, OSLONA, 9)
g_03 (9,  NATURE, SYMBIOZA, 5)  g_11 (7,  MIND, ECHO, 5)
g_04 (9,  NATURE, BUJNOSC, 25)  g_12 (12, MIND, ECHO, 7)
g_05 (13, NATURE, WZROST, 4)    g_13 (5,  DEATH, GNICIE, 3)
g_06 (2,  LIFE, OSLONA, 5)      g_14 (8,  CHAOS, SPALENIE, 7)
g_07 (5,  LIFE, OPATRZNOSC, 4)  g_15 (11, CHAOS, FURIA, 0)
```

**`data/decks/starter_oracle.tres`** (`name_key = "DECK_ORACLE"`, achievement unlock), cards `o_00..o_15`:

```
o_00 (2,  MIND, ECHO, 3)      o_08 (12, CHAOS, SPALENIE, 9)
o_01 (5,  MIND, ECHO, 4)      o_09 (14, CHAOS, FURIA, 0)
o_02 (8,  MIND, ECHO, 6)      o_10 (4,  DEATH, KLATWA, 8)
o_03 (11, MIND, ECHO, 7)      o_11 (9,  DEATH, PIJAWKA, 12)
o_04 (13, MIND, ECHO, 8)      o_12 (6,  LIFE, OSLONA, 5)
o_05 (3,  CHAOS, SPALENIE, 5) o_13 (10, LIFE, OPATRZNOSC, 5)
o_06 (6,  CHAOS, SPALENIE, 7) o_14 (4,  NATURE, WZROST, 2)
o_07 (9,  CHAOS, FURIA, 0)    o_15 (10, NATURE, SYMBIOZA, 4)
```

`deck_library.gd`:

```gdscript
const STARTERS := { "classic": "res://data/decks/starter.tres",
	"reaper": "res://data/decks/starter_reaper.tres",
	"gardener": "res://data/decks/starter_gardener.tres",
	"oracle": "res://data/decks/starter_oracle.tres" }

static func starter_deck() -> Array:
	var prof := _profile()
	var id: String = "classic"
	if prof != null and prof.available_decks().has(prof.selected_deck):
		id = prof.selected_deck
	var cards := _cards(STARTERS[id])
	if prof != null:
		for i in cards.size():
			var ed: int = prof.starter_editions.get("%s:%d" % [id, i], CardData.Edition.NONE)
			if ed != CardData.Edition.NONE:
				cards[i].edition = ed as CardData.Edition
	return cards
```

### 4.6 New Arcana (existing `ArcanumData.Effect` values only — zero combat code)

| File | name_key | effect | values | art | source |
|---|---|---|---|---|---|
| `data/arcana/arcanum_magician.tres` | `ARCANUM_MAGA` | `EXTRA_DISCARD` | `effect_value 2` | `01_magician.jpg` | Sol 40 → boss pool |
| `data/arcana/arcanum_emperor.tres` | `ARCANUM_CESARZA` | `BLOCK_ON_PLAY` | `effect_value 6`, `effect_aspect LIFE` | `04_emperor.jpg` | Sol 40 → boss pool |
| `data/arcana/arcanum_strength.tres` | `ARCANUM_SILY` | `MULT_IF_ASPECT` | `effect_aspect LIFE`, `effect_mult 1.5` | `08_strength.jpg` | ACH_UNTOUCHED → opening draft pool |
| `data/arcana/arcanum_hermit.tres` | `ARCANUM_PUSTELNIKA` | `EXTRA_DISCARD` | `effect_value 3`, `effect_aspect MIND` | `09_hermit.jpg` | ACH_OVERKILL → opening draft pool |

Opening draft widening — `run.gd _show_arcanum_draft()`:

```gdscript
var pool: Array = RunState.region.starting_pool.duplicate()
pool.append_array(Profile.draft_extra_arcana())
_arc_offers = RunState.pick_offers(pool, 3)
```

---

## 5. Achievements (5) — all computable from run stats

`omen_data.gd` gains one appended export (additive, .tres compat): `@export var requires_achievement: String = ""`. `run.gd _load_omens()` skips an omen when `o.requires_achievement != "" and not Profile.has_achievement(o.requires_achievement)`.

| id (= locale key) | Trigger (exact) | Unlock (WIDENS) |
|---|---|---|
| `ACH_DEATH_FLUSH` | `RunState.stat_death_flush_kill == true` | omen `data/omens/omen_lovers.tres` (`id "lovers"`, `requires_achievement "ACH_DEATH_FLUSH"`, art `06_lovers.jpg`): accept → `_open_deck_picker(tr("PICK_ENCHANT")-style "pick a card")` → `RunState.add_card(picked)` (duplicate a deck card) |
| `ACH_UNTOUCHED` | `RunState.stat_untouched_fights >= 1` | `arcanum_strength.tres` joins opening draft pool |
| `ACH_OVERKILL` | `RunState.stat_best_hit >= 300` | `arcanum_hermit.tres` joins opening draft pool |
| `ACH_MISER` | `RunState.stat_max_rtec >= 25` (interest cap held) | omen `data/omens/omen_sun.tres` (`id "sun"`, `requires_achievement "ACH_MISER"`, art `19_sun.jpg`): accept → `player_hp = mini(max_hp, player_hp + 12)` |
| `ACH_JOURNEY` | `victory == true` (evaluated only at run end) | starter deck `starter_oracle.tres` becomes selectable |

`profile.gd`:

```gdscript
func check_run_achievements(victory: bool) -> Array:
	var fresh: Array = []
	if RunState.stat_death_flush_kill and grant_achievement("ACH_DEATH_FLUSH"): fresh.append("ACH_DEATH_FLUSH")
	if RunState.stat_untouched_fights >= 1 and grant_achievement("ACH_UNTOUCHED"): fresh.append("ACH_UNTOUCHED")
	if RunState.stat_best_hit >= 300 and grant_achievement("ACH_OVERKILL"): fresh.append("ACH_OVERKILL")
	if RunState.stat_max_rtec >= 25 and grant_achievement("ACH_MISER"): fresh.append("ACH_MISER")
	if victory and grant_achievement("ACH_JOURNEY"): fresh.append("ACH_JOURNEY")
	return fresh
```

Called from: end of `_show_map()` with `false` (mid-run pop; new omens/arcana apply from the next roll), and from `_show_spread` with `victory` (§3.1). `grant_achievement` returns false for already-granted, so double calls are safe.

New omen ids resolve in `run.gd _accept_omen()` match: `"lovers"` (deck picker → `add_card` duplicate → return, picker callback calls `_show_map()`), `"sun"` (+12 HP, `Sfx.play(&"heal", -6.0)`).

---

## 6. Title (P7)

`project.godot` `[application]`:

```
config/name="The Cards Do Not Lie"
config/use_custom_user_dir=true
config/custom_user_dir_name="godot/app_userdata/Parallaxa_card"
```

The custom dir is MANDATORY: `user://` derives from `config/name`, and renaming the game would silently orphan every existing `profile.cfg`/`run_save.cfg`. The value above resolves to the exact current path on Linux (`~/.local/share/godot/app_userdata/Parallaxa_card`) and a case-insensitive match on Windows/macOS.

`menu.gd` title block (replace the current hardcoded `PARALLAXA` label):

```gdscript
var series := _lbl("PARALLAXA", 15, Color(0.5, 0.47, 0.58))   # series tag, literal (brand)
series.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
col.add_child(series)
var title := _lbl(tr("MENU_TITLE"), 54, Color(0.95, 0.9, 0.75))
```

Tagline stays but its VALUE changes (it can no longer duplicate the title) — see csv. Card fan behind the title is unchanged.

---

## 7. Menu: New Run setup + Collection panels

### 7.1 New Run

`_new_run()`: if `Profile.wins == 0 and Profile.available_decks().size() == 1` → current direct start (zero friction for a fresh profile), but FIRST set `RunState.next_veil = 0`. Otherwise open the setup overlay:

- Dim `Color(0,0,0,0.88)` full-rect; centered VBox sep 16.
- `NEWRUN_TITLE` font 26.
- `NEWRUN_DECK` font 16; HBox of one toggle-panel per `Profile.available_decks()` id: panel `170x56`, deck display name (`DECK_CLASSIC`/`DECK_REAPER`/`DECK_GARDENER`/`DECK_ORACLE`) font 15 + desc key font 11; selected = white 3px border (same pattern as `_on_arc_input`). Default selection = `Profile.selected_deck` if still available else `"classic"`.
- `NEWRUN_VEIL` font 16; HBox of buttons `"0" .. str(Profile.veil_selectable_max())` (44x36 each); selected highlighted; `NEWRUN_VEIL_HINT` font 13 under it. Row hidden entirely when `Profile.wins == 0`.
- `NEWRUN_BEGIN` button 240x44: `Profile.selected_deck = chosen; Profile.save_profile(); RunState.next_veil = chosen_veil; RunState.load_pending = false; RunState.delete_run_save(); get_tree().change_scene_to_file(RUN_SCENE)`.
- `COMMON_CANCEL` closes the overlay.

### 7.2 Collection

- **Starter decks section** (replaces the single starter block): header `COLLECTION_DECKS` font 18. Per deck in `DeckLibrary.STARTERS` order (classic, reaper, gardener, oracle): name font 16 + desc font 12; HFlow of its 16 `CardWidget.build` cards; below: not-owned Sol decks → button `COLLECTION_DECK_BUY % Profile.DECK_COST` (disabled when `sol < 60`) → `Profile.buy_deck(id)`; oracle un-granted → dimmed cards `modulate Color(0.45,0.45,0.5)` + label `COLLECTION_ARC_ACH % tr("ACH_JOURNEY")`; owned → `COLLECTION_DECK_OWNED` label. Edition upgrade buttons per card (as today) with new call `Profile.upgrade_starter(deck_id, i)`; when `not Profile.edition_allowed(nxt)` the button is disabled with text `COLLECTION_ED_GATE % Profile.EDITION_VEIL_GATE[nxt]`.
- **Minor Arcana section**: unchanged grid, no locked block.
- **Major Arcana section**: existing grid; for `SHOP_ARCANA` entries append under the card: owned → `COLLECTION_ARC_OWNED` label font 11; not owned → button `COLLECTION_ARC_BUY % Profile.ARCANA_COST` → `Profile.buy_arcana(id)`. For `ACH_ARCANA` entries not yet granted: card `modulate Color(0.45,0.45,0.5)` + `COLLECTION_ARC_ACH % tr(ach_id)`.
- **Achievements section** (new, after Arcana): header `COLLECTION_ACH` font 18; per achievement (fixed order: DEATH_FLUSH, UNTOUCHED, OVERKILL, MISER, JOURNEY) a VBox row: name `tr(id)` font 15 — granted `Color(0.95,0.85,0.5)` / not `Color(0.55,0.55,0.62)`; `tr(id + "_DESC")` font 12; `tr("ACH_REWARD") % tr(id + "_REWARD")` font 12; status `ACH_DONE`/`ACH_UNDONE` font 12.

---

## 8. ui.csv — exact rows to append (and 1 value change)

CHANGE existing row `MENU_TAGLINE` to: `MENU_TAGLINE,Every reading comes true.,Każda wróżba się spełnia.`

Append (mind `%` parity EN/PL; quote cells containing commas):

```
MENU_SERIES,PARALLAXA,PARALLAXA
MENU_TITLE,THE CARDS DO NOT LIE,KARTY NIE KŁAMIĄ
SPREAD_WIN,THE CARDS DID NOT LIE,KARTY NIE SKŁAMAŁY
SPREAD_LOSS,DEATH TURNS THE FINAL CARD,ŚMIERĆ ODWRACA OSTATNIĄ KARTĘ
SPREAD_ARCANA,Arcana carried,Niesione Arkana
SPREAD_HIT_TITLE,Greatest blow,Największy cios
SPREAD_HIT_FOE,struck %s,poraził: %s
SPREAD_BEST_HAND,Best hand: %s Lv%d,Najlepszy układ: %s Lv%d
SPREAD_REGIONS,Regions cleared: %d/%d,Regiony zaliczone: %d/%d
SPREAD_FIGHTS,Fights won: %d,Wygrane walki: %d
SPREAD_DAMAGE,Damage dealt: %d,Zadane obrażenia: %d
SPREAD_TURNS,Turns played: %d,Rozegrane tury: %d
SPREAD_SALT,Salt earned: +%d,Zdobyta Sól: +%d
SPREAD_SEED,Fate %s,Los %s
SPREAD_SEED_HINT,click to copy,kliknij by skopiować
SPREAD_SEED_COPIED,copied,skopiowano
SPREAD_NEW,New fate,Nowy los
SPREAD_REPEAT,Repeat this fate,Powtórz ten los
SPREAD_MENU,Menu,Menu
NEWRUN_TITLE,Prepare the spread,Przygotuj rozkład
NEWRUN_DECK,Starter deck,Talia startowa
NEWRUN_VEIL,Veil,Zasłona
NEWRUN_VEIL_LEVEL,Veil %d,Zasłona %d
NEWRUN_VEIL_HINT,Higher Veils harden the journey.,Wyższe Zasłony utrudniają podróż.
NEWRUN_BEGIN,Begin the journey,Rozpocznij podróż
CLAIM_TITLE,Claim your prize — one of two,Wybierz zdobycz — jedną z dwóch
CLAIM_TAKE,Claim,Zabierz
COLLECTION_DECKS,Starter decks,Talie startowe
COLLECTION_DECK_BUY,Unlock (%d Salt),Odblokuj (%d Soli)
COLLECTION_DECK_OWNED,Owned,Posiadana
COLLECTION_ARC_BUY,Add to boss offers (%d Salt),Dodaj do ofert bossów (%d Soli)
COLLECTION_ARC_OWNED,In the boss pool,W puli bossów
COLLECTION_ARC_ACH,Unlocked by: %s,Odblokowywane przez: %s
COLLECTION_ED_GATE,Requires Veil %d beaten,Wymaga pokonania Zasłony %d
COLLECTION_ACH,Achievements,Osiągnięcia
ACH_DONE,Fulfilled,Spełnione
ACH_UNDONE,Not yet,Jeszcze nie
ACH_REWARD,Reward: %s,Nagroda: %s
ACH_UNLOCKED,Achievement fulfilled: %s,Osiągnięcie spełnione: %s
ACH_DEATH_FLUSH,Death's Hand,Ręka Śmierci
ACH_DEATH_FLUSH_DESC,Finish a foe with a pure Death flush.,Dobij wroga czystym kolorem Śmierci.
ACH_DEATH_FLUSH_REWARD,Omen: The Lovers,Omen: Kochankowie
ACH_UNTOUCHED,Untouched,Nietknięty
ACH_UNTOUCHED_DESC,Win a fight without losing a single HP.,Wygraj walkę nie tracąc ani punktu HP.
ACH_UNTOUCHED_REWARD,Arcanum of Strength joins the opening draft.,Arkanum Siły dołącza do startowego draftu.
ACH_OVERKILL,Overkill,Przesada
ACH_OVERKILL_DESC,Deal 300 or more damage in a single play.,Zadaj 300 lub więcej obrażeń jednym zagraniem.
ACH_OVERKILL_REWARD,Arcanum of the Hermit joins the opening draft.,Arkanum Pustelnika dołącza do startowego draftu.
ACH_MISER,Alchemist's Hoard,Skarbiec Alchemika
ACH_MISER_DESC,Hold 25 ☿ at once (full interest).,Miej naraz 25 ☿ (pełne odsetki).
ACH_MISER_REWARD,Omen: The Sun,Omen: Słońce
ACH_JOURNEY,The Fool's Circle,Krąg Głupca
ACH_JOURNEY_DESC,Complete the Journey — defeat The World.,Ukończ Podróż — pokonaj Świat.
ACH_JOURNEY_REWARD,Starter deck: Oracle's Gambit,Talia startowa: Gambit Wyroczni
DECK_CLASSIC,The Fool's Deck,Talia Głupca
DECK_REAPER,Reaper's Deal,Pakt Żniwiarza
DECK_REAPER_DESC,"Death and Chaos: rot, harvest and burst.","Śmierć i Chaos: gnicie, żniwo i burst."
DECK_GARDENER,Gardener's Path,Ścieżka Ogrodnika
DECK_GARDENER_DESC,"Nature and Life: growth, block and sustain.","Natura i Życie: wzrost, blok i przetrwanie."
DECK_ORACLE,Oracle's Gambit,Gambit Wyroczni
DECK_ORACLE_DESC,Mind and Chaos: Echo scaling and fury.,Umysł i Chaos: skalowanie Echa i furia.
ARCANUM_MAGA,Arcanum of the Magician,Arkanum Maga
ARCANUM_CESARZA,Arcanum of the Emperor,Arkanum Cesarza
ARCANUM_SILY,Arcanum of Strength,Arkanum Siły
ARCANUM_PUSTELNIKA,Arcanum of the Hermit,Arkanum Pustelnika
OMEN_LOVERS,The Lovers,Kochankowie
OMEN_LOVERS_DESC,Twin one card: add a copy of a chosen deck card.,Bliźniactwo: dodaj kopię wybranej karty z talii.
OMEN_SUN,The Sun,Słońce
OMEN_SUN_DESC,Warmth restores +12 HP.,Ciepło przywraca +12 HP.
```

---

## 9. Edge cases (must-handle)

1. Defeat with zero plays: `stat_best_hit == 0` → hit-card hidden; best hand shows `High Card Lv1` (default ordinal 0).
2. Defeat before the opening draft resolves is impossible (draft precedes fight 1), but `relics` can legally be empty on legacy regions — spread shows the dimmed Fool card.
3. `run_seed == 0` sentinel: never displayed; `begin` forces `1` if `randi()` rolls 0.
4. Repeat-this-fate reproduces the run only under identical choices (rerolls consume rng) — that is the intended Balatro-style contract; no further guarantee.
5. Old profile (v1) → migration refunds 25/unlock + cumulative edition cost, clears both, writes v2. Old run save → fresh random seed, stats zeroed, veil 0; everything else continues.
6. Standalone `combat.tscn`: `record_fight` is inside `if not standalone` — profile/run stats untouched.
7. `earn_run_reward` and `record_victory` fire exactly once, both only in `_show_spread`.
8. Boss 1-of-2 alternative is filtered by `name_key` against carried relics — a purchased Arcanum can never be offered twice in one run.
9. `check_run_achievements` at `_show_map` uses `victory=false`, so `ACH_JOURNEY` can only fire at the spread.
10. Seed button uses `DisplayServer.clipboard_set`; no seed ENTRY field exists (out of scope, replay is button-only).

## CONFLICTS
- run.gd _on_combat_finished currently claims the boss arcanum unconditionally and _show_complete reads RunState.region.boss_arcanum directly — the 1-of-2 claim flow (spec 4.4) moves the claim and adds a parameter; P4's planned 'plain vs REVERSED' boss choice must merge into this SAME choice screen (alternative slot = rng pick among [reversed variant] + purchased arcana), not a second screen.
- Profile.earn_run_reward is called today from BOTH _show_complete (final) and _show_defeat; the spread screen becomes the single caller — remove both old call sites or Sol double-pays.
- profile.gd unlock API (UNLOCK_COST/is_meta_locked_keyword/is_unlocked/unlock) is deleted; menu.gd's locked-cards Collection block and deck_library.gd reward_pool filtering reference it and must be removed in the same commit or the project won't parse. COLLECTION_LOCKED/COLLECTION_UNLOCK csv keys become orphans (left in place, csv is append-only).
- Profile.next_starter_edition/upgrade_starter change signature (deck_id added, starter_editions re-keyed int -> "deckid:index" string); menu.gd call sites (lines ~124-132, _upgrade_starter) must be updated together. Old int-keyed editions are refunded and cleared by the v2 migration, so no key-format translation is needed.
- project.godot config/name change RELOCATES user:// (profile.cfg + run_save.cfg would be silently abandoned). The spec mandates use_custom_user_dir=true with custom_user_dir_name="godot/app_userdata/Parallaxa_card" to pin the existing Linux path exactly; verify once on the dev machine that user://profile.cfg still loads after the rename.
- Veil (RunState.veil, Profile.best_veil/MAX_VEIL=5, menu selector) is STORAGE+UI only here — the P1 difficulty spec must consume RunState.veil and agree on 5 tiers and on the edition gates (Foil=Veil1, Holo=Veil3, Polychrome=Veil5); if P1 ships fewer tiers, EDITION_VEIL_GATE must be re-mapped in the same change.
- Seed replay integrity: any new RunState.rng consumer added by P1/P4 (veil modifiers, reversed rolls) must be appended after existing draw sites in flow order; inserting one earlier silently breaks 'Repeat this fate'. A comment contract above RunState.rng is part of this spec.
- RunState.rest() full-heal between regions and the new Sun omen (+12 HP) predate P1's planned per-fight heal caps — P1's balance pass should review omen heal values (Star +10, Sun +12) but must not touch the achievement trigger conditions.
- menu.gd currently hardcodes the title string "PARALLAXA" (line 46) and MENU_TAGLINE's current value ('The cards do not lie.') equals the NEW title — both the label and the csv value change together or the menu shows the title twice.
- ROADMAP dlug: run.gd is already 825 lines; this spec adds _show_boss_choice/_show_spread — SpreadScreen is mandated as a separate file (src/game/region/spread_screen.gd) to respect the noted split direction.
