# PLAN WDROZENIA docs/todo.md — rozwiniecie gry

Dokument todo.md opisuje szesc warstw glebi, ktore maja zamienic Parallaxa_card w gre "od ktorej
nie mozna sie oderwac". Ten plik jest ich planem wdrozenia: co, w jakiej kolejnosci, jakim kosztem,
i co koliduje z przymierzem determinizmu ("karty nie klamia").

Zrodla: docs/todo.md (pomysly), panel projektowy 8 agentow (workflow `parallaxa-feel-overhaul`,
specs w docs/specs/), oraz **pomiary na zywym silniku** — `tools/dev/probe_deckmath.gd`, ktory
liczy prawdziwym `Poker.evaluate` + `Scoring.score`, a nie modelem.

---

## 0. Co juz zostalo zrobione (fundament, na ktorym stoi cala reszta)

Zanim cokolwiek z todo.md wejdzie, musialy zostac naprawione rzeczy, przez ktore gra "nie dawala
radosci". To jest zrobione i zmierzone:

| Etap | Co | Dowod |
|---|---|---|
| F1 | Talia pentaklowa 40 kart (5 aspektow x rangi 1-8) | kareta 0.00% -> 4.9%, sufit obrazen 474 -> 1928 |
| F1 | Korekta wyplaty KOLORU (70x8, powyzej karety) | kolor to 3. najrzadszy uklad (1 na 2531), placil jak 6. |
| F1 | Tasowanie talii przed kazda walka | wczesniej KAZDA walka runu zaczynala sie ta sama reka |
| F2 | Ceremonia naliczania karta-po-karcie | zagranie przestalo byc jednym cichym tickiem |
| F2 | Sortowanie reki (rangi / kolory) + podpowiedz "W rece: X" | **strit lezy w rece w 22.6% rak, gracz znajdowal go w 0.5%** |
| F3 | Karty 108x151, pasek koloru, sigile 5 aspektow, piaty kolor (Natura) | zrzuty w screenshots/ |
| F4 | Animowany portret wroga jako warstwa tla (372x644) | oddech, zamach, drgniecie, szal, smierc |
| F5 | 5 biomow = 5 kolorow = 5 praw pola, pieczecie, Biom Zapieczetowany | ekran wyboru drogi, `Profile.seals` |

**Najwazniejsza liczba dla dalszych prac:** gracz grupujacy karty po randze (naturalna heurystyka
oka) widzi 64.5% tur jako pare/dwie pary, choc uklad STRIT+ lezy w rece w 23.6% rozdan. Traci przez
to ~19% obrazen. Kazdy pomysl z todo.md nalezy oceniac pytaniem: **czy to pomaga graczowi ZOBACZYC
uklad, ktory juz ma?** — bo to, a nie brak mocy, bylo prawdziwa przyczyna skargi.

---

## T1. KOLEJNOSC ZAGRYWANIA KART — "KLUCZ"  ✅ WDROZONE (2026-07-30)

**Wartosc 5/5 · Koszt S · Konflikt z determinizmem: NIE**

Wdrozone dokladnie wg tego opisu: `ctx["keystone"]` domyslnie `false` (testy bez zmian),
`CombatController._ctx()` ustawia `true`; podwajane sa chipsy karty i PLASKIE wartosci slow
kluczowych, mnozace (FURIA/PRZECIAZENIE/KOMBINAT/LAWINA/ZNIWO) nietkniete. UI: numer 1..5 na
kazdej zaznaczonej karcie, zlota plakietka na ostatniej. Kolejnosc KLIKANIA jest kolejnoscia
zagrania, wiec gracz ustawia Klucz sam.

Najtansza zmiana o najwyzszym zwrocie w calym dokumencie i jedyna, ktora zamienia pytanie
"ktore 5 kart" (jedna poprawna odpowiedz) w "ktore 5 i ktora ostatnia" (piec odpowiedzi).

**Mechanika (wersja minimalna, zero nowych struktur):** ostatnia karta w kolejnosci zagrania jest
KLUCZEM — jej `chip_value()` x2 oraz liczbowa wartosc slowa kluczowego x2 (OSLONA, KORZENIE,
OPATRZNOSC, GNICIE, SPALENIE, ECHO, BUJNOSC, SYMBIOZA, PIJAWKA, KLATWA).

**Slowa MNOZACE zostaja nietkniete** (FURIA, PRZECIAZENIE, KOMBINAT, LAWINA, ZNIWO) — x2 nalozone
na x2 szkla daloby x8 z jednego klikniecia.

- `scoring.gd`: `ctx["keystone"]` domyslnie `false`, wiec wszystkie asercje `test_scoring.gd`
  zostaja co do jednostki; `CombatController._ctx()` ustawia `true`.
- UI: pip z numerem 1..5 na kazdej zaznaczonej karcie, zlota plakietka KLUCZ na ostatniej;
  przeciaganie zmienia kolejnosc, podglad przelicza sie natychmiast.

**Dlaczego bez konfliktu:** kolejnosc jest jawna, widoczna i policzona PRZED kliknieciem Zagraj.

**"Geometria ofiary"** i **lancuchy przyczynowo-skutkowe** — WDROZONE (2026-07-30) jako para slow
pozycyjnych, ktore w zlym miejscu nie robia NIC:
- `WROZBA` (Umysl): zagrana PIERWSZA daje +N chipsow kazdej karcie na prawo od siebie.
- `OFIARA` (Smierc): zagrana OSTATNIA pozera kartre po swojej lewej — ta ginie na stale
  (`destroyed_cards`, jak szklo), a jej chipsy dochodza do Ofiary.
Scoring zostaje CZYSTA funkcja: raportuje indeks pozartej karty, niszczy ja kontroler.

---

## T2. HYBRYDY DWUKOLOROWE + SEKRETNE UKLADY (Pentagram, Pelny Dwor)  ✅ WDROZONE (2026-07-30)

**Wartosc 4/5 · Koszt M (same uklady) / L (hybrydy) · Konflikt: NIE · Po T1**

Pentagram (5 kart, kazda innego aspektu) jest tematycznym zwienczeniem "zebrales 5 kolorow", wiec
wchodzi po biomach.

**OBOWIAZKOWY POMIAR PRZED WDROZENIEM:** `P(5 roznych aspektow w rece 8)` na aktualnej talii.
Na starej talii 16-kartowej bylo to 49.6% (zmierzone). Jesli na obecnej talii wyjdzie **> 25%,
Pentagram NIE MOZE dostac wyplaty rownej Kolorowi** — stanie sie ukladem domyslnym i zabije Kolor,
ktory wlasnie zostal naprawiony.

**Rekomendacja:** Pentagram = 30x3 **plus efekt unikalny "+1 odrzut z powrotem"**. Sila w TEMPIE,
nie w liczbie — wtedy Pentagram kontra Full to realny wybor, a nie oczywistosc.

**Warunek konieczny:** ranking ukladow musi byc odpiety od porzadku enuma. `Poker.value_of()` juz
istnieje i jest uzywany przez podpowiedz reki i obie tabele wyplat, ale kod, ktory porownuje
`Poker.Hand` przez `maxi()` na ordinalu (statystyki runu, `ACH_MAGNUM`), przyznalby osiagniecie za
Magnum Opus komus, kto zagral Pentagram. **Przed T2 przejsc calosc na `value_of`.**

**Hybrydy** (karta liczaca sie do dwoch kolorow) to koszt L, nie M: `Poker._is_flush` porownuje
`c.aspect` skalarnie w jednym miejscu, ale `aspect_counts` w `scoring.gd`, sigil na karcie,
`Aspects.allies` i doradca reki to kolejne cztery. Osobna pozycja, po T2.

---

## T3. METAGRA: WTAJEMNICZENIA + KSIEGA ASTROLOGA  ✅ WDROZONE (2026-07-30)

**Wartosc 4/5 · Koszt M · Konflikt: NIE (determinizm jest tu ATUTEM) · Po biomach**

Zaslony (Veil I-V) juz istnieja — to gotowy szkielet Wtajemniczen. Trzeba przestac podnosic HP
i zaczac zmieniac ZASADY:

- **Wtajemniczenie 5:** odsetki od Rteci naliczaja sie tylko od kart w kolorach WROGICH na
  Pentagramie (`Aspects.allies` juz istnieje — to jedna petla).
- **Wtajemniczenie 7:** kazdy boss zaczyna z ODWROCONA regula pola (`is_reversed` juz istnieje).
- **Wtajemniczenie 9:** talia startowa traci kolor domowy. Wprost atakuje matematyke z F1 i wymusza
  inny build — najmocniejszy modyfikator, jaki ta gra moze miec.

**Ksiega Astrologa:** Dzienny Los juz dziala. Brakuje tablicy wynikow i — kluczowe — wykorzystania
tego, ze gra jest DETERMINISTYCZNA: idealny gracz moze policzyc idealny run od poczatku do konca.
To jedyny wyroznik marketingowy tej gry wobec Balatro.

**Twarda zaleznosc:** `CONTENT_VERSION`. Kody losu sprzed reworku talii sie rozjada; Ksiega
Astrologa musi wystartowac PO ostatnim zerwaniu strumienia rng, inaczej pierwszy tydzien wynikow
jest smieciowy.

---

## T4. ODWROCONE KARTY / INWERSJA ASPEKTU  ✅ WDROZONE (2026-07-30)

**Wartosc 3/5 · Koszt M · Konflikt: TAK, rozwiazywalny · Po T2**

Odwrocenie karty daje x3 Mult, ale zmienia jej Aspekt na WROGI na Pentagramie (`Aspects.allies`
definiuje sasiadow, wiec wrogi = ten, ktory sasiadem nie jest).

**Konflikt i rozwiazanie:** odwrocenie MUSI byc aktem gracza w sklepie albo przez Arkanum, wykonanym
POZA walka, i zapisanym w karcie (`is_reversed`). Odwracanie przy dobraniu = RNG w walce = podglad
klamie. **Zakaz absolutny.**

**Uwaga krytyczna wobec F1:** inwersja aspektu ZMIENIA MATEMATYKE KOLORU. Odwrocenie polowy talii
Natury na Chaos moze albo stworzyc drugi kolor domowy (dwa flushe), albo rozbic jedyny (flush -> 0).
Przed wdrozeniem przeliczyc `P(FLUSH)` po 3, 6 i 9 odwroceniach. Jesli spada ponizej 8%, odwrocenie
musi zachowywac kolor i zmieniac tylko RANGE.

---

## T5. EWOLUCJA KART W RUNIE (Blizny i Blogoslawienstwa)  ✅ WDROZONE (2026-07-30)

**Wartosc 3/5 · Koszt M · Konflikt: NIE (o ile wyzwalacz jawny) · Po T2**

Polowa infrastruktury juz istnieje: `CardData.growth` (WZROST), `bloom` (KORZENIE), `wear`
(PRZECIAZENIE) sa polami runtime, a `wear` jest juz utrwalany w zapisie runu. "Pamiec walki" to to
samo pole, inny wyzwalacz.

**Co dodac:** karta, ktora zadala decydujacy cios bossowi, dostaje na stale +5 chipow i znacznik
wizualny. `CombatController` zna juz `fight_best_hit` i karte konczaca. — ZROBIONE.

**"Trauma po Wiezy"** — ZROBIONE (2026-07-30): wygrana z Wieza po tym, jak zniszczyla ci karty,
zostawia jednego ocalalego SPEKANEGO: `cracked = true`, jedna trzecia bazy mniej na stale, ale
LAWINA przechodzi po nim DWA razy. Nie do kupienia — trzeba za to zaplacic. Wybor ocalalego
deterministyczny (pierwsza niespekana karta w talii), nigdy losowany.

**Pulapka:** `growth` NIE jest zapisywany w `run_save` (celowo transient). Trwala ewolucja wymaga
NOWEGO, zapisywanego pola (`scar: int`) — recykling `growth` zlamie WZROST.

**Wyzwalacz musi byc deterministyczny** (ostatnia karta ostatniego zagrania). Zakaz: "10% szans,
ze karta ewoluuje".

---

## T6. ROZKLADY TAROTA JAKO MODYFIKATORY POLA

**Wartosc 2/5 wobec kosztu · Koszt L · Konflikt: TAK, powazny · NAJPOZNIEJ albo wcale**

Rozklad Trzech Kart (Przeszlosc / Terazniejszosc / Przyszlosc) burzy caly silnik punktacji:
`Poker.evaluate` zaklada 5 kart naraz, `Scoring.score` jest jednorazowa funkcja czysta, a "karta
w Przyszlosci ujawni moc za 2 tury" wymaga kolejki efektow odroczonych, ktorej nie ma.
**To nie jest modyfikator — to drugi tryb gry.**

Jesli kiedykolwiek: efekt odroczony MUSI byc widoczny w kokpicie od momentu polozenia karty
("za 2 tury: +180"), inaczej podglad klamie o przyszlosci. Jest to wykonalne (talia jest
deterministyczna, wiec przyszlosc JEST znana) i bylby to najmocniejszy dowod tezy "karty nie
klamia" w calej grze — ale kosztuje pelna przebudowe warstwy podgladu.

**Tania wersja, ktora juz zostala zrobiona zamiast tego:** "Rozklad" jako PRAWO POLA biomu, czyli
mechanizm `RegionData.Law` z etapu F5. Kazdy biom juz zmienia zasady pojedynku — fikcja rozkladu
jest dostarczona za ulamek kosztu.

---

## Kolejnosc wdrazania (rekomendacja)

```
[T1 ZROBIONE]  ->  domkniecie biomow (bossy Cesarzowej/Kola, ekran pieczeci w menu)
            ->  T2 (Pentagram + Pelny Dwor, PO pomiarze)  ->  T3 (Wtajemniczenia + Ksiega)
            ->  T5 (Blizny)  ->  T4 (Inwersja, PO pomiarze koloru)  ->  T6 (tylko eksperyment)
```

**Zasada nadrzedna dla kazdego etapu:** najpierw pomiar `tools/dev/probe_deckmath.gd`, potem kod.
Ta gra ma juz jeden precedens, w ktorym "oczywista" zmiana projektowa (talia 70 kart) zostala
odrzucona, bo pomiar pokazal, ze **pogarsza** dokladnie te skarge, ktora miala naprawic
(P(najlepszy uklad <= dwie pary) 78.1% wobec 42.8%). Liczby przed intuicja.


---

## GLEBSZA WARSTWA (2026-07-30, po zamknieciu T1-T6)

Poza szescioma glownymi punktami todo.md zawieralo pomysly szczegolowe, ktore pierwsze przejscie
tylko musnelo. Wdrozone:

| Skad | Co | Jak dziala |
|---|---|---|
| par.1 | Lancuchy przyczynowo-skutkowe | `WROZBA` zagrana PIERWSZA: +N chipsow kazdej karcie na prawo |
| par.1 | Geometria ofiary | `OFIARA` zagrana OSTATNIA: pozera i NISZCZY karte po swojej lewej |
| par.5 | Trauma po Wiezy | ocalala karta wraca SPEKANA: -1/3 bazy, ale podwojny retrigger Lawiny |
| zakonczenie | Wskrzeszanie z cmentarza | Arkanum Sadu = `RAISE_DEAD`: RAZ na walke grob wraca do talii |

Wspolna zasada: kazdy z nich zamienia HISTORIE albo POZYCJE karty w mechanike, zamiast dokladac
kolejna liczbe. Zadnego z nich nie da sie kupic w sklepie — trzeba je wygrac albo ulozyc.

## STAN KONCOWY (2026-07-30)

Wszystkie szesc pomyslow z todo.md jest zamknietych:

| | Co | Jak wyszlo |
|---|---|---|
| T1 | Klucz | ostatnia karta x2 (chipsy + plaskie keywordy); numery 1..5 + zlota plakietka |
| T2 | Pentagram / Pelny Dwor | ZMIERZONE: Pentagram dostepny 40.2%, wiec 30x3 + zwrot odrzutu; grany 16%, zabral udzial DWOM PAROM (34.9->21.3%), Koloru nie ruszyl |
| T2b | Hybrydy | drugi aspekt karty (`splash`); flush i Pentagram to teraz problem POKRYCIA, nie zliczania |
| T3 | Wtajemniczenia | Zaslony III-V zmieniaja ZASADY: sklep 2 karty / Klucz wylaczony / brak calego Aspektu |
| T3 | Ksiega Astrologa | rekord na Dzienny Los w profilu + w menu (lokalnie, bez serwera) |
| T4 | Odwrocone karty | ZMIERZONE: inwersja NIE glodzi Koloru, zageszcza go (1.86%->4.83%); x1.45 Mult, sklep 6 |
| T5 | Blizny | karta konczaca bossa: +5 chipow na stale, wlasne zapisywane pole `scar` |
| T6 | Rozklady tarota | swiadomie zastapione PRAWAMI POLA biomow (pelna wersja to drugi tryb gry, nie modyfikator) |

Kazdy punkt ma testy w `tests/test_combat.gd` (13 nowych asercji), w tym przypadki NEGATYWNE:
Cesarzowa NIE leczy sie przy pieciu kartach, a strit z pieciu aspektow NIE spada do Pentagramu.

CO ZOSTAJE DLA CZLOWIEKA (bot tego nie sprawdzi):
- balans praw biomow, zwlaszcza Biblioteka (+1 karta w rece) i Pogorzelisko (x1.5 za piec kart);
- czy Zaslona V (brak calego Aspektu) jest ciekawa czy tylko frustrujaca;
- czy cena inwersji (6) i rzezbienia (9) jest wlasciwa wobec 5 za karte.
