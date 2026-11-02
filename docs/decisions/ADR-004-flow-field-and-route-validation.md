# ADR-004: Flow field pathing and route validation

- **Status:** Accepted
- **Date:** 2026-11-02

## Context
All ground enemies walk to the Core. Players reshape the route constantly with
walls, towers and excavation, and must never fully block it. The Phase 0
benchmark measured a full-map BFS in GDScript at **17 ms** (40,960 tiles, cloud
Xeon), which is over the 5 ms budget for anything that runs on every change.

## Options considered
1. **A\* per enemy:** cost grows with enemy count; recompute storms when the maze changes. Rejected.
2. **Godot `AStarGrid2D`:** fast for single queries, but still per enemy, and no route-validity check. Rejected.
3. **Shared BFS flow field + incremental validation (chosen).**

## Decision

### Layers (per tile, packed byte arrays)
- `passable`: terrain walkable AND no *completed* blocking structure. Enemies use this.
- `plan_passable`: `passable` AND no *pending* blocking structure (under
  construction, or a relocation target). Placement validation uses this, so two
  pending walls can never jointly block the route.
- `protected`: Core and nest footprints plus a buffer; nothing can be built there.

### Flow field
- A BFS distance field from the Core tiles over `passable`. Enemies step to the
  neighbour with the lowest distance. Diagonal steps are allowed only when both
  orthogonal neighbours are passable, so enemies don't cut corners.
- Recomputation is **batched and time-sliced**: changes mark the field dirty,
  and a background job processes a fixed number of tiles per tick
  (`flow_nodes_per_tick`, default 12,000). It then swaps the result in.
  - The budget is a *node count*, not a time limit, so results stay deterministic.
  - Enemies keep using the previous field for the 2–4 ticks a recompute takes.
    This is safe because nothing can be built near enemies (see below).

### Placement validation (two stages)
1. **Local "simple tile" test (O(1)):** look at the 8 tiles around the
   candidate. If all its passable orthogonal neighbours are connected through
   passable ring tiles, blocking it cannot disconnect anything. Multi-tile
   footprints are tested tile by tile in sequence. Most placements in open
   ground pass here.
2. **Fallback:** a full BFS on `plan_passable` with the candidate tiles blocked.
   It verifies that every nest tile and every tile holding a living enemy still
   reaches the Core.

The path preview's "what if" route reuses stage 2. It runs only after the
cursor has rested on a tile briefly, so it can't run every frame.

### Anti-juggling interaction
- No placing, selling, relocating or excavating within `no_build_radius` tiles of a living enemy.
- Construction takes time, and a completed wall only starts blocking once no
  enemy stands on its footprint.

Together these guarantee that an enemy's next tile can't suddenly become blocked.

## Performance impact
- Validation stage 1: microseconds.
- Stage 2: about 17 ms (cloud) per call. It only runs for placements that touch existing structures, and at most once per placement.
- Flow recompute: spread over about 4 ticks at 12k nodes per tick (about 5 ms per tick on cloud, less on M1).

## Consequences
- Route changes take effect about 0.1 s after a wall completes. This isn't noticeable.
- If larger maps push stage 2 or the recompute over budget, the BFS core is
  the first candidate for GDExtension (C++). The interface stays the same.
