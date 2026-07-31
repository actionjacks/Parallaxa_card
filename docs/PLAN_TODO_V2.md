# PLAN WDROZENIA — domkniecie todo.md w calosci (2026-07-31)

Podstawa: `docs/AUDYT_TODO.md` — 27 obietnic, z czego 7 zrobionych, 10 czesciowo, 10 brak.
Ten plan zamyka WSZYSTKIE 20 luk. Kolejnosc jest wymuszona przez ryzyko: najpierw rzeczy
ZEPSUTE (gracz za nie placi i nic nie dostaje), potem obietnice przyciete do polowy, na koncu
mechaniki, ktorych nie ma wcale.

## Zasady, ktore obowiazuja na kazdym kroku

1. **Walka zostaje 100% deterministyczna. Podglad NIGDY nie klamie.** Kazda nowa mechanika musi
   przechodzic przez lejek, ktory podglad juz czyta: `Scoring.score()`, `effective_damage()`,
   `_intent_at()`, `predicted_taken()`, `predicted_self_damage()`. **Technika, ktorej kokpit nie
   umie wycenic, NIE WCHODZI.**
2. **Enumy APPEND-ONLY** (`.tres` trzymaja inty). Nowe wartosci wylacznie na koncu.
3. **Kontrakt seeda**: `pick_offers` / `pick_tiered_offers` / `shuffle_for_fight` konsumuja
   DOKLADNIE jedno losowanie glownego rng. Filtrowanie puli PRZED losowaniem jest bezpieczne
   (sub-generator), dopisywanie nowych konsumentow rng — tylko ZA istniejacymi.
4. **Teksty gracza tylko przez `data/locale/ui.csv`** (en+pl, parzystosc `%d`/`%s`).
5. **Przyciski akcji bottom-anchored** — cztery softlocki w historii projektu.
6. Po kazdej fazie: import, obie suity, przeklik botem na ukrytym ekranie, commit.

---

## FAZA 1 — DWANASCIE BLEDOW (rzeczy zepsute)

| # | Blad | Naprawa |
|---|---|---|
| B1 | Zwrot odrzutu za Pentagram kasowany przez reset tury | bank `_banked_discards`, doliczany PO resecie |
| B2 | Pentagram nie ma "gigantycznego efektu" | Pentagram **przelamuje pancerz**: omija STRENGTH_RESIST i BARK_HIDE przez `effective_damage()` |
| B3 | `RAISE_DEAD` to no-op | wskrzeszone karty wracaja **silniejsze** (`growth += RAISE_CHIPS`), czego zwykly recykling nie robi |
| B4 | Pelny Dwor z 4 kart punktuje jako wysoka karta | `evaluate()` sprawdza uklady sekretne takze przy 4 kartach |
| B5 | `_invert_card` bez strazy — placisz 6 drugi raz za nic | `if card.inverted: return` |
| B6 | `splash` ginie przy `duplicate()` | `splash`, `scar`, `cracked` jako `@export` |
| B7 | Blizna trafia w karte kasowana w tej samej klatce | bierz ostatnia karte zabojczego zagrania, ktorej NIE MA w `destroyed_cards` |
| B8 | `lost_aspect` Zaslony V nie filtruje puli nagrod ani sklepu | `RunState.filter_lost()` na kazdej ofercie |
| B9 | Zaslona IV nie podnosi ceny przelosowania | `_cost(_shop_reroll_cost)` |
| B10 | OFIARA obchodzi `banned_aspect` | zjedzone chipsy = 0, gdy kolor ofiary jest zakazany |
| B11 | Linia coachingu FIRST_KEYSTONE to martwy kod | przeniesiona do sciezki klikniecia karty |
| B12 | `LEVEL_UP[FULL_COURT]` martwy | FULL_COURT i PENTAGRAM dopisane do `STAR_HANDS` |

## FAZA 2 — OBIETNICE PRZYCIETE DO POLOWY

**P1. OFIARA pozera Chipsy I Mult, NA CALA RESZTE WALKI.**
Dzis absorpcja jest jednorazowa i tylko chipsowa. Nowe pole `feast` (per-walka, jak `growth`):
karta Ofiary zatrzymuje chipsy zjedzonego sasiada na stale w tej walce (`growth += devoured_chips`)
i zyskuje `+1.0 Mult` za kazda pozarta karte. Oba pola czyta `chip_value()`/`Scoring`, wiec kokpit
wycenia je bez nowego wywolania.

**P2. Kolejnosc jest OSIA DECYZJI, nie tylko pierwszym i ostatnim miejscem.**
Pasek PORZADEK pod kokpitem: zestawione karty w kolejnosci zagrania, kazda przestawialna
strzalkami. Dzis kolejnosc komunikuje sama cyfra na plakietce, czesto sprzeczna z geometria reki.

**P3. Inwersja: mocniejsza, z WYBOREM koloru i sciezka Arkanum.**
`x1.45` zostaje (pomiar: piec kart to juz x6.4), ale dochodzi **+20 chipsow** na kazdej odwroconej
karcie — pojedyncza karta staje sie odczuwalna, a piec nie eksploduje. Gracz **wybiera**, ktory z
dwoch wrogich kolorow dostanie (dzis `foes[0]` na sztywno, przez co przyklad z todo.md „Chaos w
Umysl" byl nieosiagalny).

**P4. Spaczone budowanie talii — masowa inwersja.**
Nowa akcja sklepu SPACZ (18 Rteci): odwraca w talii KAZDA karte wybranego koloru naraz. To jest
„odwroc polowe talii" z todo.md; po jednej karcie za 6 bylo to nieosiagalne ekonomicznie
(96-120 Rteci przy ~54 nagrod).

**P5. Uklady sekretne sa NAPRAWDE sekretne.**
`Profile.discovered_hands` (zapisywane). Pentagram i Pelny Dwor stoja w tabeli wyplat jako `???`
do pierwszego zagrania; podpowiedz „najlepszy dostepny uklad" tez ich nie nazywa przed odkryciem.

**P6. Splash z wyborem koloru** — ten sam wybor co przy inwersji, z dwoch sojusznikow. Dzis
`pals[0]` na sztywno, przez co przyklad z todo.md („Zycie + Natura") byl nieosiagalny.

**P7. Wieza NAPRAWDE niszczy karty, a spekana jest ta ODZYSKANA.**
Dzis regula Wiezy tylko ignoruje blok, a spekana zostaje przypadkowa obca karta. Nowe: Wieza
rozbija jedna karte z reki na kazdej swojej turze — a jesli mimo to wygrasz, **wlasnie te karty
dostajesz z powrotem, spekane**. Strata i nagroda to ten sam przedmiot, jak chce todo.md.

**P8. Zaslona V naprawde usuwa kolor** — to samo co B8.

**P9. Ksiega Astrologa: zestaw Arkanow, wynik i jedno podejscie.**
Dzienny Los narzuca **predefiniowany zestaw trzech Wielkich Arkanow** (z pelnej listy, nie z puli
biomu), share-string niesie WYNIK obok kodu losu, a rekord zapisuje **pierwsze** podejscie —
nieograniczone powtorki niszczyly porownywalnosc.

**P10. Wtajemniczenia zmieniaja EKONOMIE i ZASADY, nie liczby.**
Oba przyklady wypisane wprost w todo.md, oba dzis nieistniejace:
- Zaslona IV+: **odsetki licza sie tylko od kart w kolorach wrogich** wobec twojego dominujacego
  Aspektu — ekonomia zaczyna zalezec od tego, jak zbudowales talie.
- Zaslona V: **kazdy boss czyta tabele wyplat do gory nogami** (`INVERTED_TABLE` przestaje byc
  prywatna regula Ksiezyca). Infrastruktura (`ctx` + `Poker.mirrored`) juz istnieje i lezy nieuzyta.

## FAZA 3 — CZEGO NIE MA WCALE

**S1. ROZKLAD TRZECH KART — nowy boss: Pustelnik (Arkanum IX).**
Regula `THREE_SPREAD`. Tura cyklicznie wchodzi w slot: PRZESZLOSC -> TERAZNIEJSZOSC -> PRZYSZLOSC.
- **PRZESZLOSC**: zagranie nie zadaje obrazen — jego Mult staje sie **trwalym bonusem** do konca walki.
- **TERAZNIEJSZOSC**: obrazenia natychmiast, jak zwykle.
- **PRZYSZLOSC**: obrazenia **odlozone o 2 tury**, wypisane w kokpicie od momentu zagrania.

Dlaczego to nie lamie przymierza: talia jest deterministyczna, wiec przyszlosc JEST znana. Kokpit
pokazuje slot i kwote odlozona, zanim gracz kliknie. To najmocniejszy dowod tezy „karty nie klamia"
w calej grze — i dokladnie dlatego `docs/PLAN_TODO.md` odkladal to jako „drugi tryb gry".

**S2. KRZYZ CELTYCKI — nowy boss: Umiarkowanie (Arkanum XIV).**
Regula `CELTIC_CROSS`. Cztery dodatkowe sloty OBOK reki: przycisk ZAMROZ parkuje zaznaczone karty
poza reka (nie licza sie do jej rozmiaru, wiec dobierasz swieze), a klikniecie zamrozonej karty
sciaga ja z powrotem. Tak buduje sie gigantyczne combo na ture, w ktorej wrog telegrafuje
najmocniejszy cios — czyli dokladnie to, co obiecuje todo.md.

**S3. Wskrzeszenie w POTEZNIEJSZEJ formie** — patrz B3 (ten sam kod domyka zakonczenie todo.md).

---

## Kolejnosc wykonania

```
FAZA 1 (12 bledow)  ->  import + suity + bot + commit
FAZA 2 (10 obietnic) ->  import + suity + bot + commit
FAZA 3 (2 nowe reguly + 2 bossy + figury) -> import + suity + bot + zrzuty + commit
```

Po kazdej fazie asercje w `tests/test_combat.gd` i `tests/test_scoring.gd`, w tym **negatywne**
(np. Pentagram NIE przelamuje pancerza, gdy boss go nie ma; PRZESZLOSC NIE zadaje obrazen).
