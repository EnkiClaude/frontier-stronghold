# ADR-006: Draw enemies and belt items with culled canvas calls, not MultiMesh

- **Status:** Accepted, verified on macOS 2026-11-03 (supersedes the MultiMesh part of ADR-001)
- **Date:** 2026-11-02

## Context
v0.2.0–v0.2.3 drew enemies and belt items through `MultiMeshInstance2D`
buffers. On the player's Mac (Compatibility renderer) **none** of them
appeared. The HUD counted 56 enemies and 200+ items, the minimap showed the
enemies, and tracers flew at invisible targets. Buildings, drawn with
`draw_texture_rect`, rendered fine. The cloud test renderer (Mesa llvmpipe)
showed everything, so the failure is platform-specific and can't be reproduced here.

## Options considered
1. **Debug the MultiMesh buffer layout on macOS.** It can't be tested from the dev environment, and it's risky.
2. **RenderingServer canvas items per entity.** Fast, but complex lifetime management.
3. **Plain `_draw()` with `draw_texture_rect`, culled to the visible area (chosen).**
   It's the same path that verifiably works on the player's machine.

## Decision
`EnemyRenderer` and `ItemRenderer` redraw every frame using canvas draw calls,
skipping anything outside the visible rectangle (plus a 1-tile margin). Godot's
2D batcher merges consecutive draws that use the same texture.

## Performance impact
Cost scales with what's **on screen**, not the total count. Typical views show
tens to a few hundred units. Worst case (zoomed fully out during a big assault)
is about 2,000 draw calls of GDScript overhead, roughly 1–3 ms. If profiling
on the Mac shows a problem, revisit option 2.

## Consequences
- No dependency on renderer-specific MultiMesh behaviour.
- Each enemy gets a dark backing disc, which improves contrast on every terrain.
