# Parallaxa_card

Godot **4.7** project. Clean infrastructure base derived from `parallaxa_orange` — the
settings, autoloads and shared systems, without any gameplay yet.

## What's inside

- **Project settings** from `parallaxa_orange`: input map, rendering, `canvas_items` stretch,
  GUI theme + font, localization (EN/PL).
- **Autoloads** (`src/autoload/`): `Settings`, `Localization`, `SaveManager`, `AudioManager`,
  `InputManager`, `SceneTransition`, `ScreenEffects`, `CursorManager`.
- **Addons**: PhantomCamera 0.11.x, Dialogue Manager 3.10.x.
- **Reusable core** (`src/core/`): `state_machine/`, `camera/` (camera rig).
- **Reusable UI** (`src/ui/`): `loading/`, `settings/`.
- **Assets** (`assets/`): monogram font, UI theme, cursors, CRT shader.
- **Boot scene**: `src/main/main.tscn` (empty entry point).

No combat, grid, turns, entities or levels — those live in `parallaxa_orange` and are
intentionally left out. The card game is built on top of this base.

## Run

```
godot --path .                         # run (main scene: src/main/main.tscn)
godot --headless --import              # import after adding files
tools/dev/run_hidden.sh <scene>        # run on a hidden screen (Xvfb)
tools/dev/run_hidden.sh --peek         # screenshot the hidden screen
```

See `CLAUDE.md` for the working contract and `docs/ARCHITECTURE.md` for module layout.
