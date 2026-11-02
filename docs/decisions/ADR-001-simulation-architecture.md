# ADR-001: Fixed-tick, data-oriented, deterministic simulation

- **Status:** Accepted
- **Date:** 2026-11-02

## Context
The game needs thousands of enemies and belt items, configurable game speed,
reproducible bugs and headless tests. Godot's default style (one Node per
entity, logic in `_process`) is easy to write but slow at large entity counts
and frame-rate dependent.

## Options considered
1. **Node per entity, `_process` logic:** quick to write, but slow beyond a
   few hundred entities and not deterministic.
2. **`_physics_process` fixed step:** fixed step, but tied to engine physics
   settings and harder to drive from tests.
3. **Own fixed-tick clock + plain data objects (chosen).**

## Decision
- `SimClock` converts frame time into fixed ticks (default 30 Hz), with a speed
  multiplier, pause and a per-frame catch-up cap.
- (Rendering note: the MultiMesh drawing mentioned in early versions was replaced by culled canvas drawing; see ADR-006.)
- Simulation state lives in `RefCounted` objects holding packed arrays (structure
  of arrays). Nodes are views or controllers only, and never own simulation state.
- All randomness goes through `SimRng` streams forked by name.
- Systems run in a fixed order inside `Main._sim_tick`.
- **Renderer: GL Compatibility.** The game is 2D. This renderer has the widest
  hardware support (older Macs, integrated GPUs, iOS later) and lower startup cost.
- **Language: GDScript.** Hot loops are kept small and isolated so they can move
  to GDExtension (C++) if a benchmark requires it. C# is avoided because of
  iOS export limitations.

## Consequences
- Tests can run the simulation headlessly with `SimClock.step()`.
- Rendering must interpolate (`SimClock.alpha`) for smooth motion at 30 Hz.
- Lockstep multiplayer or replays become possible later.
