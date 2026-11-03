# Frontier Stronghold: notes for AI agents

Maze-building tower defense with automation, made in Godot 4.7.2 (GDScript).
Read `PROJECT_PLAN.md` (design), `TODO.md` (current work), `DEVELOPMENT_LOG.md`
(history and benchmarks) and `docs/decisions/` (ADRs) before changing systems.

## Working rules
- Run `tools/run_tests.sh` before every commit. It also fails on GDScript parse errors.
- Write an ADR in `docs/decisions/` before adding a new system. Benchmark the hot paths (`tools/run_benchmarks.sh`).
- Simulation (`scripts/sim`, `pathfinding`, `logistics`, `enemies`, `buildings`) is
  plain data with no Nodes (ADR-001). Views and art changes never touch it.
- Game definitions live in `data/*.tres`. Don't hardcode stats in scripts.
- **Versioning:** bump `application/config/version` in `project.godot` and the
  version fields in `export_presets.cfg`, add a `CHANGELOG.md` entry, and export
  with `tools/export.sh`. Every file given to the user carries the version in its name.
- **Web build:** `tools/export.sh Web`, then publish the folder to the `gh-pages` branch
  (orphan, force-pushed, with `.nojekyll`). Phone layout/touch: test with `--touch` or
  headless Chromium using iPhone emulation.
- Check visuals with `tools/screenshot.gd` (scenarios: start, battle, supply, enemy).
  Pass `--no-art` to check the fallback colours.

## Asset Licensing Policy & Art Integration (CC0 only)

The developing agent finds, downloads, verifies, credits and integrates free
assets itself. The user doesn't supply asset files.

### 1. Licence rules (non-negotiable)
- Use ONLY assets explicitly licensed **CC0 1.0** or **Public Domain**: free for
  any use, including commercial, with no attribution or share-alike requirements.
- Do NOT use CC-BY, CC-BY-SA, CC-BY-NC, GPL, "free for personal use", "free with
  credit", or anything with an unclear or missing licence, even temporarily.
- Verify the licence on the **original source page** (not a mirror or re-upload)
  before downloading. If it isn't clearly CC0 or public domain, skip it.
- Never use assets ripped from, or imitating, existing commercial games.
- Self-made placeholder art (e.g. generated in code) is allowed; list it in the credits.

### 2. Where to find assets (in order of preference)
1. **Kenney** (https://kenney.nl/assets, official mirror https://kenney.itch.io). All CC0, with a consistent style.
   Useful packs: Tower Defense (top-down), Sci-fi RTS, Top-down Shooter, Particle Pack,
   Smoke Particles, UI Pack, Interface/Impact/Sci-fi Sounds, Kenney Fonts.
2. **OpenGameArt.org**: only entries whose licence field lists CC0.
3. **itch.io free game assets**: only pages that explicitly state CC0.
4. **Poly Haven** / **ambientCG**: CC0 textures.
5. **Freesound.org**: only CC0 sounds.

Prefer a single source (Kenney) for a coherent look; mix sources only to fill gaps.

### 3. How to download
- Download the official zip into the scratchpad first, never straight into the repo.
- If a host is blocked by the environment's network policy, check the
  network-access documentation and try the official mirror. If that fails too,
  tell the user exactly which host to allow. Never use unofficial mirrors.
- Archives are untrusted: extract each into its own new folder, never run
  shipped scripts or executables, and inspect the contents first.
- Copy only the files actually used, plus the pack's licence file, into the repo.

### 4. Where assets go
- `assets/<type>/<source>_<pack_name>/`, where type is sprites, textures, effects, audio, ui or fonts.
- Keep the pack's original licence file in that folder.
- Pixel art uses the Nearest filter; smooth vector-style art uses Linear (with mipmaps). Be consistent per pack.

### 5. How to integrate
- Use the optional data fields: `TerrainDef.texture`, `BuildingDef.texture`,
  `BuildingDef.turret_texture` (faces +x and rotates to the aim), `EnemyDef.texture`
  (light/greyscale, tinted by `color`) and `ItemDef.icon`. Point the `.tres` files at them.
- Every renderer must keep working with no texture (`DataRegistry.art()` / `--no-art`).
- Scale: 1 tile = `WorldGrid.TILE_PX` (32 px). Source art is 64 px per tile.
  Footprints: Chain Gun and machines 2×2; walls, belts and inserters 1×1; Core 3×3.
- Art is view-only (ADR-001).
- After integrating, check screenshots (start, battle, supply):
  - enemies stand out from terrain;
  - belts show their direction;
  - an empty tower is obvious.

### 6. Credits listing (required)
- Every pack or asset gets an entry in `assets/CREDITS.md` **in the same commit** that adds it. Each entry includes:
  - name and author
  - source URL
  - licence and link
  - date added
  - local path
  - what it's used for
  - whether it was modified
- List self-made and generated placeholders too.
- When an asset is removed, delete its entry or mark it "Removed (date)".
- The in-game Credits screen (HUD → Credits) shows `assets/CREDITS.md`.
- `test_asset_credits` fails if any `assets/<type>/<pack>/` folder lacks a licence file or a CREDITS entry.
- Mention new assets in `CHANGELOG.md` and bump the patch version.
