extends SceneTree
## Headless performance benchmarks. Results go in DEVELOPMENT_LOG.md.
##
##   godot --headless --path . -s res://tests/benchmarks/run_benchmarks.gd

const CONFIG := "res://data/world/default_worldgen.tres"
const RUNS := 5


func _initialize() -> void:
	var reg := DataRegistry.load_default()
	var cfg := load(CONFIG) as WorldGenConfig
	print("Benchmarks (median of %d runs)" % RUNS)
	print("Engine: ", Engine.get_version_info()["string"], " | ", OS.get_processor_name())

	_report("World generation (%dx%d)" % [cfg.width, cfg.height], func() -> void:
		WorldGenerator.generate(cfg, reg, 1))

	var grid := WorldGenerator.generate(cfg, reg, 1)
	var west := WorldGenerator.west_edge_cells(grid)
	_report("BFS distance field, full map (%d tiles)" % grid.size(), func() -> void:
		Reachability.distance_field(grid, reg.walkable_lut, west))

	var big := WorldGrid.new(1024, 160)
	_report("BFS distance field, 8-sector map (%d tiles)" % big.size(), func() -> void:
		Reachability.distance_field(big, reg.walkable_lut, WorldGenerator.west_edge_cells(big)))

	_report("1M grid reads (get_terrain)", func() -> void:
		var acc := 0
		for i in 1000000:
			acc += grid.get_terrain(i % grid.width, i % grid.height))

	_report("1M direct packed-array reads", func() -> void:
		var t := grid.terrain
		var n := t.size()
		var acc := 0
		for i in 1000000:
			acc += t[i % n])
	_bench_sim(reg, cfg)
	_bench_belts()
	quit(0)


## 10,000 items on 50 belt loops of 52 tiles (moving, not jammed).
func _bench_belts() -> void:
	var g := WorldGrid.new(200, 160)
	var net := BeltNetwork.new(g)
	for k in 50:
		var x0 := (k % 10) * 18 + 1
		var y0 := (k / 10) * 30 + 1
		# 14 x 14 square loop (52 tiles), clockwise.
		for x in range(x0, x0 + 13):
			net.add_belt(g.idx(x, y0), 0)
		for y in range(y0, y0 + 13):
			net.add_belt(g.idx(x0 + 13, y), 1)
		for x in range(x0 + 1, x0 + 14):
			net.add_belt(g.idx(x, y0 + 13), 2)
		for y in range(y0 + 1, y0 + 14):
			net.add_belt(g.idx(x0, y), 3)
	net.ensure_built()
	var added := 0
	for line in net.lines:
		var p := 0.1
		while p < line.tiles.size() - 0.3 and added < 10000 and line.items.size() < 200:
			line.pos.append(p)
			line.items.append(0)
			p += BeltNetwork.SPACING + 0.01
			added += 1
	var times: Array[float] = []
	for i in 120:
		var t0 := Time.get_ticks_usec()
		net.tick(1.0 / 30.0)
		times.append((Time.get_ticks_usec() - t0) / 1000.0)
	times.sort()
	print("  %-48s %8.2f ms (p95 %.2f)" % ["Belt tick: %d items on %d lines" % [net.item_count(), net.lines.size()], times[60], times[114]])


## Full simulation tick under load: maze + towers + 2,000 enemies.
func _bench_sim(reg: DataRegistry, cfg: WorldGenConfig) -> void:
	var sim := GameSim.new(reg, WorldGenerator.generate(cfg, reg, 4242), 4242)
	sim.credits = 1000000
	var placed := MazeScenario.build_serpentine(sim, 9, 4, 5, 6, 10)
	MazeScenario.run(sim, 3.0)
	while sim.path.is_updating():
		sim.tick()
	var rng := SimRng.new(1)
	var walkable := PackedInt32Array()
	for i in sim.grid.size():
		if sim.path.dist[i] > 0 and sim.grid.cell_of(i).x > 30:
			walkable.append(i)
	for k in 2000:
		var tile := walkable[rng.next_int_range(0, walkable.size() - 1)]
		sim.enemies.spawn(k % reg.enemies.size(), tile, sim.grid, 1.0e9, rng)
	var towers := 0
	for b: Building in sim.buildings.values():
		if b.def.tower != null:
			towers += 1
	var times: Array[float] = []
	for i in 300:
		var t0 := Time.get_ticks_usec()
		sim.tick()
		times.append((Time.get_ticks_usec() - t0) / 1000.0)
	times.sort()
	print("  %-48s %8.2f ms (p95 %.2f)" % ["Sim tick: %d enemies, %d towers, %d structures" % [sim.enemies.count, towers, placed], times[150], times[284]])

	var wall := Vector2i(100, 40)
	var t1 := Time.get_ticks_usec()
	var err := sim.check_place(&"wall", wall)
	print("  %-48s %8.2f ms (%s)" % ["Placement check, open ground", (Time.get_ticks_usec() - t1) / 1000.0, err if err != "" else "ok"])
	_report("Route validation, full-BFS fallback", func() -> void:
		sim.path._all_reach_goal(sim.path.plan_passable, sim._enemy_cells()))
	var ticks := [0]  # Lambdas capture locals by value; use a container.
	_report("Flow field recompute, total (time-sliced)", func() -> void:
		sim.path.mark_dirty()
		ticks[0] = 0
		while sim.path.is_updating():
			sim.path.tick()
			ticks[0] += 1)
	print("  %-48s %8d" % ["  ...spread over ticks", ticks[0]])


func _report(label: String, fn: Callable) -> void:
	var times: Array[float] = []
	for i in RUNS:
		var t0 := Time.get_ticks_usec()
		fn.call()
		times.append((Time.get_ticks_usec() - t0) / 1000.0)
	times.sort()
	print("  %-48s %8.2f ms" % [label, times[RUNS / 2]])
