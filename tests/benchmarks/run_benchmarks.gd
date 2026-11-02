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
	quit(0)


func _report(label: String, fn: Callable) -> void:
	var times: Array[float] = []
	for i in RUNS:
		var t0 := Time.get_ticks_usec()
		fn.call()
		times.append((Time.get_ticks_usec() - t0) / 1000.0)
	times.sort()
	print("  %-48s %8.2f ms" % [label, times[RUNS / 2]])
