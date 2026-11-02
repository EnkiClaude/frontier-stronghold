extends TestCase

const CONFIG := "res://data/world/default_worldgen.tres"


func _gen(seed_value: int) -> Array:
	var reg := DataRegistry.load_default()
	var cfg := load(CONFIG) as WorldGenConfig
	return [WorldGenerator.generate(cfg, reg, seed_value), reg, cfg]


func test_config_loads_ore_spawns() -> void:
	var cfg := load(CONFIG) as WorldGenConfig
	assert_true(cfg != null)
	assert_eq(cfg.ore_spawns.size(), 4)


func test_deterministic_for_same_seed() -> void:
	var a: WorldGrid = _gen(99)[0]
	var b: WorldGrid = _gen(99)[0]
	var c: WorldGrid = _gen(100)[0]
	assert_true(a.terrain == b.terrain, "same seed must give identical worlds")
	assert_false(a.terrain == c.terrain, "different seeds should differ")


func test_bedrock_borders_and_clear_core_zone() -> void:
	var r := _gen(5)
	var g: WorldGrid = r[0]
	var reg: DataRegistry = r[1]
	var cfg: WorldGenConfig = r[2]
	var bedrock := reg.terrain_code(&"bedrock")
	for x in g.width:
		assert_eq(g.get_terrain(x, 0), bedrock)
		assert_eq(g.get_terrain(x, g.height - 1), bedrock)
	for x in cfg.core_clear_cols:
		for y in range(1, g.height - 1):
			assert_eq(reg.walkable_lut[g.get_terrain(x, y)], 1, "core zone must be walkable at %d,%d" % [x, y])


func test_starter_ores_near_core() -> void:
	var r := _gen(5)
	var g: WorldGrid = r[0]
	var reg: DataRegistry = r[1]
	var cfg: WorldGenConfig = r[2]
	for spawn in cfg.ore_spawns:
		var code := reg.terrain_code(spawn.terrain_id)
		var found := 0
		for x in cfg.core_clear_cols:
			for y in g.height:
				if g.get_terrain(x, y) == code:
					found += 1
		assert_true(found >= 9, "%s starter patch too small (%d)" % [spawn.terrain_id, found])


func test_route_exists_for_many_seeds() -> void:
	for s in [1, 2, 3, 4, 5, 6, 7, 8]:
		var r := _gen(s)
		var g: WorldGrid = r[0]
		var reg: DataRegistry = r[1]
		var east := PackedInt32Array([g.idx(g.width - 1, g.height / 2)])
		assert_true(Reachability.all_reachable(g, reg.walkable_lut, WorldGenerator.west_edge_cells(g), east), "seed %d has no route" % s)


func test_route_carved_when_blocked() -> void:
	var reg := DataRegistry.load_default()
	var cfg := (load(CONFIG) as WorldGenConfig).duplicate() as WorldGenConfig
	cfg.rock_threshold = -1.0  # Everything outside the clear zones is rock.
	var g := WorldGenerator.generate(cfg, reg, 3)
	var east := PackedInt32Array([g.idx(g.width - 1, g.height / 2)])
	assert_true(Reachability.all_reachable(g, reg.walkable_lut, WorldGenerator.west_edge_cells(g), east))
