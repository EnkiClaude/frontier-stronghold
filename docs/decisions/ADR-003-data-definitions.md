# ADR-003: Game definitions as typed Godot Resources

- **Status:** Accepted
- **Date:** 2026-11-02

## Context
Tower stats, enemy attributes, recipes, research and terrain must not be
hardcoded, and they need to be easy to balance.

## Options considered
1. **JSON files:** tool-agnostic, but untyped and with no editor support.
2. **Typed Resources (`.tres`) (chosen):** typed, inspector-editable, text-based (diffable), no parser to maintain.

## Decision
Each definition type is a `Resource` script with `@export` fields (e.g.
`TerrainDef`), and each definition is a `.tres` file under `res://data/<type>/`.
`DataRegistry` loads a whole folder (sorted by name, handling exported
`.remap` files), validates it and builds lookup tables indexed by numeric code
for hot loops.

## Consequences
- New content means adding a `.tres` file; no code changes.
- Validation errors are collected in `DataRegistry.errors`, and a unit test
  asserts there are none.
- If modding is wanted later, a JSON importer can produce the same Resources.
