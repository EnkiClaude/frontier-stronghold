# ADR-005: Items, belts, inserters and machines (supply slice)

- **Status:** Accepted
- **Date:** 2026-11-02

## Context
Phase 1.5 tests pillar 2, "logistics is defense": towers consume ammunition that
the factory produces and moves by belt. Belts may eventually carry 10,000+
items (budget §12), so per-item or per-tile Node logic is not an option.

## Options considered
1. **Per-tile slots:** each belt tile holds up to N items, and every tile is updated every tick. Simple, but the cost grows with belt length even when the belt is empty or jammed.
2. **Transport lines (chosen, Factorio-style):** consecutive belts merge into one *line*. A line stores its items as sorted positions along its length, so only the items move and a jam costs nothing extra.

## Decision

### Items
- `ItemDef` resources (`data/items`). Items are referenced by integer index in hot code.
- Phase 1.5 items: iron/copper ore, coal, stone, iron plate, ammo magazine.

### Belts
- Single lane, 1.875 tiles/s, items spaced 0.25 tiles apart (7.5 items/s).
- **Lines are rebuilt from scratch whenever the belt layout changes** (rare compared with ticks). Items keep their tile and offset across rebuilds.
  - A belt continues the line of the belt *behind* it. Failing that, a single side feeder continues it as a curve.
  - Any other feeder **side-loads**: its line ends by inserting into the target line halfway along that tile.
  - Loops are supported.
- Per tick, each line moves its items front to back. Each item is limited by the one ahead. The front item transfers into the downstream line when that has space; otherwise it waits (back-pressure).
- Items on a removed belt are lost.

### Machines (all non-blocking: enemies walk over them)
- **Mining drill (2×2):** mines the first drillable tile under it and pushes
  the result into whatever is directly in front: a belt, or a building that accepts the item.
- **Crafter (smelter, ammo factory; 2×2):** one fixed `RecipeDef` each, with
  bounded input and output buffers. Production stalls when the output is full.
- **Inserter (1×1):** takes one item from the tile behind it (a belt, or a
  machine's output) and delivers it to the tile in front (a belt, a machine
  input, or a tower magazine). It only picks up items the target can accept.

### Towers
- Rounds are tracked per tower. One delivered `ammo_magazine` adds `rounds_per_item` (10).
- New towers come with `starter_ammo` so the first minutes are playable.
- An empty tower doesn't fire and shows an empty indicator.
- `GameRules.infinite_ammo` restores the Phase 1 behaviour, for tests and debugging.

### Activation
Logistics only process buildings in the ACTIVE state. Construction, relocation
and selling register and unregister buildings with the belt network and the
factory system, so relocated machines keep their inventories.

## Performance impact
Belt cost is O(items) per tick and nothing per idle tile. Benchmark target: 10,000 items in transit within about 3 ms per tick on the cloud CPU.

## Consequences
- Two lanes, splitters and underground belts can come later without changing the line model.
- Construction still costs credits. Material costs come in Phase 2.
