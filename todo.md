Kompleksowa Reorganizacja UI/UX, Architektury i Meta-Progresji w Godocie
Rola i Cel

Wciel się w rolę Senior Game Developera oraz Projektanta UI/UX ze specjalizacją w silniku Godot. Twoim zadaniem jest przeprowadzenie pełnej analizy i zaprojektowanie od zera systemów, których obecnie brakuje w grze karcianej. Gra musi być intuicyjna, posiadać doskonały game feel, czytelny interfejs oraz skalowalną architekturę.
1. Architektura i Workflow (Kluczowy Wymóg Techniczny)

Obecnie większość elementów gry jest generowana hardcodem w skryptach, co uniemożliwia projektantom i designerom szybki balans rozgrywki.

    Przejście na Custom Resources: Wszystkie karty, mechaniki, przeciwnicy i nagrody muszą opierać się na zasobach (Resource / pliki .tres).

    Edycja w Inspektorze: Skrypty muszą udostępniać jak najwięcej zmiennych przez @export (np. statystyki, teksty opisowe, referencje do prefebów wizualnych, efekty dźwiękowe).

    Prefabrykowane Sceny: UI oraz elementy kart powinny być budowane jako osobne sceny Godota (.tscn), a nie budowane od zera za pomocą kodu w runtime.

2. Interfejs Walki i UX Karta-Ręka (Inspiracja: Hearthstone)

Aktualnemu panelowi walki brakuje czytelności i odpowiedniego feelu. Należy wdrożyć następujące zmiany:

    Układ Kart w Ręce: Karty trzymane przez gracza muszą być w pełni widoczne, układać się w naturalny wachlarz na dole ekranu i wizualnie przypominać fizyczne trzymanie kart w ręce.

    Animacje i Game Feel:

        Wymagane są płynne animacje (np. z użyciem Tween) dla dobierania kart (karta wylatuje z talii i wchodzi do ręki) oraz ich odrzucania/spalania.

        Gracz musi wyraźnie widzieć, co dzieje się na stole w każdej sekundzie walki.

    Mechanika Zagrywania: Aby zagrać kartę, gracz przeciąga ją (Drag & Drop) lub wyrzuca na środkowy panel walki, a następnie zatwierdza ruch przyciskiem "Zagraj" / "Koniec Tury".

    Inspekcja Karty (RMB): Kliknięcie dowolnej karty (w ręce lub na stole) prawym przyciskiem myszy powinno powodować jej przybliżenie na środku ekranu. Po prawej stronie przybliżonej karty musi rozwijać się panel z dokładnymi opisami (Tooltipy) wyjaśniającymi każde słowo kluczowe, mechanikę i statystyki.

3. Globalne GUI i Ekrany Informacyjne

Gracz obecnie czuje się zagubiony z powodu braku dostępu do kluczowych informacji.

    Ekran Przeglądu (Pod klawiszem TAB): Otwiera panel gracza w trakcie rozgrywki, w którym można sprawdzić:

        Aktualną talię (decklistę).

        Posiadane karty, odblokowane arkany oraz relikwie/przedmioty.

        Aktualny poziom wieży / progres rozgrywki.

        Aktywne mechaniki i statusy postaci.

    Menu Pauzy: Naprawa i implementacja menu pauzy wywoływanego klawiszem ESC (zawierającego opcje, powrót do gry, wyjście, zapis/odczyt).

    Menu Główne i Ekran Tytułowy: Zaprojektowanie stylowego menu (z motywem Kart Tarota i mistycyzmu pasującego do gry) zawierającego: Nową Grę, Kontynuację, Opcje, Zbiór Kart (Kolekcję) oraz Wyjście.

4. Meta-Progresja, Profil Gracza i Ulepszanie Kart

    Profil Gracza i Zapisywanie: Wdrożenie systemu profili z pełnym zapisem i odczytem stanu gry (zapis progresu w trakcie runu oraz progresu globalnego/meta między runami).

    Waluta i Ulepszanie Kart:

        Między runami gracz zbiera walutę, za którą może ulepszać karty na stałe lub odblokowywać nowe arkany.

        Wizualna Ewolucja Kart: Z każdym poziomem ulepszenia karta zyskuje lepszy wygląd – od standardowego, przez karty foliowane (Foil / efekty błysku i szaderów), aż po animowane modele 3D i dynamiczne efekty wizualne (na wzór złoty/diamentowych kart z Hearthstone).

    Ekwipunek (Inventory): Przejrzysty panel do zarządzania odblokowanymi elementami, nagrodami i przedmiotami.

Oczekiwany Rezultat od Ciebie (Claude):

    Analiza Architektoniczna: Przedstaw plan, jak przebudować obecny system na Custom Resources w Godocie (podaj przykładowy kod klasy CardData oraz instrukcję konfiguracji w Inspektorze).

    Krok po Kroku (Roadmapa): Zaproponuj kolejność wdrażania zmian, zaczynając od fundamentów (dane i zapis), przez UX walki (ręka kart), aż po menu i meta-progresję.

    Struktura Drzewa Scen: Rozpisz rekomendowaną strukturę węzłów (Nodes) dla panelu walki, wachlarza kart oraz panelu pod klawiszem TAB.



    Werdykt panelu (5 analityków, dane z sieci)
Systemy masz na poziomie czołówki gatunku i jedyny nieskopiowalny wyróżnik — ale on jest dziś niewidoczny. Uczciwy podgląd objawia się brakiem zaskoczenia, a brak nie jest wydarzeniem. Rynek: fala Balatro-like'ów utonęła prawie cała; przebił się CloverPit ($9.99, 1M kopii w <2 mies.) — jedna własna tożsamość + mechanika w jednym zdaniu. Balatro rozniósł się przez małych streamerów i wspólne seedy, a jego społeczność błaga o to, co Ty masz o jedno pole tekstowe od wdrożenia.

Priorytety (dźwignia/nakład)
A. „Widoczny cud" (~2 tyg, przed wszystkim): CEREMONIA PROROCTWA — przy śmiertelnym zagraniu pełnoekranowy stempel z obiecaną liczbą i seedem W KADRZE, heartbeat przed klikiem, licznik roluje dokładnie do przepowiedzianej wartości („As written"). To jest klip, którego żaden konkurent nie może nakręcić. Do tego: 2 diegetyczne linie w 1. walce („Wróżba jest dokładna…"), ekran śmierci z przyczyną + paskiem najbliższego odblokowania (różnica między churn a „jeszcze jeden run"), ceremonie boss-kill/szkło/Magnum Opus.

B. „Kultura seeda" (dni): pole wpisywania seeda, Daily Fate (hash daty, bez serwera), tryb „Czyste Odczytanie" (wspólne seedy na klasycznej talii — dziś skład puli zależy od profilu, więc cudzy seed kłamie; gra z uczciwością w tytule nie może tego mieć), Streamer Mode.

C. „Więcej losów" (4–6 tyg): dziś gracz widzi całość w ~6–8 runów, a recenzje pisze się w 15–25h. Rotacja bossów z 22 Arkanów (design i art JUŻ w repo, cel 12–16) — mnoży przestrzeń runów, „widziałem wszystko" z runu ~6 na ~25. Plus endless „Beyond the World", keywordy 15→25, osiągnięcia 5→25. Regionu 5 nie robić.

D. Platforma: Steam Cloud (1h!), Steam Deck Verified przed launchem (gatunek z najwyższą afinicją do Decka; schemat pada jak Balatro, fix hardcodowanych ESC/TAB), glify Aspektów (5 kolorów = podręcznikowy fail daltonizmu), lokalizacja zh-CN/ja/de/pt-BR ($2–3k za ~4k słów).

E. Sklep: hook — „Wróżka nigdy nie kłamie: zero losowości w walce — widzisz dokładne obrażenia zanim klikniesz". Capsule = jedna odwrócona, profanowana karta (zlecenie $300–800; czysty wachlarz RWS czyta się jako shovelware). Tytuł na Steam bez PARALLAXY. Cena $9.99, pełny launch, nie EA. Ścieżka: strona → demo (Regiony 1–2, klif „Księżyc czeka", profil przenosi się do pełnej gry) → Next Fest z rozegranym demo → launch. Kit streamerski: wyścig 5–10 małych twórców na wspólnym nazwanym seedzie — „determinizm czyni wyścig prawdziwie fair" to gotowy pitch.

Największe ryzyko recenzyjne: trudność (casus Wildfrost = Mixed) — bot to podłoga, nie target; Zasłonę 0 stroić pod ~40% wygranej do 3. próby u ludzi, prawdziwa gra to Zasłony 1–5.

Mówisz „start" — zaczynam od Fazy A (ceremonia proroctwa).