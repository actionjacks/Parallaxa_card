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
8. **Build = keywordy kart + jokery/Arkana** — talia ROSNIE przez draft (nagrody); pasywne modyfikatory to warstwa Wielkich Arkanow (rola dokladna — patrz Otwarte).
9. **Meta = liniowa drabinka regionow** — kazdy region konczy boss ze znana "regula pola"; miedzy szczeblami wybory (sklep / nagroda / skip-za-tag).

## Motyw i kolory: Tarot + 5 Aspektow

Talia = tarot. **Male Arkana** to nasza talia-paliwo w **5 kolorach** (custom 5-suitowa talia; kazdy suit
= jeden Aspekt). **Wielkie Arkana** (22 trumfy: Smierc, Wieza, Kolo Fortuny, Glupiec...) to warstwa
Fatum/Ducha ponad kolorami, dostepna wszystkim.

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

## Otwarte (do domkniecia)

- **Rola Wielkich Arkanow (22):** jokery/relikty (build) vs konsumowalne (model Balatro) vs bossowie/Fatum vs mix. Kierunek: **Arkana jako jokery + bossowie tematyzowani jako Arkana** (ta sama ikonografia pracuje dwa razy) — do potwierdzenia.
- **Slownik keywordow per Aspekt:** archetypy z tabeli -> konkretne keywordy (odpowiedniki Taunt/Deathrattle/Battlecry + efekty barw), skladalne w edytorze.
- **Struktura talii:** 5 suitow × rangi (As–10 + figury: Paz/Rycerz/Krolowa/Krol?), rozmiar talii startowej, ktore uklady pokerowe liczymy.
- **Ekonomia:** kasa, odsetki (Balatro), ceny, zawartosc sklepu; krzywa wydac-vs-oszczedzac.
- **HP / obrona:** model bloku, jak intencje raniA, leczenie miedzy walkami.
- **Warunek konca:** liczba regionow, finalny boss, tryb endless, tiery trudnosci (Ascension/Stakes).
- **Determinizm doboru w walce (PILNOWAC):** seed + widoczne nastepne karty ALBO brak ukrytego dobierania. Inaczej hybryda zsuwa sie w "pelne Balatro" i lamie sim-preview.
- **Pierwszy buildowalny wycinek (vertical slice):** jedna walka 1v1 z dzialajacym scoringiem Chips×Mult, jednym Arkanum i dwoma keywordami.
