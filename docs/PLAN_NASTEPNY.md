# PLAN NASTEPNY — audyt petli, przestrzen areny, zrozumialosc, epickie starcia

Zapisane na pozniej (2026-07-31). Cztery strumienie w kolejnosci wykonania: **najpierw AUDYT**,
bo bez niego kazda dalsza zmiana buduje na niesprawdzonym fundamencie, a dopiero po nim wielka
przebudowa przeciwnikow.

Zasady bez zmian: walka 100% deterministyczna, podglad NIGDY nie klamie, enumy APPEND-ONLY,
teksty przez `data/locale/ui.csv` (EN+PL), przyciski akcji bottom-anchored, po kazdym etapie
realny przeklik botem na ukrytym ekranie, **pomiar przed kodem**.

---

## N1. AUDYT CALEJ PETLI — czy wszystko dziala, jest spojne i sensowne

Cel: przejsc gre ekran po ekranie i wypisac WSZYSTKO, co jest zepsute, sprzeczne albo bez sensu.
Nie „poprawiam po drodze" — najpierw pelna lista, potem naprawy wg wagi.

**Zakres (kazdy ekran, kazde przejscie):**
menu -> nowy run (talia/Zaslona/seed/Dzienny Los) -> draft Arkanum -> wybor drogi (5 biomow) ->
mapa/wieza -> omen (wszystkie 8 typow, w tym te z wyborem karty) -> walka (kazde prawo biomu) ->
nagroda -> sklep (wszystkie 6 akcji) -> elita -> szczyt/boss -> klaim relikta -> Swiat -> brama
(3 drzwi) -> Glebia -> Biom Zapieczetowany -> rozklad konca runu -> profil/Ksiega/pieczecie.

**Czego szukac konkretnie (znane obszary ryzyka):**
- **Spojnosc liczb**: czy podglad = wynik, w kazdej regule pola i kazdym prawie biomu.
- **Save/load w kazdym punkcie**: mapa zapisuje run; sprawdzic wczytanie po KAZDYM nowym polu
  (`scar`, `inverted`, `splash`, `cracked`, `seals`, `biomes_walked`, `lost_aspect`).
- **Teksty**: czy kazdy `rule_key`/`law_key` opisuje to, co kod ROBI (raz juz bylo odwrotnie —
  trzy bossy zapowiadaly reguly, ktorych nie bylo).
- **Martwa tresc**: co jeszcze nie jest osiagalne? (`region_01..03` juz wycofane; sprawdzic
  omeny, osiagniecia, edycje, arkana kupowane za Sol).
- **Zaslony I-V**: czy kazda faktycznie zmienia to, co obiecuje jej opis.
- **Tempo**: dlugosc runu w minutach, nie tylko w starciach.

**Narzedzia, ktore juz sa:** `tools/dev/capture_playthrough.gd` (PT_BOOST / PT_ELITE / PT_SEAL /
PT_BEYOND), `tools/dev/balance_report.py`, `tools/dev/probe_deckmath.gd`, `tests/` (44+24 asercje).
**Czego brakuje:** harness, ktory przechodzi KAZDY biom (bot zawsze wybiera pierwsza droge) i
harness dla Zaslon 1-5. Dopisac `PT_BIOME=<id>` i `PT_VEIL=<n>`.

**Wynik etapu:** `docs/AUDYT_PETLI.md` — lista znalezisk z waga (blokujace / mylace / kosmetyczne)
i dopiero z niej plan napraw.

---

## N2. ARENA — wiecej przestrzeni, wiecej 3D

Dzis: portret wroga to animowana figura (sprite sheet) na plaskiej warstwie tla, reszta areny to
2D. Wieza na mapie jest juz prawdziwym 3D (`src/game/region/tower_view.gd`) i to jest wzorzec
do powtorzenia.

**Do zrobienia:**
1. **Arena jako scena 3D w SubViewporcie**, tak jak wieza: podloga/stol, glebia, mgla, jedno
   cieple zrodlo. Karty i HUD zostaja 2D NAD nia — to daje przestrzen bez ryzyka dla layoutu
   720p (ten sam trik, ktory pozwolil wstawic portret 372x644 za zero budzetu pionowego).
2. **Wiecej powietrza**: dzis kokpit, log, paytable i next-draws tloczą sie wokol portretu.
   Rozdzielic na strefy z marginesami; paytable i log moga byc chowane/rozwijane.
3. **Przeciwnik w 3D**: figura jako billboard w scenie 3D (nie na plaskim tle), zeby miala
   perspektywe i cien na podlodze. Alternatywa tansza: parallax dwoch warstw.
4. **Kamera reaguje na beat**: lekki push-in przy zagraniu, cofniecie przy ciosie wroga.

**Pulapki (z pamieci projektu):** SubViewport MUSI miec `own_world_3d = true`, kamera jawnie
`current = true`, tint albedo MNOZY teksture (ciemny tint = czarna plyta), a ukryty ekran testowy
chodzi na lavapipe — bez cieni real-time, bez SDFGI, bez mgly wolumetrycznej.

---

## N3. ZROZUMIALOSC — "gracz czuje, ze wiekszosci nie rozumie"

**Stan zmierzony:** w calym `src/game/` jest **20 miejsc z tooltipem**, a wyjasnien brakuje dla
najbardziej podstawowych pojec gry. Brak kluczy: `HELP_CHIPS`, `HELP_MULT`, `HELP_RTEC`,
`HELP_LAW`, `HELP_VEIL`, `HELP_SEAL`, `HELP_KEYSTONE`.

To jest wlasciwa diagnoza skargi: gra tlumaczy SLOWA KLUCZOWE kart (bo te maja `KWD_*`), ale nie
tlumaczy **wlasnego jezyka** — czym jest Chips kontra Mult, czym jest Rteć, co robi prawo biomu,
po co sa pieczecie.

**Do zrobienia:**
1. **Slownik pojec** — jeden ekran (TAB albo z menu) z definicjami: Chips, Mult, uklad, Klucz,
   Rteć, Sol, Arkanum, relikt, prawo pola, Zaslona, pieczec, Glebia. Kazde 1-2 zdania, po ludzku.
2. **Tooltip na KAZDEJ liczbie w HUD** — pasek HP, blok, zapas leczenia, talia/grob, licznik
   szalu, intencja, kokpit. Zasada: jesli liczba jest na ekranie, da sie na nia najechac i
   dowiedziec, skad sie bierze.
3. **Prawo biomu widoczne W WALCE**, nie tylko na ekranie wyboru drogi — gracz zapomina, w czym
   walczy. Plakietka przy nazwie wroga + tooltip z pelnym opisem.
4. **Pierwszy raz = wyjasnienie**: kazde pojecie pokazuje sie z jednorazowa linia przy pierwszym
   napotkaniu (`Profile.claim_once` juz to obsluguje — tak dziala coaching pierwszej walki).
5. **Weryfikacja**: przeklik i ZRZUTY z najechaniem, nie „kod wyglada dobrze".

---

## N4. PRZECIWNICY: proste vs zaawansowane pule, wlasne techniki, bossy zmieniajace gre

To jest najwiekszy i najwazniejszy etap. **Dowod liczbowy, ze problem jest realny:**
w `data/combat/` jest **46 zwyklych przeciwnikow i ZADEN z nich nie ma reguly pola** — wszystkie
14 regul w silniku naleza wylacznie do bossow. Kazda zwykla walka to ta sama walka z innymi
liczbami: pasek HP i cykl intencji. Stad wrazenie powtarzalnosci.

### N4.1 Dwie pule na biom: PROSTA i ZAAWANSOWANA
- **Prosta** (szczeble 1-2): jedna czytelna technika, ktora UCZY prawa biomu.
- **Zaawansowana** (szczeble 3-4 + elita): technika, ktora prawo biomu LAMIE albo obraca
  przeciwko graczowi.
- `RegionData` ma juz `fight_pool_1` / `fight_pool_2` — pule sa, brakuje ROZNICY miedzy nimi.

### N4.2 Kazdy przeciwnik ma swoja technike
Rozszerzyc `EnemyData.Rule` (APPEND-ONLY!) o reguly dla ZWYKLYCH wrogow. Kazda musi byc:
deterministyczna, widoczna w podgladzie i opisana jednym zdaniem. Kierunki (po jednym na kolor,
proste i zaawansowane):

| Kolor | Prosty | Zaawansowany |
|---|---|---|
| LIFE | leczy sie o X, gdy nie zadasz obrazen | kopiuje TWOJ blok jako swoje HP |
| MIND | co druga tura nie atakuje, ale kradnie karte z reki | wymusza uklad: inny niz zapowiedziany = polowa obrazen |
| DEATH | rosnie w sile za kazda karte w twoim grobie | za kazde zagranie usuwa 1 karte z twojej TALII na te walke |
| CHAOS | intencja losuje sie z 2 zapowiedzianych (obie widoczne!) | podwaja obrazenia, ale tylko co trzecia ture |
| NATURE | ma pancerz, ktory topnieje tylko od 5-kartowych zagran | rosnie o +X HP za kazda karte zostawiona w rece |

**Warunek:** kazda regula MUSI byc policzalna przez `predicted_taken()` / kokpit, inaczej lamie
przymierze. Regula, ktorej nie da sie pokazac w podgladzie, nie wchodzi.

### N4.3 Bossy narzucaja CALKOWICIE inne zasady
Dzis boss ma regule, ktora modyfikuje jedna liczbe. Ma **zmieniac mechanike**:
- boss, ktory odbiera odrzuty i daje w zamian +2 karty w rece;
- boss, przy ktorym uklady licza sie ODWROTNIE (para bije kolor);
- boss, ktory co ture zabiera jeden ASPEKT z gry (nie mozesz grac tego koloru);
- boss, ktory gra WLASNA reka kart przeciwko tobie;
- boss, ktory wymusza zagranie DOKLADNIE N kart.
Kazdy z wlasnym ekranem wejscia, wlasna muzyka/beatem i **jawnym opisem przed pierwsza tura**.

### N4.4 Epickosc = ceremonia, nie tylko liczby
Ceremonia proroctwa i upadek bossa juz istnieja. Dolozyc: wejscie bossa (nazwa, regula, jedna
linia diegetyczna), faza druga przy 50% HP (zmiana reguly W TRAKCIE, zapowiedziana), i ekran po
zwyciestwie mowiacy, CO ten boss zabral graczowi i co zostawil.

**Kolejnosc w N4:** najpierw 2-3 reguly zwyklych wrogow + pomiar botem (czy walki nie robia sie
za dlugie), potem reszta puli, na koncu bossy — bo bossy sa najdrozsze i najlatwiej je przestroic.

---

## Kolejnosc calosci

```
N1 AUDYT (lista znalezisk)  ->  naprawy blokujace z audytu
   ->  N3 ZROZUMIALOSC (slownik + tooltipy)      # tanie, natychmiast poprawia odbior
   ->  N4.1/N4.2 techniki zwyklych wrogow         # najwiekszy zysk dla powtarzalnosci
   ->  N2 ARENA 3D + przestrzen                   # duze, wizualne, mozna rownolegle
   ->  N4.3/N4.4 bossy zmieniajace mechanike      # najdrozsze, na koncu
```

**Dlaczego zrozumialosc przed epickoscia:** epicki boss, ktorego zasad gracz nie rozumie, jest
frustrujacy, nie epicki. N3 jest warunkiem, zeby N4 zadzialalo.

**Do przetestowania przez CZLOWIEKA (bot tego nie zlapie):** balans praw biomow (Biblioteka +1
karta, Pogorzelisko x1.5), czy Zaslona V (brak calego Aspektu) jest ciekawa czy frustrujaca, oraz
ceny w sklepie (odwrocenie 6, rzezbienie 9 przy karcie za 5).
