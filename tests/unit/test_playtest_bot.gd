extends TestCase
## End-to-end Phase 1 acceptance: a scripted player builds a maze on a real
## generated map, enemies follow it and the Chain Guns kill them.

const CONFIG := "res://data/world/default_worldgen.tres"


func _sim(seed_value: int) -> GameSim:
	var reg := DataRegistry.load_default()
	var cfg := load(CONFIG) as WorldGenConfig
	return GameSim.new(reg, WorldGenerator.generate(cfg, reg, seed_value), seed_value)


func test_maze_lengthens_route_and_defends_core() -> void:
	var sim := _sim(4242)
	sim.credits = 100000
	var straight := MazeScenario.route_length(sim)
	# Build in the rock-free zone in front of the Core.
	var placed := MazeScenario.build_serpentine(sim, 9, 4, 5)
	assert_true(placed > 550, "placed %d structures" % placed)
	MazeScenario.run(sim, 5.0)
	while sim.path.is_updating():
		sim.tick()
	var mazed := MazeScenario.route_length(sim)
	assert_true(mazed > straight + 300, "route %d -> %d tiles" % [straight, mazed])
	# Enemies need ~3 minutes to cross the map; play 7 minutes incl. 3 assaults.
	MazeScenario.run(sim, 420.0)
	assert_false(sim.game_over, "core must survive 7 minutes behind the maze")
	assert_true(sim.kills > 50, "kills: %d" % sim.kills)
	assert_true(sim.kills > sim.leaked * 10, "kills %d vs leaked %d" % [sim.kills, sim.leaked])


func test_undefended_core_falls() -> void:
	var sim := _sim(4242)
	MazeScenario.run(sim, 600.0)
	assert_true(sim.game_over or sim.core_hp < sim.rules.core_hp / 2, "core hp %d" % sim.core_hp)


func test_every_maze_placement_keeps_a_route() -> void:
	var sim := _sim(77)
	sim.credits = 100000
	MazeScenario.build_serpentine(sim, 40, 6, 5, 3)  # Through natural rock.
	MazeScenario.run(sim, 5.0)
	while sim.path.is_updating():
		sim.tick()
	for s in sim.path.spawn_cells:
		assert_true(sim.path.dist[s] > 0, "spawn %d cut off" % s)
