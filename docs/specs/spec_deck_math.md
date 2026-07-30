# Matematyka talii pentaklowej

> Zrodlo: panel projektowy (workflow parallaxa-feel-overhaul), Matematyka talii pentaklowej.
> Dokument PROJEKTOWY -- stan wdrozenia opisuje docs/ROADMAP.md.

## DIAGNOSIS

DOWOD LICZBOWY, ze "co najwyzej pary" to nie wrazenie gracza tylko struktura talii.

Skrypt: /tmp/claude-1000/deckmath.py + deckmath2.py + final.py + final2.py (wierny port Poker.evaluate, Scoring.score, CombatController._refill/_move_to_used z recyklingiem grobu). Odczyt faktow z .tres, nie z briefu.

KOREKTA FAKTOW Z BRIEFU (sprawdzone w kodzie):
- s_04.tres nie ma pola rank -> CardData.rank default = 2, nie 1. Rangi startowe: 2,3,5,5,6,6,7,7,7,8,9,9,10,12,14,14.
- START_DISCARDS to 3 NA TURE, nie na walke: combat_controller.gd, resolve_enemy_turn() -> "discards_left = START_DISCARDS + _bonus_discards()". Przy talii 16 i limicie 5 kart na odrzut gracz przewija 15 z 16 kart CO TURE.

1) SUFIT TALII JEST MATEMATYCZNY, NIE STATYSTYCZNY (wyliczenie wyczerpujace, wszystkie C(16,8)=12870 rozdan otwarcia):
   HIGH 5.25% | PAIR 30.72% | TWO_PAIR 36.33% | THREE 4.56% | STRAIGHT 17.29% | FLUSH 1.13% | FULL 4.71%
   FOUR / STRAIGHT_FLUSH / FIVE / MAGNUM_OPUS = 0.0000% -- NIEOSIAGALNE.
   Powod: max 3 kopie jakiejkolwiek rangi (trzy 7). DEATH ma rangi {2,7,7,9,14} -> brak ciagu -> zero pokerow.
   4 z 11 ukladow (36% drabinki) to martwa tresc, ktorej gracz NIGDY nie zobaczy z talii startowej.

2) W CALEJ TALII ISTNIEJE DOKLADNIE JEDEN FLUSH I DWA STRAIGHTY:
   - jedyny 5-elementowy monokolor to 5 kart DEATH -> P(wszystkie 5 w rece 8) = C(11,3)/C(16,8) = 165/12870 = 1.28%
   - jedyne ciagi w talii: {5,6,7,8,9} i {6,7,8,9,10}; oba wymagaja jedynej "8" w talii
   Dla porownania: 5 aspektow x 14 rang daje 10010 roznych flushy i 50 poker-strightow.

3) ZAMROZONA REKA -- TO JEST PRAWDZIWY ZABOJCA "RADOSCI":
   run_state.gd:100 tasuje talie RAZ na run. combat_controller.gd:59 robi "_draw = deck.duplicate()" -- ZERO tasowania miedzy walkami.
   => pierwsza reka kazdej walki w runie to te same karty deck[0..7]. Przy ~9 walkach na region x 4 regiony gracz widzi identyczne otwarcie do ~36 razy.
   P(ta zamrozona reka daje maks TWO_PAIR) = 72.31% (wyliczenie wyczerpujace).
   Czyli w 72% runow gracz jest skazany na "pary" w kazdej walce runu. Dokladnie to opisal.

4) ODRZUTY NIE RATUJA, TYLKO ODSLANIAJA PUSTKE (Monte Carlo, 210 000 zmierzonych rak na wiersz):
   OLD 16 | 0 odrzutow : HIGH 7.48 PAIR 33.34 2PAIR 31.73 TRIPS 3.25 STRT 18.85 FLUSH 1.53 FULL 3.83
   OLD 16 | 3 odrzuty/ture: HIGH 3.17 PAIR 9.59 2PAIR 3.95 TRIPS 0.25 STRT 49.53 FLUSH 16.37 FULL 17.14
   Przy 3 odrzutach/ture bot-planista wyciaga STRAIGHT w polowie tur -- ale zawsze TEN SAM straight z tych samych kart, bo talia ma tylko 2 ciagi. To nie jest przestrzen decyzji, to jedno zadanie rozwiazane raz na run.

5) WALKI KONCZA SIE ZANIM COKOLWIEK ZDAZY SIE STAC:
   OLD 16 przy shippingowych 3 odrzutach/ture, mediana skumulowanych obrazen: T1 390, T2 670, T3 962.
   HP wrogow regionu 1 = 460-560, boss 600. => mediana dlugosci walki = 2 TURY. Boss = 2 tury. SWIAT (1300 HP) = 4 tury.
   Nie ma miejsca na eskalacje, na Kombinat/Lawine, na plan. Gra nie ma czasu byc grą.

WNIOSEK: skarga "udawalo mi sie co najwyzej robic pary" jest doslownie prawdziwa dla 72% runow, a 36% drabinki ukladow jest niedostepne z definicji. Naprawa wymaga TRZECH rzeczy naraz: (a) prawdziwej talii tarota 5x14, (b) zdjecia odrzutow z "3 na ture" na "3 na walke", (c) deterministycznego rozdania per walka.

## DECK SPEC

NOWA TALIA STARTOWA: 70 KART = 5 ASPEKTOW x 14 RANG (pelne pieciokolorowe Male Arkana).

Rangi: 1 (As), 2-10 (pipy), 11 Paz, 12 Rycerz, 13 Krolowa, 14 Krol. Kazda para (rank, aspect) wystepuje DOKLADNIE RAZ -> 70 unikalnych kart, 14 na aspekt.

ROZKLAD SLOW KLUCZOWYCH: 55 kart PLAIN (Keyword.NONE) + 15 kart sygnaturowych, 3 na aspekt (dokladnie ten zestaw byl symulowany):
  LIFE   : rank 2  OSLONA 5     | rank 8  OPATRZNOSC 4 | rank 13 OSLONA 8
  MIND   : rank 3  ECHO 3       | rank 9  ECHO 5       | rank 13 ECHO 7
  DEATH  : rank 3  GNICIE 3     | rank 9  GNICIE 4     | rank 13 GNICIE 6
  CHAOS  : rank 4  FURIA 0      | rank 10 SPALENIE 8   | rank 13 FURIA 0
  NATURE : rank 5  BUJNOSC 20   | rank 8  SYMBIOZA 4   | rank 13 KORZENIE 4
Wszystkie Krolowe (13) niosa znak swojego koloru -- to jest nauczalna regula dla gracza.

CO NIE MOZE BYC W TALII STARTOWEJ (zostaje wylacznie w reward_pool):
  ZNIWO (mult x rozmiar grobu), PIJAWKA, KLATWA, PRZECIAZENIE, LAWINA, KOMBINAT.
  ZNIWO w talii 70-kartowej rozwala symulacje: grob dochodzi do 40-60 kart, wiec ZNIWO 1 daje +40..60 do Mult. Zmierzone: z ZNIWO w talii p95 obrazen = 1804 i max 10854; bez ZNIWO p95 = 372 i max 2520. To 5x roznicy w ogonie.

HAND_SIZE / ODRZUTY / ZAGRANIA:
- HAND_SIZE: 8 -- BEZ ZMIAN (kalibracja Balatro; 9 testowalem, podnosi FULL_HOUSE do 27% -> odrzucone).
- Max 5 kart na zagranie i na odrzut -- BEZ ZMIAN (combat.gd _selected.size() < 5).
- 1 zagranie na ture -- BEZ ZMIAN.
- START_DISCARDS zostaje 3, ale staje sie PULA NA CALA WALKE, nie na ture.
  Jedyna zmiana: w combat_controller.gd resolve_enemy_turn() USUNAC linie
      discards_left = START_DISCARDS + _bonus_discards()
  (oraz towarzyszacy jej HANGED_CAP clamp -- patrz risks). start() zostaje bez zmian.
  To jest 2-liniowa zmiana, ktora sama w sobie daje 60% efektu. Relikt Kaplanki (EXTRA_DISCARD +1) staje sie realnie mocny (3->4 na walke).

DETERMINISTYCZNE ROZDANIE PER WALKA (koniec zamrozonej reki, bez lamania determinizmu):
- CombatController.start(deck, enemy, relics, start_hp, max_hp, levels, veil, depth, debt, p_deal_seed: int = 0)
- gdy p_deal_seed != 0: raz, PRZED pierwszym dobraniem, przetasuj _draw generatorem RandomNumberGenerator o seedzie p_deal_seed. Potem zero losowosci: recykling _used w kolejnosci zagranej, peek_draw() dalej pokazuje dokladna przyszlosc, preview dalej nie klamie.
- p_deal_seed = 0 (domyslnie) = brak tasowania -> wszystkie testy i stare wywolania dzialaja bez zmian.
- run.gd liczy seed BEZ dotykania RunState.rng (kontrakt seeda nienaruszony):
      var fight_seed := RunState.run_seed ^ (RunState.region_index * 73856093) ^ (RunState.step * 19349663) ^ (RunState.depth * 83492791)
  Powtorzenie tego samego fate daje te same rozdania. Podglad kolejnych dobran zostaje.

CO ZOSTAJE NIEOSIAGALNE Z TALII STARTOWEJ (zgodnie z designem):
- MAGNUM_OPUS: wymaga 5 kopii tej samej pary (rank, aspect). W siatce 5x14 kazda taka para jest unikalna -> P = 0.00000% ZAWSZE, nie tylko statystycznie. Da sie go zbudowac wylacznie dodruk-ami z reward_pool. Cel spelniony strukturalnie.
- FIVE (5 tej samej rangi, rozne aspekty): P(w rece 8) = 14*C(65,3)/C(70,8) = 0.0065% na sucho, 0.02% z pula odrzutow. Legenda, nie mechanika.

ARTY RWS -- ILE KART BEZ ARTU:
- Mapowanie w card_widget.gd MINOR_SUIT: LIFE=cups, MIND=swords, CHAOS=wands, DEATH=pents. 4 aspekty x 14 rang = 56 kart MA skan RWS.
- NATURE = 14 kart bez skanu = 20% talii startowej (plus 11 kart NATURE w reward_pool -> lacznie 25 kart w grze bez artu).
- ROZWIAZANIE (shipping): NATURE zostaje "kolorem marsylskim". Rozbudowac CardWidget._build_plain_face:
    rangi 1-10  -> N glifow liscia rozlozonych w siatce marsylskiej (2 kolumny, symetrycznie), zielone na ciemnym tle, plus ornament ramki
    rangi 11-14 -> proceduralna plansza dworska: sylwetka + duzy glif liscia + pasek rangi (P/R/Q/K)
  To jest historycznie poprawne: Male Arkana w Marsylii SA kartami pipowymi, a nie ilustrowanymi. Nature dostaje przez to wlasna tozsamosc wizualna zamiast wygladac na brak.
- ROZWIAZANIE (polish, pozniej): 14 rycin public domain z Koehler "Medizinal-Pflanzen" 1887 lub Besler "Hortus Eystettensis" 1613 -> assets/cards/minor/leaves_01..14.jpg, i dopisac Aspects.Id.NATURE: "leaves" do MINOR_SUIT. Zero zmian w kodzie poza jedna linia slownika.
- NIEZALEZNIE OD TEGO: kazda karta dostaje BADGE SYGILU aspektu w rogu (kielich / miecz / rozdzka / denar / lisc) w kolorze Aspects.COLORS -- to jest wprost prosba gracza "widoczne kolory i symbole tego koloru", i dziala tak samo na kartach ze skanem i bez.

ALTERNATYWNE TALIE STARTOWE (reaper / gardener / oracle) -- tez 70 kart:
Ta sama siatka 5x14, ale 6 kart obcego aspektu zamienionych na DUBLETY aspektu domowego, plus wlasny zestaw 15 kart sygnaturowych.
Przyklad Reaper: usun NATURE 1,2,4,6,7,11; dodaj drugie kopie DEATH 4,7,10,11,12,14 -> DEATH 20 / LIFE 14 / MIND 14 / CHAOS 14 / NATURE 8.
Zmierzone (20k prob): FLUSH 5.08% przy 0 odrzutow (vs 3.25% dla siatki jednorodnej), FLUSH 43.72% przy 3 odrzutach/ture -- czyli skew realnie robi z Reapera talie kolorowa, bez ruszania reszty matematyki.

DLACZEGO 70, A NIE 50 / 40 / 30 / "flush z 4 kart" -- patrz pole probabilities (pelna tabela porownawcza 6 wariantow x 4 budzety odrzutow).

## PROBABILITIES

WSZYSTKIE LICZBY = % TUR, W KTORYCH DANY UKLAD JEST NAJLEPSZYM DOSTEPNYM (max po wszystkich podzbiorach 5-kartowych, semantyka Poker.evaluate 1:1).
Polityka odrzutow = zachlanny planista (wybiera archetyp flush / straight / set po liczbie brakujacych kart, odrzuca do 5 najslabszych spoza planu). Gracz z peek_draw() moze grac LEPIEJ, wiec to jest dolne ograniczenie.

=========================================================================
A. TABELA GLOWNA -- 210 000 ZMIERZONYCH RAK NA WIERSZ (70 000 prob x 3 tury)
=========================================================================
konfiguracja              HIGH   PAIR  2PAIR  TRIPS   STRT  FLUSH   FULL   FOUR   STFL   FIVE  MAGNUM
OLD 16 | 0 odrzutow       7.48  33.34  31.73   3.25  18.85   1.53   3.83   0.00   0.00   0.00   0.00
OLD 16 | 3 odrz./TURE     3.17   9.59   3.95   0.25  49.53  16.37  17.14   0.00   0.00   0.00   0.00
NEW 70 | 0 odrzutow       8.65  33.79  33.96   5.90   7.22   3.25   6.63   0.57   0.03   0.01   0.00
NEW 70 | 1 odrz./TURE     6.25  21.16  17.86   3.84  21.34  17.97  10.22   1.12   0.22   0.03   0.00
NEW 70 | 3 odrz./TURE     1.72   5.56   4.57   0.79  32.50  38.37  13.84   1.49   1.14   0.03   0.00

=========================================================================
B. KONFIGURACJA REKOMENDOWANA -- 210 000 RAK (30 000 prob x 7 tur), pula 3 odrzuty NA WALKE
=========================================================================
                          HIGH   PAIR  2PAIR  TRIPS   STRT  FLUSH   FULL   FOUR   STFL   FIVE  MAGNUM
NEW 70 | 3 odrz./WALKE    6.89  26.09  25.64   5.48  14.75  11.80   8.42   0.81   0.10   0.02   0.00
   rozklad po turach (widac, jak pula sie wypala -- to jest napiecie, ktorego dzis nie ma):
   T1                     3.19  10.93   8.84   5.51  29.33  29.31  11.38   1.22   0.25   0.04   0.00
   T2                     4.71  15.23  12.94   4.41  25.71  24.44  11.16   1.15   0.23   0.03   0.00
   T3                     7.50  26.69  24.95   5.30  14.95  11.55   8.16   0.76   0.10   0.03   0.00
   T4                     8.15  31.12  31.39   5.64   9.40   6.24   7.31   0.70   0.04   0.01   0.00
   T5                     8.19  33.17  33.08   5.98   7.93   4.05   6.90   0.65   0.05   0.01   0.00
   T6                     8.23  32.44  34.24   5.76   8.09   3.52   7.02   0.66   0.04   0.01   0.00
   T7                     8.24  33.04  34.07   5.74   7.82   3.51   7.01   0.55   0.02   0.01   0.00
   (dla kontrastu OLD 16 przy tej samej puli 3/walke: HIGH 8.37 PAIR 19.99 2PAIR 19.37 TRIPS 3.14 STRT 33.28 FLUSH 9.93 FULL 5.92 FOUR 0.00 -- ciagle zero karet i pokerow)

TRAFIENIE W CELE PROJEKTOWE (NEW 70 | 3 odrz./walke):
   mediana ukladu = TWO_PAIR (HIGH+PAIR = 32.98% ponizej, +2PAIR = 58.62%)  -> CEL SPELNIONY
   STRAIGHT 14.75%  -> w pasmie 8-20%   CEL SPELNIONY
   FLUSH    11.80%  -> w pasmie 8-20%   CEL SPELNIONY
   FOUR      0.81%  -> swieto           CEL SPELNIONY
   STRAIGHT_FLUSH 0.10%, FIVE 0.02%     -> legenda
   MAGNUM_OPUS 0.00000% strukturalnie   CEL SPELNIONY
   FULL_HOUSE 8.42%  -> cel byl 1-5%, jest 8.4%. ODCHYLENIE SWIADOME: przy 5 aspektach kazda ranga ma 5 kopii (talia 52-kartowa ma 4), wiec triple sa z natury czestsze. Dzwignia gdyby to przeszkadzalo: HAND_SIZE 8 -> 7 obniza FULL do ~5%, ale zabija tez STRAIGHT i FLUSH; nie polecam. FULL jest tu "duzym, ale nie rzadkim" ciosem i to jest zdrowe.

=========================================================================
C. PORONWANIE WARIANTOW (a)(b)(c)(d) -- 120 000 RAK NA WIERSZ (40 000 x 3 tury)
=========================================================================
wariant                        HIGH   PAIR  2PAIR  TRIPS   STRT  FLUSH   FULL   FOUR   STFL   FIVE
(V0) 16 obecna    | 0 odrz.    7.45  33.30  31.77   3.18  19.05   1.50   3.76   0.00   0.00   0.00
(V0) 16 obecna    | 3 odrz.    3.29   9.61   3.91   0.23  49.74  16.38  16.84   0.00   0.00   0.00
(b)  50 = 5x1-10  | 0 odrz.    0.95  14.48  42.67   6.27  15.73   2.39  15.76   1.65   0.07   0.03
(b)  50 = 5x1-10  | 3 odrz.    0.08   1.19   2.83   0.39  42.54  19.44  28.92   2.36   2.21   0.04
     55 = 5x1-11  | 0 odrz.    2.32  20.45  41.23   6.46  13.04   2.74  12.49   1.19   0.06   0.02
     60 = 5x1-12  | 0 odrz.    4.06  25.95  38.83   6.45  10.78   2.94  10.02   0.90   0.04   0.03
     65 = 5x1-13  | 0 odrz.    6.40  30.09  36.39   6.22   8.88   3.13   8.08   0.74   0.04   0.01
(a)  70 = 5x1-14  | 0 odrz.    8.71  33.71  33.78   6.03   7.17   3.34   6.64   0.59   0.02   0.01
(a)  70 = 5x1-14  | 1 odrz.    6.25  21.26  17.76   3.92  21.29  17.98  10.18   1.14   0.21   0.02
(a)  70 = 5x1-14  | 3 odrz.    1.66   5.60   4.56   0.84  32.40  38.55  13.84   1.42   1.09   0.03
(c)  40 = 5x1-8   | 0 odrz.    0.00   2.48  39.18   4.56  21.89   1.63  26.80   3.20   0.17   0.09
(c)  40 = 5x1-8   | 3 odrz.    0.00   0.09   1.09   0.12  37.38   8.88  45.57   3.95   2.85   0.06
     30 = 5x2-7   | 3 odrz.    0.00   0.00   0.06   0.00  16.82   0.97  71.30   8.58   2.00   0.27
(d)  16 + flush z 4 kart|3odrz 0.95   5.13   5.42   0.19  12.20  48.61  27.50   0.00   0.00   0.00
(d)  40 + flush z 4 kart|3odrz 0.00   0.00   0.12   0.01  10.89  16.27  44.83   4.07  23.71   0.09
(d)  50 + flush z 4 kart|3odrz 0.01   0.15   0.42   0.05  10.28  38.85  29.46   2.35  18.38   0.04
     50, HAND_SIZE 9 | 0 odrz. 0.00   3.07  38.36   3.13  21.03   4.25  27.18   2.73   0.18   0.06
     40, HAND_SIZE 9 | 0 odrz. 0.00   0.00  25.14   0.74  23.31   2.55  42.16   5.58   0.34   0.19

WERDYKT LICZBOWY:
 - (c) 40 i 30 kart: FULL_HOUSE 26.8% / 71.3% -- to sa maszynki do fulli, mediana ucieka na FULL. Odpada.
 - (b) 50 kart (rangi 1-10): najlepsze pasmo STRAIGHT+FLUSH (18.1% na sucho), ale FULL+FOUR = 17.4% zamiast 1-5%. Odpada na celu "swieto".
 - (d) flush z 4 kart / splash: przy 16 kartach FLUSH skacze z 1.0% na 19.95% (0 odrz.) i 48.61% (3 odrz.), a przy 40-50 kartach STRAIGHT_FLUSH wybija do 18-24%. Rozwala hierarchie ukladow (poker przestaje byc rzadszy od koloru) i wymaga zmiany Poker._is_flush, czyli dotkniecia rdzenia i wszystkich testow. ODPADA jako rozwiazanie glowne -- to plaster na za mala talie, a nie naprawa.
 - (a) 70 kart: JEDYNY wariant, w ktorym FULL 6.6% i FOUR 0.6% mieszcza sie blisko pasma "swieto", mediana siedzi na TWO_PAIR, a STRAIGHT+FLUSH da sie wyregulowac budzetem odrzutow do 26.5%. Do tego jest jedynym w pelni TAROTOWYM: 5 kolorow x (As, 2-10, Paz, Rycerz, Krolowa, Krol). WYBRANY.

=========================================================================
D. FAKTY STRUKTURALNE (dokladna kombinatoryka, nie Monte Carlo)
=========================================================================
                                  OBECNA 16              NOWA 70
liczba roznych flushy w talii     1                      5 * C(14,5) = 10 010
liczba okien straighta            2 ({5-9}, {6-10})      10 (1-5 ... 10-14)
liczba roznych straight flushy    0                      50
P(flush w rece 8, na sucho)       1.28%                  3.195%
P(4+ w jednym kolorze w rece 8)   --                     22.667%
P(FIVE w rece 8)                  0% (max 3 kopie rangi) 0.00648%
P(MAGNUM_OPUS z talii startowej)  0%                     0% (kazda para rank+aspect unikalna)
P(najlepszy uklad <= TWO_PAIR)    72.31% -- I TA REKA     58.62% i INNA REKA
  na turze 1                      JEST ZAMROZONA         W KAZDEJ WALCE
                                  NA CALY RUN

=========================================================================
E. WPLYW LICZBY ASPEKTOW NA FLUSH (dla projektanta 5 BIOMOW -- wazne ostrzezenie)
=========================================================================
P(flush w rece 8), talia = N aspektow x 14 rang, wzor scisly:
   2 aspekty (28 kart) = 67.762%
   3 aspekty (42 kart) = 19.807%
   4 aspekty (56 kart) =  7.241%
   5 aspektow (70 kart) =  3.195%
WNIOSEK DLA MECHANIKI "ZBIERZ 5 KOLOROW": jesli zdobycie biomu ma DODAWAC karty nowego koloru do talii, to flushe beda coraz RZADSZE w miare postepu -- gra bedzie sie robic gorsza, im dalej zajdziesz. Kolor zdobyty w biomie musi byc SYGILEM/reliktem albo pogłębieniem koloru juz posiadanego (dublety), nigdy nowym kolorem dosypanym do talii.

## BALANCE

KRZYWA OBRAZEN GRACZA -- NOWA TALIA 70, pula 3 odrzuty/walke, BEZ reliktow, bez poziomow ukladow (175 000 zagran; Scoring.score wierny, FURIA/SPALENIE/ECHO/BUJNOSC/SYMBIOZA wliczone):

  na ture: min 44 | p05 74 | p25 114 | MEDIANA 162 | p75 279 | p95 372 | p99 546 | max 2520 | srednia 199
  po turach (mediana): T1 280 | T2 260 | T3 152 | T4 136 | T5 132 | T6 134 | T7 134
  (spadek to WYPALANIE PULI ODRZUTOW -- turn 1-2 to eksplozja, potem gra sie tym co przyjdzie; to jest luk napiecia, ktorego dzis nie ma)

SKUMULOWANE OBRAZENIA (mediana | p10 | p90):
  po T1:  280 |  114 |  364
  po T2:  516 |  293 |  697
  po T3:  698 |  438 |  976
  po T4:  859 |  579 | 1212
  po T5: 1022 |  719 | 1415
  po T6: 1187 |  868 | 1604
  po T7: 1355 | 1017 | 1802

Dla porownania STARA talia przy shippingowych 3 odrzutach/ture: mediana/ture 321, skumulowane T1 390 / T2 670 / T3 962 -> przy HP 460-560 walka trwa 2 TURY.

MODEL MOCY GRACZA PO REGIONACH (mnoznik na powyzsza krzywa; relikty + poziomy ukladow + dobrane karty):
  R1 x1.25 (1 relikt z draftu)  R2 x1.70  R3 x2.30  R4 x3.00
Uwaga: przy talii 70-kartowej DOBRANE KARTY rozcienczaja sie 4x slabiej niz przy 16 (1/70 vs 1/16), wiec krzywa mocy rosnie wolniej niz dzis -- dlatego mnozniki wyzej sa lagodniejsze niz obecna krzywa HP sugeruje.

=========================================================================
NOWE HP WROGOW -- KONKRETNE LICZBY (cel: 4-6 tur normal, 6-9 tur boss)
=========================================================================
REGION 1 (cel normal 4-5 tur mediana, 3-7 zakres):
  enemy_a.tres        ENEMY_KULTYSTA     520 -> 1060   intents [10,13,8] -> [5,7,4]    enrage 2 -> 1
  enemy_a2.tres       ENEMY_WIEDZMA      480 ->  980   intents [16,4,16] -> [8,2,8]    enrage 2 -> 1
  enemy_a3.tres       ENEMY_NOWICJUSZ    500 -> 1020   intents [9,14,9]  -> [5,7,5]    enrage 2 -> 1
  enemy_b.tres        ENEMY_CIEN         460 ->  940   intents [12,15,9] -> [6,8,5]    enrage 2 -> 1
  enemy_b2.tres       ENEMY_GOLEM        500 -> 1020   intents [20,0,15] -> [10,0,8]   enrage 3 -> 2
  enemy_b3.tres       ENEMY_PRZEBITY     480 ->  980   intents [18,2,12] -> [9,1,6]    enrage 3 -> 2
  enemy_elite_r1.tres ENEMY_ELITE_R1     680 -> 1500   intents [22,0,16] -> [11,0,8]   enrage 5 -> 2
  boss_tower.tres     ENEMY_WIEZA        600 -> 1800   intents [15,20,13]-> [6,8,5]    enrage 3 -> 2
  boss_chariot.tres   ENEMY_RYDWAN       560 -> 1600   intents [9,12,7]  -> [3,4,2]    enrage 3 -> 1  (rule bije 2x)
  boss_strength.tres  ENEMY_SILA         780 -> 1700   intents [12,15,10]-> [5,7,4]    enrage 3 -> 2  (rule -20% dmg => efektywne 2125)

REGION 2 (x1.36 wzgledem R1 po uwzglednieniu wzrostu mocy):
  enemy_r2a.tres      ENEMY_KAPLAN       720 -> 1300   intents [14,17,10]-> [7,9,5]    enrage 3 -> 2
  enemy_r2a2.tres     ENEMY_UPIOR        680 -> 1250   intents [21,6,21] -> [11,3,11]  enrage 3 -> 2
  enemy_r2b.tres      ENEMY_RYCERZ       840 -> 1500   intents [16,16,16]-> [8,8,8]    enrage 3 -> 2
  enemy_r2b2.tres     ENEMY_CHIMERA      780 -> 1400   intents [24,0,19] -> [12,0,10]  enrage 4 -> 2
  enemy_elite_r2.tres ENEMY_ELITE_R2     870 -> 2000   intents [18,18,18]-> [9,9,9]    enrage 5 -> 3
  boss_devil.tres     ENEMY_DIABEL       780 -> 2450   intents [16,20,14]-> [7,9,6]    enrage 4 -> 2
  boss_hanged.tres    ENEMY_WISIELEC     760 -> 2400   intents [17,21,14]-> [8,9,6]    enrage 4 -> 2
  boss_justice.tres   ENEMY_SPRAWIEDLIWOSC 740 -> 2350 intents [15,19,12]-> [7,8,5]    enrage 4 -> 2

REGION 3 (x1.84 wzgledem R1):
  enemy_r3a.tres      ENEMY_STRAZNIK    1040 -> 1800   intents [20,23,15]-> [10,12,8]  enrage 4 -> 2
  enemy_r3a2.tres     ENEMY_WIDMO        990 -> 1700   intents [27,10,27]-> [14,5,14]  enrage 4 -> 2
  enemy_r3b.tres      ENEMY_TYTAN       1150 -> 2000   intents [22,22,22]-> [11,11,11] enrage 4 -> 2
  enemy_r3b2.tres     ENEMY_HERALD      1090 -> 1900   intents [30,0,25] -> [15,0,13]  enrage 5 -> 3
  enemy_elite_r3.tres ENEMY_ELITE_R3    1200 -> 2750   intents [25,25,25]-> [13,13,13] enrage 6 -> 3
  boss_moon.tres      ENEMY_KSIEZYC      980 -> 3300   intents [20,25,17]-> [9,11,8]   enrage 5 -> 3
  boss_judgement.tres ENEMY_SAD          950 -> 3200   intents [21,26,17]-> [9,12,8]   enrage 5 -> 3
  boss_star.tres      ENEMY_GWIAZDA     1000 -> 3350   intents [19,24,16]-> [9,11,7]   enrage 5 -> 3

REGION 4:
  boss_world.tres     ENEMY_SWIAT       1300 -> 4400   intents [26,30,22]-> [12,13,10] enrage 6 -> 3

WERYFIKACJA DLUGOSCI (mediana, R1, mnoznik x1.25):
  1.25 * skumulowane = T3 873 | T4 1074 | T5 1278 | T6 1484 | T7 1694 | T8 ~1900
  HP 940-1060 -> smierc na T4-T5 (mediana), T3 przy szczesciu, T6-T7 przy pechu = 4-6 tur SPELNIONE
  boss 1800    -> smierc na T7-T8 = 6-9 tur SPELNIONE
  elite 1500   -> T6

STALE, KTORE MUSZA POJSC ZA TYM (inaczej dluzsze walki zabija gracza):
  combat_controller.gd:
    PLAYER_MAX_HP        55 -> 80     (walki 2 tury -> 5-8 tur, gracz obrywa 2.5x czesciej)
    FIGHT_HEAL_CAP       15 -> 22
    MOON_MEND_HEAL       15 -> 60     (mediana dmg/ture 162 -- +15 jest dzis niewidoczne)
    MOON_MEND_THRESHOLD  60 -> 150
    STAR_REGEN (w resolve_enemy_turn, literal 12) -> 45
    JUSTICE riposte: prog "dmg < 40" -> "dmg < 120", dzielnik "dmg / 40" -> "dmg / 120", cap 8 -> 10
    overkill: "clampi(-enemy_hp / 50, 0, 5)" -> "clampi(-enemy_hp / 150, 0, 5)" (2 miejsca: play() i resolve_enemy_turn())
    HANGED_CAP: "discards_left = mini(discards_left, 1)" -> przy puli na walke to zabija cala walke; zmienic na "discards_left = maxi(1, discards_left / 2)" i USUNAC drugie wystapienie z resolve_enemy_turn()
  run_state.gd:
    START_MAX_HP         55 -> 80
    REST_HEAL             8 -> 12
    Veil I "player_max_hp = 48" -> 70
    Veil V "var base_cap := 10" -> 15
  scoring.gd:
    ZNIWO: "mult += float(c.keyword_value * grave)" -> "mult += float(c.keyword_value * mini(grave, 20))"
    (grob przy talii 70 dochodzi do 60 kart; bez capa ZNIWO 1 daje +60 Mult i p95 obrazen skacze z 372 na 1804, max z 2520 na 10854 -- zmierzone)

JAK PRZESKALOWAC tools/gen/gen_content.gd:
  Wszystkie liczby wyzej sa literalami w _enemy(...) / _save_enemy(...) / _save_boss(...) / _save_elite(...) w liniach ~155-246. Najczystsza forma:
    1. dopisac na gorze pliku:
         const HP_R := [1.00, 1.36, 1.84, 2.40]   ## per-region HP multiplier vs the region-1 baseline
         const INTENT_K := 0.50                    ## fights run 2.5x longer now: halve every intent
    2. dodac helper:
         static func _hp(base_r1: int, region: int) -> int:
             return int(round(base_r1 * HP_R[region] / 10.0)) * 10
         static func _int(v: Array) -> Array:  # halve, keep zeros as zeros, floor at 1
             var o: Array = []
             for x in v: o.append(0 if int(x) == 0 else maxi(1, int(round(int(x) * INTENT_K))))
             return o
    3. podmienic literaly wg tabeli wyzej (tabela JEST wynikiem tych wzorow, wiec mozna jedno albo drugie).
  _starter() zwraca teraz 70 wpisow generowanych petla:
    for a in [A.LIFE, A.MIND, A.DEATH, A.CHAOS, A.NATURE]: for r in range(1, 15): [r, a, SIG.get([a,r], KW.NONE), val]
  z jawnym slownikiem 15 kart sygnaturowych (pole deck_spec). To dalej jest editor-first: .tres wychodza z generatora i sa recznie edytowalne.

## RISKS

1. KONTRAKT SEEDA -- REALNY BLAD, KTORY TA ZMIANA UJAWNIA (najwazniejsze ryzyko):
   run_state.gd:100 wola "_shuffle(deck)", a _shuffle() (linia 308) uzywa GLOWNEGO rng. Fisher-Yates na talii N zuzywa N-1 losowan. Dzis 15, po zmianie 69. To PRZESUWA CALY STRUMIEN RNG runu, wiec kazdy istniejacy fate code i kazde Daily Fate wygeneruje inne oferty, innych wrogow i innego bossa. "Pure Reading" przestaje byc powtarzalne wstecz.
   NAPRAWA (obowiazkowa, przed czymkolwiek innym): "_shuffle(deck)" -> "_shuffle_with(deck, _sub_rng())". Wtedy tasowanie kosztuje DOKLADNIE JEDNO losowanie glownego rng niezaleznie od rozmiaru talii -- dokladnie tak, jak juz robia pick_offers() i pick_tiered_offers(). Po tej poprawce zmiana rozmiaru talii jest neutralna dla strumienia.
   Stare seedy i tak sie rozjada (talia jest inna), wiec: podbic wersje fate'ow i zaznaczyc w UI, ze kody sprzed rework nie sa zgodne.

2. ROZDANIE PER WALKA vs DETERMINIZM -- da sie zrobic bez zlamania przymierza, ale TYLKO tak:
   tasowanie MUSI sie odbyc raz, w start(), PRZED pierwszym _refill(), z generatora seedowanego wartoscia POCHODNA (run_seed ^ region_index ^ step ^ depth), a NIE z RunState.rng. Jesli ktos uzyje RunState.rng, punkt 1 wraca i "Repeat this fate" klamie.
   peek_draw(), preview(), predicted_taken() i "podglad kolejnych dobran" pozostaja dokladne, bo po starcie walki kolejnosc jest zamrozona i recykling _used dalej jest w kolejnosci zagranej.
   p_deal_seed = 0 musi byc DOMYSLNE i musi oznaczac "nie tasuj" -- inaczej patrz punkt 3.

3. TESTY, KTORE SIE ZEPSUJA (sprawdzone linia po linii):
   tests/test_combat.gd -- KAZDY helper buduje talie recznie i wola ctrl.play([0]) zakladajac, ze deck[0] trafia do hand[0]. Dowolne bezwarunkowe tasowanie w start() rozwala _hp_after, _moon_rot, _moon_mend, _heal_cap_check, _overkill_check, _glass_check, _justice_riposte, _frail_tax_check, _blood_tax_hp. Dlatego p_deal_seed domyslnie 0.
   Konkretne asercje do zaktualizowania po zmianach stalych:
     "moon mends 15 when the round dealt under 60"  -> 60 / 150
     "the star mends +12 every enemy turn"          -> 45
     "justice ripostes exactly dmg/40 (cap 8)"      -> dmg/120 (cap 10)
     "overkill converts excess to Mercury (cap 5)"  -> dzielnik 150 (test uzywa SPALENIE 200 na 10 HP -> overkill 190 -> dzis 3, po zmianie 1; podniesc keyword_value testu do 800)
     "hanged man caps discards at 1"                -> nowa regula maxi(1, pool/2) = 1 przy puli 3, wiec asercja PRZEJDZIE, ale komentarz i intencja wymagaja przepisania
     "priestess grants extra discard (3+1)"         -> przechodzi bez zmian (start() nietkniete)
     "veil5 boss stands 15% taller (600 -> 690)"    -> przechodzi (test buduje wlasne EnemyData)
   tests/test_scoring.gd -- wszystkie asercje buduja karty przez _c(), wiec zmiana talii ich NIE dotyka. Jedyny wyjatek: _check_zniwo() ("zniwo mult6" przy grave=5) -- cap mini(grave,20) nie zmienia wyniku dla grave=5, wiec test przechodzi. Dopisac NOWY test na cap: grave=50 z ZNIWO 1 musi dac mult 21, nie 51.
   Dopisac tez test strukturalny: "starter deck has 70 cards, every (rank,aspect) unique, no rank has 4 copies" -- to jest kontrakt, ktory chroni MAGNUM_OPUS przed przypadkowym wpadnieciem do talii startowej.

4. ZAPIS RUNU (save-compat):
   run_state.gd save_run() zapisuje talie jako tablice slownikow {r,a,k,v,e,y,w} -- rozmiar talii nie jest nigdzie zaszyty, wiec 70 kart zapisze i wczyta sie poprawnie. ALE stary zapis z 16 kartami wczyta sie do gry z HP wrogow x2 i gracz dostanie run nie do wygrania.
   NAPRAWA: dopisac "cf.set_value("run", "ver", 2)" w save_run() i w load_run() na starcie: jesli get_value("run","ver",1) < 2 -> zwroc "" i skasuj plik (przycisk Kontynuuj znika). Alternatywa bez utraty runu: migracja przez dolozenie brakujacych kart siatki -- odradzam, bo balans i tak bedzie inny.
   Profile.starter_editions uzywa kluczy "deckid:index" (index karty w talii). Po przejsciu na 70 kart indeksy oznaczaja INNE karty -> kupione edycje wyladuja na losowych kartach. NAPRAWA: skasowac starter_editions przy migracji profilu albo przekluczowac na "deckid:aspect:rank".

5. TEMPO RUNU I EKONOMIA NAGROD (najwiekszy dlug projektowy tej zmiany):
   Przy talii 16 dobrana karta to +6.25% talii. Przy 70 to +1.43% -- 4.4x slabsze. Bez reakcji nagrody karciane przestana byc odczuwalne i cala moc przejdzie na Arkana (co akurat jest Balatro-poprawne, ale trzeba to zrobic swiadomie).
   KONIECZNE PRZECIWWAGI (run.gd):
     - nagroda dodaje 2 KOPIE wybranej karty zamiast jednej (RunState.add_card wolane 2x), albo
     - nagroda = "dodaj karte I usun karte" w jednym kroku,
     - THIN_COST w dol i mozliwosc kupienia kilku usuniec na wizyte (talia 70 chce byc rzezbiona),
     - ENCHANT (edycje) zyskuje na wartosci, bo edycja na karcie ktora ciagniesz rzadziej jest slabsza -> rozwazyc edycje na CALEJ randze albo na calym kolorze.
   Bez tego run bedzie plaski mimo naprawionej talii.

6. SLOWA KLUCZOWE, KTORE SKALUJA SIE Z ROZMIAREM TALII / DLUGOSCIA WALKI:
   ZNIWO (mult x grave) -- rozwala ogon rozkladu, cap obowiazkowy (liczby w polu balance).
   ECHO (chips x plays) -- rosnie, bo walki maja 5-8 tur zamiast 2. Wartosci 3-7 w talii startowej sa OK, ale ECHO 10 z reward_pool przy 8 zagraniach da +80 chipow; zaakceptowac lub sciac do 8.
   PRZECIAZENIE (szklo, durability 2-3) -- przy dluzszych walkach szklo pekа w ciagu jednej walki zamiast trzech. Podniesc durability w reward_pool z 2/3 na 4/5.
   LAWINA (retrigger x liczba kart CHAOS) -- przy 5 aspektach szansa na 3 karty CHAOS w zagraniu spada; keyword traci moc. Zmienic cap z "mini(3, chaos_count)" na "mini(3, chaos_count + 1)" albo przeniesc na "karty aspektu sasiedniego".
   KOMBINAT (streak tego samego ukladu) -- ZYSKUJE: przy nowym rozkladzie PAIR/TWO_PAIR wystepuja seriami, wiec streaki 3-4 sa realne. Sprawdzic, czy KOMBINAT 75 nie robi z tego silnika glownej osi mocy.

7. LOKALIZACJA I TEKSTY (data/locale/ui.csv, kolumny en+pl, parzystosc %d/%s):
   TIP_DISCARDS "Discards renew every turn - trade freely." STAJE SIE KLAMSTWEM -> przepisac na pule na walke.
   TIP_DECK_ORDER "The deck returns in PLAYED order - never shuffled." -> dopisac, ze rozdanie jest nowe na kazda walke, ale w trakcie walki kolejnosc jest zamrozona i widoczna.
   Nowe klucze: sygil aspektu na karcie, ewentualny komunikat o niezgodnej wersji zapisu, opisy przebudowanych talii alternatywnych (DECK_REAPER_DESC itd. mowia dzis o 16 kartach).

8. WYDAJNOSC / UI:
   Podglad talii (overlays.gd _run_overview, run.gd _open_deck_picker) buduje CardWidget dla KAZDEJ karty talii. Przy 70+ kartach to 70-90 PanelContainerow z TextureRect 1 na karte. Trzeba: leniwe budowanie w ScrollContainer albo grupowanie po aspekcie/randze. Inaczej otwarcie TAB bedzie klatkowac.
   Layout 1280x720: reka to dalej 8 kart, wiec hand_fan.gd bez zmian; przyciski akcji zostaja bottom-anchored.

9. CO SIE NIE ZEPSUJE (sprawdzone, zeby nie tracic na to czasu):
   - enumy: zero nowych wartosci enumow, wiec append-only nienaruszone
   - Poker.evaluate / Poker.BASE: bez zmian, cala naprawa jest po stronie danych + budzetu odrzutow
   - preview / SimPodglad: bez zmian semantycznych, o ile tasowanie jest przed pierwszym rozdaniem
   - reward_pool.tres: zostaje 44 karty, dziala bez zmian (ale patrz punkt 5 i 6)

## FILES

- tools/gen/gen_content.gd
- data/decks/starter.tres
- data/decks/starter_reaper.tres
- data/decks/starter_gardener.tres
- data/decks/starter_oracle.tres
- data/decks/reward_pool.tres
- data/cards/
- src/game/combat/combat_controller.gd
- src/game/combat/scoring.gd
- src/game/combat/combat.gd
- src/game/region/run_state.gd
- src/game/region/run.gd
- src/game/cards/card_widget.gd
- src/game/ui/overlays.gd
- src/game/meta/profile.gd
- data/combat/enemy_a.tres
- data/combat/enemy_a2.tres
- data/combat/enemy_a3.tres
- data/combat/enemy_b.tres
- data/combat/enemy_b2.tres
- data/combat/enemy_b3.tres
- data/combat/enemy_elite_r1.tres
- data/combat/enemy_r2a.tres
- data/combat/enemy_r2a2.tres
- data/combat/enemy_r2b.tres
- data/combat/enemy_r2b2.tres
- data/combat/enemy_elite_r2.tres
- data/combat/enemy_r3a.tres
- data/combat/enemy_r3a2.tres
- data/combat/enemy_r3b.tres
- data/combat/enemy_r3b2.tres
- data/combat/enemy_elite_r3.tres
- data/combat/boss_tower.tres
- data/combat/boss_chariot.tres
- data/combat/boss_strength.tres
- data/combat/boss_devil.tres
- data/combat/boss_hanged.tres
- data/combat/boss_justice.tres
- data/combat/boss_moon.tres
- data/combat/boss_judgement.tres
- data/combat/boss_star.tres
- data/combat/boss_world.tres
- tests/test_scoring.gd
- tests/test_combat.gd
- data/locale/ui.csv
- docs/specs/spec_power.md
- docs/specs/spec_difficulty.md

