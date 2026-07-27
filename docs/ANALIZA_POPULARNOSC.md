# Analiza: czego grze brakuje do POPULARNOSCI

Metoda: panel 3 niezaleznych krytykow (retencja / glebia buildow / tozsamosc-shareability, kazdy
czytal CALY kod i docs) + synteza z dziesiatkami wlasnych playtestow pelnej petli. Bez kodowania —
diagnoza i kierunki. Stan gry: kompletny szkielet (4 regiony, meta, menu, save, wachlarz, art).

## Diagnoza jednym zdaniem

Zbudowalismy znakomity SZKIELET — ale popularne roguelike'i sprzedaja trzy emocje, ktorych u nas
jeszcze nie ma: **STRACH przed porazka, EKSTAZE z przelamania i MILOSC do swiata/postaci.**
Gra dziala; nie jest jeszcze GLODNA.

## 7 glownych brakow (posortowane; kazdy z dowodem z projektu)

### 1. NIE DA SIE PRZEGRAC -> nie ma emocji  [KRYTYCZNE]
Bot — jawnie „dolna granica umiejetnosci" — wygrywa 3/3 pelne podroze (20-45 HP); heal-stack
(rest 12 + full-heal miedzy regionami + Slonce +3/zagranie + Opatrznosc + Pijawka) nie ma zadnego
capu; jedyny zegar to enrage +2/+3 na cykl. Po wygranej: przycisk „Nowy run" w te sama, identyczna
drabine (ascension = BRAK). Roguelike zyje zdaniem „zginalem na bossie, ale juz wiem co zrobic" —
**nasza gra nie umie wyprodukowac tego zdania.**
KIERUNEK: winrate pierwszego runu ZNACZNIE < 50%; cap leczenia per walka; reguly bossow karzace
przeciaganie mocniej niz +2/cykl; ascension w bazowej grze od dnia 1.

### 2. LICZBY NIE EKSPLODUJA -> brak power fantasy  [KRYTYCZNE]
Mult jest niemal w calosci addytywny/plaski: 10 z 12 keywordow daje plaskie chipsy/staty; relikty
to stale x1.15-1.5; sufit buildu ~500 obrazen — Balatro zyje z wykladniczych drabin i „e-notation".
Do tego NAJSILNIEJSZY uklad gry (Piec jednakowych) lezy GOTOWY w starterze (piec kart rank-7!) —
apex ma byc BUDOWANY, nie rozdany. Kompunujace keywordy (Przeciazenie xMult-niszczy-karty, Lawina
retrigger, Kombinat xMult-za-powtorzenie) SA w DESIGN.md — niewdrozone.
KIERUNEK: jeden usankcjonowany wektor kompundujacy (multiplikatywna rodzina keywordow + relikty
mnozace SIEBIE nawzajem); starter max 3 karty jednej rangi; overkill placi (nadmiar dmg -> ☿/Sol).
PEREL KA PANELU: **determinizm jako dramat** — sim-preview ZAPOWIADA jackpot zanim klikniesz;
uczciwy podglad nie blokuje spektaklu, on go rezyseruje.

### 3. GRA JEST NIEMA I BEZ TWARZY  [KRYTYCZNE]
Muzyki nie ma wcale (AudioManager.play_music: zero wywolan); SFX to 10 proceduralnych bipow;
14 z 18 wrogow to LITERA w ramce; nikt w grze nie mowi — cala osobowosc pisana to ~10 zdan.
Inscryption ma Leshy'ego, Balatro ma Jimbo — my mamy pusty stol.
KIERUNEK: (a) jedna sygnaturowa petla occult-lounge z diegetycznym hookiem (warstwy gestnieja z
multem, tetno przy enrage); (b) sylwetki wrogow — **16 kart dworskich Malych Arkanow (art JUZ w
assets/cards/minor/) to gotowy bestiariusz z twarzami**, domykajacy nasza jedyna elegancka regule
(„pokonaj karte, nos karte") w dol; (c) GLOS TALII: wrozbita-narrator, ktory czyta Twoj los przed
walka — u nas przepowiednia jest z definicji PRAWDZIWA.

### 4. RUN TO METRONOM BEZ WYBOROW SCIEZKI  [POWAZNE]
walka->nagroda->walka->sklep->boss x4; jedna droga, zero elit, wezel nie jest wyborem (jeden
przycisk „Rusz"); omeny to +/-kilka statow. Warstwa StS („trasa autorowana przez gracza — wycena
ryzyka") nie istnieje. Jedyny prawdziwy draft calej gry to otwierajace 1-z-3.
KIERUNEK: binarny fork na szczeblu (ELITA: trudniejszy wrog -> lepsze Arkanum/rzadka karta vs
bezpieczna droga); omeny jako push-your-luck z konsekwencja buildowa. W deterministycznej walce to
WYBORY (nie RNG) sa nasza naturalna warstwa wariancji — i wlasnie tej warstwy brakuje.

### 5. NAGRODY BEZ SZCZYTOW  [POWAZNE]
Wszystkie karty to common (CardData nie ma rzadkosci); sklep i nagroda losuja z tej samej,
jednolitej puli 36; boss-relikt przychodzi BEZ WYBORU w stalej kolejnosci Wieza->Diabel->Ksiezyc->
Swiat co run; caly loot-space obejrzany po 2 runach. Genre'owy szczyt dopaminy — rare/legendary
moment — nie wystepuje. DESIGN.md ma gotowa odpowiedz (losowany podzbior 22 Arkanow na run).
KIERUNEK: tiery rzadkosci z innymi ramkami i szansami; boss-relikt jako wybor 1-z-N — najlepiej
**prosty vs ODWROCONY** (mocniejszy + cena) — zaparkowana mechanika reversed jako marka gry.

### 6. META ODEJMUJE ZAMIAST DODAWAC  [POWAZNE]
Zamknelismy 22% puli kart — NAJSWIEZSZE mechaniki (Wzrost/Symbioza/Pijawka/Klatwa) — za grind gry,
ktora gracz juz rozwiazal; trwale edycje startera to czysty power-creep wycelowany w stala trudnosc.
KIERUNEK: odwrocic przeplyw — baza kompletna od startu; odblokowania POSZERZAJA przestrzen (nowe
Arkana do puli bossow, nowi bossowie, omeny, alternatywne startery); czesc unlockow za OSIAGNIECIA
(„wygraj flushem Smierci"), nie za walute; trwale staty dopiero za tierami ascension.

### 7. TOZSAMOSC: KOMODYTOWY WIZUAL + NIEME NAZWISKO + ZERO SHAREABILITY  [POWAZNE]
RWS 1909 to public domain — maja go setki jam-gier; nasza sygnatura powinna byc PROFANACJA tej
talii (odwrocone/wypaczone/animowane karty bossow — mechanika reversed jako marka WIZUALNA).
Tytul PARALLAXA nic nie mowi o pokerze/tarocie i **koliduje z Twoja druga, zupelnie inna gra** —
teza gry sama jest lepszym szyldem („Karty nie klamia" / "The Cards Do Not Lie", tradycja nazw
w stylu Luck be a Landlord). Koniec 30-minutowego runu = JEDNA LINIJKA tekstu; zero seedow,
rekordow, najwiekszego hitu.
KIERUNEK-PEREL KA: **koniec runu jako ROZKLAD TAROTA** — run rozlozony fizycznie na stole:
noszone Arkana, najwiekszy hit jako karta („612 — porazil Wieze"), najlepszy uklad, seed —
ekran ZROBIONY do screenshota.

## Osobne spostrzezenie z moich testow (nie z panelu)
Deterministyczny recykling talii bez tasowania sprawia, ze dluga walka jest dosl. OKRESOWA —
tura 9 na Swiecie to tura 3 z wiekszym paskiem. Glebia per-tura sprowadza sie do „kliknij maksimum
z podgladu". Covenant pozwala na glebie PLANOWANIA (jawny wzorzec intencji nagradzajacy
przetrzymanie burstu na telegrafowane okno; keywordy odpalajace od POPRZEDNIEJ tury) — zakazuje
tylko ukrytej informacji.

## PRIORYTETY (dzwignia popularnosci / koszt)

| P | Co | Dlaczego najpierw |
|---|---|---|
| P1 | Trudnosc + fail-rate + ascension | bez strachu nic innego nie dziala |
| P2 | Jeden wykladniczy wektor mocy + starter bez gotowego Five-of-a-Kind | ekstaza „numbers go BRRR" |
| P3 | Muzyka (1 utwor-tozsamosc) + wrogowie=karty dworskie | najtanszy skok vibe'u (assety juz sa) |
| P4 | Fork elita/bezpiecznie + boss-relikt 1-z-2 (prosty vs ODWROCONY) | agency + marka reversed |
| P5 | Rozklad tarota na koniec + seed + rekordy | shareability/streamer test |
| P6 | Odwrocenie mety (poszerzanie, achievement-unlocki) | retencja dlugoterminowa |
| P7 | Decyzja o tytule | pozycjonowanie (kolizja z Parallaxa 3D) |
