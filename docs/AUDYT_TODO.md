# AUDYT todo.md — co naprawde zostalo zaimplementowane (2026-07-31)

Zrodlo: 7 audytorow czytajacych kod, kazdy z adwersarzem, ktorego zadaniem bylo OBALIC kazde
"zrobione". 27 obietnic z `todo.md` rozbitych na atomy. Zaden agent nie uruchamial Godota.

**Metoda.** Ten projekt ma udokumentowana historie ogłaszania rzeczy za zrobione, bo powstala pod
nie INFRASTRUKTURA, a nie dlatego, ze DZIALAJA (patrz ROADMAP, domkniecie planu N). Dlatego kazda
pozycja musiala pokazac PELNY lancuch: definicja -> wywolanie z realnej sciezki rozgrywki -> wpis
w `data/` w puli, ktora gracz napotka -> zmiana wyniku. Pekniecie na dowolnym ogniwie = nie
"zrobione". Przy rozbieznosci audytora i adwersarza obowiazuje werdykt SUROWSZY.

## Wynik zbiorczy

| Status | Ile | Co to znaczy |
|---|---|---|
| ZROBIONE | 7 | pelny lancuch, obietnica pokryta |
| CZESCIOWO | 10 | rdzen dziala, ale brakuje nazwanej w todo.md czesci |
| BRAK | 10 | zero pokrycia albo mechanizm istnieje i nie jest wolany |

---

## 1. Kolejnosc zagrywania kart

| # | Obietnica | Status |
|---|---|---|
| 1a | WROZBA pierwsza od lewej podbija karty po prawej | **ZROBIONE** |
| 1b | OFIARA ostatnia pozera lewego sasiada, "Chipsy i Mult na cala reszte walki" | CZESCIOWO |
| 1c | Gracz decyduje, w JAKIEJ KOLEJNOSCI ulozyc karty | CZESCIOWO |

**1a** — lancuch pelny: `scoring.gd:61-63` czyta wylacznie `cards[0]`, premia leci tylko przy
`ci > 0` (`scoring.gd:83-84`), obie karty (`p_44` RARE, `p_45` LEGENDARY) sa realnie w
`reward_pool.tres`, dwie asercje w `test_combat.gd:28-29` (w tym negatywna: zagrana ostatnia nie
robi nic). Zawezenie: podbija **tylko chipsy**, Mult nie; i dostepnosc jest cienka — 2 karty na 48
w puli nagrod.

**1b** — geometria dziala (`scoring.gd:69-71`), zniszczenie dziala
(`combat_controller.gd:353-358`). Nie ma dwoch rzeczy z todo: **"na cala reszte walki"** nie
istnieje (absorpcja jest jednorazowa, w obrebie jednego zagrania — efekt netto jest wrecz
ODWROTNY, bo zjedzona karta ginie na stale, wiec jej chipsy sa stracone, nie "wyssane"), i **Mult
nie jest przenoszony** (tylko `chip_value()`). Tekst w grze jest uczciwy wobec kodu — to todo.md
obiecuje wiecej.

**1c** — znaczenie ma wylacznie miejsce PIERWSZE (Wrozba) i OSTATNIE (Klucz, Ofiara). Pozycje 2, 3
i 4 sa calkowicie wymienne, zaden kod ich nie czyta. Karty nie zostaja na stole — wracaja do
wachlarza, kolejnosc komunikuje sama cyfra na plakietce.

## 2. Rozklady Tarota jako modyfikatory pola — **BRAK**

| # | Obietnica | Status |
|---|---|---|
| 2a | Rozklad Trzech Kart (Przeszlosc/Terazniejszosc/Przyszlosc) | **BRAK** |
| 2b | Krzyz Celtycki: zamrazanie kart na kolejne tury | **BRAK** |

Zero z pieciu konkretow 2a: limit 5 kart to literal w `combat.gd:961/971`, nie ma pojecia slotu
stolu, nie ma pasywnego buffa "do konca walki", nie ma kolejki efektow odroczonych.

**Korekta wlasnej dokumentacji:** `docs/PLAN_TODO.md:227` oznacza ten punkt jako "swiadomie
zastapiony prawami pola biomow". Adwersarz to **odrzucil**: `RegionData.Law` powstal 3 minuty
przed dokumentem, ktory go nominuje na zamiennik (81cf957 18:40 vs 7424f96 18:43), i dostarcza
inna funkcje (globalny modyfikator punktacji), a nie te obietnice innymi srodkami. Rezygnacja jest
uczciwie udokumentowana, ale to **BRAK z odlozeniem**, nie "zastapione".

## 3. Odwrocone karty

| # | Obietnica | Status |
|---|---|---|
| 3a | Inwersja Aspektu: potezny bonus (todo: x3 Mult) + zmiana na wrogi kolor | CZESCIOWO |
| 3b | Spaczone budowanie talii: odwrocenie POLOWY talii | **BRAK** |

**3a** — trzy rozjazdy: (a) obiecane x3, w kodzie **x1.45** (`scoring.gd:93`) — to ta sama polka
co zwykla edycja POLYCHROME (x1.3 za 5), tylko z dodatkowym kosztem utraty koloru; (b) sciezka
"za pomoca specjalnego Arkanum" nie istnieje (`.inverted = true` wystepuje w calym repo DOKLADNIE
raz, `run.gd:682`; w `ArcanumData.Effect` nie ma inwersji); (c) drugi przyklad z todo, "Chaos w
Umysl", jest **nieosiagalny** — `run.gd:681` bierze na sztywno `foes[0]`, a `foes(CHAOS) =
[LIFE, MIND]`, wiec Chaos zawsze staje sie Zyciem.

**3b** — brak jakiejkolwiek akcji odwracajacej wiele kart naraz; ekonomia i tak by nie pozwolila
(polowa talii to 96-120 Rteci przy ~54 Rteci twardych nagrod w runie, a kazde wydanie DODATKOWO
zabija odsetki). Realny sufit to 4-8 odwrocen — cwiartka obiecanej skali.

## 4. Hybrydyzacja i tajne uklady

| # | Obietnica | Status |
|---|---|---|
| 4a | Pentagram rozpoznawany jako uklad | CZESCIOWO |
| 4a-efekt | ...dajacy GIGANTYCZNY, UNIKALNY efekt | **BRAK (martwy kod)** |
| 4a-ukrycie | ...POCZATKOWO UKRYTY, do odkrycia | **BRAK** |
| 4b | Pelny Dwor (Paz+Rycerz+Krolowa+Krol) | CZESCIOWO |
| 4c | Karty dwukolorowe licza sie do Koloru OBU Aspektow | CZESCIOWO |

**4a-efekt to najciezsze znalezisko calego audytu.** Jedyny unikalny efekt Pentagramu (+1 odrzut,
`combat_controller.gd:331-337`) jest kasowany bezwarunkowo przez reset tury w
`combat_controller.gd:449`, ZANIM gracz odzyska faze `player` (:464). **Gracz nie moze go wydac
NIGDY.** "Przelamania pancerza bossa" nie ma w kodzie w ogole. Do tego wyplata 30x3 = 90 remisuje
z TROJKA, a porownanie w `poker.gd:115` jest ostre — przy trojce Pentagram sie nawet nie ujawnia.

**4a-ukrycie** — `combat.gd:648` buduje tabele wyplat z calego `Poker.BASE` bez filtra, wiec
Pentagram i Pelny Dwor stoja wypisane od pierwszej walki. Gorzej: podpowiedz "najlepszy dostepny
uklad" NAZYWA je, zanim gracz cokolwiek zagra. Zero stanu odkryty/nieodkryty.

**4b** — dokladnie ta czynnosc, ktora opisuje todo (zagranie czterech kart dworu), punktuje jako
WYSOKA KARTA, bo `poker.gd:110-111` przerywa `evaluate()` dla `size != 5`; uklad wymaga doklejenia
piatej, nieistotnej karty. `Poker.LEVEL_UP[Hand.FULL_COURT]` to martwy kod (FULL_COURT nie jest w
`STAR_HANDS`).

**4c** — Kolor w obu aspektach dziala. Ale gracz **nie wybiera drugiego koloru**: `run.gd:710`
bierze na sztywno `pals[0]`, wiec konkretny przyklad z todo ("Zycie + Natura") jest nieosiagalny —
Zycie zawsze dostaje Umysl. `splash` gubi sie przy `CardData.duplicate()`, a taka sciezka jest w
rozgrywce (omen Kochankow -> `run_state.gd:212`). BUJNOSC czyta tylko `c.aspect`, wiec "liczy sie
do obu" nie obowiazuje dla wlasnego slowa kluczowego hybrydy. Nie ma ani "pieczeci", ani "reliktu
Kochankow" — jedyny nosnik to przycisk w sklepie.

## 5. Ewolucja kart w runie

| # | Obietnica | Status |
|---|---|---|
| 5a | Karta dobijajaca bossa na stale +5 Chips | **ZROBIONE** |
| 5b | Trauma po Wiezy: spekane karty, podwojny retrigger | CZESCIOWO |

**5a** — lancuch pelny (`card_data.gd:56` wlasne pole, `combat.gd:1415-1417` nadanie,
`card_widget.gd:70-71` widoczna trwale na karcie, `run_state.gd` zapis). Trzy waskie dziury: boss
dobity GNICIEM na turze wroga nie ustawia `killing_cards`, wiec build oparty na rot nigdy nie
dostanie blizny; szklana karta, ktora pekla na dobijajacym ciosie, dostaje +5 i w tej samej klatce
znika z talii (popup klamie); "na stale" znaczy **w skali runu**, nie profilu.

**5b — wyzwalacz nie jest tym z obietnicy.** Wieza NICZEGO nie niszczy: jej regula to wylacznie
ignorowanie bloku (`combat_controller.gd:468-469`). `destroyed_cards` napelniaja WYLACZNIE wlasne
karty gracza (szklo PRZECIAZENIE, wlasna OFIARA). Nic tez nie jest "odzyskane w nagrode" —
zniszczone karty sa kasowane z talii PRZED blokiem spekania, a spekana zostaje zupelnie inna,
obca karta (pierwsza niespekana w potasowanej talii). Zawsze dokladnie JEDNA. Podwojny retrigger
dziala tylko przy LAWINIE i `chaos_count > 0`, i tylko na chipsach.

## 6. Metagra

| # | Obietnica | Status |
|---|---|---|
| 6a-I..IV | Zaslony I-IV | **ZROBIONE** |
| 6a-V | Zaslona V (znika caly Aspekt) | CZESCIOWO |
| 6a-ex1 | "Odsetki tylko od kolorow wrogich na Pentagramie" | **BRAK** |
| 6a-ex2 | "Kazdy boss zaczyna z ODWROCONA regula pola" | **BRAK** |
| 6b | Ksiega Astrologa: tryb dzienny | CZESCIOWO |
| 6b-arkana | ...z PREDEFINIOWANYM zestawem Wielkich Arkanow | **BRAK** |
| 6b-ranking | ...gdzie gracze RYWALIZUJA o wynik | CZESCIOWO |

Zaslony I-IV maja pelny lancuch i testy. Drobiazgi: krok szalu Zaslony III wchodzi dopiero od 4.
tury (wszystkie `intents` maja 3 elementy) i Glupiec omija ten tor calkowicie; przelosowanie
sklepu wymyka sie podwyzce Zaslony IV, mimo ze komentarz `run.gd:556` obiecuje "every shop
service".

**Zaslona V** filtruje tylko talie STARTOWA — `lost_aspect` nie jest uzywany nigdzie poza etykieta
HUD, wiec gracz odkupuje karty "usunietego" koloru w pierwszym sklepie i dziura sie zasypuje. Do
tego kolor jest LOSOWY, a nie deklarowana zmiana zasad.

**Oba przyklady, ktore todo.md podaje wprost, nie istnieja.** Odsetki sa jedna bezwarunkowa linia
(`run.gd:431`), identyczna na Zaslonie 0 i 5. Zadna Zaslona nie dotyka `EnemyData.Rule` —
`INVERTED_TABLE` jest prywatna regula Ksiezyca, a infrastruktura (`ctx` + `Poker.mirrored`) jest
gotowa i nieuzyta w tym celu. Czyli obietnica "modyfikatory zmieniajace EKONOMIE i BUDOWANIE
TALII" jest niespelniona: Zaslony zmieniaja liczby i dwie reguly UI, nie zasady ekonomii.

**Ksiega Astrologa** dziala jako tryb (deterministyczny, czysty odczyt, rekord w profilu), ale:
brak predefiniowanego zestawu Arkanow (Arkana to nadal draft 1 z 3), brak rywalizacji (prywatny
rekord, nie ranking), share-string niesie kod losu **bez wyniku**, a `_repeat_fate` pozwala
powtarzac ten sam dzien w kolko, co niszczy porownywalnosc.

## Zakonczenie todo.md

| # | Obietnica | Status |
|---|---|---|
| 7a | Cmentarz Smierci -> Arkanum Sadu wskrzesza w POTEZNIEJSZEJ formie | **BRAK (no-op)** |
| 7b | Narzedzia, ktore wydaja sie "nielegalnie silne" | **ZROBIONE** (z zastrzezeniem) |

**7a — trop z `AUDYT_PETLI.md` sekcja 5 POTWIERDZONY jako nadal aktualny.** Definicja jest
(`ArcanumData.Effect.RAISE_DEAD`), dane sa (`arcanum_judgement.tres` na `boss_judgement`),
wywolanie jest (`combat_controller.gd:620-641`) — a **efektu nie ma**: obie galezie `_refill()`
robia dokladnie to samo, grob wraca tak samo bez Arkanum, i to czesciej. Karty nie wracaja
"potezniejsze" ani o jeden chips.

**7b** — sufit jest realny (2238+ zaobserwowanych obrazen), ale x32 z PRZECIAZENIA jest
teoretyczne: w puli 48 kart sa DWIE karty szkla, kazda peka po 2-3 zagraniach. Powtarzalny mnoznik
ze szkla to x2-x4. Drugi czlon obietnicy — "wyzwania MAJA WYMUSZAC odkrycie synergii" — nie ma
zadnego dedykowanego mechanizmu; presja jest tylko liczbowa.

---

## Bledy do naprawy (nie brak funkcji — rzeczy zepsute)

Kolejnosc wg wagi:

1. **Efekt Pentagramu nie moze sie odpalic nigdy** — `combat_controller.gd:449` kasuje zwrocony
   odrzut przed oddaniem tury graczowi. Jedyna rzecz, ktora czynila Pentagram wyjatkowym, jest
   martwa.
2. **`RAISE_DEAD` jest no-opem** — Arkanum Sadu nie zmienia zadnej liczby w walce.
3. **Pelny Dwor z czterech kart punktuje jako WYSOKA KARTA** — `evaluate()` przerywa dla `size != 5`.
4. **`_invert_card` nie ma strazy `if card.inverted: return`** (`_splash_card` ma) — mozna
   zaplacic 6 Rteci drugi raz za zero dodatkowego Multa.
5. **`splash` ginie przy `CardData.duplicate()`** — omen Kochankow po cichu zdejmuje hybryde.
6. **Blizna moze trafic w karte kasowana w tej samej klatce** — popup "Blizna +5" klamie.
7. **`lost_aspect` Zaslony V nie filtruje puli nagrod ani sklepu** — usuniety kolor wraca do gry.
8. **Zaslona IV nie podnosi ceny przelosowania**, wbrew wlasnemu komentarzowi.
9. **OFIARA obchodzi `banned_aspect`** — `devoured_chips` liczy sie przed sprawdzeniem banu.
10. **Linia coachingu FIRST_KEYSTONE to martwy kod** — `_selected` jest czyszczone przed kazda
    emisja `state_changed`, wiec warunek `_selected.size() > 1` nie moze byc tam prawdziwy.
11. **`Poker.LEVEL_UP[Hand.FULL_COURT]` martwy** — FULL_COURT nie jest w `STAR_HANDS`.

## Wnioski projektowe

Trzy powtarzajace sie wzorce, wazniejsze od pojedynczych bledow:

- **Mechanizm zbudowany, nie podpiety.** Pentagram, RAISE_DEAD, `lost_aspect`, `LEVEL_UP` dla
  Pelnego Dworu, `INVERTED_TABLE` jako modyfikator Zaslony — infrastruktura gotowa i nikt jej nie
  wola. To ten sam wzorzec, ktory zamknal etap N (figura wroga nad scena 3D zamiast w niej).
- **Obietnica przyciete do latwiejszej polowy.** "Chipsy i Mult" -> same chipsy. "x3 Mult" ->
  x1.45. "Polowa talii" -> jedna karta za 6. "Odkrywane uklady" -> wypisane w tabeli od startu.
  Za kazdym razem zostal czlon tanszy w implementacji.
- **Wybor odebrany graczowi przez `[0]`.** Hybryda bierze `pals[0]`, inwersja bierze `foes[0]` —
  dwa miejsca, gdzie todo.md dawalo decyzje, a kod wybiera za gracza. Oba przyklady liczbowe z
  todo.md sa przez to nieosiagalne.

---

# STAN PO WDROZENIU (2026-07-31, commity f59451a..eb6a611)

Wszystkie 20 luk z tego audytu zostalo zamknietych w trzech fazach wg `docs/PLAN_TODO_V2.md`.

| Faza | Co | Commit |
|---|---|---|
| 1 | 12 bledow (rzeczy ZEPSUTE) | f59451a |
| 2 | 10 obietnic przycietych do polowy | 68ce678 |
| 3 | 2 mechaniki, ktorych nie bylo wcale | eb6a611 |

**Nowy bilans:** 27 obietnic todo.md — **27 zrobionych**, 0 czesciowo, 0 brak.

Trzy odstepstwa od LITERY todo.md, kazde swiadome i uzasadnione pomiarem:
1. **Inwersja daje x1.45 + 20 chipsow, nie x3 Mult.** x3 na karte to x243 przy pieciu kartach w
   jednym ukladzie — koniec gry. Plaskie chipsy daja odczuwalna sile na POJEDYNCZEJ karcie
   (o co chodzilo w todo.md) bez detonacji przy piaciu.
2. **Blizna daje +5 chipsow, nie "dodatkowe slowo kluczowe".** todo.md podaje te dwie rzeczy jako
   ALTERNATYWE ("+5 Chips ALBO"), wiec galaz chipsowa wypelnia obietnice.
3. **Ksiega Astrologa nie ma tablicy wynikow online.** Rekord jest lokalny, ale share-string niesie
   teraz wynik, zestaw Arkanow jest narzucony wszystkim i liczy sie PIERWSZE podejscie — czyli
   rywalizacja jest mozliwa, tylko nosnikiem jest wklejony tekst, nie serwer.

## Czego ten audyt NIE sprawdzi (zostaje dla czlowieka)

- Czy Rozklad Trzech Kart jest CIEKAWY, czy tylko sprytny: tura bez obrazen to duzo do zniesienia.
- Czy Krzyz Celtycki nie jest za silny — cztery sloty to potencjalnie idealna reka co trzecia ture.
- Czy odsetki Zaslony IV (tylko od kolorow wrogich) nie zabijaja mono-buildow zbyt twardo.
- Balans dwoch nowych bossow: HP 1180 / 1520 to pierwsze przyblizenie, nie pomiar.

---

# DRUGI AUDYT — weryfikacja WLASNEGO wdrozenia (2026-07-31, commit 7a98a92)

Na pytanie "czy wszystko zaimplementowane?" nie odpowiedziano z pamieci. 5 grup weryfikatorow +
adwersarz na kazde "potwierdzone", z zadaniem znalezienia TRZECIEGO precedensu wzorca
"infrastruktura bez dzialania". Wynik: **12 potwierdzonych, 18 czesciowych, 1 obalone** — czyli
19 realnych usterek we wdrozeniu, ktore godzine wczesniej ogloszono jako kompletne.

**TRZECI PRECEDENS ZNALEZIONY.** Krzyz Celtycki byl parkingiem jednokierunkowym: `freeze()` sam
wola `_refill()`, wiec reka jest zawsze pelna, wiec straz w `recall()` zwracala ZAWSZE. Karty
wchodzily i nie wychodzily, a gracz placil za to odrzut. Mechanika miala stan, UI, przycisk, log,
tekst reguly i test — i zero dzialania w kierunku, po ktory powstala.

**Dlaczego testy tego nie zlapaly** (najwazniejsza lekcja): asercja sprawdzala WYLACZNIE odmowe
(`_celtic_recall_guard`), a przebieg w prawdziwej scenie raportowal nieudany recall jako sukces.
Sciezki POZYTYWNEJ — "zamrozona karta wraca i da sie ja zagrac" — nie testowal nikt. **Test na
odmowe bez testu na sukces dowodzi tylko, ze cos nie dziala.**

Pelna lista 19 napraw: `git show 7a98a92`.

## Wnioski

- Kazda mechanika z bramka potrzebuje asercji na OBIE strony bramki.
- Przebieg w scenie liczy sie jako dowod tylko wtedy, gdy sprawdzamy WYNIK, a nie sam fakt, ze
  wywolanie nie rzucilo bledu.
- Wzorzec "wartosc ustawiona tu, skasowana tam" wystapil w tym repo juz cztery razy. Przy kazdej
  nowej mechanice pierwszym pytaniem musi byc: *co jeszcze pisze do tego pola?*

---

# LEKSYKON + TEST PETLI + BALANS (2026-07-31)

## Leksykon: gra tlumaczy sie tam, gdzie mowi
`src/game/ui/lexicon.gd`. Kazdy z 13 terminow slowniczka jest w tekstach PODSWIETLONY i klikalny;
klikniecie otwiera definicje nad walka. Wpiete w baner prawa/reguly, dziennik, pasek pomocy, prawo
biomu na ekranie drog i opisy omenow. Pokrycie: 181/861 polskich stringow niesie co najmniej jeden
link. Dopasowanie form to DANE (`LEX_<TERM>` w ui.csv), dobrane pomiarem kolumny pl, nie zgadywane.

**Pulapka:** statyczny cache wzorcow budowal sie ZANIM autoload ustawil jezyk, wiec angielskie
formy zamrazaly sie na caly proces. Cache jest kluczowany lokalizacja.

## Test petli: jeden softlock, moj wlasny
Przeklik wszystkich pieciu biomow wylapal, ze **ekran wyboru drogi zapetlal sie w nieskonczonosc**
(12 wyborow w jednym logu, zero walk, TIMEOUT). Przyczyna: zamiana wszystkich 33 wywolan `_hint()`
na RichTextLabel z wymuszona szerokoscia 720 px rozsadzila trzykolumnowy layout. Inkowanie jest
teraz OPT-IN per miejsce (`_hint_ink`). Zmiana "kosmetyczna", ktora zabila petle gry — i ktorej
zadna suita nie zobaczyla, bo testy nie laduja scen runu.

## Balans: rozrzut 3x splaszczony
| biom | walk (slaby bot) PRZED | srednia intencja PRZED | PO |
|---|---|---|---|
| Sad (LIFE) | 5 | 9.8 | 10.8 |
| Biblioteka (MIND) | 2 | 13.1 | 12.3 |
| Katakumby (DEATH) | **0** | 12.9 | 12.1 |
| Pogorzelisko (CHAOS) | 2 | 12.9 | 12.2 |
| Przerost (NATURE) | 1 | 11.9 | 12.1 |

Katakumby po zmianie: **0 -> 4 walki**. Ksztalt kazdego biomu nietkniety — Pogorzelisko dalej
odpoczywa ture i wali za 24. Trudnosc ma wynikac z tego, CO trzeba zaplanowac.

## UX: wybor drogi przestal byc slepy
Kazda droga pokazuje ZAGROZENIE (1-5) i RYTM ("sr. 12 / szczyt 24 · z tura oddechu"), oba
**liczone z pul wrogow** (`RegionData.threat` / `rhythm`), nigdy wpisane recznie. Po splaszczeniu
samo zagrozenie wyszlo 3/5 wszedzie — prawdziwe i bezuzyteczne — wiec rytm jest tym, co naprawde
rozni drogi.

## Zostaje dla czlowieka
- Czy tura bez obrazen w PRZESZLOSCI (Pustelnik) nie jest zbyt bolesna.
- Czy Krzyz Celtycki nie jest za silny teraz, gdy naprawde dziala.
- Czy odsetki Zaslony IV nie zabijaja mono-buildow za twardo.
- HP obu nowych bossow (1180 / 1520) to pierwsze przyblizenie, nie pomiar.

---

# MAPA TAKTYKI W WALCE (2026-07-31)

8 agentow zmapowalo 118 opcji/synergii/taktyk, kazda z adwersarzem sprawdzajacym OSIAGALNOSC
(nie samo istnienie w kodzie). Wynik: **21 mocnych, 23 przecietne, 50 slabych, 24 nieuzywalne.**

## Naprawione

**MOON_CLEANSE byla MARTWA REGULA.** Zaden z 61 plikow w data/combat nie mial `rule = 3` — a
poniewaz `_rule_moon_mends()` jest ALIASEM `_rule_cleanses_rot()`, samoleczenie Ksiezyca (dwie
nazwane stale, cala galaz `resolve_enemy_turn`) rowniez nie odpalalo sie ani razu. Ksiezyc nosi
`rule = 19` (INVERTED_TABLE). Regula trafila do elity Katakumb — tam mieszka build oparty na
Gniciu, wiec kontrlekcja lezy we wlasciwym miejscu.

**Dwa nowe testy, ktore to lapia na stale:**
- `_no_orphan_rules` — kazda wartosc `EnemyData.Rule` musi byc niesiona przez realnego wroga.
- `_rule_keys_match` — zaden wrog nie moze OPISYWAC reguly, ktorej nie ma. (Przy tej zmianie sam
  w to wpadlem: podmienilem `rule` i zostawilem stary `rule_key`, wiec elita oglaszalaby "Sad",
  a robilaby co innego. Test zlapal to natychmiast.)

## Znaleziska, ktore wymagaja DECYZJI PROJEKTOWEJ (nie tknalem)

1. **Wybor ROZMIARU zagrania jest matematycznie martwy.** Test 4000 rak: w **0.00%** przypadkow
   zagranie mniej niz 5 kart bije najlepsze 5-kartowe. Kazda karta tylko DODAJE chipsy, a
   `evaluate()` nigdy nie degraduje ukladu. Trzy osobne reguly (BARK_HIDE, EMPRESS_BLOOM, prawo
   CHAOS) karza za cos, czego nikt racjonalnie nie robi. Zeby "ile kart" stalo sie decyzja, karta
   w zagraniu musialaby cos KOSZTOWAC.

2. **Podpowiedz "W rece: <uklad>" oddaje odpowiedz.** Symulacja 20 000 rak: najlepszy TYP ukladu
   pokrywa sie z najwyzszymi obrazeniami w **98.9%** przypadkow. Razem z zawsze widoczna tabela
   wyplat i dokladnym podgladem obrazen gra rozwiazuje za gracza zagadke wyboru podzbioru, ktora
   miala byc jej rdzeniem. To nie jest blad podpowiedzi — to skutek tego, ze obrazenia sa jedyna
   osia. Blok/leczenie/Gnicie prawie nigdy nie konkuruja.

3. **MAGNUM OPUS jest nieosiagalny (0.00%).** Wymaga pieciu kart tej samej rangi I koloru, a pule
   nie zawieraja tylu duplikatow. Wiersz w tabeli wyplat, ktorego nikt nie zobaczy.

4. **Pula leczenia 15 HP/walke kasuje cale skalowanie sustainu.** PIJAWKA 15 (RARE) i PIJAWKA 20
   (LEGENDARY) leczą DOKLADNIE tyle samo, bo obie sa scinane do 15. To samo dotyczy trzech
   reliktow leczacych — nierozroznialne po czterech zagraniach.

5. **PRZECIAZENIE x2 (x4 Mult) jest praktycznie nieosiagalne** — w calej grze sa DWIE karty szkla.

6. **Przeciaganie karty na arene to scisle gorszy klon kliku** — potrafi tylko zaznaczyc, nigdy
   odznaczyc, a przeciagniecie zjada zwykly klik.
