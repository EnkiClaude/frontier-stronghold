class_name MazeScenario
extends RefCounted
## Scripted "bot player" used by playtest tests, benchmarks and screenshots.
## Builds a serpentine maze of walls with Chain Guns in the corridors, using
## the same commands a human player would.

## Builds [param walls] vertical walls starting at column [param x0], spaced
## [param spacing] apart, with alternating gaps of [param gap] tiles at the top
## and bottom. Returns the number of structures placed.
static func build_serpentine(sim: GameSim, x0: int, walls: int = 4, spacing: int = 6, gap: int = 6, tower_every: int = 20) -> int:
	# This scenario tests mazing only; ammo supply is covered by SupplyScenario.
	sim.infinite_ammo = true
	var h := sim.grid.height
	var placed := 0
	for k in walls:
		var x := x0 + k * spacing
		var gap_at_top := k % 2 == 1
		for y in range(1, h - 1):
			if gap_at_top and y <= gap:
				continue
			if not gap_at_top and y >= h - 1 - gap:
				continue
			if sim.place(&"wall", Vector2i(x, y)) == "":
				placed += 1
	for k in walls - 1:
		var cx := x0 + k * spacing + spacing / 2 - 1
		for y in range(tower_every / 2, h - tower_every / 2, tower_every):
			if sim.place(&"chain_gun", Vector2i(cx, y)) == "":
				placed += 1
	return placed


## Length in tiles of the current enemy route from the first nest.
static func route_length(sim: GameSim) -> int:
	var at := sim.nests[0]
	return sim.path.trace(sim.grid.idx(at.x, at.y)).size()


static func run(sim: GameSim, seconds: float) -> void:
	for i in int(seconds * sim.tick_rate):
		sim.tick()
		if sim.game_over:
			return
