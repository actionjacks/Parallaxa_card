# RAPORT: petla, decyzje, buildy, szanse rynkowe (2026-07-31)

8 agentow liczacych z plikow + adwersarz przeliczajacy KAZDA liczbe. Adwersarz obalil albo
poprawil kilkanascie wartosci w pierwszym przebiegu — ponizej sa juz wersje po korekcie.
**Zasada: zadna liczba w tym dokumencie nie pochodzi z pamieci, tylko z `plik:linia`.**

---

## 1. PETLA

| co | ile |
|---|---|
| starc w runie | **6** (4 szczeble + boss + Swiat) |
| ekranow POZA walka | **21** |
| ekranow menu na jedna walke | **3,5** |
| decyzji rozgalezialnych na run | **18** surowo, ~16 po odjeciu omenow-prezentow |
| wyborow drogi (koloru) | **1** |

**Elita ZASTEPUJE szczebel, nie dokłada walki** — i w kazdym z 5 biomow ma wiecej HP niz 3 z 4
szczebli, ktore moze zastapic. "Ryzyko za lup" jest wiec twardsza walka za te sama liczbe walk, a
podpowiedz inline nie mowi, ze zastepuje szczebel o 130-230 HP lzejszy.

**Eskalacja jest liczbowo liniowa** (+99 HP na szczebel), jakosciowo trzy stany na piec starc.
Drugi run w tym samym biomie rozni sie wylacznie kolejnoscia czterech potworow i rzutem bossa.

**Nie wiadomo, ile trwa run czlowieka.** Jedyny zmierzony zegar (85 s) to bot z boostem, ktory
zabijal wrogow w pierwszej turze. W `src/` nie ma ani jednego licznika czasu rozgrywki.

---

## 2. DECYZJE W TURZE

- Reka 8 kart daje **218** legalnych zagran; w biomie Umyslu **381**, u Wisielca **1585**.
- Realnie znaczacych jest **~4** (front Pareto 1,99; w granicach 90% najlepszego 4,03).
- **Podpowiedz "W rece: <uklad>" pokrywa sie z maksymalnymi obrazeniami w 98,9%** rak. Gra
  rozwiazuje wlasna zagadke za gracza.
- Uzywane sa **4,12 z 13** typow ukladu; cztery gorne wiersze tabeli wyplat to dekoracja
  (Kolor 1,7%, Kareta 2,8%, Poker 0,16%, Piec 0,07%), a **MAGNUM OPUS jest niemozliwy z definicji
  puli kart** — i ciagnie za soba niezdobywalne osiagniecie.
- **Odrzut to najsilniejsza os tury i NIE jest decyzja**: trzy darmowe klikniecia na ture, z gory
  wiadomo, ze nie pogarszaja. ~54 puste klikniecia na run. Naprawa nie polega na dosypaniu
  informacji, tylko na nadaniu odrzutowi KOSZTU.
- Dwie najciekawsze geometrie tury (Krzyz Celtycki, Rozklad Trzech Kart) sa zamkniete za
  losowaniem bossa — wiekszosc graczy nie zobaczy ich nigdy.

**Co dziala:** wybor zestawu kart daje **+117%** obrazen nad naiwnym zagraniem (mnoznik, nie
procenty). Bonus precyzji faktycznie ozywil os "ile kart" (bez niego: twarde **0,000%**).
Zwornik wart jest **+14,7%** obrazen — czyli Zaslona IV-V zabiera ~15%, nie 8%, jak sadzilem.

---

## 3. BUILDY

18 slow kluczowych na 181 kartach, ale **tylko 5 grup ma >=3 karty w puli nagrod**. Rozklad:
ECHO 10, Bujnosc 7, Gnicie 7, Furia 6, Spalenie 6 ... Przeciazenie 2, Ofiara 2, Wrozba 2,
Korzenie 2, Klatwa 2.

Run daje **4 sklepy** i **5-8 dokupionych kart**; talia rosnie z 40 do 49-51 (startery
reaper/gardener/oracle maja 31 kart, wiec rosna do 40-42 — o ~20% wieksza gestosc archetypu).
Realnie gracz sklada **jeden archetyp, w okolo dwoch kopiach**.

**Najwieksza dziura balansowa nie jest brakiem kart.** Reroll sklepu za 1 Rtec podwaja liczbe
widzianych slotow — czyli roznica miedzy graczem swiadomym a nieswiadomym to **2x gestosc
archetypu**, i nikt tego mechanizmu nie wycenil.

Biom Umyslu jako jedyny nie ma zadnego mnoznika swojego koloru w `boss_pool`.

---

## 4. RYNEK

### Wyroznik (realny)
Piec Aspektow zamiast czterech kolorow to **3,8x** wieksza przestrzen kombinatoryczna, znaczaca
kolejnosc kart i **zero losowosci w walce**. To jest prawdziwy, policzalny haczyk, ktorego nie ma
zaden konkurent gatunku.

### Steam
Kod GRY istnieje, kod WYDANIA nie istnieje: **0 linii Steamworks**, brak `export_presets.cfg`,
**80 s muzyki**, **2 jezyki**, 102 asercje w testach. Gotowe i realne: Zaslony 1-5, Dzienny Los,
seedy i share-stringi, 25 (nie 26) zdobywalnych osiagniec, Ksiega Odczytan.

### Android
- **Karty przechodza norme dotyku z duzym zapasem.**
- **Zaden przycisk jej nie przechodzi**: wszystkie 10 przyciskow z jawna wysokoscia jest ponizej
  48 dp; najwiekszy ma **26,1 dp (54% normy)**, a pasek z "Zagraj" — **34,6%**.
- **Zero handlerow dotyku** w calym `src/`. 18 miejsc w samej scenie walki dziala na hover, ktorego
  na telefonie nie ma.

### Trzy ryzyka
1. **Gra rozwiazuje wlasna zagadke** (podpowiedz + tabela + dokladny podglad = 98,9%).
2. **62,7% zmapowanej tresci taktycznej jest slaba albo martwa.**
3. **Brak calej warstwy wydawniczej.**

### Trzy atuty
1. **Determinizm** — sprawdzony w kodzie, nie w opisie; to jedyna karcianka gatunku, w ktorej
   podglad jest kontraktem.
2. **Meta gotowa** — Zaslony, Sol, Dzienny Los, Ksiega, osiagniecia.
3. **Kultura audytu** — piec znalezionych i naprawionych precedensow "mechanizm bez dzialania".

---

## 5. WERDYKT

**Hit na Steam: mozliwy, ale nie w tym stanie.** Rdzen jest lepszy niz jego prezentacja — problem
nie polega na braku tresci, tylko na tym, ze gra oddaje graczowi odpowiedz. Trzy zmiany o
najwyzszej dzwigni, w kolejnosci:
1. **Zabrac podpowiedz albo dodac druga os punktacji** (blok/leczenie/Gnicie prawie nigdy nie
   konkuruja z obrazeniami).
2. **Nadac odrzutowi koszt** — 54 puste klikniecia na run to najwiekszy pojedynczy ubytek napiecia.
3. **Wyciac albo naprawic martwa tresc**: MAGNUM OPUS, niezdobywalne osiagniecie, gorne wiersze
   tabeli wyplat.

**Android: NIE bez osobnego przebiegu UI.** To nie jest port, to przeprojektowanie warstwy
wejscia: kazdy przycisk ponizej normy, zero obslugi dotyku, informacja schowana pod hoverem.
Sesja (6 walk) pasuje do mobilnej, wiec praca jest oplacalna — ale to praca, nie eksport.

---

# ANEKS: stan po wdrozeniu planu Steam (2026-07-31)

## Co zostalo zmienione

| punkt | zmiana | dowod |
|---|---|---|
| A1 | **Druga os punktacji** — trzej przeciwnicy, przy ktorych obrazenia nie sa odpowiedzia | Straznica (pulap 120 + kolce), Zwiazany Zgnilizna (zasklepia sie bez Gnicia), Wal (bez bloku zero) |
| A2 | Martwe osiagniecie ozywione; **MAGNUM OPUS przestal byc niemozliwy** | 4 rangi maja >=5 kart w puli, do 3 dziela pare ranga-Aspekt, a inwersja z WYBOREM koloru sciaga reszte |
| A3 | Fork elity placi za zdrowie, ktore kosztuje (+8 Rteci) | elita ma 130-230 HP wiecej niz szczebel, ktory zastepuje |
| A4 | Reroll przestal byc tanim wyszukiwaniem (3, +3) | podwajal widziane sloty za 1 Rtec |
| A5 | **Eksport dziala**: Windows + Linux, 254 MB | `export_presets.cfg`, build bez bledow |
| A6 | Telemetria tempa (czas runu do Ksiegi) | jedyny zegar byl botem z boostem |
| — | Odrzut = pula na pojedynek (6), nie 3 co ture | ~54 puste klikniecia na run |
| — | Podpowiedz mowi ILE ukladow, nie KTORY | pokrywala sie z najlepszym w 98,9% rak |

**MAGNUM OPUS — korekta wlasnego raportu.** W glownej czesci napisalem, ze jest niemozliwy
Z DEFINICJI puli. To bylo prawda w chwili pomiaru i przestalo byc prawda przez MOJA WLASNA
wczesniejsza zmiane: odkad inwersja pozwala wybrac wrogi kolor, piec kart jednej rangi da sie
sprowadzic do wspolnego Aspektu. Test `_magnum_reachable` dowodzi konstruowalnosci ORAZ, negatywnie,
ze piec tej samej rangi w roznych kolorach to nadal tylko FIVE.

## Petla po zmianach — przeklik wszystkich pieciu drog

| biom | walk | koniec |
|---|---|---|
| Sad (LIFE) | 5 | porazka w regionie 2 |
| Biblioteka (MIND) | 2 | porazka |
| Katakumby (DEATH) | 2 | porazka |
| Pogorzelisko (CHAOS) | 3 | porazka |
| Przerost (NATURE) | 2 | porazka |
| z boostem | 6 | **ZWYCIESTWO**, 45/45 HP |

**Wniosek:** slaby bot ginie teraz na kazdej drodze (wczesniej Sad przechodzil 5 walk i szedl
dalej), a run z realna talia konczy sie zwycięstwem. To jest wlasciwy ksztalt: podloga umiejetnosci
poszla w gore, sufit zostal. Rozrzut miedzy droga najlatwiejsza a najtrudniejsza to teraz 5:2,
wczesniej byl 5:0.

**Uwaga metodologiczna, ktorej sam sobie nie odpuszczam:** to jeden przebieg na biom. Wczesniej w
tej sesji ten sam biom dawal 0, 1 i 4 wygrane walki, wiec pojedynczy run NIE JEST dowodem
balansowym — jest sygnalem, ze nic sie nie zablokowalo.

## Domkniete po tym raporcie

**DRUGA OS JEST NA KAZDEJ DRODZE.** Byla w 3 walkach na ~44, wiec kazda z pieciu drog dalo sie
przejsc maksymalizujac obrazenia. Kazdy biom oddal JEDNA zdublowana regule (szczeble 3 i 4 niosly
w kazdym biomie te sama technike) na walke, w ktorej obrazenia nie sa odpowiedzia — a kazde
parowanie idzie WBREW instynktowi biomu, wiec uczy, zamiast zasadzac sie:

| biom | walka | co wymusza |
|---|---|---|
| Sad (blok) | szczebel 4 | **Wal** — zagranie bez bloku nie robi nic |
| Biblioteka (miara) | szczebel 4 | **Straznica** — pulap 120, nadmiar wraca |
| Katakumby | szczebel 3 | **Zwiazany Zgnilizna** — bez Gnicia zasklepia sie do pelna |
| Pogorzelisko (burst) | szczebel 4 | **Straznica** — dokladnie odwrotnosc tego, co nagradza jego prawo |
| Przerost (wzrost) | szczebel 4 | **Zwiazany Zgnilizna** — zgnilizna jest cieniem wzrostu |
| + elity | Pogorzelisko, Przerost | Wal, Straznica |

**PROBA WIELOKROTNA zamiast jednego przekliku.** Wczesniej pisalem, ze jeden run na biom nie jest
dowodem. Dwa przebiegi na kazda droge, slaby bot:

| biom | proba 1 | proba 2 |
|---|---|---|
| Sad | 4 | 5 |
| Biblioteka | 3 | 2 |
| Katakumby | 2 | 2 |
| Pogorzelisko | 2 | 2 |
| Przerost | 2 | 2 |
| z realna talia | **ZWYCIESTWO, 6 walk** | |

Rozrzut jest teraz **stabilny i waski**: cztery drogi trzymaja sie 2-3 walk, Sad odstaje na 4-5.
Wczesniej ta sama droga dawala 0, 1 i 4 — czyli pomiar wreszcie cos znaczy. Sad zostaje
najlatwiejszy, co jest zgodne z jego prawem (blok + glebszy zapas leczenia), ale roznica spadla z
nieskonczonej (5 kontra 0) do jednej walki.

## Zostaje otwarte

1. **Pula 6 odrzutow na pojedynek to duza zmiana, ktorej nie tykal czlowiek.** Bot ja przeszedl;
   to nie to samo. Pierwsza rzecz do przetestowania rekami.
2. **Warstwa wydawnicza poza eksportem**: Steamworks, lokalizacje (2), capsule i trailer.
   MUZYKA DOMKNIETA: piec motywow bojowych zamiast jednego, po jednym na Aspekt (ta sama synteza,
   inna tonacja i barwa — `BIOME_KEYS` w tools/gen/gen_music.py). Walka nosi teraz kolor miejsca,
   w ktorym sie toczy; boss zachowuje wlasny temat. Pakiet urosl o 1 MB (254 -> 255 MB).
