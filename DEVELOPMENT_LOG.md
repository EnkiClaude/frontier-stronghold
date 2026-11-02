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
