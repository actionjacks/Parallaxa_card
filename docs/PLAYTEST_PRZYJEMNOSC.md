# Playtest przyjemnosci — 6 osi (2026-07-27)

Metoda: 3 pelne runy realnym inputem na SWIEZYM profilu (doswiadczenie nowego gracza) + wczesniejsze
przebiegi BOOST/ELITE/BEYOND + SONDA DECYZJI (enumeracja wszystkich 218 legalnych zagran z reki co
ture, profil Pareto po osiach obrazenia/blok/lecz/przyszlosc) + panel 3 krytykow (czytelnosc /
klarownosc systemow / flow i one-more-run) czytajacy zrzuty i kod. Zero crashy i softlockow.

## Twarde liczby
- Swiezy profil, 3 runy: 3/3 smierc w WALCE 2 regionu I (tura ~4), PRZED pierwszym sklepem.
  Nieodwiedzone przy smierci: sklep, Gwiazdy, thin, enchant, boss, klaim, regiony II-IV = ~80% systemow.
- Rtec przy smierci: 7/14/12 — gracz umiera Z NIEWYDANA waluta (nie mial gdzie).
- Progres po 3 porazkach: Sol 8->16->24 (cel 40), XP 23->46->69 (poziom przy 100), osiagniecia: 0.
- Sonda decyzji (starter vs wrog R1): 218 opcji/ture, PARETO = 2, osiagalne uklady = 2-3,
  luka najlepsze-vs-drugie = 2-10%. Bot gral pare/trojke 24 tury z rzedu w 3 runach.
- Runy 1 i 2 wylosowaly IDENTYCZNY sklad wrogow (pule po 2 kandydatow).

## Odpowiedzi na 6 pytan

1. PROBLEM Z SAMA GRA (usability)? NIE mechanicznie — hover 0 flickera, drag dziala, wszystko
   klikalne, zero softlokow w 5 pelnych przebiegach. ALE pierwsza sesja konczy sie smiercia przed
   zobaczeniem sklepu — gracz "ma problem" nie z klikaniem, lecz z murem w zlym miejscu.

2. CZYTELNOSC? Polowiczna. Najlepsze elementy: preview "Trojka 51 x 3.0 = 153" + breakdown,
   stempel PRZEPOWIEDNI, spread porazki (Zguba/tura/przyczyna + Najblizszy cel + seed). Grzechy:
   - kokpit walki rozbity na 3 rogi (intencja 20px prawy-gorny, HP lewy-dol, blok srodek-dol):
     odejmowanie przetrwania w glowie po przekatnej 1280px, co ture;
   - "Potem: X" — JEDYNY haczyk planistyczny — 14px brazem na czerni (szum, nie zaproszenie);
   - WSZYSTKIE reguly w hoverze; tabeli ukladow pokerowych NIE MA NIGDZIE (gracz nie moze
     kombinowac w strone Koloru, o ktorym nie wie, ze jest punktowany);
   - karty NATURY bez artu wygladaja jak zepsute placeholdery obok skanow RWS;
   - selekcji nie da sie policzyc na oko (biala ramka vs biale krawedzie skanow w wachlarzu);
   - 5 linii ekonomii 13px na nagrodzie (odsetki/oszczednosc/nadmiar) — nikt sie z tego nie nauczy;
   - ikonografia niedekodowana: "10 <rtec>" nigdy nie nazwane, "R" na karcie, malutki Glupiec.

3. KLARNOSC SYSTEMOW? Rdzen (1 zagranie -> DOKLADNY wynik) — wzorowa. Wszystko POWYZEJ — nie:
   - ENRAGE (zabil bota 3/3!) opisany wylacznie w... tooltipie chipa Zaslony III, widzianym po
     pierwszej wygranej. Gracz widzi 4->7->11->16 i mysli "nieuczciwe", nie "stanie = smierc".
   - DETERMINISTYCZNY RECYKLING TALII (nasz USP i najglebsza zyla kombinowania — mozna LICZYC
     dobieranie!) nie jest powiedziany ani pokazany nigdzie. Gracz zaklada tasowanie.
   - Pula leczenia "15/15" bez zadnego wyjasnienia; formuly ekonomii tylko w kodzie; sojusze
     SYMBIOZY (pentagram) nienarysowane nigdzie; BUG-GRADE: tooltip reliktu W WALCE ma sama NAZWE
     (combat.gd:1038), na mapie ma opis — pasyw definiujacy run jest nieczytelny tam, gdzie dziala.

4. DUZO DECYZJI I KOMBINOWANIA W TURZE? NIE — zmierzone: 2 opcje Pareto, luka 2-10%. Tura = klik
   oczywistego maksimum. Warstwa kombinowania ISTNIEJE w kodzie (liczenie deterministycznego
   dobierania, okno rest-turn "Potem: 0", streaki Kombinatu, Furia-gate) — UI zadnej z nich nie
   ZAPRASZA. Omeny to falszywy wybor (4/6 czysty zysk -> "Przyjmij" zawsze; uczy, ze wybory sa
   dekoracyjne). Elita dla startera = samobojstwo (680HP vs sufit 153) -> jedyny fork mapy martwy
   we wczesnych runach. Realne decyzje: ~3 na 10-minutowy run (draft, nagroda, ew. odrzut).

5. SYNDROM JESZCZE JEDNEGO RUNU? Dzwignie ISTNIEJA (seed-repeat, cel, XP, 21 osiagniec, Zaslony,
   rotacja bossow, Beyond) — ale w oknie 3 pierwszych smierci NIC nie strzela: 0 osiagniec
   (najlatwiejsze wymagaja kompetencji, brak tieru "pierwszej krwi"), 0 awansow (69/100), cel 40
   Soli przy +8/smierc = 5 smierci na zakup, i to zakup-PULAPKA (Cesarz trafia do puli KLAIMU
   BOSSA — ekranu, ktorego przegrywajacy nigdy nie widzial). Jedyny zywy hak: "Powtorz ten los".

6. PROGRES W RUNIE I GLOBALNY? Struktura — tak (karty/relikty/poziomy ukladow w runie; Sol/XP/
   rangi/osiagniecia/Zaslony/Ksiega globalnie, wszystko na ekranach). TEMPO na starcie — martwe
   (patrz #5): pierwsze pol godziny bez zadnego popu.

## WERDYKT
Gra jest UCZCIWA, BOGATA i systemowo gleboka — ale pierwsze pol godziny jest nieme: gracz umiera
do niewidzialnego zegara, przed sklepem, bez zadnego popu progresu, z celem-pulapka na ekranie
smierci. Przyjemnosc nie przecieka przez UI: kombinowanie, ktore zbudowalismy, nie jest widoczne.

## REKOMENDACJE (wg dzwigni)
1. KADENCJA SKLEPU: sklep po KAZDEJ walce (kadencja Balatro) albo minimum PRZED walka 2; walka 2
   (600/660 HP) -> ~450-480. 3/3 smierci przed dotknieciem 80% systemow to blad struktury, nie balansu.
2. KOKPIT TURY: jedna wiazka matmy przy preview — "Ty: 153 (wrog 480->327) | On: 16 - blok 0 ->
   HP 55->39" zamiast trzech rogow.
3. PAYTABLE ukladow zawsze dostepny (panel boczny w walce + TAB), z podswietlonym aktualnym.
4. ENRAGE WIDOCZNY: linia "szal +N/ture" pod intencja po 1. cyklu + jedno zdanie w walce 1.
5. POKAZ DETERMINIZM: podglad 1-3 nastepnych kart talii + zdanie "talia wraca w zagranej kolejnosci";
   "Potem: 0" jako glosny telegraf REST ("UDERZ TERAZ").
6. PIERWSZE SMIERCI MUSZA PLACIC: Sol za porazke skalowana zadanymi obrazeniami; tier osiagniec
   strzelajacych w runach 1-3 (pierwsza smierc / pierwszy sklep / pierwszy Kolor); nearest_goal
   wskazuje rzecz uzyteczna dla PRZEGRYWAJACEGO (talia startowa), nie arkanum puli bossow.
7. Tooltip reliktu w walce = describe() (1 linia, combat.gd:1038) + tooltipy puli leczenia i Zaslony.
8. Omeny: prawdziwy trade-off albo bez gramatyki Przyjmij/Zostaw; elita z nagroda INLINE, nie w tooltipie.
9. Art/rama dla NATURY (5. kolor nie moze wygladac na buga).
10. Szersze pule wrogow R1 (de-klonowanie runow 1-3).
