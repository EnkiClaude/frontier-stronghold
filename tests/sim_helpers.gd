class_name SimHelpers
extends RefCounted
## Builders for small, hand-made test worlds.

## Open ground map ([param w] x [param h]) with bedrock top/bottom rows, plus a GameSim on it.
static func open_sim(w: int = 60, h: int = 24, seed_value: int = 1) -> GameSim:
	var reg := DataRegistry.load_default()
	var g := WorldGrid.new(w, h)
	var bedrock := reg.terrain_code(&"bedrock")
	for x in w:
		g.terrain[g.idx(x, 0)] = bedrock
		g.terrain[g.idx(x, h - 1)] = bedrock
	return GameSim.new(reg, g, seed_value)


## Runs [param seconds] of game time.
static func run(sim: GameSim, seconds: float) -> void:
	for i in int(seconds * sim.tick_rate):
		sim.tick()


## Spawns one enemy of [param type_id] at tile ([param x], [param y]).
static func spawn_at(sim: GameSim, type_id: StringName, x: int, y: int, hp: float = -1.0) -> int:
	var t := sim.reg.enemies.find(sim.reg.enemies_by_id[type_id])
	var health := hp if hp > 0.0 else sim.reg.enemies[t].hp
	var uid := sim.enemies.spawn(t, sim.grid.idx(x, y), sim.grid, health, SimRng.new(5))
	sim.spatial.rebuild(sim.enemies)
	return uid


## Finishes every pending construction immediately (enemy footprint rules still apply).
static func finish_construction(sim: GameSim) -> void:
	for i in 200:
		sim.tick()
