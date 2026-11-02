class_name WorldGenerator
extends RefCounted
## Procedural generation of the frontier strip.
##
## Noise is sampled in absolute world coordinates, so later sectors generated
## with [method fill_columns] continue seamlessly from earlier ones.
## Output is fully determined by (config, registry, seed).

## Generates a new world. Guarantees bedrock borders, clear Core/nest zones,
## starter ore near the Core and a walkable route from west to east.
static func generate(cfg: WorldGenConfig, reg: DataRegistry, seed_value: int) -> WorldGrid:
	var grid := WorldGrid.new(cfg.width, cfg.height)
	grid.nest_column = nest_column(cfg)
	var rng := SimRng.new(seed_value)
	fill_columns(grid, cfg, reg, rng, 0, cfg.width)
	_place_starter_patches(grid, cfg, reg, rng.fork("starter"))
	ensure_route(grid, cfg, reg, rng.fork("route"))
	return grid


## Fills columns [x_from, x_to) with natural terrain.
static func fill_columns(grid: WorldGrid, cfg: WorldGenConfig, reg: DataRegistry, rng: SimRng, x_from: int, x_to: int) -> void:
	var c_ground := reg.terrain_code(&"ground")
	var c_rock := reg.terrain_code(&"rock")
	var c_bedrock := reg.terrain_code(&"bedrock")
	var c_water := reg.terrain_code(&"water")

	var rock_noise := _noise(rng.fork("rock").next_seed(), cfg.rock_frequency, cfg.rock_octaves)
	var water_noise := _noise(rng.fork("water").next_seed(), cfg.water_frequency, 2)
	var ore_noises: Array[FastNoiseLite] = []
	var ore_codes := PackedInt32Array()
	var ore_thresholds := PackedFloat32Array()
	for spawn in cfg.ore_spawns:
		ore_noises.append(_noise(rng.fork("ore:" + spawn.terrain_id).next_seed(), spawn.frequency, 2))
		ore_codes.append(reg.terrain_code(spawn.terrain_id))
		ore_thresholds.append(spawn.threshold)

	var h := grid.height
	var nest_x := nest_column(cfg)
	var nest_start := nest_x - cfg.nest_clear_cols / 2
	var nest_end := nest_x + cfg.nest_clear_cols / 2
	var terrain := grid.terrain
	for x in range(x_from, x_to):
		var in_clear := x < cfg.core_clear_cols or (x >= nest_start and x < nest_end)
		for y in h:
			var code := c_ground
			if y == 0 or y == h - 1:
				code = c_bedrock
			elif not in_clear:
				if rock_noise.get_noise_2d(x, y) > cfg.rock_threshold:
					code = c_rock
				elif water_noise.get_noise_2d(x, y) > cfg.water_threshold:
					code = c_water
			if code == c_ground and x >= cfg.core_clear_cols:
				for o in ore_noises.size():
					if ore_noises[o].get_noise_2d(x, y) > ore_thresholds[o]:
						code = ore_codes[o]
						break
			terrain[x * h + y] = code
	grid.terrain = terrain


## Makes sure enemies spawning at the east edge can reach the west edge by
## carving a meandering tunnel through rock/water if needed.
static func ensure_route(grid: WorldGrid, cfg: WorldGenConfig, reg: DataRegistry, rng: SimRng) -> void:
	var c_ground := reg.terrain_code(&"ground")
	var c_bedrock := reg.terrain_code(&"bedrock")
	var h := grid.height
	var west := west_edge_cells(grid)
	var target_x := grid.nest_column if grid.nest_column >= 0 else grid.width - 1
	var east := PackedInt32Array([grid.idx(target_x, h / 2)])
	if Reachability.all_reachable(grid, reg.walkable_lut, west, east):
		return
	var y := h / 2
	for x in range(cfg.core_clear_cols - 1, target_x + 1):
		y = clampi(y + rng.next_int_range(-1, 1), 2, h - 3)
		for dy in range(-1, 2):
			var i := grid.idx(x, y + dy)
			var code := grid.terrain[i]
			if reg.walkable_lut[code] == 0 and code != c_bedrock:
				grid.terrain[i] = c_ground


## Column of the first nests, kept inside the map.
static func nest_column(cfg: WorldGenConfig) -> int:
	return clampi(cfg.nest_column, cfg.core_clear_cols + cfg.nest_clear_cols, cfg.width - 6)


## Indices of the walkable-candidate cells in the first column (Core side).
static func west_edge_cells(grid: WorldGrid) -> PackedInt32Array:
	var out := PackedInt32Array()
	for y in range(1, grid.height - 1):
		out.append(grid.idx(0, y))
	return out


static func _place_starter_patches(grid: WorldGrid, cfg: WorldGenConfig, reg: DataRegistry, rng: SimRng) -> void:
	var c_ground := reg.terrain_code(&"ground")
	var spawns := cfg.ore_spawns.filter(func(s: OreSpawn) -> bool: return s.starter_patch_radius > 0)
	if spawns.is_empty():
		return
	# Spread patches evenly north-south through the middle of the Core zone.
	var band_top := grid.height * 0.25
	var band := grid.height * 0.5
	for i in spawns.size():
		var spawn: OreSpawn = spawns[i]
		var r := spawn.starter_patch_radius
		var cy := int(band_top + band * (i + 0.5) / spawns.size()) + rng.next_int_range(-2, 2)
		var cx := clampi(cfg.core_clear_cols - r - 4 + rng.next_int_range(-3, 3), r + 6, cfg.core_clear_cols - r - 1)
		var code := reg.terrain_code(spawn.terrain_id)
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if dx * dx + dy * dy > r * r + r:
					continue
				var x := cx + dx
				var y := cy + dy
				if grid.in_bounds(x, y) and grid.get_terrain(x, y) == c_ground:
					grid.terrain[grid.idx(x, y)] = code


static func _noise(noise_seed: int, frequency: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = noise_seed
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = frequency
	n.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	n.fractal_octaves = maxi(1, octaves)
	return n
