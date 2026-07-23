# Parallaxa_card — Projekt gry (design)

Status: **faza design, jeszcze bez kodu.** Dokument zywy — aktualizuj przy kazdej decyzji.
Jezyk kodu i tak zostaje angielski (patrz `CLAUDE.md`); ten plik jest notatka projektowa po polsku.

## Wizja

Roguelike-deckbuilder w duchu **Balatro / Slay the Spire**, w motywie **TAROTA**: uzalezniajaca
wspinaczka po drabince bossow + kupowanie i ulepszanie decka, zeby wygrac. Walka jako **pojedynek w
swiecie 3D ze zblizeniem kamery**. Determinizm walki dostaje motyw: **"karty nie klamia"** — wrozba jest
z gory prawdziwa, dokladnie jak zasada `SimPodglad nie moze klamac`.

## Referencje — co bierzemy, co odrzucamy

| Gra | Co bierzemy |
|---|---|
| Balatro | silnik **Chips × Mult**, drabinka ante/blindow, ekonomia + odsetki, number-go-up |
| Slay the Spire | wrog z **HP + telegrafowane intencje**, relikty (= jokery), draft rosnacej talii, meta-struktura |
| Marvel Snap | modyfikatory pola (-> "reguly pola" bossow), krotki eskalujacy budzet tur, push-your-luck |
| Hearthstone | **jezyk slow kluczowych** (system efektow, editor-first), Discover (mini-draft), Battlegrounds |
| Magic: The Gathering | **kolory jako tozsamosci/filozofie** (color pie): identyfikacja + archetyp + kolo sojuszy/wrogosci |

Odrzucamy z gier PvP: kolekcja / ladder / gacha, bluff-vs-czlowiek, RNG-fest.

## Decyzje (ustalone)

1. **RNG = hybryda** — walka DETERMINISTYCZNA (pelna informacja, sim-preview), nagrody ZMIENNE (sklep/drafty/oferty).
2. **Ksztalt walki = pojedynek-silnik** — 1v1 w 3D, nie plansza/lanes; kamera najezdza na pojedynek.
3. **Motyw = TAROT** — determinizm jako "karty nie klamia". Male Arkana = talia-paliwo; Wielkie Arkana (22) = warstwa Fatum/mocy (Duch, ponad kolorami).
4. **Model karty = ranga + kolor(Aspekt) + keyword** — karta scoruje I odpala efekt (Hearthstone-style).
5. **Combo = uklady pokerowe** — para/kolor/street...; **flush (mono-kolor) = payoff jednego Aspektu**, mieszanie kolorow = splash (jak MTG).
6. **Kolory = 5 ASPEKTOW w stylu MTG (NIE zywioly)** — kolor to filozofia + archetyp mechaniczny + kolo sojuszy/wrogosci. Piatka = pelne WUBRG = **pentagram** (pasuje do okultyzmu tarota).
7. **Zasob tury = jedno zagranie + odrzuty** — 1 uklad scoringowy/ture (do 5 kart), keywordy zagranych kart odpalaja sie free, limit odrzutow; tury naprzemienne z wrogiem.
8. **Build = keywordy kart + Wielkie Arkana** — talia (Male Arkana) ROSNIE przez draft (czeste, sklep/nagrody); pasywna warstwa buildu to **Wielkie Arkana zdobyte na bossach** (rzadkie, run-definiujace, jak relikty StS).
9. **Meta = liniowa drabinka regionow (Podroz Glupca)** — boss regionu = Wielkie Arkanum ze znana "regula pola"; pokonanie -> mozesz zabrac je jako relikt; miedzy szczeblami wybory (sklep / nagroda / skip-za-tag). Glupiec(0)=start, Swiat(21)=finalny boss.

## Motyw i kolory: Tarot + 5 Aspektow

Talia = tarot. **Male Arkana** to nasza talia-paliwo w **5 kolorach** (custom 5-suitowa talia; kazdy suit
= jeden Aspekt). **Wielkie Arkana** (22 trumfy: Smierc, Wieza, Kolo Fortuny, Glupiec...) to warstwa
Fatum/Ducha ponad kolorami, dostepna wszystkim.

**Podroz Glupca (rola Wielkich Arkanow):** 22 trumfy to szkielet runu, czytany jako narracja 0 -> 21.
Ty = **Glupiec (0)**; bossowie regionow SA konkretnymi Arkanami (Wieza = zaglada/reset, Smierc =
transformacja, Diabel = pakt/moc-za-cene, Kolo Fortuny = usankcjonowana wariancja); **Swiat (21)** =
finalny boss. **Pokonanie Arkanum-bossa pozwala zabrac je jako pasywny relikt** — ta sama karta jest
przeciwnikiem I moca, ktora potem nosisz (Wieza-boss niszczy -> zabrana Wieza pozwala niszczyc Tobie).
Laczy role bossa i jokera w jedno. Rzadkosc: Male Arkana czeste (sklep/draft), Wielkie Arkana rzadkie i
run-definiujace (z bossow).

Kolory to **Aspekty** — tozsamosci w stylu MTG, nie zywioly (przerezyserowane WUBRG):

| Aspekt | MTG | Filozofia | Archetyp (rodzina keywordow) |
|---|---|---|---|
| **Porzadek / Zycie** | W | prawo, ochrona, trwanie | leczenie, blok, "go-wide", sustain |
| **Umysl** | U | wiedza, kontrola, wrozba | dobor/manipulacja kart, skalowanie, combo-enable |
| **Smierc** | B | ofiara, rozklad, cena za moc | poswiecanie, DoT (Gnicie), usuwanie, moc-za-koszt |
| **Chaos / Wola** | R | pasja, impuls, ryzyko | agresja, burst, ×Mult, push-your-luck, bezposrednie dmg |
| **Natura / Wzrost** | G | instynkt, ekspansja | ramp, wielkie pojedyncze payoffy, wzrost w czasie |

Pentagram — kolo sojuszy i wrogosci (color pie):

```
        Porzadek/Zycie (W)
        /               \
   Natura (G)          Umysl (U)
       |                   |
   Chaos (R) ——————————— Smierc (B)
```

Sasiedzi = **sojusznicy** (2-kolorowe decki graja gladko), naprzeciw = **wrogowie** (splash trudniejszy,
mocniejszy payoff). Glowne osie starcia: **Zycie ↔ Smierc**, **Umysl ↔ Chaos**. To MTG-owe napiecie w
budowaniu decka na pokerowym silniku, gdzie **flush = zaangazowanie w barwe**.

## Keywordy per Aspekt (DRAFT startowy — do iteracji)

Kazdy Aspekt zahacza o silnik INNA dzwignia (Chips / Mult / HP / blok). Zestaw wyjsciowy, nie finalny.

| Aspekt | Sygnaturowe keywordy | Dzwignia silnika |
|---|---|---|
| **Porzadek/Zycie** (W) | Oslona (dodaj blok) · Opatrznosc (lecz HP) · Zastep (+wartosc za kazda karte Zycia w zagraniu) | blok + HP + nagroda za mono-kolor |
| **Umysl** (U) | Wrozba (podejrzyj/uporzadkuj nastepne karty) · Dobor (dobierz/powieksz reke) · Echo (+Chips za kazde zagranie w walce) | Chips + kontrola informacji + skalowanie |
| **Smierc** (B) | Gnicie (wrog traci HP co ture) · Ofiara (zniszcz wlasna karte -> zysk) · Zniwo (+Mult za karte w grobie) | DoT + Mult-za-poswiecenie |
| **Chaos/Wola** (R) | Spalenie (natychmiastowe dmg poza scoringiem) · Furia (×Mult gdy grasz bez bloku) · Hazard (podbij Mult pod warunkiem) | ×Mult + burst + ryzyko |
| **Natura/Wzrost** (G) | Wzrost (karta rosnie co ture) · Bujnosc (bonus przy >=N kart jednej barwy) · Symbioza (bonus za kolory-sojusznikow) | ramp + wielkie payoffy w czasie |

Interakcje pentagramu: **sojusznicy** dostaja keywordy-mostki (Symbioza nagradza dolozenie sasiada);
**wrogowie** sie gryza (Furia Chaosu karze blok — serce Zycia); **reguly pola bossow** moga tlumic wybrany
kolor. Wszystko deterministyczne — nawet Hazard ma warunek, nie rzut koscia.

## Talia i scoring (instalment 1)

**Talia = Male Arkana, 5 kolorow (Aspekty).** Rangi jak w tarocie: **As, 2-10, + 4 dwory: Paz, Rycerz,
Krolowa, Krol** = 14 rang × 5 kolorow = **70 kart w puli**. Twoj deck to KUROWANY podzbior (start ~18
kart, zwykle skrecony w 1-2 Aspekty; rosnie przez draft do ~25-30). Tarot daje o jeden dwor wiecej niz
poker (Rycerz).

Chipsy z karty (material):

| Karta | Chipsy |
|---|---|
| 2-10 | nominal (2...10) |
| As | 11 |
| Paz / Rycerz / Krolowa / Krol | 10 kazdy |

Dwory daja plaskie 10 chipsow, ale ROZNIA sie ranga dla streetow I niosa wrodzone keywordy zalezne od
Aspektu (Krol Smierci != Krol Zycia) — tam siedzi tozsamosc koloru w samej karcie. Ranga dla streetow:
As (1 lub high), 2..10, Paz (11), Rycerz (12), Krolowa (13), Krol (14).

Bazowy scoring ukladow (Chips × Mult, kalibracja Balatro — do strojenia):

| Uklad | Chips | Mult |
|---|---|---|
| Wysoka karta | 5 | 1 |
| Para | 10 | 2 |
| Dwie pary | 20 | 2 |
| Trojka | 30 | 3 |
| Street | 30 | 4 |
| Kolor (flush) | 35 | 4 |
| Full | 40 | 4 |
| Kareta | 60 | 7 |
| Poker (str. flush) | 100 | 8 |
| Piec jednakowych | 120 | 12 |

Sekretne uklady (Piec jednakowych, Flush house, Flush five) wchodza przy duplikatach/enchantach.
**5 kolorow => flush RZADSZY** niz w 4-kolorowym pokerze => naturalnie nagradza mono-kolor (MTG color pie).
Poziomowanie ukladow (czy Arkana podnosza baze danego ukladu jak Planety w Balatro) — do rozstrzygniecia.

## Rdzen walki — przyklad

Karta = ranga + Aspekt + keyword. Przyklad tury, zagrywasz Pare z dwoch `7` w kolorze **Smierci**:

```
Para (bazowo)..............  10 chips × 2 mult
+ dwie 7-ki (Smierc).......  +14 chips        -> 24 chips
+ keyword "Ostrze".........  +15 chips        -> 39 chips
+ Arkanum "Smierc" (×2 mult gdy grasz kolor Smierci): mult 2 -> 4
------------------------------------------------------------------
WYNIK = 39 × 4 = 156 obrazen
+ keyword "Gnicie" -> wrog dostaje 2 Gnicia (traci HP co ture)
```

Podzial pracy: **combo** daje baze, **rangi kart** dokladaja chipsy, **keywordy kart** dokladaja chipsy
I efekty, **Wielkie Arkanum** mnozy. Wszystko policzalne z gory (deterministyczne).

Petla walki:

```
Kamera najezdza na pojedynek 1v1 w swiecie 3D
  WROG:  HP + jawna intencja (np. "uderzy za 18")   <- deterministyczne
  TY:    HP trwale przez caly run
Twoja tura -> skladasz 1 uklad -> Chips×Mult = obrazenia / blok, keywordy free
Tura wroga -> robi to, co zapowiedzial; blok pochlania, reszta w HP
... az wrog padnie (nagroda) albo Ty (koniec runu)
```

## Struktura runu

```
REGION 1 -> [walka][walka][BOSS: regula pola]
   |  wybor miedzy szczeblami: sklep / nagroda / skip-za-tag
REGION 2 -> [walka][walka][BOSS]
   ...
REGION N -> [FINALNY BOSS] -> wygrana (potem ew. endless / tiery trudnosci)
```

Losowosc siedzi w warstwie nagrod (sklep/drafty). Walki i reguly bossow sa deterministyczne/znane.

## Ekonomia (instalment 2)

Waluta = **Rtec** (alchemiczny Merkur, symbol **☿**) — NIE dolary. Klucz: run-definiujacy build (Wielkie
Arkana) jest DARMOWY z bossow, wiec ☿ nie kupuje reliktow — ☿ **stroi pokerowy deck** (blizej sklepu StS).

Zrodla ☿:
- **Nagroda za walke:** ~4 ☿ zwykla, ~6 ☿ boss (+ boss daje Arkanum).
- **Odsetki:** 1 ☿ za kazde 5 ☿ w banku, **cap 5 ☿** (przy 25 ☿). Silnik oszczedzaj-vs-wydawaj.
- **Oszczednosc:** 1 ☿ za kazdy niewykorzystany odrzut na koniec walki.
- **Sprzedaz:** odsprzedaj karte/enchant za drobne.

| Bank (☿) | Odsetki/ture sklepu |
|---|---|
| 0-4 | 0 |
| 5-9 | 1 |
| 10-14 | 2 |
| 15-19 | 3 |
| 20-24 | 4 |
| 25+ | 5 (cap) |

Sklep (miedzy szczeblami = warstwa LOSOWA/nagroda):

| Pozycja | Efekt | Cena start (do strojenia) |
|---|---|---|
| **Kup karte** | dodaj Male Arkanum do decka | ~4 ☿ |
| **Enchant** | edycja/pieczec: Foil (+chips), Holo (+mult), Polichrom (×mult), pieczec (retrigger...) | ~5 ☿ |
| **Usun karte** | thinning (kurowanie decka) | ~2 ☿, rosnie |
| **Wrozba** | jednorazowe (podejrzyj przyszlosc / przeksztalc karte) | ~3 ☿ |
| **Reroll** | odswiez oferte | 1 ☿, rosnie |

**Wielkie Arkana NIE w sklepie** (rzadkosc, z bossow). Podzial: ☿ = spojny przyrostowy tuning decka;
Arkana = wielkie skoki mocy z drogi. Napiecie: wydac teraz vs oszczedzac (odsetki) vs thinning. Losowosc
tylko w ofercie sklepu; walka deterministyczna. Vouchers (stale blogoslawienstwo na region) — zaparkowane.

## Otwarte (do domkniecia)

- **Wielkie Arkana — sub-decyzje** (rola JUZ ustalona: bossowie+relikty, Podroz Glupca): ile Arkanow na run vs 22 w puli (rozne runy = rozna droga); czy zawsze zabierasz pokonane Arkanum czy wybor 1-z-N; czy mozna ODRZUCIC pakt (Arkana dwustronne jak Diabel); **karty odwrocone (reversed)** jako lewar — Arkanum wprost = boon, odwrocone = mroczniejszy efekt / trudniejszy boss; Glupiec(0) i Swiat(21) jako specjalne.
- **Slownik keywordow per Aspekt:** archetypy z tabeli -> konkretne keywordy (odpowiedniki Taunt/Deathrattle/Battlecry + efekty barw), skladalne w edytorze.
- **Struktura talii:** 5 suitow × rangi (As–10 + figury: Paz/Rycerz/Krolowa/Krol?), rozmiar talii startowej, ktore uklady pokerowe liczymy.
- **HP / obrona:** model bloku, jak intencje raniA, leczenie miedzy walkami.
- **Warunek konca:** liczba regionow, finalny boss, tryb endless, tiery trudnosci (Ascension/Stakes).
- **Determinizm doboru w walce (PILNOWAC):** seed + widoczne nastepne karty ALBO brak ukrytego dobierania. Inaczej hybryda zsuwa sie w "pelne Balatro" i lamie sim-preview.
- **Pierwszy buildowalny wycinek (vertical slice):** jedna walka 1v1 z dzialajacym scoringiem Chips×Mult, jednym Arkanum i dwoma keywordami.
