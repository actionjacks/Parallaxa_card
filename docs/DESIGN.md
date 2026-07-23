# Parallaxa_card — Projekt gry (design)

Status: **faza design, jeszcze bez kodu.** Dokument zywy — aktualizuj przy kazdej decyzji.
Jezyk kodu i tak zostaje angielski (patrz `CLAUDE.md`); ten plik jest notatka projektowa po polsku.

## Wizja

Roguelike-deckbuilder w duchu **Balatro / Slay the Spire**: uzalezniajaca wspinaczka po drabince
bossow + kupowanie i ulepszanie decka, zeby wygrac. Walka jako **pojedynek w swiecie 3D ze zblizeniem
kamery**. Determinizm walki (SimPodglad nie moze klamac) + zmienne nagrody miedzy walkami.

## Referencje — co bierzemy, co odrzucamy

| Gra | Co bierzemy |
|---|---|
| Balatro | silnik **Chips × Mult**, drabinka ante/blindow, ekonomia + odsetki, number-go-up |
| Slay the Spire | wrog z **HP + telegrafowane intencje**, relikty (= jokery), draft rosnacej talii, meta-struktura |
| Marvel Snap | modyfikatory pola (-> "reguly pola" bossow), krotki eskalujacy budzet tur, push-your-luck |
| Hearthstone | **jezyk slow kluczowych** (system efektow, editor-first), Discover (mini-draft), Battlegrounds jako roguelike-loop |

Odrzucamy z gier PvP: kolekcja / ladder / gacha, bluff-vs-czlowiek, RNG-fest.

## Decyzje (ustalone)

1. **RNG = hybryda** — walka DETERMINISTYCZNA (pelna informacja, sim-preview), nagrody ZMIENNE (sklep/drafty/oferty losowe).
2. **Ksztalt walki = pojedynek-silnik** — 1v1 w 3D, nie plansza/lanes; kamera najezdza na pojedynek.
3. **Model karty = wartosc + kolor-zywiol + keyword** — karta scoruje I odpala efekt (Hearthstone-style).
4. **Combo = uklady pokerowe** — para/kolor/street...; kolory to ZYWIOLY (ogien/woda/...); reakcje zywiolowe siedza w keywordach.
5. **Zasob tury = jedno zagranie + odrzuty** — 1 uklad scoringowy/ture (do 5 kart), keywordy zagranych kart odpalaja sie free, limit odrzutow na podmiane reki; tury naprzemienne z wrogiem.
6. **Build = keywordy kart + jokery** — talia ROSNIE przez draft (nagrody); jokery to pasywne modyfikatory (relikty Balatro/StS).
7. **Meta = liniowa drabinka regionow** — kazdy region konczy boss ze znana "regula pola"; miedzy szczeblami wybory (sklep / nagroda / skip-za-tag).

## Rdzen walki — przyklad

Karta = wartosc + kolor(zywiol) + keyword. Przyklad tury, zagrywasz Pare z dwoch `7 ♦`:

```
Para (bazowo)........  10 chips × 2 mult
+ dwie 7-ki..........  +14 chips        -> 24 chips
+ keyword "Ostrze"...  +15 chips        -> 39 chips
+ joker "Zar" (♦)....  mult 2 -> 4
--------------------------------------------------
WYNIK = 39 × 4 = 156 obrazen
+ keyword "Podpal" -> wrog dostaje 2 Palenia (traci HP co ture)
```

Podzial pracy: **combo** daje baze, **wartosci kart** dokladaja chipsy, **keywordy kart** dokladaja
chipsy I efekty, **joker** mnozy. Wszystko policzalne z gory (deterministyczne).

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

## Otwarte (do domkniecia)

- **Ekonomia:** kasa, odsetki (Balatro), ceny, zawartosc sklepu; krzywa wydac-vs-oszczedzac.
- **Roster zywiolow:** ile kolorow-zywiolow, jakie reakcje miedzy nimi, macierz keywordow.
- **HP / obrona:** dokladny model bloku, jak intencje ranią, leczenie miedzy walkami.
- **Slownik keywordow:** startowy zestaw (odpowiedniki Taunt/Deathrattle/Battlecry + reakcje zywiolowe), skladalny w edytorze.
- **Warunek konca:** liczba regionow, finalny boss, tryb endless, tiery trudnosci (Ascension/Stakes).
- **Determinizm doboru w walce (PILNOWAC):** seed + widoczne nastepne karty ALBO brak ukrytego dobierania. Inaczej hybryda zsuwa sie w "pelne Balatro" i lamie sim-preview.
- **Pierwszy buildowalny wycinek (vertical slice):** jedna walka 1v1 z dzialajacym scoringiem Chips×Mult, jednym jokerem i dwoma keywordami.
