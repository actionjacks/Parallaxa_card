# Analiza: droga do hitu na Steam

Metoda: pelny przeklik game loopu realnym inputem (swiezy profil: DEFEAT na Wiezy w regionie 1;
BOOST: VICTORY przez 4 regiony z odwroconymi reliktami i XP) + panel 5 analitykow rynkowych z
dostepem do internetu (pozycjonowanie / pierwsze 15 minut / viralnosc / glebia tresci / craft+platformy).
Pelne analizy: notatki robocze; ponizej synteza z decyzjami. Data: 2026-07-27.

## Werdykt jednym zdaniem

Warstwa SYSTEMOW jest na poziomie czolowki gatunku i ma jedyny nieskopiowalny wyroznik
(uczciwy, DOKLADNY podglad — "wrozba zawsze sie spelnia") — ale ten wyroznik jest dzis
NIEWIDOCZNY (16px tekstu), tresc wyczerpuje sie po ~6-8 runach (staly ciag bossow), a warstwa
platformowa (Deck/Cloud/achievementy Steam) prawie nie istnieje. Wszystkie trzy luki sa tansze
do zamkniecia niz to, co juz zbudowano.

## Kontekst rynkowy (zweryfikowany w sieci)

- Fala Balatro-like 2024-26 utonela niemal cala; przebily sie gry z JEDNA wlasna tozsamoscia
  sensoryczna + mechanika w jednym zdaniu (CloverPit: $9.99, 1M kopii w <2 mies.).
- Balatro rozszedl sie przez MALYCH streamerow (Northernlion po Danie Gheeslingu; turniej
  6 streamerow na wspolnym demo przed Next Festem), nie przez reklamy.
- Spolecznosc Balatro dosl. BLAGA o to, co my mamy o jedno pole tekstowe od wdrozenia:
  wpisywanie seeda i wspolny dzienny seed.
- Najsilniejszy predyktor wyniku Next Festu = wishlisty PRZED festem (r=0.825). Nie wchodzic
  na fest ze swieza strona.
- Hit-rate deckbuilderow spada (6.7%->5.1% rok do roku) — wygrywaja walidowane szablony
  Z REALNYM wyroznikiem. My go mamy; caly plan ponizej to czynienie go widocznym w 90 sekund.

## HOOK (krotki opis na Steam)

> "Wrozka nigdy nie klamie: tarotowo-pokerowy roguelike bez losowosci w walce — widzisz
> DOKLADNE obrazenia zanim klikniesz, pokonujesz Wielkie Arkana i nosisz ich karty jako moc."

Nie prowadzic slowem "deterministyczny" — prowadzic fantazja ("kazda wrozba sie spelnia"),
a podglad ma to UDOWADNIAC.

## MASTER PLAN (fazy wg dzwigni/naklad)

### FAZA A — "Widoczny cud" (~2 tyg; przed czymkolwiek innym)
1. Prymitywy hitstop/shake/flash w screen_effects (1 dzien) + opt-outy reduce-motion/flash.
2. CEREMONIA PROROCTWA: lethal-select = beat zamrozenia, diegetyczny stempel na caly ekran
   (ramka tarota, obiecana liczba, nazwa ukladu, SEED w kadrze — klip sam sie podpisuje),
   heartbeat startuje PRZED klikiem; po kliku licznik Chips x Mult roluje DOKLADNIE do
   zapowiedzianej liczby ("As written"). To jest strzal do trailera i klip streamerski.
3. Dwie jednorazowe linie diegetyczne w walce 1: przy pierwszym podgladzie ("Wrozba jest
   dokladna. Karty nie klamia — ten wynik sie stanie.") i przy pierwszym SMIERTELNE
   ("Zapowiedziana smierc zawsze przychodzi."). Bez tego USP nie laduje NIGDY (dowod
   uczciwosci to brak zaskoczenia — niewidzialny bez wskazania).
4. Ekran smierci = konwersja: linia przyczyny ("Wieza — tura 9: blok nie chronil") + najblizsze
   odblokowanie z paskiem ("Pakt Zniwiarza 11/60 Soli"). Roznica miedzy churn a "jeszcze jeden run".
5. Ceremonie: boss-kill (hitstop->flash->karta pada/plonie->beat ciszy->klaim), pekniecie szkla
   (bielenie + odlamki), odkrycie Magnum Opus (jednorazowy pentagram + zloty stempel),
   level-up Tarocisty na spreadzie (pasek + flip karty rangi).
6. Drobne z przekliku: hover-podglad karty nachodzi na odczyt intencji (kolizja UI, trywialne);
   lewy panel spreadu pusty przy <=1 relikcie (sciagnac layout).

### FAZA B — "Kultura seeda" (kilka dni)
1. Pole WPISYWANIA seeda w New Run ("Wpisz los") — bez tego "Powtorz ten los" to petla z
   przecietym drutem powrotnym.
2. Daily Fate: seed = hash(daty UTC), staly starter, bez serwera — kultura wspolnej zagadki
   samoorganizuje sie na Discordzie (Balatro to udowodnil).
3. TRYB "CZYSTE ODCZYTANIE" (Pure Reading): wspolne seedy graja na klasycznej talii i bazowych
   pulach — dzis sklad puli zalezy od profilu (dokupione arkana/omeny), wiec ten sam seed !=
   ten sam run miedzy graczami. Gra z uczciwoscia w tytule nie moze miec klamiacego seeda.
4. Share-string: kopiuj "The Cards Do Not Lie — Fate A3F2-09BC, Veil 3" (nie goly hex).
5. Streamer Mode w opcjach: +2 kroki fontu, seed stale w rogu, wieksze popupy; stale (nie
   hover-owe) opisy niesionych Arkanow. Skip animacji tury wroga (pace VOD).

### FAZA C — "Wiecej losow" (4-6 tyg; likwiduje klif "widzialem wszystko")
Dzis: ~6-8 runow (~4-5h) do obejrzenia calej tresci; recenzje gatunku pisze sie w 15-25h.
1. ROTACJA BOSSOW z 22 Arkanow (cel 12-16 wdrozonych; design + art JUZ SA w repo) — kazdy
   nowy boss MNOZY przestrzen runow zamiast dodawac; "widzialem wszystko" z runu ~6 na ~25.
   NAJWYZSZY zwrot w calym planie.
2. Endless "Beyond the World" + Zaslony 6+ — wektor wykladniczy wreszcie ma na co sie wydawac.
3. Keywordy 15 -> ~25 (Wrozba/Zwloka/Hazard/Ofiara... — zaprojektowane w DESIGN.md).
4. Challenge-spready (10-12 presetow talia+regula, czyste dane).
5. Osiagniecia 5 -> ~25 (z istniejacych statystyk; 5 na stronie sklepu wyglada jak gra
   niedokonczona).
6. NIE robic regionu 5 (dodaje minuty do runu, nie runy do gracza).

### FAZA D — "Platforma" (2-4 tyg)
1. Steam Cloud: Auto-Cloud na istniejace ConfigFiles (~1h; UWAGA na custom_user_dir path;
   wykluczyc settings.cfg z roamingu).
2. GodotSteam: osiagniecia (mirror in-game), rich presence ("Zaslona 3 — Wieza, Region 2").
3. STEAM DECK VERIFIED (decyzja: TAK, przed launch): nawigacja focus_neighbor po code-built UI,
   schemat pada jak w Balatro (D-pad po wachlarzu, A wybierz, X zagraj, Y odrzuc), glify,
   NAPRAWA hardcodowanych keycodes ESC/TAB w overlays.gd (blokuja pada i remapping),
   audyt czytelnosci monogramu na 1280x800, CRT domyslnie subtelne.
4. Dostepnosc: STALE GLIFY 5 Aspektow (redundancja ksztaltem — 5 kolorow to podrecznikowy
   fail deuteranopii), suwak skali UI, fallback font CJK (monogram nie ma glifow).
5. Lokalizacja: ~3-4k slow => zh-CN (nr 1 populacja Steam), ja, de, pt-BR (~$2-3k lacznie);
   strony sklepu w kazdym jezyku (tam mieszka konwersja). FIGS-reszta po trakcji.

### FAZA E — "Sklep i marketing"
1. TYTUL na Steam: "The Cards Do Not Lie" BEZ prefiksu PARALLAXA (kolizja z inna gra, zero
   informacji; kolizja "Cards Lie" na Steam istnieje — dyferencjacja robi capsule+tagi).
   Usunac ghost "PARALLAXA" z menu przed publicznymi screenami.
2. CAPSULE (zlecenie $300-800, najwyzszy ROI artu w projekcie): JEDNA odwrocona, profanowana
   karta (Smierc XIII / Wieza XVI, plonace krawedzie), tytul w 2 liniach ciezka antykwa —
   NIE in-game pixel font, NIE czysty wachlarz skanow RWS (czyta sie jako shovelware).
   W opisie sklepu wprost: "talia z 1909, celowo zbeszczeszczona" — uprzedzic zarzut.
3. Tagi (pierwsze 5 steruje More-Like-This): Roguelike Deckbuilder, Card Battler, Deckbuilding,
   Poker, Card Game; dalej Roguelite, Occult, Difficult, Dark Fantasy...
4. CENA: $9.99, -10% na launch (nie -20%). $14.99 = pojedynek z Balatro na polish, przegrany
   dzis. CloverPit udowodnil $9.99 jako punkt przebicia drugiej fali.
5. Sciezka: strona sklepu (sierpien) -> DEMO publiczne 3-4 tyg przed festem: REGIONY 1-2,
   klif "Ksiezyc czeka." -> wishlist; profil PRZENOSI sie do pelnej gry (napisac to na stronie);
   seedy WLACZONE w demo -> Next Fest (luty 2027) z rozegranym demo -> pelny launch $9.99.
   Cele: announce 0.5-1.5k WL, przed festem 3.5-5k, fest +2-4k, konwersja demo->WL 25-40%.
6. KIT streamerski: 5 nazwanych kuratorowanych seedow ("Dar Zniwiarza"...), wyscig 5-10 malych
   streamerow na wspolnym seedzie (model turnieju Playstack) — nasz determinizm czyni wyscig
   PROWDZIWIE fair, to jest zdanie otwierajace maila. Polska scena = tani przyczolek.
   "100% proceduralne audio = zero ryzyka DMCA" — na strone i do maili.
7. EA vs pelny launch: PELNY LAUNCH. EA w tym gatunku wybacza tylko znanym markom; nasz
   jednorazowy news-hook ("jedyny uczciwy podglad w gatunku") strzelamy raz.
8. Discord-first (kanaly #daily-fate, #seed-vault, #spread-screenshots); polityka fan-artu
   day-one (RWS = domena publiczna, remiksujcie wszystko); pozniej user://grimoire/ (paczki
   .tres/csv) — "napisz karte w pliku tekstowym" to sam w sobie beat marketingowy.

### CZEGO NIE ROBIC (ochrona planu)
Early Access; region 5; parytet shaderow z Balatro (cudza tozsamosc artu); e-notation
(zabija czytelnosc uczciwego podgladu — sufit fantazji: "duze, policzalne, przepowiedziane");
rig narratora; trading cards na start; $14.99.

## Ryzyka recenzyjne i mitigacje
1. TRUDNOSC (najwieksze; casus Wildfrost=Mixed): docelowy winrate 1. runu u LUDZI ~40% do
   3. proby na Zaslonie 0 (bot to PODLOGA, nie target); smierc zawsze z przyczyna + 1-klik
   "Powtorz ten los" jako "odczytaj karty ponownie"; prawdziwa gra = Zaslony 1-5.
2. Determinizm czytany jako "brak variety / to puzzle": przy dzisiejszym stalym ciagu bossow
   ten zarzut bylby PRAWDZIWY — rotacja bossow przed launch; marketing "wrozba jest
   prawdziwa", nigdy "bez RNG".
3. RWS = "asset flip": profanacja widoczna w 5 sekund (capsule, karty bossow); own it w opisie.
4. Zmeczenie audio ("zmutowalem"): wariacje bojowe + warstwy gestniejace z multem; jeden
   autorski utwor-sygnatura minimum.

## Stan przekliku (2026-07-27)
Swiezy profil: draft (Mag) -> 2 wygrane walki -> smierc na Wiezy -> spread z "+15 PD" — pelna
petla czysta, zero crashy. BOOST: VICTORY 4 regiony, 10 walk, odwrocone klaimy (45/45 maxHP =
cena zaplacona), XP/awanse na ekranach. Do poprawki: kolizja hover-podgladu z intencja;
sciagniecie layoutu spreadu przy <=1 relikcie.
