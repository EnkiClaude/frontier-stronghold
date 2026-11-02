# Frontier Stronghold

A maze-building tower defense game with Factorio-style automation, made in Godot 4.
Shape the enemy route with walls and carved terrain, keep your towers supplied
with ammo from your factory, and push the frontier east.

See [PROJECT_PLAN.md](PROJECT_PLAN.md) for the full design and roadmap.

**Status:** Phase 1.5 (supply slice) complete. Build walls to shape the enemy
route, defend the Core with Chain Guns, and keep the guns loaded with ammo
mined, smelted and manufactured by your own production line.
Next: a human playtest, then Phase 2 (economy).

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

### How to play

Enemies spawn from the red nests on the east edge and walk to your Core (blue,
west edge). The **orange line** is their current route. Build walls to make
that route as long as possible, then line it with Chain Guns. You can never
fully block the route; the game rejects any placement that would. While you
hover a valid wall or tower, a **cyan line** previews the route it would create.

- You can't build, sell, move or excavate within 6 tiles of an enemy (the red circles).
- Selling refunds 85% (100% within 10 s of placing). Moving costs 10%, and the tower is offline for 3 s.
- Excavating rock (grey, speckled) opens new routes.
- An **assault** (a large wave) arrives every 2 minutes. Kills earn credits.

**Ammo supply.** Each Chain Gun holds 100 rounds and starts with 50. An empty
gun stops firing and flashes a red ✕. To keep guns loaded, build:

```
Mining Drill (on iron ore) → Belt → Inserter → Smelter → Inserter → Ammo Factory → Inserter → Belt → Inserter → Chain Gun
```

- **Drills** drop ore onto whatever is in front of them (the arrow).
- **Inserters** move one item from the tile behind them to the tile in front (the arrow). They only pick up what the target can use.
- **Belts** dragged in a line point along the drag direction. Press R to rotate before placing.
- One drill feeds roughly four busy Chain Guns.
- Belts, machines and inserters don't block enemies, and enemies never damage them.

### Controls

| Action | Default |
|---|---|
| Pan camera | W A S D / arrow keys, middle-mouse drag, two-finger trackpad swipe, or click the minimap |
| Zoom (towards cursor) | Mouse wheel, trackpad pinch, Page Up / Page Down, or the Zoom +/− buttons |
| Jump to the Core | `H` (or the Core button) |
| Select building / place (drag for lines) | Left mouse |
| Cancel tool / sell building under cursor | Right mouse |
| Build: Wall, Chain Gun, Belt, Inserter, Drill, Smelter, Ammo Factory | `1`–`7` (or the toolbar) |
| Excavate rock | `X` |
| Move / sell selected building | `M` / `Delete` |
| Rotate | `R` |
| Cancel | `Esc` |
| Pause | Space |
| Game speed up / down | `=` / `-` |
| Debug overlay | F3 |

Key bindings are stored in `user://keybindings.cfg` and can be overridden there. An in-game rebinding menu is planned.

## Building release versions

```sh
tools/export.sh            # macOS, Windows and Linux into build/
tools/export.sh macOS      # just one platform
```

Builds are named `FrontierStronghold-v<version>-<platform>`. The version lives
in `project.godot` (`application/config/version`), and every change is listed
in [CHANGELOG.md](CHANGELOG.md).

You need the Godot 4.7.2 export templates (in the editor: *Editor → Manage
Export Templates → Download*). You can also export from the editor via
*Project → Export*. The macOS build is ad-hoc signed only. The first time,
right-click the app and choose **Open** (or run `xattr -cr FrontierStronghold.app`).

## Tests and benchmarks

```sh
tools/run_tests.sh               # all unit tests (headless)
tools/run_tests.sh world_grid    # only tests whose file:method contains the filter
tools/run_benchmarks.sh          # performance benchmarks
```

The test suite includes a scripted "bot player" (`tests/scenarios/maze_scenario.gd`)
that builds a maze on a real map and plays 7 minutes. It also checks that every
script compiles. `tools/screenshot.gd` renders the game for visual checks.

Set `GODOT=/path/to/godot` if the binary is not on your `PATH`. Tests are plain
GDScript under `tests/unit/` (files `test_*.gd`, methods `test_*`, extending
`TestCase`). Neither tests nor benchmarks need any third-party add-ons.

## Project layout

```
data/            Game definitions as Godot resources (.tres): terrain, world gen ...
docs/decisions/  Architecture Decision Records (ADRs)
scenes/          Scenes (main.tscn is the entry point)
scripts/
  sim/           GameSim: the whole simulation and the player commands
  buildings/     Building instances
  enemies/       Enemy storage (structure of arrays) and spawning
  combat/        Spatial hash for targeting
  logistics/     Belt network (transport lines), drills, crafters, inserters
  core/          Fixed-tick clock, deterministic RNG, event bus, key bindings
  data/          Definition classes and the DataRegistry loader
  world/         World grid storage and procedural generation
  pathfinding/   Flow field, route validation, BFS
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
