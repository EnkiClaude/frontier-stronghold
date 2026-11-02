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

## Phase 1.5 — Supply slice ✅ (pending human playtest)
- [x] ADR-005: items, belts (transport lines), inserters, machines
- [x] Iron ore drill → belt → smelter → ammo factory → inserter → Chain Gun
- [x] Tower ammo + empty indicator; `infinite_ammo` off by default
- [x] Automated supply playtest (supplied vs unsupplied)
- [ ] **Human playtest: is defending a supply line fun?**
- [ ] Profile the sim tick on an M1 (p95 is ~10 ms on the cloud CPU vs the 8 ms budget)

## Art
- [x] Texture support in data definitions with colour fallbacks (v0.2.2)
- [x] Self-made sci-fi placeholder set, credits file and screen, credits test
- [ ] **Blocked:** allow `kenney.nl` / `kenney.itch.io` in the environment's network settings, then replace placeholders with Kenney CC0 packs (Sci-fi RTS, Tower Defense, Particle Pack, UI Pack, Sci-fi Sounds)
- [ ] Effects: muzzle flashes, hit sparks, death bursts
- [ ] Audio (CC0)

## Phase 2 — Economy (after the playtest)
- [ ] ADR-006: storage, material construction costs, power, save format
- [ ] Copper/coal/stone uses; walls cost stone; storage chests
- [ ] Power network with brown-out
- [ ] Versioned save/load
- [ ] Two-lane belts? (decide after the playtest)

## Later / ideas
- [ ] In-game keybinding menu (backend exists: `Keybinds.rebind_keys`)
- [ ] Reduce grid-line moiré at far zoom (mipmaps or a separate grid overlay)
- [ ] Tune natural ore patch sizes (Phase 2)
