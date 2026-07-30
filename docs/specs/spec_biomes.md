# 5 biomow, pieczecie kolorow, Biom Zapieczetowany

> Zrodlo: panel projektowy (workflow parallaxa-feel-overhaul), 5 biomow, pieczecie kolorow, Biom Zapieczetowany.
> Dokument PROJEKTOWY -- stan wdrozenia opisuje docs/ROADMAP.md.

## Streszczenie

Run zmienia sie z 4 sztywnych regionow na 3 WYBIERANE biomy (z 5 kolorow) + Swiat — dlugosc runu bez zmian (10 walk), a pokonanie bossa biomu daje trwala PIECZEC w Profile; 5 pieczeci odblokowuje przycisk "Zlam Pieczec" przy Bramie Swiata, ktory prowadzi do ukrytego Biomu Zapieczetowanego (4 Asy + boss GLUPIEC, ktory oddaje twoj wlasny cios).

## SPEC

# PARALLAXA_CARD — 5 BIOMOW, PIECZECIE KOLOROW, BIOM ZAPIECZETOWANY
## Spec implementacyjna (docs/specs/spec_biomes.md)

---

## 0. DECYZJA GLOWNA — struktura runu

**WYBRANE: run = 3 biomy wybierane z 5 + Swiat. NIE 5 biomow po kolei.**

Uzasadnienie tempem (liczby z obecnego kodu):
- Dzis: 4 regiony = 2+2+2 walki zwykle + 3 bossy + 1 boss Swiata = **10 starc** (+ do 3 elit).
- 5 biomow po kolei = 5x3 + Swiat = **16 starc** = +60% dlugosci runu. Odpada (brief: "jeszcze jeden run", nie run na 2h).
- 1 biom na run = 3 starcia = za krotko, deck nie zdazy urosnac, poker nie wychodzi poza pary.
- **3 biomy + Swiat = 10 starc = dokladnie dzisiejsza dlugosc.** Zero regresji tempa.

Konsekwencja meta: max **3 pieczecie na run**, wiec 5 pieczeci wymaga **minimum 2 runow**, realnie 3-4. To jest wlasnie petla "jeszcze jeden run" — gracz wraca po BRAKUJACY KOLOR, a nie po powtorke tego samego.

Pieczec pada **po pokonaniu bossa biomu**, nie na koncu runu. Smierc przy Swiecie nie kasuje 3 zdobytych pieczeci (spojne z istniejaca doktryna "kazdy run karmi meta": `earn_run_reward(victory=false)`).

### Rozklad stopni (tier)
| Etap | region_index | tier | Zawartosc |
|---|---|---|---|
| 0 | 0 | 0 | biom wybrany swobodnie z 5 |
| 1 | 1 | 1 | biom: wybor 1 z 2 (rzut z pozostalych 4) |
| 2 | 2 | 2 | biom: wybor 1 z 2 (rzut z pozostalych 3) |
| 3 | 3 | 3 | **Swiat** (region_world) — bez zmian |
| 3+ | 3 | 3 | **Biom Zapieczetowany** — tylko z 5 pieczeciami, opcjonalny, po Swiecie |

Skalowanie trudnosci przechodzi z recznie pisanych HP w .tres na **mnozniki tierowe** (patrz sek. 4) — dzieki temu kazdy biom potrzebuje tylko JEDNEGO kompletu wrogow, a nie trzech.

---

## 1. PIEC BIOMOW — pelna definicja

Kazdy biom: 4 wrogow zwyklych (pool_1 = a,b; pool_2 = c,d), 1 elita, 3 bossy w rotacji, wlasne PRAWO POLA, wlasny akcent, wlasna pieczec.

**Prawo suitow (utrzymane z docs/specs/spec_content.md):** cups=LIFE, swords=MIND, wands=CHAOS, pents=DEATH; NATURE nie ma suitu → nosi **Dziesiatki** (zwykli) i **Siodemke Pentakli** (elita). Elity kazdego biomu koloru = **Dziewiatka** danego suitu (renderowana odwrocona — `is_elite` juz to robi).

---

### 1.1 BIOM LIFE — `biome_life.tres`
- Klucz nazwy: `BIOME_LIFE` = EN "The Orchard of Cups" / PL "Sad Kielichow"
- `seal_aspect = 0` (Aspects.Id.LIFE), `accent = Color(0.82, 0.74, 0.50)`
- **PRAWO: `Law.LIFE_TITHE` (1)** — `law_key = "LAW_LIFE"`
  - kazde zagranie daje **+2 bloku za kazda zagrana karte** (Scoring, krok 6b)
  - `heal_cap += 8` w kazdej walce biomu (CombatController.start)
  - Tozsamosc: biom, w ktorym da sie PRZETRWAC — wrogowie maja duzo HP i niskie, rowne intenty. Uczy grania na 5 kart (bo blok skaluje sie z liczba kart).
- **Wrogowie (wartosci BAZOWE, tier mnozy):**

| plik | art | locale | HP | intents | enrage | rtec |
|---|---|---|---|---|---|---|
| enemy_life_a | cups_11 | ENEMY_LIFE_A | 600 | [9,9,9] | 2 | 5 |
| enemy_life_b | cups_12 | ENEMY_LIFE_B | 620 | [11,8,11] | 2 | 5 |
| enemy_life_c | cups_13 | ENEMY_LIFE_C | 660 | [10,10,10] | 3 | 6 |
| enemy_life_d | cups_14 | ENEMY_LIFE_D | 700 | [12,12,6] | 3 | 6 |
| enemy_life_e (elite) | cups_09 | ENEMY_LIFE_E | 680 | [14,14,14] | 4 | 12 |

- **Bossy (3):** `boss_emperor` (NOWY, Rule.EMPEROR_WALL), `boss_strength` (istnieje, STRENGTH_RESIST), `boss_star` (istnieje, STAR_REGEN)
- **Nagrody:** `reward_aspect = 0` — pierwszy slot kazdej oferty kart i sklepu jest LIFE.

---

### 1.2 BIOM MIND — `biome_mind.tres`
- `BIOME_MIND` = EN "The Library of Swords" / PL "Biblioteka Mieczy"
- `seal_aspect = 1`, `accent = Color(0.43, 0.62, 0.80)`
- **PRAWO: `Law.MIND_ARCHIVE` (2)** — `law_key = "LAW_MIND"`
  - `hand_size = 9` zamiast 8
  - `discards_left = START_DISCARDS + 1 + _bonus_discards()` (czyli 4 zamiast 3)
  - Tozsamosc: **to jest bezposrednia odpowiedz na "udawalo mi sie robic tylko pary"**. 9 kart + 4 odrzuty = pierwszy biom, w ktorym gracz REALNIE sklada strita/kolor. Wrogowie maja malo HP i dwa ostre szczyty — walka jest krotka i jest zagadka.
- **Wrogowie:**

| plik | art | locale | HP | intents | enrage | rtec |
|---|---|---|---|---|---|---|
| enemy_mind_a | swords_11 | ENEMY_MIND_A | 440 | [17,3,17] | 2 | 5 |
| enemy_mind_b | swords_12 | ENEMY_MIND_B | 460 | [19,0,19] | 2 | 5 |
| enemy_mind_c | swords_13 | ENEMY_MIND_C | 480 | [16,6,16] | 3 | 6 |
| enemy_mind_d | swords_14 | ENEMY_MIND_D | 500 | [21,2,21] | 3 | 6 |
| enemy_mind_e (elite) | swords_09 | ENEMY_MIND_E | 620 | [22,4,22] | 4 | 12 |

- **Bossy:** `boss_hermit` (NOWY, HERMIT_DARK), `boss_hanged` (istnieje, HANGED_CAP), `boss_justice` (istnieje, JUSTICE_RIPOSTE)
- `reward_aspect = 1`

---

### 1.3 BIOM DEATH — `biome_death.tres`
- `BIOME_DEATH` = EN "The Catacombs of Pentacles" / PL "Katakumby Pentakli"
- `seal_aspect = 2`, `accent = Color(0.52, 0.40, 0.68)`
- **PRAWO: `Law.DEATH_HARVEST` (3)** — `law_key = "LAW_DEATH"`
  - `chips += 2 * grave` — kazda karta w stosie zuzytych dodaje +2 zetony do KAZDEGO zagrania. `grave` juz jest w `ctx` (`_used.size()`), zero nowego plumbingu.
  - Tozsamosc: biom nagradzajacy DLUGA walke. Wrogowie mieleni, wysoki enrage — wyscig miedzy narastajacym grave a narastajacym intentem.
- **Wrogowie:**

| plik | art | locale | HP | intents | enrage | rtec |
|---|---|---|---|---|---|---|
| enemy_death_a | pents_11 | ENEMY_DEATH_A | 520 | [12,13,11] | 3 | 5 |
| enemy_death_b | pents_12 | ENEMY_DEATH_B | 560 | [13,13,13] | 3 | 5 |
| enemy_death_c | pents_13 | ENEMY_DEATH_C | 600 | [14,12,12] | 4 | 6 |
| enemy_death_d | pents_14 | ENEMY_DEATH_D | 640 | [15,14,13] | 4 | 6 |
| enemy_death_e (elite) | pents_09 | ENEMY_DEATH_E | 700 | [18,18,18] | 5 | 12 |

- **Bossy:** `boss_death` (NOWY, DEATH_TITHE — arcanum_death JUZ ISTNIEJE), `boss_moon` (istnieje, MOON_CLEANSE), `boss_judgement` (istnieje, JUDGEMENT_FRAIL)
- `reward_aspect = 2`

---

### 1.4 BIOM CHAOS — `biome_chaos.tres`
- `BIOME_CHAOS` = EN "The Burnt Field of Wands" / PL "Pogorzelisko Bulaw"
- `seal_aspect = 3`, `accent = Color(0.80, 0.38, 0.30)`
- **PRAWO: `Law.CHAOS_KINDLING` (4)** — `law_key = "LAW_CHAOS"`
  - zagranie **5 kart → mult *= 1.5**; zagranie **1-2 kart → mult *= 0.75**
  - Tozsamosc: **drugi bezposredni fix skargi gracza** — biom, ktory wprost UCZY, ze gra sie 5 kartami, i placi za to. Wrogowie z rytmem burst-odpoczynek `[X,0,Y]`: masz turę oddechu na przygotowanie duzej reki.
- **Wrogowie:**

| plik | art | locale | HP | intents | enrage | rtec |
|---|---|---|---|---|---|---|
| enemy_chaos_a | wands_11 | ENEMY_CHAOS_A | 460 | [20,0,14] | 3 | 5 |
| enemy_chaos_b | wands_12 | ENEMY_CHAOS_B | 480 | [22,0,15] | 3 | 5 |
| enemy_chaos_c | wands_13 | ENEMY_CHAOS_C | 500 | [24,0,16] | 4 | 6 |
| enemy_chaos_d | wands_14 | ENEMY_CHAOS_D | 520 | [26,0,18] | 4 | 6 |
| enemy_chaos_e (elite) | wands_09 | ENEMY_CHAOS_E | 640 | [24,10,24] | 5 | 12 |

- **Bossy:** `boss_tower` (istnieje), `boss_devil` (istnieje), `boss_chariot` (istnieje) — **zero nowej pracy**
- `reward_aspect = 3`

---

### 1.5 BIOM NATURE — `biome_nature.tres`
- `BIOME_NATURE` = EN "The Overgrowth" / PL "Przerost"
- `seal_aspect = 4`, `accent = Color(0.42, 0.66, 0.40)`
- **PRAWO: `Law.NATURE_OVERGROWTH` (5)** — `law_key = "LAW_NATURE"`
  - na koniec kazdej tury wroga **kazda karta pozostawiona na rece dostaje `growth += 3`** (obok istniejacego rampu WZROST/KORZENIE w combat_controller.gd ~linia 338). `CardData.chip_value()` juz sumuje `growth`, wiec podglad jest exact.
  - Tozsamosc: jedyny biom, w ktorym **oplaca sie NIE zagrywac** — trzymasz reke, karty tyja, potem uderzasz raz i mocno. Wrogowie maja rosnace intenty (`[niskie, srednie, wysokie]`) i wysoki enrage: zegar jest realny.
- **Wrogowie (Dziesiatki — NATURE nie ma suitu):**

| plik | art | locale | HP | intents | enrage | rtec |
|---|---|---|---|---|---|---|
| enemy_nature_a | cups_10 | ENEMY_NATURE_A | 540 | [8,11,14] | 4 | 5 |
| enemy_nature_b | swords_10 | ENEMY_NATURE_B | 520 | [7,12,15] | 4 | 5 |
| enemy_nature_c | wands_10 | ENEMY_NATURE_C | 560 | [9,12,16] | 5 | 6 |
| enemy_nature_d | pents_10 | ENEMY_NATURE_D | 580 | [10,13,16] | 5 | 6 |
| enemy_nature_e (elite) | **pents_07** | ENEMY_NATURE_E | 720 | [12,16,20] | 6 | 12 |

  (pents_07 = Siodemka Pentakli: czlowiek oparty o motyke patrzacy na rosnacy krzew — najbardziej "rolnicza" karta RWS. Rozwiazuje problem "NATURE nie ma skanu" bez wymyslania grafiki.)
- **Bossy:** `boss_empress` (NOWY, EMPRESS_BLOOM — arcanum_empress JUZ ISTNIEJE), `boss_temperance` (NOWY, TEMPERANCE_MIX — nowe arcanum), `boss_wheel` (NOWY, WHEEL_TURN — nowe arcanum)
- `reward_aspect = 4`

---

### 1.6 Przydzial 22 Arkanow — pelna mapa (bez kolizji)

| Biom | Bossy (Arkana) | Nowe .tres bossa | Nowe .tres arkanum |
|---|---|---|---|
| LIFE | Cesarz(4), Sila(8), Gwiazda(17) | boss_emperor | — (arcanum_emperor istnieje) |
| MIND | Pustelnik(9), Wisielec(12), Sprawiedliwosc(11) | boss_hermit | — (arcanum_hermit istnieje) |
| DEATH | Smierc(13), Ksiezyc(18), Sad(20) | boss_death | — (arcanum_death istnieje) |
| CHAOS | Wieza(16), Diabel(15), Rydwan(7) | — | — |
| NATURE | Cesarzowa(3), Umiarkowanie(14), Kolo Fortuny(10) | boss_empress, boss_temperance, boss_wheel | arcanum_temperance, arcanum_wheel |
| Swiat | Swiat(21) | — | — |
| Zapieczetowany | **Glupiec(0)** | boss_fool | arcanum_fool |

Nieuzyte jako bossy: Mag(1), Kaplanka(2), Kaplan(5), Kochankowie(6) — zostaja jako arkana draftu/omeny/portret Tarocisty (Kaplan = portret gracza w menu, nie ruszac).
**Nowej roboty: 6 bossow + 3 arkana. Reszta rotacji to redystrybucja istniejacych plikow.**

---

## 2. UKRYTY BIOM — "BIOM ZAPIECZETOWANY / ARKANUM ZERO"

### 2.1 Warunek wejscia i miejsce w UI
- `Profile.seals_complete()` (5 z 5) **ORAZ** `RunState.depth == 0` **ORAZ** run wlasnie pokonal Swiat.
- Pojawia sie jako **TRZECI przycisk na istniejacym ekranie Bramy Swiata** (`run.gd::_show_world_gate`), obok "Zakoncz odczytanie" i "Dalej — Glebia %d":
  - `GATE_SEAL` = "Zlam Pieczec — Arkanum Zero", kolor `Color(0.95, 0.92, 0.85)`, `custom_minimum_size = Vector2(200, 40)`
  - podpis `GATE_SEAL_HINT` pod rzedem
- **NIE ma wejscia z menu glownego.** Uzasadnienie: potezny boss wymaga ZBUDOWANEJ talii (26-30 kart + 3-4 Arkana). Wejscie z menu z talia 16 kart = niewygrywalne albo trzeba budowac osobny tryb. W menu jest za to **plakietka 5 pieczeci** + linijka `SEAL_PLAQUE_FULL` = "Pentagram zamkniety. Pieczec odpowiada na koncu Podrozy." — gracz wie, gdzie isc, i to jest tekst mechaniczny, nie wypelniacz.
- `depth > 0` chowa przycisk: **Glupiec odpowiada tylko PIERWSZEJ domknietej podrozy.**

### 2.2 Zawartosc — `region_sealed.tres`
- `BIOME_SEALED` = EN "The Sealed Biome — Arcanum Zero" / PL "Biom Zapieczetowany — Arkanum Zero"
- `seal_aspect = -1` (nie daje pieczeci — jest ich zwienczeniem), `hidden = true`, `tier_index = 3`
- `accent = Color(0.88, 0.88, 0.92)` — kosciana biel (brak koloru = wszystkie kolory)
- Struktura: **2 walki + boss** (tak jak biom), bez elity.
- **Wrogowie = cztery ASY** (zarezerwowany art z spec_content.md: "reka z chmury = czysta moc" — dokladnie to, czym jest zapieczetowany biom):

| plik | art | locale | HP baz. | intents baz. | enrage | rtec |
|---|---|---|---|---|---|---|
| enemy_seal_a | cups_01 | ENEMY_ACE_CUPS | 620 | [10,10,10] | 1 | 10 |
| enemy_seal_b | swords_01 | ENEMY_ACE_SWORDS | 580 | [13,3,13] | 1 | 10 |
| enemy_seal_c | wands_01 | ENEMY_ACE_WANDS | 560 | [15,0,11] | 1 | 10 |
| enemy_seal_d | pents_01 | ENEMY_ACE_PENTS | 600 | [11,11,11] | 2 | 10 |

  (po tier 3: HP 1450-1610, intenty ~[23..35] — powyzej Swiata, bo talia jest juz pelna i dziala PRAWO PIECZECI)

- **PRAWO: `Law.SEAL_FIVE` (6)** — `law_key = "LAW_SEAL"`
  - `mult += float(aspect_counts.size())` — **+1.0 mnoznika za KAZDY odmienny Aspekt w zagraniu, max +5.0**
  - Dlaczego to jest deterministyczne i uczciwe: `aspect_counts` juz jest liczone w `Scoring.score` (linia ~37). Zero zmian w `Poker.evaluate` — **kontrakt podgladu nietkniety**.
  - Dlaczego to jest ZWIENCZENIE: caly run walczysz o KOLOR (flush = 5 tego samego aspektu). Tutaj gra odwraca wlasna zasade: nagradzana jest **teczowa reka, jedna karta z kazdego z 5 kolorow** — dokladnie te 5 kolorow, ktore gracz zbieral przez cala meta-podroz. Fikcja i mechanika sa tym samym zdaniem.

### 2.3 BOSS: **GLUPIEC (0)** — `boss_fool.tres`

**Wybor GLUPIEC, nie SWIAT. Uzasadnienie:**
1. Swiat(21) JUZ jest finalem runu i brama do Glebi (`_show_world_gate`). Uzycie go drugi raz duplikuje koniec gry — brief tego wprost zabrania ("nie duplikowac konca gry").
2. Gra juz mowi graczowi, ze **JEST Glupcem** — pasek statusu renderuje `00_fool.jpg` z tooltipem `FOOL_YOU`. Spotkanie Glupca po zebraniu 5 kolorow jest jedynym zakonczeniem, ktore przewartosciowuje caly run wstecz.
3. Glupiec = 0 = pusta pieczec, szosty kolor ktory jest brakiem koloru. Idealnie domyka "5 kolorow → to co po nich".

**Statystyki:** `max_hp = 1300` (po `TIER_BOSS_HP[3] = 2.00` → **2600 efektywnie**), `intents = [12]` (tylko fallback tury 1), `enrage_step = 0`, `reward_rtec = 40`, `is_boss = true`, art `assets/cards/arcana/00_fool.jpg`, `arcanum = arcanum_fool.tres`.

**Regula pola: `Rule.FOOL_MIRROR` (17)** — `rule_key = "RULE_FOOL"`

```gdscript
## The Fool answers with your own blow. Deterministic and preview-EXACT: the combat HUD feeds
## the live preview damage into this, so the intent number moves while you pick cards.
func mirror_intent(play_damage: int) -> int:
    if play_damage <= 0:
        return _intent_at(0)          # turn 1 fallback (authored intents, tier-scaled)
    @warning_ignore("integer_division")
    return clampi(play_damage / 14, 8, 34)
```
- FOOL_MIRROR **omija skalowanie tier/veil/depth intentow** (zegar Glupca to gracz, nie tabela) — udokumentowac jako jawny wyjatek w `_intent_at`.
- `combat.gd`: gdy `controller.active_rule() == Rule.FOOL_MIRROR`, etykieta intentu pokazuje `controller.mirror_intent(effective_damage(preview.damage))` na biezaco przy zaznaczaniu kart, i zamraza sie po `play()`.
- Efekt: **to jest kulminacja tezy "karty nie klamia"** — podglad przestaje byc kalkulatorem, a staje sie dialogiem. Gracz na 55 HP musi wazyc "zabic szybciej" vs "nie oberwac wlasnym ciosem" (cap 34 = smierc w 2 turach bez bloku).

### 2.4 Nagroda za zlamanie pieczeci
- Ekran `_show_sealed_end()`:
  - `Profile.claim_once("seal_broken")` → pierwszy raz pokazuje `SEALED_END_LINE`, kolejne razy `SEALED_END_AGAIN` (bez powtarzania ceremonii)
  - `Profile.grant_achievement("ACH_ZERO")` (+10 Sol jak kazdy)
  - Arkanum Glupca (`arcanum_fool`) — jedyny relikt z `Effect.MAGNIFY`, `effect_mult = 1.4`, `price = Price.NONE`. Wchodzi do `Profile.SHOP_ARCANA`? **NIE** — wchodzi do `Profile.ACH_ARCANA` pod `ACH_ZERO`, czyli **na stale do puli draftu otwierajacego run**. To jest zgodne z doktryna odwroconej mety (`spec_meta.md`): nagroda POSZERZA przestrzen mozliwosci, nie daje +X do statystyki.
  - potem `_show_spread(true)` — normalny rozklad konca runu, Sol/XP/osiagniecia jak zawsze (liczone RAZ).
- Powtarzalne: mozna zlamac pieczec w kazdym kolejnym wygranym runie. Ceremonia jednorazowa, walka nie.

### 2.5 Relacja z "Za Swiatem"/depth (endless) — bez duplikacji
| | Glebia (Beyond) | Biom Zapieczetowany |
|---|---|---|
| os | POZIOMA: petla tej samej Podrozy, +50% HP / +35% intent na glebie | PIONOWA: jednorazowy terminus |
| warunek | pokonanie Swiata | pokonanie Swiata **+ 5 pieczeci** |
| dlugosc | nieskonczona | +3 starcia |
| dostepnosc | zawsze | tylko `depth == 0` |
| tresc | ta sama, przeskalowana | wlasne 5 przeciwnikow, wlasne prawo, wlasny boss |
- **Wzajemnie wykluczajace sie w jednym runie**: wejscie w Pieczec ustawia `RunState.sealed_entered = true` i po pokonaniu Glupca run konczy sie rozkladem — Brama juz nie wraca. Kto chce grindowac Glebie, klika "Dalej". Kto chce zakonczenia, klika "Zlam Pieczec". Zero nakladania sie.

---

## 3. MODEL DANYCH

### 3.1 `src/game/region/region_data.gd` — DOPISANE pola (append na koncu, .tres-safe)
```gdscript
## Field law of EVERY duel in this biome (bosses stack their own rule on top).
## Born append-only: never renumber, only append.
enum Law { NONE, LIFE_TITHE, MIND_ARCHIVE, DEATH_HARVEST, CHAOS_KINDLING, NATURE_OVERGROWTH, SEAL_FIVE }

@export var seal_aspect: int = -1        ## Aspects.Id granted by beating this biome; -1 = no seal
@export var law: Law = Law.NONE          ## the biome's field law
@export var law_key: String = ""         ## locale key of the law (map header + combat chip)
@export var desc_key: String = ""        ## one-line identity, shown at the crossroads
@export var reward_aspect: int = -1      ## card offers / shop bias this Aspect into slot 0; -1 = off
@export var tier_index: int = -1         ## -1 = use the run's stage index; >=0 pins it (World/Sealed = 3)
@export var hidden: bool = false         ## never offered at a crossroads (the Sealed Biome)
```
**Uwaga append-only:** `seal_aspect` i `reward_aspect` sa `int` z sentinelem `-1`, a NIE `Aspects.Id`. Dzieki temu **enum `Aspects.Id` nie jest w ogole dotykany** — zadnego `NONE` do dopisania, zadnego ryzyka dla zapisanych .tres.

### 3.2 NOWY `src/game/region/journey_data.gd`
```gdscript
@tool
class_name JourneyData
extends Resource
## The whole journey as ONE editor-authorable resource: the five colour biomes, the finale and
## the hidden biome. Replaces the hardcoded JOURNEY path array in run.gd (editor-first rule).

@export var biomes: Array[RegionData] = []          ## exactly 5, ordered by Aspects.Id (LIFE..NATURE)
@export var finale: RegionData                      ## The World
@export var sealed_biome: RegionData                ## Arcanum Zero (5 seals)
@export var starting_pool: Array[ArcanumData] = []  ## run-opening draft (moved OFF RegionData)
@export var stages: int = 3                         ## biomes visited before the finale
```
Plik: `data/regions/journey.tres`. `RegionData.starting_pool` / `starting_arcanum` zostaja w schemacie jako legacy (append-only: nic nie usuwamy), ale `run.gd` czyta juz `journey.starting_pool`.

### 3.3 `src/game/combat/enemy_data.gd` — DOPISANE do `Rule` (11..17, append-only)
```gdscript
##  EMPEROR_WALL    - a wall: every play loses a FLAT 25 damage (small hands bounce off)
##  HERMIT_DARK     - one lamp: hand holds 5 cards, but +2 discards
##  DEATH_TITHE     - the tithe: the highest-ranked card of each play is destroyed after scoring
##  EMPRESS_BLOOM   - she grows: +40 max HP at the start of every one of her turns
##  TEMPERANCE_MIX  - mixture: single-Aspect play x0.5; three or more Aspects x1.5
##  WHEEL_TURN      - a FIXED cycle of rules, printed on screen four turns ahead
##  FOOL_MIRROR     - the Fool's hit = your last play / 14, clamped 8..34 (preview-live)
enum Rule { NONE, TOWER_IGNORES_BLOCK, DEVIL_BLOOD_TAX, MOON_CLEANSE, WORLD_ALL, CHARIOT_DOUBLE,
    STRENGTH_RESIST, HANGED_CAP, JUSTICE_RIPOSTE, JUDGEMENT_FRAIL, STAR_REGEN,
    EMPEROR_WALL, HERMIT_DARK, DEATH_TITHE, EMPRESS_BLOOM, TEMPERANCE_MIX, WHEEL_TURN, FOOL_MIRROR }
```
`WHEEL_TURN` wymaga refaktoru: **wszystkie porownania `enemy.rule == ...` w `combat_controller.gd` (12 miejsc: linie 82, 148, 154, 162, 309, 316, 333, 345, 348, 351, 418) zamieniamy na `active_rule() == ...`**:
```gdscript
const WHEEL_CYCLE: Array[int] = [Rule.TOWER_IGNORES_BLOCK, Rule.CHARIOT_DOUBLE, Rule.STRENGTH_RESIST, Rule.NONE]

## The rule in force on the CURRENT turn. Only the Wheel differs from the authored rule -- and its
## cycle is fixed and printed, so "the preview never lies" survives a boss made of fortune.
func active_rule() -> int:
    if enemy == null:
        return EnemyData.Rule.NONE
    if enemy.rule == EnemyData.Rule.WHEEL_TURN:
        return WHEEL_CYCLE[(turn - 1) % 4]
    return enemy.rule
```

### 3.4 `src/game/region/run_state.gd` — nowe pola
```gdscript
var journey: JourneyData                  ## this run's authored journey resource
var visited_biomes: Array = []            ## resource paths of biomes already entered this run
var run_seals: Array = []                 ## Aspects.Id ints sealed THIS run (map chip + spread)
var cross_offers: Array = []              ## resource paths offered at the pending crossroads
var pending_stage: int = -1               ## >=0: a crossroads is owed for that stage (resume point)
var sealed_entered: bool = false          ## this run stepped through the Seal (locks Beyond)
```
`begin()` zmienia sygnature na `begin(p_journey: JourneyData, p_seed: int = 0)`:
- `journey = p_journey`, `region = null`, `region_index = -1`, `visited_biomes = []`, `run_seals = []`, `cross_offers = []`, `pending_stage = 0`, `sealed_entered = false`
- fallback startowego arkanum: `if journey.starting_pool.is_empty() ... ` (juz nie z regionu)
- **rzut przeciwnikow (`fights`, `_roll_boss`) NIE dzieje sie w `begin()`** — dzieje sie w `enter_region()` przy pierwszym wyborze biomu. **To przesuwa strumien rng — kontrakt seeda: patrz sek. 6.**

Nowa metoda:
```gdscript
## Biomes still unvisited this run, in journey order (crossroads candidates).
func remaining_biomes() -> Array:
    var out: Array = []
    for b: RegionData in journey.biomes:
        if not b.hidden and not visited_biomes.has(b.resource_path):
            out.append(b)
    return out

## The tier this stage fights at: pinned by the region, else the stage index (0..3).
func tier() -> int:
    if region != null and region.tier_index >= 0:
        return region.tier_index
    return clampi(region_index, 0, 3)
```
`enter_region()` dopisuje `visited_biomes.append(p_region.resource_path)` gdy `p_region.seal_aspect >= 0`.

### 3.5 Zapis runu `user://run_save.cfg` — nowe klucze + STEMPEL FORMATU
```gdscript
cf.set_value("run", "format", 2)                       # <-- NOWE, pierwszy klucz
cf.set_value("run", "journey", journey.resource_path)
cf.set_value("run", "visited", visited_biomes)
cf.set_value("run", "run_seals", run_seals)
cf.set_value("run", "cross", cross_offers)
cf.set_value("run", "pending_stage", pending_stage)
cf.set_value("run", "sealed", sealed_entered)
```
`load_run()` — PIERWSZA linia po `cf.load(...) == OK`:
```gdscript
if int(cf.get_value("run", "format", 1)) < 2:
    delete_run_save()      # region_01..04 no longer exist: a v1 save cannot be resumed
    return "!stale"
```
`run.gd::_ready` traktuje `"!stale"` jak brak zapisu (startuje swiezy run). `menu.gd` dostaje `RunState.run_save_compatible() -> bool` (peek formatu) i wylacza "Kontynuuj" dla starych zapisow.

### 3.6 `src/game/meta/profile.gd` — PIECZECIE
```gdscript
const VERSION := 3                 ## v2 -> v3: seals ledger (no data conversion needed)
const SEAL_COUNT := 5

var seals: Array = []              ## Aspects.Id ints, append-only, kept sorted
var seal_veil: Dictionary = {}     ## str(aspect) -> highest Veil at which the seal was taken

func has_seal(aspect: int) -> bool:
    return seals.has(aspect)

func seal_count() -> int:
    return seals.size()

func seals_complete() -> bool:
    return seals.size() >= SEAL_COUNT

## Beating a biome's boss brands its colour into the profile FOREVER. Returns true when NEW.
func grant_seal(aspect: int, veil: int) -> bool:
    var key := str(aspect)
    var fresh := not seals.has(aspect)
    if fresh:
        seals.append(aspect)
        seals.sort()
    seal_veil[key] = maxi(int(seal_veil.get(key, 0)), veil)
    if fresh and seals.size() == 1:
        grant_achievement("ACH_SEAL_FIRST")
    if fresh and seals_complete():
        grant_achievement("ACH_PENTAGRAM")
    save_profile()
    changed.emit()
    return fresh
```
`save_profile()` +2 linie: `cf.set_value("meta","seals",seals)`, `cf.set_value("meta","seal_veil",seal_veil)`.
`load_profile()` +2 linie (po galezi `v < 2`): `seals = cf.get_value("meta","seals",[])`, `seal_veil = cf.get_value("meta","seal_veil",{})`.

**Migracja wersji:** jawna galaz NIE jest potrzebna. `ConfigFile.get_value` z domyslna wartoscia sprawia, ze plik v2 wczytuje sie jako v3 z pusta lista pieczeci; pierwszy `save_profile()` przestempluje go na 3. `VERSION` podnosimy tylko po to, zeby plik sam sie identyfikowal. **Istniejaca galaz `if v < 2` zostaje nietknieta** (robi refund i `return` — nie dotykamy, to dziala).

`ACH_ORDER` — dopisac NA KONCU (tablica jest kolejnoscia wyswietlania, append jest bezpieczny):
```gdscript
"ACH_SEAL_FIRST", "ACH_PENTAGRAM", "ACH_ZERO"
```
`ACH_ARCANA` — dopisac: `"fool": ["ACH_ZERO", "res://data/arcana/arcanum_fool.tres"]`.

---

## 4. SKALOWANIE TIEROWE (zastepuje reczne HP per region)

`src/game/combat/combat_controller.gd`:
```gdscript
## Stage tier scaling: one authored enemy serves every stage of the journey. Applied BEFORE the
## Veil-V boss bump and the Beyond-depth multiplier -- order is fixed and documented, because
## changing it silently rebalances every fight in the game.
const TIER_HP: Array[float]          = [1.00, 1.50, 2.10, 2.60]
const TIER_INTENT: Array[float]      = [1.00, 1.45, 1.95, 2.35]
const TIER_BOSS_HP: Array[float]     = [1.00, 1.30, 1.60, 2.00]
const TIER_BOSS_INTENT: Array[float] = [1.00, 1.10, 1.35, 1.60]
```
- elity uzywaja tabel BOSS (`is_boss or is_elite`)
- `enrage_step_effective = enemy.enrage_step + tier + (1 if veil >= 3) + depth`
- `reward_rtec_effective = enemy.reward_rtec + 2 * tier` (liczone w `run.gd::_on_combat_finished`)

**Weryfikacja wobec dzisiejszych liczb (dlatego te mnozniki, a nie inne):**
| | dzis R1 / R2 / R3 | baza x TIER |
|---|---|---|
| zwykly HP | 520 / 720 / 1040 | 520 → 520 / 780 / 1092 |
| zwykly intent | [10,13,8] / [14,17,10] / [20,23,15] | [10,13,8] → [14,18,11] / [19,25,15] |
| boss HP | 600 / 780 / 980 / 1300 | 620 → 620 / 806 / 992 / **1240** |
| boss intent | [15,20,13] / [16,20,14] / [20,25,17] | [15,20,13] → [16,22,14] / [20,27,17] |
| elita HP | 680 / 870 / 1200 | 680 → 680 / 884 / 1088 / 1360 |
Krzywa trudnosci **odtwarza dzisiejsza gre** — to nie jest rebalans, to jest ta sama drabina wyrazona formula.

---

## 5. PRAWA BIOMOW W SILNIKU (deterministyczne, preview-exact)

### 5.1 `src/game/combat/scoring.gd` — nowy krok 6b
W komentarzu pipeline'u dopisac: `6b. BIOME LAW (before relics: the law is the field, not a relic -- MAGNIFY never amplifies it)`.
`ctx` dostaje nowy klucz `"law"` (int, domyslnie `RegionData.Law.NONE`). Wstawka po kroku PRZECIAZENIE, przed petla reliktow:
```gdscript
# 6b. The biome's field law. Deterministic; every branch is visible in the preview.
match int(ctx.get("law", 0)):
    RegionData.Law.LIFE_TITHE:
        block += 2 * cards.size()
    RegionData.Law.DEATH_HARVEST:
        chips += 2 * grave
    RegionData.Law.CHAOS_KINDLING:
        if cards.size() >= 5:
            mult *= 1.5
        elif cards.size() <= 2:
            mult *= 0.75
    RegionData.Law.SEAL_FIVE:
        mult += float(aspect_counts.size())
```
`MIND_ARCHIVE` i `NATURE_OVERGROWTH` nie dotykaja scoringu — sa po stronie kontrolera.

### 5.2 `src/game/combat/combat_controller.gd`
```gdscript
var law: int = 0                   ## RegionData.Law in force this fight (the biome's field)
var hand_size: int = HAND_SIZE     ## HAND_SIZE unless a law/rule changes it
```
- `start(...)` dostaje dopisany parametr `p_law: int = 0` (i `p_tier: int = 0`) — **append na koncu listy**, obie wartosci domyslne, wiec `tests/test_combat.gd` i tryb standalone nadal dzialaja.
- w `start()`:
```gdscript
law = p_law
hand_size = HAND_SIZE
if law == RegionData.Law.MIND_ARCHIVE:
    hand_size = 9
if active_rule() == EnemyData.Rule.HERMIT_DARK:
    hand_size = 5
if law == RegionData.Law.LIFE_TITHE:
    heal_cap += 8
```
- `_refill()`: `while hand.size() < hand_size:`
- odrzuty (2 miejsca — linie 81 i 332):
```gdscript
discards_left = START_DISCARDS + _bonus_discards()
if law == RegionData.Law.MIND_ARCHIVE:
    discards_left += 1
if active_rule() == EnemyData.Rule.HERMIT_DARK:
    discards_left += 2
if active_rule() == EnemyData.Rule.HANGED_CAP:
    discards_left = mini(discards_left, 1)
```
- ramp NATURE, obok istniejacego bloku WZROST/KORZENIE (~linia 338):
```gdscript
for c in hand:
    if law == RegionData.Law.NATURE_OVERGROWTH:
        c.growth += 3          # the Overgrowth: what waits in hand thickens
```
- `_ctx()` dopisuje `"law": law`
- `effective_damage()` rozszerzyc o dwie nowe reguly (jedyne miejsce, gdzie boss dotyka obrazen):
```gdscript
func effective_damage(raw: int) -> int:
    var r := active_rule()
    if r == EnemyData.Rule.STRENGTH_RESIST:
        return ceili(raw * 0.8)
    if r == EnemyData.Rule.EMPEROR_WALL:
        return maxi(0, raw - 25)
    return raw
```
  (TEMPERANCE_MIX mnozy mult, wiec siedzi w `Scoring` obok praw — przekazac przez `ctx["rule"]`.)
- `EMPRESS_BLOOM` w `_enemy_turn()`: `enemy_max_hp += 40; enemy_hp += 40; message.emit("LOG_EMPRESS_BLOOM", [40])`
- `DEATH_TITHE` w `play()`: po podliczeniu wyznacz karte o najwyzszym `rank` (remis → pierwsza w kolejnosci zaznaczenia) i wrzuc ja do `destroyed_cards`. `combat.gd` maluje jej ramke `Color("b23a48")` **zanim** gracz kliknie Zagraj.
- `mirror_intent()` + wyjatek w `_intent_at` dla FOOL_MIRROR (sek. 2.3).

### 5.3 `src/game/combat/combat.gd`
- `setup(...)` dostaje dopisane na koncu `p_tier: int = 0, p_law: int = 0`; przekazuje do `controller.start(...)`.
- Nowy element UI: **chip prawa pola** obok portretu wroga — `PanelContainer` 1 linia, ramka w `region.accent`, tekst `tr(law_key)`, `custom_minimum_size = Vector2(0, 22)`, zakotwiczony pod paskiem HP wroga. Nie rusza budzetu przyciskow (zaden przycisk akcji sie nie przesuwa — regula bottom-anchored nienaruszona).
- FOOL_MIRROR: etykieta intentu zywa (sek. 2.3).
- WHEEL_TURN: pasek 4 nadchodzacych regul pod chipem prawa (tekst z `WHEEL_STEP_%d`).

---

## 6. KONTRAKT SEEDA — co sie zmienia i jak to trzymamy uczciwie

Kolejnosc pobran z `RunState.rng` po zmianie (**dopisywanie na koncu przeplywu, nigdy wstawianie w srodek** — zasada z naglowka `run_state.gd`):
1. `begin()`: `_shuffle(deck)` — **bez zmian, zostaje pierwszy**
2. `begin()`: **NIC wiecej** (znika `pick_offers` na `fight_pool_1/2` i `_roll_boss` — przenosza sie)
3. draft arkanum otwierajacy run — bez zmian
4. **NOWE: crossroads stage 0 → brak rzutu** (pelny wybor 5 biomow, zero rng)
5. `enter_region(biom)` → `pick_offers(fight_pool_1,1)`, `pick_offers(fight_pool_2,1)`, `_roll_boss()` — te same trzy pobrania co dzis, tylko przesuniete za wybor
6. **NOWE: crossroads stage 1/2 → `pick_offers(remaining_biomes(), 2)`** — jedno pobranie glownego rng (kontrakt `pick_offers`: dokladnie jedno, niezaleznie od rozmiaru puli)
7. reszta bez zmian

**Skutek: kody losu (fate codes) sprzed tej zmiany NIE odtworza sie.** To jest zmiana wersji tresci, nie bug. Do zrobienia: dopisac do `NEWRUN_SEED_HINT` numer wersji rozkladu albo zawrzec `Profile.VERSION` w kodzie losu — **rekomendacja: dopisac stala `const CONTENT_VERSION := 2` w `run_state.gd` i pokazac ja na ekranie rozkladu obok kodu** (`SPREAD_SEED_VER` = "Rozklad v%d"). Dzienny Los liczy sie od nowa od dnia wdrozenia — to normalne i uczciwe.

`pick_tiered_offers` dostaje dopisany parametr `aspect_bias: int = -1`; filtr aspektu dziala **wewnatrz `_pick_from_tier` na liscie kandydatow** i **nie zmienia liczby wywolan `sub.randf()` / `sub.randi_range()`** — dlatego bias regionalny nie przesuwa strumienia.

---

## 7. UI — nowe ekrany w `run.gd`

### 7.1 `_show_crossroads()` — ROZDROZE
Wywolywane przed kazdym biomem (stage 0/1/2). Ustawia `RunState.pending_stage`, wola `RunState.save_run()` (nowy punkt wznowienia).
- naglowek `_title(tr("CROSS_TITLE"))`
- podpis: `CROSS_HINT_FIRST` dla stage 0, `CROSS_HINT` dla 1/2
- **licznik pieczeci** `SEAL_COUNT` % `Profile.seal_count()` + rzad 5 sygnetow (te same widgety co w menu)
- rzad paneli-kandydatow (`HBoxContainer`, `separation = 28`), kazdy panel `custom_minimum_size = Vector2(240, 300)`:
  - pasek koloru u gory: `ColorRect` 240x6 w `accent`
  - nazwa biomu `tr(name_key)`, 20px
  - `tr(desc_key)`, 12px, autowrap, szerokosc 220
  - `tr(law_key)`, 13px, kolor `accent`, autowrap — **prawo pola jest widoczne PRZED wyborem**
  - `CROSS_BOSSES % <nazwy 3 bossow rozdzielone " / ">`
  - chip: `CROSS_SEAL_NEW` (zielony) gdy `not Profile.has_seal(seal_aspect)`, inaczej `CROSS_SEALED_OWNED` (szary)
- na stage 0: **5 kandydatow, posortowanych tak, ze niezapieczetowane ida pierwsze** (gracz poluje na brakujacy kolor)
- na stage 1/2: `RunState.pick_offers(RunState.remaining_biomes(), 2)`, zapisane w `RunState.cross_offers`
- przycisk `CROSS_ENTER % nazwa` **jako OSTATNI element `_screen_column()`** (identyczny wzorzec jak `_show_boss_choice` — regula "przyciski akcji tylko na dole" utrzymana), `disabled` do momentu wyboru panelu

### 7.2 `_show_seal()` — CEREMONIA PIECZECI
Po `_take_claim()` (odbior Arkanum bossa), przed `_show_complete()`, tylko gdy `region.seal_aspect >= 0`:
- `var fresh := Profile.grant_seal(region.seal_aspect, RunState.veil)`; `RunState.run_seals.append(region.seal_aspect)`
- wielki sygnet: `PanelContainer` 160x160, `bg = Aspects.color(aspect).darkened(0.75)`, ramka 4px w `Aspects.color(aspect)`; w srodku symbol suitu z tego samego zrodla, co nowe symbole na kartach (**zaleznosc od zadania "karty maja miec widoczne kolory i symbole" — uzyc TEJ SAMEJ funkcji rysujacej glif, zero drugiego systemu**)
- `SEAL_TITLE % tr(Aspects.name_key(aspect))`, 30px, w kolorze aspektu
- `SEAL_COUNT % Profile.seal_count()`
- **DRAFT KOLORU:** `SEAL_DRAFT` + 3 karty tego aspektu do wyboru 1 — `RunState.pick_tiered_offers(DeckLibrary.full_reward_pool(), 3, false, region.seal_aspect)`, reuzycie istniejacego widgetu z `_show_reward()`
  - **To jest mechaniczna nagroda za pieczec W RUNIE**: talia gestnieje w jednym kolorze → **kolory (flush) staja sie osiagalne**. Bezposrednia odpowiedz na "udawalo mi sie robic tylko pary".
- przycisk na dole → `_show_complete(claimed)`

### 7.3 `_show_world_gate()` — trzeci przycisk
```gdscript
if Profile.seals_complete() and RunState.depth == 0 and not RunState.sealed_entered:
    var seal_btn := _button(tr("GATE_SEAL"), _enter_sealed)
    seal_btn.custom_minimum_size = Vector2(200, 40)
    seal_btn.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
    ctrls.add_child(seal_btn)
    root.add_child(_hint(tr("GATE_SEAL_HINT")))
```
```gdscript
func _enter_sealed() -> void:
    RunState.sealed_entered = true
    _pending_omen = null
    _last_rest = RunState.enter_region(_journey.sealed_biome, 3)
    _refresh_backdrop()
    _show_map()
```

### 7.4 `_show_complete()` — koniec etapu
`var final := RunState.region_index >= 3` (zamiast `region_index + 1 >= JOURNEY.size()`).
- `region == _journey.finale` → `_show_world_gate()` (bez zmian)
- `region == _journey.sealed_biome` → `_show_sealed_end()`
- inaczej → przycisk `COMPLETE_NEXT` → `_continue_journey()` → `_show_crossroads()` dla stage `region_index + 1`, a przy stage 3 wprost `RunState.enter_region(_journey.finale, 3)`

### 7.5 `menu.gd` — PLAKIETKA PIECZECI
Pod tagline'em, nad przyciskami (`col.add_child(...)` przed pierwszym `_menu_btn`):
- `HBoxContainer`, `alignment = CENTER`, `separation = 10`
- 5 paneli 34x34 w kolejnosci `Aspects.Id`: wypelnione `Aspects.color(id)` gdy `Profile.has_seal(id)`, inaczej `bg = Color(0.10,0.10,0.13)` + ramka `Aspects.color(id).darkened(0.6)`, `modulate.a = 0.45`
- tooltip: `SEAL_TAKEN % [tr(nazwa aspektu), veil]` albo `SEAL_NONE % tr(nazwa aspektu)`
- pod rzedem: `SEAL_PLAQUE` % — gdy `seals_complete()` cala plakietka dostaje zlota ramke i podpis `SEAL_PLAQUE_FULL`
Dodatkowo w Kolekcji nowa sekcja `COLLECTION_SEALS` — kodeks 5 biomow: nazwa, prawo pola, 3 bossy, stan pieczeci. Wylacznie tresc mechaniczna, zero wypelniaczy.

---

## 8. KLUCZE LOKALIZACJI (`data/locale/ui.csv`, kolumny keys,en,pl)

**USUNAC:** `REGION_01`, `REGION_02`, `REGION_03`, `REGION_04` (regiony przestaja istniec).
**DOPISAC** (parzystosc `%` sprawdzona — po jednym `%s`/`%d` w obu kolumnach tam, gdzie wystepuje):

```
BIOME_LIFE,The Orchard of Cups,Sad Kielichów
BIOME_MIND,The Library of Swords,Biblioteka Mieczy
BIOME_DEATH,The Catacombs of Pentacles,Katakumby Pentakli
BIOME_CHAOS,The Burnt Field of Wands,Pogorzelisko Buław
BIOME_NATURE,The Overgrowth,Przerost
BIOME_WORLD,The World,Świat
BIOME_SEALED,The Sealed Biome — Arcanum Zero,Biom Zapieczętowany — Arkanum Zero
BIOME_LIFE_DESC,High HP, low steady blows. Nothing here kills fast — nothing here dies fast.,Dużo HP, niskie równe ciosy. Nic tu nie zabija szybko — nic tu szybko nie ginie.
BIOME_MIND_DESC,"Fragile foes, twin spikes. The widest hand in the game.","Kruchi wrogowie, dwa szczyty. Najszersza ręka w grze."
BIOME_DEATH_DESC,Grinding foes and a rising enrage clock. The used pile is the weapon.,Mielący wrogowie i rosnący zegar szału. Bronią jest stos zużytych.
BIOME_CHAOS_DESC,Burst and rest. One turn to breathe, one turn to burn.,Wybuch i oddech. Jedna tura na przygotowanie, jedna na spalenie.
BIOME_NATURE_DESC,Slow foes that escalate. What waits in your hand thickens.,Powolni wrogowie, którzy narastają. To, co czeka na ręce, tyje.
BIOME_SEALED_DESC,Four Aces and the card numbered zero.,Cztery Asy i karta o numerze zero.
LAW_LIFE,Law of the Tithe: +2 block per card played; the heal pool here is +8.,Prawo Dziesięciny: +2 bloku za każdą zagraną kartę; zapas leczenia jest tu większy o 8.
LAW_MIND,Law of the Archive: your hand holds 9 cards and you get one more discard each turn.,Prawo Archiwum: trzymasz 9 kart na ręce i masz o jeden odrzut więcej co turę.
LAW_DEATH,Law of the Harvest: every card in the used pile adds +2 chips to each play.,Prawo Żniwa: każda karta w stosie zużytych dodaje +2 żetony do każdego zagrania.
LAW_CHAOS,Law of the Kindling: a 5-card play scores x1.5 Mult; a play of 1-2 cards scores x0.75.,Prawo Podpałki: zagranie 5 kart daje x1.5 mnożnika; zagranie 1-2 kart daje x0.75.
LAW_NATURE,Law of the Overgrowth: every card left in hand gains +3 chips at the end of each turn.,Prawo Rozrostu: każda karta zostawiona na ręce zyskuje +3 żetony na koniec tury.
LAW_SEAL,Law of Five Seals: +1.0 Mult for every distinct Aspect in the play.,Prawo Pięciu Pieczęci: +1.0 mnożnika za każdy odmienny Aspekt w zagraniu.
RULE_EMPEROR,The Emperor is a wall: every play loses a flat 25 damage.,Cesarz jest murem: każde zagranie traci 25 obrażeń.
RULE_HERMIT,"One lamp: your hand holds 5 cards, but you get +2 discards.","Jedna lampa: trzymasz 5 kart na ręce, ale masz +2 odrzuty."
RULE_DEATH,The tithe: the highest-ranked card of every play is destroyed after it scores.,Dziesięcina: najwyższa karta każdego zagrania ginie po podliczeniu.
RULE_EMPRESS,She grows: +40 max HP at the start of every one of her turns.,Rośnie: +40 maks. HP na początku każdej swojej tury.
RULE_TEMPERANCE,Mixture: a single-Aspect play scores x0.5; three or more Aspects score x1.5.,Mieszanina: zagranie w jednym Aspekcie daje x0.5; trzy lub więcej Aspektów daje x1.5.
RULE_WHEEL,The wheel turns on a fixed cycle: block ignored / double strike / 20% resistance / rest.,Koło obraca się stałym cyklem: blok ignorowany / podwójny cios / 20% odporności / spokój.
RULE_FOOL,The Fool answers with your own blow: its hit is your play divided by 14 (8-34).,Głupiec odpowiada twoim ciosem: jego uderzenie to twoje zagranie podzielone przez 14 (8-34).
CROSS_TITLE,Choose the colour,Wybierz kolor
CROSS_HINT_FIRST,The first road is yours to name.,Pierwszą drogę wybierasz sam.
CROSS_HINT,The road forks. Two colours answer.,Droga się rozwidla. Odpowiadają dwa kolory.
CROSS_ENTER,Enter %s,Wejdź: %s
CROSS_SEAL_NEW,New seal,Nowa pieczęć
CROSS_SEALED_OWNED,Seal already taken,Pieczęć już zdobyta
CROSS_BOSSES,Guarded by: %s,Strzeżony przez: %s
SEAL_TITLE,%s SEALED,PIECZĘĆ: %s
SEAL_DRAFT,The colour comes with you — take one card.,Kolor idzie z tobą — weź jedną kartę.
SEAL_COUNT,Seals: %d/5,Pieczęcie: %d/5
SEAL_PLAQUE,Seals,Pieczęcie
SEAL_PLAQUE_FULL,The pentagram is closed. The Seal answers at the end of a Journey.,Pentagram zamknięty. Pieczęć odpowiada na końcu Podróży.
SEAL_NONE,%s — not sealed,%s — bez pieczęci
SEAL_TAKEN,%s — sealed at Veil %d,%s — zapieczętowany na Zasłonie %d
GATE_SEAL,Break the Seal — Arcanum Zero,Złam Pieczęć — Arkanum Zero
GATE_SEAL_HINT,Three duels past the World. The Fool waits and answers with your own blow.,Trzy pojedynki za Światem. Głupiec czeka i odpowiada twoim własnym ciosem.
SEALED_END,ARCANUM ZERO,ARKANUM ZERO
SEALED_END_LINE,The Fool falls into the Fool. The reading is closed.,Głupiec upada w Głupca. Odczytanie domknięte.
SEALED_END_AGAIN,The Seal answers again.,Pieczęć odpowiada ponownie.
COLLECTION_SEALS,Seals and biomes,Pieczęcie i biomy
LOG_EMPRESS_BLOOM,The Empress grows: +%d HP,Cesarzowa rośnie: +%d HP
LOG_DEATH_TITHE,The tithe takes %s,Dziesięcina zabiera %s
WHEEL_STEP_0,block ignored,blok ignorowany
WHEEL_STEP_1,double strike,podwójny cios
WHEEL_STEP_2,20% resistance,20% odporności
WHEEL_STEP_3,rest,spokój
SPREAD_SEED_VER,Spread v%d,Rozkład v%d
ACH_SEAL_FIRST,First Seal,Pierwsza Pieczęć
ACH_SEAL_FIRST_DESC,Beat the boss of any biome and take its colour.,Pokonaj bossa dowolnego biomu i zabierz jego kolor.
ACH_PENTAGRAM,The Closed Pentagram,Zamknięty Pentagram
ACH_PENTAGRAM_DESC,Hold all five seals at once.,Miej naraz wszystkie pięć pieczęci.
ACH_PENTAGRAM_REWARD,The Sealed Biome opens at the World's gate.,Biom Zapieczętowany otwiera się przy bramie Świata.
ACH_ZERO,Arcanum Zero,Arkanum Zero
ACH_ZERO_DESC,Break the Seal and fell The Fool.,Złam Pieczęć i powal Głupca.
ACH_ZERO_REWARD,The Fool joins the opening draft.,Głupiec dołącza do draftu otwierającego.
ARCANUM_GLUPCA,Arcanum of the Fool,Arkanum Głupca
ARCANUM_UMIARKOWANIA,Arcanum of Temperance,Arkanum Umiarkowania
ARCANUM_KOLA,Arcanum of the Wheel,Arkanum Koła
ENEMY_GLUPIEC,The Fool,Głupiec
ENEMY_CESARZ,The Emperor,Cesarz
ENEMY_PUSTELNIK,The Hermit,Pustelnik
ENEMY_SMIERC,Death,Śmierć
ENEMY_CESARZOWA,The Empress,Cesarzowa
ENEMY_UMIARKOWANIE,Temperance,Umiarkowanie
ENEMY_KOLO,The Wheel of Fortune,Koło Fortuny
ENEMY_LIFE_A,"Page of Cups, Novice of the Spring","Paź Kielichów, Nowicjusz Źródła"
ENEMY_LIFE_B,"Knight of Cups, Bearer of the Draught","Rycerz Kielichów, Niosący Napar"
ENEMY_LIFE_C,"Queen of Cups, Keeper of the Still Water","Królowa Kielichów, Strażniczka Cichej Wody"
ENEMY_LIFE_D,"King of Cups, the Unmoved","Król Kielichów, Niewzruszony"
ENEMY_LIFE_E,"Nine of Cups, the Granted Wish","Dziewiątka Kielichów, Spełnione Życzenie"
ENEMY_MIND_A,"Page of Swords, the Eavesdropper","Paź Mieczy, Podsłuchujący"
ENEMY_MIND_B,"Knight of Swords, the Headlong","Rycerz Mieczy, Na Oślep"
ENEMY_MIND_C,"Queen of Swords, the Severed Verdict","Królowa Mieczy, Odcięty Wyrok"
ENEMY_MIND_D,"King of Swords, the Cold Verdict","Król Mieczy, Zimny Wyrok"
ENEMY_MIND_E,"Nine of Swords, the Sleepless","Dziewiątka Mieczy, Bezsenność"
ENEMY_DEATH_A,"Page of Pentacles, Rotting Cultist","Paź Pentakli, Gnijący Kultysta"
ENEMY_DEATH_B,"Knight of Pentacles, Clad in Ash","Rycerz Pentakli, Zakuty w Popiół"
ENEMY_DEATH_C,"Queen of Pentacles, Barren Regent","Królowa Pentakli, Jałowa Regentka"
ENEMY_DEATH_D,"King of Pentacles, Frost Titan","Król Pentakli, Tytan Mrozu"
ENEMY_DEATH_E,"Nine of Pentacles, the Walled Garden","Dziewiątka Pentakli, Ogród za Murem"
ENEMY_CHAOS_A,"Page of Wands, Ash Witch","Paź Buław, Popielna Wiedźma"
ENEMY_CHAOS_B,"Knight of Wands, the Running Fire","Rycerz Buław, Biegnący Ogień"
ENEMY_CHAOS_C,"Queen of Wands, the Pyre Queen","Królowa Buław, Pani Stosu"
ENEMY_CHAOS_D,"King of Wands, Herald of the End","Król Buław, Herold Końca"
ENEMY_CHAOS_E,"Nine of Wands, the Last Guard","Dziewiątka Buław, Ostatnia Warta"
ENEMY_NATURE_A,"Ten of Cups, the Whole Household","Dziesiątka Kielichów, Cały Dom"
ENEMY_NATURE_B,"Ten of Swords, the Field of Stakes","Dziesiątka Mieczy, Pole Pali"
ENEMY_NATURE_C,"Ten of Wands, Cinder Chimera","Dziesiątka Buław, Żużlowa Chimera"
ENEMY_NATURE_D,"Ten of Pentacles, Cinder Golem","Dziesiątka Pentakli, Żużlowy Golem"
ENEMY_NATURE_E,"Seven of Pentacles, the Patient Gardener","Siódemka Pentakli, Cierpliwy Ogrodnik"
ENEMY_ACE_CUPS,"Ace of Cups, the First Seal","As Kielichów, Pierwsza Pieczęć"
ENEMY_ACE_SWORDS,"Ace of Swords, the Second Seal","As Mieczy, Druga Pieczęć"
ENEMY_ACE_WANDS,"Ace of Wands, the Third Seal","As Buław, Trzecia Pieczęć"
ENEMY_ACE_PENTS,"Ace of Pentacles, the Fourth Seal","As Pentakli, Czwarta Pieczęć"
```
Uwaga: wiersze z przecinkiem w wartosci MUSZA byc w cudzyslowach (dotyczy wszystkich ENEMY_* i kilku *_DESC). `BIOME_LIFE_DESC` w EN ma przecinek — **wziac w cudzyslow**.

---

## 9. KOLEJNOSC IMPLEMENTACJI

**B0** `docs/specs/spec_biomes.md` — ten dokument do repo. Commit osobno.
**B1** Schemat danych, zero zachowania: `region_data.gd` (+enum `Law`, +6 `@export`), nowy `journey_data.gd`, `enemy_data.gd` (`Rule` 11..17). `godot --headless --import`, projekt startuje.
**B2** `tools/gen/gen_content.gd`: `_region()` → `_biomes()`. Wygenerowac 29 wrogow (25 biomowych + 4 Asy), 6 nowych bossow + `boss_fool`, 3 nowe arkana, 7 plikow regionow, `journey.tres`. **Skasowac** `data/regions/region_01..04.tres` (+ `.uid`) i osierocone `data/combat/enemy_[ab]*.tres`, `enemy_r2*`, `enemy_r3*`, `enemy_elite_r*`. Import.
**B3** `data/locale/ui.csv`: usuniecie 4 kluczy, dopisanie ~90. Skrypt pythonowy sprawdzajacy parzystosc `%` miedzy `en` i `pl` na CALYM pliku (pulapka z CLAUDE.md — Godot nie zglasza bledu, tylko oddaje szablon).
**B4** Silnik walki: tabele TIER, `law`/`hand_size`, `active_rule()` (12 podmian), 7 nowych regul, `mirror_intent()`, krok 6b w `scoring.gd`, `ctx["law"]`/`ctx["rule"]`. Dopisane parametry `setup(..., p_tier, p_law)`. Aktualizacja `tests/test_combat.gd` + `tests/test_scoring.gd` (nowe przypadki: kazde prawo osobno, FOOL_MIRROR na 3 wartosciach zagrania, WHEEL_TURN na 5 turach).
**B5** `profile.gd`: VERSION 3, `seals`, `seal_veil`, `grant_seal`, 3 osiagniecia, `ACH_ARCANA["fool"]`.
**B6** `run.gd`: `JourneyData`, `_show_crossroads`, `_show_seal`, `_enter_sealed`, `_show_sealed_end`, przepiecie `_show_complete`/`_continue_journey`, `format = 2` w zapisie, wznowienie z `pending_stage`.
**B7** `menu.gd`: plakietka pieczeci, sekcja `COLLECTION_SEALS`, `run_save_compatible()` na przycisku Kontynuuj.
**B8** Test: `tools/dev/run_hidden.sh` + `--peek`, przejscie pelnego runu botem (`TEST_PROFILE=biomes`), zrzuty rozdroza / ceremonii pieczeci / bramy z 3 przyciskami / walki z Glupcem — **obejrzec zrzuty, nie zakladac**.

Kazda faza to osobny commit; B1-B3 sa czysto danymi i mozna je wypuscic przed B4.

## RISKS

RYZYKA I PULAPKI (konkretnie, z miejscami w kodzie):

1. ZAPISY RUNU. Skasowanie region_01..04.tres wysadza kazdy istniejacy user://run_save.cfg — `load_run()` robi `region = load("res://data/regions/region_01.tres")` → null → crash na `region.fight_pool_1`. MITYGACJA: stempel `format = 2` sprawdzany PIERWSZA linia w load_run + `run_save_compatible()` na przycisku Kontynuuj w menu.gd. Bez tego = 100% crash u kazdego gracza z zapisem.

2. KONTRAKT SEEDA PEKA. Przeniesienie `pick_offers(fight_pool)` i `_roll_boss()` z `begin()` do `enter_region()` przesuwa strumien rng — stare kody losu i Dzienne Losy sprzed wdrozenia NIE odtworza sie. To zmiana wersji tresci, nie bug, ale MUSI byc widoczna: `RunState.CONTENT_VERSION = 2` pokazane na ekranie rozkladu (`SPREAD_SEED_VER`). Inaczej gracze zglosza "kod losu klamie" — w grze o tytule "Karty nie klamia" to najgorszy mozliwy bug wizerunkowy.

3. active_rule() — 12 PODMIAN, LATWO PRZEOCZYC JEDNA. Miejsca w combat_controller.gd: 82, 148, 154, 162, 309, 316, 333, 345, 348, 351, 418 + `_rule_ignores_block/_rule_blood_tax/_rule_cleanses_rot`. Pominiete miejsce = Kolo Fortuny dziala tylko czesciowo i podglad zaczyna klamac. Weryfikacja: `grep -n "enemy.rule ==" src/game/combat/` musi zwrocic ZERO trafien poza samym `active_rule()`.

4. FOOL_MIRROR vs kontrakt podgladu. Jesli etykieta intentu nie bedzie sie odswiezac przy zaznaczaniu kart, gra bedzie klamac o nadchodzacym ciosie — to zlamanie glownej zasady projektu. Wymaga sygnalu z warstwy preview do etykiety intentu w combat.gd; przetestowac osobno przypadek "zaznaczam, odznaczam, zagrywam".

5. SKALOWANIE TIEROWE = GLOBALNY REBALANS UKRYTY POD REFAKTOREM. Kolejnosc mnozen (tier → Veil V → depth) jest arbitralna, ale musi byc ZAPISANA w komentarzu i w tescie, bo zamiana kolejnosci cicho przestraja cala gre. Test: `test_combat.gd` sprawdza dokladne HP dla (tier=2, veil=5, depth=1) na jednym bossie.

6. DEATH_TITHE niszczy karty z talii runu. `destroyed_cards` juz istnieje (szklane karty), ale przy 6-8 zagraniach boss zjada 6-8 kart — przy talii 20 kart to polowa. Trzeba dac limit: max 5 zniszczen na walke, potem regula przestaje dzialac (i chip prawa to pokazuje). Bez limitu ta walka jest niewygrywalna dla cienkiej talii.

7. PRAWO NATURE (+3 growth/ture) mnozy sie ze slowem kluczowym WZROST na tej samej karcie i z `enter_region()` — `growth` jest polem RUNTIME kart w talii runu, a `load_run()` go NIE zapisuje ("deck growth is intentionally transient"). Karty przenosza growth miedzy walkami w tym samym biomie? Trzeba jawnie zerowac `growth` w `CombatController.start()` dla kazdej karty z talii, inaczej biom NATURE snieguje przez caly run.

8. MIND_ARCHIVE (reka 9) vs budzet layoutu 1280x720. Reka to `hand_fan.gd`, karty 80x112, hover 1.45x. 9 kart zamiast 8 = +80px szerokosci przed zachodzeniem. Sprawdzic na zrzucie, ewentualnie zmniejszyc `separation` w wachlarzu tylko dla 9 kart. Gracz JUZ narzeka, ze karty sa za male — nie wolno ich zmniejszyc, trzeba mocniej zachodzic.

9. TEMPERANCE_MIX x0.5 za mono-kolor wprost karze budowanie na flush, czyli glowna sciezke mocy. Jesli wypadnie jako boss w biomie NATURE u gracza z talia mono-NATURE, run konczy sie sciana. MITYGACJA: rotacja bossow jest widoczna na mapie (`_node_chip` juz pokazuje tooltip z rule_key) — ale przy rozdrozu gracz widzi TRZECH mozliwych bossow, a nie wylosowanego. Rozwazyc pokazanie WYLOSOWANEGO bossa juz na rozdrozu (rzut i tak juz padl w `enter_region`), zeby wybor biomu byl w pelni poinformowany.

10. INFLACJA TALII. +1 karta za kazda pieczec (3/run) + nagrody + sklep = talia ~28-30 kart pod koniec runu vs 25 dzis. Kazda karta wiecej rozcienicza szanse na kolor. To jest zamierzone (draft pieczeci jest MONOKOLOROWY, wiec gestnieje wlasnie kolor), ale wymaga sprawdzenia w tescie: symulacja 1000 rak z talii po 3 pieczeciach — odsetek rak z 5 kartami jednego aspektu musi wzrosnac, nie spasc.

11. ZALEZNOSC OD DRUGIEGO ZADANIA. Sygnet pieczeci i symbol koloru na karcie MUSZA uzywac tej samej funkcji rysujacej glif suitu. Jesli powstana dwa niezalezne systemy symboli, gra bedzie miala dwa jezyki wizualne dla tej samej rzeczy. Uzgodnic API (np. `Aspects.glyph(id) -> String` albo `Aspects.sigil(id) -> Texture2D`) PRZED faza B6/B7.

12. Godot nie zglasza bledu parzystosci `%` w tlumaczeniach — oddaje szablon bez zmian. ~90 nowych wierszy CSV to najwiekszy jednorazowy zastrzyk tekstu w historii projektu. Bez skryptu walidujacego (faza B3) na pewno wjedzie co najmniej jeden zly wiersz.

## FILES

- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/region/region_data.gd
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/region/journey_data.gd
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/region/run.gd
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/region/run_state.gd
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/meta/profile.gd
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/menu/menu.gd
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/combat/enemy_data.gd
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/combat/combat_controller.gd
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/combat/combat.gd
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/combat/scoring.gd
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/cards/aspects.gd
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/tools/gen/gen_content.gd
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/data/locale/ui.csv
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/data/regions/journey.tres
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/data/regions/biome_life.tres
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/data/regions/biome_mind.tres
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/data/regions/biome_death.tres
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/data/regions/biome_chaos.tres
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/data/regions/biome_nature.tres
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/data/regions/region_world.tres
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/data/regions/region_sealed.tres
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/data/regions/region_01.tres
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/data/regions/region_02.tres
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/data/regions/region_03.tres
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/data/regions/region_04.tres
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/tests/test_combat.gd
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/tests/test_scoring.gd
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/docs/specs/spec_biomes.md

