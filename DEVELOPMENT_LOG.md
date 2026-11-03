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

## 2026-11-02 — Phase 1.5: Supply slice

### Done
- **ADR-005:** items, belts as transport lines, inserters, machines.
- **Data:** 6 items (`data/items`), 2 recipes (`data/recipes`), and 5 new
  buildings: Conveyor Belt, Inserter, Mining Drill, Smelter, Ammo Factory.
  `BuildingDef.kind` selects the behaviour.
- **`BeltNetwork`:** single-lane belts (1.875 tiles/s, 0.25 spacing).
  - Chains are merged into lines and rebuilt lazily when the layout changes.
  - Curves, side-loading, loops and back-pressure all work.
  - Items survive rebuilds; items on removed belts are lost.
- **`FactorySystem`:**
  - Drills mine the ore under them and push into the tile in front.
  - Crafters have bounded input and output buffers.
  - Inserters only pick up what the target can accept.
  - Relocated machines keep their inventories.
- **Towers use ammo:** 100-round magazine, 50 starter rounds, +10 per
  delivered magazine. Empty towers stop firing. `GameRules.infinite_ammo`
  keeps the Phase 1 behaviour for tests.
- **Views:**
  - Belts with direction chevrons.
  - Belt items drawn with a MultiMesh.
  - Inserter arm animation with the held item.
  - Drill and crafter progress.
  - Tower ammo bar and a flashing ✕ when empty.
  - Direction arrows on ghosts.
- **Controls:** keys 1–7 and toolbar buttons. Dragging belts points them along the drag.
- **HUD:** the selection panel shows ammo, crafter inputs and outputs, and what a drill is mining (or that its output is blocked).

### Bug found and fixed
- **Drag-to-place only placed one structure (Phase 1 bug).** `_commit_drag`
  cleared the dragging flag before working out the line. The bot tests used
  `GameSim` commands directly, so they never exercised the input controller.
  - Fix: compute the line before clearing the flag.
  - New `test_build_controller` drives the real controller with a simulated mouse, and fails if the bug is reintroduced.

### Testing
- 83 tests. New ones cover:
  - **Belts:** compression and spacing, curves, side-load, loops, rebuilds, filters, opposite belts.
  - **Factory:** drill needs ore, drill stalls when blocked, the inserter filter, crafting, a full chain loading a tower, relocation keeping inventory, selling a belt unregistering it, and an empty tower not firing.
  - **Controller:** drag placement, belt drag direction.
- Mutation checks: disabling belt back-pressure fails 2 tests, and the old drag bug fails 2 tests.

**Supply playtest** (`test_supply_playtest`): the same 4 Chain Guns behind a funnel wall, 6 minutes of real spawning.

| | Rounds fired | Kills | Leaked | Core |
|---|---|---|---|---|
| No supply (starter ammo only) | 200 | 33 | 20 | **destroyed** |
| Drill → smelter → ammo factory → belt → inserters | 2,892 | 230 | 5 | **7/20, survived** |

### Benchmarks (cloud Xeon; 5-run medians)

| Benchmark | Result |
|---|---|
| Belt tick, 9,950 moving items on 50 lines | 1.4–2.6 ms |
| Sim tick, 2,000 enemies + maze | 5.7–6.0 ms median, p95 9–11 ms |
| Route validation fallback | ~16 ms |
| Flow field recompute | ~17 ms over 4 ticks |

The sim tick's p95 is over the 8 ms budget on this CPU, though the median is
well inside it. It needs profiling on an M1 before deciding whether
enemy movement needs optimizing (TODO).

### Open questions for the human playtest
- Is keeping a supply line running fun, or a chore? (The Phase 1.5 question.)
- Is a 50-round starter enough to survive until the first ammo line is running?
- Are the costs right? (Drill 40, Smelter 50, Ammo Factory 60, Inserter 10, Belt 2, all in `data/buildings`.)

## 2026-11-02 — v0.2.1: first human playtest feedback

### Feedback (macOS)
1. "It zoomed all the way out and I could not zoom back in."
2. Not enough credits to wall off and build at the start.
3. Couldn't see enemies when zoomed out.
4. Wanted a resources panel and details of the selected tower (e.g. its ammo).
5. Wanted version numbers on delivered files.

### Diagnosis and changes
1. **Zoom:** I can't reproduce Mac input here. The likely causes, all fixed:
   - Every wheel event counted as a full 15% step. Trackpads and Magic Mice
     send dozens of small events per gesture, so one flick zoomed out about
     16×. Zoom now uses the event's `factor` (scroll amount).
   - Pinch (`InputEventMagnifyGesture`) and two-finger swipe
     (`InputEventPanGesture`) weren't handled. Now they zoom and pan.
   - The minimum zoom (0.08) was absurdly far out. It now stops when the map height fills the screen.
   - No HiDPI scaling. Stretch mode is now `canvas_items`, so Retina renders at the intended size.
   - Fallbacks: Zoom +/− buttons, an `H`/Core button, a clickable minimap and Page Up/Down.
   - `test_camera` sends simulated smooth-scroll, pinch and pan events, and
     checks that zooming back in from the minimum works.
2. **Balance:** start credits 400 → 1500; grace period 25 s → 45 s with an on-screen countdown.
3. **Visibility:** enemies are at least 7 px on screen, plus a minimap with red enemy dots.
4. **Panels:**
   - Left: resources, with item totals, production per minute and tower ammo.
   - Right: info for the selection or the selected tool. Towers show damage
     and type, fire rate, DPS, range, targeting, ammo type, loaded rounds,
     kills and rounds fired.
   - `BuildingDef.description` was added for every building.
5. **Versioning:** `application/config/version` drives the window title, the HUD
   and the export file names (`FrontierStronghold-v0.2.1-macOS.zip`). `CHANGELOG.md` was added.

Tests: 92 pass (new: camera input, tower stats, item totals and production, start-resource floor).

## 2026-11-02 — v0.2.2: futuristic art pass

- **Asset sources blocked.** The environment's network policy denies kenney.nl,
  kenney.itch.io, opengameart.org, ambientcg.com, polyhaven.com and
  freesound.org (HTTP 403 at the proxy). Per the asset policy, I didn't
  use unofficial mirrors. The user was told which hosts to allow.
- **Self-made placeholder set** instead, which the policy allows:
  `tools/art/generate_placeholder_art.gd` draws 25 PNGs using antialiased
  signed-distance shapes (64 px per tile). The output is deterministic, CC0
  and credited.
- **Data-driven art fields:** `TerrainDef.texture`, `BuildingDef.texture`,
  `BuildingDef.turret_texture`, `EnemyDef.texture` (tinted) and `ItemDef.icon`.
  Renderers read them through `DataRegistry.art()`, so `--no-art` (or
  `art_enabled = false`) gives the colour fallback without modifying the cached
  resources.
- **Renderers:**
  - Terrain: 64 px atlas, layer scaled 0.5, with flip variants and mipmaps.
  - Buildings: textured or fallback path, with shared status overlays. The turret rotates to `aim_angle`; belts rotate with the building.
  - Enemies and belt items: one MultiMesh per type, each with its own texture.
- **Readability checked with screenshots** (start, battle, supply, and a new
  "empty" scenario): enemies stand out, belts show direction, and empty towers
  are tinted red with a flashing ✕. Rock was brightened, and terrain colours
  were updated so the minimap matches the art.
- **Credits:** `assets/CREDITS.md` and an in-game Credits screen. `test_asset_credits` checks that:
  - every pack has a licence file and a credits entry;
  - textures live under `assets/`;
  - the tileset builds with and without art.
- 96 tests pass.

## 2026-11-02 — v0.2.3: playtest feedback #2

| Feedback | Change |
|---|---|
| Can't see items on belts | Bigger icons with a 6 px minimum. **Root cause found:** drills only output to one of their two front tiles, so a belt on the other tile got nothing. Drills now feed all front tiles in turn (`test_drill_outputs_to_either_front_tile`). |
| Belts should replace for free | Placing a belt or arm over the same kind re-orients it at no cost and keeps the items on it (`test_belt_overlap_reorients_for_free`). |
| Input/output indicators | `BuildingRenderer.draw_io` adds cyan (in) and green (out) markers, used for both buildings and ghosts. |
| A way for a belt to feed a turret and keep going | That was already the Inserter; it was renamed **Robotic Arm** and documented. `test_arm_feeds_turret_while_belt_keeps_going` shows the arm loads exactly 3 magazines and the rest continue to the end of the belt. |
| Remove the no-build rule near enemies | `no_build_radius` is now 0 by default; the rule code and its tests are kept (tests use a duplicated rules resource). |
| Spawns closer, +2 min preparation, skippable | Nests at column 115 (was 251). The generator keeps a clear zone there and guarantees a route to it. Preparation is 165 s, with `skip_preparation()`. All wave pacing counts from the end of preparation. |
| Options menu with HUD scaling | `GameSettings` autoload (saved to `user://settings.cfg`); menu with HUD scale, pan and zoom speed, routes, fullscreen. The HUD root is scaled while keeping its anchors correct. |

**Issue found and fixed:** tool scripts that reference `Hud` failed to compile,
because autoload names aren't registered yet at that point. Settings are now
accessed via `GameSettings.get_instance()`, which works everywhere.

Tests: 103 pass.

## 2026-11-02 — v0.2.4: playtest feedback #3

**Invisible enemies and belt items.** The player's screenshots showed the HUD
counting 56 enemies and 200+ factory items, the minimap showing enemy dots, and
a tracer pointing at an empty spot, but no enemies or belt items in the world.
Buildings, drawn with `draw_texture_rect`, rendered fine. Both missing layers
used `MultiMeshInstance2D` with raw buffers, which fails on the player's Mac
(Compatibility renderer) while working on the Linux test renderer. I couldn't
reproduce it here, so I switched both to the drawing path that's proven to work
on the player's machine: canvas draw calls culled to the view (ADR-006).

**Other changes:**
- Middle-click pipette (`CameraController.middle_clicked` fires when the
  middle-button press moved less than 6 px; `Q` does the same).
- Right-click swipe-sell, locked to the first axis moved
  (`BuildController.begin_sell_swipe`, `_swipe_target`).
- Activity-based input/output markers: `Building.last_in_tick`,
  `last_out_tick` and `last_out_tile` are recorded by `FactorySystem`, and
  `BuildingRenderer.draw_io(..., only_active)` fades markers over 1.5 s.

Tests: 106 pass (new: pipette, locked swipe-sell, transfer timestamps).

### 2026-11-03 — v0.2.4 confirmed on macOS
The player confirmed that enemies and belt items are now visible on their Mac.
ADR-006 (culled canvas drawing instead of MultiMesh) is verified on the target platform.

### 2026-11-03 — Playtest note
The player reports the early game is now doable with 1,500 starting credits and
the closer nests (v0.2.3 balance). No economy tweak is needed for now; revisit in Phase 2.

## 2026-11-03 — v0.3.0: towers, resources, storage, power (Phase 3 core + Phase 2 economy core)

Design: ADR-007. Summary:
- **New data:**
  - 7 items, each with a credit value; 6 recipes.
  - 5 towers with attack patterns (single, cone, splash, pulse, chain) and status effects (slow, burn, stun).
  - 10 new buildings, organised into toolbar categories.
- **Simulation:**
  - Status effects stored per enemy; armour by damage type.
  - `PowerSystem` (union-find node networks, generators that burn fuel only on demand, a satisfaction ratio).
  - Stockpile (Core + Storage), material costs and refunds.
  - Selectable crafter recipes, Recycler income, Water Pump, stone from excavation.
- **UI:**
  - Toolbar tabs, recipe button, material costs with current stock.
  - Power and stockpile sections in the resources panel; power coverage previews; power lines.
  - Distinct fallback shapes per tower, attack effects, status tints.
- **Tests:** 127 pass. New suites: `test_economy`, `test_power`, `test_towers`.
  The economy suite also checks that every item has at least one use.

**Balance probe** (`tools/balance_probe.gd`: one tower, unlimited supply, 3 minutes of waves through one gap):

| Tower | Kills | Leaks | Total cost | Kills / 100 cost |
|---|---|---|---|---|
| Chain Gun | 68 | 20 (Core died) | 100 | 68 |
| Sniper Rifle | 96 | 16 | 240 | 40 |
| Flamethrower | 94 | 1 | 190 | 50 |
| Icy Blast (support) | 44 | 20 | 160 | 28 |
| Tesla Coil | 95 | 10 | 250 | 38 |
| Lightning Tower | 98 | 9 | 350 | 28 |

After the first probe, I nerfed the Flamethrower (it held a lane alone with 0
leaks at 170 cost) and buffed the Sniper (it was overpriced). The Chain Gun stays
the most efficient per credit but can't hold alone; the special towers are
stronger but need deeper supply chains.

Benchmarks are unchanged (sim tick about 5.3 ms with 2,000 enemies).
Not yet: save/load, powered machines, Regenerator/Fast/Boss enemies, art for the new buildings.
