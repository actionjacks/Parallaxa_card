# Parallaxa_card — Plan UI/UX: architektura zasobow, roadmapa, drzewa scen

Odpowiedz na brief z `todo.md` (reorganizacja UI/UX, architektury i meta-progresji).
Dokument oparty o FAKTYCZNY stan kodu (stan: 2026-07-27). Trzy czesci, zgodnie z briefem:
1) analiza architektoniczna, 2) roadmapa wdrozenia, 3) struktura drzew scen.

Przeczytane zrodla: `src/game/cards/{card_data,card_widget,aspects,deck_data}.gd`,
`src/game/combat/{combat,combat_controller,scoring,poker,enemy_data,deck_library}.gd`,
`src/game/region/{run,run_state,region_data}.gd`, `src/game/arcana/arcanum_data.gd`,
`src/autoload/save_manager.gd`, `tools/gen/gen_content.gd`, `docs/{DESIGN,ROADMAP}.md`.

---

## 1. ANALIZA ARCHITEKTONICZNA

### 1.1 Co JUZ jest na Custom Resources (wbrew tezie briefu — fundament stoi)

Brief zaklada, ze "wiekszosc elementow generowana jest hardcodem". To nieaktualne dla DANYCH:
cala tresc gry to `Resource` + pliki `.tres` edytowalne w Inspektorze. Hardcode zostal w UI
i w kilku wyliczonych nizej miejscach logiki przeplywu.

| Klasa (`class_name`) | Plik | Pola `@export` | Instancje `.tres` |
|---|---|---|---|
| `CardData` | `src/game/cards/card_data.gd` | `rank, aspect, keyword, keyword_value, edition` | `data/cards/s_00..s_15.tres` (starter), `p_00..p_35.tres` (pula nagrod) |
| `DeckData` | `src/game/cards/deck_data.gd` | `name_key, cards: Array[CardData]` | `data/decks/starter.tres`, `reward_pool.tres` |
| `EnemyData` | `src/game/combat/enemy_data.gd` | `name_key, max_hp, intents, enrage_step, reward_rtec, is_boss, rule, rule_key, art` | `data/combat/*.tres` (14 wrogow + 4 bossy) |
| `ArcanumData` | `src/game/arcana/arcanum_data.gd` | `name_key, effect, effect_aspect, effect_mult, effect_value, art` + metoda `describe()` | `data/arcana/*.tres` (9 szt.) |
| `RegionData` | `src/game/region/region_data.gd` | `name_key, fights (legacy), fight_pool_1, fight_pool_2, boss, boss_arcanum, starting_arcanum (legacy), starting_pool` | `data/regions/region_01..04.tres` |

Wszystkie klasy danych sa `@tool` + `extends Resource`, wiec Inspektor pokazuje pola na zywo.
Generator `tools/gen/gen_content.gd` (uruchamiany headless: `godot --headless -s
res://tools/gen/gen_content.gd`) zapisuje powyzsze `.tres` — sa to zasoby "editor-first":
po wygenerowaniu MOZNA je recznie stroic w Inspektorze i to jest zamierzony workflow.
`DeckLibrary` (`src/game/combat/deck_library.gd`) laduje talie z `.tres` i robi `duplicate()`
kazdej karty, zeby edycje (Foil/Holo) w runie nigdy nie mutowaly wspolnego pliku.

### 1.2 Co pozostaje hardcoded (realna lista luk)

| Element | Miejsce | Uwaga |
|---|---|---|
| Omeny (5 szt.) | `run.gd` — `const OMENS` + `_accept_omen()` (match po `id`) | Jedyna TRESC poza `.tres`; ma juz TODO(editor-first) w kodzie |
| Cale UI walki | `combat.gd::_build_ui()` (~130 linii budowania wezlow) | `combat.tscn` to pusty root Control ze skryptem |
| Ekrany runu (mapa/nagroda/sklep/draft/omen) | `run.gd` (~790 linii, ekrany budowane w `_show_*`) | `run.tscn` rowniez pusty root |
| Widok karty | `CardWidget.build()/build_preview()` — statyczne fabryki | Wspolny wyglad, ale zero prefabu |
| Tlo ekranow | `Backdrop.build()` (`src/game/ui/backdrop.gd`) | Celowo bez assetow |
| Ceny sklepu | `run.gd`: `BUY_COST=5, THIN_COST=3, ENCHANT_COST=5, STAR_COST=7` | Kandydat na `ShopConfig` Resource lub @export |
| Parametry walki | `combat_controller.gd`: `HAND_SIZE=8, START_DISCARDS=3, PLAYER_MAX_HP=50` | jw. |
| Tabele pokera | `poker.gd`: `BASE`, `LEVEL_UP` | Akceptowalne — to silnik, nie tresc |
| Efekty keywordow | `scoring.gd` (match po `CardData.Keyword`) | Akceptowalne — kod efektow musi byc kodem; tresc (ktora karta ma jaki keyword) juz jest w `.tres` |
| Sciezki JOURNEY (4 regiony) | `run.gd`: `const JOURNEY` | Kandydat na `JourneyData` Resource |
| Dzwieki | `Sfx.play(&"hit")` itd. rozsiane po `combat.gd`/`run.gd` | Brak pol sfx na zasobach |
| Art kart Malych Arkanow | konwencja nazwy pliku w `CardWidget.minor_art()` (`MINOR_SUIT` + rank -> `assets/cards/minor/%s_%02d.jpg`) | Dziala, ale karta nie moze miec wlasnej ilustracji poza konwencja |

Braki systemowe (nie hardcode, po prostu brak): zapis runu (`SaveManager` z autoloadow jest
kompletny — slotowy JSON, zapis atomowy, grupa `persistent` z `save_data()/load_data()` — ale
`RunState` NIE jest podpiety), profil/meta miedzy runami, ESC-pauza, TAB-przeglad, menu glowne
(`run.tscn` jest main scene w `project.godot`; `src/main/main.tscn` to pusty boot), kolekcja,
drag&drop (jest klik-select), RMB-inspekcja (jest hover-preview w stalym miejscu `(1016,118)`).

### 1.3 Przyklad realny: klasa CardData + edycja karty w Inspektorze

Faktyczny kod (`src/game/cards/card_data.gd`, skrot):

```gdscript
@tool
class_name CardData
extends Resource

enum Keyword { NONE, OSLONA, OPATRZNOSC, GNICIE, ZNIWO, FURIA, SPALENIE, ECHO,
               BUJNOSC, WZROST, SYMBIOZA, PIJAWKA, KLATWA }
enum Edition { NONE, FOIL, HOLO, POLYCHROME }

@export var rank: int = 2                  ## 1 = As, 2..10, 11 Paz, 12 Rycerz, 13 Krolowa, 14 Krol
@export var aspect: Aspects.Id = Aspects.Id.LIFE
@export var keyword: Keyword = Keyword.NONE
@export var keyword_value: int = 0         ## sila efektu, np. Gnicie X / Oslona X
@export var edition: Edition = Edition.NONE

var growth: int = 0   ## celowo NIE-@export: stan runtime keyworda WZROST
```

Instrukcja dla designera (bez dotykania kodu):
1. FileSystem -> `data/cards/` -> PPM -> **Create New -> Resource** -> wybierz `CardData`
   (albo otworz istniejacy `s_XX.tres` / `p_XX.tres`).
2. W Inspektorze ustaw pola: `rank` (1..14), `aspect` (dropdown 5 Aspektow), `keyword`
   (dropdown), `keyword_value` (liczba), opcjonalnie `edition`. Zapisz (Ctrl+S).
3. Otworz `data/decks/starter.tres` (lub `reward_pool.tres`) — to `DeckData`. W polu
   `cards` (Array[CardData]) kliknij **Add Element** i przeciagnij swoj `.tres` z FileSystem
   (albo wybierz Quick Load). Zapisz.
4. Uruchom gre — `DeckLibrary.starter_deck()` czyta talie z tego pliku; karta pojawi sie
   w rece. Nazwy/opisy keywordow ida z `data/locale/ui.csv` (klucze `KW_*`, `KWD_*`),
   wiec nowy keyword wymaga TYLKO wiersza w CSV + galezi w `scoring.gd` (kod efektu).

### 1.4 Plan domkniecia luk

**a) `OmenData` (nowy Resource)** — przenosi `const OMENS` z `run.gd` do `.tres`:

```gdscript
@tool
class_name OmenData
extends Resource
enum Effect { HEAL, GAIN_RTEC, TRADE_HP_FOR_RTEC, HEAL_AND_RTEC, REMOVE_CARD }
@export var name_key: String = ""
@export var desc_key: String = ""
@export var art: Texture2D
@export var effect: Effect = Effect.HEAL
@export var hp_delta: int = 0        ## +10 Gwiazda, -5 Wisielec, +6 Umiarkowanie
@export var rtec_delta: int = 0      ## +4 Kolo, +8 Wisielec, +2 Umiarkowanie
@export var min_hp_required: int = 0 ## Wisielec: blokada gdy HP <= 5 (dzis if w _omen_block)
```

`RegionData` dostaje `@export var omen_pool: Array[OmenData]`, `gen_content.gd` generuje
5 obecnych omenow do `data/omens/`, a `run.gd::_accept_omen()` zamienia match po stringu
na match po `effect`. Wzorzec identyczny jak przy `ArcanumData.Effect` — sprawdzony.

**b) Opcjonalne pola sfx/art na zasobach** (wszystkie z fallbackiem na obecna konwencje,
zeby nic nie trzeba bylo wypelniac od razu):

| Zasob | Nowe pola | Fallback dzisiaj |
|---|---|---|
| `CardData` | `art_override: Texture2D`, `play_sfx: AudioStream` | `CardWidget.minor_art()` (konwencja suit+rank), `Sfx.play(&"card_play")` |
| `EnemyData` | `hit_sfx`, `attack_sfx`, `death_sfx: AudioStream` | stale `&"hit"`, `&"player_hit"`, `&"lose"` w `combat.gd` |
| `ArcanumData` | `claim_sfx: AudioStream` | `&"coin"` w `run.gd` |
| `OmenData` | `accept_sfx: AudioStream` | match w `_accept_omen()` |

**c) Prefabrykacja UI (.tscn) — stanowisko pragmatyczne.** Obecne UI-w-kodzie jest SPOJNE
(helpery `_label/_panel/_button`, motyw z `project.godot`), przetestowane (testy + harness
inputu wg ROADMAP.md) i dziala. Big-bang przepisywanie wszystkiego na sceny to ryzyko
regresji bez zysku dla gracza. Zasada: **prefabrykujemy ekran wtedy, kiedy i tak go
przebudowujemy** (a przebudowa wachlarza/HUD/TAB i tak nadchodzi — patrz roadmapa):

1. **`card_widget.tscn` najpierw** — najczestszy widok w grze (reka, sklep, nagroda,
   picker, kolekcja). Scena: PanelContainer + warstwy art/badge/scrim; `CardWidget` staje sie
   skryptem sceny z `func setup(card: CardData)` zamiast statycznej fabryki. To tez jedyne
   miejsce, gdzie wpinamy shadery edycji (Foil/Holo/Polichrom) — patrz roadmapa, etap 4.
2. **`combat_hud.tscn` drugi** — panel wroga + pasek gracza + kontrolki; `combat.gd` traci
   ~130 linii `_build_ui()` na rzecz `@onready` referencji. Wachlarz (`HandFan`) wchodzi
   jako dziecko tej sceny.
3. **`overview_panel.tscn` trzeci** — panel TAB jest NOWYM ekranem, wiec od pierwszego dnia
   powstaje jako scena (nie ma kodu legacy do utrzymania).
4. Ekrany runu (mapa/sklep/draft) — na koncu, przy okazji planowanego w ROADMAP.md podzialu
   `run.gd` na pliki per-ekran. Do tego czasu zostaja w kodzie: dzialaja i sie nie zmieniaja.

---

## 2. ROADMAPA WDROZENIA (kolejnosc)

Kolejnosc briefu potwierdzona: dane/zapis -> UX walki -> globalne GUI -> meta-progresja.
Oznaczenia: **[TERAZ]** = w biezacej implementacji zespolu; [NAST] = nastepne; [PLAN] = dalej.

### Etap 1 — Fundamenty: dane + zapis **[TERAZ]**

| # | Zadanie | Grunt w kodzie |
|---|---|---|
| 1.1 | **Zapis runu**: `RunState` do grupy `persistent` + `save_data()/load_data()` (serializacja: hp, rtec, region_index, step, deck jako sciezki `.tres` + edycje, relics jako sciezki, hand_levels, fights jako sciezki, seed rng) | `SaveManager` (`src/autoload/save_manager.gd`) gotowy: sloty, JSON, zapis atomowy, sidecar meta — wystarczy podpiac; autozapis po kazdym wezle mapy (`RunState.changed`) |
| 1.2 | **Profil gracza / meta-zapis**: osobny plik `user://profile.json` (waluta meta, odblokowania, statystyki) — poza systemem slotow, bo zyje MIEDZY runami | wzorzec `_write_atomic` z SaveManagera |
| 1.3 | **`OmenData`** + `data/omens/` + `RegionData.omen_pool` (sekcja 1.4a) | TODO w `run.gd` juz to zapowiada |
| 1.4 | Pola sfx/art na zasobach (sekcja 1.4b) | fallbacki istnieja |

### Etap 2 — UX walki (Hearthstone-feel) **[TERAZ]**

| # | Zadanie | Grunt w kodzie |
|---|---|---|
| 2.1 | **Wachlarz kart** (`HandFan`, sekcja 3b): luk, rotacja, hover podnosi i prostuje | `_reconcile_hand()` w `combat.gd` juz robi reconcile-not-rebuild; zamiana `HBoxContainer` na `HandFan` zachowuje ten kontrakt |
| 2.2 | **Drag&drop**: przeciagniecie karty nad strefe stolu = zaznaczenie do zagrania; upuszczenie poza reka = powrot tweenem; zatwierdzenie nadal przyciskiem "Zagraj" (kontrakt determinizmu: podglad przed commitem NIE znika) | `_on_card_input()` (klik-select) zostaje jako rownolegla sciezka; `preview()` w `CombatController` juz liczy dokladny wynik |
| 2.3 | **RMB inspekcja**: klik prawym na karte (reka/stol/sklep) -> powiekszona karta na srodku + panel tooltipow słow kluczowych po prawej | `CardWidget.build_preview()` juz buduje duza karte z opisem keyworda (`KWD_*`); brakuje overlaya na srodku + rozbicia na wiersze-tooltipy |
| 2.4 | Animacja doboru **z talii** (start przy liczniku stosow `_counters_label`, lot do slotu w wachlarzu) | `_animate_draw()` (fade+scale) do rozbudowy; `_fly_card()` juz robi lot odrzutu/zagrania |
| 2.5 | Podglad karty przy kursorze zamiast stalej pozycji `(1016,118)` | `_show_card_preview()` |

### Etap 3 — Globalne GUI [NAST]

| # | Zadanie | Grunt w kodzie |
|---|---|---|
| 3.1 | **ESC pauza** (wznow / opcje / zapis+wyjscie / porzuc run): CanvasLayer + `get_tree().paused`; akcja `ui_cancel` | `settings_menu.tscn` istnieje (`src/ui/settings/`); `SaveManager` liczy playtime z poszanowaniem pauzy |
| 3.2 | **TAB przeglad** (`OverviewPanel`, sekcja 3c) | `ArcanumData.describe()`, `RunState.hand_levels`, `RunState.region_index/step` — wszystkie dane juz sa |
| 3.3 | **Menu glowne**: Nowa Gra / Kontynuacja (z `SaveManager.get_slot_info`) / Opcje / Kolekcja / Wyjscie; motyw tarota (art 22 Arkanow juz w `assets/cards/arcana/`) | `src/main/main.tscn` to pusty boot — naturalne miejsce; zmiana `run/main_scene` w `project.godot` |
| 3.4 | **Kolekcja**: siatka 78 kart (`CardWidget` w gridzie) + zdobyte Arkana; stan z profilu (1.2) | picker talii w `run.gd::_open_deck_picker` to gotowy wzorzec siatki |

### Etap 4 — Meta-progresja i ewolucja wizualna kart [PLAN]

| # | Zadanie | Uwagi |
|---|---|---|
| 4.1 | Waluta meta przyznawana po runie (wygrana/przegrana, skalowana progresem `fights_won`) -> profil | ROADMAP.md M4 "meta-odblokowania" |
| 4.2 | Trwale ulepszenia: odblokowywanie kart do puli startowej / nowych Arkanow do draftu | pule to `DeckData`/`RegionData.starting_pool` — meta filtruje zawartosc |
| 4.3 | **Ewolucja wizualna kart** — poziomy: standard -> **Foil** (blysk, shader) -> **Holo** -> **Polichrom** (teczowy przeplyw) -> **animowana** (parallax warstw artu). Enum `CardData.Edition` i kolory ramek (`CardWidget._ed_color`) juz istnieja; brakuje shaderow (`assets/shaders/` ma tylko CRT) — wpiecie w `card_widget.tscn` jako materialy na TextureRect artu | wymaga 1.4c pkt 1 (prefab karty) |
| 4.4 | Ekwipunek/inwentarz nagrod meta | po 3.4 |

---

## 3. STRUKTURA DRZEWA SCEN (Nodes)

### 3a. Panel walki — `combat.tscn` (docelowo)

Odwzorowuje DZISIEJSZA hierarchie z `combat.gd::_build_ui()` (kolejnosc dzieci = kolejnosc
rysowania), z dwoma zmianami: `HandFan` zamiast `HBoxContainer` i nowe overlaye pauzy/inspekcji.

```
Combat (Control, full rect)                      # skrypt: combat.gd
+-- Backdrop (Control)                           # dzis: Backdrop.build() — gradient + winieta
+-- Margin (MarginContainer, 24px)
|   +-- Root (VBoxContainer, sep 14)
|       +-- EnemyPanel (PanelContainer)          # dzis: _enemy_panel
|       |   +-- V (VBoxContainer)
|       |       +-- Row (HBox): EnemyName (Label) | IntentLabel (Label)
|       |       +-- HpRow (HBox): EnemyHpBar (ProgressBar) | EnemyHpLabel (Label)
|       |       +-- GnicieLabel, KlatwaLabel, RuleLabel (Label)   # statusy + regula pola bossa
|       +-- Mid (VBoxContainer, expand)          # srodek stolu
|       |   +-- RelicRow (HBoxContainer)         # chipy ArcanumData (art + nazwa, tooltip describe())
|       |   +-- EmblemWrap (CenterContainer)
|       |   |   +-- EnemyEmblem (Panel)          # arena: glyph LUB art Wielkiego Arkanum bossa
|       |   |       +-- EmblemGlyph (Label) / EmblemArt (TextureRect)
|       |   +-- PreviewLabel (Label)             # "Uklad: X chips x Y mult = Z" — sim-podglad
|       |   +-- PreviewExtra (Label)             # blok/leczenie/gnicie zagrania
|       |   +-- BreakdownLabel (Label)           # rozbicie multa (_mult_breakdown)
|       |   +-- LogLabel (Label)                 # 4 ostatnie linie logu
|       +-- PlayerRow (HBoxContainer)
|           +-- PlayerHpBar | PlayerHpLabel | BlockLabel | TurnLabel | CountersLabel
+-- HandFan (Control, custom)                    # sekcja 3b; dzis: _hand_row (HBoxContainer)
+-- ControlsBar (HBoxContainer)                  # STALY overlay dolny — anchor_top/bottom = 1.0
|   +-- PlayBtn (Button) | DiscardBtn (Button) | HelpLabel (Label)
|   # UWAGA: kotwiczenie do dolu jest SWIADOME — kolumna srodkowa dwa razy zepchnela
|   # przyciski poza 720p (softlock); nie wracac do layoutu w flow (komentarz w combat.gd)
+-- FoolArt (TextureRect)                        # Glupiec po stronie gracza (ty = karta 0)
+-- Fx (Control, full rect, mouse IGNORE)        # popupy obrazen, flash, latajace karty, preview
+-- Overlays
    +-- EndOverlay (Control: dim + wynik + restart)      # dzis: _overlay
    +-- InspectOverlay (Control)                 # NOWE (2.3): RMB — dim + duza karta + tooltipy
    +-- PauseOverlay (CanvasLayer)               # NOWE (3.1): ESC — pauza; CanvasLayer, bo musi
                                                 # dzialac przy get_tree().paused
```

### 3b. Wachlarz kart — custom Control `HandFan`

`HandFan extends Control` z dziecmi-`CardWidget` (PanelContainer). Layout liczony recznie
w `_update_layout()` (NIE kontener) — kontenery nie umieja luku ani nakladania.

```
HandFan (Control, na dole ekranu, wysokosc ~150)
+-- CardWidget x N (PanelContainer, pivot = srodek karty; CARD_SIZE = 80x112)
```

Parametry (@export, strojone w Inspektorze): `max_spread_deg` (~24), `arc_height` (~26 px),
`overlap_px` (odstep maleje z liczba kart), `hover_raise` (~40 px).

Matematyka pozycji dla karty `i` z `n` (t = i - (n-1)/2.0, czyli odleglosc od srodka):
- `rotation_degrees = t * (max_spread_deg / max(n-1, 1))` — rotacja z indeksu;
- `position.y = base_y + abs(t) * arc_height_step` — im dalej od srodka, tym nizej (luk);
- `position.x` = srodek + `t * krok` (krok maleje, gdy kart wiecej — reka sie sciska);
- **hover**: karta unosi sie (`y -= hover_raise`), prostuje (`rotation -> 0`), skaluje ~1.15
  i dostaje `z_index = 1` — dokladnie jak dzis `CardWidget._on_hover`, ktory celowo NIE robi
  `move_to_front()` (reorder wyrzucal karte spod kursora -> exit -> flicker; komentarz w kodzie);
- zaznaczenie (`set_selected`) dodatkowo podnosi baze skali do 1.1 — bez zmian.

**Regula reconcile-not-rebuild (JUZ ISTNIEJE — przeniesc, nie wymyslac).**
`combat.gd::_reconcile_hand()` utrzymuje mape `_widgets: {CardData -> panel}`:
istniejace widgety ZOSTAJA (zadnego kasowania calej reki), nowo dobrane karty sa dodawane
z animacja (`_animate_draw`), kolejnosc jest wyrownywana `move_child`, a karty zagrane /
odrzucone sa wyjmowane z mapy i ODLATUJA osobno (`_fly_card` -> reparent do `Fx` z
zachowaniem pozycji globalnej -> tween -> free). `HandFan` przejmuje ten kontrakt 1:1:
`reconcile(cards: Array)` zamiast rebuildu; jedyna nowosc to tween pozycji/rotacji do
docelowego slotu na luku po kazdym reconcile.

### 3c. Panel TAB — `overview_panel.tscn` (`OverviewPanel`)

Nowa scena (prefab od pierwszego dnia — sekcja 1.4c). Otwierana klawiszem TAB w runie
i w walce (tylko podglad, bez pauzy logiki walki — walka i tak czeka na input gracza).

```
OverviewPanel (CanvasLayer, layer 10)
+-- Dim (ColorRect, full rect, czarny a=0.7; klik zamyka)
+-- Frame (PanelContainer, wysrodkowany, ~1100x600)
    +-- H (HBoxContainer, sep 16)
        +-- DeckColumn (VBoxContainer, expand)
        |   +-- DeckTitle (Label)                     # "Talia (N)" — N = RunState.deck.size()
        |   +-- DeckScroll (ScrollContainer, expand)
        |       +-- DeckGrid (HFlowContainer)         # CardWidget per karta z RunState.deck;
        |                                             # wzorzec: run.gd::_open_deck_picker
        |                                             # (ScrollContainer + HFlowContainer, sep 8)
        +-- RightColumn (VBoxContainer, ~360 px)
            +-- RelicsTitle (Label)                   # "Arkana / relikwie"
            +-- RelicsList (VBoxContainer)            # per ArcanumData z RunState.relics:
            |   +-- RelicRow (HBox): art (TextureRect 22x38) | name (tr(name_key))
            |       + opis z a.describe()             # gotowa metoda ArcanumData
            +-- HandLevelsTitle (Label)               # "Poziomy ukladow"
            +-- HandLevelsList (VBoxContainer)        # per wpis RunState.hand_levels:
            |                                         # tr(Poker.name_key(h)) + " Lv%d" +
            |                                         # baza z Poker.leveled_base(h, lv)
            +-- JourneyTitle (Label)                  # "Podroz Glupca"
            +-- JourneyRow (HBoxContainer)            # 4 kropki regionow (JOURNEY) — aktywny
            |                                         # = RunState.region_index; w regionie
            |                                         # krok RunState.step / fights.size()+1
            +-- StatsLabel (Label)                    # HP, Rtec, wygrane walki (fights_won),
                                                      # odrzuty/limity (START_DISCARDS + bonusy)
```

Dane: wszystko czytane z autoloadu `RunState` (+ `Poker`), zero nowego stanu — panel jest
czysto prezentacyjny i odswieza sie na sygnale `RunState.changed` oraz przy otwarciu.

---

## Zalaczniki — decyzje krotko

- **Determinizm ponad wszystko**: kazda zmiana UX walki musi zachowac kontrakt "podglad nie
  klamie" (`CombatController.preview()` == wynik `play()`); drag&drop dlatego NIE zagrywa
  karty sam — zagrywa przycisk, po pokazaniu pelnego podgladu.
- **Teksty**: wszystkie nowe stringi przez `data/locale/ui.csv` (zasada 6 z CLAUDE.md);
  ten dokument nie wprowadza zadnych hardcodowanych tekstow dla gracza.
- **Testy**: nowe ekrany (pauza, TAB, menu) dopisac do harnessu inputu z `tests/`;
  uruchamianie wylacznie przez `tools/dev/run_hidden.sh`.
