# Frontier Stronghold — Project Plan

> Revision 2 · 2026-11-02
> Status: Pre-production (Phase 0 not started)

---

## 1. Project Objective

Build a real-time **maze-building tower defense** game with Factorio-style construction and automated production.

The player protects a **Core** at one end of the map. Enemies pour out of nests at the far end and walk toward it. The player decides the route they take by placing walls and carving the terrain. Defenses work only while the factory keeps them supplied with ammunition, fuel, coolant and power. Each nest the player neutralizes pushes the frontier further out, revealing richer resources and stronger enemies.

### Design Pillars

Every feature is judged against these, in priority order:

1. **The path is the puzzle.** Shaping the enemy route with walls and terrain is the main skill and the main thing that sets this game apart. A feature that weakens mazing doesn't ship.
2. **Logistics is defense.** Towers depend on supply lines. A broken belt during an assault is a crisis, not an inconvenience.
3. **Readable cause and effect.** The player can always see where enemies will walk, why a tower is idle, and what's starving the factory.
4. **Push the frontier.** Progress is spatial: clear nests, expand, and dig deeper into a harder world.

### Core Loop

```
EXPLORE → MINE → AUTOMATE → SUPPLY → MAZE & DEFEND → NEUTRALIZE NESTS → EXPAND → RESEARCH → REPEAT
```

### Differentiation

| Game | What it does | What we do differently |
|---|---|---|
| Mindustry | Automation + TD; enemies attack buildings | Enemies only target the Core; **the maze is the player's main tool** |
| Factorio | Automation; biters attack everything | Defense is a pathing puzzle, not a wall of turrets |
| They Are Billions / Riftbreaker | Base building vs hordes | Grid mazing, terrain carving, ammo logistics |
| Classic maze TDs (WC3, Desktop TD) | Pure mazing | Persistent, expanding world with a real economy feeding the towers |

---

## 2. Technology

| Area | Decision |
|---|---|
| Engine | Godot 4.x, pinned to the latest stable release at project start (version recorded in README) |
| Language | GDScript, written in a data-oriented style. Hot paths are isolated so they can move to GDExtension (C++) **only if profiling demands it**. No C#, because of iOS export constraints. |
| Dev platform | macOS (Apple Silicon) |
| Targets | macOS, Windows, Linux. iOS/iPadOS later. |
| Rendering | 2D top-down; optional 2.5D effects (shadows, height shading, particles) |
| Input | Keyboard and mouse through an action layer, ready for touch later |
| Version control | Git, one commit per working milestone |
| Dependencies | None at runtime. Tests use a small in-house headless runner; gdUnit4 is added only if that runner becomes limiting. |

---

## 3. World & Map Layout

### Frontier strip

- The map is a horizontal **strip**: fixed height (starting at about 160 tiles) and a length that grows as sectors unlock.
- The **Core** sits at the west edge. **Nests** spawn in the active sector at the east edge.
- The world is split into **sectors** (for example 160 × 128 tiles), and each sector into **chunks** of 32 × 32 tiles.
- Neutralizing every nest in the active sector unlocks and generates the next sector further east, with harder enemies and rarer resources.
- Enemies from the active frontier walk across every earlier sector to reach the Core. The maze can therefore extend across the whole map, and old sectors stay relevant as defense in depth. Because enemies never attack structures, older sectors also serve as safe industrial zones.
- The strip's top and bottom edges are indestructible bedrock.

### Terrain types

| Tile | Walkable | Buildable | Destructible | Notes |
|---|---|---|---|---|
| Ground | ✔ | ✔ | — | Default |
| Rock | ✘ | ✘ | ✔ (mine / blast) | Becomes Ground plus Stone when removed |
| Ore-in-rock | ✘ | ✘ | ✔ | Yields ore when removed, then becomes Ground |
| Ore deposit (surface) | ✔ | Drills only | — | Node-based extraction |
| Water | ✘ | ✘ | — | Can be bridged or filled later (backlog) |
| Bedrock | ✘ | ✘ | ✘ | Map frame and fixed obstacles |

### Destructible terrain and walls (key mechanic)

All destruction is **player-driven**. It's the second half of mazing.

- **Excavation:** an Excavator building removes adjacent rock over time and yields stone or ore. This lets players open new corridors.
- **Demolition charges:** a crafted, consumable item that clears a 3×3 area of rock instantly, at a cost.
- **Walls:** a cheap, fast way to *close* routes. They come in tiers (Stone → Concrete → Reinforced) that gate how large a maze you can afford.
- **Terrain vs walls:** rock is free blocking that you can only remove. Walls are blocking you pay for and can move. Good players sculpt with both.
- Mined-out tiles become walkable ground, so mining shapes the maze. This creates a deliberate tension between economy and defense.
- *Backlog (later phases):* a **Burrower** enemy that tunnels through **rock only**, never through player structures, as a telegraphed late-game twist. Requires design sign-off.

### Path rules

- Enemies path to the Core across Ground and surface ore tiles.
- **Blocking:** walls, towers, rock, water and bedrock.
- **Non-blocking:** belts, inserters, pipes, power poles and other logistics or production buildings. Enemies walk over or through them and never damage them.
- There must **always** be at least one valid route from every active nest to the Core. A placement or removal that would break this is rejected, and the preview turns red.
- **Gates are removed** from scope. Without player units they would only serve the toggle exploit.

---

## 4. Economy

### Resources

**Raw resources**

| Tier | Resources | Unlock |
|---|---|---|
| 1 | Iron ore, Copper ore, Stone, Coal | Start |
| 2 | Sand, Titanium ore | Sector 2+ |
| 3 | Uranium ore, Rare crystals | Sector 4+ |
| 4 | Exotic matter | Late frontier (design TBD) |

**Intermediates (crafted)**

Iron plate, Copper plate, Copper wire, Steel, Bricks, Concrete, Glass, Circuits (electronics), Titanium alloy, and further items as needed.

**Build priority:** Tier 1 and Tier 2 ship first. Tiers 3 and 4 are designed later, against real playtest data.

### Systems

- Mining drills on ore deposits, plus the Excavator for terrain mining
- Conveyor belts (two lanes) and inserters
- Storage
- Smelting and manufacturing using data-defined recipes
- Electricity: generators, poles and networks, with brown-out when demand exceeds supply
- Ammunition production

### Ammunition and supply (the integration hook)

Every tower consumes a supply type, delivered by belt and inserter or by power network:

| Tower | Supply | Variants (data-driven) |
|---|---|---|
| Chain Gun | Bullets | Standard, Armour-piercing, Incendiary |
| Sniper Rifle | Rifle rounds | Standard, AP, Explosive |
| Flamethrower | Fuel canisters | Standard, Napalm |
| Icy Blast | Coolant canisters | Standard, Cryo |
| Tesla Coil | Electricity | — (tuned by power draw) |
| Lightning Tower | Electricity | — |

- Each tower has a small internal buffer (a magazine). An empty tower stops firing and shows a clear "no ammo" or "no power" icon.
- Ammo variants change damage type or status effects, not just damage numbers.
- Before the economy exists (Phase 1), towers use infinite ammo behind a debug flag.

---

## 5. Buildings

| Building | Blocks path | Purpose |
|---|---|---|
| Core | ✔ | Enemy target; starter storage; game over if destroyed |
| Mining drill | ✘ | Extracts surface deposits |
| Excavator | ✘ | Removes adjacent rock or ore-in-rock |
| Conveyor belt | ✘ | Item transport |
| Inserter | ✘ | Moves items between belts, buildings and towers |
| Storage | ✘ | Buffer |
| Smelter | ✘ | Ore → plates |
| Assembler | ✘ | Recipes |
| Ammunition factory | ✘ | Ammo, fuel and coolant recipes |
| Generator / power pole | ✘ | Power network |
| Research lab | ✘ | Consumes research packs |
| Repair station | ✘ | Heals the Core over time and repairs walls that terrain events affect (later) |
| Suppressor | ✘ | Nest-neutralization objective (Phase 5) |
| Walls (tiers) | ✔ | Maze building |
| Towers | ✔ | Defense; towers are part of the maze |

All buildings have data-defined costs, footprints, rotation and placement rules.

---

## 6. Towers

| # | Tower | Range | Targeting | Damage profile | Role |
|---|---|---|---|---|---|
| 1 | **Chain Gun** | Medium | Single target | Moderate damage, high fire rate, Kinetic | Light enemies, swarm cleanup |
| 2 | **Icy Blast** | Short–medium | Cone or area | Low damage, Cold, **Slow** | Control; amplifies everything else |
| 3 | **Flamethrower** | Short | Cone | Moderate damage, Fire, **Burn** over time | Swarms, Regenerators (burn suppresses regen) |
| 4 | **Tesla Coil** | **Short** | **Pulse around itself**, hits all enemies in radius | Moderate damage, Electric, **Shock** (brief stun) | Choke-point defense; place at maze corners |
| 5 | **Lightning Tower** | **Long** | Single strike that **chains** to nearby enemies | High damage, Electric, Shock | Clustered enemies at range |
| 6 | **Sniper Rifle** | Very long | Single target | Very high damage, slow fire rate, Armour-piercing | Armoured enemies and bosses |

- **Targeting priorities** (per tower, player-configurable): First, Last, Strongest, Weakest, Closest, Most armoured.
- **Upgrade paths:** each tower has two branches of three tiers each (data-defined). Choosing a branch locks the other for that tower, so every placement is a meaningful specialization.
- **Damage types:** Kinetic, Fire, Cold, Electric, Armour-piercing.
- **Status effects:** Slow, Burn, Shock (stun / interrupt), Brittle (Cold + Kinetic synergy, introduced in Phase 3 or 4).

---

## 7. Enemies

| Enemy | Traits |
|---|---|
| **Swarm** | Weak, cheap, very numerous |
| **Armoured** | High armour, slow; weak to Armour-piercing and Electric |
| **Fast** | Low HP, high speed; punishes short mazes |
| **Regenerator** | Heals over time; Burn suppresses regeneration |
| **Boss** | Huge HP, resistances, abilities (for example an aura that buffs nearby enemies, or periodic speed bursts) |

- Attributes are all data-defined: HP, armour, speed, resistances per damage type, Core damage, abilities and drop table.
- Enemies **never attack structures**. They walk the path and damage the Core on arrival.
- **Flying enemies:** backlog. If added later, they ignore the maze and need dedicated anti-air.

---

## 8. Construction Rules (anti-exploit)

### Selling

- **85% refund** of total invested value (construction plus all upgrades).
- **100% refund** within 10 seconds of placement, to undo misclicks.

### Relocation

- Costs **10% of total invested value** (not refunded).
- The tower goes offline for a short pack-and-deploy time (about 3 seconds), and its ammo buffer moves with it.
- The destination must pass normal placement and path validation.

### Anti-juggling rules

- **No-build radius:** nothing can be placed, sold, relocated or demolished within about 6 tiles of any living enemy. This blocks the classic mid-wave rerouting exploit and still allows building elsewhere.
- **Construction time:** walls and towers take a short build time (about 1–2 seconds). They count for pathing only once complete, and enemies re-path once per completed change.
- **No gates.**
- **Destroyed structures:** not applicable, since enemies can't damage structures. If a future mechanic destroys something, it gives no refund.

---

## 9. Progression

1. **In-game tower upgrades:** branching paths, paid for with manufactured materials.
2. **Research tree:** permanent unlocks paid with research packs, such as new buildings, recipes, ammo variants, wall tiers and tower branches.
3. **Rare drops:** initially, bosses and nests drop **rare research materials** that unlock special tech. The full **equipment / loot system** (tower modules with specialized effects, not just damage) is deferred to the backlog. It's a large system and gets its own design pass once the core loop is proven fun.

---

## 10. Expanding Frontier

1. Nests in the active sector emit a continuous trickle of enemies.
2. **Assaults** happen periodically and are announced with an on-screen countdown. They are large, mixed waves, sometimes led by a boss.
3. **Neutralizing a nest** (two methods):
   - **Destroy:** nests have HP, and towers in range can target them.
   - **Suppress:** build a powered, supplied Suppressor within range and keep it running for a set time. This tests the player's supply lines at the frontier.
4. When every nest in a sector is neutralized, the next sector unlocks to the east. It brings new nests, stronger enemy mixes and higher-tier deposits.
5. Difficulty scales by sector depth and elapsed time. A "breather" window follows each sector clear.
6. **Fail condition:** Core HP reaches 0. The mode is endless; score is the number of sectors cleared and time survived.

---

## 11. Camera, Controls & UX

- WASD or arrow keys to pan, mouse-wheel zoom toward the cursor, middle-mouse drag to pan
- Left-click to select or build; right-click for context actions or to cancel; R to rotate; Q for pipette (copy building)
- Drag-to-place lines of walls and belts; box multi-select
- Construction ghosts with valid/invalid colouring
- **Path preview overlay:** shows the current enemy route live, plus the route the hovered placement *would* create
- **Pause, plus game speeds 1× / 2× / 3×**, with building allowed while paused
- Configurable keybindings through the Godot InputMap, saved to user settings
- Every input goes through named actions (`place`, `rotate`, `cancel`, `pan`, `zoom`, …) so the touch version is a new input layer, not a rewrite

---

## 12. Architecture

### Principles

- **The simulation is plain data, updated on a fixed tick** (default 30 Hz, configurable). Rendering interpolates between ticks and never mutates simulation state.
- **Deterministic:** seeded RNG and no frame-time-dependent logic. This gives reproducible bugs, headless tests and possible replays.
- **Data-driven:** towers, enemies, recipes, research, buildings and waves are defined as Godot `Resource` files (`.tres`) with typed scripts. Nothing about the game's balance is hardcoded.
- **Data-oriented hot paths:** enemies, projectiles and belt items live in packed arrays (structure of arrays), not one Node each. Large counts are drawn with `MultiMeshInstance2D` or `RenderingServer`.

### Key technical decisions

| System | Approach | Why |
|---|---|---|
| Tile grid | Chunked (32×32) packed arrays per layer: terrain, building id, path cost. Rendered with `TileMapLayer`. | Cache-friendly; chunks load as sectors unlock |
| Pathfinding | **One flow field** (BFS integration field from the Core's tiles) shared by all ground enemies. Enemies step down the gradient. | Cost doesn't grow with enemy count, unlike A* per enemy |
| Path updates | Recompute once, after a batch of completed constructions. Time-sliced across ticks if needed. Incremental repair only if profiling shows a need. | Cheap and predictable |
| Route validation | (1) **Local check:** if the tile's 8 neighbours stay connected around it, the global path can't be broken, so accept immediately (most placements). (2) Otherwise run a full reachability BFS from the Core to every nest. | Keeps preview validation fast |
| Enemy collision | Spatial hash grid plus light separation steering | Avoids O(n²) checks |
| Tower targeting | Same spatial hash, queried by range; targets re-evaluated every N ticks rather than every tick | Scales to hundreds of towers |
| Belts | **Transport-line segments** that store items as gaps and offsets; only segment ends need logic | The approach Factorio is known for; thousands of items stay cheap |
| Power | Networks as connected components, rebuilt on pole changes; a satisfaction ratio is applied per tick | Simple and cheap |
| Save/load | Versioned format with a migration hook from the **first** save (Phase 2) | Avoids a forced rewrite later |

### Project structure

```
res://
  scenes/        world/ ui/ debug/
  scripts/
    core/        # tick loop, RNG, event bus, input actions
    world/       # chunks, terrain, generation, sectors
    pathfinding/ # flow field, route validation
    combat/      # towers, projectiles, damage, status effects
    enemies/     # enemy SoA store, movement, spawning, nests
    buildings/   # placement, construction, sell/relocate
    economy/     # resources, inventories, recipes
    logistics/   # belts, inserters, power
    progression/ # research, upgrades
    saving/      # serializer, migrations
    render/      # view sync, multimesh drawers, overlays
  data/
    terrain/ buildings/ towers/ enemies/ ammo/ recipes/ research/ waves/
  assets/        sprites/ effects/ audio/
  tests/         unit/ benchmarks/
docs/
  decisions/     # Architecture Decision Records (ADR-NNN-*.md)
```

### Performance budgets

These are the acceptance gates on the reference machine (Apple Silicon M1, 60 fps):

| Metric | Budget |
|---|---|
| Simultaneous enemies | 2,000 |
| Belt items in transit | 10,000 |
| Active towers | 300 |
| Simulation tick (30 Hz) | ≤ 8 ms |
| Flow field full recompute (one sector) | ≤ 5 ms, or time-sliced |
| Placement validation (typical) | ≤ 1 ms |

A `tests/benchmarks/` scene measures each budget headlessly. Results are logged in `DEVELOPMENT_LOG.md` at every milestone.

---

## 13. Development Milestones

### Phase 0 — Foundation

- Godot project, folder structure, README, DEVELOPMENT_LOG, TODO, ADR template
- Fixed-tick simulation loop, seeded RNG, event bus
- Chunked grid data and a `TileMapLayer` renderer
- Data-definition loading (`Resource` classes)
- Input action layer and camera controls
- Debug overlay (FPS, tick time, entity counts, hovered tile)
- Headless test runner and benchmark scene

**Acceptance:** The project runs, the camera feels good on a large map, and tests run headlessly.

### Phase 1 — Maze prototype

1. Large top-down grid map with Rock, Ground and Bedrock
2. Factorio-style camera
3. Building placement with ghosts, rotation and drag-placement
4. Walls that change the enemy route
5. Core on the west edge, nests on the east edge, continuous spawning
6. Flow-field movement with route validation (no full blocking allowed)
7. Chain Gun tower (infinite ammo, debug flag)
8. Enemy HP, tower damage and Core HP; game over at 0
9. Resource counter (a single currency for now)
10. Selling and relocation with the costs and no-build radius from §8
11. Path preview overlay; pause and 1×/2×/3× speed
12. Excavating rock to open new routes (simple version)

**Acceptance:** The player builds a maze from walls and carved rock, enemies follow it, the Chain Gun kills them, illegal blocks are rejected, and juggling is impossible. A playable desktop build is exported.

### Phase 1.5 — Supply slice (fun check)

- Iron ore → drill → belt → smelter → ammo factory → inserter → Chain Gun
- Turn off the infinite-ammo flag

**Acceptance:** A playtest answers the question "Is defending a supply line fun?" Pillar 2 is adjusted before the full economy is built.

### Phase 2 — Economy

- Tier 1–2 resources and intermediates; drills, Excavator, storage, belts, inserters
- Smelting, assemblers, recipes, power network with brown-out
- Construction costs in materials
- **Versioned save/load**

**Acceptance:** The player automates production of wall materials and ammunition, and a save survives a restart.

### Phase 3 — Combat

- All six towers, ammo variants, damage types, resistances, status effects
- All five enemy types (including the Boss)
- Targeting priorities; wall tiers; demolition charges

**Acceptance:** Different tower and ammo combinations have measurable strategic advantages against different enemy mixes.

### Phase 4 — Progression

- Research tree and labs; tower upgrade branches; rare research drops
- Tier 3 resources and advanced production

**Acceptance:** Players can meaningfully strengthen their defense through research and upgrades.

### Phase 5 — Frontier

- Sectors, nest neutralization (destroy and suppress), periodic assaults, boss waves
- Difficulty scaling and procedural sector generation tuned per depth

**Acceptance:** An endless survive-and-expand loop that stays challenging for 3+ hours.

### Phase 6 — Polish & platforms

- Art, animation, VFX, audio, UI pass, tutorial or onboarding
- Optimization pass against the budgets; desktop exports for all three OSes
- Touch input layer and iPad prototype

### Backlog (after Phase 6, needs design sign-off)

- Flying enemies plus anti-air
- Equipment and loot system for towers
- Burrower enemy that tunnels rock
- Tier 4 exotic materials
- Water bridging
- Co-op multiplayer (the deterministic simulation makes lockstep feasible)

---

## 14. Development Rules

- Build playable milestones; never implement every system at once.
- **Check before building:** before starting any new system, write a short ADR in `docs/decisions/` covering:
  - the problem;
  - the options considered;
  - how it interacts with existing systems;
  - its performance impact against §12's budgets.

  Prototype or benchmark the risky parts before committing to them.
- **Measure, don't guess:** profile before optimizing, and re-run benchmarks after any change to a hot path.
- Test each system (headless unit tests where practical) before moving on.
- Never replace a working system without a demonstrated improvement (benchmark or playtest evidence).
- Keep the game playable after every milestone, and commit working milestones to Git.
- Maintain `DEVELOPMENT_LOG.md`, `TODO.md`, `README.md` (with setup instructions) and the ADRs.
- Prioritize gameplay over placeholder polish.
- No runtime dependencies or external services.

---

## 15. Immediate Next Task

Start **Phase 0**, then **Phase 1**. Don't begin Phase 1.5 until Phase 1's acceptance criteria pass in a playtest. Don't begin Phase 2 until the supply-slice fun check is done.

### Open questions (non-blocking)

- Sector and map dimensions (the starting values above are placeholders, to be tuned in playtests)
- Whether Core damage per enemy varies by type or is flat
- Whether the Repair Station stays in scope, since structures don't take damage (it could heal the Core instead)
