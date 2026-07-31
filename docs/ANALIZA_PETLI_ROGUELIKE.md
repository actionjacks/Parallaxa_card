# ANALIZA PETLI JAKO ROGUELIKE (2026-07-31)

8 agentow + adwersarz, ktory **napisal port silnika punktacji w Pythonie i przesymulowal gre**
(port przechodzi 13/13 asercji z `tests/test_scoring.gd`). To nie sa opinie — to pomiary.
Adwersarz **odwrocil cztery z moich wlasnych diagnoz**. Ponizej wersje po korekcie.

---

## 1. SILNIKIEM MOCY NIE JEST TALIA, TYLKO SZUKANIE  *(krytyczne)*

Mediana najlepszego zagrania, talia startowa 40 kart, wg liczby odrzutow:

| odrzuty | 0 | 1 | 2 | 3 | 4 | 6 |
|---|---|---|---|---|---|---|
| obrazenia | 264 | 339 | 392 | 412 | 823 | **1029** |

Szesc odrzutow pozwala obejrzec **26 z 40 kart** przed zagraniem. To mnoznik **3,9x** z zasobu,
ktory nic nie kosztowal.

**KONSEKWENCJA, KTORA WYWRACA DECKBUILDING:** talia konca runu (48 kart) mierzy **844**, czyli
MNIEJ niz startowa 40 (**1029**) — kazda dokupiona karta rozcieńcza szukanie. Budowanie talii
walczylo z najsilniejszym systemem w grze.

**MOJ WLASNY BLAD.** Zmiane "3 odrzuty na ture -> 6 na pojedynek" zacommitowalem jako naprawe
54 pustych klikniec. Nie byla naprawa: walki trwaja **mediane 2 tur**, wiec szesc na pojedynek TO
sa trzy na ture. Zmienila sie etykieta, nie gra.

**ZROBIONE:** `START_DISCARDS` 6 -> **3**. Zmierzone: mediana 1029 -> 412, udzial ukladow
Kolor-lub-lepszy 72% -> 42%, czyli dolna polowa tabeli wyplat wraca do gry.

---

## 2. GORA TABELI JEST DOMYSLNA, DOL JEST DEKORACJA  *(odwrocenie mojej diagnozy)*

Co gracz FAKTYCZNIE zagrywa (starter, 6 odrzutow, 80 prob):

| KARETA | PIEC | STRIT | FULL | KOLOR | POKER | para / 2 pary / trojka / Pentagram |
|---|---|---|---|---|---|---|
| 32,5% | 30,0% | 18,8% | 15,0% | 2,5% | 1,2% | **0,0%** |

Pisalem, ze gorne wiersze sa dekoracja. Jest **odwrotnie**: Kareta jest ukladem modalnym, a cztery
dolne wiersze nie sa najlepszym zagraniem ANI RAZU. Punkt 1 to naprawia u zrodla.

---

## 3. GWIAZDA SPRZEDAJE ZERO ZA 8 RTECI  *(wysokie)*

Zmierzona wartosc ulepszenia (baza mediana 903):

| KARETA | STRIT | PENTAGRAM | TROJKA | FULL | 2 PARY | PARA | KOLOR | FULL_COURT |
|---|---|---|---|---|---|---|---|---|
| 4,48x | 3,08x | 2,89x | 2,76x | 2,45x | 1,57x | 1,38x | 1,05x | **1,00x** |

Dziewiec ofert w jednej cenie, rozstrzal **4,48x do 1,00x** — a FULL_COURT byl sprzedawany pod
etykieta `???`, bo gracz go jeszcze nie odkryl. Gra brala 8 Rteci za nienazwany przedmiot warty
doslownie nic.

**ZROBIONE:** FULL_COURT usuniety ze `STAR_HANDS`.
**ZOSTAJE:** Gwiazda zawsze na ladzie, wybor 1 z 3 zamiast 1 z 9; cena rosnaca 6/10/14/18 zamiast
ukrytego limitu "jedna na wizyte"; **zakaz sprzedawania czegokolwiek pod `???`**.

---

## 4. WALKA TRWA DWIE TURY, WIEC PIEC SYSTEMOW NIE MA KIEDY ZAISTNIEC  *(krytyczne)*

Mediana dlugosci: szczebel 4 = **2 tury**, boss biomu = **2**, Swiat = **2**.

- **HP jest martwe:** 30 HP i 55 HP daja DOKLADNIE po 2 zagrania. Trzecie wymagaloby 70 HP przy
  maksimum 55. Cala ekonomia odpoczynkow i omenow +10/+12 HP nie kupuje ani jednego zagrania.
- **enrage_step Swiata (6) nie odpala sie NIGDY** — prog wchodzi od tury 4.
- Blok, leczenie, Gnicie i danina krwi maja ten sam problem.

Podniesienie limitu leczenia 8 -> 20 jest **zmierzonym no-opem** (15,0% -> 15,0%).

**RECEPTA:** nie tnij HP — daj walce DLUGOSC. Blok ma dzialac w finale (ignorowanie bloku zostaje
wylacznie Wiezy): zmierzone, 10 bloku na ture zamienia 2 zagrania na 4, 20 bloku na 5.
`region_04.tres` nie ma zadnej puli walk — dolozyc 2 szczeble i pelny przystanek przed Swiatem
(dzis 13 Rteci przepada tuz przed ostatnia walka).

---

## 5. EKSPOZYCJA TRESCI

| jest w grze | widzi w jednym runie |
|---|---|
| 61 wrogow | 6 |
| 15 bossow | 2 |
| 21 Arkanow | ~3 |
| 5 biomow | **1** |

To jednoczesnie najwiekszy atut regrywalnosci i najwieksze ryzyko: **pierwsze wrazenie pokazuje
okolo 10% gry**. 120 kombinacji startowych, ale Zaslony sa za wygranymi, wiec nowy gracz ma ich
szesc razy mniej.

Zero wystapien slowa "tutorial" w `src/`. Gra uczy jednorazowymi liniami przy pierwszym napotkaniu
pojecia — elegancko, ale to nie zastepuje pierwszej walki prowadzonej za reke.

---

## 6. CO ZROBIC, ZEBY TO BYL HIT — kolejnosc wg zmierzonej dzwigni

1. **Odrzuty 3 na pojedynek** — ZROBIONE. Bez tego zaden inny system nie ma znaczenia, bo
   szukanie przykrywa wszystko.
2. **Wydluzyc walke do 4-5 tur** — odblokowuje HP, blok, leczenie, Gnicie, enrage naraz. Jedna
   zmiana, piec systemow.
3. **Naprawic sklep**: koniec sprzedawania pod `???`, Gwiazda 1 z 3, cena rosnaca.
4. **Dolozyc walki do Swiata** i przystanek przed finalem.
5. **Pierwsza walka prowadzona za reke** — 10% gry w pierwszym wrazeniu to za malo, zeby gracz
   sam odkryl, po co tu jest.
