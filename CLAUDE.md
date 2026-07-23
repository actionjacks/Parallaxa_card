# Parallaxa_card — zasady pracy

Projekt Godot **4.7**. Ten plik jest kontraktem pracy: obowiazuje przy kazdej zmianie.
Kontrakt techniczny (uklad modulow) jest osobno: **`docs/ARCHITECTURE.md`** — czytaj go PRZED
dodaniem nowego modulu i aktualizuj w tym samym commicie, jesli zmieniasz publiczne API.

Baza pochodzi z `parallaxa_orange` — to CZYSTA infrastruktura (ustawienia, autoloady, addony,
theme, lokalizacja) bez gameplayu. Gameplay karcianki budujemy tutaj od zera.

## Zasady (obowiazkowe)

1. **Commituj i pushuj po sensownej pracy.** Repo: `https://github.com/actionjacks/Parallaxa_card.git`,
   branch `main`. Commit ma opisywac CO i DLACZEGO, nie tylko "fix". Nie zostawiaj pracy tylko lokalnie.
2. **Wszystko w folderze projektu.** Zadnych plikow roboczych poza repo. Zero Artefaktow/Artifacts —
   dokumentacja, analizy i notatki ida do `docs/` w tym repo.
3. **Zrzuty ekranu do `screenshots/`** (folder jest w .gitignore — sluzy do przegladu, nie do commitu).
4. **Testy na ukrytym ekranie.** Gra do testow nie moze wyskakiwac na monitor uzytkownika — uruchamiaj
   przez `tools/dev/run_hidden.sh` (Xvfb). Flagi: `--peek` (zrzut biezacej klatki) i `--stop`.
5. **Nie zgaduj — sprawdzaj.** Przed zmiana czytaj kod; po zmianie uruchom import i potwierdz, ze
   projekt startuje bez bledow. Przy zmianach wygladu zrob zrzut i OBEJRZYJ go — "kod wyglada dobrze"
   nie jest dowodem, ze cos sie renderuje.
6. **KOD I KOMENTARZE PO ANGIELSKU.** Nazwy klas, zmiennych, funkcji, plikow, sygnalow, kluczy
   tlumaczen i komentarzy — wszystko po angielsku, ASCII-safe. Rozmowa z uzytkownikiem i ten plik:
   po polsku. Teksty dla GRACZA nie sa hardkodowane — ida przez klucze tlumaczen (`data/locale/ui.csv`),
   gdzie kolumna `pl` ma normalna polszczyzne z diakrytykami.
7. **Rownolegli agenci nie uruchamiaja Godota.** Cache `.godot/` jest wspolny i rownolegle importy go
   uszkadzaja. Import i testy robi jeden proces integrujacy.

## Struktura

| Folder | Po co |
|---|---|
| `src/autoload/` | globalne menedzery (Settings, Localization, SaveManager, AudioManager, InputManager, SceneTransition, ScreenEffects, CursorManager) |
| `src/core/` | klocki wielokrotnego uzytku, niezalezne od gameplayu (`state_machine/`, `camera/`) |
| `src/main/` | scena startowa (`main.tscn` = main scene) |
| `src/ui/` | interfejs (`loading/`, `settings/`) |
| `data/` | TRESC jako dane: `locale/` (ui.csv + kompilaty tlumaczen) |
| `assets/` | surowe assety: `fonts/`, `ui/` (theme, kursory), `shaders/` (crt), `audio/`, `models/`, `textures/` |
| `tools/` | `dev/` skrypty uruchomieniowe |
| `tests/` | testy headless |
| `docs/` | `ARCHITECTURE.md` + analizy i decyzje |
| `addons/` | PhantomCamera, Dialogue Manager (nie edytowac recznie) |

**Zasada podzialu:** kod w `src/`, TRESC w `data/`, surowe assety w `assets/`.

## Addony

- **Phantom Camera 0.11.x** — rig kamery. Wzor: jedna `Camera3D` + `PhantomCameraHost` (DZIECKO
  kamery) + `PhantomCamera3D`. **Bez `look_at_mode` + `look_at_target` ekran jest czarny** — kamera stoi
  dobrze, ale patrzy w pustke. Przy dziwnym zachowaniu kamery to pierwszy podejrzany.
- **Dialogue Manager 3.10.x** — dialogi `.dialogue` w `data/dialogue/`. Autoload `DialogueManager`.

Oba sa wpisane w `project.godot` recznie (`[editor_plugins] enabled` + `[autoload]`). Wlaczenie ich
jeszcze raz klikiem w edytorze dopisze autoload DRUGI raz — wtedy usun duplikat.

## Uruchomienie

```
godot --path .                              # gra (main scene: src/main/main.tscn)
godot --headless --import                   # import po dodaniu plikow
tools/dev/run_hidden.sh <scena>             # uruchomienie na UKRYTYM ekranie
tools/dev/run_hidden.sh --peek              # zrzut -> screenshots/hidden_preview.png
```

Rozdzielczosc bazowa 1280x720, `canvas_items` + `expand`, filtr tekstur NEAREST (pod pixel-art).
Wysokosc okna powinna byc calkowita wielokrotnoscia bazy pixel-art, inaczej obraz migocze.

## Pulapki, ktore juz nas kosztowaly czas (dziedziczone z bazy)

- **Materiał mnozy `albedo_texture` przez `albedo_color`.** Ciemny kolor-zastepczy zostawiony po
  podpieciu tekstury = czarna powierzchnia. Po podpieciu tekstury tint wraca na bialy.
- **`Basis(...)` przyjmuje WIERSZE, a osie to KOLUMNY.** Liczenie kierunku swiatla z wierszy daje zly
  wynik; slonce swiecace w gore nie oswietla niczego. Sprawdzaj znak `-basis.z.y`.
- **Nie uzywaj `pkill -f <wzorzec>`, jesli wzorzec pasuje do wlasnej komendy** — zabija wlasna powloke.
- Godot 4.4+ generuje pliki `*.uid`. **Musza byc commitowane.**
- **Godot NIE zglasza bledu formatowania tlumaczen przez wyjatek — oddaje szablon BEZ ZMIAN.** Wiersz
  z inna liczba `%d` niz przekazuje kod nie wyglada na zepsuty: na ekranie pojawia sie doslowne `%d`.
  Pilnuj parzystosci `%` miedzy kolumnami en i pl.
