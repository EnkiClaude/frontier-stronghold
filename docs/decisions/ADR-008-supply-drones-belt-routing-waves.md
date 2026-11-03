# ADR-008: Supply drones, belt routing (tunnels, splitters, belt-to-building), wave pacing

- **Status:** Accepted
- **Date:** 2026-11-03

## Context
Playtest feedback on v0.3.0:
1. Routing belts is awkward: belts can't cross each other.
2. There's no way to split a belt.
3. Belting ammo to every tower "feels off". The player would rather produce
   ammo into storage and have towers fill themselves, so production volume is
   what limits the defense, and the base can sit apart from the defense line
   (which fits pushing outward later).
4. The continuous trickle leaves no quiet time to rebuild the maze.
5–6. There's too little ore near the base and in the wider world.
7. The route preview only updates while the game runs.

## Decision

### Supply drones (replaces "an arm per tower" as the main way to supply ammo)
- Every 0.5 s, each ammo-using tower with room for at least one item, and no
  delivery already on the way, requests ammo.
- The **nearest** stockpile building (Core or Storage) within
  `supply_range` (45 tiles) that has the item sends a drone carrying up to
  `supply_max_items` (5).
- The items leave the stockpile immediately (reserved). The drone flies at
  `drone_speed` (10 tiles/s) and loads the tower when it arrives. If the tower
  is gone by then, the items return to the Core.
- Consequences:
  - Production volume is the limit.
  - Distant towers resupply slowly, or not at all, until a forward Storage is built and kept stocked.
  - Arms and belts still work for direct feeding.
- Drones are simulation data (deterministic). Views draw them as small moving dots.

### Belts deliver into buildings
- A belt line whose next tile is a building, not a belt, inserts its front item
  into that building if the building accepts it (Core, Storage, crafter, tower,
  generator, recycler, splitter).
- This uses the same `accepts`/`give` path as arms.

### Splitter (1×1, directional)
- Accepts items from belts pointing into it (one-item buffer).
- Outputs round-robin to left, front and right, skipping blocked outputs.
- Outputs go to belts or buildings.

### Belt tunnels (entrance/exit pair, auto-placed)
- `belt_tunnel` tiles carry a direction and a role (entrance or exit). An
  entrance's successor is the first exit ahead of it, in the same direction,
  within `TUNNEL_MAX_GAP` (4) tiles. The exit continues that line.
- Items cross the gap instantly (the length counts as one tile).
- Tiles in between are free for anything, typically a crossing belt.
- **Auto-placement:** when the player drags a belt line across existing belts
  (or other buildings) for 1–4 tiles, the controller places a tunnel entrance
  on the tile before the obstacle and an exit on the tile after it, instead of
  re-orienting the crossed belts.

### Wave pacing
- The trickle is replaced by **small waves** every `wave_interval` (20 s).
  - Each spawns `wave_base_size + wave_growth_per_minute × minutes` enemies per nest, spaced `assault_spawn_spacing` apart.
  - Assaults are unchanged.
- After every assault finishes spawning there's a **lull** (`lull_after_assault`,
  20 s) with no spawns.
- The HUD shows the next wave and the lull countdown.

### Ore
- Starter patches can repeat (`OreSpawn.starter_patches`) and are bigger.
- Natural deposit thresholds drop with distance from the Core
  (`ore_density_gain`), so ore gets denser as you expand.

### Route preview while paused
- The displayed route uses `plan_passable` (it counts pending walls). It's
  recomputed whenever structures change, regardless of pause.
- Enemies still follow the live field.

## Performance impact
- Drones: O(towers / 15) requests per tick and O(drones) movement.
- Route preview: one BFS (about 16 ms) per structure change, not per frame.
- Splitters and tunnels add no per-item cost beyond the belt lines.
