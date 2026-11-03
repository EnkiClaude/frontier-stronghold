# ADR-007: Resource roles, stockpile, towers and power (v0.3.0)

- **Status:** Accepted
- **Date:** 2026-11-03

## Context
The map has iron, copper, coal, stone and water, but only iron is used (iron →
plates → Chain Gun ammo). Credits only come from kills. The player asked for
the remaining towers, storage, an economy balance pass, and a clear purpose for
every resource. This covers Phase 3 (towers) and the core of Phase 2 (economy).
Art is out of scope (fallback shapes and colours only).

## Decision

### 1. Every resource has a job

| Resource | Refined into | Used for |
|---|---|---|
| **Iron ore** | Iron Plate (Smelter) | Chain Gun ammo; steel; sold for credits |
| **Copper ore** | Copper Plate (Smelter) | Building material for electric and special towers, generators and power nodes; coolant cells |
| **Coal** | — | Generator fuel; steel; Flamethrower fuel |
| **Stone** | Brick (Smelter) | Building material for generators, storage, recyclers and the Sniper Rifle; also gained by excavating rock |
| **Water** (pumped from lakes) | — | Coolant Cells for Icy Blast |
| Steel (2 iron plate + coal) | — | Sniper rounds; material for the Sniper, Tesla and Lightning towers |

### 2. Recipes (data: `data/recipes`)
Crafters hold a **list** of recipes, and the player picks one in the info panel.
Changing recipe returns the buffered inputs to the stockpile.
- **Smelter:** Iron Plate, Copper Plate, Brick (2 stone), Steel (2 iron plate + 1 coal).
- **Ammo Factory:** Ammo Magazine, Rifle Rounds (steel), Fuel Canister (2 coal + 1 iron plate), Coolant Cell (2 water + 1 copper plate).

### 3. Stockpile and storage
- The **Core** and every **Storage** building hold items. Arms can put any item
  in and take items out, so storage doubles as a buffer.
- Together they form the **stockpile**. Advanced buildings cost credits plus
  materials taken from it (`BuildingDef.material_cost`), Core first.
- Selling refunds 85% of credits and 85% of materials, into the Core.
- Early buildings (walls, Chain Gun, belts, arms, drill, smelter, ammo factory)
  stay credit-only, so the opening plays as before.
- Excavating rock adds 2 stone to the Core.

### 4. Credits from the factory: Recycler
The Recycler (2×2) takes any item from an arm and pays `ItemDef.value` credits,
one item every 0.5 s. This lets a strong factory fund expansion, so kills are
no longer the only income.

### 5. Power (Generators and Power Nodes)
- **Power Node (1×1):** powers buildings within 4.5 tiles and links to other nodes within 9 tiles.
- **Generator (2×2):** burns 1 coal every 5 s while there is demand, producing 120 power.
- Linked nodes form a **network** (rebuilt when nodes change).
  - `satisfaction = min(1, generation / demand)`.
  - Electric towers recharge at `satisfaction ×` their normal rate; with no power they don't fire.
- Only electric towers use power for now; machines stay unpowered (revisit later).

### 6. Towers (attack patterns in data: `TowerDef.attack`)

| Tower | Attack | Supply | Role |
|---|---|---|---|
| Chain Gun | single target, kinetic | Ammo Magazine | cheap all-rounder |
| Sniper Rifle | single target, long range, armour-piercing | Rifle Rounds | Armoured enemies |
| Flamethrower | cone; burns over time | Fuel Canister | swarms |
| Icy Blast | splash around the target; slow | Coolant Cell | control, amplifies others |
| Tesla Coil | pulse hitting everything around itself; stun | power | maze corners and chokes |
| Lightning Tower | long-range strike chaining to nearby enemies; brief stun | power | clusters |

### 7. Status effects and armour
- Stored per enemy (structure of arrays): slow (factor, timer), burn (damage per second, timer) and stun (timer).
- Armour reduces kinetic and cold damage fully, electric damage by half, and armour-piercing and fire damage not at all. A hit always deals at least 20%.

### 8. Toolbar categories
There are now 17 buildings, so the toolbar has tabs: Defense, Logistics,
Production and Power. Keys 1–9 pick within the current tab, Tab and the tab
buttons switch tabs, and Q/middle-click pipette works on everything.

## Performance impact
- Status effects add a few array reads per enemy per tick.
- The cone, splash and pulse attacks reuse the spatial-hash queries.
- Power networks are rebuilt only when nodes change; per-tick cost is O(nodes + consumers).

## Consequences
Phase 2 still lacks save/load and powered machines; Phase 3 still lacks the
Regenerator, Fast and Boss enemies.
