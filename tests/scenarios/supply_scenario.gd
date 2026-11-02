class_name SupplyScenario
extends RefCounted
## Scripted supply chain used by tests, benchmarks and screenshots:
## drill -> belt -> inserter -> smelter -> inserter -> ammo factory -> inserter -> tower.

## Builds the chain starting at [param at] (row y, going east). Converts the
## drill footprint to iron ore first. Returns the tower (or null on failure).
static func build_chain(sim: GameSim, at: Vector2i, belt_length: int = 4) -> Building:
	var ore := sim.reg.terrain_code(&"ore_iron")
	for dx in 2:
		for dy in 2:
			sim.grid.set_terrain(at.x + dx, at.y + dy, ore)
	var x := at.x
	var y := at.y
	var steps: Array = [[&"mining_drill", Vector2i(x, y), 0]]
	x += 2
	for k in belt_length:
		steps.append([&"conveyor_belt", Vector2i(x + k, y), 0])
	x += belt_length
	steps.append([&"inserter", Vector2i(x, y), 0])
	steps.append([&"smelter", Vector2i(x + 1, y), 0])
	steps.append([&"inserter", Vector2i(x + 3, y), 0])
	steps.append([&"ammo_factory", Vector2i(x + 4, y), 0])
	steps.append([&"inserter", Vector2i(x + 6, y), 0])
	steps.append([&"chain_gun", Vector2i(x + 7, y), 0])
	for s in steps:
		var err := sim.place(s[0], s[1], s[2])
		if err != "":
			push_error("SupplyScenario: %s at %s: %s" % [s[0], s[1], err])
			return null
	return sim.building_at(Vector2i(x + 7, y))


## Builds an ammo production row at [param at] ending in an ammo belt that runs
## east for [param belt_len] tiles, plus [param towers] Chain Guns south of the
## belt, each fed by its own inserter. Returns the towers.
static func build_defense_line(sim: GameSim, at: Vector2i, belt_len: int = 28, towers: int = 4, with_supply: bool = true) -> Array[Building]:
	var x := at.x
	var y := at.y
	var steps: Array = []
	if with_supply:
		var ore := sim.reg.terrain_code(&"ore_iron")
		for dx in 2:
			for dy in 2:
				sim.grid.set_terrain(x + dx, y + dy, ore)
		steps.append([&"mining_drill", Vector2i(x, y), 0])
		for k in 4:
			steps.append([&"conveyor_belt", Vector2i(x + 2 + k, y), 0])
		steps.append([&"inserter", Vector2i(x + 6, y), 0])
		steps.append([&"smelter", Vector2i(x + 7, y), 0])
		steps.append([&"inserter", Vector2i(x + 9, y), 0])
		steps.append([&"ammo_factory", Vector2i(x + 10, y), 0])
		steps.append([&"inserter", Vector2i(x + 12, y), 0])
		for k in belt_len:
			steps.append([&"conveyor_belt", Vector2i(x + 13 + k, y), 0])
	var out: Array[Building] = []
	for k in towers:
		var tx := x + 16 + k * 6
		if with_supply:
			steps.append([&"inserter", Vector2i(tx, y + 1), 1])
		steps.append([&"chain_gun", Vector2i(tx, y + 2), 0])
	for s in steps:
		var err := sim.place(s[0], s[1], s[2])
		if err != "":
			push_error("SupplyScenario: %s at %s: %s" % [s[0], s[1], err])
	for k in towers:
		var b := sim.building_at(Vector2i(x + 16 + k * 6, y + 2))
		if b != null:
			out.append(b)
	return out
