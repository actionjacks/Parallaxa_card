# Raport balansu — 7 pelnych przeklikow bota (2026-07-30)

Wygenerowane przez `tools/dev/balance_report.py` z logow w `screenshots/balance/`.
Bot jest CELOWO slaby: grupuje karty po randze i nie szuka stritow ani kolorow,
wiec rozklad ukladow mowi, co dostaje gracz grajacy NAJPROSTSZA heurystyka —
nie jaki jest sufit gry.

```
==================================================================
RAPORT BALANSU — z prawdziwych przeklikow bota
==================================================================
  boost        VICTORY  walk=6   tur/walke=1.3  odrzutow=5    biom=Sad Kielichów
  elite        DEFEAT   walk=5   tur/walke=3.2  odrzutow=23   biom=Sad Kielichów
  vanilla_1    DEFEAT   walk=4   tur/walke=3.4  odrzutow=17   biom=Sad Kielichów
  vanilla_2    DEFEAT   walk=5   tur/walke=3.7  odrzutow=23   biom=Sad Kielichów
  vanilla_3    DEFEAT   walk=5   tur/walke=4.8  odrzutow=36   biom=Sad Kielichów
  vanilla_4    DEFEAT   walk=5   tur/walke=3.5  odrzutow=31   biom=Sad Kielichów
  vanilla_5    DEFEAT   walk=5   tur/walke=3.0  odrzutow=26   biom=Sad Kielichów

-- UKLADY, ktore bot REALNIE zagral (134 zagran) --
   Trójka              81.34%   (109)
   Kareta              10.45%   (14)
   Para                 5.97%   (8)
   Kolor                1.49%   (2)
   Pięć jednakowych     0.75%   (1)

-- OBRAZENIA na zagranie --
   p05=104  mediana=207  p95=1386  max=3188   rozrzut p95/med=6.70x

-- DLUGOSC WALKI (tury) --
   min=1  mediana=3  max=7  srednia=3.3

-- KOSZT WALKI w HP (wejscie minus wyjscie) --
   mediana=12  p90=39  max=41   (gracz ma 55 HP)
   walk bez strat: 22%

-- ZAKONCZENIA --
   DEFEAT    6/7
   VICTORY   1/7
   walk wygranych: min=4 mediana=5 max=6
```
