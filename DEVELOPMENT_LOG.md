# Development Log

## 2026-11-02 — Phase 0: Foundation

### Done
- Godot 4.7.2 project with the GL Compatibility renderer (ADR-001).
- **Simulation core:** `SimClock` (fixed 30 Hz tick, 1x/2x/3x speed, pause,
  catch-up cap), `SimRng` (seeded, with named independent streams), `Events`
  autoload for loose notifications.
- **Input:** `Keybinds` autoload registers every input action in code and loads
  user overrides from `user://keybindings.cfg`. Uses physical keys, so the
  layout is the same on AZERTY/QWERTZ keyboards.
- **Data-driven definitions:** `TerrainDef`, `WorldGenConfig` and `OreSpawn`
  resources in `data/`. `DataRegistry` validates them (unique ids and codes,
  valid references) and builds lookup tables for hot loops (ADR-003).
- **World grid:** a flat, column-major packed array, so the world can grow east
  without re-indexing (ADR-002).
- **World generation:** a 256×160 frontier strip with noise-based rock and
  water, bedrock borders, clear Core and nest zones, guaranteed starter patches
  of iron, copper, coal and stone, and a guaranteed west→east route (a tunnel
  is carved if needed). It's deterministic per seed.
- **Rendering:** a `TileMapLayer` with a generated placeholder tileset (no art
  assets yet).
- **Camera:** WASD/arrows, wheel zoom anchored at the cursor, middle-mouse
  drag, clamped to the map.
- **Debug overlay (F3):** FPS, speed, tick timing, world size and generation
  time, zoom, hovered tile.
- **Tests:** a headless runner plus 25 unit tests (clock, RNG, grid, registry,
  BFS, world generation: determinism, borders, starter ores, route guarantee
  across 8 seeds and a forced fully-rocky map).
- `tools/screenshot.gd` renders the game under a virtual display for visual
  checks.

### Benchmarks (cloud Xeon 2.8 GHz, headless; expect an M1 to be faster)

| Benchmark | Median |
|---|---|
| World generation 256×160 | 81 ms |
| BFS distance field, full map (40,960 tiles) | 17 ms |
| BFS distance field, 8-sector map (163,840 tiles) | 86 ms |
| 1M reads via `get_terrain()` | 369 ms |
| 1M direct packed-array reads | 59 ms |

### Findings that change the plan
- **A full-map BFS in GDScript (17 ms) is over the 5 ms budget.** So for Phase 1:
  - The flow field must not be fully recomputed on every placement.
  - Placement validation uses the planned *local neighbour check* first.
  - Recomputes are batched and time-sliced across ticks.
  - If that's still not enough, the BFS (about 60 lines) is the first
    candidate for GDExtension (C++).

  This needs an ADR before Phase 1 pathfinding is implemented.
- **Method calls cost about 6× more than direct array reads.** Hot loops must
  read the packed arrays directly (as `Reachability` does) instead of calling
  `get_terrain()` per tile.

### Acceptance check (Phase 0)
- [x] Project runs; camera works on a large map (verified by screenshot under Xvfb)
- [x] Tests run headlessly (25/25 pass)
- [ ] Manual camera "feel" test on macOS (needs a human with a mouse)

## 2026-11-02 — Phase 1: Maze prototype

### Done
- **ADR-004:** flow-field pathing and two-stage route validation (written before
  implementation, using the Phase 0 benchmark numbers).
- **`GameSim`:** the whole simulation is plain data with player commands
  (`place`, `sell`, `relocate`, `excavate`). Each returns "" or a readable
  reason. It is deterministic: the same seed and commands give the same state
  hash (tested).
- **Pathing (`PathMap`):**
  - Separate `passable` and `plan_passable` layers, so pending walls count for validation but not yet for movement.
  - Time-sliced BFS flow field (node budget, so it stays deterministic).
  - 8-directional movement with no corner cutting.
  - Local "simple tile" validation with a full-BFS fallback. Living enemies must stay connected, so they can't be trapped.
- **Core and nests:** the Core is 3×3 at the west edge with 20 HP. Two nests sit on the east edge. Both have protected build-free buffers.
- **Buildings (data-driven):** Stone Wall (5 credits, 1 s build) and Chain Gun (2×2, 100 credits, 2 s build). Walls only block the path once complete *and* no enemy is standing on them.
- **Anti-juggling:**
  - No build, sell, move or excavate within 6 tiles of an enemy.
  - Build times.
  - No gates.
- **Sell / relocate:**
  - Selling refunds 85% (100% inside a 10 s undo window).
  - Moving costs 10% and the tower is offline for 3 s.
  - Refunds are based on total invested value.
- **Excavation:** rock becomes ground after 2 s (15 credits) and opens routes.
- **Enemies:** stored as structure of arrays.
  - Swarmer (fast, weak).
  - Armoured Crawler (slow, armour 3, unlocks at 1:30).
  - HP grows 8% per minute.
  - Continuous trickle plus an announced assault every 2 minutes that grows each time.
- **Chain Gun:** hitscan, "first" targeting (closest to the Core along the
  route), sticky targets, spatial-hash queries, armour (minimum 20% damage).
- **Views:**
  - Enemies are drawn with MultiMesh buffers and interpolated between ticks, with health bars.
  - Buildings show construction and redeploy progress bars and the Core HP bar.
  - Tracers for shots.
  - Route lines are drawn beneath enemies.
- **Build controller:**
  - Ghosts (green/red) with the reason shown in the hint bar.
  - Drag-to-place lines.
  - Tower range circles.
  - Live route (orange) and a "what if" route (cyan) for the hovered placement.
  - No-build radius circles.
  - Select, sell and move.
- **HUD:** credits, Core HP, enemies, kills, assault countdown, game time,
  speed; toolbar buttons (touch-ready); selection panel with Sell/Move; toasts;
  game-over screen with Restart.
- **Export presets** for macOS (universal, ad-hoc signed), Windows and Linux, plus `tools/export.sh`.

### Testing
- 60 headless tests, including:
  - pathing and validation edge cases;
  - every command rule;
  - determinism;
  - a bot playtest on a real generated map;
  - a test that loads every script and scene.
- Mutation-checked: breaking the simple-tile test or the corner rule makes tests fail.
- `tools/run_tests.sh` now also fails on any engine script or parse error. The
  first version missed two type-inference errors in UI code; that's fixed, and
  `test_all_scripts_compile` was added.

**Bot playtest (seed 4242):**
- A 4-wall serpentine stretches the route from **247 to 748 tiles**.
- With 24 Chain Guns, 7 minutes (3 assaults) gives 149 kills, 0 leaks and a full-HP Core.
- Undefended, the Core falls at **3:56**.

### Benchmarks (cloud Xeon 2.8 GHz)

| Benchmark | Result |
|---|---|
| Sim tick: 2,000 enemies, 45 towers, 653 structures | 5.6 ms median, 8.4 ms p95 (budget 8 ms) |
| Placement check (fast path) | 0.06 ms |
| Route validation, full-BFS fallback | 16.7 ms (once per placement, only when needed) |
| Flow field recompute | 17 ms spread over 4 ticks (~4.3 ms/tick) |

`flow_nodes_per_tick` was lowered from 12,000 to 8,000 to stay under about 5 ms per tick.

### Known limitations / for playtesting
- **Balance is untested by a human.** The starting credits (400), kill rewards and
  spawn rates are first guesses, all in `data/rules/` and `data/enemies/`.
- Enemies travel in near single file (small random offsets, no separation).
- A route change waits for the next flow-field swap (about 0.1 s).
- The "what if" preview isn't shown while moving a building.

### Acceptance check (Phase 1)
- [x] The player can build a maze, enemies follow it, and towers eliminate them (bot playtest + screenshots)
- [x] Illegal full blocks are rejected; juggling is prevented by the no-build radius
- [x] Selling and relocation work with the agreed costs
- [ ] Human playtest on macOS (needs you, at a computer)
- [ ] Playable desktop builds exported (see below)
