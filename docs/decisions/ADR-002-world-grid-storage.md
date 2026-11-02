# ADR-002: Column-major flat grid storage

- **Status:** Accepted
- **Date:** 2026-11-02

## Context
The world is a strip with a fixed height that grows east as sectors unlock.
Pathfinding, placement and rendering all read tiles constantly.

## Options considered
1. **Dictionary of chunks:** flexible, but every tile read needs a hash lookup.
2. **Row-major flat array:** fast, but growing the width re-indexes every tile.
3. **Column-major flat array (chosen):** `index = x * height + y`.

## Decision
Each layer is a single packed array in column-major order. Growing east appends
columns to the end, so existing indices (stored in flow fields, enemy positions,
save files) never change. "Chunks" (32×32) are a logical concept for render
batching, dirty tracking and saving. They aren't a storage unit.

## Consequences
- O(1) tile access with no hashing. Neighbours are `±1` (north/south, with a
  column-boundary check) and `±height` (east/west).
- Bulk writers (generation) write the array directly. Single-tile edits go
  through `set_terrain()`, which emits `terrain_changed`.
- **Benchmark:** direct array reads are about 6× faster than calling
  `get_terrain()`, so hot loops should read arrays directly.
