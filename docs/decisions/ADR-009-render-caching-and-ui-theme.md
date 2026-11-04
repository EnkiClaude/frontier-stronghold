# ADR-009: Cache static buildings in map chunks; one code-built UI theme

- **Status:** Accepted
- **Date:** 2026-11-04

## Context
After the player reached a stable mid-game base, a profiler (`tools/profile_frame.gd`)
was run on a late-game state: about 2,500 structures, 7,000 belt items and 2,000 enemies.
The views took **about 25 ms per frame**, over the whole 60 fps budget:

- `BuildingRenderer`: 15.6 ms. Every building on the map, visible or not, was drawn from GDScript every frame.
- `ItemRenderer`: 9.4 ms. Every item's position was computed (two dictionary lookups) before culling.

The simulation itself was fine (3.8 ms per 30 Hz tick with 2,000 enemies).

Separately, the HUD used Godot's default grey theme with text-only buttons
and long status strings, which the player asked to modernise.

## Decision
**Rendering (view-only, ADR-001 unchanged):**
- Walls, belts and tunnels that are *active* never change look, so they are drawn
  into cached **32×32-tile chunk canvas items** that only redraw when their own
  contents change (signature check on `structures_version` changes).
  - Godot culls off-screen chunks itself.
  - Placing a wall only redraws its own chunk.
- Everything else (towers aim and show ammo, machines animate, anything under
  construction) is drawn every frame, **culled to the view**. The selection outline is drawn on top.
- `BeltNetwork.Line` caches tile centres, directions and a bounding box at rebuild.
  - The item renderer skips whole lines outside the view.
  - Items aren't drawn when tiles are under 7 px on screen.
- Enemy backing discs are a texture instead of `draw_circle`.
- The minimap bakes structures into a 1 px/tile image (on change and once a second) and draws all enemy dots in one `draw_multiline` call.

**UI:**
- `UiTheme` builds a single `Theme` in code (palette, rounded flat buttons with hover/pressed states, panels with shadows,
  sliders, checkboxes, scrollbars, tooltips). The HUD root uses it, so new controls are styled automatically.
- `BuildingIcons` renders toolbar and info-panel icons with the real
  `BuildingRenderer` in tiny one-shot `SubViewport`s, so icons always match the map (art or fallback).

## Result (same machine, same late-game state)
| | Before | After |
|---|---|---|
| All views, default zoom | ~25 ms | 3.2 ms |
| Buildings | 15.6 ms | ~0 (cached) |
| Belt items | 9.4 ms | ~2 ms |
| Enemies, zoomed out | 3.3 ms | 1.6 ms |

## Consequences
- A new static building kind must be added to `BuildingRenderer.STATIC_KINDS` only if its look never changes once built.
- Chunks are separate nodes under the building renderer (`show_behind_parent`).
- Test: `test_render_cache`.
