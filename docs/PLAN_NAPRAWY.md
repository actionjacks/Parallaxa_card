# PLAN NAPRAWY PRZYJEMNOSCI — jasny i pelny

Zrodlo: docs/PLAYTEST_PRZYJEMNOSC.md (3/3 smierci przed sklepem; PARETO=2 opcje/ture; enrage i
determinizm niewidoczne; zadnych popow w pierwszych 3 runach). Plan = 5 etapow wdrazanych PO KOLEI,
kazdy z wlasnym commitem, testami i kryteriami akceptacji. Zasady bez zmian: walka w 100%
deterministyczna, podglad nigdy nie klamie, enumy append-only, teksty przez ui.csv (EN+PL),
przyciski akcji bottom-anchored, po kazdym etapie realny przeklik botem na ukrytym ekranie.

────────────────────────────────────────────────────────────────────────────
## ETAP 1 — STRUKTURA RUNU: zburzyc mur, ozywic start  [najwieksza dzwignia]

1.1 SKLEP PO KAZDEJ WALCE (kadencja Balatro).
    Flow regionu: W1 -> nagroda+sklep -> W2 -> nagroda+sklep -> BOSS (zamiast W1->nagroda,
    W2->sklep). Implementacja: run.gd `_on_combat_finished` nie-boss ZAWSZE: `_show_reward()`,
    a `_take/_skip_reward` przechodzi do `_show_shop()` (nowy krok posredni), `_leave_shop` -> step+1.
    Gwiazda: 1 na WIZYTE (bez zmian) => 2/region — kompensacja: STAR_COST 7 -> 8.
    Pliki: run.gd (flow), ui.csv (bez zmian kluczy).

1.2 WALKA 2 BEZ SCIANY: enemy_b 600 -> 460 HP, enemy_b2 660 -> 500 HP (intencje bez zmian).
    Racjonale: walka 2 ma testowac ZAKUP ze sklepu (ktory teraz poprzedza), nie karac jego braku.
    Pliki: gen_content.gd + regen .tres.

1.3 SOL ZA PORAZKE SKALOWANA WYSILKIEM: defeat = 5 + 3*fights + floor(dmg_total/150) [cap +10]
    + 2*veil. Trzy przecietne smierci daja ~36-45 Soli zamiast 24.
    Pliki: profile.gd `earn_run_reward`.

1.4 OSIAGNIECIA "PIERWSZEJ KRWI" (strzelaja w runach 1-3) + KAZDE osiagniecie placi +10 Soli:
    ACH_FIRST_WIN (wygraj 1. pojedynek), ACH_FIRST_SHOP (kup cokolwiek), ACH_FIRST_FLUSH
    (zagraj Kolor), ACH_FIRST_STAR (ulepsz uklad Gwiazda), ACH_FIRST_OMEN (przyjmij omen).
    Triggery: nowe staty runu (stat_bought, stat_flush_played, stat_star_used, stat_omen_taken)
    + sweep w check_run_achievements. grant_achievement: sol += 10 (jednorazowo, kazde).
    Pliki: run_state.gd (staty+save), run.gd (inkrementy), profile.gd, ui.csv (10 wierszy), menu (auto).

1.5 CEL SMIERCI UZYTECZNY DLA PRZEGRYWAJACEGO: nearest_goal priorytet = talie startowe (uzywalne
    od zaraz), arkana puli bossow dopiero gdy obie talie kupione. Sciezka celu spina sie z 1.3+1.4:
    talia 60 Soli osiagalna w ~3-4 smierci.
    Pliki: profile.gd `nearest_goal`.

1.6 DE-KLONOWANIE R1: pule wezlow 2 -> 3 kandydatow. Nowi wrogowie (wolne karty dworskie):
    ENEMY_PAZ_KIELICHOW (cups_11, 500 HP [9,14,9] e2, LIFE-lean) do pool_1;
    ENEMY_DZIESIATKA_MIECZY (swords_10, 560 HP [18,2,12] e3, spike) do pool_2.
    Pliki: gen_content.gd, ui.csv (2 nazwy EN/PL), regen.

AKCEPTACJA ETAPU 1: swiezy profil, 3 runy bota: (a) sklep odwiedzony w runie 1 w >=2/3 prob;
(b) >=2 osiagniecia strzelily; (c) Sol po 3 runach >= 45; (d) sklady wrogow roznia sie miedzy runami.

────────────────────────────────────────────────────────────────────────────
## ETAP 2 — KOKPIT WALKI: caly rachunek tury w jednym miejscu

2.1 WIAZKA MATMY pod podgladem zagrania (jedna linia 16px, zawsze widoczna):
    bez selekcji:  "On: 16 − blok 0 -> Ty 55 -> 39"
    z selekcja:    "Wrog: 480 -> 327   |   On: 16 − blok 4 -> Ty 55 -> 43"
    Liczby z controllera (effective_damage, intent_shown, block po zagraniu). Kolory: czesc wroga
    zielona przy LETHAL, czesc gracza czerwienieje gdy hp_after < 40% max.
    Klucze: COCKPIT_ENEMY ("Wrog: %d -> %d"), COCKPIT_YOU ("On: %d − blok %d -> Ty %d -> %d").
    Pliki: combat.gd (_update_selection_ui + _render), ui.csv.

2.2 TELEGRAF REST-TURN: gdy next_intent()==0 -> zamiast "Potem: 0" zloty pulsujacy tag
    "ODPOCZYNEK WROGA — uderz teraz" (REST_TELEGRAPH, 16px); gdy next > 1.4*current -> czerwony
    "zamierza sie" (WINDUP_TELEGRAPH). "Potem: %d" rosnie do 15px jasniejszy.
    Pliki: combat.gd (_render), ui.csv.

2.3 ENRAGE JAWNY: po 1. pelnym cyklu pod intencja linia 13px czerwona "szal: +%d/ture"
    (ENRAGE_TAG, wartosc = enrage_step + veil3 + depth). Jednorazowa linia przymierza w walce 1
    (claim_once "covenant_enrage"): "Zwloka karmi szal — po pelnym cyklu kazda tura dodaje sile."
    Pliki: combat.gd, ui.csv.

2.4 POLICZALNA SELEKCJA: przycisk "Zagraj (N)" z liczba wybranych; niewybrane karty przygaszone
    (modulate 0.82) DOPOKI cokolwiek wybrane; selekcja = ZLOTA ramka 3px (nie biala — bialo gubi
    sie na krawedziach skanow) + raise 18 -> 26.
    Pliki: combat.gd (_update_selection_ui, _refresh_card_styles), card_widget.gd (set_selected),
    hand_fan.gd (RAISE_SELECTED).

2.5 TOOLTIPY-DZIURY: relikt w walce = tr(name)+"\n"+describe() (combat.gd:1038, parytet z mapa);
    pula leczenia -> HEAL_POOL_TIP ("Wspolny limit leczenia na te walke (karty+relikty+pijawka);
    Wieza/Swiat polowia."); badge Zaslony -> VEIL_%d_DESC; licznik Talia/Grob -> DECK_TIP
    ("Talia wraca w zagranej kolejnosci — bez tasowania. Licz swoje karty.").
    Pliki: combat.gd, run.gd (badge), ui.csv.

AKCEPTACJA: zrzut walki — trzy pytania tury (ile potrzebuje / ile oberwe / co mnie kosztuje)
odpowiedziane w JEDNYM rzucie oka; test inputu bez regresji (flicker 0).

────────────────────────────────────────────────────────────────────────────
## ETAP 3 — WIEDZA W GRZE: paytable, determinizm, formuly

3.1 PAYTABLE UKLADOW (stale dostepny):
    Panel lewy w walce (pod Glupcem, kolumna ~200px, font 13): 11 ukladow "nazwa  chips x mult"
    z poziomami z RunState.hand_levels; wiersz aktualnie wybranego ukladu PODSWIETLONY zlotem.
    Przycisk-toggle "Uklady" obok pomocy (stan w Settings "gameplay/paytable", domyslnie ON
    przez pierwsze 3 runy profilu, potem zapamietany). Druga kopia: kolumna w TAB-overview.
    Pliki: combat.gd (nowy _build_paytable + refresh w _update_selection_ui), overlays.gd, ui.csv
    (PAYTABLE_TITLE + toggle), settings (klucz, bez UI — sam przycisk w walce).

3.2 PODGLAD DOBIERANIA (determinizm na wierzchu): obok licznika Talia dwie mini-karty 40x56 =
    DOKLADNIE nastepne 2 karty z wierzchu talii (controller.peek_draw(2) — nowa czysta funkcja);
    tooltip = pelne podglady. Naglowek "Nastepne:". Gdy talia pusta a grob pelny — pokazuje
    poczatek grobu (bo recykling jest deterministyczny).
    Pliki: combat_controller.gd (peek_draw), combat.gd (render), ui.csv (NEXT_DRAWS).

3.3 SOJUSZE SYMBIOZY WPROST: KWD_SYMBIOZA dopisac pary sojuszy; w RMB-inspekcji karty Symbiozy
    linia "Sojusznicy: X i Y" (Aspects.allies -> nazwy). Analogicznie KWD_BUJNOSC doprecyzowac
    ("3+ kart TEGO koloru w zagraniu").
    Pliki: ui.csv, overlays.gd (inspect: linia sojuszy).

3.4 FORMULY W HINTACH EKONOMII (zamiast golych wynikow):
    ECON_INTEREST -> "Odsetki: +%d ☿ (1 za kazde 5 ☿, max 5)";
    ECON_THRIFT   -> "Oszczednosc: +%d ☿ (1 za niewykorzystany odrzut, max 2)";
    REWARD_OVERKILL -> "Nadmiar obrazen: +%d ☿ (1 za 50 nadmiaru, max 5)".
    Pliki: ui.csv (wartosci istniejacych kluczy).

3.5 EDYCJE WIDOCZNE PRZY ZAKUPIE: w Kolekcji przycisk ulepszenia dostaje druga linie z efektem
    (ED_*_DESC); w sklepie enchant — opis pod przyciskami (stala 12px linia, nie tylko tooltip).
    Pliki: menu.gd, run.gd.

3.6 ONBOARDING WALKI 1 (jednorazowe, claim_once, po jednej linii na ture):
    t1: covenant_preview (jest) ; t2: "Odrzuty odnawiaja sie co ture." ; t3: covenant_enrage (2.3);
    t4: "Talia wraca w zagranej kolejnosci — licz karty." Kazda 3.5 s, pasmo y=505.
    Pliki: combat.gd, ui.csv, profile flags.

AKCEPTACJA: nowy gracz moze z SAMEJ GRY wyczytac: tabele ukladow, zegar szalu, limit leczenia,
porzadek talii, formuly ekonomii, sojusze — panel klarownosci przechodzi z "14 systemow
tooltip-only/nigdzie" do <=4 (sekrety celowe: Magnum, Beyond).

────────────────────────────────────────────────────────────────────────────
## ETAP 4 — UCZCIWE WYBORY: omeny, elita, mapa

4.1 OMENY BEZ FALSZYWEGO WYBORU: czyste dary (star/wheel/temperance/sun) TRACA gramatyke
    Przyjmij/Zostaw -> jeden przycisk "Przyjmij dar" (OMEN_GIFT). Prawdziwe wybory zostaja
    (hanged: HP za ☿; justice: usun karte; lovers: duplikat). NOWY omen-wybor "Kolo Fortuny"
    (przerobka wheel): "+6 ☿ ALE nastepna walka: intencje +2" vs "Zostaw" — pierwszy
    push-your-luck (flaga RunState.omen_debt konsumowana przy nastepnym starcie walki,
    deterministyczna, pokazana w intencji).
    Pliki: run.gd (_omen_block/_accept), run_state.gd (omen_debt+save), combat setup, ui.csv.

4.2 ELITA Z CENA I NAGRODA INLINE (nie w tooltipie): pod przyciskami mapy stala linia 13px:
    "Elita: %d HP, szal +%d — lup wyzszej rzadkosci" (dane z region.elite). Przycisk elity
    nieaktywny w walce 1 pierwszego regionu (odblokowany od step>=1 LUB region>=2) — fork ma
    byc zywym wyborem, nie pulapka na nowicjusza.
    Pliki: run.gd, ui.csv (ELITE_INLINE).

4.3 MAPA JAKO DROGA: miedzy chipami walk male kropki-kroki [nagroda][sklep] (ikonki ☿/karta),
    boss chip z regula pola w podtytule (rule_key skrocony). Wypelnia pustke i pokazuje
    przegrywajacemu, CO traci umierajac przed sklepem.
    Pliki: run.gd (_show_map ladder), ui.csv (MAP_STEP_REWARD/SHOP).

AKCEPTACJA: zaden ekran nie oferuje wyboru bez roznicy; elita opisana danymi; mapa pokazuje
strukture regionu jednym rzutem oka.

────────────────────────────────────────────────────────────────────────────
## ETAP 5 — NATURA I DROBNICA WIZUALNA

5.1 TWARZ KART NATURY: celowy wlasny styl zamiast "pustego placeholdera":
    tlo pionowy gradient (0.10,0.16,0.10)->(0.05,0.09,0.05), PODWOJNA ramka (zewn. zielona 2px,
    wewn. 1px jasniejsza, corner 3), centralny ornament: duzy glif rangi 34px nad stylizowanym
    pentagramem-liściem z prymitywow (3 nakladajace sie romby ColorRect obrocone 45°), keyword
    na dolnym scrimie JAK na kartach z artem (ujednolicenie jezyka layoutu).
    Pliki: card_widget.gd (_build_plain_face -> _build_nature_face).

5.2 SPOJNOSC: rangi-litery (P/R/Q/K) dostaja tooltip na plakietce; waluta w statusbarze raz
    nazwana: "10 ☿ Rtec" (pierwsze 3 runy profilu, potem samo ☿).
    Pliki: card_widget.gd, run.gd, ui.csv.

AKCEPTACJA: zrzut reki — Natura czyta sie jako STYL, nie bug; jezyk layoutu jednolity.

────────────────────────────────────────────────────────────────────────────
## WERYFIKACJA CALOSCI (po Etapie 5)
1. Testy headless: scoring+combat (rozszerzyc o: omen_debt w intencji, peek_draw, nowa Sol za
   porazke) — wszystkie zielone.
2. probe_decisions po zmianach (sklep po W1 = bot z 1 zakupem): oczekiwanie luka best-vs-second
   > 15% w >=1/3 tur (zakupione karty roznicuja opcje).
3. 3 swieze runy bota: kryteria Etapu 1 + zrzuty WSZYSTKICH ekranow (menu/draft/mapa/walka/
   nagroda/sklep/omen/spread/kolekcja/tarocista) przejrzane OKIEM.
4. BOOST przebieg do zwyciestwa + brama + Glebia 1 (regresja).
5. Wpis do ROADMAP + pamiec projektu.

## KOLEJNOSC I SZACUNKI
E1 struktura ~1 sesja | E2 kokpit ~1 sesja | E3 wiedza ~1-1.5 | E4 wybory ~0.5-1 | E5 natura ~0.5.
Kazdy etap konczony commitem "Ex: ..." z botami; zadnych zmian zasad silnika (czysta warstwa
flow/UI/liczby), wiec ryzyko regresji niskie i lokalne.
