# RAPORT: petla, decyzje, buildy, szanse rynkowe (2026-07-31)

8 agentow liczacych z plikow + adwersarz przeliczajacy KAZDA liczbe. Adwersarz obalil albo
poprawil kilkanascie wartosci w pierwszym przebiegu — ponizej sa juz wersje po korekcie.
**Zasada: zadna liczba w tym dokumencie nie pochodzi z pamieci, tylko z `plik:linia`.**

---

## 1. PETLA

| co | ile |
|---|---|
| starc w runie | **6** (4 szczeble + boss + Swiat) |
| ekranow POZA walka | **21** |
| ekranow menu na jedna walke | **3,5** |
| decyzji rozgalezialnych na run | **18** surowo, ~16 po odjeciu omenow-prezentow |
| wyborow drogi (koloru) | **1** |

**Elita ZASTEPUJE szczebel, nie dokłada walki** — i w kazdym z 5 biomow ma wiecej HP niz 3 z 4
szczebli, ktore moze zastapic. "Ryzyko za lup" jest wiec twardsza walka za te sama liczbe walk, a
podpowiedz inline nie mowi, ze zastepuje szczebel o 130-230 HP lzejszy.

**Eskalacja jest liczbowo liniowa** (+99 HP na szczebel), jakosciowo trzy stany na piec starc.
Drugi run w tym samym biomie rozni sie wylacznie kolejnoscia czterech potworow i rzutem bossa.

**Nie wiadomo, ile trwa run czlowieka.** Jedyny zmierzony zegar (85 s) to bot z boostem, ktory
zabijal wrogow w pierwszej turze. W `src/` nie ma ani jednego licznika czasu rozgrywki.

---

## 2. DECYZJE W TURZE

- Reka 8 kart daje **218** legalnych zagran; w biomie Umyslu **381**, u Wisielca **1585**.
- Realnie znaczacych jest **~4** (front Pareto 1,99; w granicach 90% najlepszego 4,03).
- **Podpowiedz "W rece: <uklad>" pokrywa sie z maksymalnymi obrazeniami w 98,9%** rak. Gra
  rozwiazuje wlasna zagadke za gracza.
- Uzywane sa **4,12 z 13** typow ukladu; cztery gorne wiersze tabeli wyplat to dekoracja
  (Kolor 1,7%, Kareta 2,8%, Poker 0,16%, Piec 0,07%), a **MAGNUM OPUS jest niemozliwy z definicji
  puli kart** — i ciagnie za soba niezdobywalne osiagniecie.
- **Odrzut to najsilniejsza os tury i NIE jest decyzja**: trzy darmowe klikniecia na ture, z gory
  wiadomo, ze nie pogarszaja. ~54 puste klikniecia na run. Naprawa nie polega na dosypaniu
  informacji, tylko na nadaniu odrzutowi KOSZTU.
- Dwie najciekawsze geometrie tury (Krzyz Celtycki, Rozklad Trzech Kart) sa zamkniete za
  losowaniem bossa — wiekszosc graczy nie zobaczy ich nigdy.

**Co dziala:** wybor zestawu kart daje **+117%** obrazen nad naiwnym zagraniem (mnoznik, nie
procenty). Bonus precyzji faktycznie ozywil os "ile kart" (bez niego: twarde **0,000%**).
Zwornik wart jest **+14,7%** obrazen — czyli Zaslona IV-V zabiera ~15%, nie 8%, jak sadzilem.

---

## 3. BUILDY

18 slow kluczowych na 181 kartach, ale **tylko 5 grup ma >=3 karty w puli nagrod**. Rozklad:
ECHO 10, Bujnosc 7, Gnicie 7, Furia 6, Spalenie 6 ... Przeciazenie 2, Ofiara 2, Wrozba 2,
Korzenie 2, Klatwa 2.

Run daje **4 sklepy** i **5-8 dokupionych kart**; talia rosnie z 40 do 49-51 (startery
reaper/gardener/oracle maja 31 kart, wiec rosna do 40-42 — o ~20% wieksza gestosc archetypu).
Realnie gracz sklada **jeden archetyp, w okolo dwoch kopiach**.

**Najwieksza dziura balansowa nie jest brakiem kart.** Reroll sklepu za 1 Rtec podwaja liczbe
widzianych slotow — czyli roznica miedzy graczem swiadomym a nieswiadomym to **2x gestosc
archetypu**, i nikt tego mechanizmu nie wycenil.

Biom Umyslu jako jedyny nie ma zadnego mnoznika swojego koloru w `boss_pool`.

---

## 4. RYNEK

### Wyroznik (realny)
Piec Aspektow zamiast czterech kolorow to **3,8x** wieksza przestrzen kombinatoryczna, znaczaca
kolejnosc kart i **zero losowosci w walce**. To jest prawdziwy, policzalny haczyk, ktorego nie ma
zaden konkurent gatunku.

### Steam
Kod GRY istnieje, kod WYDANIA nie istnieje: **0 linii Steamworks**, brak `export_presets.cfg`,
**80 s muzyki**, **2 jezyki**, 102 asercje w testach. Gotowe i realne: Zaslony 1-5, Dzienny Los,
seedy i share-stringi, 25 (nie 26) zdobywalnych osiagniec, Ksiega Odczytan.

### Android
- **Karty przechodza norme dotyku z duzym zapasem.**
- **Zaden przycisk jej nie przechodzi**: wszystkie 10 przyciskow z jawna wysokoscia jest ponizej
  48 dp; najwiekszy ma **26,1 dp (54% normy)**, a pasek z "Zagraj" — **34,6%**.
- **Zero handlerow dotyku** w calym `src/`. 18 miejsc w samej scenie walki dziala na hover, ktorego
  na telefonie nie ma.

### Trzy ryzyka
1. **Gra rozwiazuje wlasna zagadke** (podpowiedz + tabela + dokladny podglad = 98,9%).
2. **62,7% zmapowanej tresci taktycznej jest slaba albo martwa.**
3. **Brak calej warstwy wydawniczej.**

### Trzy atuty
1. **Determinizm** — sprawdzony w kodzie, nie w opisie; to jedyna karcianka gatunku, w ktorej
   podglad jest kontraktem.
2. **Meta gotowa** — Zaslony, Sol, Dzienny Los, Ksiega, osiagniecia.
3. **Kultura audytu** — piec znalezionych i naprawionych precedensow "mechanizm bez dzialania".

---

## 5. WERDYKT

**Hit na Steam: mozliwy, ale nie w tym stanie.** Rdzen jest lepszy niz jego prezentacja — problem
nie polega na braku tresci, tylko na tym, ze gra oddaje graczowi odpowiedz. Trzy zmiany o
najwyzszej dzwigni, w kolejnosci:
1. **Zabrac podpowiedz albo dodac druga os punktacji** (blok/leczenie/Gnicie prawie nigdy nie
   konkuruja z obrazeniami).
2. **Nadac odrzutowi koszt** — 54 puste klikniecia na run to najwiekszy pojedynczy ubytek napiecia.
3. **Wyciac albo naprawic martwa tresc**: MAGNUM OPUS, niezdobywalne osiagniecie, gorne wiersze
   tabeli wyplat.

**Android: NIE bez osobnego przebiegu UI.** To nie jest port, to przeprojektowanie warstwy
wejscia: kazdy przycisk ponizej normy, zero obslugi dotyku, informacja schowana pod hoverem.
Sesja (6 walk) pasuje do mobilnej, wiec praca jest oplacalna — ale to praca, nie eksport.
