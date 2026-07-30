# Parallaxa_card — analiza stanu i mapa drogowa

Stan na: po passach UX/animacje/art/regrywalnosc (PASS 1-3 w PLAYTEST_FEEDBACK.md).
Dokument zywy: aktualizuj przy kazdym kamieniu milowym.

## Gdzie jestesmy (uczciwie)

**Mamy dopracowany VERTICAL SLICE jednego regionu (~5-10 min):** draft buildu (5 stylow) -> mapa
(losowani wrogowie) -> walka (poker, Chips×Mult, 8 keywordow, edycje, relikty, enrage) -> nagroda/omen/
sklep -> boss z regula pola -> zdobycie Arkanum. Pelny art tarota (78 kart PD), SFX, animacje,
determinizm z uczciwym podgladem, PL/EN, testy 14+5 + harness realnego inputu.

**Czego ta gra jeszcze NIE jest:** pelnym rogalikiem. Run konczy sie po 1 regionie („REGION ZALICZONY"
to slepa uliczka), nie ma luku 0->21 (Podroz Glupca z designu), nie ma silnika wzrostu mocy na dluga
mete (poziomowanie ukladow), ekonomia jest plytsza niz w designie (BRAK odsetek!), runu nie da sie
zapisac, nie ma muzyki.

## Luki design-vs-implementacja (z docs/DESIGN.md)

| Z designu | Stan |
|---|---|
| Drabinka WIELU regionow, final = Swiat (21) | BRAK — 1 region, koniec |
| Poziomowanie ukladow (odpowiednik Planet z Balatro) | BRAK |
| **Odsetki ☿** (1 za kazde 5, cap 5) — silnik oszczedzaj-vs-wydawaj | **BRAK** |
| 1 ☿ za niewykorzystany odrzut | BRAK |
| Skip-za-tag (pomijasz walke -> nagroda-tag) | BRAK |
| Karty odwrocone (reversed) | BRAK (zaparkowane) |
| Ascension/stakes po wygranej | BRAK |
| Slownik keywordow: ~25 zaprojektowanych | 8 wdrozonych (brak m.in. Wzrost, Symbioza, Pijawka, Klatwa, Zwloka, Kombinat, Swietosc, Lawina, Przeciazenie, Korzenie, Plon) |
| 22 bossow-Arkanow | 1 (Wieza); 20 artow czeka |

Braki spoza designu: zapis runu (SaveManager niepodpiety), ESC/ustawienia w runie, muzyka/ambient,
eksporty (build do dystrybucji).

## Dlug techniczny (maly, ale notowany)

- Omeny hardcoded w run.gd (TODO editor-first .tres).
- RegionData.fights (legacy) obok fight_pool_1/2 — ujednolicic przy Regionie II.
- run.gd 714 linii / combat.gd 670 — przy Regionie II wydzielic ekrany (map/shop/draft) do osobnych plikow.
- Testy omenow/draftu tylko przez driver (brak headless unit).

## MAPA DROGOWA (kolejnosc = dzwignia na „najlepszy w kategorii")

### M1 — „Pelna Podroz" — ✅ ZROBIONE (commit 8e4d45d)
Run przez 3 regiony az do finalu. To zamienia 5-minutowy slice w ~20-30 min run z prawdziwym lukiem.
- Region II „Zgliszcza" i Region III „Szczyt": nowi wrogowie (skalowani), nowe reguly pol.
- Bossowie z gotowych artow: **Diabel (XV)** — pakt: co ture zabiera karte z reki?; **Ksiezyc (XVIII)**
  — cienie: co cykl przywoluje pomniejszona kopie; final **SWIAT (XXI)** — laczy reguly poprzednich.
- Ciaglosc miedzy regionami: HP/talia/relikty/☿ ida dalej; miedzy regionami PELNY rest + druzgocacy
  wybor (ulepszenie vs leczenie).
- Kolekcja Arkanow rosnie W TRAKCIE runu (po kazdym bossie nosisz jego moc) — druzyna reliktow 3+.
- Warunek wygranej: Swiat pokonany = RUN WYGRANY (ekran zwyciestwa z pelnym rozkladem kart runu).

### M2 — „Silnik wzrostu" (moc musi rosnac szybciej niz proga)
- ✅ Odsetki ☿ (1/5, cap 5) + 1 ☿ za niewykorzystany odrzut — ZROBIONE razem z M1 (8e4d45d).
- ✅ ZROBIONE: **Poziomowanie ukladow**: konsumowalne „Gwiazdy" (odpowiednik Planet; tarotowo: Gwiazda XVII juz jest
  omenem — uzyc motywu konstelacji) podnoszace baze Chips/Mult konkretnego ukladu; w sklepie i nagrodach.
- **Odsetki ☿** (1/5, cap 5) + **1 ☿ za niewykorzystany odrzut** — dwie brakujace nogi ekonomii z designu.
- ✅ ZROBIONE: druga fala keywordow (Wzrost, Symbioza, Pijawka, Klatwa) — pary tworzace nowe archetypy.
- Wiecej edycji/pieczeci (retrigger z designu).

### M3 — „Zycie jakosci" (dluzszy run tego wymaga)
- **Zapis runu** (SaveManager jest w autoloadach — podpiac snapshot RunState po kazdym wezle).
- ESC -> ustawienia/porzuc run (settings_menu z bazy orange juz istnieje).
- Muzyka + ambient (AudioManager.play_music gotowe; brak utworow — prosty dron/ambient proceduralny
  albo CC0).
- Telemetria balansu: bot x20 runow -> winrate/mediany HP per build — strojenie na danych.

### M4 — „Pazur" (unikalnosc i endgame)
- **Karty odwrocone (reversed)**: przy drafcie Arkanum moze byc odwrocone (mocniejszy efekt + cena);
  u bossow: odwrocony boss = harder wariant. Mechaniczno-tematyczny znak firmowy.
- Ascension/stakes po wygranej (drabina trudnosci).
- Skip-za-tag na mapie.
- Meta-odblokowania miedzy runami (nowe karty startowe/Arkana do puli).

## Rekomendacja

Zaczac od **M1** — bez pelnego luku runu gra pozostaje swietnym demo. M1 wykorzystuje w 100% to, co juz
lezy gotowe (20 artow Arkanow, pule wrogow, system regul pola, kolekcje reliktow) i podwaja-potraja czas
runu. Rownolegle drobne z M2 (odsetki + ☿/odrzut) — 1-2h, natychmiastowa glebia sklepu.

## M-POP: Plan popularnosci P1-P7 (2026-07-27) — ZROBIONE
Pelne wdrozenie docs/ANALIZA_POPULARNOSC.md wg specs w docs/specs/ (panel 4 projektantow):
P1 trudnosc+Zaslony 1-5, P2 wektor wykladniczy (szklo/lawina/kombinat/Magnum Opus/Mag)+rzadkosci,
P3 wrogowie=karty dworskie+muzyka proceduralna+akcenty regionow, P4 fork elity+boss-relikt
prosty/ODWROCONY/dokupiony, P5 rozklad tarota+seed+powtorka losu, P6 meta odwrocona (pelna pula
dnia 1, osiagniecia, talie, edycje za Zaslony), P7 tytul "The Cards Do Not Lie".
Weryfikacja: 40 testow headless, review adwersaryjny (18 znalezisk naprawionych), pelne
przeklikniecia real-input: vanilla=DEFEAT (cel trudnosci), BOOST=VICTORY, ELITE=VICTORY, GUI wave.
Nastepne: balans Zaslon na ludziach + telemetria x20, ceremonia jackpotu, prefabrykacja UI.

## Faza C "Wiecej losow" (2026-07-27) — ZROBIONE
Rotacja bossow z 22 Arkanow: 13 bossow (R1 Wieza/Rydwan/Sila, R2 Diabel/Wisielec/Sprawiedliwosc,
R3 Ksiezyc/Sad/Gwiazda, final Swiat), kazdy z regula pola i klaimowalnym reliktem (prosty/ODWROCONY);
6 nowych deterministycznych regul (podwojny cios, resist 20% w uczciwym preview, cap odrzutow,
riposta, osad talii, regeneracja). ENDLESS "Za Swiatem": brama po zabiciu Swiata, Glebia = +50% HP /
+35% intencje / +1 enrage na petle; smierc w Glebi pozostaje WYGRANA. Keyword KORZENIE (blok-rampa).
Osiagniecia 5 -> 21 (prestiz). Dedupe klaimu (ten sam relikt nigdy 2x prosto). Testy 24+23.

## Plan naprawy przyjemnosci E1-E5 (2026-07-27) — ZROBIONE
Pelne wdrozenie docs/PLAN_NAPRAWY.md (zrodlo: PLAYTEST_PRZYJEMNOSC.md):
E1 struktura runu: sklep po KAZDEJ walce (kadencja Balatro, Gwiazda 8 rtec), walka 2 bez sciany
(460/500 HP), +2 wrogow R1 (pule po 3: Nowicjusz 500, Przebity 480), Sol za porazke skalowana
wysilkiem, osiagniecia pierwszej krwi x5 (+10 Soli za KAZDE osiagniecie), omen Kola = pozyczka
(+6 rtec, dlug intencji +2 w nastepnej walce), elita zablokowana na 1. szczeblu, sciezki na mapie
("-> karta + sklep"), pierwsze 3 runy profilu nazwane.
E2 kokpit decyzji: wiazka matmy ("Wrog: X -> Y | Cios A - blok B -> Ty C -> D", zloto przy lethalu),
telegraf REST/WINDUP przy intencji, jawny licznik szalu, zlota selekcja + "Zagraj (N)", tooltipy
(relikt, pula leczenia, talia/grob).
E3 wiedza: paytable (toggle "Uklady", pamietany), podglad next-draws (determinizm widoczny),
przeglad TAB z pelna tabela ukladow, legenda kart dworskich, coaching 1. walki (2 linie, raz na
profil).
E5 Natura: pelnoprawna ramka kart bez artu (gradient, diamenty, scrim) + spojnosc jezyka.
KRYTYCZNY FIX przy akceptacji: _refresh_next_draws mial while na get_child_count()+queue_free()
— queue_free nie zdejmuje dziecka w tej samej klatce, wiec KAZDY drugi render (np. klik Odrzuc)
zawieszal CALA gre w nieskonczonej petli. Diagnoza: bot real-input + flushowane logi zawezily
zgon do jednego kliku; naprawa: remove_child przed queue_free.
Akceptacja E1 (3 swieze runy bota): sklep w runie 1 = 3/3, osiagniec 7 (cel >=2), Sol 127
(cel >=45), sklady/drafty sie roznia (probe_rolls.gd: seed->identyczny sklad, rozne seedy->rozne).
Testy 24+23 PASS; przeklik pelnej petli: walka->nagroda->sklep(zakupy)->mapa->omen->boss->spread.

## Przebudowa odczuc: talia, arena, portrety, biomy (2026-07-30) — ZROBIONE
Skarga gracza: "gra nie daje dobrego wrazenia, udawalo mi sie co najwyzej robic pary, nie czuje
tej gry; karty za male; podglad po prawej bez sensu; trzeba animowanych portretow na srodku;
karty maja miec widoczne kolory i symbole; 5 aspektow = 5 biomow, kazdy daje kolor, 5 kolorow
otwiera ukryty biom z poteznym bossem".

DIAGNOZA (pomiar na zywym silniku, tools/dev/probe_deckmath.gd, 9000 zagran): stara talia
16-kartowa grala dwie pary w 48% tur, a KARETA/POKER/PIEC/MAGNUM = 0.00% — cztery z jedenastu
szczebli drabinki ukladow byly nieosiagalne. Obrazenia 120-426 niezaleznie od decyzji gracza.
Dodatkowo: talia byla tasowana RAZ na run i nietasowana miedzy walkami, wiec kazda walka runu
zaczynala sie ta sama reka.

WDROZONE:
- TALIA PENTAKLOWA: 5 aspektow x rangi 1-8 = 40 kart, kazda ranga w kazdym kolorze. Karty dworskie
  celowo tylko z nagrod/sklepu. Po zmianie: kareta 4.9%, poker 0.17%, piec 0.24%, mediana 228,
  sufit 1928, rozrzut p95/mediana 2.64x. Talie alternatywne = ta sama siatka wygieta w dwa kolory.
- KOREKTA KOLORU: przy 5 kolorach flush jest 3. najrzadszym ukladem (1 na 2531, rzadszy od karety),
  a placil jak 6. Teraz 70x8; obie tabele wyplat sortowane po WARTOSCI, nie po enumie.
- TASOWANIE PRZED WALKA (RunState.shuffle_for_fight, 1 losowanie glowne) + naprawa kontraktu seeda:
  tasowanie talii przeniesione na sub-rng, bo Fisher-Yates zjada N-1 losowan i zmiana rozmiaru
  talii unieważniala kody losu.
- CEREMONIA NALICZANIA: karta po karcie, +N chipsow nad kazda, osobne liczniki Chips i Mult,
  potem iloczyn i cios. Czysto prezentacyjne — liczby pochodza z tego samego Scoring.score.
- NARZEDZIA REKI: sortowanie (dobrane/rangi/kolory, tylko kolejnosc WYSWIETLANIA) + podpowiedz
  "W rece: <uklad>". Powod liczbowy: strit lezy w rece w 22.6% rak, a gracz grupujacy po randze
  znajduje go w 0.5% — traci ~19% obrazen. Problemem byla NIEWIDOCZNOSC ukladu, nie brak mocy.
- KARTY: 108x151 (bylo 80x112), pelnowysokosciowy PASEK KOLORU na lewej krawedzi, SIGIL aspektu
  przy randze (src/game/cards/aspect_sigil.gd — kielich/miecz/pentagram/plomien/lisc, rozne
  SYLWETKA, nie tylko kolorem). Usuniety podglad po prawej: hover sam powieksza karte.
- PIATY KOLOR: RWS 1909 ma tylko 4 kolory, wiec NATURA nie miala zadnego artu. tools/gen/
  gen_nature_suit.py wyprowadza 14 kart z plansz public domain (odbicie lustrzane + zielony
  duotone + sigil + banderola zamiast odwroconego tytulu).
- PORTRETY: src/game/combat/enemy_portrait.gd — plyta 372x644 jako WARSTWA TLA (zero kosztu dla
  budzetu 720p), oddech, zamach przed atakiem, drgniecie przy ciosie, szal, smierc. Bez shadera
  (ukryty ekran testowy chodzi na lavapipe).
- BIOMY: 5 kolorow = 5 PRAW POLA (Sad +2 bloku/karte, Biblioteka +1 karta w rece, Katakumby
  +2 chipsy za karte w grobie, Pogorzelisko 5 kart x1.5 Mult, Przerost karty tyja w rece).
  Run = 3 wybrane biomy + Swiat (10 starc jak dotad; 5 po kolei bylo by +60% dlugosci).
  PIECZECIE w Profile — trwale, przyznawane przy upadku bossa biomu. 5 pieczeci otwiera trzecie
  drzwi przy Bramie Swiata: BIOM ZAPIECZETOWANY (cztery Asy + GLUPIEC), ktorego prawo odwraca
  cala gre: +1 Mult za KAZDY odmienny aspekt w zagraniu.

ODRZUCONE PO POMIARZE: propozycja panelu "talia 70 kart 5x14" — zmierzona daje
P(najlepszy uklad <= dwie pary) 78.1% wobec 42.8%, czyli 1.8x POGARSZA skarge, ktora miala naprawic.

DALEJ: docs/PLAN_TODO.md (T1 Klucz -> T2 Pentagram -> T3 Wtajemniczenia -> T5 Blizny -> T4 Inwersja).

## Wieza, figury wrogow, Klucz (2026-07-30, druga tura) — ZROBIONE
Prosba gracza: "lecimy z pomyslami z todo; kazdy biom ma miec 5 szczebli w formie WIEZY po
ktorej gracz sie wspina; portrety mialem na mysli portrety PRZECIWNIKOW, nie karte w tle --
jak jest kultysta, to chce animowana postac kultysty, animowana jak rycina".

FIGURY WROGOW (tools/gen/gen_foe_figures.py): postac jest WYCINANA z planszy RWS (public domain)
-- to uczciwe zrodlo, bo cala koncepcja gry mowi, ze wrogowie SA kartami dworskimi. Pipeline:
kadr bez marginesu/ramki/banderoli -> flood-fill nieba do alfy zasiany z KAZDEGO piksela
krawedzi (kilka ziaren zostawialo confetti ze speckli druku i linii ramki) -> zachowanie kazdej
wyspy w granicach 16% najwiekszej (NIE tylko najwiekszej: niektore plansze to SCENA -- ciecie do
jednej wyspy scielo Diabla z jego wlasnej karty i zostawialo dwie skute postacie) -> wygaszenie
gruntu od dolu -> 8 klatek warpu pasmowego (oddech + kolysanie, glowa najbardziej, stopy w
ziemi) jako jeden sprite sheet. Pasma i 10 fps sa CELOWE: plynne tweenowanie czyta sie jak
zdjecie z filtrem, kroki czytaja sie jak drzeworyt. Szal przyspiesza do 16 fps. 42 figury, ~5 s
regeneracji. Elita Natury pozycza Siodemke Pentakli (nasza plansza Natury nie ma nieba do
wyciecia). EnemyData.figure/figure_frames; EnemyPortrait gra sheet przez AtlasTexture i CHOWA
ramke plyty (ramka obramowuje KARTE, przy stojacej postaci czyta sie jak dwie kreski obok niej).

WIEZA: biom = 5 szczebli (4 pojedynki + boss na SZCZYCIE), mapa pionowa czytana z gory na dol.
RunState._roll_tower losuje po dwoch przeciwnikow z kazdej puli (pula krotsza niz jej szczeble
powtarza, zamiast skracac wieze -- wysokosc jest stala), wiec wieza Kielichow czyta sie jako
Paz -> Rycerz -> Krolowa -> Krol -> Sila: dwor tego koloru, rosnacy. JEDNA wieza na run + Swiat
= 6 starc i DOKLADNIE JEDNA pieczec, wiec zamkniecie pentagramu wymaga pieciu udanych podrozy.
HP wiezy rampuje +60/szczebel z lagodniejszej bazy (szczebel 1 ~710 zamiast ~1020).

T1 z todo.md — KLUCZ: ostatnia karta w zagraniu liczy PODWOJNIE (chipsy + plaskie slowa
kluczowe; mnozace nietkniete, bo x2 na szkle daloby x8 z jednego klikniecia). ctx["keystone"]
domyslnie false, wiec testy bez zmian. Numery 1..5 na zaznaczonych kartach, zlota plakietka na
ostatniej; kolejnosc klikania = kolejnosc zagrania.

NAPRAWIONE (oba wykryte OBSERWACJA bota, nie czytaniem kodu): final podrozy testowal stara
tablice 4 regionow, wiec po upadku Swiata run ladowal Swiat PONOWNIE w kolko; harness znal tylko
OMEN_TAKE/OMEN_SKIP, wiec omeny-prezenty z E1 (jeden przycisk OMEN_GIFT) zapetlaly go na mapie.

## Domkniecie dlugow + CALE todo.md (2026-07-30, trzecia tura) — ZROBIONE
DLUGI: (1) boss_empress/boss_wheel/boss_fool mialy `rule_key` bez `rule` — gra WYPISYWALA regule
pola i nic sie nie dzialo; wdrozone EMPRESS_BLOOM (leczy 40 przy zagraniu <5 kart), WHEEL_TURN
(cykl intencji przeskakuje o krok), FOOL_MIRROR (intencja = twoj ostatni cios /14, clamp 8-34,
z podgladem na ZAINSCENIZOWANYM zagraniu, nie na poprzednim). (2) Plakietka 5 pieczeci w menu
(wypelnione/puste sigile + lista brakujacych). (3) Biom Zapieczetowany PRZEKLIKANY (PT_SEAL=1):
brama ma trzy drzwi, Asy + Glupiec rozegrani. (4) region_01..03 wycofane; Glebia wchodzila w nie
zamiast wspinac sie na kolejna wieze.

TODO.MD ZAMKNIETE W CALOSCI (szczegoly i liczby w docs/PLAN_TODO.md):
T1 Klucz, T2 Pentagram+Pelny Dwor (po POMIARZE: dostepny 40.2% -> wyceniony na TEMPO, nie
obrazenia; grany 16%, kosztem dwoch par, Kolor nietkniety), T2b hybrydy dwukolorowe (`splash`),
T3 Zaslony III-V zmieniajace ZASADY + Ksiega Astrologa, T4 odwrocone karty (po POMIARZE:
inwersja ZAGESZCZA talie, 1.86%->4.83% szansy na Kolor), T5 blizny (wlasne pole `scar`, bo
`growth` jest celowo nietrwaly). T6 swiadomie zastapione prawami pola biomow.
ZASADA, ktora sie oplacila: pomiar przed kodem. Dwa razy obalil zalozenie planu.
