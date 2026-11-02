# Frontier Stronghold

A maze-building tower defense game with Factorio-style automation, made in Godot 4.
Shape the enemy route with walls and carved terrain, keep your towers supplied
with ammo from your factory, and push the frontier east.

See [PROJECT_PLAN.md](PROJECT_PLAN.md) for the full design and roadmap.

**Status:** Phase 0 (Foundation) complete. Next: Phase 1 (Maze prototype).

## Requirements

- **Godot 4.7.2-stable** (standard build, not .NET). Download it from
  <https://godotengine.org/download> or the
  [godot-builds releases](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable).
- No other dependencies.

## Running the game

1. Open Godot, then **Import** and select `project.godot` in this folder.
2. Press **F5** (Run Project).

Or from a terminal (on macOS, `godot` is `/Applications/Godot.app/Contents/MacOS/Godot`):

```sh
godot --path .
```

### Controls

| Action | Default |
|---|---|
| Pan camera | W A S D / arrow keys, or middle-mouse drag |
| Zoom (towards cursor) | Mouse wheel / Page Up / Page Down |
| Pause | Space |
| Game speed up / down | `=` / `-` |
| Debug overlay | F3 |

Key bindings are stored in `user://keybindings.cfg` and can be overridden there. An in-game rebinding menu is planned.

## Tests and benchmarks

```sh
tools/run_tests.sh               # all unit tests (headless)
tools/run_tests.sh world_grid    # only tests whose file:method contains the filter
tools/run_benchmarks.sh          # performance benchmarks
```

Set `GODOT=/path/to/godot` if the binary is not on your `PATH`. Tests are plain
GDScript under `tests/unit/` (files `test_*.gd`, methods `test_*`, extending
`TestCase`). Neither tests nor benchmarks need any third-party add-ons.

## Project layout

```
data/            Game definitions as Godot resources (.tres): terrain, world gen ...
docs/decisions/  Architecture Decision Records (ADRs)
scenes/          Scenes (main.tscn is the entry point)
scripts/
  core/          Fixed-tick clock, deterministic RNG, event bus, key bindings
  data/          Definition classes and the DataRegistry loader
  world/         World grid storage and procedural generation
  pathfinding/   Grid BFS (basis of the Phase 1 flow field)
  render/        Views that draw simulation state (never modify it)
  player/        Camera and player input
  ui/            HUD and debug overlay
tests/           Unit tests and benchmarks
tools/           Helper scripts (test runners, screenshot tool)
```

## Development docs

- [DEVELOPMENT_LOG.md](DEVELOPMENT_LOG.md): what changed, milestone by milestone, with benchmark results
- [TODO.md](TODO.md): current task list
- [docs/decisions/](docs/decisions/): why the architecture is the way it is
