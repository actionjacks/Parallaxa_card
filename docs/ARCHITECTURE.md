# Architecture — Parallaxa_card

Clean infrastructure base derived from `parallaxa_orange`. This document lists what the base
provides and where new gameplay hangs off it. Update it in the same commit whenever a module's
public API changes.

## Boot

- `run/main_scene = res://src/main/main.tscn` — an empty `Node` (`src/main/main.gd`). It exists so
  the project runs; the card game replaces or wraps it.

## Autoloads (`src/autoload/`)

Registered in `project.godot` under `[autoload]`, order matters (later ones may read earlier ones):

| Autoload | File | Responsibility |
|---|---|---|
| `Settings` | `settings_manager.gd` | user settings, persisted; source of truth for audio/display/input prefs |
| `Localization` | `localization.gd` | locale switching over `data/locale/` translations |
| `SaveManager` | `save_manager.gd` | save/load slots to disk |
| `AudioManager` | `audio_manager.gd` | bus volumes, SFX/music playback |
| `InputManager` | `input_manager.gd` | reads the input map, exposes high-level input intent |
| `SceneTransition` | `scene_transition.gd` | fade/swap between scenes |
| `ScreenEffects` | `screen_effects.gd` | CRT shader (`assets/shaders/crt.gdshader`) on a CanvasLayer + color grade; missing WorldEnvironment is warned and skipped |
| `CursorManager` | `cursor_manager.gd` | swaps hardware cursors from `assets/ui/cursors/` |

Plus addon autoloads: `PhantomCameraManager`, `DialogueManager`.

## Reusable core (`src/core/`)

- `state_machine/` — generic `State` / `StateMachine` nodes (see `state_machine/README.md`).
- `camera/camera_rig.gd` — `Node3D` camera rig helper (pairs with PhantomCamera).

## Reusable UI (`src/ui/`)

- `loading/loading_indicator.tscn` — spinner/progress widget.
- `settings/settings_menu.tscn` — settings menu bound to the `Settings` autoload.

Theme: `assets/ui/theme/ui_theme.tres` (set as `gui/theme/custom`), font `monogram-extended.ttf`.

## Data (`data/`)

- `locale/ui.csv` (+ compiled `ui.en.translation`, `ui.pl.translation`). Player-facing text goes
  through translation keys, never hardcoded.

## Not included (lives in parallaxa_orange)

Combat, grid, turn system, entities (player/enemy/dummy), levels (sandbox/arena), combat HUD.
These were intentionally left out — the card game defines its own gameplay modules here.
