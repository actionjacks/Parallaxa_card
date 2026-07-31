# AUDYT PETLI (etap N1) — 2026-07-31

Zrodla: panel 6 audytorow czytajacych kod + adwersarz weryfikujacy ich znaleziska + **macierz
empiryczna 8 przeklikow bota** (5 biomow przez `PT_BIOME`, 3 Zaslony przez `PT_VEIL`) +
50 asercji w `tests/`.

Zasada: kazde znalezisko sprawdzone w kodzie ZANIM cokolwiek ruszono. Dwa zgloszenia zostaly
**odrzucone** po weryfikacji i celowo NIE sa naprawiane (sekcja na koncu).

---

## 1. Wynik empiryczny — co dziala

| Run | Biom / Zaslona | Prawo | Koniec | Walk | Rtec na koniec |
|---|---|---|---|---|---|
| biome_0 | Sad Kielichow (LIFE) | 1 | **ZWYCIESTWO** | 6 | 64 |
| biome_1 | Biblioteka Mieczy (MIND) | 2 | porazka | 3 | 16 |
| biome_2 | Katakumby Pentakli (DEATH) | 3 | porazka | 4 | 13 |
| biome_3 | Pogorzelisko Bulaw (CHAOS) | 4 | porazka | 2 | 13 |
| biome_4 | Przerost (NATURE) | 5 | porazka | 3 | 15 |
| veil_3 | Zaslona III | — | **ZWYCIESTWO** | 6 | 59 |
| veil_4 | Zaslona IV | — | porazka | 3 | 44 |
| veil_5 | Zaslona V | — | porazka | 4 | 76 |

**CZYSTO:** wszystkie 5 biomow i wszystkie 3 Zaslony zmieniajace zasady sa OSIAGALNE, kazdy run
doszedl do prawdziwego zakonczenia — zero petli, zero ekranow bez wyjscia, zero martwych sciezek.
Wszystkie 6 praw pola maja teraz asercje (`tests/test_combat.gd`) i przechodza.

**ZNALEZISKA BALANSOWE (do decyzji czlowieka, nie bugi):**
- **Rozrzut trudnosci biomow jest 3x**: Sad (LIFE) konczy sie zwycięstwem po 6 walkach,
  Pogorzelisko (CHAOS) porazka po 2. LIFE daje blok i glebszy zapas leczenia, CHAOS ma intencje
  burstowe [20,0,14] — kolor decyduje o trudnosci runu bardziej niz cokolwiek innego.
- **Zaslona III okazala sie LATWIEJSZA od runu bazowego** (zwyciestwo, 6 walk). Tier trudnosci,
  ktory ulatwia gre, to blad projektowy — do przestrojenia.
- **Zaslona V konczy z 76 Rteci niewydanej** (najwiecej ze wszystkich runow): sklep nie nadaza
  wchlonac przychodu w runie na 5-6 starc.

---

## 2. NAPRAWIONE w tym etapie (9)

Wszystkie z tej samej rodziny co precedens, ktory uruchomil audyt: **obietnica bez pokrycia**.

| # | Plik | Na czym polegal |
|---|---|---|
| 1 | `run_state.gd` | `lost_aspect` ustawiany przez Zaslone V i **kasowany 17 linii nizej** przez blok resetu w tej samej `begin()`. Kolor usuniety przez Zaslone V byl zapisywany, wczytywany i zawsze rowny -1. |
| 2 | `run.gd` | Zaslona III obiecuje "sklep pokazuje DWIE karty". Pierwsze zatowarowanie honorowalo `SHOP_SLOTS()`, ale **reroll i fallback mialy na sztywno 3** — jedna Rtec cofala Zaslone. |
| 3 | `combat_controller.gd` | `growth` i `bloom` **nie byly zerowane nigdzie**. Rampy WZROST/KORZENIE sa z zalozenia per-walka, wiec karta czekajaca w rece w walce 1 niosla bonus do konca runu, kumulujac. (`scar` i `cracked` sa TRWALE i celowo nietkniete.) |
| 4 | `combat_controller.gd` + `combat.gd` | `predicted_taken()` pomijal **riposte Sprawiedliwosci, osad Sadu i danine Diabla** — wszystkie trzy uderzaja zaraz po zagraniu, ktore nie zabija. Kokpit obiecywal HP, ktorego gra nie zamierzala dotrzymac. Nowe `predicted_self_damage()`; przy zagraniu smiertelnym zwraca 0, bo zabojczy cios wygrywa pierwszy. |
| 5 | `combat.gd` | Zlota plakietka **Klucza malowana przy Zaslonie IV**, gdzie Klucz jest wylaczony. UI mowilo, ze karta liczy podwojnie, gdy nie liczyla. |
| 6 | `ui.csv` | `KWD_WROZBA` zawieral `%d`, ktorego nikt nie formatuje — gracz widzial na karcie **doslowne "%d"**. |
| 7 | `profile.gd` | `add_xp` zmienial xp/poziom/Sol i **nigdy nie zapisywal profilu**. Zamkniecie gry po wygranym pojedynku kasowalo wszystko, co ten pojedynek zaplacil. |
| 8 | `overlays.gd` | Przycisk "Zapisz i wyjdz do menu" **nie zapisywal niczego** — run jest zapisywany tylko na mapie, wiec wyjscie ze sklepu wyrzucalo run. |
| 9 | `run.gd` (sklep) | **Blad zlozenia dwoch poprawnych funkcji**, przeoczony przez wszystkich 6 audytorow: wyrzezbienie drugiego koloru daje aspekt SPRZYMIERZONY, ale pozniejsze odwrocenie karty zmienia jej aspekt na WROGI i nie rusza splasha — powstaje hybryda dwoch wrogich kolorow, czyli dokladnie to, czego `_splash_card` odmawia sprzedac. Jedna taka karta domyka Kolor w OBU. Teraz splash podaza za odwroceniem. |

---

## 3. ODRZUCONE po weryfikacji (NIE naprawiac)

- **"`_mount()` zostawia stary ekran klikalny przez 180 ms"** — nieprawda. Nowy ekran jest
  OSTATNIM dzieckiem, a `gui_find_control_at_pos` iteruje od konca i zwraca pierwszy trafiony
  Control; `MOUSE_FILTER_PASS` propaguje do RODZICA, nie do nizszego rodzenstwa.
- **"Migracja profilu v1->v2 kasuje dorobek"** — nieprawda. v1 trwale mial tylko `sol`,
  `unlocked` i `starter_editions`; pozostalych pol w v1 fizycznie nie bylo.

---

## 4. NAPRAWIONE w partii N1c (14)

Synteza audytu przeczytala repo PO pierwszej partii i znalazla, ze **dwie moje naprawy zepsuly
cos innego**. Te ida pierwsze — naprawa, ktora wprowadza blad, jest gorsza od bledu, ktory
zastapila.

**Moje regresje:**
- Zerowanie `growth`/`bloom` sprawilo, ze `KWD_WZROST` zaczal klamac (obiecywal narost na CALY
  run). Tekst przepisany na "do konca tego pojedynku".
- Zapis przy "Zapisz i wyjdz" otworzyl FARME: `step` rosl dopiero w `_leave_shop`, wiec dalo sie
  wygrac walke, zainkasowac nagrode/nadmiar/odsetki/XP, wyjsc z ekranu nagrody i wrocic na TEN
  SAM szczebel. Szczebel rosnie teraz w momencie wygranej, a ekran nagrody jest punktem zapisu.

**Ekonomia:** `_buy()` nie zdejmowal karty z lady (osiem kopii tego samego Krola za 40 Rteci);
"jedna Gwiazda na wizyte" bylo cofane przez reroll.

**Przymierze podgladu:** podglad nie ostrzegal przed OFIARA (niszczy karte trwale); zwrot odrzutu
za Pentagram lamal limit Wisielca; `next_intent()` klamal przy Kole (pokazywal 22, uderzal 9) i
Glupcu (czytal tabele, ktorej ten nie uzywa) — teraz zwraca -1 i HUD mowi, ze ciosu nie da sie
przepowiedziec; Arkanum Sadu opisywalo sie pustym stringiem; prawo biomu bylo liczone i NIGDY
niepokazane w walce.

**Struktura:** Swiat byl nieosiagalny od Glebi 1 (etap podrozy WNIOSKOWANY z `fights_won`);
Biom Zapieczetowany nie byl terminusem wbrew trzem wlasnym tekstom; pieczec z ostatniego szczebla
przyznawana w ciszy; mapa z omenem wypychala "Rusz" poza 720p — ekrany runu przewijaja sie, a
pasek akcji jest zakotwiczony do dolu.

---

## 5. POZOSTAJE

Potwierdzone, jeszcze nienaprawione — kolejnosc wg wagi:

1. **Swiat nieosiagalny na Glebi >= 1**: `_go_beyond` zeruje `region_index`, ale `fights_won > 0`
   sprawia, ze `_show_biome_choice` liczy `idx = 1` i wchodzi od razu w Swiat... a potem petla
   pomija go w kolejnych Glebiach. `boss_world` staje sie trescia nieosiagalna.
2. **Biom Zapieczetowany nie jest terminusem**, wbrew wlasnemu opisowi ("Podroz konczy sie tam").
3. **Pieczec zdobyta na Glebi przyznawana po cichu** — efekt policzony, nigdy niepokazany.
4. **Mapa z omenem przekracza 720p** i chowa przycisk "Rusz" — czwarty softlock tej rodziny.
5. **Osiagniecia przyznawane w ciszy** — `check_run_achievements` zwraca liste swiezo zdobytych,
   a wynik jest wyrzucany; gracz nie widzi popu.
6. **`_show_map` dereferencuje `RunState.region` bez straznika**, choc reszta kodu zaklada, ze
   moze byc null.
7. **`describe()` nie ma galezi dla `RAISE_DEAD`** — Arkanum Sadu ma pusty opis.
8. **Podglad ostrzega przed rozpadem szkla, ale nie przed OFIARA**, ktora niszczy karte trwale.
9. **Zwrot odrzutu za Pentagram lamie limit Wisielca** (`HANGED_CAP`).
10. **`next_intent()` klamie przy Kole i Glupcu** (Kolo przeskakuje cykl o 2, Glupiec nie uzywa
    tabeli intencji).
11. **`_mult_breakdown` pomija co najmniej piec zrodel mnoznika** (m.in. `inverted`, prawa biomow).
12. **Prawo pola nie jest pokazane W WALCE** — gracz zapomina, w czym walczy.

---

### Znane, jeszcze nietkniete
- **RAISE_DEAD jest funkcjonalnie no-opem**: silnik i tak recyklinguje grob bezwarunkowo, wiec
  Arkanum Sadu nie daje nic poza wpisem w logu. Wymaga decyzji projektowej (albo silnik przestaje
  recyklowac automatycznie, albo Sad robi cos innego).
- `lost_aspect` jest juz poprawny, ale nikt go nie POKAZUJE — Zaslona V nie mowi, ktory kolor znikl.
- `KEYSTONE_TAG` istnieje w ui.csv i nie jest nigdzie uzyty: mechanika Klucza nie jest w grze
  wyjasniona ani razu.
- `_mult_breakdown` pomija co najmniej piec zrodel mnoznika.
- Blok omenu nachodzi wizualnie na zakotwiczony pasek akcji (kosmetyczne — przyciski dzialaja).

## 6. Co dalej

Etap N1c: naprawy z sekcji 4 (1-6 to blokujace). Potem N3 (zrozumialosc) — audyt zrozumialosci
potwierdzil diagnoze liczbami: 20 tooltipow w calym `src/game/` i brak definicji dla
najbardziej podstawowych pojec gry.
