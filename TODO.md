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

## Phase 1 — Maze prototype ✅ (pending human playtest)
- [x] ADR-004 flow field + route validation
- [x] Core, nests, building layer, BuildingDef/TowerDef/EnemyDef data
- [x] Placement: ghosts, drag lines, rotation, validation with reasons
- [x] Walls, Chain Gun, enemies, spawning, assaults, HP scaling
- [x] Sell / relocate / no-build radius / excavation
- [x] Route + "what if" overlay, HUD, game over + restart
- [x] Export presets + export script
- [ ] **Human playtest on macOS**, then tune `data/rules/*.tres`
- [ ] Enemy separation (they walk in near single file)
- [ ] "What if" route while moving a building

## Phase 1.5 — Supply slice (next)
- [ ] ADR-005: items, belts (transport-line segments), inserters
- [ ] Iron ore drill → belt → smelter → ammo factory → inserter → Chain Gun
- [ ] Tower ammo buffer + "no ammo" indicator; turn off `infinite_ammo`
- [ ] Playtest question: is defending a supply line fun?

## Later / ideas
- [ ] In-game keybinding menu (backend exists: `Keybinds.rebind_keys`)
- [ ] Reduce grid-line moiré at far zoom (mipmaps or a separate grid overlay)
- [ ] Tune natural ore patch sizes (Phase 2)
