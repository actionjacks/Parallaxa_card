# P3 SPEC — Court-Card Bestiary, Procedural Music, First-60-Seconds Context

Target: Godot 4.7 project at `/home/johnbakoma/Downloads/-11111/Parallaxa_card`.
Covenant respected: no combat RNG is introduced anywhere in this spec; music/visuals are presentation-only; all enums untouched (append-only rule preserved — the only schema change is ONE appended `@export` on `RegionData`, which is .tres-compatible because absent properties load as defaults). All player text goes through `data/locale/ui.csv` (columns `keys,en,pl`). All code/comments English ASCII.

---

## 1. Court-Card Bestiary (12 regular enemies → Minor Arcana faces)

### 1.1 Suit law (fixed, document in a comment in gen_content.gd)

| Suit | Aspect | File prefix |
|---|---|---|
| Cups | LIFE | `cups_` |
| Swords | MIND | `swords_` |
| Wands | CHAOS | `wands_` |
| Pentacles | DEATH | `pents_` |
| **NATURE** | **no court — wears the numbered TEN** of its elementally nearest suit | `*_10` |

**DECISION: NATURE = Tens, not Aces.** Rationale: a Ten is the suit grown past its limit (overgrowth = NATURE's Bujnosc/Wzrost mechanic), and the 4 Aces stay reserved as future reward/omen art (a lone hand-from-cloud reads as "pure power", wrong for a beast). This is final.

File naming in `assets/cards/minor/`: `01`=Ace, `02`–`10`=numbers, `11`=Page, `12`=Knight, `13`=Queen, `14`=King. All 56 files exist as `.jpg` (x384, RWS 1909 scans, same portrait ratio as the arcana scans — the existing 128x222 emblem frame in `combat.gd` (line ~280, `STRETCH_KEEP_ASPECT_CENTERED`) handles them with no code change).

### 1.2 Rank ladder = region tier

Region I = **Pages**, Region II = **Knights**, Region III = **Queens (pool 1) + Kings (pool 2)**. NATURE enemies break rank and wear a Ten. Region IV has no regular enemies (World duel only).

### 1.3 The mapping (art + new display names)

`.tres` file = existing file in `data/combat/`. Art path = `res://assets/cards/minor/<file>`.

| .tres | Locale key | Card | Art file | Aspect | EN value (new) | PL value (new) |
|---|---|---|---|---|---|---|
| enemy_a | ENEMY_KULTYSTA | Page of Pents | `pents_11.jpg` | DEATH | `"Page of Pentacles, Rotting Cultist"` | `"Paź Pentakli, Gnijący Kultysta"` |
| enemy_a2 | ENEMY_WIEDZMA | Page of Wands | `wands_11.jpg` | CHAOS | `"Page of Wands, Ash Witch"` | `"Paź Buław, Popielna Wiedźma"` |
| enemy_b | ENEMY_CIEN | Page of Swords | `swords_11.jpg` | MIND | `"Page of Swords, Wandering Shade"` | `"Paź Mieczy, Zbłąkany Cień"` |
| enemy_b2 | ENEMY_GOLEM | Ten of Pents | `pents_10.jpg` | NATURE | `"Ten of Pentacles, Cinder Golem"` | `"Dziesiątka Pentakli, Żużlowy Golem"` |
| enemy_r2a | ENEMY_KAPLAN | Knight of Cups | `cups_12.jpg` | LIFE | `"Knight of Cups, Ember Priest"` | `"Rycerz Kielichów, Kapłan Zgliszcz"` |
| enemy_r2a2 | ENEMY_UPIOR | Knight of Swords | `swords_12.jpg` | MIND | `"Knight of Swords, Ember Wraith"` | `"Rycerz Mieczy, Upiór Zgliszcz"` |
| enemy_r2b | ENEMY_RYCERZ | Knight of Pents | `pents_12.jpg` | DEATH | `"Knight of Pentacles, Clad in Ash"` | `"Rycerz Pentakli, Zakuty w Popiół"` |
| enemy_r2b2 | ENEMY_CHIMERA | Ten of Wands | `wands_10.jpg` | NATURE | `"Ten of Wands, Cinder Chimera"` | `"Dziesiątka Buław, Żużlowa Chimera"` |
| enemy_r3a | ENEMY_STRAZNIK | Queen of Cups | `cups_13.jpg` | LIFE | `"Queen of Cups, Summit Warden"` | `"Królowa Kielichów, Strażniczka Szczytu"` |
| enemy_r3a2 | ENEMY_WIDMO | Queen of Swords | `swords_13.jpg` | MIND | `"Queen of Swords, Peak Phantom"` | `"Królowa Mieczy, Widmo Grani"` |
| enemy_r3b | ENEMY_TYTAN | King of Pents | `pents_14.jpg` | DEATH | `"King of Pentacles, Frost Titan"` | `"Król Pentakli, Tytan Mrozu"` |
| enemy_r3b2 | ENEMY_HERALD | King of Wands | `wands_14.jpg` | CHAOS | `"King of Wands, Herald of the End"` | `"Król Buław, Herold Końca"` |

Fit notes (why these, so future edits keep the logic): steady rhythms sit on Pentacles (Knight/King of Pents are the stolid courts: RYCERZ [13,13,13], TYTAN [18,18,18]); spiky two-peak rhythms sit on Swords (WIEDZMA [13,3,13] is the exception — she is Wands for the ash-fire theme); burst-then-rest [x,0,y] enemies are the two NATURE Tens (GOLEM, CHIMERA) and the King of Wands (HERALD [24,0,20], apocalyptic fire). Region I leans Pentacles/DEATH deliberately (Ash region, starter deck is Death-heavy — the enemy suits teach the aspect wheel).

All en values contain commas → **must be double-quoted in ui.csv**. PL uses tarot-standard suit names: Kielichy, Miecze, Buławy, Pentakle; ranks Paź/Rycerz/Królowa/Król.

### 1.4 Code change (gen_content.gd only)

In `tools/gen/gen_content.gd`, assign `art` before each `ResourceSaver.save`. For the `_save_enemy()` helper add an optional trailing parameter `art_path: String = \"\"`; when non-empty: `e.art = load(art_path)`. For region-I enemies built inline (lines 111–118) assign directly, e.g.:

```gdscript
a.art = load(\"res://assets/cards/minor/pents_11.jpg\")
```

Exact art per file per the table above. Re-run the generator. **Zero changes in combat.gd** — the `_enemy.art != null` branch (line 274) already renders it; the letter-glyph fallback stays as dead-code safety.

### 1.5 Elites (P4 forward-spec — reserves art now, wire-up later)

Elites are **reversed Queens/Kings**: the four court cards NOT used by regulars: `pents_13` (Queen of Pentacles), `wands_13` (Queen of Wands), `swords_14` (King of Swords), `cups_14` (King of Cups — reserved spare, unused in v1). Elite emblem renders the card upside down: on the emblem `TextureRect` set `flip_h = true` and `flip_v = true` (= 180 deg rotation) when `enemy.is_elite` (P4 adds `@export var is_elite: bool = false` — appended field, .tres-safe).

**Elite stat multipliers (exact):**
- `max_hp`: base x **1.5**, rounded UP to nearest 10
- every intent value: base x **1.4**, floor
- `enrage_step`: base **+2**
- `reward_rtec`: base x **2**

Elite bases = the strongest pool_2 enemy of the region. Resulting resources (generate in P4):

| .tres | Base | HP | Intents | Enrage | Rtec | Art | Locale key | EN | PL |
|---|---|---|---|---|---|---|---|---|---|
| enemy_elite_r1 | GOLEM 450 | 680 | [22,0,16] | 5 | 12 | pents_13 | ENEMY_ELITE_R1 | `"Queen of Pentacles, Barren Regent"` | `"Królowa Pentakli, Jałowa Regentka"` |
| enemy_elite_r2 | RYCERZ 580 | 870 | [18,18,18] | 5 | 14 | wands_13 | ENEMY_ELITE_R2 | `"Queen of Wands, Pyre Queen"` | `"Królowa Buław, Pani Stosu"` |
| enemy_elite_r3 | TYTAN 800 | 1200 | [25,25,25] | 6 | 18 | swords_14 | ENEMY_ELITE_R3 | `"King of Swords, Cold Verdict"` | `"Król Mieczy, Zimny Wyrok"` |

**Elite name format key** (used on the map fork button and the combat title):
```
ELITE_NAME_FMT,"%s — Reversed","%s — Odwrócenie"
```
(one `%s` in both columns — mind the en/pl `%` parity trap). This ties elites to the game's "reversed card" brand.

---

## 2. Region visual identity — accent colors

Append to `src/game/region/region_data.gd` (after `starting_pool`, append-only):
```gdscript
@export var accent: Color = Color(0.6, 0.6, 0.65)  ## region identity tint: map header + backdrop
```

Exact values, set in gen_content.gd per region:

| Region | Hex | Godot Color |
|---|---|---|
| region_01 (Ash) | `9a8f84` | `Color(0.604, 0.561, 0.518)` |
| region_02 (Embers) | `d95f3b` | `Color(0.851, 0.373, 0.231)` |
| region_03 (Summit) | `7fb4d4` | `Color(0.498, 0.706, 0.831)` |
| region_04 (World) | `e8c268` | `Color(0.910, 0.761, 0.408)` |

Usage (both are 1-line changes):
1. **Map header** — `run.gd` line ~159: title color becomes `RunState.region.accent.lerp(Color(0.96, 0.92, 0.82), 0.35)` (35% toward the existing cream keeps 720p readability on the dark backdrop). Use `_label_center(text, 30, that_color)` instead of `_title()` on the map screen only; draft/other screens keep the cream `_title()`.
2. **Backdrop** — change `Backdrop.build()` signature to `build(accent: Color = Color(0, 0, 0, 0))`. If `accent.a > 0.0`: bottom gradient stop becomes `Color(0.10, 0.06, 0.045).lerp(accent, 0.18)` (top stop and vignette unchanged). `run.gd` and `combat.gd` pass `RunState.region.accent` when `RunState.region != null`; `menu.gd` passes nothing.

---

## 3. Procedural music (offline Python → WAV)

### 3.1 Files and format

Script: `tools/gen/gen_music.py`, **stdlib only** (`math`, `wave`, `struct`/`array`) — no numpy, so it runs on any machine. Run: `python3 tools/gen/gen_music.py` from repo root; writes into `assets/audio/music/`. Deterministic: no `random` at all — every event is scheduled by formula (matches project ethos; commit the wavs anyway so builds do not depend on Python).

Format for all files: **WAV PCM 16-bit, mono, 32000 Hz**. Peak-normalize each file to 0.71 (-3 dBFS). Seamless loop: render each track 0.5 s LONGER than its loop length, then equal-power crossfade the extra 0.5 s tail into the first 0.5 s (`out[i] = head[i]*sqrt(t) + tail[i]*sqrt(1-t)`), and cut to exact length.

| File | Loop length | Samples | Size |
|---|---|---|---|
| `menu_drone.wav` | 32.000 s | 1,024,000 | 1.95 MiB |
| `combat_loop.wav` | 20.000 s | 640,000 | 1.22 MiB |
| `boss_loop.wav` | 24.000 s | 768,000 | 1.46 MiB |
| `heartbeat_loop.wav` | 4.000 s | 128,000 | 0.24 MiB |

All under 2.5 MB. Total added to repo: ~4.9 MiB.

Note frequency table (equal temperament, A4=440; use these exact values):
D1 36.71, C2 65.41, C#2 69.30, D2 73.42, Eb2 77.78, F2 87.31, G2 98.00, A2 110.00, Bb2 116.54, C3 130.81, C#3 138.59, D3 146.83, Eb3 155.56, E3 164.81, F3 174.61, F#3 185.00, G3 196.00, A3 220.00, Bb3 233.08, C4 261.63, D4 293.66, Eb4 311.13, F#3/4 as listed, F4 349.23, G4 392.00, Ab4 415.30, A4 440.00, Bb4 466.16, C5 523.25, C#5 554.37, D5 587.33, E5 659.25, F5 698.46, A5 880.00.

Shared synthesis primitives (mirror the vocabulary of `sfx.gd` for consistency):
- `sine(f)` and `tri(f)` (triangle via `2/pi * asin(sin(phase))`).
- Envelopes: `adsr(a, d, s, r)` linear attack/release, exponential decay to sustain; `pluck(dur, k)` = `exp(-k*t/dur)`.
- `noise()`: deterministic LCG (`x = (x*1103515245 + 12345) & 0x7fffffff`, seed **1909**) mapped to [-1,1]; one-pole low-pass `y = 0.55*y + 0.45*x` for thuds; first-difference high-pass for hats.

### 3.2 `menu_drone.wav` — the occult lounge table (32 s, free time)

Key: **D natural minor** (aeolian) with a harmonic-minor pull at the turn. Mood target: candlelit fortune-teller, not horror.

Layers (amplitudes are pre-normalization linear):
1. **Drone**: continuous. `sine(D2 73.42) * 0.20` + `sine(73.72) * 0.20` (+0.3 Hz detune beat ≈ every 3.3 s) + `tri(D3 146.83) * 0.08`. Amplitude LFO on the sum: `1.0 + 0.12*sin(2*pi*0.1*t)`.
2. **Pad** (triangle, detune pairs at f and f+0.4 Hz, each voice 0.06 amp, attack 2.0 s, release 2.0 s, sustain full): four 8-second chords —
   - 0–8 s: **Dm** [D3, F3, A3]
   - 8–16 s: **Bb** [Bb2, D3, F3]
   - 16–24 s: **Gm** [G2, Bb2, D3]
   - 24–32 s: **A** [A2, C#3, E3] (the harmonic-minor dominant; the loop resolving back into Dm at 0 s IS the hook)
3. **Bell arp** (sine, `pluck(2.5, 5.0)`, amp 0.10): one note every 4.0 s starting at t=2.0 s, fixed 8-note sequence: **D5, A4, F5, D5, C5, A4, Bb4, C#5** (last bell is the leading tone landing on the loop seam).

### 3.3 `combat_loop.wav` — the duel (96 BPM, 4/4, 8 bars = 20.000 s)

Key: **D Phrygian** (D Eb F G A Bb C) — the b2 is the menace. Grid: sixteenth = 0.15625 s, beat = 0.625 s, bar = 2.5 s.

Progression, 2 bars each: **Dm [D,F,A] | Eb [Eb,G,Bb] | Dm | Cm [C,Eb,G]** (bVII walks back up to i at the seam).
1. **Bass** (triangle, amp 0.30, `adsr(0.005, 0.10, 0.6, 0.15)`, note length one eighth): per bar, chord ROOT at octave 2 on sixteenth-steps **0, 6, 8, 14**; step 8 plays the root one octave up (octave 3).
2. **Arp** (sine, amp 0.11, `pluck(0.12, 6.0)`): straight sixteenths, chord tones at octave 4 as [T0=root, T1=third, T2=fifth, T3=root+12]; 16-step index pattern per bar: **[0,1,2,3, 2,1,0,1, 2,3,2,1, 0,1,2,3]**; steps 0/4/8/12 accented x1.41.
3. **Pad** (triangle detune ±0.4 Hz, amp 0.10 total, attack 0.8 s, release 1.2 s): the current chord at octave 3, sustained per 2-bar block.
4. **Kick** (sine sweep 140→45 Hz over 70 ms, `pluck(0.09, 5.0)`, amp 0.40): beats 1 and 3 of every bar.
5. **Hat** (high-passed noise, 25 ms, amp 0.07): sixteenth-steps 2, 6, 10, 14 (offbeats).

### 3.4 `boss_loop.wav` — the Major Arcana made flesh (80 BPM, 4/4, 8 bars = 24.000 s)

Key: **D Phrygian dominant** (D Eb F# G A Bb C) — the occult-liturgical scale. Grid: eighth = 0.375 s, bar = 3.0 s.
1. **Deep drone**: `sine(D1 36.71) * 0.18 + sine(D2 73.42) * 0.10 + sine(73.92) * 0.10`, continuous.
2. **Bass ostinato** (triangle, amp 0.32, `pluck(0.35, 4.0)`): per bar, eighth-note steps [0..7] play **[D2, D2, rest, D2, Eb2, rest, C#2, rest]** — the half-step shudder under everything.
3. **Pad chords** (triangle detune pairs, amp 0.09 total, attack 1.0 s, release 1.5 s, vibrato 5 Hz, depth 0.3% of f), 2 bars each: **D [D3,F#3,A3] | Eb [Eb3,G3,Bb3] | D | Cm [C3,Eb3,G3]** — major I against bII is pure Phrygian-dominant dread.
4. **Toll bell** (sine at f + 0.3*sine at 2f, decay `pluck(2.2, 4.5)`, amp 0.26): **D4** at the start of bars 1, 3, 7; at bar 5 the toll is the **tritone stab [D4 + Ab4 415.30]** (decay 1.8 s) — the mid-loop wound.
5. **Tick** (high-passed noise 20 ms, amp 0.05): every beat (quarter notes) — the metronome of the enrage clock.

### 3.5 `heartbeat_loop.wav` — enrage stem (4.000 s, 4 beats at 60 BPM)

"Lub-dub" pair at t = 0.0, 1.0, 2.0, 3.0 s: lub = `sine(52 Hz)`, 100 ms, amp 0.9, `pluck(0.10, 6.0)`; dub at +180 ms = `sine(48 Hz)`, 80 ms, amp 0.65, same envelope. Low-pass the pair once (`y = 0.6*y + 0.4*x`). Nothing else in the file — it is a stem to layer, not a track.

### 3.6 Registration, loop flags, start/stop matrix

New file `src/game/audio/music_lib.gd` (`class_name MusicLib`), mirroring the `Sfx` static-registration pattern:
```gdscript
const TRACKS := {
    &\"music_menu\": \"res://assets/audio/music/menu_drone.wav\",
    &\"music_combat\": \"res://assets/audio/music/combat_loop.wav\",
    &\"music_boss\": \"res://assets/audio/music/boss_loop.wav\",
    &\"music_heartbeat\": \"res://assets/audio/music/heartbeat_loop.wav\",
}
```
`MusicLib.ensure_registered()` loads each, and **forces looping at runtime** (Godot imports .wav non-looping by default; do not depend on .import edits):
```gdscript
var s: AudioStreamWAV = load(path)
s.loop_mode = AudioStreamWAV.LOOP_FORWARD
s.loop_begin = 0
s.loop_end = s.data.size() / 2   # 16-bit mono: 2 bytes per frame
am.register(key, s)
```
`MusicLib.play(key, fade)` = ensure_registered + `AudioManager.play_music(key, fade)`; headless-safe null check like `Sfx.play`.

**Start/stop matrix (exact call sites and crossfade seconds):**

| Screen / event | Call | Fade |
|---|---|---|
| Main menu (`menu.gd _ready`) | `MusicLib.play(&\"music_menu\", 2.0)` | 2.0 |
| Run start: draft + map + shop + reward + omen (`run.gd _start_run_flow`) | `MusicLib.play(&\"music_menu\", 1.5)` | 1.5 (no-op if already playing — `play_music` dedupes by key) |
| Back on map after a fight (`run.gd _show_map`) | `MusicLib.play(&\"music_menu\", 1.5)` | 1.5 |
| Regular combat (`combat.gd setup`, `enemy.is_boss == false`) | `MusicLib.play(&\"music_combat\", 0.8)` | 0.8 |
| Boss combat (`enemy.is_boss == true`) | `MusicLib.play(&\"music_boss\", 0.8)` | 0.8 |
| Combat WIN overlay (`combat.gd`, on `ended(true)`) | `AudioManager.stop_music(1.5)` | 1.5 out |
| Combat LOSS overlay (`ended(false)`) | `AudioManager.stop_music(0.5)` | 0.5 out — hard silence sells the death; the `lose` sfx stands alone |
| Region complete / (P5) tarot-spread screen | `MusicLib.play(&\"music_menu\", 3.0)` | 3.0 |
| Defeat screen (`run.gd` death screen) | nothing — stays silent; music returns via `_start_run_flow` on the next run | — |

### 3.7 Heartbeat wiring (enrage)

Expose on `combat_controller.gd` (the formula already exists inline at line 63):
```gdscript
func enrage_cycles() -> int:
    return _intent_index / enemy.intents.size()
```
`combat.gd` owns ONE dedicated `AudioStreamPlayer` (bus `Music`, `stream = MusicLib` heartbeat stream, created in `setup`) — NOT the sfx pool (pool voices get stolen; a loop must never be stolen). After each enemy turn resolves: let `c := controller.enrage_cycles()`; if `c >= 1` and not playing → start at **-10 dB** and tween to target over **0.5 s**; target dB = `min(0.0, -10.0 + 3.0 * (c - 1))` (cycle 1 = -10, 2 = -7, 3 = -4, 4 = -1, 5+ = 0), retweened 0.3 s on each new cycle. On `ended(...)`: fade out 0.3 s and stop. Deterministic: driven purely by the intent index.

---

## 4. First-60-seconds context (Arcanum draft)

No tutorial system. Two additions to the existing draft screen in `run.gd`, all text mechanical/diegetic per the no-filler covenant.

### 4.1 Playstyle blurb per draftable Arcanum

Key derivation: **`<name_key> + \"_BLURB\"`** (so `arcanum_data.gd` gets `func blurb_key() -> String: return name_key + \"_BLURB\"`, and the panel hides the label when `tr(k) == k`). New ui.csv rows (quote every en value containing a comma; en/pl have zero `%` — parity trivially safe):

```
ARCANUM_SMIERCI_BLURB,\"Aggro: stack Death, hit big.\",\"Agresja: stakuj Śmierć, bij mocno.\"
ARCANUM_SLONCA_BLURB,Sustain: every play heals you.,Przetrwanie: każde zagranie leczy.
ARCANUM_KAPLANKI_BLURB,\"Control: more discards, better hands.\",\"Kontrola: więcej odrzutów, lepsze układy.\"
ARCANUM_DIABLA_BLURB,\"Greed: power now, blood later.\",\"Chciwość: moc teraz, krew później.\"
ARCANUM_CESARZOWEJ_BLURB,Defense: every play builds block.,Obrona: każde zagranie daje blok.
```
(Each ≤ 6 words. Pattern is fixed: `Archetype: consequence.` — future arcana must follow it.)

Placement in `_arcanum_offer_panel` (run.gd line ~752): between the name label (16 px) and the `describe()` label (13 px), add the blurb as a centered label, **font 12, color `Color(0.62, 0.64, 0.72)`**. Order top-to-bottom: art → name → blurb (what it plays like) → describe() (exact numbers).

### 4.2 Draft-screen intro line

One new key:
```
DRAFT_CONTEXT,Your Arcanum is a permanent passive for the entire run.,Arkanum to stały pasyw na cały run.
```
Placement in `_show_arcanum_draft` (line ~705): directly under `DRAFT_TITLE`, above `DRAFT_HINT`, as `_hint(tr(\"DRAFT_CONTEXT\"))` (existing 15 px gray helper). `DRAFT_HINT` (\"The cards are laid out...\") stays as the third, flavor line.

---

## 5. Edge cases

- **Missing minor art file** → `load()` returns null → existing letter-glyph fallback renders; no crash path. Keep it.
- **`play_music` re-entry**: dedupe-by-key means map→shop→map never restarts the drone; the ONLY forced restarts are combat entries (different keys). Correct as-is.
- **Two fights back-to-back with same key** (fight 1 → fight 2, both `music_combat`): dedupe keeps it playing through the map interlude ONLY if the map didn't switch to menu music — it does (1.5 s fade), so fight 2 re-enters cleanly at 0.8 s. Accept the brief drone between fights; it is the \"table between deals\" beat.
- **Loop seam pops**: the 0.5 s equal-power baked crossfade (3.1) plus `LOOP_FORWARD` covers it; do not rely on zero-crossing trims.
- **Volume settings**: everything rides the existing `Music` bus; no new settings keys.
- **Headless tests**: `MusicLib.play` no-ops without the autoload (same guard as `Sfx.play`), so `run_hidden.sh` and unit tests are unaffected.
- **Locale regeneration**: after editing ui.csv run the import so the `.translation` compilates refresh; PL diacritics stay UTF-8.

## 6. Implementation order (one integrator, sequential)

1. `gen_music.py` + commit wavs (pure addition, zero engine risk).
2. `MusicLib` + start/stop hooks + heartbeat + `enrage_cycles()`.
3. ui.csv: 12 renamed values + 6 new keys (blurbs + DRAFT_CONTEXT) + ELITE_NAME_FMT.
4. gen_content.gd: enemy art + `RegionData.accent` + region accents; regenerate .tres.
5. `Backdrop.build(accent)` + map header color + draft-screen labels.
6. Import, run hidden, screenshot draft screen + one combat per region, and LISTEN to each loop seam.

## CONFLICTS
- ui.csv: the 12 regular-enemy display names (ENEMY_KULTYSTA..ENEMY_HERALD, lines 229, 255-262, 266, 351-352) get NEW en/pl VALUES (court-fused names). Keys are unchanged so .tres/save compat holds, but any screenshot/doc referencing old names goes stale.
- ENEMY_RYCERZ 'Ash Knight' would read 'Knight of Pentacles - Ash Knight' (double Knight). Spec renames the epithet to 'Clad in Ash' / 'Zakuty w Popiol'.
- AudioManager.play_music currently has ZERO call sites (confirmed) - all start/stop hooks in section 3.6 are new code, nothing to migrate.
- Godot imports .wav with loop DISABLED by default; without the loop_mode fix in 3.5 every music track plays once and stops. Spec sets AudioStreamWAV.loop_mode at registration time (runtime, in-memory) - do NOT rely on .import edits.
- combat_controller.gd has no enrage signal; heartbeat needs the new public func enrage_cycles() (section 3.7). The formula already exists inline at line 63.
- Region IV has no regular enemies (boss-only duel), so the '12 across 4 regions' bestiary actually lives in regions I-III. No filler enemies are added - do not invent any.
- CSV escaping: several new en values contain commas and MUST be double-quoted in ui.csv (Godot CSV translation format), e.g. blurbs and court names with epithets.
- sfx.gd synthesizes at 22050 Hz while music is 32000 Hz - this is fine (independent streams), do not 'unify' the rates.
- Elite resources (enemy_elite_r1..r3) are P4 content speced here only to reserve art (pents_13, wands_13, swords_14, cups_14) - generating the .tres now is harmless, but do NOT wire them into fight pools in P3.
