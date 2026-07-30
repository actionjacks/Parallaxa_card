# Animowane portrety przeciwnikow

> Zrodlo: panel projektowy (workflow parallaxa-feel-overhaul), Animowane portrety przeciwnikow.
> Dokument PROJEKTOWY -- stan wdrozenia opisuje docs/ROADMAP.md.

## Streszczenie

Przebudowa areny na sztywną siatkę absolutnych prostokątów (koniec z VBoxem, który 3x wypchnął przyciski poza 720p): wielki portret wroga 268x452 jako warstwa SCENY pod HUD-em, ręka +45% (116x162), usunięty podgląd po prawej, plus procedularne symbole 5 Aspektów (AspectGlyph) i pasek koloru na każdej karcie.

## SPEC

═══════════════════════════════════════════════════════════════
CZESC 0 — DIAGNOZA (co widac na zrzucie pt2_f01_sel.png)
═══════════════════════════════════════════════════════════════
Zrzut potwierdza brief: srodek kadru (y 130..500, ~370px x 1280) to PUSTKA
z pustym Panelem 168x168 i litera "G". Portret wroga (116x201 gdy jest art)
zajmuje 1.8% kadru. Karty 80x112 = 1.2% kadru kazda. Podglad po prawej
(1000,172) 240px duplikuje to, co i tak robi hover. Tekst matmy (Kareta 88 x
7.0 = 616) wisi w prozni na y=423 bez zadnego tla.

PRZYCZYNA STRUKTURALNA: `_build_ui` buduje MarginContainer -> VBoxContainer ->
[enemy_panel, mid(EXPAND_FILL), prow, hand_row]. Kazdy nowy label w `mid`
rosnie w dol i przesuwa reke. To jest zrodlo 3 softlockow (komentarz w linii
219-221 sam to przyznaje). Rozwiazanie ponizej NIE jest kosmetyczne:
KASUJEMY caly przeplyw kontenerowy w arenie i przechodzimy na SZTYWNE
prostokaty w jednym pliku stalych. Wtedy zaden nowy label nie moze nic
wypchnac — z definicji.

═══════════════════════════════════════════════════════════════
CZESC 1 — NOWY PLIK STALYCH: src/game/ui/arena_layout.gd
═══════════════════════════════════════════════════════════════
Nowa klasa `class_name ArenaLayout` — SAME stale, zero logiki. Kazdy
prostokat areny mieszka tu i nigdzie indziej. Dzieki temu test headless
moze udowodnic, ze budzet 1280x720 sie domyka.

const VW := 1280.0
const VH := 720.0

# --- pasy pionowe ---
const HEADER_Y      := 8.0     # 8..90
const STAGE_Y       := 76.0    # 76..556  (scena portretu, warstwa TLA)
const PLATE_Y       := 384.0   # 384..488 (plyta matmy)
const HAND_Y        := 528.0   # 528..720
const BTN_BAND_Y    := 676.0   # 676..712 (bottom-anchored)

# --- naglowek (z=0) ---
const R_ENEMY_NAME  := Rect2(300, 8, 680, 32)
const R_ENEMY_HP    := Rect2(400, 44, 480, 24)
const R_STATUS_ROW  := Rect2(300, 70, 680, 20)
const R_INTENT      := Rect2(1068, 8, 200, 32)
const R_INTENT_NEXT := Rect2(1068, 42, 200, 22)
const R_ENRAGE      := Rect2(1068, 66, 200, 20)

# --- scena portretu (z=-20), wspolrzedne GLOBALNE ---
const R_STAGE       := Rect2(224, 76, 832, 480)
const R_BACKPLATE   := Rect2(290, 84, 700, 462)   # local w stage: (66, 8)
const R_VIGNETTE    := Rect2(224, 76, 832, 480)   # local: (0, 0)
const R_PORTRAIT    := Rect2(506, 90, 268, 452)   # local: (282, 14)
const R_PORT_FRAME  := Rect2(501, 85, 278, 462)   # local: (277, 9)
const R_PORT_SHADOW := Rect2(474, 528, 332, 30)   # cien pod stopami

# --- plyta matmy (z=1) ---
const R_PLATE       := Rect2(316, 384, 648, 104)
const R_TALLY       := Rect2(326, 390, 628, 20)   # local (10, 6)
const R_PREVIEW     := Rect2(326, 412, 628, 34)   # local (10, 28)
const R_PREVIEW_X   := Rect2(326, 446, 628, 20)   # local (10, 62)
const R_COCKPIT     := Rect2(326, 466, 628, 20)   # local (10, 82)

# --- lewy slup x 12..212 (z=0) ---
const R_SEALS       := Rect2(12, 12, 200, 28)
const R_RELIC_GRID  := Rect2(12, 48, 200, 104)
const R_PAYTABLE    := Rect2(12, 162, 200, 210)
const R_FOOL        := Rect2(20, 382, 84, 144)
const R_PLAYER_HP   := Rect2(12, 536, 200, 26)
const R_PLAYER_STAT := Rect2(12, 568, 200, 22)

# --- prawy slup x 1068..1268 (z=0) ---
const R_META_ROW    := Rect2(1068, 94, 200, 22)   # tura + talia/grob
const R_NEXT_TITLE  := Rect2(1068, 122, 200, 18)
const R_NEXT_ROW    := Rect2(1068, 144, 200, 56)
const R_LOG         := Rect2(1068, 212, 200, 80)

# --- reka + przyciski ---
const R_HAND        := Rect2(300, 528, 680, 192)
# przyciski: bottom-anchored (anchor_top = anchor_bottom = 1.0)
const BTN_TOP       := -44.0   # offset_top
const BTN_BOTTOM    := -8.0    # offset_bottom
const BTN_PLAY_X    := Vector2(20, 144)     # offset_left/right od lewej
const BTN_DISCARD_X := Vector2(152, 276)
const BTN_PAYT_X    := Vector2(-168, -48)   # offset od prawej
const BTN_HELP_X    := Vector2(-44, -12)

# --- warstwy ---
const Z_BACKDROP := -30
const Z_STAGE    := -20
const Z_FOOL     := -6
const Z_HUD      := 0
const Z_HAND     := 0     # w drzewie PO _hud -> rysuje sie nad nim
const Z_HOVER    := 3     # karta pod kursorem / przeciagana
const Z_BUTTONS  := 4     # przyciski ZAWSZE nad karta
const Z_FX       := 6
const Z_OVERLAY  := 10

═══════════════════════════════════════════════════════════════
CZESC 2 — PORTRET WROGA (src/game/combat/combat.gd)
═══════════════════════════════════════════════════════════════
Skany RWS to 305x512 (arkana) i 222x384 (minory), proporcja 0.58-0.60.
Portret 268x452 ma proporcje 0.593 — arkanum wchodzi bez letterboxa i
w DOL-skalowaniu (452 < 512), czyli ostro.

`_make_emblem()` -> zastapione przez `_make_stage() -> Control`.
Kasujemy `_enemy_emblem`, `_emblem_glyph`, `_emblem_art`, `_enemy_panel`.
Nowe pola: `_stage`, `_portrait`, `_portrait_art`, `_portrait_frame`,
`_stage_back`, `_portrait_shadow`.

Budowa `_make_stage()`:
1. `_stage := Control.new()`; rect = R_STAGE; z_index = Z_STAGE;
   mouse_filter = IGNORE.
2. `_stage_back := TextureRect.new()`
   - expand_mode = EXPAND_IGNORE_SIZE  **USTAWIC PRZED texture i size**
     (pulapka EXPAND_KEEP_SIZE jest juz udokumentowana w combat.gd:249-251
     i card_widget.gd:120 — tu ugryzie po raz trzeci)
   - stretch_mode = STRETCH_KEEP_ASPECT_COVERED
   - texture_filter = LINEAR
   - local rect (66, 8, 700, 462)
   - modulate = Color(0.60, 0.56, 0.62, 0.80)  # przyciemniony "swiat karty"
   To jest ta sama tekstura co portret, ale rozciagnieta na 700 szer.
   i wykadrowana — daje wrazenie, ze wrog wypelnia kadr, mimo ze ostra
   karta ma tylko 268px.
3. `_stage_vignette := TextureRect.new()` z GradientTexture2D:
   fill = FILL_RADIAL, fill_from (0.5,0.5), fill_to (1.0,0.5),
   gradient: 0.0 -> Color(0.055,0.045,0.05, 0.0), 0.55 -> alpha 0.35,
   1.0 -> Color(0.055,0.045,0.05, 1.0). Rect = R_VIGNETTE local (0,0).
   Zadaniem winiety jest ZLIKWIDOWANIE twardej krawedzi kadru backplate'u.
4. `_portrait_frame := Panel.new()` — StyleBoxFlat, border 3px w kolorze
   wroga (etint), corner_radius 5, bg Color(0.06,0.04,0.06,0.35).
   local rect (277, 9, 278, 462). **SIOSTRA `_portrait`, NIE rodzic** —
   inaczej oddech (scale) faluje ramka.
5. `_portrait := Control.new()`; local rect (282, 14, 268, 452);
   `clip_contents = true`; `pivot_offset = Vector2(134, 452)` (STOPY —
   oddech nie odrywa figury od cokolu).
6. `_portrait_art := TextureRect.new()` jako dziecko `_portrait`:
   expand_mode PRZED texture; STRETCH_KEEP_ASPECT_CENTERED; LINEAR;
   PRESET_FULL_RECT; `modulate = Color(0.88, 0.86, 0.90)` (skany 1909 sa
   kremowe i inaczej przepala ciemny UI); `pivot_offset = Vector2(134, 452)`.
7. `_portrait_shadow` — TextureRect z GradientTexture2D FILL_RADIAL,
   Color(0,0,0,0.55) -> alpha 0, local rect (250, 452, 332, 30).

W `_render()` zamiast obecnych linii 368-384:
  _portrait_art.texture = _enemy.art
  _portrait_art.flip_h = _enemy.is_elite
  _portrait_art.flip_v = _enemy.is_elite
  _stage_back.texture = _enemy.art
  (StyleBoxFlat ramki).border_color = etint
Fallback gdy `_enemy.art == null`: wszystkie 27 plikow data/combat/*.tres
MAJA art (sprawdzone), ale fallback zostaje: `_portrait_art.texture = null`
+ Label z pierwsza litera nazwy, font **170** (nie 92 — w ramce 268x452
font 92 wyglada jak blad), plus AspectGlyph 200x200 w alpha 0.18 za litera.

ANIMACJA PORTRETU (limit amplitudy: +-10px pozycji, max scale 1.06 —
przy 452px wysokosci scale 1.10 wjechaloby 45px w plyte matmy):
- `_portrait_idle()`: petla, `_portrait_art.scale` 1.000 <-> 1.022,
  2 x 1.6s, TRANS_SINE. Dzieki `clip_contents` na `_portrait` skala nie
  wychodzi poza ramke — to jest "oddychajacy kadr" z jednego skanu.
- `_portrait_windup()` (zastepuje wind-up na `_enemy_panel`, linie 1070-1075):
  `_portrait.position.y += 6` + `_portrait_art.modulate` -> Color(1.5,0.8,0.8)
  przez `wind` sekund, potem powrot.
- `_portrait_hit()` (zastepuje `_emblem_hit`): `_portrait_art.scale` 1.06 -> 1.0
  przez 0.28 TRANS_BACK + `_portrait.position.x` +-5 (2 odbicia po 0.06).
- `_on_ended` (linie 1122-1129): tweeny celuja w `_portrait` zamiast
  `_enemy_emblem`; upadek `position:y += 120`, rotation 0.5, modulate ciemny.
- `_start_emblem_idle` -> `_portrait_idle`, `_emblem_idle` -> `_portrait_idle_tw`.

Portret zajmuje 268x452 = 121k px (13.2% kadru) ostro + backplate 700x462
= 323k px (35% kadru) atmosferycznie. Razem "scena wroga" to ~48% kadru
wobec obecnych 1.8%. To jest odpowiedz na "zajmujace WIEKSZOSC ekranu".

═══════════════════════════════════════════════════════════════
CZESC 3 — REKA: NOWE ROZMIARY (src/game/ui/hand_fan.gd)
═══════════════════════════════════════════════════════════════
Stare -> nowe:
  CARD_W          80.0  -> 116.0
  CARD_H         112.0  -> 162.0     (proporcja 0.716 == stara 0.714)
  SPACING_MAX     74.0  ->  90.0
  ARC_ROT_STEP     1.8  ->   2.2
  ARC_DIP          3.0  ->   2.4
  HOVER_SCALE     1.45  ->   1.30
  RAISE_SELECTED  26.0  ->  22.0
  RAISE_HOVER      0.0  ->   0.0     (bez zmian — pivot dolny zostaje)
  custom_minimum_size (0,148) -> (0,192)
  NOWA: const EDGE_PAD := 8.0

Wzor rozstawu (linia 40) — obecne `-160.0` to magiczna stala, ktora
sztucznie sciska wachlarz:
  var spacing: float = minf(SPACING_MAX,
      (size.x - CARD_W - EDGE_PAD * 2.0) / maxf(n - 1, 1.0))

Pozycja w slocie (linie 54-55):
  var x := size.x / 2.0 + c * spacing - CARD_W / 2.0
  var y := 4.0 + minf(pow(absf(c), 1.5) * ARC_DIP, 16.0)   # CLAMP na dip

RACHUNEK BUDZETU dla HAND_SIZE = 8 (combat_controller.gd:11), przy
_hand_row.size = (680, 192) na pozycji (300, 528):
  spacing = min(90, (680-116-16)/7) = 78.28
  lewa krawedz 1. karty  = 300 + 340 - 273.98 - 58 = 308.0   (lewy slup konczy sie na 212 -> luz 96)
  prawa krawedz 8. karty = 300 + 340 + 273.98 - 58 + 116 = 971.98  (prawy slup zaczyna sie na 1068 -> luz 96)
  dol karty skrajnej     = 528 + 4 + 15.7 + 162 = 709.7      (< 720, luz 10.3)
  gora karty pod hoverem = 709.7 - 162 * 1.30 = 499.1        (> 488 = dol plyty matmy -> PLYTA NIGDY NIE JEST ZASLONIETA)
  gora karty zaznaczonej = (528+4-22) + 162 - 162*1.1 = 493.8 (> 488, luz 5.8)
TWARDY SUFIT: HOVER_SCALE nie moze przekroczyc (709.7-488)/162 = 1.368.
1.30 zostawia margines; nie podnosic bez przesuniecia plyty.

WIDOCZNOSC KARTY: stary uklad dawal 74px widocznego paska na karte 80x112.
Nowy daje 78.3px paska na karcie 116x162 — czyli o 4px szerszy pasek, ale
o 45% wyzszy, a ilustracja RWS jest 2.1x wieksza powierzchniowo. Jesli
gameplay-agent obnizy HAND_SIZE do 7, rozstaw skacze do 90 (cap) i widoczny
pasek rosnie do 90px — rekomendacja, nie warunek.

Reka NIE jest juz w przeplywie: w `_build_ui` ustawic
  _hand_row.position = ArenaLayout.R_HAND.position
  _hand_row.size = ArenaLayout.R_HAND.size
i na koncu `_build_ui` wywolac `_hand_row.relayout(false)` — sygnal
`resized` odpali raz przy przypisaniu size, ale jawne wywolanie chroni
przed wyscigiem z pierwszym `_render`.

`_reconcile_hand` linia 408: `panel.position = Vector2(size.x - 60.0, 30.0)`
-> karty maja przylatywac z licznika talii w prawym slupie:
  panel.position = _hand_row.to_local(_deck_icon.global_position) - Vector2(58, 81)
Drag (linia 816): `_drag_panel.z_index = 2` -> `= ArenaLayout.Z_HOVER` (3).
CardWidget._on_hover (linia 257): `z_index = 2 if entering else 0`
  -> `= ArenaLayout.Z_HOVER if entering else 0`.

═══════════════════════════════════════════════════════════════
CZESC 4 — USUNIECIE PODGLADU PO PRAWEJ
═══════════════════════════════════════════════════════════════
Kasujemy (combat.gd):
  - linia 67:      var _preview_node
  - linie 422-423: panel.mouse_entered.connect(_show_card_preview...) i mouse_exited
  - linie 439-449: cale _show_card_preview() i _hide_card_preview()
  - linia 963:     _hide_card_preview() w _on_play()
  - linia 985:     _hide_card_preview() w _on_discard()
Po tym `CardWidget.build_preview()` (card_widget.gd:282-326) nie ma juz
zadnego wywolania w projekcie (sprawdzone gerpem) — USUNAC caly statyk
(45 linii) razem z komentarzem w naglowku pliku (linia 4). Overlays.inspect
uzywa `CardWidget.minor_art` + `CardWidget.build`, wiec nie ucierpi.

CO WCHODZI W PRAWY SLUP (x 1068..1268, odzyskane 200px):
  R_INTENT       (1068,  8, 200, 32) — zamiar wroga, font 24, prawa
  R_INTENT_NEXT  (1068, 42, 200, 22) — nastepny zamiar, font 15
  R_ENRAGE       (1068, 66, 200, 20) — zegar furii, font 13
  R_META_ROW     (1068, 94, 200, 22) — _turn_label + _counters_label, HBox
                                       ALIGNMENT_END, font 14, sep 10
  R_NEXT_TITLE   (1068,122, 200, 18) — tr("NEXT_DRAWS"), font 13
  R_NEXT_ROW     (1068,144, 200, 56) — _next_wrap, 3 mini-karty 40x56, sep 6
                                       (obecnie 2 sztuki 20x24 — za male,
                                       przy okazji `controller.peek_draw(2)`
                                       -> `peek_draw(3)`)
  R_LOG          (1068,212, 200, 80) — _log_label, font 13,
                                       autowrap_mode = AUTOWRAP_WORD,
                                       4 linie (limit juz jest, linia 1012)
Ponizej y=292 prawy slup jest PUSTY — to celowe: winieta sceny wsiaka
w te przestrzen i portret ma czym oddychac.

Zastepnik podgladu: hover (1.30x = 151x211px, wiecej niz stary panel 240px
podgladu w praktycznej czytelnosci ilustracji) + PPM -> Overlays.inspect
(300x519 skan + pelny opis). Nic nie ginie.

═══════════════════════════════════════════════════════════════
CZESC 5 — PLYTA MATMY (kokpit) i reszta HUD
═══════════════════════════════════════════════════════════════
`_plate := PanelContainer.new()` na R_PLATE (316,384,648,104), z_index = 1,
`clip_contents = true`, `mouse_filter = MOUSE_FILTER_PASS`.
StyleBoxFlat: bg Color(0.05,0.04,0.07,0.86), border_width_top = 2 w kolorze
wroga (etint), pozostale 1px Color(0.30,0.26,0.36), corner_radius 3.
Wizualnie czyta sie jako COKOL, na ktorym stoi wrog — nie jako okno UI.
Plyta jest ZAWSZE widoczna (staly dom dla oka, zero skokow layoutu).

Zawartosc (dzieci absolutne, wspolrzedne LOKALNE wzgledem plyty):
  (10,  6, 628, 20) `_tally_row` — 5 pozycji: [glyph 18x18][" N/M" font 13]
                     w kolorze Aspektu, HBox ALIGNMENT_CENTER, sep 34.
                     N = karty tego Aspektu W RECE, M = zostale w talii
                     dobierania. Tekst budowany w kodzie jako "%d/%d"
                     (bez wiersza w ui.csv -> zero ryzyka parzystosci %).
                     tooltip: tr("TALLY_TIP").
                     TO JEST NARZEDZIE DECYZYJNE, nie ozdoba: gracz skarzy
                     sie, ze robi "co najwyzej pary" — tally mowi wprost,
                     czy Kolor jest w ogole mozliwy.
  (10, 28, 628, 34) `_preview_label` — font 28 (bylo 24), HORIZONTAL_CENTER,
                     mouse_filter = STOP, tooltip = `_mult_breakdown(hand)`
  (10, 62, 628, 20) `_preview_extra` — tagi (+Blok, Gnicie, LETAL), font 15
  (10, 82, 628, 20) `_cockpit_label` — font 15, zawsze widoczny
`_breakdown_label` — USUNAC jako osobny Label; jego tresc idzie w tooltip
`_preview_label` (patrz wyzej). To kasuje najbardziej deweloperska linijke
z kadru, nie tracac informacji.
Gdy `_selected.is_empty()`: `_preview_label.text = tr("COMBAT_SELECT_HINT")`
font 20 alpha 0.75, `_preview_extra.text = ""`, `_cockpit_label` dalej
pokazuje pasywny kokpit (co wrog zrobi w tej turze).

NAGLOWEK (z=0, dzieci `self`):
  `_enemy_name`     R_ENEMY_NAME (300,8,680,32), font 26, HORIZONTAL_CENTER,
                    clip_text = true, text_overrun_behavior = TRIM_ELLIPSIS
  `_enemy_hp_bar`   R_ENEMY_HP (400,44,480,24), custom_minimum_size (480,24)
  `_enemy_hp_label` dziecko paska, PRESET_FULL_RECT, font 15, CENTER/CENTER,
                    Color(0.96,0.94,0.96) + outline 2px czarny
  `_status_row`     R_STATUS_ROW (300,70,680,20), HBox ALIGNMENT_CENTER,
                    sep 10. Zawiera "chipy" (PanelContainer, bg 0.5 alpha,
                    font 13, clip_text): [regula bossa][Gnicie N][Klatwa N].
                    `_rule_label` przenosi sie TU jako pierwszy chip
                    (TRIM_ELLIPSIS + pelny tekst w tooltipie) — dzieki temu
                    lewy slup jest wolny na relikwie.
  `_intent_label` / `_next_intent_label` / `_enrage_label` — prawy slup,
                    HORIZONTAL_ALIGNMENT_RIGHT.

LEWY SLUP (z=0):
  `_seals_row`   R_SEALS (12,12,200,28) — NOWE: 5 pieczeci Aspektow
                 (AspectGlyph 24x24, sep 20). Zdobyty biom = pelna alpha
                 + kolor Aspektu; niezdobyty = alpha 0.22, szary.
                 Zrodlo: RunState (pole `won_aspects: Array[int]` — do
                 dodania przez agenta od struktury runu; jesli jeszcze nie
                 istnieje, renderowac wszystkie jako dim i nie wywalac sie).
                 tooltip tr("SEALS_TIP"). To jest wizualny licznik "podrozy
                 zbierania arkanow" z briefu.
  `_relic_grid`  R_RELIC_GRID (12,48,200,104) — GridContainer, columns = 4,
                 h/v_separation 8. Chipy relikwii TYLKO IKONOWE: 40x48
                 TextureRect (a.art, KEEP_ASPECT_CENTERED, LINEAR) w ramce
                 1px w kolorze `Aspects.color(a.effect_aspect)`, tooltip =
                 nazwa + `a.describe()` (jak dzis w `_relic_chip`, linia 1215).
                 4x2 = 8 relikwii bez przewijania. Przy >8: 8. slot to chip
                 "+N" (font 14) z tooltipem lista reszty.
                 USUNAC `_relic_row: HBoxContainer` i tekstowa nazwe z chipa.
  `_paytable`    R_PAYTABLE (12,162,200,210). KRYTYCZNE: ustawic jawnie
                 `_paytable.size = Vector2(200, 210)` ORAZ
                 `_paytable.clip_contents = true`, a kazdy wiersz-Label:
                 `custom_minimum_size = Vector2(184, 15)`, `clip_text = true`,
                 font 12, VBox separation 0, content_margin 8.
                 PanelContainer domyslnie ROSNIE do dzieci — a wiersze rosna,
                 gdy uklad awansuje na "(Lv4)". To dokladnie ten mechanizm,
                 ktory 3x wypchnal przyciski. Bez clip_contents wroci.
                 Toggle (przycisk prawy dolny) zmienia TYLKO `visible` —
                 nic sie nie przesuwa, bo nic nie jest w przeplywie.
  `_fool`        R_FOOL (20,382,84,144), z_index = Z_FOOL (-6).
                 Proporcja 84/144 = 0.583 = proporcja skanu. tooltip
                 tr("FOOL_YOU") zostaje.
  `_player_hp_bar`  R_PLAYER_HP (12,536,200,26), zielony;
                    `_player_hp_label` jako dziecko PRESET_FULL_RECT,
                    font 15, CENTER (tak jak pasek wroga — symetria).
  `_player_stat_row` R_PLAYER_STAT (12,568,200,22), HBox sep 10, font 14:
                    `_block_label` + `_heal_pool_label`.
                    `_turn_label` i `_counters_label` ida do R_META_ROW
                    (prawy slup) — to metryki stolu, nie gracza.
  USUNAC caly `prow: HBoxContainer` (linie 186-211).

PRZYCISKI (z = Z_BUTTONS = 4, bottom-anchored — reguly nie ruszamy):
  Kazdy przycisk osobno, anchor_top = anchor_bottom = 1.0,
  offset_top = -44, offset_bottom = -8 (wysokosc 36, font 16).
  `_play_btn`    anchor_left/right = 0.0, offset 20 / 144
  `_discard_btn` anchor_left/right = 0.0, offset 152 / 276
  `pt_btn`       anchor_left/right = 1.0, offset -168 / -48
  `help_btn`     anchor_left/right = 1.0, offset -44 / -12, text "?",
                 tooltip_text = tr("COMBAT_HELP")
  USUNAC `_help_label` z paska przyciskow (linie 243-244) — to on zjadal
  x 160..470 i kolidowal z lewa krawedzia wachlarza (308). Tekst pomocy
  zyje w tooltipie "?" oraz jednorazowo przez `_covenant_line`.
  Sprawdzenie luzow: przyciski lewe koncza sie na 276, pierwsza karta
  zaczyna sie na 308 (luz 32). Przyciski prawe zaczynaja sie na 1112,
  ostatnia karta konczy sie na 972 (luz 140).

KOTWICE FX (linie 1166-1176) — przepiac na portret; to najtansza poprawa
"czucia" w calym zadaniu, bo liczby obrazen zaczna wyskakiwac Z CIALA WROGA,
a zagrane karty beda w NIEGO leciec (`_fly_card(..., _enemy_fx_pos())`):
  _enemy_fx_pos()  -> _portrait.global_position + Vector2(134, 150)
  _player_fx_pos() -> _fool.global_position + Vector2(42, 20)
  _grave_fx_pos()  -> Vector2(1168, 100)
  _block_fx_pos()  -> _player_hp_bar.global_position + Vector2(100, -26)

PRZESUNIECIA CEREMONII:
  `_set_prophecy` linia 615: p.position (470,190) -> Vector2(455, 214),
    custom_minimum_size (340,0) -> (370,0), pivot (170,70) -> (185,80).
    Piecz kryje TORS wroga — to celowe przejecie kadru.
  `_covenant_line` linia 635: offset_top 505 -> **PRESET_TOP_LEFT,
    position = Vector2(300, 92), size = Vector2(680, 24)**. Stare 505
    koliduje teraz z niczym waznym, ale 92 (tuz pod naglowkiem, nad glowa
    portretu) jest czyste i nie zaslania plyty matmy.
  `_fulfill_prophecy` linia 681: offset_top 220 -> 200; "PROPHECY_FULFILLED"
    offset_top 300 -> 286.
  `_magnum_reveal` (250 / 330) — bez zmian, to pelnoekranowe przejecie.

USUWANE Z `_build_ui`: `margin: MarginContainer` (114-117),
`root: VBoxContainer` (119-121), `enemy_panel` + `ev`/`erow`/`ehp` (124-153),
`mid: VBoxContainer` + `emblem_wrap: CenterContainer` (156-183),
`prow` (186-211), `crow` w obecnej formie (222-244).
Wszystko staje sie: `add_child(node); node.position = R.position;
node.size = R.size; node.z_index = Z_*`.
NA KAZDYM absolutnie pozycjonowanym Labelu ustawic JAWNIE `size` — bo
`_pulse()` (linia 1244) robi `pivot_offset = node.size * 0.5`, a Label bez
kontenera i bez jawnego size ma size == (0,0) do pierwszego przebiegu
layoutu i pierwszy pulse obraca sie wokol lewego gornego rogu.

═══════════════════════════════════════════════════════════════
CZESC 6 — SYMBOLE ASPEKTOW: src/game/ui/aspect_glyph.gd (NOWY)
═══════════════════════════════════════════════════════════════
class_name AspectGlyph
extends Control

Rysowanie PROCEDURALNE w `_draw()`, plus statyk do rysowania na cudzym
plotnie bez alokacji wezla:

  static func draw_into(ci: CanvasItem, id: int, r: Rect2, col: Color) -> void

Wszystkie ksztalty definiowane w kwadracie jednostkowym 0..1 (y w dol)
i mapowane przez `p * r.size + r.position`. Grubosc kreski:
  var w: float = maxf(1.0, r.size.x * 0.09)
Prog uproszczenia:
  var small: bool = r.size.x < 26.0
Kwadrat rysowania: bok = minf(r.size.x, r.size.y), wysrodkowany w r.

1) LIFE — KIELICH (dziedzictwo Pucharow, zloto f4e2a1)
   - czasza: draw_arc(c=(0.50,0.42), R=0.30, 0.0, PI, 18, col, w)
     (kat 0..PI w Godocie zakresla dolna polowe -> miska)
   - rant:  draw_line((0.18,0.42),(0.82,0.42), col, w)
   - trzon: draw_line((0.50,0.72),(0.50,0.86), col, w)
   - stopa: draw_line((0.28,0.88),(0.72,0.88), col, w * 1.2)
   - small: draw_colored_polygon(polprzekroj miski jako 10-katny wielokat
     od (0.18,0.42) po luku R=0.32 do (0.82,0.42)) + rant. Bez trzonu/stopy.
   Sylwetka unikalna: JEDYNY ksztalt z zaokraglonym dolem i plaska gora.

2) MIND — OSTRZE (dziedzictwo Mieczy, blekit 6ec6ff)
   - klinga (wypelnienie): draw_colored_polygon([
       (0.50,0.04), (0.63,0.44), (0.50,0.96), (0.37,0.44)], col)
   - jelec:  draw_line((0.22,0.62),(0.78,0.62), col, w * 1.1)
   - small: bez zmian (obie czesci sa nosne; jelec to CALY odczyt)
   Sylwetka unikalna: JEDYNY ksztalt z pozioma belka przecinajaca pion.

3) DEATH — PENTAKL (dziedzictwo Denarow, fiolet 9a6bd6)
   - obrecz: draw_arc((0.50,0.50), 0.44, 0.0, TAU, 30, col, w)
   - gwiazda: 5 wierzcholkow p[i] = (0.50,0.50) + 0.34 * Vector2(
       cos(-PI/2 + i*TAU/5), sin(-PI/2 + i*TAU/5));
       draw_polyline([p0,p2,p4,p1,p3,p0], col, w * 0.85)
   - small: obrecz PRECZ, zamiast polyline WYPELNIONA 5-ramienna gwiazda
     (10 wierzcholkow: promien zewn. 0.46 / wewn. 0.19, kat startu -PI/2),
     draw_colored_polygon. Pieciolinia przy 20px zlewa sie w plamke —
     wypelniona gwiazda zostaje czytelna do ~12px.
   Sylwetka unikalna: JEDYNY ksztalt kolisty / kolczasty promieniscie.

4) CHAOS — PLOMIEN (dziedzictwo Buław, czerwien ff6b57)
   - wypelniony wielokat 12-wierzcholkowy (zeby "zab" plomienia byl widoczny):
     [(0.50,0.02),(0.66,0.34),(0.60,0.32),(0.74,0.62),(0.66,0.60),
      (0.72,0.92),(0.50,0.98),(0.28,0.92),(0.34,0.60),(0.26,0.62),
      (0.40,0.32),(0.34,0.34)]
   - small: 7 wierzcholkow:
     [(0.50,0.02),(0.72,0.56),(0.62,0.52),(0.66,0.96),(0.34,0.96),
      (0.38,0.52),(0.28,0.56)]
   Sylwetka unikalna: JEDYNY ksztalt z poszarpanym, wielokoncowym szczytem.

5) NATURE — LISC (brak historycznej masci RWS, zielen 74c46b)
   - vesica: 18 punktow, t = i/8 dla i in 0..8:
       lewa:  (0.50 - 0.34 * sin(PI * t), 0.04 + 0.92 * t)
       prawa: (0.50 + 0.34 * sin(PI * (1-t)), 0.04 + 0.92 * (1-t))
     -> draw_colored_polygon(zamkniety wielokat, col)
   - nerw: draw_line((0.50,0.10),(0.50,0.90), tlo_karty, w * 0.8)
     (WYCINANY kolorem tla, nie kreska w kolorze — czyta sie jak zylka)
   - small: sam vesica, bez nerwu.
   Sylwetka unikalna: JEDYNY ksztalt spiczasty z OBU koncow.

Zestaw jest rozroznialny w sylwecie (test: wyrenderowac cala piatke
w czerni na bieli w 20px i sprawdzic, czy da sie je odroznic bez koloru —
tak, bo kryterium rozroznienia jest ksztalt konturu, nie detal).

MIEJSCA UZYCIA: karty w rece, mini-karty `_next_wrap`, pieczecie `_seals_row`,
znak wodny na twarzy NATURE, Overlays.inspect (obok nazwy Aspektu).

═══════════════════════════════════════════════════════════════
CZESC 7 — KARTA: KOLOR I SYMBOL (src/game/cards/card_widget.gd)
═══════════════════════════════════════════════════════════════
UWAGA NA REGRESJE: `CardWidget.build()` ma 7 wywolan poza reka
(menu.gd:421,454; overlays.gd:119,188; run.gd:404,495,620 — nagrody, sklep,
kolekcja, przegladarka talii). Powiekszenie samego CARD_SIZE przelozy
wszystkie te siatki. Dlatego:

  const CARD_SIZE      := Vector2(80, 112)    # BEZ ZMIAN — siatki
  const HAND_CARD_SIZE := Vector2(116, 162)   # NOWE — tylko reka
  static func build(card: CardData, px: Vector2 = CARD_SIZE) -> PanelContainer

Wszystkie wewnetrzne wymiary jako UŁAMKI px (k := px.x / 80.0):
  ramka:        border_width_all = roundi(2.0 * k)        -> 3 (reka) / 2 (siatka)
  tlo:          sb.bg_color = Color(col.r*0.16+0.035, col.g*0.16+0.035,
                                    col.b*0.16+0.035)     # tlo TEZ w kolorze Aspektu,
                                                          # zamiast wspolnego BG
  badge (rog gorny-lewy): Rect2(0.034*W, 0.025*H, 0.26*W, 0.27*H)
                -> (4,4,30,44) w rece / (2.7,2.8,20.8,30.2) w siatce
                ColorRect Color(0.04,0.04,0.06,0.88) + 1px obrys w `col`
    ranga:      Label font = roundi(0.115*H) -> 19 / 13, kolor `col`,
                w gornej polowie badge'a
    symbol:     AspectGlyph bok = 0.17*W -> 19.7 / 13.6, w dolnej polowie
  pasek koloru (dolna krawedz): Rect2(0, H - 0.037*H, W, 0.037*H)
                -> (0,156,116,6) w rece / (0,108,80,4) w siatce
                ColorRect w PELNYM `Aspects.color(card.aspect)` (bez alpha)
  scrim slow kluczowych: przesunac o wysokosc paska w gore
                (offset_top = -(scrim_h + bar_h))
  scrim koloru na arcie: TextureRect z GradientTexture2D,
                fill = FILL_LINEAR, fill_from (0,0), fill_to (1,1),
                stopnie: 0.00 -> Color(col, 0.32)
                         0.42 -> Color(col, 0.04)
                         1.00 -> Color(col, 0.26)
                wstawiony NAD arte, POD badge'em i scrimem.
                (linia skosna, nie radialna — radialna na kremowym skanie
                 1909 daje mydlo)

DLACZEGO TRZY WARSTWY KOLORU, A NIE SAMA RAMKA: ramka 2px na karcie 80x112
to 0.5% powierzchni i przy 8 nachodzacych kartach widac tylko jej lewy
odcinek. Pasek 6px na pelnej szerokosci + tlo w tincie + skosny scrim daja
~14% powierzchni karty w kolorze Aspektu. Przy wachlarzu paski ustawiaja
sie w KOD KRESKOWY wzdluz dolnej krawedzi — jednym rzutem oka widac
rozklad kolorow w rece (a to jest dokladnie informacja, ktorej gracz
potrzebuje, zeby przestac robic "co najwyzej pary").

DLACZEGO BADGE W ROGU GORNYM-LEWYM: HandFan dodaje dzieci w kolejnosci
rosnacej, wiec karta i+1 rysuje sie NA karcie i i zaslania jej PRAWA
strone. Lewa krawedz kazdej karty jest widoczna ZAWSZE (78.3px paska przy
8 kartach) — to jest ten sam powod, dla ktorego prawdziwe talie drukuja
indeks w lewym gornym rogu. Badge 30x44 miesci sie z ogromnym zapasem.

TWARZ NATURE (`_build_plain_face`, linie 171-252) — usunac dwa obrocone
Panele-romby (linie 202-214) i wstawic:
  AspectGlyph (LEAF) jako znak wodny: Rect2(0.24*W, 0.18*H, 0.52*W, 0.52*H)
  w Color(col, 0.26); ranga font roundi(0.27*H) -> 44 na wierzchu.
Gradient tla zostaje. To likwiduje wrazenie "brakujacego assetu" i spina
piaty Aspekt z jezykiem symboli.

MINI-KARTY `_next_wrap` (combat.gd:541-558) — 20x24 -> 40x56:
  ranga font 15 u gory, AspectGlyph 16x16 w lewym dolnym rogu,
  pasek koloru 3px na dole, ramka 1px w `col`. Tooltip bez zmian.

═══════════════════════════════════════════════════════════════
CZESC 8 — TEKSTY (data/locale/ui.csv)
═══════════════════════════════════════════════════════════════
Nowe wiersze (kolumny key,en,pl) — ZADEN nie zawiera %d/%s, wiec pulapka
parzystosci formatow nie ma tu jak wystrzelic:
  TALLY_TIP,Cards of this Aspect: in your hand / left in the draw pile.,Karty tego Aspektu: w ręce / zostałe w talii dobierania.
  SEALS_TIP,Aspect seals won. Five seals open the hidden biome.,Zdobyte pieczęcie Aspektów. Pięć pieczęci otwiera ukryty biom.
Klucz `COMBAT_HELP` (istnieje, linia 383) przenosi sie z Labela do
tooltipa przycisku "?". `NEXT_DRAWS` (654) i `PAYTABLE_TITLE` (654) bez zmian.
Napis licznika tally budowany w kodzie jako `"%d/%d" % [in_hand, in_draw]`
— celowo POZA csv, bo to notacja liczbowa, nie zdanie.

═══════════════════════════════════════════════════════════════
CZESC 9 — KOLEJNOSC IMPLEMENTACJI (9 krokow, kazdy weryfikowalny zrzutem)
═══════════════════════════════════════════════════════════════
1. `src/game/ui/arena_layout.gd` — same stale. Zero ryzyka, ale musi byc
   pierwszy, bo reszta sie do niego odwoluje.
2. `src/game/ui/aspect_glyph.gd` — 5 ksztaltow. Weryfikacja: tymczasowa
   scena `tests/glyph_sheet.tscn` rysujaca siatke 5 x 2 (20px i 120px)
   w kolorze i w czerni; zrzut; OBEJRZEC. Dopiero po akceptacji dalej.
3. `hand_fan.gd` — 8 stalych + wzor rozstawu + clamp dipu. Weryfikacja:
   zrzut walki, policzyc ze zadna karta nie przekracza y=720 i ze lewa
   krawedz jest > 276 (koniec przyciskow).
4. `card_widget.gd` — parametr `px`, badge, pasek koloru, scrim, twarz
   NATURE. Weryfikacja: zrzut + zrzut ekranu kolekcji (menu.gd) — siatki
   MUSZA wygladac jak przedtem, bo `px` domyslnie = CARD_SIZE.
5. Kasacja podgladu: `_show_card_preview`/`_hide_card_preview`/`_preview_node`
   + `CardWidget.build_preview`. Weryfikacja: `godot --headless --check-only`
   albo import bez bledow parsowania.
6. `_make_stage()` + przepiecie `_render` na portret + fallback bez artu.
   Weryfikacja: zrzut z bossem (arkanum 305x512) i z zwyklym (minor 222x384).
7. Przebudowa `_build_ui` na prostokaty z ArenaLayout (naglowek, slupy,
   plyta matmy, przyciski lewe/prawe). NAJWIEKSZY krok — robic osobnym
   commitem. Weryfikacja: zrzut w trzech stanach (bez zaznaczenia /
   3 karty zaznaczone / proroctwo letalne).
8. Kotwice FX + ceremonie (proroctwo, covenant, fulfill) + animacje
   portretu (idle / windup / hit / smierc).
9. `ui.csv` + test straznik `tests/test_arena_layout.gd`:
   headless, iteruje po wszystkich stalych `R_*` w ArenaLayout i sprawdza
   (a) `r.end.y <= 720` i `r.end.x <= 1280`,
   (b) zaden `R_*` z lewego/prawego slupa nie przecina `R_HAND`,
   (c) pas przyciskow (y 676..712, x 20..276 i 1112..1268) nie przecina
       zadnego prostokata HUD.
   Ten test jest ubezpieczeniem od czwartego softlocka.

═══════════════════════════════════════════════════════════════
CZESC 10 — CO ZOSTAJE POZA ZAKRESEM TEJ ZMIANY
═══════════════════════════════════════════════════════════════
- HAND_SIZE (8) i START_DISCARDS (3) — decyzja gameplayowa; layout dziala
  dla 8, a przy 7 robi sie luzniejszy (rozstaw 90 zamiast 78.3).
- 5 biomow / ukryty biom — struktura runu; layout dostarcza tylko
  `_seals_row` i czyta hipotetyczne `RunState.won_aspects`.
- Nowe skany / animowane spritey wroga — nie mamy zrodla poza RWS 1909;
  "animacja" to tu tweeny + oddychajacy kadr na jednym skanie.

## RISKS

RYZYKO 1 — REGRESJA SIATEK KART POZA WALKA (najwazniejsze). CardWidget.build() ma 7 wywolan poza reka: menu.gd:421 i 454 (kolekcja), overlays.gd:119 i 188 (przeglad runu, inspect), run.gd:404 (nagroda), 495 (sklep), 620 (przegladarka talii). Podniesienie samego CARD_SIZE do 116x162 przelozylo by HFlowContainer 640px z 8 kart w rzedzie na 5, a talia runu rosnie do 25+ kart. Dlatego CARD_SIZE ZOSTAJE 80x112, a reka dostaje osobne HAND_CARD_SIZE przez nowy parametr build(card, px). Jesli implementujacy pojdzie na skroty i zmieni sama stala, zepsuje 4 inne ekrany.

RYZYKO 2 — PANELCONTAINER PAYTABLE ROSNACY W NIESKONCZONOSC. To ten sam mechanizm, ktory 3x wypchnal przyciski poza 720p. Wiersze paytable dostaja sufiks "(Lv%d)" gdy uklad awansuje, a PanelContainer dopasowuje sie do dzieci. Obowiazkowo: jawne _paytable.size = Vector2(200,210) + clip_contents = true + per-wiersz custom_minimum_size (184,15) + clip_text = true. Bez tego regresja wroci przy pierwszym awansie MAGNUM OPUS.

RYZYKO 3 — PULAPKA EXPAND_KEEP_SIZE. TextureRect z domyslnym expand_mode inflatuje custom_minimum_size do rozmiaru tekstury (305x512) w momencie przypisania .texture, a pozniejszy .size zostaje przyciety. Dotyczy backplate'u 700x462 i portretu 268x452. Kod juz to dokumentuje dwa razy (combat.gd:249-251, card_widget.gd:120) i mimo to zostanie zapomniane. expand_mode = EXPAND_IGNORE_SIZE MUSI byc ustawiony PRZED .texture i PRZED .size.

RYZYKO 4 — SKANY 1909 SA KREMOWE I PRZEPALA CIEMNY UI. Portret 268x452 z jasnym tlem stanie sie najjasniejszym obiektem kadru i bedzie walczyl z ciemnym HUD. Zabezpieczenie: _portrait_art.modulate = Color(0.88,0.86,0.90), backplate modulate (0.60,0.56,0.62,0.80), winieta radialna do koloru tla. To MUSI byc zweryfikowane zrzutem, nie kodem — "kod wyglada dobrze" nie jest dowodem renderu.

RYZYKO 5 — UPSCALE BACKPLATE'U 2.3x. Zrodlo 305px szerokosci rozciagniete na 700px z filtrem LINEAR to widoczna mydlana plama. Jest przyciemniona i zawiniętowana, wiec powinno ujsc, ale to jest pierwszy element do wyciecia, jesli zrzut wyjdzie brzydki — wtedy zostaje sam radialny poswiat w kolorze Aspektu regionu za portretem.

RYZYKO 6 — HOVER KARTY MOZE ZASLONIC PLYTE MATMY. Przy HOVER_SCALE 1.30 gora powiekszonej karty siega y=499, a dol plyty to y=488 — luz 11px. Twardy sufit to 1.368. Kazda zmiana ARC_DIP, HAND_Y albo CARD_H przesuwa ten rachunek. Test-straznik z kroku 9 nie zlapie tego automatycznie (to zalezy od skali runtime) — trzeba dopisac osobna asercje na (HAND_Y + 4 + dip_max + CARD_H - CARD_H*HOVER_SCALE) > PLATE_Y + 104.

RYZYKO 7 — HAND_SIZE > 8. Przy 9-10 kartach dip rosnie i karty schodza ponizej 720. Zabezpieczenie: clamp dipu do 16px we wzorze. Przy 11+ kartach rozstaw spada do ~54px i badge 30px zaczyna sie tloczyc — layout wytrzyma do 10, dalej trzeba dwuwierszowej reki. Aktualnie HAND_SIZE = 8 (combat_controller.gd:11) i nic go nie zwieksza.

RYZYKO 8 — LABEL BEZ JAWNEGO size + _pulse(). _pulse() (combat.gd:1244) robi pivot_offset = node.size * 0.5. Label pozycjonowany absolutnie, bez kontenera i bez jawnego size, ma size (0,0) do pierwszego przebiegu layoutu — pierwszy pulse obraca sie wokol lewego gornego rogu i wyglada jak glitch. Kazdy absolutnie pozycjonowany Label w _build_ui dostaje jawne .size.

RYZYKO 9 — _hand_row POZA KONTENEREM NIE DOSTANIE resized. HandFan._ready podpina relayout do sygnalu resized, bo VBox przypisywal szerokosc pozno. Po przejsciu na pozycjonowanie absolutne sygnal odpali raz przy przypisaniu size, ale kolejnosc (add_child przed czy po ustawieniu size) decyduje. Na koncu _build_ui trzeba jawnie wywolac _hand_row.relayout(false), inaczej pierwsza reka moze wyladowac spiętrzona w punkcie (0,0).

RYZYKO 10 — DLUGIE TEKSTY PL. "Odwrócony Gnijący Kultysta" (ELITE_NAME_FMT) przy foncie 26 w polu 680px, oraz regula bossa jako chip w _status_row (680px na 3 chipy). Wszystkie te Labele dostaja clip_text = true + text_overrun_behavior = TRIM_ELLIPSIS + pelny tekst w tooltipie. Bez tego tekst wyleci poza slup i nachodzi na portret.

RYZYKO 11 — _seals_row CZYTA RunState.won_aspects, KTORE MOZE JESZCZE NIE ISTNIEC. Implementacja musi uzyc obronnego odczytu (has_method / get z domyslna pusta tablica) i renderowac 5 przygaszonych pieczeci, zamiast wywalac walke, jesli agent od struktury runu jeszcze nie dodal tego pola.

RYZYKO 12 — CardWidget.build_preview STAJE SIE MARTWY. Po kasacji podgladu nie ma zadnego wywolania (zweryfikowane grepem po src/ i tools/). Usuniecie 45 linii jest bezpieczne, ale jesli ktorys rownolegly agent wlasnie dopisuje wywolanie, bedzie konflikt — sprawdzic grepem PONOWNIE tuz przed kasacja.

## FILES

- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/ui/arena_layout.gd (NOWY - wszystkie prostokaty areny jako stale)
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/ui/aspect_glyph.gd (NOWY - 5 proceduralnych symboli Aspektow)
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/combat/combat.gd (przebudowa _build_ui, _make_emblem->_make_stage, _render, kotwice FX, kasacja podgladu)
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/ui/hand_fan.gd (CARD_W/H 116x162, SPACING_MAX 90, ARC_DIP 2.4+clamp, HOVER_SCALE 1.30, RAISE_SELECTED 22, nowy wzor rozstawu)
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/cards/card_widget.gd (HAND_CARD_SIZE, build(card, px), badge rangi+symbolu, pasek koloru, skosny scrim Aspektu, twarz NATURE, kasacja build_preview)
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/data/locale/ui.csv (TALLY_TIP, SEALS_TIP)
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/ui/overlays.gd (opcjonalnie: AspectGlyph obok nazwy Aspektu w inspect)
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/tests/test_arena_layout.gd (NOWY - straznik budzetu 1280x720)

