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

### M1 — „Pelna Podroz" (NAJWIEKSZY skok: z demo w GRE)
Run przez 3 regiony az do finalu. To zamienia 5-minutowy slice w ~20-30 min run z prawdziwym lukiem.
- Region II „Zgliszcza" i Region III „Szczyt": nowi wrogowie (skalowani), nowe reguly pol.
- Bossowie z gotowych artow: **Diabel (XV)** — pakt: co ture zabiera karte z reki?; **Ksiezyc (XVIII)**
  — cienie: co cykl przywoluje pomniejszona kopie; final **SWIAT (XXI)** — laczy reguly poprzednich.
- Ciaglosc miedzy regionami: HP/talia/relikty/☿ ida dalej; miedzy regionami PELNY rest + druzgocacy
  wybor (ulepszenie vs leczenie).
- Kolekcja Arkanow rosnie W TRAKCIE runu (po kazdym bossie nosisz jego moc) — druzyna reliktow 3+.
- Warunek wygranej: Swiat pokonany = RUN WYGRANY (ekran zwyciestwa z pelnym rozkladem kart runu).

### M2 — „Silnik wzrostu" (moc musi rosnac szybciej niz proga)
- **Poziomowanie ukladow**: konsumowalne „Gwiazdy" (odpowiednik Planet; tarotowo: Gwiazda XVII juz jest
  omenem — uzyc motywu konstelacji) podnoszace baze Chips/Mult konkretnego ukladu; w sklepie i nagrodach.
- **Odsetki ☿** (1/5, cap 5) + **1 ☿ za niewykorzystany odrzut** — dwie brakujace nogi ekonomii z designu.
- Druga fala keywordow (min. Wzrost, Symbioza, Pijawka, Klatwa) — pary tworzace nowe archetypy.
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
