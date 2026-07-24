# Playtest feedback — Region I (perspektywa gracza)

Metoda: pelny przeklik runu REALNYM inputem (mysz: motion + klik przez `Input.parse_input_event`)
narzedziem `tools/dev/capture_playthrough.gd`, zrzut kazdego etapu (screenshots/pt2_*.png), ocena
kazdego ekranu tak, jak widzi go gracz. Locale = PL.

## Co dziala dobrze (ZOSTAWIC)

- **Feedback w walce jest czytelny**: zagrane karty WYLATUJA do wroga, dobrane wlatuja, popupy obrazen/
  bloku/leczenia, tween HP, wind-up wroga, „death beat". Widac przyczyne-skutek W walce.
- **Duzy podglad karty na hover** (rank + aspekt + keyword + PELNY opis) — bardzo dobre, gracz czyta co robi karta.
- **Hover kart** juz nie miga (fix z_index).
- **Lokalizacja PL** wszedzie (poza jednym bugiem, nizej — naprawiony).
- **Sklep** czytelny i kompletny (kup/ulepsz/losuj/usun/dalej), ceny w Rtec.
- **Regula bossa** wypisana wprost („Wieza: blok nie chroni").
- **Podglad wyniku** „Kolor 72 x 5.6 = 403" — jasny.
- **Ekonomia** ciasna i znaczaca (11 Rtec = jedna decyzja).

## KRYTYCZNE — to sprawia, ze gra „wyglada na niedokonczona"

1. **Walka to w ~60% czarna pustka.** Wrog = cienki pasek HP na gorze, karty na dole, a CALY srodek ekranu
   to czern. Brak wizualizacji wroga, brak areny, brak tla. Projekt mowil „walka w swiecie 3D ze zblizeniem
   kamery" — tego NIE MA; to plaskie karciane UI zawieszone w pustce. To jest powod #1, dla ktorego „nie czuc gry".
   -> Wypelnic arene: **wizualny wrog** (portret/sylwetka/sprite/sigil) na srodku; **tlo pola walki**; scisnac
   elementy blizej, zeby ekran nie byl pusty.
2. **Kazdy ekran jest goly** (mapa, sklep, walka, final) — wszystko plywa w czerni. Zero klimatu, zero
   tozsamosci biomu („Popiol" nigdzie nie widac). Wyglada jak wireframe, nie gra.
   -> Tlo/atmosfera per ekran; choc placeholder art / gradient / winieta w klimacie popiolu.
3. **Wrog nie ma tozsamosci wizualnej** — tylko nazwa („Gnijacy Kultysta", „Wieza"). Gracz nie odroznia
   wrogow wzrokowo, nie czuje zagrozenia. -> Nawet placeholder (sylwetka + kolor) zmieni odbior.

## WAZNE — czytelnosc i zrozumienie („co z czego wynika")

4. **Rozbicie mnoznika ukryte.** Gracz widzi „72 x 5.6" ale nie WIE skad 5.6 (baza Kolor 4 x Arkanum 1.4).
   Balatro pokazuje budowanie wyniku. -> Pokazac rozbicie (baza ukladu -> +chips z kart -> x relikty)
   albo animacje naliczania. To uczy silnika.
5. **Relikt latwo przeoczyc** — w walce malutkie „* Arkanum Smierci" w rogu; na mapie chip bez etykiety.
   Gracz moze nie wiedziec, ze ma aktywny relikt i co on robi. -> Wyrazniejszy panel reliktow + podglad efektu.
6. **Edycje w sklepie (Foil/Holo/Polichrom) bez opisu.** Nowy gracz nie wie, co daja. -> Tooltip na przyciskach
   (Foil +chips / Holo +mult / Polichrom xmult).
7. **Wezly mapy puste** — „Walka 1/2/BOSS" bez informacji jaki wrog / jaka nagroda czeka. -> Podglad wezla.
8. **Talia jest mono-Smierc** -> kazda reka to flush Smierci -> powtarzalnosc, brak realnej decyzji „jaki
   uklad zagrac". -> Wiecej roznorodnosci w talii startowej / stonowac dominacje flusha (balans).

## DROBNE

9. Prefiks „>" na aktualnym wezle mapy — zbedny obok zoltej ramki.
10. Brak podsumowania runu na koncu (tury, zadane obrazenia).
11. Tagi keyword/edycja na twarzy karty male (lagodzone przez duzy podglad).
12. Pusty srodek walki moglby pokazywac **stosy talii/grobu** wizualnie (dobieranie z widocznego stosu).

## Naprawione w ramach tego playtestu

- **BUG lokalizacji**: `COMBAT_SELECT_HINT` mial nieopakowany przecinek w kolumnie EN
  („Select cards, then Play"), przez co PL pokazywalo smiec „then Play". Opakowano w cudzyslow.
  (Klasyczna pulapka CSV z CLAUDE.md — wykryta dopiero patrzac na ekran w locale PL.)

## PASS 2 — satysfakcja / regrywalnosc / wciagniecie (playtest realnym inputem, 2+ runy)

Kryteria: gra ma byc satysfakcjonujaca, REGRYWALNA i wciagajaca. Ustalenia i wdrozone naprawy:

1. **KRYTYCZNE / REGRYWALNOSC: gra byla w 100% deterministycznym skryptem.** Zero RNG w calym kodzie:
   oferty nagrod = staly offset (step*3), sklep = staly offset 5, talia w stalej kolejnosci .tres.
   Kazdy run identyczny -> zerowa regrywalnosc. To LAMALO decyzje projektowa „hybryda: walka
   deterministyczna, nagrody ZMIENNE". **NAPRAWIONE**: RunState.rng (seed per run) = jedyne
   usankcjonowane zrodlo losowosci; losowe 3 oferty nagrody, losowe oferty sklepu, reroll = prawdziwe
   losowanie, talia tasowana RAZ na starcie runu (w runie dobor pozostaje deterministyczny, sim-preview
   nie klamie). Dowod: 3 runy — rozne talie startowe, rozne oferty, rozne przebiegi (hp 27/27/43).
2. **KRYTYCZNE / SATYSFAKCJA: gra byla CALKOWICIE niema.** AudioManager istnial, nikt go nie wolal.
   **NAPRAWIONE**: proceduralne SFX (src/game/audio/sfx.gd — WAV syntezowany w kodzie, zero plikow):
   select/deselect karty, zagranie, trafienie (glosniejsze i nizsze przy wiekszych obrazeniach), blok,
   lecz, Gnicie, moneta (kupno/nagroda), cios w gracza, ZABLOKOWANO, fanfara wygranej / zjazd porazki.
3. **WCIAGNIECIE: brak eskalacji napiecia w walce.** Intencje wroga staly w miejscu — dlugie walki nie
   grozily niczym. **NAPRAWIONE**: enrage (EnemyData.enrage_step) — po kazdym pelnym cyklu intencji
   baza rosnie (+2 zwykli, +3 boss). Deterministyczne, zawsze widoczne w „Uderzy za N" (uczciwe).
   Przeciaganie walki = kara; szybkie zabicie = nagroda. Boss 470 HP (po dywersyfikacji talii).
4. **SATYSFAKCJA: kazde trafienie wygladalo tak samo.** 400-dmg flush = ten sam popup co 29-dmg para.
   **NAPRAWIONE**: rozmiar liczby obrazen skaluje z wartoscia, trafienia >=150 wstrzasaja arena
   (screen shake), dzwiek trafienia ciezszy przy duzych hitach.
5. **Bot testowy gral bez odrzutow** (nie jak gracz) — po dywersyfikacji talii nie domykal bossa.
   Poprawiony: fishuje odrzutami przy slabej rece (jak realny gracz). 3/3 runy wygrane z marginesem
   27-43 HP — napiecie jest, sciana nie.

Pozostaje do przyszlego strojenia: wiecej wrogow/pul nagrod (wieksza przestrzen wariancji), muzyka,
dzwieki na hover/przyciskach, ascension/stakes po pierwszym zwyciestwie.

## Rekomendowana kolejnosc

1. **Wizualny wrog + tlo pola walki** (KRYT #1/#3) — najwiekszy skok „to gra, nie wireframe".
2. **Tla/atmosfera pozostalych ekranow** (KRYT #2).
3. **Rozbicie mnoznika + wyrazniejsze relikty** (WAZNE #4/#5) — zrozumienie silnika.
4. **Podglady wezlow mapy + tooltipy edycji** (WAZNE #6/#7).
5. **Roznorodnosc talii / balans flusha** (WAZNE #8).
6. Drobnica.
