# TODO

## Phase 0 — Foundation ✅
- [x] Project skeleton, docs, ADRs
- [x] Fixed-tick clock, deterministic RNG, event bus
- [x] Input action layer + user overrides
- [x] Data definitions + registry
- [x] Chunk-ready world grid + generator + renderer
- [x] Camera controls
- [x] Debug overlay
- [x] Headless tests + benchmarks
- [ ] Manual playtest of camera feel on macOS

## Phase 1 — Maze prototype (next)
- [ ] ADR-004: flow field and incremental route validation (use the Phase 0 benchmark numbers)
- [ ] Building layer in the grid (occupancy + blocking LUT); BuildingDef data
- [ ] Core building on the west edge; Core HP; game over
- [ ] Placement controller: ghost preview, rotation, drag-to-place lines, valid/invalid colours
- [ ] Walls (data-defined cost, build time)
- [ ] Route validation: local neighbour check, then full BFS fallback; reject full blocks
- [ ] Flow field from the Core; batched recompute after completed constructions
- [ ] Nests on the east edge; continuous spawning (data-defined waves)
- [ ] Enemy store (structure of arrays), flow-field movement, separation via spatial hash
- [ ] Enemy rendering with MultiMeshInstance2D
- [ ] Chain Gun tower (infinite-ammo debug flag), targeting via spatial hash, projectiles/hitscan
- [ ] Enemy HP, damage, death, currency rewards; resource counter HUD
- [ ] Sell (85%, or 100% within 10 s) and relocate (10% fee, 3 s offline)
- [ ] No-build radius around enemies (anti-juggling)
- [ ] Path preview overlay (current route + "what if" for the hovered placement)
- [ ] Excavating rock to open routes (simple version)
- [ ] Pause/speed HUD indicator
- [ ] Desktop export presets (macOS/Windows/Linux) and a playable build

## Later / ideas
- [ ] In-game keybinding menu (backend exists: `Keybinds.rebind_keys`)
- [ ] Reduce grid-line moiré at far zoom (mipmaps or a separate grid overlay)
- [ ] Tune natural ore patch sizes (Phase 2)
