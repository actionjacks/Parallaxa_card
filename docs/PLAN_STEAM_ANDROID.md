# PLAN: hit na Steam TERAZ, Android POTEM (2026-07-31)

Podstawa liczbowa: `docs/RAPORT_HIT.md`. Kazda pozycja ma powod z pomiaru, nie z intuicji.

---

# CZESC A — STEAM (teraz)

## A0. ZROBIONE W TEJ TURZE

**Odrzut przestal byc darmowym klikaniem.** Byl odswiezany co ture, wiec jego wynik byl z gory
znany jako niepogarszajacy — poprawne zagranie brzmialo zawsze "odrzuc trzy, potem mysl", czyli
ok. **54 puste klikniecia na run**. Teraz to **pula na caly pojedynek** (6, +1 za Arkanum Kaplanki).
Kazde uzycie jest pytaniem. Zawieszenie Wisielca znaczy dzis "jedno sito na cala walke", a zwrot
Pentagramu jest jedyna rzecza, ktora oddaje odrzut — czyli dokladnie ta przewaga tempa, dla ktorej
powstal.

**Podpowiedz przestala oddawac odpowiedz.** Zmierzone na 20 000 rak: najlepszy TYP ukladu pokrywal
sie z najwyzszymi obrazeniami w **98,9%**, wiec nazwanie go bylo wreczeniem graczowi rozwiazania
jedynego pytania, wokol ktorego zbudowana jest gra. Mowi teraz, ILE roznych ukladow lezy w rece —
tyle, zeby obiecac, ze reke warto przeczytac, i nie tyle, zeby przeczytac ja za gracza.

## A1. DRUGA OS PUNKTACJI  *(najwyzsza dzwignia, jeszcze nie zrobione)*
Blok, leczenie i Gnicie prawie nigdy nie konkuruja z obrazeniami — dlatego "najlepszy uklad" i
"najwiekszy cios" to prawie zawsze to samo. Dopoki obrazenia sa jedyna osia, kazda podpowiedz
bedzie rozwiazaniem, a 218 zagran bedzie szumem.
**Kierunek:** wrogowie, ktorych NIE DA SIE pokonac samym ciosem (progi bloku, okna leczenia,
przeciwnik ginacy wylacznie od Gnicia) — zeby "co maksymalizuje" bylo pytaniem, a nie stala.

## A2. MARTWA TRESC — wyciac albo naprawic
- **MAGNUM OPUS** jest niemozliwy Z DEFINICJI puli kart, a nie rzadki. Albo pula dostaje
  duplikaty rang w kolorze, albo uklad znika z tabeli.
- **Jedno z 26 osiagniec jest niezdobywalne** (ciagnie je MAGNUM OPUS).
- Gorne wiersze tabeli: Kolor 1,7%, Kareta 2,8%, Poker 0,16%, Piec 0,07%. **Poker i Piec zostaja**
  (padaja ~raz na 600 rak i to najmocniejsze trafienie w grze) — do przemyslenia jest tylko to,
  czy maja byc widoczne przed odkryciem.

## A3. FORK ELITY JEST ZLE WYCENIONY
Elita **zastepuje** szczebel zamiast go dokladac, a w kazdym z 5 biomow ma wiecej HP niz 3 z 4
szczebli, ktore moze zastapic. "Ryzyko za lup" jest dzis twardsza walka za te sama liczbe walk.
**Napraw:** albo elita DOKLADA szczebel, albo jej lup rosnie na tyle, by pokryc roznice HP.

## A4. REROLL JEST UKRYTYM WYSZUKIWANIEM
Reroll sklepu za 1 Rtec podwaja liczbe widzianych slotow, czyli roznica miedzy graczem swiadomym
a nieswiadomym to **2x gestosc archetypu**. To wieksza dziura balansowa niz brak kart.
**Napraw:** cena rosnaca od pierwszego uzycia, albo limit na sklep.

## A5. WARSTWA WYDAWNICZA (bez tego nie ma premiery)
Stan: **0 linii Steamworks**, brak `export_presets.cfg`, **80 s muzyki**, **2 jezyki**,
102 asercje. Kolejnosc: preset eksportu -> Steamworks (chmura + osiagniecia + karty) ->
muzyka do ~12 min -> capsule i trailer -> demo na NextFest.

## A6. TELEMETRIA TEMPA
Nikt nie wie, ile trwa run czlowieka — jedyny zegar to bot z boostem zabijajacy w pierwszej turze.
Bez tego kazda decyzja o dlugosci runu jest na oko. **Minimum:** czas runu, czas walki, liczba tur,
zapisywane do profilu.

---

# CZESC B — ANDROID (potem, ale zaplanowane teraz)

To **nie jest port, tylko przeprojektowanie warstwy wejscia**. Sesja (6 walk) pasuje do mobilnej,
wiec praca jest oplacalna — ale to praca.

## B1. DOTYK (blokujace)
- **Zaden przycisk nie spelnia normy 48 dp.** Wszystkie 10 z jawna wysokoscia sa ponizej;
  najwiekszy w grze ma **26,1 dp (54% normy)**, pasek z "Zagraj" — **34,6%**.
  **Napraw:** minimalna wysokosc dotykowa jako stala w `Chrome`, wymuszana w `Chrome.button()`,
  wiec jedna zmiana podnosi kazdy przycisk w grze.
- **Zero handlerow dotyku** w calym `src/`. Potrzebne: tap, long-press (zamiast hovera), swipe na
  wachlarzu reki.
- **Karty przechodza norme z duzym zapasem** — jedyny element, ktory juz jest mobilny.

## B2. INFORMACJA SCHOWANA POD HOVEREM
18 miejsc w samej scenie walki dziala na najechanie, ktorego na telefonie NIE MA. Leksykon juz
dziala na klikniecie i jest wzorcem: **wszystko, co dzis jest tooltipem, musi miec wersje na
przytrzymanie.**

## B3. UKLAD PIONOWY
1280x720 poziomo jest do zniesienia na tablecie, nie na telefonie. Reka MTG-Arena, tabela wyplat
i kolumna matematyki wymagaja osobnego ukladu portretowego.

## B4. KOLEJNOSC
`B1 (dotyk + rozmiary) -> B2 (long-press) -> B3 (portret) -> testy na realnym urzadzeniu`.
Zadnego z nich nie da sie zrobic "przy okazji" — kazdy to osobny przebieg z wlasnymi zrzutami.
