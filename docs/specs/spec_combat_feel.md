# Odczucia walki: ceremonia i decyzje tury

> Zrodlo: panel projektowy (workflow parallaxa-feel-overhaul), Odczucia walki: ceremonia i decyzje tury.
> Dokument PROJEKTOWY -- stan wdrozenia opisuje docs/ROADMAP.md.

## Streszczenie

Walka jest "arytmetyczna", bo (1) rozliczenie zagrania to jedna liczba bez ceremonii, (2) UI nigdy nie pokazuje sufitu reki — symulacja 20k rozdan mowi, ze gracz grajacy "na pary" wyciska srednio 103 obrazen przy dostepnych 151, i przegapia gotowego Streeta/Kolor w 22,3% rak, oraz (3) na ture jest realnie ~1,3 decyzji; proponuje sekwencje punktacji karta-po-karcie (Chips i Mult jako dwa osobne liczniki), deterministyczny doradca reki ("odrzuc te 2 -> dobierzesz 7 i 8 -> Street 264"), trzy nowe osie decyzji (KLUCZ / DOBRANIE / BANK) i dwa sekretne uklady PENTAGRAM + PELNY DWOR dopisane na koncu enuma.

## SPEC

=====================================================================
0. DIAGNOZA — TWARDE LICZBY (symulacja 20 000 rozdan, talia `classic`)
=====================================================================

Talia startowa (zweryfikowana w data/cards/s_00..s_15.tres):
  rangi: 2,3,5,5,6,6,7,7,7,8,9,9,10,12,14,14
  aspekty: DEATH 5, CHAOS 4, LIFE 3, MIND 2, NATURE 2
  (uwaga: w briefie byla ranga "1" — w plikach jest 2. As nie wystepuje w starterze,
   wiec chip_value()==11 nigdy nie odpala w 1. regionie.)

Ile faktycznie da sie zrobic z reki 8 kart (najlepszy uklad 5 kart wg obrazen):
  HIGH      5,3%   PAIR 30,7%   TWO_PAIR 36,7%   THREE 4,3%
  STRAIGHT 17,0%   FLUSH 1,1%   FULL 4,9%   FOUR/SF/FIVE/MO 0,0%
  obrazenia: mediana 118, p10 98, p90 280, max 324

  -> 72,7% rak konczy sie na Dwoch Parach lub gorzej. Gracz mial RACJE.
  -> FLUSH z 5 kart jednego aspektu przy rozkladzie 5/4/3/2/2 = 1,28%
     (hipergeom.: C(5,5)*C(11,3)/C(16,8)). Kolor jest w praktyce NIEOSIAGALNY.
  -> FOUR/STRAIGHT_FLUSH/FIVE/MAGNUM_OPUS to 0% — polowa paytable to martwe wiersze.

DIAG-1 (najwazniejsza): heurystyka "szukam par" daje srednio 103 obrazen,
  optimum daje 151. Gracz zostawia 47% obrazen na stole, BO UI NIGDY NIE POKAZUJE
  SUFITU REKI. STRAIGHT jest dostepny w 16,8% rak, a gracz go nie widzi — rangi sa
  nietypowe (brak 4, 11, 13), aspektow jest 5, a karta ma 80x112 px.
  W 22,3% rak istnieje Street/Kolor+, ktorego gracz nie zagral.

DIAG-2: rozliczenie zagrania trwa 0 ms wizualnie. `_on_play()` odpala `_fly_card()`
  na wszystkich 5 kartach ZANIM cokolwiek sie policzy, potem leci jeden `_popup("-118")`.
  Nie ma miejsca, w ktorym gracz widzi, ZA CO dostal te liczbe. Chips i Mult istnieja
  wylacznie jako fragment stringa `COMBAT_PREVIEW` = "%s  %d x %.1f = %d" (18 px, jedna linia).
  W Balatro to sa dwa osobne, ROSNACE liczniki, i to jest cala gra.

DIAG-3: w Scoring.score() KAZDA zagrana karta dodaje chipsy (petla `for c in cards:
  chips += c.chip_value()`), takze te spoza ukladu. Wniosek: zagranie 5 kart jest ZAWSZE
  >= zagraniu 4. Decyzja "ile kart" nie istnieje. Zostaje "ktory uklad" = arytmetyka.

DIAG-4: realne decyzje na ture DZIS:
  1. ktore 5 z 8 (patrz DIAG-3 — zredukowane do jednej poprawnej odpowiedzi)
  2. czy odrzucic (3 odrzuty na CALA walke, czyli ~0,6 na ture) — i to na slepo
  3. blok vs obrazenia (tylko gdy w rece jest OSLONA/KORZENIE i nie ma FURII)
  Razem ~1,3 decyzji na ture, z czego 1 jest wymuszona.

DIAG-5: BUG czekajacy na dopisanie ukladow. `combat_controller.gd:193`
  `fight_best_hand = maxi(fight_best_hand, int(result["hand"]))` traktuje ordinal enuma
  jako sile ukladu, a `profile.gd:136` sprawdza `stat_best_hand >= Poker.Hand.MAGNUM_OPUS`.
  Dopisanie PENTAGRAM=11 na koncu enuma przyznaloby osiagniecie ACH_MAGNUM za Pentagram.
  MUSI byc naprawione RAZEM z pkt. D (rozwiazanie: slownik `Poker.POWER`).


=====================================================================
A. SCORING SEQUENCE — rozliczanie karta po karcie  [MUST]
=====================================================================

ZASADA NIENARUSZALNA: animacja NICZEGO nie liczy. Prawda = `Scoring.score()`.
Sekwencja dostaje gotowa liste krokow z nowej CZYSTEJ funkcji i tylko ja odtwarza.

--- A1. src/game/combat/scoring.gd — nowa funkcja czysta ---

    ## Display-only replay of the canonical pipeline. Every element is one animation beat.
    ## The LAST element's chips/mult MUST equal score()'s -- guarded by a test.
    ## step = { "kind": StringName, "card": CardData, "label_key": String, "arg": Variant,
    ##          "chips": int, "mult": float, "op": StringName }
    ##   kind: &"base" | &"card" | &"edition" | &"keyword" | &"mod" | &"relic" | &"final"
    ##   op:   &"add" (pokaz "+N") | &"mul" (pokaz "xN")
    static func breakdown(cards: Array, relics: Array, ctx: Dictionary = {}) -> Array

Implementacja: kopia petli ze `score()` z zapisem stanu (chips, mult) po KAZDYM zdarzeniu,
w dokladnie tej samej kolejnosci co komentarz kanoniczny w scoring.gd (kroki 1..10).
Na koncu `breakdown()` wola `score(cards, relics, ctx)` i NADPISUJE ostatni krok jej
wartosciami (chips/mult/damage) — dryf numeryczny jest niemozliwy z definicji.

Test w tests/test_scoring.gd (nowy): `_breakdown_reconciles()` — 12 fixture'ow
(para, kolor, glass x2, lawina+3 chaosy, kombinat streak 3, 2 reliki + MAGNIFY,
klatwa 40%, polychrome x2, spalenie, pijawka, keystone on/off, 1-kartowe zagranie).
Asercja: `steps[-1]["chips"] == r["chips"] and is_equal_approx(steps[-1]["mult"], r["mult"])`.

--- A2. src/game/combat/combat.gd — nowe wezly UI (SCORE BOX) ---

Usun `_preview_label` jako jedyny nosnik liczb. Zamiast tego w `_build_ui()`:

    _score_box: PanelContainer   # 420x74, wysrodkowany, y = 504
      _hand_name_label: Label    # 22 px, Color(0.98,0.85,0.40), CENTER
      HBoxContainer (separation 14, ALIGNMENT_CENTER):
        _chips_label: Label      # Aspects.color(MIND)  = 6ec6ff, prawy align
        _x_label:     Label      # "x", 24 px, Color(0.55,0.55,0.62)
        _mult_label:  Label      # Aspects.color(CHAOS) = ff6b57, lewy align
      _advice_label: Label       # 15 px, Aspects.color(NATURE) = 74c46b (patrz B)

Rozmiary czcionek SKALUJA SIE Z WARTOSCIA (to jest powod, dla ktorego x16 przeraza):
    _chips_label font_size = 26 + clampi(chips / 20, 0, 18)      # 26..44
    _mult_label  font_size = 26 + clampi(int(mult) * 2, 0, 22)   # 26..48

Nowe funkcje w combat.gd:
    func _set_score_readout(hand: int, chips: int, mult: float) -> void
    func _count_to(node: Label, from_v: float, to_v: float, ms: int, as_int: bool) -> void
    func _card_score_pop(panel: Control, text: String, col: Color) -> void
    func _stage_selected() -> Array           # reparent zagranych kart do _stage_row
    func _run_score_sequence(steps: Array, damage: int) -> void   # coroutine
    func _skip_score_sequence() -> void
    func _crunch(chips: int, mult: float, damage: int) -> void
    func _crunch_tier(damage: int) -> int

--- A3. STAGE ROW (rzad zagranych kart) ---

    _stage_row: HBoxContainer
      position  = Vector2(400, 398)   # 5 kart x 84 px + 4 x 12 px separation = 468 -> wysrodkowane na 640
      separation = 12
      z_index    = 3                  # zagrane karty leza NA portrecie przeciwnika

`_on_play()` NIE wola juz `_fly_card()` na starcie. Kolejnosc:
  1. `_scoring_anim = true`; `_play_btn.disabled = true`; `_discard_btn.disabled = true`
  2. `var idx := _selected_indices()`  (kolejnosc = kolejnosc KLIKANIA, juz zachowana)
  3. `var cards := []` z `controller.hand[i]` w tej samej kolejnosci
  4. `var steps := Scoring.breakdown(cards, controller.relics, controller._ctx())`
     -> potrzebny publiczny getter: `CombatController.ctx() -> Dictionary` (alias `_ctx()`)
  5. `_stage_selected()` — reparent 5 widgetow do `_stage_row`, skala 1.05, rotacja 0
  6. `await _run_score_sequence(steps, promised)`
  7. `controller.play(idx)`   <-- STAN ZMIENIA SIE DOPIERO TU
  8. `_fly_card()` na kartach ze `_stage_row` -> `_enemy_fx_pos()`
Determinizm nietkniety: `play()` nie zalezy od czasu, testy wolaja controller bezposrednio.

--- A4. CZASY (stale w combat.gd) ---

    const SEQ_STEP_MS       := 110    # jeden beat (karta / modyfikator), tempo normalne
    const SEQ_STEP_FAST_MS  := 45     # Juice.fast_pace()
    const SEQ_STEP_MIN_MS   := 34
    const SEQ_MAX_TOTAL_MS  := 2000   # twardy sufit calej sekwencji przed crunchem
    const SEQ_HOLD_MS       := 260    # cisza przed zwarciem Chips x Mult
    const SEQ_CRUNCH_MS     := 420    # rolka licznika do finalnej liczby

    func _step_ms(count: int) -> int:
        var cap: int = SEQ_STEP_FAST_MS if Juice.fast_pace() else SEQ_STEP_MS
        return clampi(SEQ_MAX_TOTAL_MS / maxi(count, 1), SEQ_STEP_MIN_MS, cap)

Typowe zagranie 5 kart bez edycji: 1 base + 5 card + 2 mod = 8 krokow
  -> 8 x 110 + 260 + 420 = 1,56 s  (fast pace: 8 x 45 + 130 + 210 = 0,70 s)
Zagranie ekstremalne (5 kart, 3 edycje, lawina, furia, kombinat, 2 glass, 3 reliki,
polychrome, klatwa) = ~22 kroki -> 22 x 90 (skompresowane) + hold + crunch = 2,66 s.

SKIP: `_unhandled_input` — LMB / KEY_SPACE / KEY_ENTER podczas `_scoring_anim`
wola `_skip_score_sequence()`: `_seq_tween.kill()`, natychmiast `_set_score_readout(final)`,
`_crunch()` bez hitstopu. Zawsze dostepne, nigdy nie blokuje.

REDUCE MOTION (`Juice.reduce_motion()`): `_step_ms` -> 0, brak podskokow kart,
crunch bez zoomu/shake'u, ale liczniki NADAL pokazuja koncowe Chips i Mult (czytelnosc
nie jest efektem, jest informacja).

--- A5. CO SIE DZIEJE W JEDNYM KROKU ---

kind == &"card":
  - `Juice.punch(stage_panel, 1.18, 90)` — karta podskakuje w miejscu (pivot bottom-center)
  - `_card_score_pop(panel, "+%d" % d_chips, Aspects.color(Aspects.Id.MIND))`
    -> Label 20 px, start 26 px NAD karta, tween pozycja y-30 / alpha 1->0 w 420 ms
  - `_count_to(_chips_label, prev_chips, step.chips, ms, true)` + `Juice.punch(_chips_label, 1.12, 70)`
  - `Sfx.play(&"chip_tick", -12.0, 1.00 + 0.06 * step_index)`   # pitch ROSNIE z krokiem
kind == &"keyword"/&"edition" z op == &"mul":
  - pop tekstem "x%s" w Aspects.color(CHAOS), `_count_to(_mult_label, ...)`,
    `Sfx.play(&"mult_tick", -10.0, 1.0 + 0.04 * step_index)`
kind == &"relic":
  - dodatkowo `Juice.punch(relic_chip_node, 1.25, 110)` — widac KTORY relik zadzialal
kind == &"final" (crunch):
  - `await get_tree().create_timer(SEQ_HOLD_MS/1000.0).timeout`
  - `_x_label` skaluje sie do 1.6 i wraca (zwarcie)
  - `_count_to(damage_label, 0, damage, SEQ_CRUNCH_MS, true)`
  - `_crunch(chips, mult, damage)` — tabela tierow z pkt. E


=====================================================================
B. HAND-QUALITY FEEDBACK — gracz WIDZI sufit reki  [MUST]
=====================================================================

--- B1. NOWY PLIK: src/game/combat/hand_advisor.gd ---

    class_name HandAdvisor
    ## Pure, deterministic hand analysis. Uses Scoring.score() so the advice can NEVER
    ## disagree with the preview (the covenant). No RNG, no combat state mutation.

    const MAX_PLAN_MS := 8            ## hard budget for the discard planner
    const ADVICE_GAIN_MIN := 1.25     ## show a discard hint only if it gains >= +25% damage

    ## Best 5-card subset of `hand` by SCORED damage. C(8,5) = 56 Scoring.score() calls,
    ## ~11k ops, < 0.5 ms. Returns { "idx": Array[int], "hand": int, "damage": int }.
    static func best_play(hand: Array, relics: Array, ctx: Dictionary) -> Dictionary

    ## The EXACT deterministic discard plan. Because peek_draw() is truth, this hint is not
    ## a probability -- it is a promise. Tries k = 1..3 (only k <= discards_left), each with
    ## C(8,k) subsets (8 + 28 + 56 = 92 max), replacing them with controller.peek_draw(k).
    ## Returns {} or { "discard": Array[int], "k": int, "hand": int, "damage": int }.
    static func plan_discard(hand: Array, peek: Array, discards_left: int,
                             relics: Array, ctx: Dictionary) -> Dictionary

    ## Sort orders for the hand row (cosmetic only; scoring order stays the CLICK order).
    enum Sort { DEALT, RANK, ASPECT }
    static func sorted_order(hand: Array, mode: int) -> Array   ## returns a permutation

Budzet: `plan_discard` przerywa petle gdy `Time.get_ticks_usec() - t0 > MAX_PLAN_MS * 1000`
i zwraca najlepszy znaleziony wynik. Uruchamiane RAZ na zmiane reki, nie co klatke.

--- B2. Cache w combat.gd ---

    var _advice: Dictionary = {}
    var _advice_key: String = ""
    func _refresh_advice() -> void:
        var key := ""
        for c in controller.hand:
            key += "%d," % c.get_instance_id()
        key += "|%d" % controller.discards_left
        if key == _advice_key:
            return
        _advice_key = key
        _advice = {
            "best": HandAdvisor.best_play(controller.hand, controller.relics, controller.ctx()),
            "plan": HandAdvisor.plan_discard(controller.hand, controller.peek_draw(3),
                     controller.discards_left, controller.relics, controller.ctx()),
        }
Wolane na koncu `_reconcile_hand()`.

--- B3. Podswietlenie najlepszego ukladu ---

    CardWidget.set_ghost(panel: PanelContainer, on: bool) -> void
      # ramka 2 px w Color(0.98, 0.82, 0.35, 0.45) + bg_color Color(0.13,0.12,0.10)
      # WYRAZNIE inna od zaznaczenia (tam: pelne zloto 3 px + BG_SEL)

    combat.gd: func _show_best_hint(on: bool) -> void
      # nakłada set_ghost na karty z _advice["best"]["idx"]
      # + _advice_label.text = tr("ADVICE_BEST_FMT") % [tr(Poker.name_key(h)), dmg]

WYZWALACZE (nie niania — opt-in):
  - przytrzymanie TAB (`_input`, KEY_TAB pressed/released) — zawsze
  - automatycznie przez pierwsze 3 walki profilu: `Profile.life["fights"] < 3`
  - przycisk "?" obok przycisku Uklady (bottom-anchored, patrz zasada layoutu)

--- B4. Podpowiedz odrzutu (to jest ta rzecz, ktorej nie ma nikt inny) ---

    _advice_label.text = tr("ADVICE_DISCARD_FMT") % [k, tr(Poker.name_key(h)), dmg]
Widoczna gdy `plan["damage"] >= best["damage"] * HandAdvisor.ADVICE_GAIN_MIN`.
Hover na `_advice_label` -> karty do odrzucenia dostaja `set_ghost` w kolorze
Color(1.0, 0.45, 0.40, 0.45); klik -> zaznacza je i ustawia focus na `_discard_btn`.

DLACZEGO TO DZIALA: talia jest deterministyczna, `peek_draw(k)` mowi prawde.
Podpowiedz brzmi "Odrzuc 2 -> dobierzesz 7 i 8 -> Street (264)", a nie "sprobuj szczescia".
Odrzut przestaje byc reroll'em, staje sie ZAGADKA. Symulacja: 13,0% rak jest DOKLADNIE
jeden odrzut od Koloru, 22,3% ma juz w sobie uklad, ktorego gracz nie widzi.

--- B5. Sortowanie reki ---

    CombatController.reorder_hand(order: Array) -> bool
      ## Validates `order` is a permutation of hand indices; applies it. Cosmetic only:
      ## _refill() always appends, and play()/discard() resolve indices at call time.
      ## Returns false (no-op) on a bad permutation -- guarded by a test.

    combat.gd `_input`: KEY_R -> Sort.RANK, KEY_A -> Sort.ASPECT, KEY_D -> Sort.DEALT
    (aktywne tylko gdy `controller.phase == "player"` i `not _scoring_anim`)
    Po sorcie: `_reconcile_hand()` + `Sfx.play(&"hand_sort", -14.0)`.
    Podpowiedz w `_help_label`: klucz `SORT_HINT`.
    Nowe akcje w project.godot [input]: `hand_sort_rank` (R), `hand_sort_aspect` (A),
    `hand_sort_dealt` (D), `hand_peek_best` (TAB).

--- B6. Karty musza byc CZYTELNE (bezposrednio z briefu) ---

    hand_fan.gd:  CARD_W 80 -> 104,  CARD_H 112 -> 146,  SPACING_MAX 74 -> 92,
                  HOVER_SCALE 1.45 -> 1.30 (przy wiekszej karcie 1,45 wychodzi poza kadr),
                  custom_minimum_size.y 148 -> 186
    card_widget.gd: CARD_SIZE = Vector2(104, 146); badge rangi 22x22 -> 28x28,
                  font rangi 16 -> 20; nowy element: PIP ASPEKTU (patrz nizej)
    Nowa funkcja: `CardWidget._add_aspect_pip(panel, card, col)` — kolo 18 px w prawym
    gornym rogu wypelnione `Aspects.color(card.aspect)` z symbolem 12 px:
      LIFE "♥"  MIND "♦"  DEATH "♠"  CHAOS "♣"  NATURE "✿"
    (znaki z fontu monogram; jesli brak glifu — fallback na pierwsza litere klucza aspektu).
    To jest odpowiedz na "karty powinny miec widoczne kolory i symbole tego koloru".
    Usun podglad po prawej: `_show_card_preview` / `_hide_card_preview` / `_preview_node`
    znikaja z combat.gd (hover + RMB->Overlays.inspect wystarczaja) — brief mowi to wprost.
    Budzet 720p po zmianach: portret do y=430, stage row 398..544, score box 504..578
    (nachodzi na stage row -> score box przenosimy na y=548), reka 566..752 — NIE MIESCI SIE.
    KOREKTA: reka na y=560 z wysokoscia 186 konczy sie na 746 > 720.
    Ostateczny budzet: HandFan.custom_minimum_size.y = 168, karta 96x134, SPACING_MAX 86,
      portret 100..420, stage row y=386 (karty 96x134 -> do 520), score box y=470..534,
      reka y=540..708, przyciski bottom-anchored 686..714 (bez zmian).
    Karta 96x134 to +44% powierzchni wzgledem 80x112 — wystarczajaco.


=====================================================================
C. DECYZJE NA TURE — z 1,3 do 4  [KLUCZ i DOBRANIE = MUST, BANK = NICE]
=====================================================================

--- C1. OS 1: KLUCZ (Keystone) — pozycja ma znaczenie  [MUST] ---

Minimalna wersja pkt. 1 z todo.md, zero nowych struktur: OSTATNIA karta w kolejnosci
zagrania (najbardziej na prawo w stage row) jest KLUCZEM.
  - jej `chip_value()` liczy sie x2
  - liczbowa wartosc jej slowa kluczowego liczy sie x2
    (OSLONA, KORZENIE, OPATRZNOSC, GNICIE, SPALENIE, ECHO, BUJNOSC, SYMBIOZA, PIJAWKA, KLATWA)
  - slowa MNOZACE (FURIA, PRZECIAZENIE, KOMBINAT, LAWINA, ZNIWO) sa NIEZMIENIONE
    — swiadomie, zeby nie wysadzic krzywej (x2 na x2 glass = x8 z jednego klikniecia)

scoring.gd:
    var key_card: CardData = null
    if bool(ctx.get("keystone", false)) and cards.size() >= 2:
        key_card = cards[cards.size() - 1]
    # w petli: var w: int = 2 if c == key_card else 1
    #   chips += c.chip_value() * w ; retrig_total += c.chip_value() * w
    #   flat keywords: c.keyword_value * w
DOMYSLNIE `false` -> wszystkie 261 linii tests/test_scoring.gd zostaja co do jednostki.
`CombatController.ctx()` ustawia `"keystone": true`. Sprawdzone: tests/test_combat.gd
gra 2 karty tylko w linii 241 (`play([0,1])`, asercja o podatku Sadu, nie o obrazeniach)
— test przechodzi bez zmian.

UI: karta na pozycji 5 (i tylko ona) dostaje zlota plakietke `tr("KEYSTONE_TAG")` = "KLUCZ",
kazda zaznaczona karta dostaje pip z numerem kolejnosci 1..5 (18 px, prawy dolny rog).
Nowa funkcja `CardWidget.set_order_pip(panel, n: int, is_key: bool)`.
Zmiana kolejnosci: przeciagniecie zaznaczonej karty w stage row w lewo/prawo
(`_stage_row.move_child`) + lustrzana zmiana w `_selected` -> `_update_selection_ui()`.
Podglad przelicza sie natychmiast, wiec gracz WIDZI roznice miedzy ustawieniami.
Efekt: "ktore 5 kart" (1 poprawna odpowiedz) staje sie "ktore 5 i ktora ostatnia" (5 odpowiedzi).

--- C2. OS 2: DOBRANIE (Overdraw) — push-your-luck z jawna cena  [MUST] ---

combat_controller.gd:
    const OVERDRAW_TAX_PCT := 50      ## next enemy intent +50%, rounded up
    var overdraws_left: int = 1       ## +1 per ArcanumData.Effect.EXTRA_OVERDRAW relic
    var overdraw_tax: int = 0         ## surcharge on the NEXT enemy turn only

    func overdraw() -> void:
        if phase != "player" or overdraws_left <= 0:
            return
        overdraw_tax += ceili(current_intent() * OVERDRAW_TAX_PCT / 100.0)
        overdraws_left -= 1
        var all_idx: Array = []
        for i in hand.size():
            all_idx.append(i)
        _move_to_used(all_idx)
        _refill()
        message.emit("LOG_OVERDRAW", [overdraw_tax])
        state_changed.emit()

`_intent_at(idx)` NIE zmieniany. Doliczenie w `resolve_enemy_turn()` obok
`_pact_surcharge()`: `taken += overdraw_tax` gdy `incoming > 0`, potem `overdraw_tax = 0`.
`intent_shown()` i `predicted_taken()` dodaja `overdraw_tax` — kokpit pokazuje cene
NATYCHMIAST po nacisnieciu, zanim gracz zagra. Podglad nie klamie.
Reset w `start()`: `overdraws_left = 1 + _bonus_overdraws()`, `overdraw_tax = 0`.

UI: trzeci przycisk w `crow` (bottom-anchored!), tekst `tr("OVERDRAW_BTN") % overdraws_left`,
tooltip `tr("OVERDRAW_COST_FMT") % ceili(current_intent()*0.5)`, disabled przy 0.
Dlaczego to jest decyzja: talia ma 16 kart, reka 8. Dobranie pokazuje DRUGA POLOWE TALII.
Przy telegrafie "next: 0 (REST)" dobranie jest darmowe -> gracz zaczyna czytac wyprzedzenie.
Test w tests/test_combat.gd: `_overdraw_check()` — intent 20, overdraw -> `predicted_taken()`
== 30, po turze `overdraw_tax == 0` i nastepny intent bez doplaty.

--- C3. OS 3: BANK — nakrecanie tury  [NICE] ---

    CombatController.bank(selected: Array) -> void
      ## Convert this play into stored chips instead of damage. 60% conversion.
      ## banked_chips = int(chips * mult * 0.60); expires after ONE play or at end of turn.
    Scoring: `chips += int(ctx.get("banked", 0))` PRZED mnozeniem przez mult.
    Bank oplaca sie tylko gdy mult nastepnego zagrania >= 1,67x obecnego —
    czyli gdy gracz WIDZI (peek_draw + doradca), ze za ture bedzie Kolor/Street.
    Sprzega sie z istniejacym telegrafem "REST_TELEGRAPH" i "WINDUP_TELEGRAPH".
    To jest os "Marvel Snap": zjadam ture, zeby nastepna byla dwa razy wieksza.
    NICE, bo dotyka Scoring i wymaga osobnej kalibracji z agentem od balansu.


=====================================================================
D. SEKRETNE UKLADY: PENTAGRAM i PELNY DWOR  [MUST]
=====================================================================

--- D1. Enum (APPEND-ONLY, dwie nowe pozycje na koncu) ---

    enum Hand { HIGH_CARD, PAIR, TWO_PAIR, THREE, STRAIGHT, FLUSH, FULL_HOUSE, FOUR,
                STRAIGHT_FLUSH, FIVE, MAGNUM_OPUS, PENTAGRAM, FULL_COURT }
                                                    #  ^ 11        ^ 12
Zapisane .tres nie przechowuja Poker.Hand — jedynym miejscem, gdzie ordinal jest
zapisywany, jest `RunState.stat_best_hand` w save runu. Bezpieczne.

--- D2. NOWY slownik POWER (naprawia DIAG-5) ---

    ## Ranking strength, decoupled from the enum ordinal (which is append-only and therefore
    ## NOT ordered by power). Every "which hand is better" comparison must go through this.
    const POWER: Dictionary = {
        Hand.HIGH_CARD: 0, Hand.PAIR: 10, Hand.TWO_PAIR: 20, Hand.THREE: 30,
        Hand.STRAIGHT: 40, Hand.FLUSH: 50, Hand.PENTAGRAM: 55, Hand.FULL_HOUSE: 60,
        Hand.FOUR: 70, Hand.STRAIGHT_FLUSH: 80, Hand.FULL_COURT: 85,
        Hand.FIVE: 90, Hand.MAGNUM_OPUS: 100,
    }
    static func by_power() -> Array   ## hands sorted ascending -- paytable row order

WYMAGANE POPRAWKI:
  combat_controller.gd:193
    - `fight_best_hand = maxi(fight_best_hand, int(result["hand"]))`
    + `if Poker.POWER[int(result["hand"])] > Poker.POWER[fight_best_hand]:
           fight_best_hand = int(result["hand"])`
  profile.gd:136
    - `if RunState.stat_best_hand >= Poker.Hand.MAGNUM_OPUS ...`
    + `if RunState.stat_best_hand == Poker.Hand.MAGNUM_OPUS ...`
  combat.gd:494 `for hand in Poker.BASE:`  ->  `for hand in Poker.by_power():`
  overlays.gd:132 to samo.

--- D3. Wartosci ---

    Hand.PENTAGRAM:  [35, 4]     # LUSTRO KOLORU: Flush = 5 x jeden aspekt (35x4),
                                 # Pentagram = 5 x kazdy inny aspekt (35x4). Paytable czyta
                                 # sie jak para przeciwienstw — zapamietywalne.
    Hand.FULL_COURT: [100, 9]    # Paz + Rycerz + Krolowa + Krol (rangi 11,12,13,14) + 1 dowolna
    LEVEL_UP:
    Hand.PENTAGRAM:  [15, 2]     # jak FLUSH
    Hand.FULL_COURT: [40, 3]
    NAME_KEYS: PENTAGRAM -> "HAND_PENTAGRAM", FULL_COURT -> "HAND_FULL_COURT"
    const SECRET: Array = [Hand.MAGNUM_OPUS, Hand.PENTAGRAM, Hand.FULL_COURT]

Typowe liczby (5 kart o sredniej wartosci chipow 7,1 = 36 chipow z kart):
    TWO_PAIR   (20+36)*2  = 112     FLUSH      (35+36)*4  = 284
    THREE      (30+36)*3  = 198     PENTAGRAM  (35+36)*4  = 284
    STRAIGHT   (30+36)*4  = 264     FULL_HOUSE (40+36)*4  = 304
    FOUR       (60+36)*7  = 672     FULL_COURT (100+47)*9 = 1323

--- D4. Detekcja w Poker.evaluate() (kolejnosc = malejaca POWER) ---

    static func _is_pentagram(cards: Array) -> bool:
        if cards.size() != 5: return false
        var seen := {}
        for c in cards: seen[c.aspect] = true
        return seen.size() == 5
    static func _is_full_court(cards: Array) -> bool:
        var ranks := {}
        for c in cards: ranks[c.rank] = true
        return ranks.has(11) and ranks.has(12) and ranks.has(13) and ranks.has(14)

Kolejnosc sprawdzen w evaluate() (wstawki oznaczone +):
    top==5 and flush -> MAGNUM_OPUS
    top==5           -> FIVE
  + _is_full_court() -> FULL_COURT           # nad SF: 1323 > 1200 nawet w skrajnym przypadku
    flush and straight -> STRAIGHT_FLUSH
    top==4           -> FOUR
    full house       -> FULL_HOUSE           # 304 > 284, wiec full bije pentagram
  + _is_pentagram()  -> PENTAGRAM
    flush            -> FLUSH                # pentagram i flush wykluczaja sie z definicji
    ... reszta bez zmian
Uwaga do udokumentowania w komentarzu: teczowy full house punktuje jako FULL_HOUSE
(wieksze obrazenia) i traci efekt Pentagramu. Deterministyczne i widoczne w podgladzie.

--- D5. UNIKALNY EFEKT PENTAGRAMU (to co todo.md nazywa "gigantycznym") ---

Sila Pentagramu NIE jest w obrazeniach (bo 284 == Kolor), tylko w tempie:
    Scoring.score() zwraca dodatkowo `"discard_refund": 1` gdy hand == PENTAGRAM
    CombatController.play(): `discards_left += int(result.get("discard_refund", 0))`
Efekt: Pentagram vs Full House to REALNY WYBOR (304 obrazen vs 284 + odrzut z powrotem),
a nie arytmetyka. Doradca (B1) wybiera po obrazeniach i pokaze Full House — gracz moze
zdecydowac inaczej. To jest dokladnie ta decyzja, ktorej brakuje.
Rozszerzenie na potem (NICE): `"rule_silence": 1` — zasada bossa nie dziala przez jedna
ture przeciwnika (todo.md "przelamanie pancerza bossa").

--- D6. ODKRYWANIE ---

    profile.gd:
      var discovered_hands: Array = []       ## Poker.Hand ints, append-only
      func discover_hand(h: int) -> bool     ## returns true the FIRST time only
      # zapis: cf.set_value("meta", "discovered_hands", discovered_hands) obok "achievements"
      # wczytanie w tej samej sekcji; brak klucza -> [] (stare profile dzialaja)

    combat.gd `_refresh_paytable_values()`:
      var secret_hidden := hand in Poker.SECRET and not Profile.discovered_hands.has(hand)
      row.text = tr("HAND_UNKNOWN") if secret_hidden else "<normalny wiersz>"
      # WIERSZ ZOSTAJE — gracz widzi, ze cos tam jest. To jest haczyk.

    combat.gd `_on_play()` po `controller.play(idx)`:
      var h := int(controller.last_score.get("hand", -1))
      if h in Poker.SECRET and Profile.discover_hand(h):
          _discovery_reveal(h)      # nowa funkcja, wzorowana na _magnum_reveal()

    func _discovery_reveal(hand: int) -> void
      # ColorRect dim 0.55 + tr("DISCOVERY_TITLE") 28 px + tr(Poker.name_key(hand)) 64 px
      # + wiersz "chips x mult" 20 px, zoom-in 0.6->1.0 w 300 ms (TRANS_BACK),
      # Sfx.play(&"discover", -2.0), Juice.flash(_fx, Color(1,0.9,0.5,0.35), 0.5),
      # 1,8 s hold, fade 0,5 s. Istniejacy _magnum_reveal() staje sie
      # _discovery_reveal(Hand.MAGNUM_OPUS) — jedna sciezka zamiast dwoch.

KLUCZOWE: podglad (COMBAT_PREVIEW / score box) POKAZUJE prawdziwe liczby zaraz po
zaznaczeniu 5 kart, nawet gdy uklad jest nieodkryty. Ukryty jest TYLKO wiersz w
tabeli referencyjnej. Przymierze "karty nie klamia" jest nietkniete, a moment
"zaraz, CO?!" na hoverze jest dokladnie ta radoscia, ktorej gracz nie czuje.

    run.gd:20-21 STAR_HANDS — dopisz `Poker.Hand.PENTAGRAM`, ale filtruj oferte sklepu:
      `if h in Poker.SECRET and not Profile.discovered_hands.has(h): continue`
      (sklep nie moze zdradzic ukladu przed odkryciem). FULL_COURT i MAGNUM_OPUS
      zostaja poza STAR_HANDS.

--- D7. SPRZEZENIE Z BALANSEM (przekazac agentowi od tresci — liczby gotowe) ---

Symulacja 15k rozdan startowych z PENTAGRAM 35x4 wlaczonym:
    PAIR 17%  TWO_PAIR 20%  THREE 3%  STRAIGHT 7%  FULL 4%  PENTAGRAM ~44%
    mediana obrazen 118 -> 272,  srednia 151 -> 220
Powod: talia startowa ma wszystkie 5 aspektow, wiec zestaw 5 roznych aspektow istnieje
w 45,5% rak 8-kartowych. To jest CECHA, nie blad — starter staje sie "talia Pentagramu",
a Kolor jest czyms, co sie BUDUJE (i to domyka luk fabularny "5 biomow, 5 kolorow").
Ale realne obrazenia gracza rosna z ~103 (gra naiwna, dzis) do ~272 (gra z doradca).

KONKRET DLA BALANSU: pomnozyc `EnemyData.max_hp` KAZDEGO wroga x2,4 i zaokraglic do 10,
BEZ ruszania `intents`. Dlugosc walki i przyjmowane obrazenia zostaja identyczne.
    enemy_a 520 -> 1250, enemy_b 460 -> 1100, enemy_elite_r1 680 -> 1630,
    boss_chariot 560 -> 1340, boss_world 1300 -> 3120.
Alternatywa, jesli balans woli nie ruszac HP: PENTAGRAM = [25, 3] (=(25+36)*3 = 183,
mediana ~190) — wtedy uklad przestaje byc "gigantyczny" i traci sens jako sekret.
REKOMENDACJA: mnoznik HP. Duzy uklad MA czuc sie duzo.


=====================================================================
E. DZWIEK I EKRAN  [MUST]
=====================================================================

--- E1. src/game/audio/sfx.gd — 5 nowych klipow w `_register_all()` ---

    am.register(&"chip_tick", _wav(_tone(880, 0.035, 0.13, 1180)))
    am.register(&"mult_tick", _wav(_tone(220, 0.060, 0.22, 300)))
    am.register(&"crunch",    _wav(_mix(_noise(0.28, 0.34), _tone(140, 0.28, 0.40, 46))))
    am.register(&"discover",  _wav(_seq([_tone(660, 0.08, 0.20), _tone(880, 0.08, 0.20),
                                          _tone(1320, 0.22, 0.24)])))
    am.register(&"hand_sort", _wav(_tone(500, 0.04, 0.10, 620)))

Chipsy i Mult MUSZA brzmiec inaczej (880 Hz rosnaco vs 220 Hz) — inaczej sekwencja
jest jednostajnym klekotem. Wysokosc dzwieku chipow rosnie z indeksem kroku
(`pitch = 1.00 + 0.06 * i`, po 10 krokach 1,60x) — narastanie robi napiecie za darmo.

--- E2. src/game/ui/juice.gd — 3 nowe prymitywy ---

    ## Scale punch used by every counter, card and relic chip in the scoring sequence.
    static func punch(node: Control, amount: float = 1.18, ms: float = 90.0) -> void
        # pivot_offset = size * 0.5; scale -> amount, powrot TRANS_BACK/EASE_OUT
        # no-op przy reduce_motion()

    ## The screen leans in: pushes the whole combat root's scale and returns it.
    static func zoom(node: Control, amount: float = 1.04, ms: float = 140.0) -> void
        # pivot_offset = Vector2(640, 360); no-op przy reduce_motion()

    ## Shader-free radial vignette pulse (GradientTexture2D, fill_mode RADIAL) -- the
    ## "big hit" tint without touching the CRT stack.
    static func vignette_pulse(host: Control, col: Color, ms: float = 320.0) -> void
        # no-op przy flash_disabled()

--- E3. TABELA ESKALACJI CIOSU (combat.gd) ---

    ## [dmg_min, hitstop_s, shake_px, flash_alpha, zoom, sfx_db]
    const CRUNCH_TIERS: Array = [
        [   0, 0.00,  0.0, 0.00, 1.00, -9.0],
        [ 120, 0.06,  5.0, 0.12, 1.02, -5.0],
        [ 300, 0.10,  9.0, 0.22, 1.04, -2.0],
        [ 600, 0.14, 14.0, 0.32, 1.06,  0.0],
        [1200, 0.20, 20.0, 0.45, 1.09,  0.0],
    ]
    func _crunch_tier(damage: int) -> int   ## index into CRUNCH_TIERS

    func _crunch(chips: int, mult: float, damage: int) -> void:
        var t: Array = CRUNCH_TIERS[_crunch_tier(damage)]
        Juice.hitstop(float(t[1]))
        Juice.shake(self, float(t[2]))
        Juice.flash(_fx, Color(1.0, 0.86, 0.55, float(t[3])), 0.35)
        Juice.zoom(self, float(t[4]), 150.0)
        Juice.vignette_pulse(_fx, Aspects.color(Aspects.Id.CHAOS), 320.0)
        Sfx.play(&"crunch", float(t[5]), clampf(1.15 - damage / 900.0, 0.62, 1.15))
        if damage >= 1200:
            Sfx.play(&"win", -6.0, 1.35)   # warstwa "to bylo nielegalne"
        _emblem_hit()

Dzis `_on_message("LOG_PLAY")` robi shake dopiero od 150 obrazen i tylko przez `_popup`.
Po zmianie: KAZDY cios ma swoj tier, granica 120/300/600/1200 pokrywa sie z realnym
rozkladem (p10 98, mediana 272, p90 470, boss ~1300) — gracz w jednej walce przechodzi
przez 3 rozne tiery i CZUJE roznice miedzy para a Pentagramem.
`LOG_PLAY` w `_on_message` traci swoj `_popup`/`Sfx`/`_shake` (przenosi je `_crunch`),
zeby cios nie odpalal sie dwa razy.

--- E4. Klucze do data/locale/ui.csv (parzystosc %d/%s sprawdzona) ---

    SCORE_CHIPS,Chips,Żetony
    SCORE_MULT,Mult,Mnożnik
    ADVICE_BEST_FMT,Best in hand: %s (%d),Najlepszy w ręce: %s (%d)
    ADVICE_DISCARD_FMT,Discard %d -> %s (%d),Odrzuć %d -> %s (%d)
    HAND_PENTAGRAM,Pentagram,Pentagram
    HAND_FULL_COURT,Full Court,Pełny Dwór
    HAND_UNKNOWN,??? undiscovered,??? nieodkryty
    DISCOVERY_TITLE,NEW HAND DISCOVERED,NOWY UKŁAD ODKRYTY
    KEYSTONE_TAG,KEY,KLUCZ
    KEYSTONE_TIP,Last card played: double chips and keyword value.,Ostatnia zagrana karta: podwójne żetony i wartość słowa kluczowego.
    OVERDRAW_BTN,Overdraw (%d),Dobranie (%d)
    OVERDRAW_COST_FMT,Next hit +%d,Następny cios +%d
    LOG_OVERDRAW,Overdraw: next hit +%d,Dobranie: następny cios +%d
    PENTAGRAM_REFUND,+1 discard,+1 odrzut
    SORT_HINT,R rank / A aspect / D dealt / TAB best,R ranga / A aspekt / D kolejność / TAB najlepszy


=====================================================================
F. KOLEJNOSC WDROZENIA
=====================================================================

MUST (naprawia brief, w tej kolejnosci — kazdy krok jest osobnym commitem):
  1. Poker.POWER + naprawa DIAG-5 (fight_best_hand, profile.gd:136) — samodzielne, 0 ryzyka
  2. Scoring.breakdown() + test _breakdown_reconciles()  — czysta funkcja, testowalna headless
  3. Score box (chips/mult jako dwa liczniki) + stage row + _run_score_sequence + skip
  4. Sfx chip_tick/mult_tick/crunch + Juice.punch/zoom/vignette_pulse + CRUNCH_TIERS
  5. Powiekszenie kart (96x134), pip aspektu, usuniecie podgladu po prawej
  6. HandAdvisor + podswietlenie najlepszego ukladu (TAB) + podpowiedz odrzutu
  7. Sortowanie reki (reorder_hand + R/A/D) + test permutacji
  8. PENTAGRAM + FULL_COURT + odkrywanie (Profile.discovered_hands) + _discovery_reveal
  9. KLUCZ (ctx["keystone"]) + pipy kolejnosci + przeciaganie w stage row
 10. DOBRANIE (overdraw) + test _overdraw_check()
 11. Przekazanie balansowi: mnoznik HP x2,4 (pkt D7)

NICE (po weryfikacji, ze petla juz cieszy):
  - BANK (C3)
  - PENTAGRAM "rule_silence" (D5)
  - Scoring: karty spoza ukladu za 50% chipow (naprawia DIAG-3, ale przelicza caly balans)
  - chromatic aberration na crunchu (wymaga shadera, kolizja z CRT)


## RISKS

RYZYKO 1 (wysokie) — DIAG-5, cichy blad osiagniec. `combat_controller.gd:193` uzywa `maxi()` na ordinalu enuma jako mierze sily ukladu, a `profile.gd:136` sprawdza `stat_best_hand >= Poker.Hand.MAGNUM_OPUS`. Dopisanie PENTAGRAM=11 przyzna ACH_MAGNUM za zagranie Pentagramu i zepsuje statystyke "najlepszy uklad" w kazdym zapisie runu. Slownik `Poker.POWER` + zmiana obu miejsc MUSI wejsc PRZED enumem, osobnym commitem.

RYZYKO 2 (wysokie) — sprzezenie z balansem. PENTAGRAM 35x4 podnosi mediane obrazen z reki startowej ze 118 na 272, a realne obrazenia gracza (naiwna gra + brak doradcy) ze 103 na 272, czyli x2,6. Bez mnoznika HP x2,4 (pkt D7) region 1 padnie w 2 tury i "brak radosci" zamieni sie w "za latwo". Punkty D i D7 sa jedna zmiana, nie dwiema — nie wolno ich rozdzielic miedzy commity.

RYZYKO 3 (srednie) — budzet 720p i 3x softlock w historii. Powiekszenie kart do 96x134 + stage row + score box zjada ~170 px pionu. Wyliczony budzet (portret 100..420, stage 386..520, score box 470..534, reka 540..708) MIESCI sie tylko przy HandFan.custom_minimum_size.y = 168 i przyciskach zostawionych jako `anchor_top/bottom = 1.0` overlay poza flow. Kazda kolejna linia w kolumnie srodkowej (nowy tag Klucza, linia doradcy, wiersz Pentagramu) musi isc do `_fx` jako element pozycjonowany, NIGDY do `root` VBoxa.

RYZYKO 4 (srednie) — `_on_play()` odracza `controller.play(idx)` o 0,7-2,7 s. W tym oknie gracz moze kliknac Zagraj/Odrzuc/karte drugi raz albo walka moze sie skonczyc. Wymagany twardy gate: `_scoring_anim` sprawdzany na wejsciu `_on_play`, `_on_discard`, `_on_card_input`, `_toggle_paytable` i `_input` (sort), plus `_play_btn.disabled = true` na czas sekwencji, plus `if controller == null or controller.phase != "player": return` po `await`. Bez tego mozliwe podwojne zagranie tych samych indeksow.

RYZYKO 5 (srednie) — koszt CPU doradcy. `plan_discard` w najgorszym przypadku to 92 podzbiory x C(8,5)=56 wywolan `Scoring.score()` = 5152 wywolan. Bez cache i bez budzetu czasowego (`MAX_PLAN_MS = 8`) to widoczna zadyszka przy kazdej zmianie reki. Cache musi byc kluczowany po `get_instance_id()` kart ORAZ po `discards_left` (plan zalezy od liczby dostepnych odrzutow).

RYZYKO 6 (niskie) — `ctx["keystone"]` domyslnie `false`. Jesli ktos ustawi domyslnie `true` w `Scoring.score()`, wszystkie asercje chipow w tests/test_scoring.gd (linie 70, 81, 113, 145, 206) rozjada sie o wartosc ostatniej karty. Domyslna wartosc `false` i ustawienie `true` wylacznie w `CombatController.ctx()` jest warunkiem koniecznym. Sprawdzone: tests/test_combat.gd gra 2+ karty tylko w linii 241 i nie asertuje tam obrazen — przechodzi bez zmian.

RYZYKO 7 (niskie) — `reorder_hand()` mutuje `hand`, ktore jest zrodlem indeksow dla `play()`/`discard()`. Bezpieczne tylko dlatego, ze `_selected_indices()` przelicza indeksy z `CardData` w momencie klikniecia przycisku, a nie w momencie zaznaczenia. Kazda przyszla zmiana, ktora zacache'uje indeksy, zlamie sortowanie. Wymagany komentarz-ostrzezenie w `reorder_hand()` i test na odrzucenie nie-permutacji.

RYZYKO 8 (niskie) — parzystosc %d/%s w ui.csv. `ADVICE_DISCARD_FMT` ma trzy argumenty (%d, %s, %d) w obu kolumnach; Godot nie rzuca bledu przy rozjezdzie, tylko oddaje szablon bez zmian. Po dopisaniu kluczy przepuscic ui.csv przez licznik `%` per wiersz.

## FILES

- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/combat/combat.gd
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/combat/poker.gd
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/combat/scoring.gd
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/combat/combat_controller.gd
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/combat/hand_advisor.gd
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/ui/juice.gd
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/ui/hand_fan.gd
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/ui/overlays.gd
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/cards/card_widget.gd
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/audio/sfx.gd
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/meta/profile.gd
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/src/game/region/run.gd
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/data/locale/ui.csv
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/tests/test_scoring.gd
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/tests/test_combat.gd
- /home/johnbakoma/Downloads/-11111/Parallaxa_card/project.godot

